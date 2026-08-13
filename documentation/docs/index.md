# Welcome to Andrew's Home Flake

<div align="center">
  <img src="assets/brand/andrewthomaslee-transparent-logo.png" alt="Andrew's Logo" width="400">
</div>

<p align="center">
  <a href="https://github.com/andrewthomaslee/home/releases"><img src="https://img.shields.io/github/v/release/andrewthomaslee/home?include_prereleases&style=for-the-badge" alt="Latest Release"></a>
  <a href="https://github.com/andrewthomaslee/home/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/andrewthomaslee/home/ci.yml?style=for-the-badge" alt="CI Status"></a>
  <a href="https://github.com/andrewthomaslee/home/blob/main/LICENSE"><img src="https://img.shields.io/github/license/andrewthomaslee/home?style=for-the-badge&color=blue" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/andrewthomaslee/home"><img src="https://img.shields.io/badge/github-repo-24292e?logo=github&style=for-the-badge" alt="GitHub Repo"></a>
  <a href="https://flakehub.com/flake/andrewthomaslee/home"><img src="https://img.shields.io/endpoint?url=https://flakehub.com/f/andrewthomaslee/home/badge&style=for-the-badge" alt="FlakeHub"></a>
</p>


<h3 align="center">
  <strong>🏠 Home Repository for my <u>NixOS Machines</u>❄️ and <u>Kubernetes Clusters</u>☸️</strong>
</h3>


## Features

### ☸️ **Kubernetes**
`K3s` • `Cilium & Cluster Mesh` • `Sealed Secrets` • `FluxCD` • `Kubenix` • `Cloudflare Tunnels`

### ❄️ **NixOS**
`Determinate Systems` • `Clan.lol` • `flake-parts` • `dendritic` • `home-manager` • `Tailscale` • `Modded Minecraft Server` • `KDE` • `Wayland`



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
        apps/           # Applications `nix run .#<app>`
        packages/       # Packages `nix build .#<package>`
        homeModules/    # Home-manager Modules
        nixosModules/   # NixOS Modules

    documentation/      # MkDocs
        mkdocs.yml      # MkDocs configuration
        docs/           # Documentation source

    .github/workflows/    # GitHub Actions workflows
        ci.yml            # Flake Health Checker ( Run on push )
        machines.yml      # Build Machines + Publish to FlakeHub ( Run on trigger )
        release.yml       # Tagged release + Build Machines + Build Docs & devShells + Publish to FlakeHub ( Run on trigger )

    .devcontainer/          # Devcontainer

    sops/                   # Encrypted Secrets
    vars/                   # Clan.lol implementaion of SOPS

## Flake Outputs

```console
$ nix flake show
├───apps
│   └───x86_64-linux
│       ├───apply-and-reboot: app: Apply latest NixOS configuration + delayed reboot to allow Terraform/SSH to exit cleanly
│       ├───fetch-kubeconfig: app: no description
│       ├───get-keys: app: no description
│       ├───update-flake-show: app: no description
│       └───watch-documentation: app: Run mkdocs in watch mode over your documentation folder. Automatically rebuilds your docs on changes.
├───clan: unknown
├───clanInternals: unknown
├───darwinConfigurations: unknown
├───darwinModules: unknown
├───devShells
│   └───x86_64-linux
│       └───default: development environment 'nix-shell'
├───formatter
│   └───x86_64-linux: package 'alejandra-4.0.0'
├───homeConfigurations: unknown
├───homeModules: unknown
├───nixosConfigurations
│   ├───ghost: NixOS configuration
│   ├───hp-notebook: NixOS configuration
│   └───nixos: NixOS configuration
├───nixosModules
│   ├───amd: NixOS module
│   ├───bluetooth: NixOS module
│   ├───clan: NixOS module
│   ├───clan-machine-ghost: NixOS module
│   ├───clan-machine-hp-notebook: NixOS module
│   ├───clan-machine-nixos: NixOS module
│   ├───default: NixOS module
│   ├───docker: NixOS module
│   ├───flatpak: NixOS module
│   ├───intel: NixOS module
│   ├───jovian: NixOS module
│   ├───kde: NixOS module
│   ├───lan: NixOS module
│   ├───longhorn: NixOS module
│   ├───motd: NixOS module
│   ├───nix: NixOS module
│   ├───nix-ld: NixOS module
│   ├───ollama: NixOS module
│   ├───openssh: NixOS module
│   ├───rancher: NixOS module
│   ├───sound: NixOS module
│   ├───steam: NixOS module
│   ├───storagebox: NixOS module
│   ├───tailscale: NixOS module
│   ├───wan: NixOS module
│   ├───warp: NixOS module
│   └───wayland: NixOS module
├───overlays
│   └───default: Nixpkgs overlay
├───packages
│   └───x86_64-linux
│       ├───apply-and-reboot: package 'apply-and-reboot'
│       ├───apply-dry-activate: package 'apply-dry-activate'
│       ├───apply-now: package 'apply-now'
│       ├───apply-test: package 'apply-test'
│       ├───apply-to-boot: package 'apply-to-reboot'
│       ├───devShell: package 'nix-shell'
│       ├───documentation: package 'mkdocs-flake-documentation'
│       ├───get-keys: package 'get-keys'
│       ├───longhornctl: package 'longhornctl-v1.12.0'
│       ├───tfctl: package 'tfctl-0.16.4'
│       └───vcluster: package 'vcluster-v0.36.1'
└───templates
    ├───clan: template: Dendritic Clan Flake
    ├───default: template: Dendritic Flake
    ├───minimal: template: Minimal Dendritic Flake
    └───self: template: This Flake
```