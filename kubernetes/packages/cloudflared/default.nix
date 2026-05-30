{
  pkgs,
  # config,
  kubenix,
  ...
}: let
  kubeVersion = builtins.substring 0 4 "${pkgs.k3s.version}";
  domain = "domain.com";
in {
  imports = [
    kubenix.modules.k8s
    kubenix.modules.helm
  ];

  kubenix.project = "cloudflared";
  kubernetes = {
    version = kubeVersion;
    namespace = "cloudflare";
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
          nodeSelector.web = "true";
          tunnelSecrets = {
            existingPemFileSecret = {
              name = "cloudflared-cert";
              key = "cert.pem";
            };
            existingConfigJsonFileSecret = {
              name = "cloudflared-credentials";
              key = "credentials.json";
            };
          };
          tunnelConfig.name = domain;
          resources = {
            limits = {
              cpu = "500m";
              memory = "256Mi";
            };
            requests = {
              cpu = "1m";
              memory = "4Mi";
            };
          };
          # cloudflared tunnel route dns home <domain>.andrewlee.fun
          ingress = [
            {
              service = "http_status:404"; # MUST GO LAST
            }
          ];
        };
      };
    };
  };
}
