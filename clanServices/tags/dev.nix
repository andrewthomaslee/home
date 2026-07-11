{lib, ...}: {
  imports = [];
  config = {
    # hostSpec options
    hostSpec = {
      networking = {
        tailscale = {
          enable = true;
          systray = true;
        };
        services = {
          docker.enable = true;
          storagebox.enable = true;
          nix.enable = true;
        };
      };
    };

    # nixos options
    security.sudo.wheelNeedsPassword = false;
    boot.binfmt.emulatedSystems = ["aarch64-linux"];

    specialisation.warp.configuration = {
      hostSpec.networking = {
        tailscale = {
          enable = lib.mkForce false;
          systray = lib.mkForce false;
        };
        warp.enable = lib.mkForce true;
      };
    };
  };
}
