# SSH (Home) Module

Welcome to the **SSH (Home)** module documentation! Seamlessly integrate custom, unmanaged SSH configurations into your declarative workflow.

## Overview

While Nix handles declarative SSH configurations beautifully, tools like DevPod often require a mutable `~/.ssh/config` file to dynamically inject connection parameters. This module gracefully solves that problem.

## Key Features

- **DevPod Compatibility:** Specifically designed to play nicely with DevPod by globally exposing `SSH_CONFIG_PATH = "~/.ssh/config.local"`.
- **Local Overrides:** Instructs the SSH daemon to explicitly include `~/.ssh/config.local` at runtime, allowing you to manually add or dynamically generate host configurations without breaking your declarative Nix setup.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.ssh.enable = true;
```
