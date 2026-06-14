{self, ...}: {
  flake.homeModules.profile-wife = {pkgs, ...}: {
    imports = [self.homeModules.default];
    config = {
      # homeSpec options
      homeSpec = {
        xdg.enable = true;
        programs = {
          plasma-manager.enable = true;
          firefox.enable = true;
          media.enable = true;
        };
      };

      # Home Options
      home.packages = with pkgs; [
        zen-browser
        discord
        spotify
        prismlauncher
      ];
    };
  };
}
