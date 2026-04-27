# Sound Module

Welcome to the **Sound** module documentation! Immerse yourself in crystal-clear audio powered by the modern PipeWire multimedia framework.

## Overview

Gone are the days of complex Linux audio routing issues. This module leverages PipeWire to provide a unified, low-latency, and highly compatible audio stack that seamlessly handles all your multimedia needs, from casual listening to professional audio production.

## Key Features

- **PipeWire Core:** Enables the core PipeWire service, the modern standard for Linux audio and video routing.
- **Universal Compatibility:** Automatically enables translation layers for legacy audio systems:
  - **PulseAudio:** Ensures all standard desktop applications work flawlessly.
  - **ALSA:** Provides deep hardware-level compatibility.
  - **JACK:** Delivers pristine, low-latency performance for professional audio applications and DAWs.

## Usage

Enable the module in your host configuration:

```nix
hostSpec.hardware.sound.enable = true;
```
