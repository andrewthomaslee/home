{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: {
    # Lint gate: alejandra (format), statix (anti-patterns), deadnix (dead
    # bindings). Runs inside `nix flake check`, so CI fails on findings.
    # Source is filtered to .nix files so docs/vars changes don't
    # invalidate the check and secrets never enter this closure. Add any
    # future statix.toml to the suffix list or statix won't see it.
    checks.lint =
      pkgs.runCommand "lint" {
        nativeBuildInputs = with pkgs.unstable; [alejandra statix deadnix];
      } ''
        cd ${lib.sources.sourceFilesBySuffices self [".nix"]}
        alejandra --check .
        statix check .
        deadnix --fail .
        touch $out
      '';

    # devenv lock drift: devenv.yaml/devenv.lock pin nixpkgs, nixpkgs-unstable
    # and clan-core to the exact revisions flake.lock holds, so both
    # lockfiles reference identical sources (same builds, shared
    # devenv.cachix.org cache). Fails when flake.lock was bumped without
    # bumping the devenv pins (or vice versa) — update both in one commit
    # (`nix flake update <input>` + edit devenv.yaml + `devenv update`).
    checks.devenv-lock-drift =
      pkgs.runCommand "devenv-lock-drift"
      {
        nativeBuildInputs = [pkgs.jq];
        flakeLock = "${self}/flake.lock";
        devenvLock = "${self}/devenv.lock";
      }
      ''
        status=0
        for input in nixpkgs nixpkgs-unstable clan-core; do
          flake_rev=$(jq -r ".nodes.\"$input\".locked.rev // empty" "$flakeLock")
          devenv_rev=$(jq -r ".nodes.\"$input\".locked.rev // empty" "$devenvLock")
          if [ -z "$flake_rev" ]; then
            echo "FAIL: flake.lock has no locked rev for $input" >&2
            status=1
          elif [ "$flake_rev" != "$devenv_rev" ]; then
            echo "FAIL: $input drifted: flake.lock=$flake_rev devenv.lock=$devenv_rev" >&2
            echo "      Update devenv.yaml pins + devenv update in the same commit." >&2
            status=1
          fi
        done
        if [ "$status" -ne 0 ]; then exit 1; fi
        touch $out
      '';
  };
}
