{
  description = "Dendritic Determinate Flake";
  inputs = {
    # Determinate Nix
    # https://docs.determinate.systems/guides/advanced-installation/
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-devenv.url = "github:cachix/devenv-nixpkgs/rolling";

    # Devenv
    # https://devenv.sh/guides/using-with-flake-parts/
    devenv = {
      url = "github:cachix/devenv";
      inputs = {
        nixpkgs.follows = "nixpkgs-devenv";
        flake-parts.follows = "flake-parts";
        flake-compat.follows = "flake-compat";
        git-hooks.inputs.flake-compat.follows = "flake-compat";
        git-hooks.inputs.gitignore.follows = "gitignore";
        git-hooks.inputs.nixpkgs.follows = "nixpkgs-devenv";
        crate2nix.inputs.flake-parts.follows = "flake-parts";
        crate2nix.inputs.flake-compat.follows = "flake-compat";
        crate2nix.inputs.nixpkgs.follows = "nixpkgs-devenv";
        crate2nix.inputs.crate2nix_stable.inputs.flake-parts.follows = "flake-parts";
        crate2nix.inputs.crate2nix_stable.inputs.flake-compat.follows = "flake-compat";
        nixd.inputs.nixpkgs.follows = "nixpkgs-devenv";
        nixd.inputs.treefmt-nix.follows = "treefmt-nix";
        cachix.inputs.nixpkgs.follows = "nixpkgs-devenv";
        cachix.inputs.flake-compat.follows = "flake-compat";
        pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs-devenv";
        pre-commit-hooks.inputs.flake-compat.follows = "flake-compat";
        pre-commit-hooks.inputs.gitignore.follows = "gitignore";
      };
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs = {
        nixpkgs.follows = "nixpkgs-devenv";
      };
    };
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };

    # Mkdocs
    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        poetry2nix.inputs.nixpkgs.follows = "nixpkgs";
        poetry2nix.inputs.systems.follows = "systems";
        poetry2nix.inputs.treefmt-nix.follows = "treefmt-nix";
        poetry2nix.inputs.flake-utils.follows = "flake-utils";
        pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
        uv2nix.inputs.nixpkgs.follows = "nixpkgs";
      };
    };

    # Clan.lol
    clan-core = {
      url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        systems.follows = "systems";
        treefmt-nix.follows = "treefmt-nix";
        disko.inputs.nixpkgs.follows = "nixpkgs";
        sops-nix.inputs.nixpkgs.follows = "nixpkgs";
        nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
      };
    };

    # Home-manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Utility Flakes
    flake-parts.follows = "determinate/nix/flake-parts";
    import-tree.url = "github:vic/import-tree";
    systems.url = "github:nix-systems/default";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-cache:4FILs79Adxn/798F8qk2PC1U8HaTlaPqptwNJrXNA1g="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    extra-substituters = [
      "https://install.determinate.systems"
      "https://devenv.cachix.org"
      "https://cache.clan.lol"
      "https://nix-community.cachix.org"
      "https://cache.lounge.rocks/nix-cache"
      "https://cache.nixos.org"
    ];
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
      ];

      imports = [
        (inputs.import-tree ./flake-parts)
        inputs.devenv.flakeModule
        inputs.mkdocs-flake.flakeModules.default
        inputs.clan-core.flakeModules.default
        inputs.home-manager.flakeModules.home-manager
      ];
    };
}
