# K9s Module

Welcome to the **K9s** module documentation! Take total command of your Kubernetes clusters with the ultimate terminal-based dashboard.

## Overview

Navigating Kubernetes resources via standard CLI tools can be tedious. This module installs K9s, a powerful TUI that lets you interact with your clusters at the speed of thought, heavily stylized for an exceptional visual experience.

## Key Features

- **Dracula Aesthetics:** Automatically downloads and configures the stunning Dracula skin, applying it globally via the `K9S_SKIN` session variable for a gorgeous, unified dark mode experience.
- **Unstable Updates:** Pulls K9s directly from the unstable channel, guaranteeing you have the newest features and bug fixes for managing modern Kubernetes clusters.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.k9s.enable = true;
```
