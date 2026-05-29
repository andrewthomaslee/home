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
    namespace = "shared";
    resources = {
      namespaces = {
        cert-manager = {};
        whoami = {};
      };
      deployments.whoami = {
        metadata.namespace = "whoami";
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
              containers.whoami = {
                image = "traefik/whoami";
                args = ["--port" "8080"];
                ports = [
                  {
                    containerPort = 8080;
                    protocol = "TCP";
                  }
                ];
                securityContext = {
                  allowPrivilegeEscalation = false;
                  capabilities.drop = ["ALL"];
                };
              };
            };
          };
        };
      };
      services.whoami = {
        metadata = {
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
              protocol = "TCP";
              targetPort = 8080;
            }
          ];
        };
      };
      ingresses.whoami = {
        metadata.namespace = "whoami";
        spec.rules = [
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
    objects = [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "sealed-secrets-oci";
          namespace = "flux-system";
        };
        spec = {
          type = "oci";
          interval = "7d";
          url = "oci://registry-1.docker.io/bitnamicharts";
        };
      }
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "sealed-secrets";
          namespace = "kube-system";
        };
        spec = {
          interval = "7d";
          chart.spec = {
            chart = "sealed-secrets";
            version = "2.18.6";
            reconcileStrategy = "ChartVersion";
            sourceRef = {
              kind = "HelmRepository";
              name = "sealed-secrets-oci";
              namespace = "flux-system";
            };
          };
          install.crds = "CreateReplace";
          upgrade.crds = "CreateReplace";
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
      }
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "cert-manager-oci";
          namespace = "flux-system";
        };
        spec = {
          type = "oci";
          interval = "7d";
          url = "oci://quay.io/jetstack/charts";
        };
      }
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "cert-manager";
          namespace = "cert-manager";
        };
        spec = {
          interval = "7d";
          chart = {
            spec = {
              chart = "cert-manager";
              version = "v1.14.0";
              reconcileStrategy = "ChartVersion";
              sourceRef = {
                kind = "HelmRepository";
                name = "cert-manager-oci";
                namespace = "flux-system";
              };
            };
          };
          install.crds = "CreateReplace";
          upgrade.crds = "CreateReplace";
          values = {
            nodeSelector.role = "server";
            resources = {
              limits = {
                cpu = "500m";
                memory = "256Mi";
              };
              requests = {
                cpu = "10m";
                memory = "32Mi";
              };
            };
          };
        };
      }
    ];
  };
}
