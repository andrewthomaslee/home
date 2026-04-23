{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.go = {config, ...}: let
    cfg = config.homeSpec.programs.go;
  in {
    options.homeSpec.programs.go.enable = lib.mkEnableOption "default go configuration";
    config = lib.mkIf cfg.enable {
      home.sessionVariables.GOPATH = "/home/${config.home.username}/.go";
      programs.go = {
        enable = true;
        env.GOPATH = "/home/${config.home.username}/.go";
      };
    };
  };
}
