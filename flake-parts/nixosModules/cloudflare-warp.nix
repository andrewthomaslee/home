{lib, ...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.warp = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.hostSpec.networking.warp;
  in {
    options.hostSpec.networking.warp = {
      enable = lib.mkEnableOption "default warp configuration";
      headless = lib.mkEnableOption "headless login as a Mesh Node connector";
    };

    config = lib.mkIf cfg.enable {
      clan.core.vars.generators = lib.mkIf cfg.headless {
        cloudflare-warp = {
          prompts.token.persist = true;
        };
      };

      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
        "net.ipv6.conf.all.accept_ra" = 2;
      };
      services = {
        cloudflare-warp = {
          enable = true;
          package = pkgs.unstable.cloudflare-warp;
        };
        resolved = {
          enable = true;
          settings.Resolve = {
            DNSOverTLS = false;
            DNSSEC = false;
            ResolveUnicastSingleLabel = true;
            DNS =
              if cfg.headless
              then [
                "1.1.1.1"
              ]
              else [
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
        firewall.trustedInterfaces = ["CloudflareWARP"];
      };
      systemd.network.config.networkConfig = {
        ManageForeignRoutes = false;
        ManageForeignRoutingPolicyRules = false;
      };
      systemd.services = lib.mkIf cfg.headless {
        cloudflare-warp-connector = {
          description = "Register Cloudflare WARP Mesh Node Connector";
          after = ["cloudflare-warp.service" "network-online.target"];
          wants = ["network-online.target"];
          requires = ["cloudflare-warp.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = let
            warpCli = "${config.services.cloudflare-warp.package}/bin/warp-cli";
          in ''
            TOKEN_FILE="${config.clan.core.vars.generators.cloudflare-warp.files.token.path}"

            if [[ -s "$TOKEN_FILE" ]]; then
              echo "Waiting for Cloudflare WARP daemon to be ready..."
              for i in {1..15}; do
                if ${warpCli} --accept-tos status >/dev/null 2>&1; then
                  break
                fi
                sleep 1
              done

              # 1. Clean up lingering mdm.xml if any exists
              if [[ -f /var/lib/cloudflare-warp/mdm.xml ]]; then
                echo "Found lingering mdm.xml. Removing..."
                rm -f /var/lib/cloudflare-warp/mdm.xml
                ${warpCli} --accept-tos disconnect || true
                ${warpCli} --accept-tos registration delete || true
              fi

              # 2. Check if registered, but NOT as a Mesh Connector (TunnelOnly)
              if ${warpCli} --accept-tos registration show | grep -q "Account type"; then
                if ! ${warpCli} --accept-tos settings | grep -q "Mode: TunnelOnly"; then
                  echo "Detected standard client registration (not in TunnelOnly mode). Clearing registration..."
                  ${warpCli} --accept-tos disconnect || true
                  ${warpCli} --accept-tos registration delete || true
                fi
              fi

              # 3. Perform registration if we cleared it above or if it is a clean slate
              if ! ${warpCli} --accept-tos registration show | grep -q "Account type"; then
                echo "Registering Cloudflare Mesh Node..."
                ${warpCli} --accept-tos connector new "$(cat "$TOKEN_FILE")"
                ${warpCli} --accept-tos connect
              else
                # Make sure the connector is actually connected
                if ${warpCli} --accept-tos status | grep -q "Disconnected"; then
                  echo "Mesh Node is registered but disconnected. Connecting..."
                  ${warpCli} --accept-tos connect
                else
                  echo "Cloudflare Mesh Node is already registered and active."
                fi
              fi
            else
              echo "Mesh Node token not found or empty at $TOKEN_FILE"
            fi
          '';
        };
      };
    };
  };
}
