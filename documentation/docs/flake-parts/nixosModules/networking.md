# Networking Module

Welcome to the **Networking** module documentation! Establish a rock-solid foundation for your system's connectivity with ease and simplicity.

## Overview

Connectivity is the lifeblood of any modern machine. This module provides a hassle-free approach to managing your network interfaces, ensuring that you stay connected whether you're wired in or roaming on Wi-Fi.

## Key Features

- **NetworkManager Integration:** Activates NetworkManager, the premier service for dynamically managing varied network connections on Linux. It handles everything from Ethernet to complex wireless setups effortlessly.
- **DHCP by Default:** Ensures that Dynamic Host Configuration Protocol (DHCP) is enabled, allowing your machine to automatically securely negotiate IP addresses and routing information from your local router.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.networking.enable = true;
```
