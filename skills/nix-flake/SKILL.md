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

Nest attribute sets; one path segment per level, and never repeat a prefix
across sibling lines. Keys with a single member stay flat dotted; keys
with two or more members are written once and nested:

```nix
# good: single members flat, multi-member keys nested once
{
  homeSpec = {
    programs = {
      firefox.enabled = true;
      spotify.enabled = true;
    };
    shell.bash.enabled = true;
  };
}

plugins = {
  cc-safety-net.enable = true;   # single member: flat
  morph-fast-apply = {           # three members: nested once
    enable = true;
    apiKeyFile = "/path/to/key";
    model = "auto";
  };
};
```

```nix
# bad: quoted identifiers, repeated prefixes (quoted or not), mixed styles
{
  homeSpec."programs".firefox.enabled = true;
  homeSpec."programs".spotify.enabled = true;
  homeSpec.shell.bash.enabled = true;
}

plugins = {
  "morph-fast-apply".enable = true;
  "morph-fast-apply".apiKeyFile = "/path/to/key";
  "morph-fast-apply".model = "auto";
};
```

statix's `repeated_keys` lint only fires on 3+ adjacent repeats; this rule
is stricter — 2+ assignments of the same prefix in one attrset are a
violation, adjacency irrelevant. Enforce it while writing, not by waiting
for the linter.

### Attribute keys and quoting

Attribute keys are identifiers, and Nix identifiers legally contain
hyphens (`cloudflare-docs`, `morph-fast-apply`) and trailing apostrophes
(`self'`). Identifier keys are therefore **never quoted**:

```nix
# good
mcp = {
  cloudflare.enable = true;
  cloudflare-docs.enable = true;
};
```

```nix
# bad: unnecessary quotes
mcp = {
  cloudflare.enable = true;
  "cloudflare-docs".enable = true;
};
```

Quote a key only when it is not an identifier: it contains `/` or `.`
(`xdg.configFile."opencode/skills"`, `etc."vm-mcp-probe.py"`) or starts
with a digit. When a quoted key has multiple members, quote it once at its
own nesting level, never per sibling line. camelCase is preferred for new
multi-word keys but not enforced — keep existing names, never rename for
style.

### Boolean toggles

For boolean toggles you control (new options, new modules), prefer
`setting.enabled = true` over `setting.enable = true` where possible.
Not strictly enforced: standard NixOS and home-manager options are named
`enable` (`mkEnableOption` generates `enable`), and existing options are
never renamed for this — apply it where the naming is yours to choose.

### inherit

One `inherit (source) ...` statement per source per attrset. Never split
members of the same source across two `inherit` statements:

```nix
# good
services.ollama = {
  inherit (cfg) package port loadModels;
};

# bad: duplicated source
services.ollama = {
  inherit (cfg) package;
  inherit (cfg) port loadModels;
};
```

statix's `manual_inherit_from` lint converts `x = cfg.x;` into `inherit
(cfg) x;` but does not merge duplicates — consolidate by hand.

### Repo-root paths

Reference repo-root paths through `customLib.custom.relativeToRoot`
(`relativeToRoot "skills"`), never through fragile `../../` chains in
module code, and never by defining a local
`relativeToRoot = lib.path.append ../../.` clone. Scope: NixOS modules get
`customLib` via `_module.args` (set in `nixosModules/default`);
home-manager modules get it via `home-manager.extraSpecialArgs`, set once
in `nixosModules/default` — not per clan service, or non-clan consumers
(KubeVirt VM packages, test VMs) lose it.

One hard exception: a NixOS module whose **config value** needs a
repo-root path cannot take `customLib` as a module arg — args are
resolved lazily through `config._module.args`, which is circular while
`config` itself is being evaluated (clan machine evals die with
`attribute 'customLib' missing`). There, read the file with a direct path
literal and comment why:

```nix
# machines.json lives at the repo root; a module arg here would be
# circular (config._module.args lookup while config is evaluating)
machinesJson = builtins.fromJSON (builtins.readFile ./../../machines.json);
```

Home-manager modules are unaffected — `extraSpecialArgs` is a separate
eval channel, so `relativeToRoot` is always safe there.

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

### Enforcement

What CI automates (`checks.lint`, built by `nix flake check`):

| Tool | Catches |
|---|---|
| alejandra | formatting |
| statix `repeated_keys` | same key assigned 3+ times, adjacent |
| statix `manual_inherit*` | assignments that should be `inherit` |
| deadnix | unused bindings and arguments |

What is convention the agent must enforce itself (CI cannot see it):

- quoting rule — no quotes on identifier keys
- 2+-member nesting (statix needs 3+ adjacent repeats)
- inherit consolidation
- `relativeToRoot` for repo-root paths
- `enabled` preference

Fix violations in passing whenever you touch a file; write new code right
the first time. When a rule and a linter disagree, the rule wins — and if
a linter's suggestion would violate a rule (e.g. `inherit` with double
parentheses), restructure so both are satisfied.

## Tool loop (mandatory)

Run this loop before claiming any Nix work is done — in order:

```
1. nix fmt .                      # format
2. statix check .                 # lint (anti-patterns)
3. deadnix --fail .               # dead code; --fail exits 1 on findings
4. nix flake check --show-trace   # eval every output
5. nix build .#<thing-you-touched> -L   # real build, -L = logs
```

`--fail` on deadnix makes findings fatal; `-e`/`--edit` removes them and
writes the files — run it, review the diff, keep or revert. In module-heavy
repos, unused module args are common; `deadnix -l -L --fail .` tolerates
them (ignores unused lambda args/attrset-pattern names) if the repo's
convention accepts them — follow the repo's `AGENTS.md`/gate, not taste.

If a tool is not in the environment, run it through nixpkgs instead of
skipping:

```
nix run nixpkgs#statix -- check .
nix run nixpkgs#deadnix -- --fail .
```

These three tools belong in the repo's devShell (`packages = [alejandra
statix deadnix ...]`) **and** in a gate, so lint/format failures break the
build instead of relying on an agent's goodwill. The gate is either a
`checks.lint` derivation or a CI step; see
[flakehub-ci.md](references/flakehub-ci.md) for a worked example.

When fixing mechanically, run the fixers in this order: `deadnix -e .`,
then `statix fix .`, then `nix fmt .` — deadnix removes unused bindings
first (it can leave `{...}:` patterns behind), statix then normalizes what
remains (e.g. `{...}:` → `_:`), and alejandra settles formatting last.

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
