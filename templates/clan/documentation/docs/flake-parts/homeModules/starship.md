# Starship Module

Welcome to the **Starship** module documentation! Bring absolute brilliance to your terminal prompt with the fast, highly customizable, cross-shell Starship prompt.

## Overview

Your prompt should provide context without clutter. This module configures a gorgeous, highly optimized Starship prompt that smartly hides irrelevant information while elevating the data you actually care about.

## Key Features

- **Context Aware:** Dynamically detects your environment, beautifully rendering Nix shells (`❄`), Git branch states (ahead/behind indicators), and active Kubernetes contexts (`KUBECONFIG`).
- **Aesthetic Tweaks:** Customizes the visual hierarchy to make your terminal readable at a glance:
  - Bolds directory paths in blue and intelligently truncates deep repository trees.
  - Highlights the hostname in a bold green.
  - Dims the Git branch name slightly for better visual balance.
- **Clutter Reduction:** Explicitly disables cloud provider prompts (AWS, GCloud) to prevent unnecessary network polling and keep your prompt incredibly snappy.

## Usage

Enable the module in your Home Manager configuration:

```nix
homeSpec.programs.starship.enable = true;
```
