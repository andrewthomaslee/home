# Tailscale Module

Welcome to the **Tailscale** module documentation! Effortlessly weave your machine into a secure, globally-accessible mesh network with zero configuration headaches.

## Overview

Tailscale revolutionizes virtual private networking. This module deeply integrates the Tailscale daemon into your NixOS host, securely provisioning authentication keys via Clan, managing firewall traversal, and even tweaking low-level network dispatchers for optimal throughput.

## Key Features

- **Clan Secret Integration:** Automatically securely retrieves and persists Tailscale authentication keys (`authKeyFile`), allowing nodes to preauthorize without manual intervention.
- **Routing & Exit Nodes:** Automatically advertises the host as an exit node and tags it appropriately (`tag:home`), letting you securely route internet traffic from anywhere.
- **Advanced Network Dispatching:** Implements custom `networkd-dispatcher` scripts that manipulate `ethtool` settings (UDP GRO forwarding), drastically improving network performance and throughput over the mesh.
- **Optional Systray:** Easily toggle a graphical `tailscale-systray` widget in your desktop environment for quick status checks and configuration.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.networking.tailscale = {
  enable = true;
  systray = true; # Optional GUI tray icon
};
```
