# XDG Module

Welcome to the **XDG** module documentation! Keep your home directory meticulously clean and organized.

## Overview

Cluttered home directories are a thing of the past. This module strictly enforces the XDG Base Directory Specification across your user environment, ensuring that configuration files, state data, and caches are neatly tucked away into their proper respective folders.

## Key Features

- **Standardized Paths:** Automatically enables XDG configuration (`xdg.enable = true`), forcing well-behaved applications to store their files in `~/.config`, `~/.local/share`, and `~/.cache` rather than dumping dotfiles directly into your home directory.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.xdg.enable = true;
```
