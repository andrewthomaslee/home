# UV Module

Welcome to the **UV** module documentation! Embrace the incredible speed of the Rust-based Python package installer and resolver.

## Overview

Python package management has never been faster. This module installs `uv` from the unstable channel and configures it with strict, system-first paradigms to ensure a clean and predictable Python development experience.

## Key Features

- **Python 3.14 Integration:** Automatically provisions the cutting-edge `python314` interpreter alongside `uv`.
- **Strict Resolution Rules:** Configured with `python-downloads = "never"` and `python-preference = "only-system"`, forcing `uv` to utilize your system's Nix-provided Python instead of silently downloading rogue interpreters.
- **Copy Mode:** Enforces `link-mode = "copy"` to prevent strange symlinking behaviors in Nix environments when creating virtual environments.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.uv.enable = true;
```
