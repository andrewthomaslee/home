# devenv CLI entry point (`devenv shell`) — imports the shared module and
# wires the pkgs attributes devenv/default.nix expects (`unstable`,
# `clan-cli`) from the devenv.yaml inputs. The flake entry point
# (flake-parts/devShells.nix) gets the same attributes from
# overlays/default.nix instead.
#
# devenv/default.nix must stay free of flake-only references (`inputs`,
# `self'`) — that is what makes it evaluable by both entry points.
{inputs, ...}: {
  imports = [./devenv];

  # Agent sandbox variant activated with `devenv --profile agent shell`.
  # Shares the generic image (no host worktree) and adds agent-runtime
  # conveniences (token credential helper, ephemeral agent state).
  profiles.agent.module.imports = [./devenv/agent.nix];

  overlays = [
    (_final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (prev.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };

      clan-cli = inputs.clan-core.packages.${prev.stdenv.hostPlatform.system}.clan-cli;
    })
  ];
}
