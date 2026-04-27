# Bun Module

Welcome to the **Bun** module documentation! Supercharge your JavaScript and TypeScript development with the incredibly fast, all-in-one Bun toolkit.

## Overview

This module provisions Bun via Home Manager, ensuring you have the latest unstable version while automatically tailoring the installation for maximum privacy and isolation.

## Key Features

- **Privacy First:** Explicitly disables telemetry (`telemetry = false`) so your usage data remains yours alone.
- **Clean Environment:** Prevents Bun from needlessly polluting your global environment variables (`env = false`).
- **Isolated Linking:** Enforces isolated linking for global packages, placing everything neatly into `~/.bun/install/global` and `~/.bun/bin`.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.bun.enable = true;
```
