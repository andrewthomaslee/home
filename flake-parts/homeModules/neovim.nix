{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.neovim = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.neovim;
  in {
    options.homeSpec.programs.neovim.enable = lib.mkEnableOption "default neovim configuration";
    config = lib.mkIf cfg.enable {
      programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
        defaultEditor = true;
      };
    };
  };
}
