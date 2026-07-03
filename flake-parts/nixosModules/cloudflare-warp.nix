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
        networkmanager = {
          dns = "systemd-resolved";
          unmanaged = ["CloudflareWARP"];
        };
        resolvconf.enable = false;
      };
    };
  };
}
