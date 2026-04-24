{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.tailscale = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.hostSpec.networking.tailscale;
  in {
    options.hostSpec.networking.tailscale = {
      enable = lib.mkEnableOption "default tailscale configuration";
      systray = lib.mkEnableOption "systray";
    };

    config = lib.mkIf cfg.enable {
      clan.core.vars.generators.tailscale = {
        share = true;
        prompts.auth_key.persist = true;
      };

      services.tailscale = {
        enable = true;
        package = pkgs.unstable.tailscale;
        openFirewall = true;
        authKeyFile = config.clan.core.vars.generators.tailscale.files.auth_key.path;
        authKeyParameters = {
          ephemeral = false;
          preauthorized = true;
        };
        useRoutingFeatures = "server";
        extraUpFlags = [
          "--advertise-exit-node"
          "--advertise-tags=tag:home"
        ];
      };
      networking = {
        networkmanager.unmanaged = ["tailscale0"];
        firewall = {
          trustedInterfaces = ["tailscale0"];
          checkReversePath = "loose";
        };
      };
      services.networkd-dispatcher = {
        enable = true;
        rules."50-tailscale" = {
          onState = ["routable"];
          script = ''
            #!${pkgs.runtimeShell}
            NETDEV=$(${pkgs.iproute2}/bin/ip -o route get 8.8.8.8 | cut -f 5 -d " ")
            ${pkgs.ethtool}/bin/ethtool -K "$NETDEV" rx-udp-gro-forwarding on rx-gro-list off
          '';
        };
      };

      systemd.services.tailscaled-autoconnect = {
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
          StartLimitIntervalSec = 0;
        };
        unitConfig = {
          StartLimitIntervalSec = 0; # Unlimited retries
        };
      };

      systemd.user.services.tailscale-systray = lib.mkIf cfg.systray {
        enable = true;
        description = "Tailscale Systray GUI";
        after = [
          "graphical-session.target"
          "tailscaled.service"
        ];
        wants = ["tailscaled.service"];
        wantedBy = ["graphical-session.target"];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStart = ''${pkgs.tailscale}/bin/tailscale systray'';
        };
      };
    };
  };
}
