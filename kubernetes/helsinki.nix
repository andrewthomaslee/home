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
            # cloudflared tunnel route dns home <domain>.andrewlee.cloud
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
    ];
  };
}
