{
  self,
  inputs,
  ...
}: {
  # Terranix Main Entrypoint
  perSystem = {
    config,
    pkgs,
    customLib,
    inputs',
    self',
    ...
  }: let
    extraArgs = {inherit inputs self pkgs customLib inputs' self';};
    prefixText = ''
      export REPO_ROOT
      REPO_ROOT=$(git rev-parse --show-toplevel)
      export CLAN_DIR
      CLAN_DIR="$REPO_ROOT"

      eval "$(bunx varlock load --format shell --path "$REPO_ROOT"/.env)"
    '';
  in {
    terranix.terranixConfigurations.tofu = {
      modules = [self.terranixModules.tofu];
      inherit extraArgs;
      terraformWrapper = {
        inherit prefixText;
        package = pkgs.opentofu.withPlugins (p: [
          p.hashicorp_external
          p.hashicorp_tls
          p.hetznercloud_hcloud
          p.cloudflare_cloudflare
        ]);
        extraRuntimeInputs = with pkgs;
        with inputs'; [
          clan-core.packages.clan-cli
          self'.packages.get-keys
          git
          bun
        ];
      };
    };

    terranix.terranixConfigurations.cloudflare = {
      modules = [self.terranixModules.cloudflare];
      inherit extraArgs;
      terraformWrapper = {
        inherit prefixText;
        package = pkgs.opentofu.withPlugins (p: [
          p.cloudflare_cloudflare
        ]);
        extraRuntimeInputs = with pkgs; [
          git
          bun
        ];
      };
    };
  };
}
