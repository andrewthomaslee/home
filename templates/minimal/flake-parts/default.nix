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

    # Dev Shell
    devShells.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        bashInteractive
        bash
      ];
      packages = with pkgs.unstable; [
        alejandra
        bun
      ];
      shellHook = ''
        export REPO_ROOT
        REPO_ROOT=$(git rev-parse --show-toplevel)
        eval "$(bunx varlock load --format shell)"
      '';
    };
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
  };
}
