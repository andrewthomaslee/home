# Welcome to Andrew's Home Flake

This repository is the home for all my personal NixOS machines.

## Features

- flake-parts
- dendritic
- home-manager
- clan.lol
- Determinate Systems


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
│       └───watch-documentation: app
├───checks
│   └───x86_64-linux
├───clan unknown flake output
├───clanInternals unknown flake output
├───darwinConfigurations
├───darwinModules
├───devShells
│   └───x86_64-linux
│       └───default: development environment
├───formatter
│   └───x86_64-linux: formatter
├───homeConfigurations
├───homeModules
│   ├───default: Home Manager module
│   ├───direnv: Home Manager module
│   ├───docker: Home Manager module
│   ├───firefox: Home Manager module
│   ├───ghostty: Home Manager module
│   ├───git: Home Manager module
│   ├───go: Home Manager module
│   ├───k9s: Home Manager module
│   ├───ksshaskpass: Home Manager module
│   ├───media: Home Manager module
│   ├───profile-developer: Home Manager module
│   ├───profile-normal: Home Manager module
│   ├───profile-server: Home Manager module
│   ├───shell: Home Manager module
│   ├───ssh: Home Manager module
│   ├───starship: Home Manager module
│   ├───tmux: Home Manager module
│   ├───uv: Home Manager module
│   ├───vscode: Home Manager module
│   └───xdg: Home Manager module
├───legacyPackages
│   └───x86_64-linux omitted (use '--legacy' to show)
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
│       └───documentation: package
└───templates
    ├───clan: template
    ├───default: template
    └───minimal: template
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