{lib, ...}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.plasma-manager = {
    pkgs,
    config,
    osConfig,
    ...
  }: let
    cfg = config.homeSpec.programs.plasma-manager;
  in {
    options.homeSpec.programs.plasma-manager.enable = lib.mkEnableOption "default plasma-manager configuration";
    config = lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        bibata-cursors
        bibata-cursors-translucent
        papirus-icon-theme
        tela-circle-icon-theme
        colloid-icon-theme
        klassy
        darkly
      ];

      # programs.plasma = lib.optionalAttrs osConfig.services.desktopManager.plasma6.enable {
      #   enable = true;
      #   workspace = {
      #     lookAndFeel = "org.kde.breezedark.desktop";
      #     cursor.theme = "Bibata-Modern-Ice";
      #   };
      #   hotkeys.commands."launch-kalk" = {
      #     name = "Launch Konsole";
      #     key = "Meta+Alt+K";
      #     command = "kalk";
      #   };
      # };
    };
  };
}
