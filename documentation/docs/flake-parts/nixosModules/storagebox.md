# Storage Box Module

Welcome to the **Storage Box** module documentation! Seamlessly integrate massive, remote Hetzner Storage Box capacity directly into your NixOS filesystem.

## Overview

This highly sophisticated module uses `rclone` to mount a remote Hetzner Storage Box over SFTP. It handles everything from securely generating SSH keypairs to establishing highly resilient, cached systemd mount units, treating remote storage as if it were a local disk.

## Key Features

- **Secure Key Generation:** Uses Clan variables to automatically generate and deploy ED25519 SSH keys specifically for connecting to the Hetzner Storage Box.
- **Advanced Rclone Mounting:** Creates a highly tuned `rclone` mount with:
  - Full VFS caching (`vfs_cache_mode=full`) with up to 5GB of local cache.
  - Large read-ahead buffers (`256M`) for incredibly smooth media streaming and file access.
  - Tunable concurrency limits to maximize bandwidth without overwhelming the remote server.
- **Flexible Mounting Strategies:** Choose between mounting the drive permanently at boot, or utilizing `mountOnAccess` (automount) to only establish the connection when you navigate to the directory, saving bandwidth and system resources.

## Usage

Enable and configure the module in your host specification:

```nix
hostSpec.services.storagebox = {
  enable = true;
  boxUser = "u123456";
  mountPoint = "/mnt/remote-storage";
  mountOnAccess = true;
};
```
