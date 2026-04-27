# KDE Plasma Module

Welcome to the **KDE Plasma** module documentation! Transform your desktop experience with a beautiful, fully-featured, and hardware-accelerated KDE Plasma 6 environment.

## Overview

This module delivers a stunning graphical interface powered by KDE Plasma 6 and the modern Wayland display protocol via SDDM. It takes care of everything from ensuring buttery-smooth hardware graphics acceleration to curating an excellent suite of essential desktop applications. 

## Key Features

- **Plasma 6 & Wayland:** Activates the bleeding-edge KDE Plasma 6 desktop manager alongside the SDDM display manager, fully configured for Wayland.
- **Hardware Acceleration:** Forces the enablement of both 64-bit and 32-bit hardware graphics acceleration, guaranteeing exceptional performance for UI rendering, gaming, and multimedia.
- **Curated Application Suite:** Comes pre-packaged with a fantastic array of KDE tools and system utilities, including:
  - *Productivity:* KRunner, Kate, Kalk (Calculator)
  - *System Tools:* Filelight (Disk usage), KSystemLog, Hardinfo2
  - *Media & Graphics:* Haruna (Video player), KolourPaint, KColorChooser
  - *Utilities:* KTorrent, Krfb (Desktop sharing), xclip
- **Refined Defaults:** Purges legacy software like `xterm` and sets up a clean `us` keyboard layout for a polished out-of-the-box experience.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.services.kde.enable = true;
```
