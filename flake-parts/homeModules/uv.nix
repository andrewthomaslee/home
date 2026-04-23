{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.uv = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.uv;
  in {
    options.homeSpec.programs.uv.enable = lib.mkEnableOption "default uv configuration";
    config = lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        python314
      ];
      programs.uv = {
        enable = true;
        settings = {
          python-downloads = "never";
          python-preference = "only-system";
          link-mode = "copy";
        };
      };
    };
  };
}
