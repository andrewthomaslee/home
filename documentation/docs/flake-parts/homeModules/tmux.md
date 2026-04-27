# Tmux Module

Welcome to the **Tmux** module documentation! Master your terminal with a highly customized, incredibly efficient terminal multiplexer configuration.

## Overview

This module installs Tmux from the unstable channel and heavily modifies its default behavior to provide a fluid, keyboard-driven workspace that makes managing multiple terminal sessions a joy.

## Key Features

- **Ergonomic Prefix:** Remaps the default prefix key to `Ctrl-A` (`C-a`), a significantly more comfortable and accessible keystroke for heavy terminal users.
- **Quality of Life Tweaks:** 
  - *Zero Delay:* Reduces the `escapeTime` to `20ms`, eliminating frustrating delays when using Vim/Neovim inside Tmux.
  - *Base 1 Indexing:* Changes the base index for windows and panes to `1`, aligning perfectly with the number row on your keyboard.
  - *Auto-Spawning:* Automatically spawns a new session if you attempt to attach and none currently exist.
- **Massive History:** Expands the scrollback history limit to an impressive `8000` lines.
- **Powerful Plugins:** Comes pre-packaged with `tmux-fzf` for fuzzy finding sessions/windows, and the `pass` plugin for seamlessly integrating your password store directly into your multiplexer environment.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.tmux.enable = true;
```
