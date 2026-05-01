{
  description = "Dendritic Determinate Flake";
  inputs = {
    # Determinate Nix
    # https://docs.determinate.systems/guides/advanced-installation/
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # Clan.lol
    # https://clan.lol/docs/unstable
    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";

    # Nixpkgs
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs-unstable.url = "clan-core/nixpkgs";

    # Clan.lol Community
    clan-community = {
      url = "https://git.clan.lol/clan/clan-community/archive/main.tar.gz";
      inputs.clan-core.follows = "clan-core";
    };

    # kubenix
    kubenix = {
      url = "github:hall/kubenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Mkdocs
    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Home-manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11"; # TODO: update to main once nixpkgs is updated
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Utility Flakes
    flake-parts.follows = "clan-core/flake-parts";
    import-tree.url = "github:vic/import-tree";
  };

  nixConfig = {
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-cache:4FILs79Adxn/798F8qk2PC1U8HaTlaPqptwNJrXNA1g="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    extra-substituters = [
      "https://install.determinate.systems"
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
        inputs.mkdocs-flake.flakeModules.default
        inputs.clan-core.flakeModules.default
        inputs.home-manager.flakeModules.home-manager
      ];
    };
}
