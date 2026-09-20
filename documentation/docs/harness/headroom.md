# Headroom — Context Optimization

[Headroom](https://www.headroomlabs.ai/) is the context optimization layer
of the [OpenCode harness](index.md): a local compression proxy between the
agent and the upstream LLM providers (DeepSeek, Anthropic, OpenAI, ...).
This flake packages it, integrates it with OpenCode declaratively, and
ships a [VM test](vm-tests.md) that validates the whole stack.

## What Headroom does

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
- **OpenCode transport plugin** — bundled JS plugin (`entry.opencode.js`)
  that reroutes *all* provider traffic through the proxy and registers
  `headroom_retrieve` as a native tool.

## Why `headroom wrap opencode` is not used

Upstream `headroom wrap opencode` mutates `~/.config/opencode/opencode.json`
in place. Under Home-Manager that file is a symlink into the read-only Nix
store, so wrap fails with `Read-only file system`. The declarative
equivalent is implemented directly in the home-manager modules instead.

## Package

`flake-parts/packages/headroom.nix` builds `headroom-ai` **v0.37.0** from
the prebuilt manylinux wheel pinned as the `headroom` flake input (abi3,
CPython 3.10–3.13), patched with `autoPatchelfHook` and propagated with the
`[all]` runtime dependency set from `nixpkgs#python313Packages` (including
`h2`, required for the proxy's HTTP/2 upstream client). It is exposed as:

- top-level output: `nix build .#headroom`
- overlay: `pkgs.headroom`

A trimmed variant `packages.headroom-slim` (core+proxy+code+mcp deps only —
no torch/sentence-transformers/OCR) is what the headless agent image uses;
see [KubeVirt AI Agent](kubevirt-agent.md#image-optimization-trim-compress).

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
| `proxy.memory` | `false` | Persistent cross-session memory (off by default: proxy-injected memory tools have no executor in opencode; also pulls embedding models at startup) |
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
- **Transport plugin** — the bundled `entry.opencode.js` from the Nix
  store. It patches OpenCode's HTTP stack so *every* provider is routed
  through the proxy (tagged via `x-headroom-base-url`), and registers
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
