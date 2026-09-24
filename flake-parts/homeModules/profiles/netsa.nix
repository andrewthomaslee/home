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
          devenv = {
            # devenv CLI (flake package) + 2.x native auto-activation hook
            enabled = true;
            autoActivate.enabled = true;
          };
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
          opencode = {
            enable = true;
            mcp = {
              # Dev-profile opt-ins (off by module default)
              typeui.enable = true;
              # GitHub MCP via the clan-var PAT method; the "github-mcp"
              # generator + sops deployment is derived automatically by
              # nixosModules/github-mcp. Provision with:
              #   clan vars set github-mcp pat <machine>
              github.auth = "pat";
              # Cloudflare remote MCP servers
              cloudflare.enable = true;
              cloudflare-docs.enable = true;
              cloudflare-bindings.enable = true;
              cloudflare-builds.enable = true;
              cloudflare-browser.enable = true;
              cloudflare-containers.enable = true;
              # MDN Web Docs
              mdn.enable = true;
              # ArtifactHub (Helm charts)
              artifacthub.enable = true;
              # Kubernetes MCP — exits without a kubeconfig, so the module
              # default is off; dev machines provision one.
              kubernetes.enable = true;
              # devenv MCP (search nixpkgs packages + devenv options)
              devenv.enable = true;
              # Varlock docs (search varlock.dev docs)
              varlock-docs.enable = true;
            };
            # Dev-profile plugins (off by module default)
            plugins = {
              opencode-mem.enable = true;
              devcontainers.enable = true;
            };
          };
          headroom.enable = true;
        };
      };
      # Home Options
      home.packages = with pkgs;
        [
          moscripts
          kubefetch
        ]
        ++ (with pkgs.unstable; [
          asciinema
          kalker
          lazyssh
          lazyjournal
          freelens-bin
        ]);
    };
  };
}
