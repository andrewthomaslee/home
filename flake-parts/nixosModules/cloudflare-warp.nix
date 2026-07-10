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
      headless = lib.mkEnableOption "headless login";
      secretsPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/run/secrets/vars/cloudflare-warp";
        description = "Directory containing the 'id', 'token', and 'org' files for headless login";
      };
    };

    config = lib.mkIf cfg.enable {
      clan.core.vars.generators = lib.mkIf cfg.headless {
        cloudflare-warp = {
          share = true;
          prompts = {
            id = {};
            org = {};
            token = {};
          };
          files."creds.xml" = {};
          script = ''
            cat > $out/creds.xml <<EOF
            <dict>
              <key>organization</key>
              <string>$(cat $prompts/org)</string>
              <key>auth_client_id</key>
              <string>$(cat $prompts/id)</string>
              <key>auth_client_secret</key>
              <string>$(cat $prompts/token)</string>
              <key>auto_connect</key>
              <integer>1</integer>
              <key>service_mode</key>
              <string>warp</string>
              <key>onboarding</key>
              <false/>
            </dict>
            EOF
          '';
        };
      };
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
        ManageForeignRoutes = false;
        ManageForeignRoutingPolicyRules = false;
      };
      systemd.services = lib.mkIf cfg.headless {
        cloudflare-warp = {
          preStart = ''
            CRED_FILE="${cfg.secretsPath}/creds.xml"
            MDM_FILE="/var/lib/cloudflare-warp/mdm.xml"

            # Ensure the configuration directory exists
            mkdir -p /var/lib/cloudflare-warp
            cp "$CRED_FILE" "$MDM_FILE"

            # Check if the secret files exist and are not empty
            if [[ -s "$MDM_FILE" ]]; then
              echo "Found Cloudflare WARP credentials. Generating mdm.xml..."
              chmod 0600 "$MDM_FILE"
            else
              echo "WARP credentials missing or empty in ${cfg.secretsPath}. Skipping MDM config generation."
              # Remove any stale MDM configs if secrets are removed to prevent unintended logins
              rm -f "$MDM_FILE"
            fi
          '';
        };
      };
    };
  };
}
