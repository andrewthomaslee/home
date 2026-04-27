# Direnv Module

Welcome to the **Direnv** module documentation! Say goodbye to manual environment variable management and hello to seamless, directory-specific development environments.

## Overview

This module supercharges your workflow by integrating `direnv`, `nix-direnv`, and `devenv` directly into your shell. It automatically loads and unloads environment variables and Nix environments the moment you `cd` into your project directories.

## Key Features

- **Nix Integration:** Enables `nix-direnv`, preventing garbage collection of your development environments and drastically speeding up shell load times.
- **Devenv Ready:** Pre-installs `devenv` from the unstable channel, giving you access to incredibly fast, declarative development shells.
- **Bash Native:** Automatically injects the necessary hooks into your Bash shell for a frictionless experience.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.direnv.enable = true;
```
