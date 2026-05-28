{
  pkgs,
  # config,
  kubenix,
  ...
}: let
  kubeVersion = builtins.substring 0 4 "${pkgs.k3s.version}";
  domain = "andrewlee.fun";
in {
  imports = [
    kubenix.modules.k8s
  ];

  kubenix.project = "home";
  kubernetes = {
    version = kubeVersion;
    namespace = "default";
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
            tunnelConfig.name = "home";
            resources = {
              limits = {
                cpu = "300m";
                memory = "256Mi";
              };
              requests = {
                cpu = "10m";
                memory = "16Mi";
              };
            };
            # cloudflared tunnel route dns home <domain>.andrewlee.fun
            ingress = [
              {
                hostname = "whoami.${domain}";
                service = "http://whoami.whoami.svc.cluster.local:80";
              }
              {
                hostname = "hubble.${domain}";
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
