{self, ...}: {
  # Headless AI agent profile based on netsa user configuration
  # Tailored for KubeVirt spawnable AI agent VMs with developer toolings
  # and Headroom + OpenCode web/proxy implementation.
  flake.homeModules.profile-netsa-agent = {pkgs, ...}: {
    imports = [self.homeModules.default];
    config = {
      # homeSpec options
      homeSpec = {
        xdg.enable = true;
        programs = {
          # Headless developer toolings
          tmux.enable = true;
          bun.enable = true;
          direnv.enable = true;
          docker.enable = true;
          git.enable = true;
          go.enable = true;
          k9s.enable = true;
          neovim.enable = true;
          password-store.enable = true;
          shell.enable = true;
          ssh.enable = true;
          starship.enable = true;
          uv.enable = true;

          # AI Agent stack: Headroom context optimizer + OpenCode
          headroom = {
            enable = true;
            # Slim build: proxy + MCP compress/retrieve only (~1 GB closure
            # vs 4 GB full). memory/learn/image features are disabled anyway.
            package = pkgs.headroom-slim;
            proxy = {
              enable = true;
              # memory/learn pull embedding models at startup, which blocks
              # on a HF download in a fresh HOME (spawnable VMs boot offline).
              memory = false;
              learn = false;
            };
          };
          opencode = {
            enable = true;
            # Headless: no Electron desktop app, no k3s/rke2/devcontainer
            # heavy toolset. Keeps docker, kubectl, helm, k9s, bun, go, uv.
            enableDesktop = false;
            fullDevTools = false;
          };

          # Explicitly disable desktop/GUI toolings in headless agent profile
          plasma-manager.enable = false;
          firefox.enable = false;
          ghostty.enable = false;
          vscode.enable = false;
          media.enable = false;
          ksshaskpass.enable = false;
        };
      };

      # Home Packages (Headless CLI tools)
      home.packages = with pkgs;
        [
          moscripts
          kubefetch
          curl
          jq
          ripgrep
          fd
          python3
        ]
        ++ (with pkgs.unstable; [
          asciinema
          kalker
          lazyssh
          lazyjournal
        ]);
    };
  };
}
