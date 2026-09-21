# OpenCode Harness

[OpenCode](https://opencode.ai) is the AI agent harness used across the
machines in this flake. It is managed **declaratively** — no imperative
config mutation: `flake-parts/homeModules/opencode.nix` merges everything
into `programs.opencode.settings`, and `~/.config/opencode/opencode.json`
is a symlink into the read-only Nix store. Two companion home-manager
modules extend the harness:

- `flake-parts/homeModules/opencode.nix` — settings: MCP servers, plugins,
  LSP, formatters, compaction, packages and wrappers
- `flake-parts/homeModules/headroom.nix` — context optimization
  ([Headroom](headroom.md)) and its proxy service

## Module options (`homeSpec.programs.opencode`)

| Option | Default | Description |
|---|---|---|
| `enable` | `false` | Enable OpenCode + the declarative configuration below |
| `enableDesktop` | `true` | Install `opencode-desktop` (Electron GUI). Disable for headless machines — saves ~2.4 GB (Electron + GTK stack) |
| `fullDevTools` | `true` | Install the full heavy dev toolset (`k3s`, `rke2`, `k3d`, `devpod`, `devcontainer`, `podman`, `gleam`, `terraform-ls`, `helm-ls`, `go_latest`). Disable for slim headless agents — keeps `docker`, `kubectl`, `helm` |

The packaging trims are what made the KubeVirt agent image drop from
~12 GB to ~2 GB — see [KubeVirt AI Agent](kubevirt-agent.md#image-optimization-trim-compress).

## What the module configures

- **MCP servers** — 13 servers under `mcp.<name>.enable` (nix, openrouter,
  playwright, github, cloudflare ×6, mdn, artifacthub, kubernetes, typeui),
  each hermetically packaged or hosted-remote. See
  [MCP Servers](mcp-servers.md).
- **Plugins** — four plugins under `plugins.<name>.enable` (cc-safety-net,
  morph-fast-apply, opencode-mem, devcontainers) wired with absolute store
  paths, nothing fetched from npm at runtime. See [Plugins](plugins.md).
- **Skills** — a merged skills folder (repo `skills/` + external flake
  inputs) symlinked to `~/.config/opencode/skills`. See [Skills](skills.md).
- **LSP**: nixd (`.nix`), helm_ls (`.yaml`/`.yml`), pyrefly (`.py`/`.pyi`),
  gleam (`.gleam`). The nixd entry replaces the previous `nil` one (the
  settings key must be `nixd` — that is opencode's built-in nixd LSP, and
  a different key would start both servers). It carries
  `initialization.nixd.nixpkgs.expr` for out-of-box completion in foreign
  repos — opencode spawns nixd with cwd = project root, so `toString ./.`
  evaluates the flake at the repo root and completion uses that flake's
  own nixpkgs. In non-flake dirs the expr eval fails; nixd logs it and
  keeps its startup default `import <nixpkgs> { }`, resolved through the
  `NIX_PATH` this module sets (this flake's nixpkgs). Repo-level
  `opencode.json` deep-merges over the global config, so a foreign flake
  can override the expr (borg does exactly this via
  `opencode-nixd-scaffold`). Exact-structure option overrides for this
  flake live in the repo-root `opencode.json` / `.vscode/settings.json`
  (machine-agnostic — the hostname is read from `/etc/hostname` at LSP
  eval time), scaffoldable elsewhere with `opencode-nixd-scaffold`.
  Built-in pyright is disabled: it would auto-download
  `pyright-langserver` at runtime (non-hermetic) and duplicate pyrefly's
  `.py` coverage.
- **Formatters**: alejandra (`.nix`), ruff (`ruff format`, `.py`/`.pyi`),
  gleam — all with `"$FILE"` placeholders and dotted extensions (OpenCode
  requires both; see the VM test history).
- **Compaction**: auto with `tail_turns = 32`.
- **Wrapper scripts** — `github-mcp-server-opencode` (exports the GitHub
  PAT, see [MCP Servers](mcp-servers.md#github-mcp-server)) and the Morph
  key wrapper (exports `MORPH_API_KEY`, see [Plugins](plugins.md)).

## Packages

`nix build .#<package>` outputs relevant to the harness:

| Package | Purpose |
|---|---|
| `kubernetes-mcp-server` | containers/kubernetes-mcp-server v0.0.66, hermetic `buildGoModule` (`flake-parts/packages/kubernetes-mcp-server.nix`) |
| `opencode-nixd-scaffold` | scaffolds per-repo `opencode.json` + `.vscode/settings.json` nixd overrides (`flake-parts/packages/opencode-nixd-scaffold.nix` + `.py`, `writers.writePython3Bin`) |
| `cc-safety-net`, `opencode-mem`, `opencode-morph-fast-apply`, `opencode-devcontainers` | plugin packages from `flake-parts/packages/opencode-plugins.nix` |
| `artifacthub-mcp` | ArtifactHub MCP binary (`flake-parts/packages/artifacthub-mcp.nix`) |

## Profiles

- **Dev profile** (`flake-parts/homeModules/profiles/netsa.nix`) — applied
  to `netsa` on the netsa-tagged dev machines (nixos, kamrui-h1, ghost)
  through the users clan service in `inventory.nix`. Opts into the MCP
  servers / plugins that need credentials or a cluster (typeui,
  kubernetes, github `pat`, cloudflare ×6, mdn, artifacthub, opencode-mem,
  devcontainers) and pairs with `hostSpec.services.nix-ld.enable = true`
  so prebuilt native binaries (onnxruntime) run.
- **Headless agent profile** (`flake-parts/homeModules/profiles/
  netsa-agent.nix`, `flake.homeModules.profile-netsa-agent`) — headless
  OpenCode-web machine profile used by the KubeVirt agent image; sets
  `enableDesktop = false`, `fullDevTools = false`, uses `headroom-slim`.
- The netsa tag itself (`clanServices/tags/netsa.nix`) carries only
  machine-level `hostSpec` options (nix-ld); all opencode opt-ins live in
  the dev profile.

## Files

| File | Purpose |
|---|---|
| `flake-parts/homeModules/opencode.nix` | everything on this page: MCP under `mcp.<name>.enable`, plugins under `plugins.<name>.enable`, LSP (nixd, helm_ls, pyrefly, gleam), formatters, compaction, `enableDesktop`/`fullDevTools` trims, PAT + Morph wrappers |
| `flake-parts/homeModules/headroom.nix` | headroom options + `headroom-proxy.service` user unit — see [Headroom](headroom.md) |
| `flake-parts/homeModules/profiles/netsa.nix` | dev profile: opencode MCP/plugin opt-ins |
| `flake-parts/homeModules/profiles/netsa-agent.nix` | headless AI agent profile |
| `flake-parts/packages/opencode-plugins.nix` | hermetic plugin packages |
| `flake-parts/nixosModules/github-mcp.nix` | clan vars PAT generator (see [MCP Servers](mcp-servers.md#github-mcp-server)) |
| `flake-parts/nixosModules/morph-api-key.nix` | clan vars generator for the Morph API key (see [Plugins](plugins.md)) |
| `flake-parts/packages/kubernetes-mcp-server.nix` | kubernetes-mcp-server package |
| `flake-parts/packages/opencode-nixd-scaffold.nix` + `.py` | nixd per-repo scaffold package |
| repo-root `opencode.json` / `.vscode/settings.json` | per-repo nixd overrides for this flake |
| `clanServices/tags/netsa.nix` | netsa tag: machine-level `hostSpec` options only (nix-ld) |
| `flake-parts/packages/artifacthub-mcp.nix` | artifacthub-mcp package (see [MCP Servers](mcp-servers.md)) |
