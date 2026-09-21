{lib, ...}: let
  relativeToRoot = lib.path.append ../../.;
  inherit ((builtins.fromJSON (builtins.readFile (relativeToRoot "machines.json")))) machines;
in {
  # ------ NixOS Modules ------ #
  flake.nixosModules = {
    lan = {config, ...}: let
      cfg = config.hostSpec.networking.lan;
    in {
      options.hostSpec.networking.lan = {
        enabled = lib.mkEnableOption "default lan configuration";
        defaultGateway = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.254";
        };
        defaultGateway6 = lib.mkOption {
          type = lib.types.str;
          default = "2600:1700:5e40:c2e0::1";
        };
      };

      config = lib.mkIf cfg.enabled {
        networking = let
          net = (lib.findFirst (m: m.name == config.networking.hostName) null machines).network;
          inherit (net.lan) ipv4 ipv6 interface;
        in {
          # networkmanager.unmanaged = [interface];
          interfaces.${interface} = {
            useDHCP = false;
            ipv4.addresses = [
              {
                address = ipv4;
                prefixLength = 24;
              }
            ];
            ipv6.addresses = [
              {
                address = ipv6;
                prefixLength = 64;
              }
            ];
          };

          defaultGateway = {
            address = lib.mkForce cfg.defaultGateway;
            interface = lib.mkForce interface;
          };

          defaultGateway6 = {
            address = lib.mkForce cfg.defaultGateway6;
            interface = lib.mkForce interface;
          };
        };
      };
    };
    wan = {config, ...}: let
      cfg = config.hostSpec.networking.wan;
    in {
      options.hostSpec.networking.wan.enabled = lib.mkEnableOption "default wan configuration";

      config = lib.mkIf cfg.enabled {
        # TCP + WiFi tuning for lossy, long-RTT WAN links (e.g. Dallas ->
        # Helsinki): CUBIC collapses to ~300 KB/s under ~2% loss at 160 ms
        # RTT while BBR holds the uplink cap. NOTE: machines.json still has
        # kamrui-h1's old interface name (wlp0s20f3 vs live wlp2s0) — NM owns
        # the real NIC so the interfaces stanza below is inert there; fixing
        # the name would require networkmanager.unmanaged to keep NM in
        # charge.
        boot = {
          kernel.sysctl = {
            "net.ipv4.tcp_congestion_control" = "bbr";
            "net.core.default_qdisc" = "fq";
            "net.core.wmem_max" = 16777216;
            "net.ipv4.tcp_wmem" = "4096 65536 16777216";
          };
          kernelModules = ["tcp_bbr"];
          # Verified against the running kernel's modules (modinfo):
          # rtw89_core.disable_ps_mode + rtw89_pci.{disable_clkreq,
          # disable_aspm_l1} — kills WiFi power-save / PCIe PM latency
          # spikes; inert on machines without the rtw89 driver.
          extraModprobeConfig = ''
            options rtw89_core disable_ps_mode=Y
            options rtw89_pci disable_clkreq=Y disable_aspm_l1=Y
          '';
        };

        networking = let
          net = (lib.findFirst (m: m.name == config.networking.hostName) null machines).network;
        in {
          networkmanager.enable = lib.mkDefault true;
          networkmanager.wifi.powersave = lib.mkDefault false;
          interfaces.${net.wan.interface} = {
            useDHCP = true;
            # ipv4.addresses = [
            #   {
            #     address = net.wan.ipv4;
            #     prefixLength = 24;
            #   }
            # ];
            # ipv6.addresses = [
            #   {
            #     address = net.wan.ipv6;
            #     prefixLength = 64;
            #   }
            # ];
          };

          defaultGateway = {
            address = lib.mkDefault "192.168.1.254";
            interface = lib.mkDefault net.wan.interface;
          };

          defaultGateway6 = {
            address = lib.mkDefault "2600:1700:5e40:c2e0::1";
            interface = lib.mkDefault net.wan.interface;
          };
        };
      };
    };
  };
}
