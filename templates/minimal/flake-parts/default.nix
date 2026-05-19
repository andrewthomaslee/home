{
  inputs,
  self,
  ...
}: let
  # Define custom lib accessable as `lib.custom`
  customLib = inputs.nixpkgs.lib.extend (self: super: {custom = import ../lib {inherit (inputs.nixpkgs) lib;};});
  inherit (customLib.custom) relativeToRoot;
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    _module.args = {
      lib = customLib;
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
        config.allowUnfree = true;
      };
    };

    formatter = pkgs.alejandra;

    # Dev Shell
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        bash
        bun
      ];
      shellHook = ''
        export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
        export REPO_ROOT=$(git rev-parse --show-toplevel)
        eval "$(bunx varlock load --format shell)"
      '';
    };
  };

  flake = {
    # Default NixOS Module
    nixosModules.default = {pkgs, ...}: {
      _module.args.lib = customLib;
      nixpkgs.overlays = [self.overlays.default];
    };

    # Overlays
    overlays.default = import (relativeToRoot "overlays") {inherit inputs self;};
  };
}
