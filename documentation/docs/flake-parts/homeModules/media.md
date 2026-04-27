# Media Module

Welcome to the **Media** module documentation! Equip your user environment with essential, high-performance multimedia utilities.

## Overview

This lightweight module provisions a curated selection of fast, command-line friendly media applications, ensuring you can view, edit, and convert media without heavy GUI overhead.

## Key Features

- **MPV Player:** Installs `mpv`, the immensely powerful, highly-customizable, and hardware-accelerated media player capable of playing virtually any video format imaginable.
- **ImageMagick:** Provides the `imagemagick` suite, giving you unparalleled command-line power to convert, resize, crop, and manipulate images instantly.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.media.enable = true;
```
