{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.opencode = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.opencode;
  in {
    options.homeSpec.programs.opencode.enable = lib.mkEnableOption "default opencode configuration";
    config = lib.mkIf cfg.enable {
      programs.opencode = {
        enable = true;
        package = pkgs.unstable.opencode;
        extraPackages = with pkgs.unstable; [
          uv
          nix
        ];
      };
    };
  };
}
