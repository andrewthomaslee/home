{
  description = "Dendritic Determinate Flake";

  nixConfig = {
    extra-substituters = [
      "https://openshell.cachix.org"
      "https://devenv.cachix.org"
      "https://cache.clan.lol"
      "https://nix-community.cachix.org"
      "https://chaotic-nyx.cachix.org"
      "https://cache.geninf.io"
    ];
    extra-trusted-public-keys = [
      "openshell.cachix.org-1:OAr5MunsfH5PZvUsfD08OtGx5RtcwdNZGJdU5FqLm5w="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n8ae7W70yP3m9y9633ndgliTLGsQI="
      "cache.geninf.io-1:uhEViaczNKSoerYM+w7uqXUzlAhnbEBKsFzgg9n3cvI="
    ];
  };

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
    # Pinned to the v2.0.16 release tag: v2 is a major rework (new plugin
    # API, new server API, native V2 config shape); see
    # https://opencode.ai/docs/migrate-v1/ for the breaking changes this
    # repo's homeModules/opencode.nix was migrated to.
    opencode = {
      url = "github:anomalyco/opencode?ref=v2.0.16";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # MCP-NixOS — MCP server for NixOS / Home Manager / nix-darwin
    # package & option search (opencode mcp server).
    mcp-nixos = {
      url = "github:utensils/mcp-nixos";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # devenv — developer environments CLI (auto-activation hook, `devenv
    # mcp` MCP server). Pinned to the release tag; builds are served by
    # the devenv.cachix.org substituter already trusted in
    # nixosModules/nix.nix.
    devenv.url = "github:cachix/devenv?ref=v2.3.1";
    # Required for devenv container builds:
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";

    openshell.url = "github:NVIDIA/OpenShell?ref=v0.1.2";

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

    # Whisper Dictation — local push-to-talk speech-to-text daemon (whisper.cpp)
    whisper-dictation.url = "github:jacopone/whisper-dictation";

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

    # David Ondrej's agent skills (source tree, not a flake). Skills live
    # two levels deep (skills/<category>/<name>/SKILL.md), so
    # homeModules/opencode.nix wires one mkSkills entry per category with
    # a deeper skillsDir.
    skills-davidondrej = {
      url = "github:davidondrej/skills";
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
        # devenv flake-parts module: evaluates devenv/default.nix through
        # devenv.shells.default (see flake-parts/devShells.nix) so
        # `nix develop` and the devenv CLI share one module.
        inputs.devenv.flakeModule
      ];
    };
}
