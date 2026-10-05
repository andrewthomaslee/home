{lib, ...}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.kimi-code = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.kimi-code;
  in {
    options.homeSpec.programs.kimi-code = {
      enable = lib.mkEnableOption "the Kimi Code CLI (MoonshotAI)";
      # Package comes from numtide/llm-agents.nix via overlays/default.nix
      # (from-source pnpm build, binary `kimi`, auto-update disabled by the
      # wrapper). Overridable so a caller can pin another build.
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kimi-code;
        defaultText = lib.literalExpression "pkgs.kimi-code";
        description = "The kimi-code package to install.";
      };
    };
    config = lib.mkIf cfg.enable {
      # The CLI is self-contained: it is logged in interactively with
      # `/login` and its MCP servers configured with `/mcp-config`, so
      # there is no declarative config file to render here yet (its state
      # lives under the user's home). Add an xdg.configFile block here if
      # an upstream config format stabilizes.
      home.packages = [cfg.package];
    };
  };
}
