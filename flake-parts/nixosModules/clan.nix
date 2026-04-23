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
        # Default to deploying to root@hostName
        networking.targetHost = lib.mkDefault "root@${config.networking.hostName}";
        # Require explicit updates
        deployment.requireExplicitUpdate = lib.mkDefault true;
        # Enable state versioning
        settings.state-version.enable = true;
      };
    };
  };
}
