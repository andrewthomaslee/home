{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.clan = {config, ...}: let
    cfg = config.hostSpec.clan;
  in {
    options.hostSpec.clan.enable = lib.mkEnableOption "default clan configuration";

    config = lib.mkIf cfg.enable {
      clan.core = {
        # Require explicit updates
        deployment.requireExplicitUpdate = lib.mkDefault true;
        # Enable state versioning
        settings.state-version.enable = true;
      };
    };
  };
}
