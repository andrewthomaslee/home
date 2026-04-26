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
      home.packages = with pkgs; [
        devenv
      ];
      programs.direnv = {
        enable = true;
        package = pkgs.unstable.direnv;
        enableBashIntegration = true;
        nix-direnv.enable = true;
      };
    };
  };
}
