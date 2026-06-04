{lib, ...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.longhorn = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.hostSpec.services.longhorn;
  in {
    options.hostSpec.services.longhorn.enable = lib.mkEnableOption "default longhorn configuration";

    config = lib.mkIf cfg.enable {
      # nixos config for longhorn
      services.openiscsi = {
        enable = true;
        name = "iqn.2016-04.com.open-iscsi:${config.networking.hostName}";
      };
      environment.systemPackages = with pkgs; [
        cifs-utils
        nfs-utils
        gzip
      ];
      systemd.tmpfiles.rules = [
        "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
      ];
      boot.kernelModules = ["dm_crypt"];

      services.rke2.nodeLabel = ["storage=longhorn" "longhorn=true"];
      services.k3s.nodeLabel = ["storage=longhorn" "longhorn=true"];
    };
  };
}
