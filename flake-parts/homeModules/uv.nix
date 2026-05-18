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
      home = {
        packages = [pkgs.python3-wrapped];
        sessionVariables.UV_PYTHON = "${pkgs.python3-wrapped}/bin/python";
      };
      programs.uv = {
        enable = true;
        package = pkgs.unstable.uv;
        settings = {
          python-downloads = "never";
          python-preference = "only-system";
          link-mode = "copy";
        };
      };
    };
  };
}
