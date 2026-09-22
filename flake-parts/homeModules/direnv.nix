{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.direnv = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.direnv;
  in {
    options.homeSpec.programs.direnv.enable = lib.mkEnableOption "default direnv configuration";
    config = lib.mkIf cfg.enable {
      # devenv the CLI is NOT installed here — it has its own module
      # (homeModules/devenv.nix) so the flake-package source stays in one
      # place; direnv only wires the shell integration (nix-direnv).
      programs.direnv = {
        enable = true;
        package = pkgs.unstable.direnv;
        enableBashIntegration = true;
        nix-direnv.enable = true;
      };
    };
  };
}
