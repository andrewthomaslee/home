# Neovim Module

Welcome to the **Neovim** module documentation! Equip yourself with the hyper-extensible, modern iteration of the classic Vim text editor.

## Overview

A robust terminal workflow demands an equally robust text editor. This module installs Neovim and deeply integrates it into your shell environment, ensuring it's always ready when you need to quickly edit a configuration file or dive into code.

## Key Features

- **System Default:** Automatically sets `defaultEditor = true`, making Neovim the default handler for system commands like `git commit` and `crontab -e`.
- **Seamless Aliasing:** Configures `viAlias = true` and `vimAlias = true`, so even if your muscle memory types `vi` or `vim`, you'll effortlessly drop right into the modern Neovim experience.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.neovim.enable = true;
```
