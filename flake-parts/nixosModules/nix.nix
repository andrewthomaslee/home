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
      clan.core.vars.generators."nix" = {
        prompts.nix-access-tokens.persist = true;
        share = true;
      };

      nix = {
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };

        extraOptions = ''
          !include ${config.clan.core.vars.generators."nix".files."nix-access-tokens".path}
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

          substituters = [
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
