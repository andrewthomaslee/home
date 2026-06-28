{lib, ...}: {
  imports = [];
  config = {
    # hostSpec options
    hostSpec = {
      networking.tailscale = {
        enable = lib.mkForce false;
        systray = lib.mkForce false;
      };
      services = {
        docker.enable = true;
        storagebox.enable = true;
        nix.enable = true;
      };
    };

    # nixos options
    security.sudo.wheelNeedsPassword = false;
    boot.binfmt.emulatedSystems = ["aarch64-linux"];

    services = {
      cloudflare-warp.enable = true;
      resolved = {
        enable = true;
        settings.Resolve = {
          DNSOverTLS = false;
          DNSSEC = false;
        };
      };
    };
    networking = {
      networkmanager.dns = "systemd-resolved";
      resolvconf.enable = false;
    };
  };
}
