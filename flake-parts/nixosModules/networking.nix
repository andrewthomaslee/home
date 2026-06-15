{lib, ...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.networking = {
    config,
    customLib,
    ...
  }: let
    cfg = config.hostSpec.networking;
    inherit (customLib.custom) relativeToRoot;
  in {
    options.hostSpec.networking = {
      enable = lib.mkEnableOption "default networking configuration";
      file = lib.mkOption {
        type = lib.types.path;
        default = relativeToRoot "machines.json";
        description = "The network file";
      };
      machines = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = (builtins.fromJSON (builtins.readFile cfg.file)).machines;
        description = "Network configuration";
      };
    };

    config = lib.mkIf cfg.enable {
      networking = let
        hostname = config.networking.hostName;
        net = (lib.findFirst (m: m.name == hostname) null cfg.machines).network;
      in {
        networkmanager.enable = true;
        interfaces. ${net.interface} = {
          useDHCP = net.type != "lan";
          ipv4.addresses = [
            {
              address = net.ipv4;
              prefixLength = 24;
            }
          ];
          ipv6.addresses = [
            {
              address = net.ipv6;
              prefixLength = 64;
            }
          ];
        };

        defaultGateway = {
          address = "192.168.1.254";
          interface = net.interface;
        };

        defaultGateway6 = {
          address = "2600:1700:5e40:c2e0::1";
          interface = net.interface;
        };

        nameservers = [
          "1.1.1.1"
          "2606:4700:4700::1111"
        ];
      };
    };
  };
}
