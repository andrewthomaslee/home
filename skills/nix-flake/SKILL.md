---
name: nix-flake
description: Conventions and style guide for working in Nix flake repos — Determinate Nix, FlakeHub, GitHub Actions with self-hosted runners, nix build .#<thing>, alejandra/statix/deadnix, and hermetic NixOS VM tests. Use when editing any .nix file, adding flake inputs/outputs/packages/modules, wiring CI for a flake, or creating and running VM tests.
---

# Nix Flake Conventions

Generic conventions for any flake-based repo. The user runs Determinate Nix
(everywhere: workstations, CI runners, machines), publishes to
[FlakeHub](https://docs.determinate.systems/flakehub/), and builds and ships
artifacts with GitHub Actions, primarily as `nix build .#<thing>`. Assume
Determinate Nix on every host: never emit `experimental-features` boilerplate,
install-script workarounds, channel setup, or `nix-env` advice.

## Non-negotiables

- Flakes only. `nix build .#<attr>` is *the* build interface. No
  `nix-build`, no `shell.nix`/`default.nix` entry points, no channels, no
  `<nixpkgs>` / `NIX_PATH` lookups.
- `flake.lock` is committed. Update it with `nix flake update <input>` or
  `nix flake lock --update-input`; never hand-edit the lock file.
- Nix evaluates the flake from the git tree. `git add` every new file
  (`.nix`, test files, skills, assets) before `nix build` /
  `nix flake check` — untracked files do not exist to Nix.
- No secrets in Nix source or the store (it is world-readable). Secrets come
  from a provisioning layer (sops-nix, clan vars, CI OIDC, GitHub
  Actions secrets), never from expressions.
- Never reach for `--impure`, `--no-sandbox`, `sandbox = false`, or
  `builtins.readFile /etc/...` to make something build. Impurity hides bugs,
  breaks FlakeHub Cache reproducibility, and fails on CI. If something needs
  the outside world, make it an input (a flake input, a store path, a test
  fixture) instead.

## Style guide

### Attribute nesting

Nest attribute sets; one path segment per level. Never quote a path
component unless the key is not a valid identifier (hyphenated names,
numbers). Never repeat a prefix across sibling lines.

```nix
# good
{
  homeSpec = {
    programs = {
      firefox.enabled = true;
      spotify.enabled = true;
    };
    shell.bash.enabled = true;
  };
}
```

```nix
# bad: quoted identifiers, repeated prefixes, mixed styles
{
  homeSpec."programs".firefox.enabled = true;
  homeSpec."programs".spotify.enabled = true;
  homeSpec.shell.bash.enabled = true;
}
```

Quoting is only correct when required, e.g. `plugins."morph-fast-apply".enable`
— the key contains a hyphen, so the quoted segment is mandatory. Mixing
styles when unquoted works (`homeSpec.shell.bash.enabled` vs
`homeSpec."shell".bash.enabled`) is still wrong: pick the unquoted form
whenever the key is an identifier.

### Module system

- Options: `lib.mkEnableOption` for booleans; `lib.mkOption` always with
  `type`, `default`, and a `description` (write it for the next reader).
- Option namespaces: use one namespace per concern (`hostSpec.*`,
  `homeSpec.*`, or the repo's equivalent) so modules compose without
  collisions.
- Set values with `lib.mkIf`, `lib.mkDefault`, `lib.mkMerge`, and
  `lib.mkForce` (sparingly — `mkForce` is a smell in library code). Use
  `lib.optionals`/`lib.optional` instead of `++ (if c then [...] else [])`.
- `assertions = [ { assertion = ...; message = "user-facing: ..."; } ]` for
  mutual exclusions and config invariants — an error message a user can act
  on beats a weird eval failure.

### Language mechanics

- `inherit` from enclosing scopes (`{inherit inputs self pkgs;}`); the
  formatter aligns it, let it.
- `with pkgs;` only inside a small list literal where it reads better
  (`(with pkgs.unstable; [ ... ])`); never `with` around a whole module
  body or over `lib`.
- Comments explain *why*, not *what* — especially for pins, workarounds, and
  anything a future reader would be tempted to "clean up". Include the bug
  link where a workaround exists.
- Kebab-case attribute and file names. One concern per file; let the
  repo's auto-import mechanism pick it up (flake-parts + import-tree style:
  new files are auto-loaded, there is no import list to update).

### Formatting

alejandra is the formatter. It owns the layout: never hand-format Nix,
never fight its choices, never merge conflict over whitespace. After every
edit:

```
nix fmt .          # write
nix fmt -- --check .   # verify without writing
```

If `nix fmt` fails with no path or with empty stdin, pass an explicit path
(`nix fmt .`).

## Tool loop (mandatory)

Run this loop before claiming any Nix work is done — in order:

```
1. nix fmt .                      # format
2. statix check .                 # lint (anti-patterns)
3. deadnix -f .                   # unused bindings (f = fix, -e = keep lambdas)
4. nix flake check --show-trace   # eval every output
5. nix build .#<thing-you-touched> -L   # real build, -L = logs
```

`-f` on deadnix writes fixes; run it, review the diff, keep or revert. If a
tool is not in the environment, run it through nixpkgs instead of skipping:

```
nix run nixpkgs#statix -- check .
nix run nixpkgs#deadnix -- -f .
```

These three tools belong in the repo's devShell (`packages = [alejandra
statix deadnix ...]`) **and** in a gate, so lint/format failures break the
build instead of relying on an agent's goodwill. The gate is either a
`checks.lint` derivation or a CI step; see
[flakehub-ci.md](references/flakehub-ci.md) for a worked example.

Paste the last failing/passing command and its exit status when reporting
results. "It should work" is not verification.

## Flake layout

- Prefer flake-parts: `imports = [ (inputs.import-tree ./flake-parts) ]`
  with `perSystem` modules; declare `systems` explicitly (e.g.
  `systems = ["x86_64-linux"];`).
- Use the standard output names: `packages`, `devShells`, `checks`,
  `apps`, `nixosConfigurations`, `homeModules`/`nixosModules`, `overlays`,
  `formatter`, `templates`.
- Make the devShell buildable and cacheable so CI can warm it:
  `packages.devShell = self'.devShells.default;` then `nix build .#devShell`.
