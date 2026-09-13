# Headroom — Context Optimization for AI Agents

[Headroom](https://www.headroomlabs.ai/) is a context optimization layer for
LLM-powered coding agents. This flake packages Headroom, integrates it with
OpenCode declaratively (no imperative config mutation), and ships a NixOS VM
test that validates the whole stack.

## What Headroom does

Headroom sits between an AI agent (OpenCode) and the upstream LLM providers
(DeepSeek, Anthropic, OpenAI, ...):

```
┌─────────────────────────────┐
│ OpenCode                    │
│  tools + headroom MCP       │
└──────────────┬──────────────┘
               │ HTTP
               ▼
┌─────────────────────────────┐
│ headroom proxy (:8787)      │
│  compression pipeline:      │
│  SmartCrusher, Kompress ML, │
│  code-aware (tree-sitter),  │
│  log/tabular compactors     │
│  CCR store (retrieve)       │
└──────────────┬──────────────┘
               ▼
   Upstream LLM providers
```

- **Optimization proxy** — local FastAPI server (`headroom proxy`), default
  `127.0.0.1:8787`. `cache` mode freezes prior turns to maximize provider
  prefix-cache hits; `token` mode aggressively rewrites prior turns.
- **Compression engines** compress large tool outputs (bash logs, diffs,
  file reads, tables) before they reach the model.
- **CCR (Compress-Cache-Retrieve)** — compressed content is replaced by
  markers (`<<ccr:<hash>>>`); the agent can call `headroom_retrieve(hash)`
  to fetch the verbatim original on demand.
- **MCP server** (`headroom mcp serve`) — stdio MCP server exposing
  `headroom_compress`, `headroom_retrieve`, and `headroom_stats`.
- **OpenCode transport plugin** — bundled JS plugin
  (`entry.opencode.js`) that reroutes *all* provider traffic through the
  proxy and registers `headroom_retrieve` as a native tool.

## Why `headroom wrap opencode` is not used

Upstream `headroom wrap opencode` mutates `~/.config/opencode/opencode.json`
in place. Under Home-Manager that file is a symlink into the read-only Nix
store, so wrap fails with `Read-only file system`. The declarative
equivalent is implemented directly in the home-manager modules instead.

## Package

`flake-parts/packages/headroom.nix` builds `headroom-ai` **v0.37.0** from the
prebuilt manylinux wheel pinned as the `headroom` flake input (abi3,
CPython 3.10–3.13), patched with `autoPatchelfHook` and propagated with the
`[all]` runtime dependency set from `nixpkgs#python313Packages` (including
`h2`, required for the proxy's HTTP/2 upstream client). It is exposed as:

- top-level output: `nix build .#headroom`
- overlay: `pkgs.headroom`

## Home-manager module

`flake-parts/homeModules/headroom.nix` — options under
`homeSpec.programs.headroom`:

| Option | Default | Description |
|---|---|---|
| `enable` | `false` | Install headroom and enable the integration |
| `package` | `pkgs.headroom` | Headroom package to install |
| `proxy.enable` | `true` | Run `headroom proxy` as a systemd **user** service |
| `proxy.port` | `8787` | Proxy listen port |
| `proxy.host` | `127.0.0.1` | Proxy bind host |
| `proxy.mode` | `cache` | `cache` (prefix-cache friendly) or `token` (max compression) |
| `proxy.memory` | `true` | Persistent cross-session memory |
| `proxy.learn` | `true` | Live traffic learning |
| `proxy.extraArgs` | `[]` | Extra CLI args for `headroom proxy` |

The service (`headroom-proxy.service`) is `Restart=always` and
`WantedBy=default.target`.

!!! note "First boot with memory/learn"
    `--memory`/`--learn` pull embedding models from Hugging Face on first
    startup; with an empty `HOME` cache this can stall boot for a long
    while. The VM test disables both for a fast, hermetic smoke run.

## OpenCode integration

`flake-parts/homeModules/opencode.nix` declaratively merges the following
into `programs.opencode.settings` when headroom is enabled (no
`headroom wrap opencode` needed — wrap is unusable on a read-only
home-manager config):

- **MCP server** — `mcp.headroom = { type = "local"; command = ["headroom" "mcp" "serve"]; enabled = true; }`
- **Transport plugin** — the bundled `entry.opencode.js` from the Nix store.
  It patches OpenCode's HTTP stack so *every* provider is routed through the
  proxy (tagged via `x-headroom-base-url`), and registers
  `headroom_retrieve` as a native tool.
- **Provider baseURL overrides** — `deepseek`, `anthropic`, and `openai`
  point at `http://127.0.0.1:8787/v1` (the reliable fallback layer that
  works even without the plugin, e.g. `opencode --pure`).

### Additional MCP servers

The same module also declaratively adds three more MCP servers to
`mcp.<name>`, each behind a defaulted toggle:

| Option | Default | Server | Kind | Description |
|---|---|---|---|---|
| `enableNixMcp` | `true` | `mcp.nixos` | local | mcp-nixos flake package: NixOS / Home Manager / nix-darwin package & option search |
| `enableOpenrouterMcp` | `true` | `mcp.openrouter` | remote | OpenRouter's hosted MCP server (`https://mcp.openrouter.ai/mcp`): live model catalog, pricing, credits, rankings, benchmarks, docs search. Nothing is installed locally — opencode runs the OAuth flow automatically on first use (minted key expires after 7 days, revocable in the OpenRouter dashboard) |
| `enablePlaywrightMcp` | `true` | `mcp.playwright` | local | nixpkgs `playwright-mcp` package: browser automation via accessibility snapshots. Fully hermetic — the nixpkgs wrapper pins the browser bundle (`playwright-driver.browsers`) and the playwright node modules into `/nix/store`, so no npx/docker/uvx runtime downloads. Runs `--headless` so it works on displayless agents/VMs; chromium is the default browser |
| `enableGithubMcp` | `true` | `mcp.github` | local *or* remote | GitHub's official MCP server (`github-mcp-server` from the pinned nixpkgs-unstable revision). Auth method selected by `githubMcpAuth` — see below. Only takes effect when opencode itself is enabled (all `mcp.*` entries live inside `mkIf` on `enable`) |
| `enableCloudflareMcp` | `false` | `mcp.cloudflare` | remote | Cloudflare **Code Mode** server (`https://mcp.cloudflare.com/mcp`) — recommended entry point, broad access across Cloudflare's APIs through code execution |
| `enableCloudflareDocsMcp` | `false` | `mcp.cloudflare-docs` | remote | Cloudflare **Documentation** server (`https://docs.mcp.cloudflare.com/mcp`) — up-to-date Cloudflare reference information; public, no OAuth needed |
| `enableCloudflareBindingsMcp` | `false` | `mcp.cloudflare-bindings` | remote | Cloudflare **Workers Bindings** server (`https://bindings.mcp.cloudflare.com/mcp`) — build Workers applications with storage, AI, and compute primitives |
| `enableCloudflareBuildsMcp` | `false` | `mcp.cloudflare-builds` | remote | Cloudflare **Workers Builds** server (`https://builds.mcp.cloudflare.com/mcp`) — insights and management for Cloudflare Workers Builds |
| `enableCloudflareBrowserMcp` | `false` | `mcp.cloudflare-browser` | remote | Cloudflare **Browser Run** server (`https://browser.mcp.cloudflare.com/mcp`) — fetch web pages, convert them to markdown and take screenshots |
| `enableCloudflareContainersMcp` | `false` | `mcp.cloudflare-containers` | remote | Cloudflare **Container** server (`https://containers.mcp.cloudflare.com/mcp`) — spin up a sandbox development environment |
| `enableMdnMcp` | `false` | `mcp.mdn` | remote | MDN Web Docs server (`https://mcp.mdn.mozilla.net/`) — up-to-date web API/CSS/JS reference from Mozilla |
| `enableArtifacthubMcp` | `false` | `mcp.artifacthub` | local | ArtifactHub MCP server — Helm-chart tools against artifacthub.io: chart info, default `values.yaml` (with fuzzy search), templates (with fuzzy search). Built hermetically from the `v1.1.1` source pin (`buildNpmPackage` in `flake-parts/packages/artifacthub-mcp.nix`), so no docker/`npx` runtime downloads |

All six Cloudflare servers, the MDN Web Docs server, and the ArtifactHub
server are **off by
default** and enabled via the
**netsa tag profile** (`clanServices/tags/netsa.nix`) for the netsa dev
machines. The Cloudflare/MDN servers are hosted remote servers — no local
install, no docker, no
secrets; opencode runs the Cloudflare browser OAuth flow automatically on
first tool use (the docs and MDN servers are public). The ArtifactHub
server is a local stdio binary (also installed on the user's PATH like
`playwright-mcp`) and needs no secrets — it queries the public
artifacthub.io API.

### GitHub MCP server

`mcp.github` is **on by default** (`enableGithubMcp`, default `true`) and
supports two **mutually exclusive** auth methods, selected by
`homeSpec.programs.opencode.githubMcpAuth`:

| `githubMcpAuth` | `mcp.github` entry | Secret |
|---|---|---|
| `"oauth"` (**default**) | `type = "remote"`, `url = "https://api.githubcopilot.com/mcp/"` — GitHub's hosted server; opencode runs the browser OAuth flow automatically on first tool use | none |
| `"pat"` | `type = "local"`, command = the `github-mcp-server-opencode` wrapper (`github-mcp-server stdio`) | PAT file at `githubPatFile` (default: the clan var path below) |

Exclusivity is enforced by the `githubMcpAuth` enum (one method at a time)
plus an eval-time home-manager assertion: `"oauth"` requires
`githubPatFile` to be `null`.

The wrapper reads the PAT file (explicit `githubPatFile` override, else the
canonical `/run/secrets/vars/shared/github-mcp/pat`) and exports
`GITHUB_PERSONAL_ACCESS_TOKEN` before exec'ing the server. The upstream
server exits immediately when that env var is unset, so a readable PAT file
is a hard requirement for the `"pat"` method to work.

#### Clan vars provisioning (`flake-parts/nixosModules/github-mcp.nix`)

All githubMcp options live under `homeSpec.programs.opencode` — there is no
separate NixOS option tree. The option-less NixOS module
`nixosModules.github-mcp` scans every home-manager user's opencode config
and, for each user with `enableGithubMcp` + `githubMcpAuth = "pat"`
(and opencode enabled), declares the shared clan vars generator:

```nix
clan.core.vars.generators."github-mcp" = {
  share = true;              # one PAT for the whole fleet
  prompts.pat.persist = true;
  prompts.pat.type = "hidden";
  files.pat = {
    owner = <user>;          # readable by the opencode user
    mode = "0400";
    neededFor = "services";  # deployed via sops-nix at boot
  };
};
```

Provisioning (interactive, **no fake values in the repo**):

```bash
clan vars set github-mcp pat <machine>   # or: clan vars generate
clan vars upload <machine>               # if needed
```

sops-nix then deploys the secret to
`/run/secrets/vars/shared/github-mcp/pat` (owner = user, mode `0400`) and
the wrapper picks it up on every MCP server start. Machines using the
default `"oauth"` method declare no generator and need no secret at all.

The netsa dev machines opt into `"pat"` via the **netsa tag profile**
(`clanServices/tags/netsa.nix`, wired to machines tagged `netsa` through the
`tags` clan service in `inventory.nix`), which just sets
`home-manager.users.netsa.homeSpec.programs.opencode.githubMcpAuth = "pat"`.
No per-machine configuration is needed anywhere.

No docker image or `uvx` shim is needed anywhere: OpenRouter is remote-only,
and Playwright comes from the pinned nixpkgs revision. `playwright-mcp` is
also put on the user's PATH (`home.packages` — note that
`programs.opencode.extraPackages` is *not* a user PATH mechanism) so the
server binary can be probed/reused outside opencode.

Providers NOT overridden (intentionally):

- **openrouter / google gemini** — native OpenCode providers resolved from
  models.dev. Keep their real upstream baseURLs; the proxy's OpenAI handler
  honors the plugin's `x-headroom-base-url` header and its Gemini handler
  serves `/v1beta/models/...` natively. Config-level entries for them are
  unnecessary (and would break upstream selection).
- **Auth** — use `/connect` in the TUI (writes
  `~/.local/share/opencode/auth.json`) or provider env vars
  (`OPENROUTER_API_KEY`, `GEMINI_API_KEY`). Never in the read-only store.

Also configured declaratively in the same module:

- **LSP**: pyrefly (`pyrefly lsp`, `.py`/`.pyi`), nil (`nil`, `.nix`),
  gleam (`gleam lsp`, `.gleam`); built-in pyright disabled (it would
  auto-download `pyright-langserver` at runtime — non-hermetic — and
  duplicate pyrefly's `.py` coverage).
- **Formatters**: alejandra (`.nix`), ruff (`ruff format`, `.py`/`.pyi`),
  gleam — all with `"$FILE"` placeholders and dotted extensions (OpenCode
  requires both; see the VM test history).
- **Compaction**: auto with `tail_turns = 32`.

## VM tests

VM tests live in the dedicated `vm-tests/` directory at the repository root.
They are auto-discovered, dynamically scaled into 3 resource sizes, and exposed
at `legacyPackages.vmTests.<name>-<size>`. They are deliberately **not** part of
`nix flake check` (static checks never boot a VM).

### Sizing schema

Every VM test defined in `vm-tests/<test-name>.nix` automatically generates three size variants:

| Size | Suffix | Cores | RAM | Disk |
|---|---|---|---|---|
| **Small** (Baseline) | `-sm` | 2 cores | 4 GB (`4096 MiB`) | 30 GB (`30720 MiB`) |
| **Medium** (2x) | `-md` | 4 cores | 8 GB (`8192 MiB`) | 60 GB (`61440 MiB`) |
| **Large** (3x) | `-lg` | 6 cores | 12 GB (`12288 MiB`) | 90 GB (`92160 MiB`) |

### Available test suites (`nix run .#vm-test -- --list`):

1. **`headroom-opencode-<sm|md|lg>`** (`vm-tests/headroom-opencode.nix`):
   - 1 KVM VM, home-manager profile with headroom + opencode enabled.
   - Asserts binaries on PATH (headroom, opencode, playwright-mcp, github-mcp-server), `opencode.json` generation (headroom MCP + plugin + provider override + `mcp.openrouter`/`mcp.playwright` entries), `headroom-proxy.service` healthcheck (`/livez`), stdio JSON-RPC MCP CCR compression roundtrip (`/etc/vm-mcp-probe.py`), a second stdio probe driving the Playwright MCP server (`initialize` → `tools/list`, asserting `browser_navigate`/`browser_snapshot`/`browser_click`), and a third stdio probe driving the `github-mcp-server-opencode` wrapper (PAT method with a fake `/etc/vm-github-pat` — a successful `tools/list` proves the PAT file was read and exported, since the server exits without it).
   - A second lightweight user (`bob`) exercises the other exclusive auth branch: `mcp.github` must be the `remote` oauth entry (`https://api.githubcopilot.com/mcp/`).
2. **`headroom-opencode-web-<sm|md|lg>`** (`vm-tests/headroom-opencode-web.nix`):
   - Tests a KubeVirt AI agent machine using the headless `netsa` profile (`profile-netsa-agent`).
   - Asserts headless dev tooling on `netsa`'s PATH, `opencode.json` generation (headroom MCP + plugin + `mcp.openrouter`/`mcp.playwright` entries), OpenCode Web HTTP access on port 4096 (`<title>OpenCode</title>`), Headroom proxy `/livez`, and MCP CCR roundtrip (`/etc/vm-mcp-probe.py`).

### Running

```bash
nix run .#vm-test -- --list                             # list all test names
nix run .#vm-test -- headroom-opencode-sm               # sandboxed (CI-style)
nix run .#vm-test -- headroom-opencode-sm --driver      # driver mode: logs + artifacts
nix run .#vm-test -- headroom-opencode-web-sm --driver  # driver mode for web test
```

**Sandbox mode** (default): builds the full test derivation; the driver
runs inside the Nix build sandbox, exit code = test result, log = build
log (`-L`).

**Driver mode** (`--driver`): builds only the `.driver` output and runs
the standalone `nixos-test-driver` outside the sandbox:

| Flag | Effect |
|---|---|
| `--out DIR` | artifact dir (default `/tmp/home-vm-tests/<name>`) |
| `--keep-state` | keep VM state between runs (resumable with `-K`) |
| `--interactive` | drop into the test-driver Python REPL |
| `--timeout SEC` | external watchdog (default `global_timeout` + 300; sandboxed runs default 3900) |

Artifacts after a run:

```
/tmp/home-vm-tests/<name>/
├── master.log    # full master log (grep-able, VM serial output included)
├── log.xml       # same log as XML (driver LOGFILE)
├── junit.xml     # JUnitXML per-subtest report
├── out/          # files pulled from the VM
└── tmp/          # vm-state-<machine>/ (QEMU disks, sockets)
```

Green runs clean `tmp/`; red runs keep it for post-mortem. Exit codes:
`0` pass, `1` failure, `124` watchdog fired.

Requirements: `/dev/kvm` (TCG fallback is impossible by design,
`qemu.forceAccel = true`).

## KubeVirt AI Agent

- **Headless agent profile**: `flake.homeModules.profile-netsa-agent` in `flake-parts/homeModules/profiles/netsa-agent.nix`.
- **Bootable QCOW2 image**: `packages.kubevirt-image` (single, unsized, **compressed qcow2**, ~2 GB).
- **OCI ContainerDisk**: `packages.ai-agent` → `ghcr.io/andrewthomaslee/ai-agent` (~2.2 GB layer).
- **Kustomize manifests**: `packages.ai-agent-oci` (Kubenix-evaluated, kustomize-CLI-validated).
- **NixOS machine config**: `nixosConfigurations.kubevirt-agent`.

### How the KubeVirt machine is produced

The pipeline is fully deterministic, from flake evaluation to a running
`VirtualMachine` in Kubernetes:

```
nix eval  nixosConfigurations.kubevirt-agent
  ├─ modules: nixpkgs virtualisation/kubevirt.nix + self.nixosModules.default
  │           + home-manager + profile-netsa-agent
  ├─ BIOS GRUB on /dev/vda (kubevirt.nix is BIOS-only; GRUB EFI is forced off),
  │  console=ttyS0, growPartition + autoResize root filesystem
  ├─ qemu-guest-agent (KubeVirt uses it to report VM IP/status to the k8s API),
  │  cloud-init, sshd, headroom proxy + opencode-web user services (netsa)
  └─ system.build.kubevirtImage
        → make-disk-image.nix boots a throwaway install VM inside the build
          sandbox, installs the closure and produces a **compressed qcow2**
          (format = "qcow2-compressed", zlib clusters)
        → dockerTools.buildImage wraps it as /disk/root.qcow2
          (packages.ai-agent, a KubeVirt containerDisk)
        → CI pushes it to ghcr.io/andrewthomaslee/ai-agent:<tag>
        → Kubenix evaluates the VirtualMachine CR (containerDisk volume +
          cloudInitNoCloud userData + sized cpu/memory) and the Service
          (opencode-web 4096 + ssh 22)
        → kubectl apply -k … spawns the VM
```

The QCOW2 image and OCI containerDisk are **single, unsized artifacts**: the
root filesystem auto-grows on boot (`boot.growPartition` + `autoResize`), so
one image serves every VM size. Resource sizing happens at **deploy time**
through the Kustomization overlays.

### Manifests package layout (`packages.ai-agent-oci`)

```
result/
├── kustomization.yaml          # root build = sm baseline
├── base/
│   ├── kustomization.yaml      # labels + resources
│   ├── virtualmachine.yaml     # VM "ai-agent" (containerDisk + cloudInit)
│   └── service.yaml            # ClusterIP: 4096 (opencode-web), 22 (ssh)
└── overlays/
    ├── sm/                     # 2 cores / 4Gi  (baseline)
    ├── md/                     # 4 cores / 8Gi  (2x)
    └── lg/                     # 6 cores / 12Gi (3x)
```

Every `kustomization.yaml` is validated with the `kustomize` CLI during the
package build (root + all three overlays). The overlays apply a strategic-merge
patch on `spec.template.spec.domain` (cpu cores + memory requests/limits) and a
`app.kubernetes.io/size` label.

### Deploying

```bash
# from a built manifests package
nix build .#ai-agent-oci
kubectl apply -k result/overlays/lg     # or sm / md, or result/ for baseline

# from the published OCI artifact
oras pull ghcr.io/andrewthomaslee/ai-agent-manifests:latest
kubectl apply -k latest/overlays/lg
```

Runtime configuration is injected via the `cloudInitNoCloud` volume: the VM
writes `/etc/default/opencode-web` (e.g. `OPENCODE_SERVER_PASSWORD`,
`OPENCODE_PORT`) which the `opencode-web.service` unit picks up through
`EnvironmentFile`.

### Image optimization (trim + compress)

The agent image is aggressively slimmed without touching desktop profiles
(all trims are behind defaulted options):

| Optimization | Change | Savings |
|---|---|---|
| `homeSpec.programs.opencode.enableDesktop = false` | skips `opencode-desktop` + Electron/GTK chain | ~4 GB |
| `homeSpec.programs.opencode.fullDevTools = false` | skips k3s/rke2/k3d/devpod/devcontainer/podman/gleam/terraform-helm LSPs/go_latest; **keeps docker, kubectl, helm, k9s, bun, go, uv** | ~3.5 GB |
| `packages.headroom-slim` | core+proxy+code+mcp deps only (no torch/sentence-transformers/OCR); validated by the MCP E2E test | ~2.7 GB |
| documentation/manpages off | agent VM needs no docs | ~0.1 GB |
| `qcow2-compressed` image format | zlib-compressed qcow2 clusters (KubeVirt-compatible) | image 12 GB → **2.0 GB**, OCI layer 6.9 GB → **2.2 GB** |

Desktop profiles (`profile-netsa`, `profile-wife`) keep the defaults
(`enableDesktop = true`, `fullDevTools = true`, full `pkgs.headroom`) and are
unchanged. `packages.headroom` (full) is also untouched.

### CI publishing

`.github/workflows/oci.yml` (manual dispatch) and the `Release` workflow both
invoke `.github/workflows/_oci.yml`, which:

1. Builds `.#ai-agent` → pushes `ghcr.io/andrewthomaslee/ai-agent:<tag>` + `:latest`.
2. Builds `.#ai-agent-oci` → pushes the whole manifests directory as an OCI
   artifact at `ghcr.io/andrewthomaslee/ai-agent-manifests:<tag>` + `:latest`
   via `oras` (artifact type `application/vnd.kustomize.v1+tar`).

### VM test

`vm-tests/headroom-opencode-web.nix` exercises the same machine definition
(unsized) as `headroom-opencode-web-<size>`: it asserts the headless
developer tooling is on `netsa`'s PATH, the Headroom proxy healthcheck, the
OpenCode web UI on port 4096, and the MCP CCR roundtrip.

## Files landed

| File | Purpose |
|---|---|
| `flake-parts/packages/headroom.nix` | `headroom-ai` v0.37.0 (full `[all]`) + `headroom-slim` (core/proxy/code/mcp) packages |
| `flake-parts/homeModules/headroom.nix` | headroom options + `headroom-proxy.service` user unit |
| `flake-parts/homeModules/opencode.nix` | OpenCode settings: MCP (headroom, nixos, openrouter, playwright, github, cloudflare ×6, mdn, artifacthub), plugin, baseURL routing, LSP, formatters; `enableDesktop`/`fullDevTools` trims; `enableNixMcp`/`enableOpenrouterMcp`/`enablePlaywrightMcp`/`enableGithubMcp` toggles (github: exclusive `githubMcpAuth` `oauth`/`pat` + `githubPatFile` wrapper); `enableCloudflare*Mcp`/`enableMdnMcp`/`enableArtifacthubMcp` toggles (default off) |
| `flake-parts/nixosModules/github-mcp.nix` | Option-less module: derives the clan vars `github-mcp` PAT generator (shared, prompted, persisted, owner `<user>` mode `0400`) from each home-manager user's `githubMcpAuth = "pat"` opencode config |
| `clanServices/tags/netsa.nix` | netsa tag profile: `githubMcpAuth = "pat"` + all six Cloudflare MCP toggles + MDN + ArtifactHub toggles for netsa's opencode on netsa-tagged dev machines |
| `flake-parts/homeModules/profiles/netsa-agent.nix` | Headless AI agent profile with developer toolings |
| `flake-parts/packages/ai-agent.nix` | KubeVirt QCOW2 image (compressed), OCI containerdisk, Kubenix Kustomization package |
| `flake-parts/apps/vm-test.nix` | `vm-test` app (sandboxed + driver modes) |
| `flake-parts/tests.nix` | VM test auto-discovery & dynamic 3x sizing engine |
| `vm-tests/headroom-opencode.nix` | Headroom + OpenCode CLI/MCP VM test definition |
| `vm-tests/headroom-opencode-web.nix` | KubeVirt machine Headroom + OpenCode Web VM test definition |
| `.github/workflows/_oci.yml` | Reusable workflow to publish OCI containerdisks and Kustomize manifests |
| `.github/workflows/oci.yml` | Manual dispatch workflow for OCI publishing |
| `flake.nix` | `headroom` wheel input + `kubenix` input |
| `overlays/default.nix` | `pkgs.headroom` + `pkgs.headroom-slim` |