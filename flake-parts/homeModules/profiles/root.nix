{self, ...}: {
  flake.homeModules.profile-root = {
    imports = [self.homeModules.default];
    config.homeSpec = {
      xdg.enable = true;
      programs = {
        shell.enable = true;
        ssh.enable = true;
        starship.enable = true;
        k9s.enable = true;
      };
    };
  };
}
