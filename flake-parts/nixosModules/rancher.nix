{lib, ...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.rancher = {config, ...}: let
    cfg = config.hostSpec.services.rancher;
  in {
    options.hostSpec.services.rancher.enable = lib.mkEnableOption "default rancher configuration";
    config = lib.mkIf cfg.enable {
      services.k3s.disable = ["local-storage"];
    };
  };
}
