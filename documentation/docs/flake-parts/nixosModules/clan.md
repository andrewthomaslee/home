# Clan Module

Welcome to the **Clan** module documentation! This module serves as the foundational glue for integrating your NixOS machine into the broader Clan ecosystem, ensuring secure, versioned, and deliberate deployments.

## Overview

Managing fleet deployments requires precision and safety. This module configures the core Clan settings for your host, enforcing strict deployment rules and robust state management to keep your infrastructure reliable and predictable.

## Key Features

- **Explicit Updates:** Enforces `deployment.requireExplicitUpdate = true`. This safeguard ensures that your machine only receives updates when deliberately instructed, preventing accidental rollouts from breaking your environment.
- **State Versioning:** Activates state versioning (`settings.state-version.enable = true`), an essential mechanism for tracking the lifecycle of your host's data and maintaining compatibility across configuration revisions.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.clan.enable = true;
```
