{inputs, ...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.jovian = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.hostSpec.hardware.jovian;
  in {
    options.hostSpec.hardware.jovian = {
      enable = lib.mkEnableOption "default jovian configuration";
      steamui = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable steam big picture mode";
        example = true;
      };
      amd = lib.mkOption {
        type = lib.types.bool;
        default = config.hostSpec.hardware.amd.enable or false;
        description = "has amd";
        example = true;
      };
    };

    imports = [
      inputs.jovian.nixosModules.default
    ];

    config = lib.mkIf cfg.enable {
      jovian = {
        hardware.has.amd.gpu = cfg.amd;
        steam.enable = cfg.steamui;
      };
      services.orca.enable = false; # Disable screen reader
      networking.networkmanager.enable = lib.mkForce true; # Steam UI needs networkmanager
    };
  };
}
