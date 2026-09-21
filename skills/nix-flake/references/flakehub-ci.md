# CI: GitHub Actions, Determinate, FlakeHub

Conventions for building and shipping flake artifacts with GitHub Actions.
Stack: Determinate Nix on the runners, FlakeHub Cache for caching,
flakehub-push for publishing, self-hosted runners (ARC) where available.

## Runner setup

One composite action installs Nix and turns on caching; every Nix-using job
calls it instead of repeating steps:

```yaml
# .github/actions/setup-nix/action.yml
name: 'Setup Nix'
description: 'Installs Nix and configures FlakeHub cache'
runs:
  using: "composite"
  steps:
    - uses: DeterminateSystems/determinate-nix-action@v3
    - uses: DeterminateSystems/flakehub-cache-action@main
```

Prefer the pinned major (`@v3`) over `@main` for the installer; cache/push
actions may track `@main`.

- `determinate-nix-action` installs Determinate Nix — never
  `nix-installer-action` alone, channels, or apt-based installs.
- `flakehub-cache-action` is the only cache. Zero-config, OIDC-based.
  Do not add Magic Nix Cache, Cachix, or `actions/cache` for `/nix/store`.

### Permissions

Every Nix-using job needs OIDC — FlakeHub Cache exchanges the workflow's
`id-token` for a cache session:

```yaml
permissions:
  id-token: write
  contents: read
```

Set `permissions` at workflow level (entry workflows) and re-declare it in
reusable-workflow jobs; `actions/checkout` with `persist-credentials: false`
for publish/docs jobs that do not need git credentials.

### Runners

Preferred: self-hosted GitHub Actions Runner Controllers (ARC) scale sets
with Determinate Nix baked in. Use the repo's actual scale-set name for
`runs-on`; fall back to `ubuntu-latest` only if no runner set exists:

```yaml
runs-on: <arc-runner-scale-set>   # e.g. arc-runner-set, or org/org-label
```

Self-hosted runner notes:

- Ephemeral runners have cold `/nix/store`s — do not rely on a warm store;
  FlakeHub Cache does the heavy lifting. That is the point of the stack.
- `/dev/kvm` is the gate for VM tests: only jobs on a runner with KVM may
  run VM-test builds. Guard such jobs (see vm-tests.md); hosted
  `ubuntu-latest` runners have no KVM, so keep KVM builds out of `checks`.
- Keep heavy `nix build` work in steps, not in the runner image, so the
  runner image stays small and generic.

## Workflow layout

- Reusable workflows are prefixed with `_`
  (`.github/workflows/_build-machines.yml`), called as
  `uses: ./.github/workflows/_x.yml`. Entry workflows (`ci.yml`,
  `release.yml`) stay thin: trigger + permissions + `needs` chain.
- `ci.yml` runs on `push` to `main` (plus PR if wanted) with
  `concurrency: cancel-in-progress` keyed on the workflow/ref.
- Release machinery is manual (`workflow_dispatch`) — tags and publishing
  are deliberate acts, not side effects of merges.
- Build jobs are matrices over flake attributes, `fail-fast: false`:

```yaml
strategy:
  fail-fast: false
  matrix:
    artifact: [devShell, some-package, some-service]
steps:
  - uses: actions/checkout@v6
  - uses: ./.github/actions/setup-nix
  - run: nix build .#${{ matrix.artifact }} --show-trace -L
```

Every CI-buildable thing should be reachable as `nix build .#<attr>`
(including the devShell, via `packages.devShell = self'.devShells.default`).
Machine configs build via
`nix build .#nixosConfigurations.<name>.config.system.build.toplevel`.
Keep matrices in sync with reality (e.g. a new machine added to
`inventory.nix` must be added to the build matrix too).

## Lint gate

Format/lint is a hard gate, not an agent convention. Wire the three tools
into the devShell and one of:

**Option A — `checks.lint` derivation** (fails `nix flake check`, which CI
already runs):

```nix
{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: {
    checks.lint = pkgs.runCommand "lint" {
      nativeBuildInputs = with pkgs; [alejandra statix deadnix];
    } ''
      cd ${lib.sources.sourceFilesBySuffices self [".nix"]}
      alejandra --check .
      statix check .
      deadnix --fail .
      touch $out
    '';
  };
}
```

Filtering the source to `.nix` files keeps docs/asset changes from
invalidating the check and keeps secrets out of its closure. If the repo
gains a `statix.toml`, add it to the suffix list or statix won't see it.
(Verify exact flags per tool version: `deadnix --help`,
`statix check --help`; deadnix fails on findings with `--fail`.)

**Option B — dedicated CI step** (fast feedback before the full check):

```yaml
- uses: ./.github/actions/setup-nix
- run: |
    nix run nixpkgs#alejandra -- --check .
    nix run nixpkgs#statix -- check .
    nix run nixpkgs#deadnix -- --fail .
```

`flake-checker` (`DeterminateSystems/flake-checker-action@main`) runs
alongside as the lockfile-hygiene gate; it is eval-only, no build.

## Publishing to FlakeHub

`flakehub-push` publishes on demand, not on every push:

```yaml
flakehub:
  needs: [flake-check, build-machines, build-artifacts, tag]
  permissions:
    id-token: write
    contents: read
  steps:
    - uses: actions/checkout@v6
    - uses: ./.github/actions/setup-nix
    - uses: DeterminateSystems/flakehub-push@main
      with:
        visibility: public            # private is the safer default for org work
        name: <org>/<repo>
        include-output-paths: true
        rolling: true                 # rolling release ...
        rolling-minor: 3              # ... published as 0.3.<n>
```

- `include-output-paths: true` persists resolved store paths with the
  release — required for `fh resolve` / `fh apply` deploys. Turn it on for
  anything machines consume.
- `rolling: true` + `rolling-minor: N` publishes `0.N.<count>` without git
  tags. Alternatively drive versions from git tags (tag-driven semver);
  pick one model per repo and stay consistent.
- Publishing depends on green check + builds, never runs first.
- Keep flakes private by default in org contexts; publish publicly only
  what is genuinely meant for the wider Nix ecosystem.

## Deployment

Pull-based from FlakeHub — machines pull, CI never SSH-pushes:

```
fh apply nixos "https://flakehub.com/f/<org>/<repo>/*" switch   # or boot|test|dry-activate
```

`fh apply` resolves the latest release (`/*` = any semver; constrain with
`/0.3` etc.) and fetches prebuilt closures from FlakeHub Cache when
`include-output-paths` was enabled at publish time — no evaluation on the
target machine. Wrap the command as a tiny package (`apply-now`,
`apply-and-reboot`) so machines have a one-word deploy verb; a reboot
variant should first `nixos-rebuild boot` / `fh apply ... boot`, verify the
new generation, then reboot cleanly.

## Input freshness

- `DeterminateSystems/update-flake-lock` on a weekly cron opens update PRs
  (`pr-labels: [dependencies, automated]`); pair it with `flake-checker`.
- Update inputs in small increments — frequent small updates beat rare
  big-bang `nix flake update`.
