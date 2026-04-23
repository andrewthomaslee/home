# Welcome to A Generic Dendritic Determinate Nix Flake


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

    ├───apps
    │   └───x86_64-linux
    │       └───watch-documentation: app
    ├───devShells
    │   └───x86_64-linux
    │       ├───default: development environment
    │       └───pure: development environment
    ├───formatter
    │   └───x86_64-linux: formatter
    ├───nixosModules
    │   └───default: NixOS module
    ├───overlays
    │   └───default: Nixpkgs overlay
    ├───packages
    │   └───x86_64-linux
    │       ├───container-processes: package
    │       ├───container-shell: package
    │       ├───devenv-test: package
    │       ├───devenv-up: package
    │       └───documentation: package
    └───templates
        ├───default: template
        └───devenv: template



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