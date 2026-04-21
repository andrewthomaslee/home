{
  description = "Dendritic Determinate Flake";
  inputs = {
    # Determinate Nix
    # https://docs.determinate.systems/guides/advanced-installation/
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # Nixpkgs
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    nixpkgs-devenv.url = "github:cachix/devenv-nixpkgs/rolling";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Flake-Parts
    # https://flake.parts/index.html
    flake-parts.follows = "determinate/nix/flake-parts";
    import-tree.url = "github:vic/import-tree";

    # Devenv
    # https://devenv.sh/guides/using-with-flake-parts/
    devenv = {
      url = "github:cachix/devenv";
      inputs = {
        nixpkgs.follows = "nixpkgs-devenv";
        flake-parts.follows = "flake-parts";
        crate2nix.inputs.flake-parts.follows = "flake-parts";
        crate2nix.inputs.crate2nix_stable.inputs.flake-parts.follows = "flake-parts";
      };
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs-devenv";
    };
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
  };

  nixConfig = {
    extra-trusted-public-keys = ["devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="];
    extra-substituters = ["https://devenv.cachix.org" "https://install.determinate.systems"];
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
      ];

      imports = [
        (inputs.import-tree ./flake-parts)
        inputs.devenv.flakeModule
      ];
    };
}
