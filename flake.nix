{
  description = "Dendritic Determinate Flake";
  inputs = {
    # Determinate Nix
    # https://docs.determinate.systems/guides/advanced-installation/
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nix.inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix.inputs.git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixpkgs
    nixpkgs.follows = "determinate/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Flake-Parts
    flake-parts.follows = "determinate/nix/flake-parts";
    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        (inputs.import-tree ./flake-parts)
      ];
    };
}
