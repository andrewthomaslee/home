{
  description = "Dendritic Determinate Flake";
  inputs = {
    # Determinate Nix
    # https://docs.determinate.systems/guides/advanced-installation/
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # Clan.lol
    # https://git.clan.lol/clan/clan-core
    clan-core = {
      url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixpkgs
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs-devenv.url = "github:cachix/devenv-nixpkgs/rolling";

    # Devenv
    # https://devenv.sh/guides/using-with-flake-parts/
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs-devenv";
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

    # Mkdocs
    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home-manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Utility Flakes
    flake-parts.follows = "clan-core/flake-parts";
    import-tree.url = "github:vic/import-tree";

    # Zen Browser
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    moscripts = {
      url = "https://flakehub.com/f/andrewthomaslee/moscripts/0.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    kubefetch = {
      url = "https://flakehub.com/f/andrewthomaslee/kubefetch/0.9.0";
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
