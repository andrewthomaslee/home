{lib, ...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.warp = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.hostSpec.networking.warp;
  in {
    options.hostSpec.networking.warp.enable = lib.mkEnableOption "default warp configuration";

    config = lib.mkIf cfg.enable {
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
        "net.ipv6.conf.all.accept_ra" = 2;
      };
      services = {
        cloudflare-warp.enable = true;
        resolved = {
          enable = true;
          settings.Resolve = {
            LLMNR = false;
            MulticastDNS = false;
            DNSOverTLS = false;
            DNSSEC = false;
            ResolveUnicastSingleLabel = true;
            DNS = [
              "127.0.2.2"
              "127.0.2.3"
              "fd01:db8:1111::2"
              "fd01:db8:1111::3"
            ];
          };
        };
      };
      networking = {
        networkmanager = {
          dns = "systemd-resolved";
          unmanaged = ["CloudflareWARP"];
        };
        resolvconf.enable = false;
      };
      systemd.network.config.networkConfig = {
        # This prevents systemd-networkd from deleting WARP's custom ip rules and tables.
        ManageForeignRoutes = false;
        ManageForeignRoutingPolicyRules = false;
      };
    };
  };
}
