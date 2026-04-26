# flake-parts/default.nix

Main entry point for flake-parts configuration.

## Overview
Defines core flake outputs, per-system arguments, and default module configurations.

## Key Sections
- `perSystem`: System-specific settings (formatter, pkgs).
- `flake.nixosModules.default`: Shared NixOS configuration.
- `flake.homeModules.default`: Shared Home Manager configuration.
- `templates`: Project templates (default, minimal, clan).
