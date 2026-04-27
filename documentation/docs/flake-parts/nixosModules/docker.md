# Docker Module

Welcome to the **Docker** module documentation! Dive into the world of containerization with a robust, production-ready Docker configuration tailored for your NixOS machine.

## Overview

This module provisions the Docker daemon as your primary OCI container backend. It is meticulously configured with modern networking standards (like IPv6), efficient logging, and automated maintenance routines to keep your system performing at its best without manual intervention.

## Key Features

- **OCI Backend Integration:** Sets the `oci-containers.backend` to Docker, ensuring seamless compatibility with NixOS container definitions.
- **Advanced Networking:** Enables IPv6 support within the Docker daemon out-of-the-box, alongside a fixed IPv6 CIDR (`fd00::/80`) to ensure your containers can communicate effectively in modern network topologies.
- **Efficient Logging:** Utilizes the `json-file` log driver, making it easy to parse, rotate, and manage container logs.
- **Automated Housekeeping:** Turns on automatic pruning (`autoPrune.enable = true`), which routinely cleans up dangling images and unused resources, freeing up valuable disk space effortlessly.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.services.docker.enable = true;
```
