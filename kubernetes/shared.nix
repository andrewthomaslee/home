{
  pkgs,
  # config,
  kubenix,
  ...
}: let
  kubeVersion = builtins.substring 0 4 "${pkgs.k3s.version}";
in {
  imports = [kubenix.modules.k8s];

  kubenix.project = "shared";
  kubernetes = {
    version = kubeVersion;
    namespace = "default";
    objects = [
      # --- cloudflared --- #
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "cloudflare";
      }
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "cloudflared";
          namespace = "flux-system";
        };
        spec = {
          interval = "24h";
          url = "https://community-charts.github.io/helm-charts";
        };
      }
      # --- tailscale --- #
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "tailscale";
      }
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "tailscale-operator";
          namespace = "flux-system";
        };
        spec = {
          interval = "24h";
          url = "https://pkgs.tailscale.com/helmcharts";
        };
      }
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "tailscale";
          namespace = "tailscale";
        };
        spec = {
          interval = "24h";
          chart = {
            spec = {
              chart = "tailscale-operator";
              version = "1.96.5";
              interval = "24h";
              sourceRef = {
                kind = "HelmRepository";
                name = "tailscale-operator";
                namespace = "flux-system";
              };
            };
          };
          values = {
            apiServerProxyConfig.mode = "true";
          };
        };
      }
      # --- vcluster --- #
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "vcluster-home";
      }
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "vcluster-helsinki";
      }
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "vcluster";
          namespace = "flux-system";
        };
        spec = {
          interval = "24h";
          url = "https://charts.loft.sh";
        };
      }
      # --- whoami --- #
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "whoami";
      }
      {
        apiVersion = "apps/v1";
        kind = "DaemonSet";
        metadata = {
          name = "whoami";
          namespace = "whoami";
        };
        spec = {
          selector.matchLabels.app = "whoami";
          template = {
            metadata.labels.app = "whoami";
            spec = {
              securityContext = {
                runAsNonRoot = true;
                runAsUser = 1000;
                runAsGroup = 1000;
                fsGroup = 1000;
                seccompProfile.type = "RuntimeDefault";
              };
              containers = [
                {
                  name = "whoami";
                  image = "traefik/whoami";
                  args = [
                    "--port"
                    "8080"
                  ];
                  ports = [{containerPort = 8080;}];
                  securityContext = {
                    allowPrivilegeEscalation = false;
                    capabilities.drop = ["ALL"];
                  };
                }
              ];
            };
          };
        };
      }
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "whoami";
          namespace = "whoami";
          annotations."service.cilium.io/global" = "true";
        };
        spec = {
          type = "ClusterIP";
          ipFamilies = ["IPv4" "IPv6"];
          ipFamilyPolicy = "PreferDualStack";
          selector.app = "whoami";
          ports = [
            {
              port = 80;
              targetPort = 8080;
            }
          ];
        };
      }
    ];
  };
}
