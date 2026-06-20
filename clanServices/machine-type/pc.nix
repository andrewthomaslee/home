{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];
  config = {
    # --- hostSpec options --- #
    hostSpec = {
      networking.tailscale.systray = true;
      hardware = {
        bluetooth.enable = true;
        sound.enable = true;
      };
      services = {
        kde.enable = true;
        wayland.enable = true;
      };
    };
    environment.systemPackages = with pkgs;
    with kdePackages; [
      video-downloader # download youtube videos
      libreoffice-qt-fresh # Comprehensive, professional-quality productivity suite, a variant of openoffice.org
      haruna # Open source video player built with Qt/QML and libmpv
      krunner
      kate # text editor
      kcharselect # Tool to select and copy special characters from all installed fonts
      kcolorchooser # A small utility to select a color
      kolourpaint # Easy-to-use paint program
      ktorrent # Powerful BitTorrent client
      filelight # disk usage analyzer
      kalk # Calculator
      xclip # Tool to access the X clipboard from a console application
      zen-browser
      discord
      spotify
      prismlauncher
      tor-browser
      obsidian
      mediawriter
    ];
  };
}
