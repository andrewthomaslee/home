# Password Store Module

Welcome to the **Password Store** module documentation! Take back control of your credentials with the standard Unix password manager.

## Overview

Security should be simple, transparent, and completely under your control. This module installs `pass`, the classic, incredibly secure password manager that treats passwords as encrypted GPG files.

## Key Features

- **Unstable Channel:** Always fetches the latest version of `pass` from the unstable channel for maximum reliability and security patches.
- **Unix Philosophy:** Integrates perfectly with standard Unix tools, Git, and other modules (like Tmux) to seamlessly weave password management into your existing terminal workflow.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.password-store.enable = true;
```
