{
  pkgs,
  # config,
  kubenix,
  ...
}: let
  kubeVersion = builtins.substring 0 4 "${pkgs.k3s.version}";
in {
  imports = [
    kubenix.modules.k8s
    kubenix.modules.helm
  ];

  kubenix.project = "shared";
  kubernetes = {
    version = kubeVersion;
    namespace = "default";
    resources.namespaces = {
      cert-manager = {};
      whoami = {};
    };
    helm.releases = {
      sealed-secrets = {
        namespace = "kube-system";
        chart = kubenix.lib.helm.fetch {
          repo = "https://bitnami-labs.github.io/sealed-secrets";
          chart = "sealed-secrets";
          version = "2.18.6";
          sha256 = "";
        };
        values = {
          ingress.enabled = true;
          nodeSelector.role = "server";
          resources = {
            limits = {
              cpu = "500m";
              memory = "256Mi";
            };
            requests = {
              cpu = "1m";
              memory = "8Mi";
            };
          };
        };
      };
    };
    objects = [
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
