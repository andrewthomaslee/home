_: {
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
        default =
          if config.hostSpec.hardware.gpu.amd.enable
          then pkgs.unstable.ollama-vulkan
          else pkgs.unstable.ollama;
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
        user = "ollama";
        group = "ollama";
        inherit (cfg) package;
        openFirewall = true;
        syncModels = true;
        inherit (cfg) port;
        inherit (cfg) loadModels;
      };

      users.users.ollama.extraGroups = ["video"];
    };
  };
}
