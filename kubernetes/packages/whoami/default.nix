{
  pkgs,
  # config,
  kubenix,
  ...
}: let
  kubeVersion = builtins.substring 0 4 "${pkgs.k3s.version}";
in {
  imports = [kubenix.modules.k8s];

  kubenix.project = "whoami";
  kubernetes = {
    version = kubeVersion;
    namespace = "whoami";
    resources = {
      namespaces.whoami = {};
      deployments.whoami.spec = {
        selector.matchLabels.app = "whoami";
        template = {
          metadata.labels.app = "whoami";
          spec = {
            nodeSelector.web = "true";
            securityContext = {
              runAsNonRoot = true;
              runAsUser = 1000;
              runAsGroup = 1000;
              fsGroup = 1000;
              seccompProfile.type = "RuntimeDefault";
            };
            containers.whoami = {
              image = "traefik/whoami";
              args = ["--port" "8080"];
              ports = [
                {
                  containerPort = 8080;
                  protocol = "TCP";
                }
              ];
              resources = {
                requests = {
                  cpu = "1m";
                  memory = "4Mi";
                };
                limits = {
                  cpu = "100m";
                  memory = "64Mi";
                };
              };
              securityContext = {
                allowPrivilegeEscalation = false;
                capabilities.drop = ["ALL"];
              };
            };
          };
        };
      };
      services.whoami = {
        metadata.annotations = {
          "service.cilium.io/global" = "true";
          "service.cilium.io/affinity" = "remote";
        };
        spec = {
          type = "ClusterIP";
          ipFamilies = ["IPv4" "IPv6"];
          ipFamilyPolicy = "PreferDualStack";
          selector.app = "whoami";
          ports = [
            {
              port = 80;
              protocol = "TCP";
              targetPort = 8080;
            }
          ];
        };
      };
      ingresses.whoami.spec.rules = [
        {
          host = "whoami.localhost";
          http.paths = [
            {
              path = "/";
              pathType = "Prefix";
              backend = {
                service = {
                  name = "whoami";
                  port.number = 80;
                };
              };
            }
          ];
        }
      ];
    };
  };
}
