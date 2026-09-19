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
    kubenix = {
      url = "github:hall/kubenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.flake-parts.follows = "flake-parts";
    };

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

    # MCP-NixOS — MCP server for NixOS / Home Manager / nix-darwin
    # package & option search (opencode mcp server).
    mcp-nixos = {
      url = "github:utensils/mcp-nixos";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ArtifactHub MCP — stdio MCP server for Helm charts on artifacthub.io
    # (opencode mcp server). Repo has no flake.nix, so the source tree is
    # pinned to the v1.1.1 tag and built with buildNpmPackage in
    # packages/artifacthub-mcp.nix.
    artifacthub-mcp = {
      url = "github:AlexW00/artifacthub-mcp?ref=v1.1.1";
      flake = false;
    };

    # Headroom — context compression layer for AI agents.
    # Pinned to the v0.37.0 manylinux_2_28 x86_64 wheel (abi3, compatible with
    # CPython 3.10–3.13). This is the prebuilt maturin/Rust extension; using
    # the wheel avoids rebuilding the cdylib from source. Used as `src` for
    # buildPythonApplication { format = "wheel"; } in packages/headroom.nix.
    headroom = {
      url = "https://files.pythonhosted.org/packages/72/b8/16878cf4fe6fc390a0d22025b671468619db690ff14c1b103ace4b5e35f9/headroom_ai-0.37.0-cp310-abi3-manylinux_2_28_x86_64.whl";
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

    # Payload CMS AI agent skills (opencode skills; source tree, not a
    # flake). Root `skills/` dir with `payload` and `cms-migration`.
    skills-payloadcms = {
      url = "github:payloadcms/skills";
      flake = false;
    };

    # Splashtop Streamer — remote-access daemon, Ubuntu amd64 tarball containing the .deb
    splashtop-streamer = {
      url = "https://download.splashtop.com/linux/STB_CSRS_Ubuntu_v3.8.2.0_amd64.tar.gz";
      flake = false;
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
      ];

      # Expose flake.debug.options (module-system declarations) for nixd's
      # "flake-parts" option provider and `nix repl` inspection.
      # https://flake.parts/debug
      debug = true;

      imports = [
        (inputs.import-tree ./flake-parts)
        inputs.mkdocs-flake.flakeModules.default
        inputs.clan-core.flakeModules.default
        inputs.home-manager.flakeModules.home-manager
      ];
    };
}
