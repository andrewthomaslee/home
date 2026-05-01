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
        extraOptions = ''
          !include ${config.clan.core.vars.generators."nix".files."nix-access-tokens".path}
        '';

        settings = {
          trusted-users = ["root"];
          allowed-users = ["root"];
        };
      };
    };
  };
}
