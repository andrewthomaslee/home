# Clan Template

<h3 align="center">
  <strong><u>Clan Template</u></strong>
</h3>

<h3 align="center">
  <strong><u>PLEASE UPDATE YOUR INFO WHERE `TODO` IN REPO</u></strong>
</h3>


## Project layout

    flake.nix       # Flake that controls the project
    flake.lock      # Flake's lock file
    inventory.nix   # Clan.lol Inventory of all NixOS machines and Services
    .envrc          # direnv configuration
    .env.schema     # Varlock schema

    machines/       # NixOS Machines
    clanServices/   # Clan.lol Services    
    lib/            # Custom functions accessible via `lib.custom`
    overlays/       # Overlays for Nixpkgs. Adds `pkgs.unstable`
    templates/      # Templates for Projects

    flake-parts/        # Top-level Flake Part files
        default.nix     # Default flake-parts configuration
        profiles.nix    # Profiles for NixOS and Home-manager
        devShells.nix   # Development Shells
        kubenix.nix     # Manifests built with `nix run .#kubenix`
        apps/           # Applications `nix run .#<app>`
        packages/       # Packages `nix build .#<package>`
        homeModules/    # Home-manager Modules
        nixosModules/   # NixOS Modules

    kubernetes/         # Kubernetes Manifests and Kubenix Packages
        shared.nix      # Shared Kubernetes Manifests
        <cluster>.nix   # Cluster Manifests    
        clusters/       # FluxCD Bootstrap Folders

    documentation/      # MkDocs
        mkdocs.yml      # MkDocs configuration
        docs/           # Documentation source

    .github/workflows/      # GitHub Actions workflows
        check-flake.yml     # Flake Health Checker ( Run on push )
        publish-flake.yml   # Publish to FlakeHub + MkDocs to GitHub Pages ( Run on tagged release )

    .devcontainer/          # Devcontainer

    sops/                   # Encrypted Secrets
    vars/                   # Clan.lol implementaion of SOPS

## Flake Outputs

```console
$ nix flake show
├───apps
├───clan: unknown
├───clanInternals: unknown
├───darwinConfigurations: unknown
├───darwinModules: unknown
├───devShells
├───formatter
├───homeConfigurations: unknown
├───homeModules: unknown
├───nixosConfigurations
├───nixosModules
├───overlays
├───packages
└───templates
```