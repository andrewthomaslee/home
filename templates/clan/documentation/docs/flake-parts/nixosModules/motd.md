# MOTD Module

Welcome to the **MOTD (Message of the Day)** module documentation! Greet your users with style and vital system information every time they log in.

## Overview

A great server deserves a great greeting. This module provides a highly customizable, scriptable Message of the Day system that uniquely tailors the greeting depending on whether the user is logging in locally or remotely via SSH.

## Key Features

- **Context-Aware Greetings:** Dynamically detects your connection type and serves either the `sshMotd` or `localMotd` script, ensuring the information presented is highly relevant to your session.
- **Duplicate Prevention:** Intelligently exports a `MOTD_DISPLAYED` flag to ensure your beautifully crafted greeting isn't annoyingly printed multiple times during nested shell initializations.
- **Scriptable Power:** Because the MOTD is rendered using a `writeShellApplication`, you have the full power of bash, `gawk`, `procps`, and `coreutils` at your disposal to generate dynamic system stats on the fly!

## Usage

Enable the module in your host configuration:

```nix
hostSpec.services.motd.enable = true;
```
