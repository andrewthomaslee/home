{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.networking = {config, ...}: let
    cfg = config.hostSpec.networking;
  in {
    options.hostSpec.networking.enable = lib.mkEnableOption "default networking configuration";

    config = lib.mkIf cfg.enable {
      networking = {
        useDHCP = true;
        networkmanager.enable = true;
      };
    };
  };
}
