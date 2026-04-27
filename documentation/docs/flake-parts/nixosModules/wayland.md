# Wayland Module

Welcome to the **Wayland** module documentation! Step into the future of Linux graphics with a module designed to ensure perfect compatibility and smooth operation on Wayland compositors.

## Overview

Migrating to Wayland can sometimes introduce friction with legacy applications. This module squashes those issues by proactively injecting essential environment variables and configuring the XDG desktop portals required for flawless screen sharing and modern app support.

## Key Features

- **Electron Compatibility:** Sets crucial session variables (like `NIXOS_OZONE_WL=1`) to force modern Electron-based applications to run natively under Wayland, resulting in crisper text and smoother animations.
- **Robust Desktop Portals:** Configures `xdg-desktop-portal` with the `wlr` and `gtk` backends, ensuring that screen sharing (WebRTC) and file-picker dialogs function perfectly out of the box.
- **Essential Tooling:** Installs handy utilities like `wdisplays` to help you visually configure and manage your monitor placements within a Wayland environment.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.services.wayland.enable = true;
```