- Expensive, KVM-dependent, or VM-booting outputs must NOT go in `checks`
  (`nix flake check` evaluates and often builds `checks`). Expose them under
  `legacyPackages.<system>.vmTests` — `nix flake check` does not walk it.
  See [vm-tests.md](references/vm-tests.md).
- Do not add a `nixConfig` block requiring extra `trusted-public-keys` /
  `extra-substituters` trust from consumers. In CI, caching is configured by
  the runner-side actions, not by the flake.

## Inputs

- Reference FlakeHub flakes by URL with semver wildcards:
  `https://flakehub.com/f/<org>/<repo>/*` (latest), `/0` or `/1.2` for a
  major or major.minor constraint. Update often and in small increments —
  stale nixpkgs inputs are the leading cause of painful upgrades.
- Deduplicate big inputs with `follows`
  (`nixpkgs.follows = "clan-core/nixpkgs";`) so one nixpkgs instance serves
  the whole graph. Surface a second channel as `pkgs.unstable` via an
  overlay, not by re-importing nixpkgs ad hoc.
- Pin binary artifacts (tarballs, wheels) as `flake = false` inputs so
  `flake.lock` carries the hash:
  `artifacthub-mcp = { url = "github:owner/repo?ref=v1.1.1"; flake = false; }`.
- One flake per versioned thing (Determinate's own advice): a CLI tool, a
  service's NixOS config, a docs site — publish each; consolidate later.
  Several flakes may live in one repo (monorepo-friendly).

## Working in a flake repo (agent contract)

1. Read `flake.nix` and the neighbouring module *before* editing; mirror
   the local patterns (namespaces, mkMerge usage, overlay routing) instead
   of importing your own style.
2. Never guess option or package names. Look them up (the `nix` MCP tool,
   search.nixos.org) and verify the exact attribute path — the repo may pin
   versions or scope packages under `pkgs.unstable` via an overlay.
3. Generated files (`flake.lock`, disko layouts, `facter.json`, clan
   `inventory.json`) are not hand-editable. Regenerate them with their
   generator, or leave them alone.
4. Prefer the smallest change that satisfies the request; do not refactor
   modules you did not need to touch.
5. Verify per the tool loop, and state which command verified the change.
   If you cannot build it (missing hardware, no KVM), say so explicitly.

## References (load on demand)

- [flakehub-ci.md](references/flakehub-ci.md) — GitHub Actions + Determinate
  actions, FlakeHub Cache and publishing, self-hosted runner notes,
  deployment via `fh`, lint-gate examples.
- [vm-tests.md](references/vm-tests.md) — hermetic NixOS VM tests: writing,
  running, size variants, driver mode, agent iteration loop.
