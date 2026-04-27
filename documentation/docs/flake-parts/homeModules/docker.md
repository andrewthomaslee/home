# Docker (Home) Module

Welcome to the **Docker (Home)** module documentation! Elevate your container management workflow with powerful terminal UI tools.

## Overview

While the system-level Docker module handles the daemon, this Home Manager module focuses on the user experience. It provides intuitive, keyboard-driven utilities for interacting with your containers effortlessly.

## Key Features

- **Lazydocker Integration:** Installs and configures `lazydocker`, the premier terminal UI for both Docker and Docker Compose.
- **Custom Commands:** Comes pre-loaded with incredibly useful custom commands. With a single keypress, you can instantly drop into an interactive `bash` or `sh` shell within any running container.
- **Bake Support:** Automatically exports the `COMPOSE_BAKE="true"` session variable to enable advanced buildx capabilities.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.docker.enable = true;
```
