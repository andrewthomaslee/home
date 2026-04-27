# VS Code Module

Welcome to the **VS Code** module documentation! Step into a hyper-optimized, visually stunning, and highly opinionated VSCodium editor environment, driven entirely by Nix.

## Overview

This is no ordinary text editor configuration. This module installs VSCodium (the telemtry-free fork of VS Code) and declaratively outfits it with a massive suite of extensions, beautiful theming, strict formatting rules, and deep integration with Nix tooling. 

## Key Features

- **VSCodium Base:** Uses the telemetry-free `vscodium` package while allowing a mutable extension directory for on-the-fly additions.
- **Curated Extensions:** Pre-loaded with essential extensions for a modern developer:
  - *Nix:* Alejandra, Nix-IDE (`nil` language server)
  - *AI:* Supermaven, Roo Cline
  - *DevOps:* Terraform, Docker, Kubernetes, GitHub Actions
  - *Languages:* Python (Ruff), TailwindCSS, YAML, TOML, Hugo
- **Aesthetics & UI:** Configured with the striking "Red" color theme and `catppuccin-macchiato` icons. The UI is heavily streamlined—disabling the minimap, hiding the secondary sidebar, and moving the primary sidebar to the right.
- **Pre-Configured Tooling:** 
  - *Python:* Enforces Ruff for blazing-fast formatting and linting.
  - *Nix:* Configures the `nil` language server with 6GB of memory and automatic flake evaluation, seamlessly formatting with Alejandra on save.
  - *Roo Cline:* Strictly defines allowed and denied commands, ensuring the AI assistant operates safely within your NixOS environment.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.vscode.enable = true;
```
