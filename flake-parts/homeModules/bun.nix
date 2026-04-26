{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.bun = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.bun;
  in {
    options.homeSpec.programs.bun.enable = lib.mkEnableOption "default bun configuration";
    config = lib.mkIf cfg.enable {
      programs.bun = {
        enable = true;
        package = pkgs.unstable.bun;
        settings = {
          env = false;
          telemetry = false;
          install = {
            globalDir = "~/.bun/install/global";
            globalBinDir = "~/.bun/bin";
            linker = "isolated";
          };
        };
      };
    };
  };
}
