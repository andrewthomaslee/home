# Shell Module

Welcome to the **Shell** module documentation! Supercharge your command-line workflow with a heavily customized, incredibly capable Bash environment.

## Overview

Your shell is your command center. This module doesn't just configure Bash; it outfits it with a phenomenal suite of modern utilities and a massive arsenal of custom aliases specifically designed to accelerate NixOS administration, development, and cluster management.

## Key Features

- **Modern Utilities:** Pre-installs the holy trinity of modern terminal tools from the unstable channel:
  - **Eza:** A modern, incredibly fast replacement for `ls`.
  - **Ripgrep:** A blazing-fast search tool that respects your `.gitignore`.
  - **FZF:** The ultimate command-line fuzzy finder.
- **Nix Workflows:** Provides lightning-fast aliases for common Nix commands:
  - `nfc`, `nfu`, `nfs`: Flake checking, updating, and showing.
  - `nr`, `nd`: Nix run and Nix develop.
  - `nixos-rebuild-switch/boot/test`: Pre-configured, `sudo`-wrapped system rebuild commands dynamically targeted to the current host!
- **Cluster & System Tools:** Includes complex automation aliases like `k3s-wipe` for instant Kubernetes cluster resets, `fabric-backup` for quick Minecraft world syncing via rsync, and immediate system halts (`off`).

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.shell.enable = true;
```
