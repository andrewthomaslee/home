{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    self',
    inputs',
    ...
  }:
    with pkgs.unstable; let
      inherit (pkgs.unstable) lib;
      inherit (self'.packages) tofu;

      apply-tofu-pkg = writeShellApplication {
        name = "apply-tofu";
        runtimeInputs = [
          inputs'.clan-core.packages.clan-cli
          self'.packages.get-keys
          bun
          (opentofu.withPlugins (p: [
            p.hashicorp_external
            p.hashicorp_tls
            p.hetznercloud_hcloud
            p.cloudflare_cloudflare
          ]))
        ];
        text = ''
          if [ "$#" -ne 1 ]; then
            echo "Usage: apply-tofu <repo-root>" >&2
            exit 1
          fi

          REPO_ROOT="$1"

          if [ ! -d "$REPO_ROOT" ]; then
            echo "Error: REPO_ROOT directory not found: $REPO_ROOT" >&2
            exit 1
          fi

          export REPO_ROOT
          export CLAN_DIR
          CLAN_DIR="$REPO_ROOT"

          BACKEND_CONFIG="$REPO_ROOT/backend.tfbackend"

          if [ ! -f "$BACKEND_CONFIG" ]; then
            echo "Error: backend config file not found: $BACKEND_CONFIG" >&2
            exit 1
          fi

          eval "$(bunx varlock load --format shell --path "$REPO_ROOT"/.env)"

          cp ${tofu.config} "$REPO_ROOT/config.tf.json"

          cd "$REPO_ROOT"

          tofu init -reconfigure -backend-config="$BACKEND_CONFIG"
          tofu apply
        '';
      };
    in {
      packages.apply-tofu = apply-tofu-pkg;
      apps.apply-tofu = {
        type = "app";
        program = lib.getExe apply-tofu-pkg;
        meta = {
          mainProgram = "apply-tofu";
          description = "Apply OpenTofu configuration using a backend.tfbackend file";
        };
      };
    };
}
