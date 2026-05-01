# Welcome to Andrew's Home Flake

<img src="documentation/assets/icons/kubenix.svg" width="400">

This repository is the home for all my personal NixOS machines.

## Features

- flake-parts
- dendritic
- home-manager
- clan.lol
- Determinate Systems
- Modded Minecraft Server


## Project layout

    flake.nix     # Flake that controls the project
    flake.lock    # Flake's lock file
    .envrc        # direnv configuration
    .env.schema   # Varlock schema

    lib/          # Custom functions accessible via `lib.custom`
    overlays/     # Overlays for Nixpkgs. Adds `pkgs.devenv-unstable`
    templates/    # Templates for NixOS

    flake-parts/        # Top-level Flake Part files
        default.nix     # Default flake-parts configuration
        devShells.nix   # Development Shells

    documentation/      # MkDocs
        mkdocs.yml      # MkDocs configuration
        docs/           # Documentation source

    .github/workflows/      # GitHub Actions workflows
        check-flake.yml     # Flake Health Checker ( Run on push )
        publish-flake.yml   # Publish to FlakeHub + MkDocs to GitHub Pages ( Run on tagged release )

## Flake Outputs

```console
$ nix flake show
├───apps
│   └───x86_64-linux
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
│       ├───kubenix-helsinki omitted due to use of import from derivation
│       ├───kubenix-home omitted due to use of import from derivation
│       └───playit: package 'playit-0.17.1'
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