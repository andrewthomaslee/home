# Nix Module

Welcome to the **Nix** module documentation! Optimize and secure the core package manager that powers your entire operating system.

## Overview

This module fine-tunes the Nix daemon, ensuring it operates securely and has the necessary credentials to fetch private repositories. By integrating seamlessly with Clan's secret management, it automates the provisioning of access tokens.

## Key Features

- **GitHub PAT Integration:** Automatically generates and persists Nix access tokens using Clan variables. This allows Nix to seamlessly authenticate against GitHub to pull private flakes and repositories without rate limits.
- **Secure Access Control:** Restricts Nix daemon interaction to trusted users (`root` and `netsa`), preventing unauthorized users on the system from manipulating the Nix store or executing arbitrary builds.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.services.nix.enable = true;
```
