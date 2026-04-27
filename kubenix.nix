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
    # kubenix.modules.helm
  ];

  kubenix.project = "home";
  kubernetes = {
    version = kubeVersion;
    namespace = "default";
    # helm.releases = {};
    resources = {
    };
    objects = [
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
        };
        spec = {
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
