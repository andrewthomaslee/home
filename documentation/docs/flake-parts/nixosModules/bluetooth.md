# Bluetooth Module

Welcome to the **Bluetooth** module documentation! This streamlined module seamlessly integrates Bluetooth capabilities into your NixOS environment, ensuring a frictionless wireless experience from the moment you turn on your machine.

## Overview

By toggling a single option, this module takes care of the underlying hardware configurations necessary to get your Bluetooth controller up and running. It is designed to be completely hands-off—powering on your Bluetooth adapter automatically during the boot sequence.

## Key Features

- **Instant Hardware Activation:** Flawlessly sets up `hardware.bluetooth.enable` to activate the system's Bluetooth stack.
- **Power-On at Boot:** Configures the adapter to turn on automatically upon system boot (`powerOnBoot = true`), saving you from manually toggling it before connecting your favorite headphones or peripherals.

## Usage

Enable the module in your host configuration as follows:

```nix
hostSpec.hardware.bluetooth.enable = true;
```
