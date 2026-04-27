# Minecraft Module

Welcome to the **Minecraft** module documentation! Embark on blocky adventures with a powerhouse, fully-declarative Minecraft server environment managed entirely through NixOS and Clan.

## Overview

Powered by `nix-minecraft`, this module provides a highly advanced, secure, and extensible foundation for hosting a Fabric-based Minecraft server. From dynamically generated world seeds to secure proxy networking via Playit.gg, it handles the heavy lifting so you can focus on building and exploring.

## Key Features

- **Fabric Server Integration:** Spens up a dedicated Fabric server, allowing you to easily specify loader versions and inject custom mod symlinks directly into your Nix configuration.
- **Dynamic Secrets & Seeds:** Leverages Clan variables to securely generate and persist unique world seeds across deployments.
- **Extensive Customization:** Offers robust Nix options for configuring every aspect of the server:
  - **JVM Options:** Pre-configured with highly optimized G1GC arguments for smooth, lag-free gameplay.
  - **Server Properties:** Easily manage gamemode, difficulty, simulation distance, and your server's MOTD.
  - **Whitelists & Operators:** Declaratively manage player access and admin privileges.
- **Playit.gg Proxy integration:** Automatically deploys the Playit.gg proxy in a highly-secured, hardened systemd service, allowing you to expose your server to the internet without complicated port-forwarding.

## Usage

Enable and configure the module in your host specification:

```nix
hostSpec.services.minecraft = {
  enable = true;
  serverProperties = {
    gamemode = "survival";
    difficulty = "hard";
    motd = "❄️ Welcome to the NixOS Server ⛏️";
  };
  # Add mods, whitelists, and operators...
};
```
