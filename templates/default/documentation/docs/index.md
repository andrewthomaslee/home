# Welcome to A Generic Dendritic Determinate Nix Flake


## Project layout

    flake.nix     # Flake that controls the project.
    flake.lock    # Flake's lock file.
    .envrc        # direnv configuration.
    .env.schema   # Varlock schema.

    lib/          # Custom functions accessible via `lib.custom`.
    overlays/     # Overlays for Nixpkgs. Adds `pkgs.unstable` and `pkgs.devenv-unstable`.
    templates/    # Templates for NixOS.

    flake-parts/  # Top-level Flake Part files.
        default.nix  # Default flake-parts configuration.
        devShells.nix  # Development Shells.

    documentation/
        mkdocs.yml  # Mkdocs configuration.
        docs/       # Documentation source.

    .github/workflows/
        flakehub-publish-tagged.yml  # GitHub Actions workflow to publish Flake outputs to FlakeHub.

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