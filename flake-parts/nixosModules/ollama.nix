{...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.ollama = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.hostSpec.services.ollama;
  in {
    options.hostSpec.services.ollama = {
      enable = lib.mkEnableOption "default ollama configuration";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ollama;
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 11434;
      };
      loadModels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };

    config = lib.mkIf cfg.enable {
      services.ollama = {
        enable = true;
        package = cfg.package;
        openFirewall = true;
        syncModels = true;
        port = cfg.port;
        loadModels = cfg.loadModels;
      };
    };
  };
}
