{self, ...}: {
  # For Andrew's PCs
  flake.homeModules.profile-netsa = {pkgs, ...}: {
    imports = [self.homeModules.default];
    config = {
      # homeSpec options
      homeSpec = {
        xdg.enable = true;
        # AI coding agents: the shared repo skill set (skills/ merged via
        # inputs.agents.lib.mkSkills) is wired into every enabled agent.
        agents = {
          skills.enabled = true;
          opencode.enabled = true;
          kimi.enabled = true;
          pi.enabled = true;
          claude.enabled = true;
        };
        programs = {
          plasma-manager.enable = true;
          docker.enable = true;
          devenv.enabled = true;
          firefox.enable = true;
          ghostty.enable = true;
          git.enable = true;
          k9s.enable = true;
          ksshaskpass.enable = true;
          media.enable = true;
          password-store.enable = true;
          shell.enable = true;
          ssh.enable = true;
          starship.enable = true;
          vscode.enable = true;
          openshell.enable = true;
        };
      };
      # Home Options
      home.packages = with pkgs; [
        moscripts
        asciinema
        kalker
        freelens-bin
        gh
      ];
    };
  };
}
