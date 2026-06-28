{...}: {
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

    services = {
      cloudflare-warp.enable = true;
      resolved = {
        enable = true;
        dnssec = "false"; # Disable DNSSEC
        dnstls = "false"; # Disable DNS-over-TLS
        extraConfig = ''
          ResolveUnicastSingleLabel=yes
        '';
      };
    };
    networking = {
      networkmanager.dns = "systemd-resolved";
      resolvconf.enable = false;
    };
  };
}
