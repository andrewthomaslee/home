# Go Module

Welcome to the **Go** module documentation! Set up a pristine, correctly-configured environment for writing modern Go applications.

## Overview

This module takes the hassle out of setting up the Go programming language by installing the latest compiler and strictly organizing your workspace environment variables.

## Key Features

- **Unstable Channel:** Installs the absolute latest stable release of the Go compiler from the unstable channel.
- **Clean Workspace:** Explicitly sets the `GOPATH` session variable to `~/.go`, keeping your home directory clean and your Go dependencies neatly organized in one place.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.go.enable = true;
```
