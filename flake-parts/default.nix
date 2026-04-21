{
  inputs,
  self,
  ...
}: let
  # Define custom lib accessable as `lib.custom`
  customLib = inputs.nixpkgs.lib.extend (
    self: super: {
      custom = import ../lib {
        inherit (inputs.nixpkgs) lib;
      };
    }
  );
in {
  perSystem = {
    pkgs,
    system,
    config,
    self',
    ...
  }: {
    _module.args = {
      lib = customLib;
      # Make pkgs.unstable available in perSystem evaluation as well
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
        config.allowUnfree = true;
      };
    };

    # Formatter
    formatter = pkgs.unstable.alejandra;
    # Mkdocs
    documentation.mkdocs-root = ../documentation;
  };

  flake = {
    # Default NixOS Module
    nixosModules.default = {pkgs, ...}: {
      _module.args.lib = customLib;

      nixpkgs = {
        overlays = [self.overlays.default];
        config.allowUnfree = true;
      };

      imports = [
        inputs.determinate.nixosModules.default
      ];
    };

    # Overlays
    overlays.default = import ../overlays {inherit inputs self;};

    # Templates
    templates = {
      default = {
        path = ../templates/default;
        description = "Dendritic Flake";
      };
      devenv = {
        path = ../templates/devenv;
        description = "Dendritic Flake + devenv";
      };
    };
  };
}
