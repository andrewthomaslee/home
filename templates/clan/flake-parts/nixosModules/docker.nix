{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.docker = {config, ...}: let
    cfg = config.hostSpec.services.docker;
  in {
    options.hostSpec.services.docker.enable = lib.mkEnableOption "default docker configuration";

    config = lib.mkIf cfg.enable {
      virtualisation = {
        oci-containers.backend = "docker";
        docker = {
          enable = true;
          logDriver = "json-file";
          daemon.settings = {
            fixed-cidr-v6 = "fd77:7777:7777::/48";
            ipv6 = true;
          };
          autoPrune.enable = true;
        };
      };
    };
  };
}
