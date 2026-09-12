{lib, ...}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.headroom = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.headroom;
  in {
    options.homeSpec.programs.headroom = {
      enable = lib.mkEnableOption "headroom context compression layer";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.headroom;
        defaultText = lib.literalExpression "pkgs.headroom";
        description = "The headroom package to install.";
      };
      proxy = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to run headroom proxy as a systemd user service.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8787;
          description = "Port to run the headroom proxy server on.";
        };
        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Host to bind the headroom proxy server to.";
        };
        mode = lib.mkOption {
          type = lib.types.enum ["cache" "token"];
          default = "cache";
          description = "Optimization mode: 'cache' (preserves prompt-caching prefix) or 'token' (aggressive rewrite).";
        };
        memory = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable persistent cross-session memory.";
        };
        learn = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable live traffic learning.";
        };
        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Extra command-line arguments to pass to 'headroom proxy'.";
        };
      };
    };

    config = lib.mkIf cfg.enable {
      home.packages = [cfg.package];

      # When opencode is also enabled, surface headroom on its PATH
      programs.opencode = lib.mkIf (config.programs.opencode.enable or false) {
        extraPackages = [cfg.package];
      };

      systemd.user.services.headroom-proxy = lib.mkIf cfg.proxy.enable {
        Unit = {
          Description = "Headroom Context Optimization Proxy";
          After = ["network.target"];
        };
        Install = {
          WantedBy = ["default.target"];
        };
        Service = {
          Type = "simple";
          Restart = "always";
          RestartSec = "3s";
          ExecStart = lib.concatStringsSep " " ([
              "${lib.getExe cfg.package}"
              "proxy"
              "--host"
              cfg.proxy.host
              "--port"
              (toString cfg.proxy.port)
              "--mode"
              cfg.proxy.mode
            ]
            ++ lib.optional cfg.proxy.memory "--memory"
            ++ lib.optional cfg.proxy.learn "--learn"
            ++ cfg.proxy.extraArgs);
        };
      };
    };
  };
}
