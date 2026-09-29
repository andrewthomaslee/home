# OpenCode References — Attachable Doc Bundles

References are OpenCode V2's named access to directories outside the
current project ([v2 docs](https://opencode.ai/v2/docs/references/)):
entries in `opencode.json` under `references`, keyed by alias, each
pointing at a local `path` (or a git `repository`) with an optional
`description` that gets advertised in agent instructions.

This flake ships a set of curated reference doc bundles from the repo's
top-level `references/` tree — deep "how things work" material
(replacing the former per-skill `references/` files in
`skills/nix-flake/`) — and manages them declaratively in
`flake-parts/homeModules/opencode.nix`.

## How it works

Each available reference has a fixed alias and module-default
description. Enabling one:

1. installs the repo's `references/<name>/` tree as a symlink at
   `~/.config/opencode/references/<name>` (a `pkgs.linkFarm` over the
   enabled subset),
2. emits a `settings.references.<name>` entry in the generated
   `~/.config/opencode/opencode.json`:

```json
{
  "references": {
    "nix-style": {
      "path": "~/.config/opencode/references/nix-style",
      "description": "Nix code style + tool loop (user preferences): ..."
    }
  }
}
```

3. adds `read` + `external_directory` permission rules for
   `<home>/.config/opencode/references/**` to the ordered permissions
   array — reference reads happen outside the active project location,
   so `external_directory` is required, not just `read`.

Entries with a description are advertised in agent instructions
automatically (alias + resolved path), so agents discover them without
a manual attach; the description's "when to use" wording is what drives
loading.

## Options

```
homeSpec.programs.opencode.references.<name>.enable          # bool, default false
homeSpec.programs.opencode.references.<name>.description     # str, module default per alias
```

Available aliases and coverage:

| Alias | Covers |
|---|---|
| `nix-style` | Nix code style (nesting, quoting, inherit, repo-root paths, module system), the mandatory alejandra/statix/deadnix tool loop, devShell + agent contract |
| `flake-parts` | mkFlake/perSystem mechanics, what the infra provides, input handling, lint gate, integrations |
| `import-tree` | flake-parts auto-import: mechanics, tree layout conventions, agent rules |
| `determinate` | Determinate docs map, FlakeHub publishing/cache/private flakes, semver (rolling `0.1.<commits>`), `fh` CLI + `fh apply` |
| `home-manager` | HM with flakes + flake-parts, worked example: `homeModules/profiles/netsa.nix` |
| `clan-core` | inventory, clanServices, exports + strict-eval check, vars/generators, clan CLI, machine updates, clanService VM tests |
| `clanservices` | Authoring clan.service modules in the official style: module skeleton + manifest options, roles/interfaces, perInstance/perMachine args, exports (mkExports/selectExports), vars generators, registration + inventory instances, static-only verification |
| `devenv` | devenv 2.x CLI reference, CLI-native vs flake embedding, borg hybrid pattern, devcontainer.json, monorepo/polyrepo, containers/K8s, Claude Code integration |
| `vm-tests` | Hermetic NixOS VM tests: structure, size variants, running, agent loop |
| `lib` | This repo's `customLib` (`relativeToRoot`, `mkLib`, injection channels, specialArgs gotcha) + the AGENTS flake lib (`mkSkills` skill cherry-picking, `loadAgents`, `agentsJson`, `skills-runtime`) |
| `cilium` | Cilium 1.20.x: the v2 CRD-based BGP control plane (all four CRDs, advertisement types, auto-discovery, timers, no-BFD), LB IPAM, L2 announcements, network policy language, troubleshooting conditions + symptom table, operation playbook |
| `disko` | Disko declarative disk partitioning: the `disko.devices` tree, CLI modes vs the NixOS module's auto-injected `fileSystems`/`boot`/`swapDevices`, clan-core auto-import of `machines/<name>/disko.nix` (module arrives via clanCore), ext4/btrfs/zfs recipes, LUKS + clan vars `neededFor="partitioning"` keys (initrd SSH unlock), 2-disk RAID1/ZFS-mirror redundancy |
| `openebs` | OpenEBS 4.6.x Kubernetes CSI storage: the umbrella chart's five engines (Local PV hostpath/LVM/ZFS/rawfile + Replicated PV Mayastor), per-engine node prerequisites (HugePages, `nvme_tcp`, VGs/zpools), StorageClass parameter tables, DiskPool CRs, NVMe-oF TCP, KubeVirt live migration, CloudNativePG storage choice, air-gapped install (with verbatim save/push scripts), upgrades, troubleshooting symptom tables |
| `clanservices` | Authoring clan.service modules in the official clan-core style: module skeleton + manifest options (constraints/categories/readme), roles/interfaces, perInstance/perMachine argument tables, multi-instance namespacing, experimental exports (`mkExports`/`selectExports`, scope ownership), vars generators, passing `self`/`pkgs`, this repo's flake-module registration + inventory instances, static-only verification |

The reference sources are the repo's own curated docs (the
`nix-flake` skill's former `references/*.md`, ported and extended with
determinate/home-manager material). Editing them is a normal repo
change; the installed copies update on the next home-manager
activation.

## Always-on hook for style rules

References are read-on-demand. To keep the user's Nix-writing
preferences in front of agents that write `.nix` files, the
per-machine context file (`machine-<host>.md`, injected into every
session's system prompt by the opencode module) gains a pointer line
whenever `references.nix-style.enable` is on:

```
When writing or editing any .nix file: read the opencode reference nix-style ...
```

## Enablement

Defaults are off for all users; `profile-netsa` (the dev profile)
enables all thirteen aliases:

```nix
# flake-parts/homeModules/profiles/netsa.nix
homeSpec.programs.opencode.references = {
  nix-style.enable = true;
  flake-parts.enable = true;
  import-tree.enable = true;
  determinate.enable = true;
  home-manager.enable = true;
  clan-core.enable = true;
  clanservices.enable = true;
  devenv.enable = true;
  vm-tests.enable = true;
  lib.enable = true;
  cilium.enable = true;
  disko.enable = true;
  openebs.enable = true;
};
```

## Adding a reference

1. Create `references/<name>/index.md` (one directory per reference).
2. Add the alias + default description to `availableReferences` in
   `flake-parts/homeModules/opencode.nix` — the `lib.genAttrs` there
   auto-generates the `homeSpec.programs.opencode.references.<name>`
   option, so the options block needs no edit.
3. Enable it per profile (`references.<name>.enable = true;` in
   `flake-parts/homeModules/profiles/netsa.nix`).
4. `git add references/<name>/` — Nix evaluates the flake from the git
   tree, so untracked files are invisible to `nix build` /
   `nix flake check`.

The `add-skill-or-reference` custom skill carries these instructions to
agents at runtime. To add a skill instead, see [Skills](skills.md).

## Verify

- Eval + store path:
  `nix eval --raw .#nixosConfigurations.<name>.config.home-manager.users.netsa.xdg.configFile."opencode/references".source`
  — prints the `opencode-references` linkFarm store path; `ls` it to
  see the installed aliases.
- Config wiring:
  `nix eval --json .#nixosConfigurations.<name>.config.home-manager.users.netsa.programs.opencode.settings.references | jq keys`.
- `nix flake check --show-trace` evaluates all machines (CI parity).
