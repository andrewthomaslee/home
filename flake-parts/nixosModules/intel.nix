{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.intel = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.hostSpec.services.intel;
  in {
    options.hostSpec.services.intel.enable = lib.mkEnableOption "default intel configuration";

    config = lib.mkIf cfg.enable {
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-compute-runtime
        ];
      };
    };
  };
}
