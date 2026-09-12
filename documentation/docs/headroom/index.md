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
- **Compaction**: auto with `tail_turns = 3`.

## VM test

VM tests live at `legacyPackages.vmTests.<name>` and are deliberately
**not** part of `nix flake check` (static checks never boot a VM).

Current suite (`nix run .#vm-test -- --list`): `headroom-opencode` —
1 KVM VM, home-manager profile with headroom + opencode enabled.

What the test asserts:

1. `headroom --version` / `opencode --version` on the user's PATH.
2. `~/.config/opencode/opencode.json` contains the headroom MCP entry,
   the transport plugin, and the deepseek provider override.
3. The `headroom-proxy.service` user unit exists; the test deterministically
   `daemon-reload`s and starts it (HM activation can race the user-manager
   boot when linger is enabled).
4. Proxy health: `curl -sf http://127.0.0.1:8787/livez`.
5. `headroom mcp --help` (CLI sanity).
6. **MCP end-to-end** (`/etc/vm-mcp-probe.py`): drives
   `headroom mcp serve` over stdio JSON-RPC exactly as OpenCode does —
   `initialize` → `tools/list` (asserts `headroom_compress`,
   `headroom_retrieve`, `headroom_stats`) → `tools/call headroom_compress`
   → `tools/call headroom_retrieve` → asserts the verbatim roundtrip.
   The probe exits 0 only if every step passes.

!!! warning "Temporary resource bump"
    The test currently runs 8 cores / 16 GB RAM / 50 GB disk (marked
    `# TEMP` in `flake-parts/tests.nix`) to speed up iteration. Revert to
    2 cores / 2048 MB / default disk once done iterating.

### Running

```bash
nix run .#vm-test -- --list                          # list test names
nix run .#vm-test -- headroom-opencode               # sandboxed (CI-style)
nix run .#vm-test -- headroom-opencode --driver      # driver mode: logs + artifacts
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
| `--timeout SEC` | external watchdog (default `global_timeout` + 300) |

Artifacts after a run:

```
/tmp/home-vm-tests/headroom-opencode/
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

## Files landed

| File | Purpose |
|---|---|
| `flake-parts/packages/headroom.nix` | `headroom-ai` v0.37.0 package (wheel + autoPatchelf) |
| `flake-parts/homeModules/headroom.nix` | headroom options + `headroom-proxy.service` user unit |
| `flake-parts/homeModules/opencode.nix` | OpenCode settings: MCP, plugin, baseURL routing, LSP, formatters |
| `flake-parts/apps/vm-test.nix` | `vm-test` app (sandboxed + driver modes) |
| `flake-parts/tests.nix` | `headroom-opencode` NixOS VM test + MCP probe |
| `flake.nix` | `headroom` wheel input pinned to v0.37.0 |
| `overlays/default.nix` | `pkgs.headroom` |