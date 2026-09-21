# Plugins

OpenCode plugins are wired through `settings.plugin` with **absolute store
paths** (nothing is fetched from npm at runtime). Plugin packages come from
`flake-parts/packages/opencode-plugins.nix`. Options live under
`homeSpec.programs.opencode.plugins.<name>`.

| Option | Default | Description |
|---|---|---|
| `plugins.cc-safety-net.enable` | `true` | CC Safety Net — pre-tool-call guard blocking destructive commands (`git reset --hard`, `rm -rf` on dangerous targets, ...) and secret access (SSH keys, `.env`, `~/.aws`). Policy tuning is runtime state via `cc-safety-net gui`; broken config never blocks |
| `plugins.morph-fast-apply.enable` | `false` | Morph Fast Apply — `morph_edit` tool (lazy edit markers, ~10k tok/s merges). Needs a Morph API key: the `morph-api-key` clan var generator (nixosModules/morph-api-key) deploys it, the opencode wrapper exports it as `MORPH_API_KEY`; `apiKeyFile` overrides the var path, `model` selects `morph-v3-fast`/`morph-v3-large`/`auto` |
| `plugins.opencode-mem.enable` | `false` | opencode-mem — persistent project memory with local vector search (embedded libSQL + onnxruntime, autoPatchelf'd for NixOS). Default embedding model downloads from Hugging Face on first use; web UI on `127.0.0.1:4747`; runtime config at `~/.config/opencode/opencode-mem.jsonc` |
| `plugins.devcontainers.enable` | `false` | opencode-devcontainers — isolated branch workspaces via devcontainers/git worktrees (`/devcontainer`, `/worktree`, `/workspaces`). Needs `devcontainer` CLI (fullDevTools) + docker/podman |

The three opt-in plugins are enabled for the **dev profile**
(`flake-parts/homeModules/profiles/netsa.nix`), which pairs with
`hostSpec.services.nix-ld.enable = true` on the netsa-tagged dev machines
(nixos, kamrui-h1, ghost) so prebuilt native binaries (onnxruntime) run.

## Morph API key provisioning (`flake-parts/nixosModules/morph-api-key.nix`)

Mirrors the [github-mcp generator](mcp-servers.md#clan-vars-provisioning-flake-partsnixosmodulesgithub-mcpnix):
a clan vars generator that is **inert** until
`plugins.morph-fast-apply.enable = true`. The opencode wrapper exports
the key as `MORPH_API_KEY` at launch (default var path
`/run/secrets/vars/shared/morph-api-key/api-key`).

## Packages

| Package | Contents |
|---|---|
| `cc-safety-net` | dist committed, zero deps |
| `opencode-morph-fast-apply` | bun FOD + source |
| `opencode-devcontainers` | bun FOD + source |
| `opencode-mem` | bun FODs + tsc/vite build + autoPatchelf (all from `flake-parts/packages/opencode-plugins.nix`) |
