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
  };
}
