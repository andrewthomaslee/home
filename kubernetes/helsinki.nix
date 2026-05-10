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

  kubenix.project = "helsinki";
  kubernetes = {
    version = kubeVersion;
    namespace = "default";
    helm.releases = {};
    objects = [
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "cloudflared";
          namespace = "cloudflare";
        };
        spec = {
          interval = "24h";
          chart = {
            spec = {
              chart = "cloudflared";
              version = "2.2.7";
              interval = "24h";
              sourceRef = {
                kind = "HelmRepository";
                name = "cloudflared";
                namespace = "flux-system";
              };
            };
          };
          values = {
            tunnelSecrets = {
              existingPemFileSecret.name = "cloudflared-cert-pem-file-secret";
              existingConfigJsonFileSecret.name = "cloudflared-config-json-file-secret";
            };
            tunnelConfig.name = "cloud";
            resources = {
              limits = {
                cpu = "200m";
                memory = "128Mi";
              };
              requests = {
                cpu = "100m";
                memory = "64Mi";
              };
            };
            # cloudflared tunnel route dns cloud <domain>.andrewlee.cloud
            ingress = [
              {
                hostname = "whoami.andrewlee.cloud";
                service = "http://whoami.whoami.svc.cluster.local:80";
              }
              {
                hostname = "hubble.andrewlee.cloud";
                service = "http://hubble-ui.kube-system.svc.cluster.local:80";
              }
              {
                service = "http_status:404"; # MUST GO LAST
              }
            ];
          };
        };
      }
      # --- garage --- #
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "garage";
      }
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "garage";
          namespace = "garage";
        };
        spec = {
          interval = "24h";
          chart = {
            spec = {
              chart = "garage";
              version = "2.3.2";
              interval = "72h";
              sourceRef = {
                kind = "HelmRepository";
                name = "garage";
                namespace = "flux-system";
              };
            };
          };
          values = {
            nodeSelector."machine" = "kamrui-p1";
            image.tag = "2.3.0";
            deployment.replicaCount = 1;
            garage = {
              replicationFactor = 1;
              compressionLevel = 19;
              metadataAutoSnapshotInterval = "2 days";
            };
            persistence = {
              meta = {
                size = "5Gi";
                storageClass = "local-path";
              };
              data = {
                size = "50Gi";
                storageClass = "local-path";
              };
            };
            # Resource requests/limits
            resources = {
              limits = {
                cpu = "2";
                memory = "4Gi";
              };
              requests = {
                cpu = "100m";
                memory = "128Mi";
              };
            };
          };
        };
      }
      # --- GitLab --- #
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "gitlab";
      }
      # --- Postgres ---#
      {
        apiVersion = "postgresql.cnpg.io/v1";
        kind = "Cluster";
        metadata = {
          name = "postgres";
          namespace = "gitlab";
        };
        spec = {
          instances = 1;
          storage = {
            size = "150Gi";
            storageClass = "local-path";
          };
          walStorage = {
            size = "15Gi";
            storageClass = "local-path";
          };
          resources = {
            limits = {
              cpu = "2";
              memory = "4Gi";
            };
            requests = {
              cpu = "100m";
              memory = "128Mi";
            };
          };
        };
      }
      #--- Valkey --- #
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "valkey";
          namespace = "gitlab";
        };
        spec = {
          interval = "72h";
          chart = {
            spec = {
              chart = "valkey";
              version = "0.9.4";
              interval = "72h";
              sourceRef = {
                kind = "HelmRepository";
                name = "valkey";
                namespace = "flux-system";
              };
            };
          };
          values = {
            image.tag = "9.0.2";
            # Resource requests/limits
            resources = {
              limits = {
                cpu = "1";
                memory = "1Gi";
              };
              requests = {
                cpu = "100m";
                memory = "128Mi";
              };
            };
            initResources = {
              limits = {
                cpu = "1";
                memory = "1Gi";
              };
              requests = {
                cpu = "100m";
                memory = "128Mi";
              };
            };
            # Persistence
            dataStorage = {
              enabled = true;
              requestedSize = "8Gi";
              className = "local-path";
              nodeSelector."machine" = "kamrui-p1";
            };
          };
        };
      }
    ];
  };
}
