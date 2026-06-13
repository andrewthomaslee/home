{...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.flatpak = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.hostSpec.services.flatpak;
  in {
    options.hostSpec.services.flatpak.enable = lib.mkEnableOption "default flakpak configuration";

    config = lib.mkIf cfg.enable {
      services.flatpak.enable = true; # Enable Flatpak

      environment.systemPackages = with pkgs; [
        gnome-software # for flatpaks
      ];
    };
  };
}
