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
    kubenix.modules.helm
  ];

  kubenix.project = "home";
  kubernetes = {
    version = kubeVersion;
    namespace = "home";
    resources.namespaces.cloudflare = {};
    helm.releases = {
      cloudflared = {
        namespace = "cloudflare";
        chart = kubenix.lib.helm.fetch {
          repo = "https://community-charts.github.io/helm-charts";
          chart = "cloudflared";
          version = "2.2.7";
          sha256 = "sha256-rIFTfA0qQxEQriSzZJ06ZOafg/ZHTM/DwPfRC4g0Zvc=";
        };
        values = {
          tunnelSecrets = {
            existingPemFileSecret.name = "cloudflared-cert-pem-file-secret";
            existingConfigJsonFileSecret.name = "cloudflared-config-json-file-secret";
          };
          tunnelConfig.name = domain;
          resources = {
            limits = {
              cpu = "500m";
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
    };
  };
}
