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
      options.hostSpec.networking.lan.enabled = lib.mkEnableOption "default lan configuration";

      config = lib.mkIf cfg.enabled {
        networking = let
          net = (lib.findFirst (m: m.name == config.networking.hostName) null machines).network;
          inherit (net.lan) ipv4 ipv6 interface;
        in {
          networkmanager.unmanaged = [interface];
          interfaces.${interface} = {
            useDHCP = true;
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

          defaultGateway = lib.mkForce {
            address = "192.168.1.254";
            inherit interface;
          };

          defaultGateway6 = lib.mkForce {
            address = "2600:1700:5e40:c2e0::1";
            inherit interface;
          };

          nameservers = lib.mkForce [
            "2606:4700:4700::1111"
            "1.1.1.1"
          ];
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

          defaultGateway = lib.mkDefault {
            address = "192.168.1.254";
            interface = net.wan.interface;
          };

          defaultGateway6 = lib.mkDefault {
            address = "2600:1700:5e40:c2e0::1";
            interface = net.wan.interface;
          };

          nameservers = lib.mkDefault [
            "2606:4700:4700::1111"
            "1.1.1.1"
          ];
        };
      };
    };
  };
}
