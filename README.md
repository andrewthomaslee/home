# Welcome to Andrew's Home Flake

<div align="center">
  <img src="https://blog.andrewlee.fun/favicon.ico" width="400">
</div>

<p align="center">
  <a href="https://github.com/andrewthomaslee/home/releases"><img src="https://img.shields.io/github/v/release/andrewthomaslee/home?include_prereleases&style=for-the-badge" alt="Latest Release"></a>
  <a href="https://github.com/andrewthomaslee/home/actions/workflows/check-flake.yml"><img src="https://img.shields.io/github/actions/workflow/status/andrewthomaslee/home/check-flake.yml?style=for-the-badge&label=Tests" alt="Tests Status"></a>
  <a href="https://github.com/andrewthomaslee/home/actions/workflows/publish-flake.yml"><img src="https://img.shields.io/github/actions/workflow/status/andrewthomaslee/home/publish-flake.yml?style=for-the-badge" alt="Build Status"></a>
  <a href="https://github.com/andrewthomaslee/home/blob/main/LICENSE"><img src="https://img.shields.io/github/license/andrewthomaslee/home?style=for-the-badge&color=blue" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/andrewthomaslee/home"><img src="https://img.shields.io/badge/github-repo-24292e?logo=github&style=for-the-badge" alt="GitHub Repo"></a>
  <a href="https://flakehub.com/flake/andrewthomaslee/home?view=usage"><img src="https://img.shields.io/badge/flakehub-repo-purple?style=for-the-badge" alt="FlakeHub Repo"></a>
</p>


<h3 align="center">
  <strong>🏠 Home Repository for my <u>NixOS Machines</u>❄️ and <u>Kubernetes Clusters</u>☸️</strong>
</h3>


<div align="center">

## Features

### ☸️ **Kubernetes**
`K3s` • `Cilium & Cluster Mesh` • `Sealed Secrets` • `FluxCD` • `Kubenix` • `Cloudflare Tunnels`

### ❄️ **NixOS**
`Determinate Systems` • `Clan.lol` • `flake-parts` • `dendritic` • `home-manager` • `Tailscale` • `Modded Minecraft Server` • `KDE` • `Wayland`

</div>



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
│   └───x86_64-linux
│       ├───fetch-kubeconfig: app: no description
│       ├───flux-bootstrap: app: no description
│       ├───kubenix: app: no description
│       ├───tmp-pod: app: no description
│       ├───update-flake-show: app: no description
│       ├───update-minecraft-mods: app: no description
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
│   ├───hel-1: NixOS configuration
│   ├───hp-notebook: NixOS configuration
│   ├───kamrui-p1: NixOS configuration
│   └───nixos: NixOS configuration
├───nixosModules
│   ├───bluetooth: NixOS module
│   ├───clan: NixOS module
│   ├───clan-machine-ghost: NixOS module
│   ├───clan-machine-hel-1: NixOS module
│   ├───clan-machine-hp-notebook: NixOS module
│   ├───clan-machine-kamrui-p1: NixOS module
│   ├───clan-machine-nixos: NixOS module
│   ├───default: NixOS module
│   ├───docker: NixOS module
│   ├───kde: NixOS module
│   ├───minecraft: NixOS module
│   ├───motd: NixOS module
│   ├───networking: NixOS module
│   ├───nix: NixOS module
│   ├───openssh: NixOS module
│   ├───profile-developer: NixOS module
│   ├───profile-normal: NixOS module
│   ├───profile-server: NixOS module
│   ├───sound: NixOS module
│   ├───storagebox: NixOS module
│   ├───tailscale: NixOS module
│   └───wayland: NixOS module
├───overlays
│   └───default: Nixpkgs overlay
├───packages
│   └───x86_64-linux
│       ├───documentation: package 'mkdocs-flake-documentation'
│       ├───helsinki: package 'helsinki-generated.json'
│       ├───home: package 'home-generated.json'
│       ├───playit: package 'playit-0.17.1'
│       └───shared: package 'shared-generated.json'
└───templates
    ├───clan: template: Dendritic Clan Flake
    ├───default: template: Dendritic Flake
    └───minimal: template: Minimal Dendritic Flake
```



## Top-level Flake Part files

Example of a top-level Flake Part file:

```nix
{
  inputs,
  self,
  lib,
  ...
}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    system,
    config,
    self',
    inputs',
    customLib,
    ...
  }: {
  };

  flake = {
    # ------ NixOS Modules ------ #
    nixosModules.template = {
      pkgs,
      config,
      ...
    }: {};

    # ------ Home-manager Modules ------ #
    homeModules.template = {
      pkgs,
      config,
      ...
    }: {};
  };
}

```