# Shared devenv module — evaluated by BOTH entry points:
#   1. devenv CLI (`devenv shell`): root devenv.nix imports this directory.
#   2. flake-parts (`nix develop`): flake-parts/devShells.nix imports it.
#
# Hard rule: no flake-only references (`inputs`, `self'`) here. This module
# evaluates inside devenv's own module system, where `inputs` means
# devenv.yaml inputs, not the flake's. Flake values that packages need are
# injected as pkgs attributes via overlays:
#   - flake mode: overlays/default.nix provides `unstable` and `clan-cli`.
#   - CLI mode: the root devenv.nix overlay provides the same attributes
#     from the devenv.yaml inputs (pinned to the same revs as flake.lock).
{
  pkgs,
  lib,
  ...
}: {
  # ------ Packages ------ #
  packages =
    [
      pkgs.clan-cli
    ]
    ++ (with pkgs.unstable; [
      alejandra
      bash
      bun
      deadnix
      disko
      statix
    ]);

  # ------ Environment ------ #
  # Repo root + clan dir (required by the clan CLI), and the gitignored
  # .env loaded via varlock (SOPS_AGE_KEY, GITHUB_TOKEN, ...).
  enterShell = ''
    export REPO_ROOT="$(git rev-parse --show-toplevel)"
    export CLAN_DIR="$REPO_ROOT"
    eval "$(bunx varlock load --format shell)"
  '';

  # devenv needs to query the working directory; pure evals (flake
  # consumers) have no PWD fallback — point them at a writable scratch dir
  # instead of failing eval.
  devenv.root = let
    pwd = builtins.getEnv "PWD";
  in
    if pwd == ""
    then "/tmp/devenv-pure-root"
    else pwd;

  # No container use case here; the flake-parts module would generate
  # container-shell/container-processes outputs that throw at eval time
  # without nix2container/mk-shell-bin inputs.
  containers = lib.mkForce {};

  # The repo loads secrets via varlock in enterShell, not .env — silence
  # devenv's "consider dotenv" hint.
  dotenv.disableHint = true;
}
