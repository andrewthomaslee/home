# KSSHAskPass Module

Welcome to the **KSSHAskPass** module documentation! Effortlessly integrate your SSH keys with the KDE Plasma desktop environment.

## Overview

Dealing with password prompts for SSH keys in a graphical session can be incredibly frustrating. This module bridges the gap, ensuring that KDE Plasma smoothly handles SSH agent authentication prompts and automatically unlocks your keys upon login.

## Key Features

- **Plasma Integration:** Installs `ksshaskpass` and globally sets the `SSH_ASKPASS` variable, redirecting all terminal SSH password prompts to a beautiful GUI dialog.
- **Automated Agent Management:** Deploys highly specific scripts directly into your `plasma-workspace` configuration to gracefully start the `ssh-agent` on login and cleanly terminate it on shutdown.
- **Autostart Unlock:** Automatically triggers `ssh-add` during your desktop login sequence, allowing you to unlock your keys once and use them everywhere.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.ksshaskpass.enable = true;
```
