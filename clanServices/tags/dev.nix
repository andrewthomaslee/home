{lib, ...}: {
  imports = [];
  config = {
    # hostSpec options
    hostSpec = {
      services = {
        docker.enable = true;
        storagebox.enable = true;
        nix.enable = true;
      };
    };

    # nixos options
    security.sudo.wheelNeedsPassword = false;
    boot.binfmt.emulatedSystems = ["aarch64-linux"];

    specialisation.tailscale.configuration = {
      hostSpec.networking = {
        tailscale = {
          enable = lib.mkForce true;
          systray = lib.mkForce true;
        };
        warp.enable = lib.mkForce false;
      };
    };
  };
}
