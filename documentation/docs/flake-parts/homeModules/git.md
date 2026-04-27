# Git Module

Welcome to the **Git** module documentation! Transform your version control experience with a highly opinionated, extremely powerful Git configuration.

## Overview

This module doesn't just install Git; it overhauls it. It brings in `lazygit` for a beautiful TUI experience, configures intelligent defaults, sets up global ignores, and strictly enforces secure SSH commit signing.

## Key Features

- **Lazygit & LFS:** Installs the full version of Git alongside Git LFS (Large File Storage) and the `lazygit` terminal UI.
- **Secure Commits:** Automatically configures Git to cryptographically sign all your commits using your ED25519 SSH key (`signByDefault = true`).
- **Intelligent Defaults:** 
  - *Rebasing:* Forces `autoSetupRebase = "always"` and enables `autoStash` and `autoSquash` to keep your commit history impeccably clean.
  - *Pulling:* Defaults to rebasing on pull, utilizing the modern `ort` merge strategy.
  - *Typo Correction:* Automatically corrects minor typos with `help.autocorrect = 10`.
- **Global Ignores:** Pre-loads a comprehensive `.gitignore` that ignores `.env` files, `.direnv`, `.terraform`, and build artifacts across *all* your repositories.
- **Powerful Aliases:** Includes battle-tested shortcuts like `git uncommit`, `git comma` (amend), and `git force-push` (with lease for safety).

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.git.enable = true;
```
