{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.nix = {config, ...}: let
    cfg = config.hostSpec.services.nix;
  in {
    options.hostSpec.services.nix.enable = lib.mkEnableOption "default nix configuration";

    config = lib.mkIf cfg.enable {
      # github PAT for private repos
      # Per-service generators (nix-github, nix-gitlab, etc.) each collect
      # one host's token. When adding a second host, create a collector
      # generator that depends on all service generators and concatenates
      # their fragments into a single `access-tokens = ` line (nix.conf
      # does not accumulate duplicate keys across !include files).
      clan.core.vars.generators."nix-github" = {
        prompts.token = {
          description = "GitHub personal access token (e.g. github_pat_...)";
          type = "hidden";
        };
        files.nix-access-tokens.secret = true;
        script = ''
          token=$(cat "$prompts/token")
          # strip surrounding whitespace
          token=''${token#"''${token%%[![:space:]]*}"}
          token=''${token%"''${token##*[![:space:]]}"}
          if [ -z "$token" ]; then
            echo "GitHub token is empty" >&2
            exit 1
          fi
          printf 'access-tokens = github.com=%s\n' "$token" > "$out/nix-access-tokens"
        '';
        share = true;
      };

      nix = {
        extraOptions = ''
          !include ${config.clan.core.vars.generators."nix-github".files."nix-access-tokens".path}
        '';

        settings = {
          trusted-users = ["root"];
          allowed-users = ["root"];
        };
      };
    };
  };
}
