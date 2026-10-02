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
          docker.enable = true;
          devenv = {
            # devenv CLI (flake package) + 2.x native auto-activation hook
            enabled = true;
            autoActivate.enabled = true;
          };
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
          opencode = {
            enable = true;
            # Dev-profile references (off by module default): attachable
            # doc bundles under ~/.config/opencode/references, advertised
            # via settings.references. Sources live in the repo's
            # references/ tree.
            references = {
              # Nix style guide + mandatory tool loop (user preferences)
              nix-style.enable = true;
              # flake-parts mechanics + integrations
              flakeparts.enable = true;
              # flake-parts auto-import mechanics
              import-tree.enable = true;
              # Determinate Systems / FlakeHub / fh apply / rolling semver
              determinate.enable = true;
              # home-manager with flakes + flake-parts (profile example)
              home-manager.enable = true;
              # clan-core fleet management
              clan-core.enable = true;
              # Authoring clan.service modules (clanServices) upstream style
              clanservices.enable = true;
              # devenv 2.x (CLI, hybrid borg pattern, containers)
              devenv.enable = true;
              # Hermetic NixOS VM tests
              vm-tests.enable = true;
              # This repo's customLib + the AGENTS flake lib (mkSkills etc.)
              lib.enable = true;
              # Cilium docs: v2 BGP control plane, LB IPAM, L2 announcements
              cilium.enable = true;
              # disko: disk layouts, clan integration, LUKS + vars, RAID1/mirror
              disko.enable = true;
              # OpenEBS: Kubernetes CSI storage engines + Mayastor
              openebs.enable = true;
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
          openshell
        ]
        ++ (with pkgs.unstable; [
          asciinema
          kalker
          freelens-bin
        ]);
    };
  };
}
