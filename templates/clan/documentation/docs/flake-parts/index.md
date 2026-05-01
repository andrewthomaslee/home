# Top-level Flake Part files

Example of a top-level Flake Part file:

```nix
{
  inputs,
  self,
  lib,
  ...
}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    system,
    config,
    self',
    inputs',
    customLib,
    ...
  }: {
  };

  flake = {
    # ------ NixOS Modules ------ #
    nixosModules.template = {
      pkgs,
      config,
      ...
    }: {};

    # ------ Home-manager Modules ------ #
    homeModules.template = {
      pkgs,
      config,
      ...
    }: {};
  };
}

```