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
          interval = "72h";
          url = "https://community-charts.github.io/helm-charts";
        };
      }
      # --- sealed-secrets --- #
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "sealed-secrets";
          namespace = "flux-system";
        };
        spec = {
          interval = "72h";
          url = "https://bitnami-labs.github.io/sealed-secrets";
        };
      }
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "sealed-secrets";
          namespace = "flux-system";
        };
        spec = {
          interval = "72h";
          chart = {
            spec = {
              chart = "sealed-secrets";
              sourceRef = {
                kind = "HelmRepository";
                name = "sealed-secrets";
              };
            };
          };
          install.crds = "CreateReplace";
          upgrade.crds = "CreateReplace";
        };
      }
      # --- valkey --- #
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "valkey";
          namespace = "flux-system";
        };
        spec = {
          interval = "72h";
          url = "https://valkey.io/valkey-helm/";
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
        kind = "Deployment";
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
          annotations = {
            "service.cilium.io/global" = "true";
            "service.cilium.io/affinity" = "remote";
          };
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
