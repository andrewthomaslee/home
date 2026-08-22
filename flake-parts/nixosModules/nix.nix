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
      clan.core.vars.generators.github = {
        share = true;
        prompts.pat = {
          description = "GitHub personal access token (e.g. github_pat_...), configure with contents read only";
          type = "hidden";
        };
        files.access-tokens.secret = true;
        script = ''
          token=$(cat "$prompts/pat")
          # strip surrounding whitespace
          token=''${token#"''${token%%[![:space:]]*}"}
          token=''${token%"''${token##*[![:space:]]}"}
          if [ -z "$token" ]; then
            echo "GitHub token is empty" >&2
            exit 1
          fi
          printf 'access-tokens = github.com=%s\n' "$token" > "$out/token"
        '';
      };

      nix = {
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 180d";
        };

        extraOptions = ''
          !include ${config.clan.core.vars.generators.github.files.access-tokens.path}
        '';

        settings = {
          download-buffer-size = 524288000; # 500MB
          auto-optimise-store = true;
          trusted-users = ["root" "netsa"];
          allowed-users = ["@wheel" "root" "netsa" "wife"];

          auto-allocate-uids = true;
          system-features = ["uid-range"];

          experimental-features = [
            "nix-command"
            "flakes"
            "auto-allocate-uids"
            "cgroups"
          ];

          trusted-public-keys = [
            "nix-cache:4FILs79Adxn/798F8qk2PC1U8HaTlaPqptwNJrXNA1g="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
          ];

          extra-substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
            "https://cache.lounge.rocks/nix-cache"
          ];

          trusted-substituters = [
            "https://cache.nixos.org"
            "https://cache.lounge.rocks"
            "https://cache.flox.dev"
            "https://devenv.cachix.org"
            "https://cache.clan.lol"
          ];
        };
      };
    };
  };
}
