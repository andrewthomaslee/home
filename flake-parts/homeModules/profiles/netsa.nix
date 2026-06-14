{self, ...}: {
  # For Andrew's PCs
  flake.homeModules.profile-netsa = {pkgs, ...}: {
    imports = [self.homeModules.default];
    config = {
      # homeSpec options
      homeSpec = {
        xdg.enable = true;
        programs = {
          plasma-manager.enable = true;
          tmux.enable = true;
          bun.enable = true;
          direnv.enable = true;
          docker.enable = true;
          firefox.enable = true;
          ghostty.enable = true;
          git.enable = true;
          go.enable = true;
          k9s.enable = true;
          ksshaskpass.enable = true;
          media.enable = true;
          neovim.enable = true;
          password-store.enable = true;
          shell.enable = true;
          ssh.enable = true;
          starship.enable = true;
          uv.enable = true;
          vscode.enable = true;
        };
      };
      # Home Options
      home.packages = with pkgs;
        [
          zen-browser
          moscripts
          kubefetch
        ]
        ++ (with pkgs.unstable; [
          obsidian
          asciinema
          prismlauncher
          tor-browser
          kalker
          lazyssh
          lazyjournal
          jq
          yq
          httpie
          mediawriter
          fastfetch
        ]);
    };
  };
}
