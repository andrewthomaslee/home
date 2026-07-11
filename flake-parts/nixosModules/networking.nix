{lib, ...}: let
  relativeToRoot = lib.path.append ../../.;
  machines = (builtins.fromJSON (builtins.readFile (relativeToRoot "machines.json"))).machines;
in {
  # ------ NixOS Modules ------ #
  flake.nixosModules = {
    lan = {
      config,
      customLib,
      ...
    }: let
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
    wan = {
      config,
      customLib,
      ...
    }: let
      cfg = config.hostSpec.networking.wan;
    in {
      options.hostSpec.networking.wan.enabled = lib.mkEnableOption "default wan configuration";

      config = lib.mkIf cfg.enabled {
        networking = let
          net = (lib.findFirst (m: m.name == (config.networking.hostName)) null machines).network;
        in {
          networkmanager.enable = lib.mkDefault true;
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
