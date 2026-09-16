{
  self,
  lib,
  ...
}: {
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
          opencode = {
            enable = true;
            mcp = {
              # Dev-profile opt-ins (off by module default)
              typeui.enable = true;
              # GitHub MCP via the clan-var PAT method; the "github-mcp"
              # generator + sops deployment is derived automatically by
              # nixosModules/github-mcp. Provision with:
              #   clan vars set github-mcp pat <machine>
              github.auth = lib.mkDefault "pat";
              # Cloudflare remote MCP servers
              cloudflare.enable = lib.mkDefault true;
              "cloudflare-docs".enable = lib.mkDefault true;
              "cloudflare-bindings".enable = lib.mkDefault true;
              "cloudflare-builds".enable = lib.mkDefault true;
              "cloudflare-browser".enable = lib.mkDefault true;
              "cloudflare-containers".enable = lib.mkDefault true;
              # MDN Web Docs
              mdn.enable = lib.mkDefault true;
              # ArtifactHub (Helm charts)
              artifacthub.enable = lib.mkDefault true;
            };
            # Dev-profile plugins (off by module default)
            plugins.opencode-mem.enable = true;
            plugins.oh-my-openagent.enable = true;
            plugins.devcontainers.enable = true;
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
