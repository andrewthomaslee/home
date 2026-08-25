{
  description = "Dendritic Determinate Flake";
  inputs = {
    # Determinate Nix
    # https://docs.determinate.systems/guides/advanced-installation/
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # Nixpkgs
    nixpkgs.follows = "clan-core/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Clan.lol
    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";

    # Clan.lol Community
    clan-community = {
      url = "git+https://git.clan.lol/andrewthomaslee/clan-community.git?ref=feat/rancher";
      inputs.clan-core.follows = "clan-core";
    };

    # Mkdocs
    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Home-manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # KDE
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Utility Flakes
    flake-parts.follows = "clan-core/flake-parts";
    import-tree.url = "github:denful/import-tree";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0";

    # ------ Packages ------ #
    # Zen Browser
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Scripts
    moscripts = {
      url = "https://flakehub.com/f/andrewthomaslee/moscripts/*";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # neofetch for kube
    kubefetch.url = "https://flakehub.com/f/andrewthomaslee/kubefetch/*";

    # Jovian NixOS
    jovian.url = "github:Jovian-Experiments/Jovian-NixOS";

    # OpenCode
    opencode = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Headroom — context compression layer for AI agents.
    # Pinned to the v0.36.5 manylinux_2_28 x86_64 wheel (abi3, compatible with
    # CPython 3.10–3.13). This is the prebuilt maturin/Rust extension; using
    # the wheel avoids rebuilding the cdylib from source. Used as `src` for
    # buildPythonApplication { format = "wheel"; } in homeModules/headroom.nix.
    headroom = {
      url = "https://files.pythonhosted.org/packages/15/c9/650195df8133b0f2ae5156bd9780fd70e17d8cead361016983e72d629697/headroom_ai-0.36.5-cp310-abi3-manylinux_2_28_x86_64.whl";
      flake = false;
    };

    agents = {
      url = "git+https://code.m3ta.dev/m3tam3re/AGENTS";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    skills-anthropic = {
      url = "github:anthropics/skills";
      flake = false;
    };
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
