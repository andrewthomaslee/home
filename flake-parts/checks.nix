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
    checks = {
      lint =
        pkgs.runCommand "lint" {
          nativeBuildInputs = with pkgs; [alejandra statix deadnix];
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
      devenv-lock-drift =
        pkgs.runCommand "devenv-lock-drift"
        {
          nativeBuildInputs = [pkgs.jq];
          flakeLock = "${self}/flake.lock";
          devenvLock = "${self}/devenv.lock";
        }
        ''
          status=0
          for input in nixpkgs nixpkgs-unstable clan-core nix2container mk-shell-bin; do
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

      # Skill frontmatter gate: pi and kimi-code parse SKILL.md frontmatter
      # with JS YAML libraries that reject ': ' (colon+space) inside an
      # unquoted plain scalar and then SILENTLY skip the skill (pi reports
      # a skill conflict, kimi logs "Skipping invalid skill"). PyYAML
      # enforces the same restriction, so this fails `nix flake check`
      # before a broken skill reaches hosts or the code-agent image.
      skill-frontmatter =
        pkgs.runCommand "skill-frontmatter"
        {
          nativeBuildInputs = [
            (pkgs.python3.withPackages (ps: [ps.pyyaml]))
          ];
        }
        ''
          python3 ${pkgs.writeText "check-skill-frontmatter.py" ''
            import pathlib
            import re
            import sys

            import yaml

            root = pathlib.Path(sys.argv[1])
            failed = False
            for skill_md in sorted(root.glob("*/SKILL.md")):
              text = skill_md.read_text(encoding="utf-8")
              match = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", text, re.DOTALL)
              if not match:
                print(f"FAIL {skill_md}: missing YAML frontmatter block", file=sys.stderr)
                failed = True
                continue
              try:
                meta = yaml.safe_load(match.group(1))
              except yaml.YAMLError as error:
                print(f"FAIL {skill_md}: frontmatter is not parseable YAML: {error}", file=sys.stderr)
                failed = True
                continue
              if not isinstance(meta, dict) or not meta.get("name") or not meta.get("description"):
                print(f"FAIL {skill_md}: frontmatter must set 'name' and 'description'", file=sys.stderr)
                failed = True
                continue
              if meta["name"] != skill_md.parent.name:
                print(
                  f"FAIL {skill_md}: name '{meta['name']}' does not match "
                  f"directory '{skill_md.parent.name}'",
                  file=sys.stderr,
                )
                failed = True
            sys.exit(1 if failed else 0)
          ''} ${self}/skills
          touch $out
        '';
    };
  };
}
