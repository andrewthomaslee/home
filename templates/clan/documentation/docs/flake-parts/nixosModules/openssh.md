# OpenSSH Module

Welcome to the **OpenSSH** module documentation! Securely administer your NixOS machines from anywhere in the world with a hardened SSH daemon.

## Overview

Remote access is critical, but security is paramount. This module deploys the OpenSSH daemon with modern security practices enforced by default, locking down vulnerable authentication methods and opening the necessary firewall ports.

## Key Features

- **Secure by Default:** Actively disables traditional, easily-bruteforced `PasswordAuthentication` and `KbdInteractiveAuthentication`. Access is strictly limited to secure, cryptographic SSH keys.
- **On-Demand Startup:** Configures the daemon to start only when needed (`startWhenNeeded = true`), preserving system resources while remaining responsive to incoming connections.
- **Firewall Integration:** Automatically opens Port 22 on the system's firewall, ensuring your machine is instantly reachable over the network.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.services.openssh.enable = true;
```
