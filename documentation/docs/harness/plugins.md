# Plugins

OpenCode plugins are wired through `settings.plugin` with **absolute store
paths** (nothing is fetched from npm at runtime). Plugin packages come from
`flake-parts/packages/opencode-plugins.nix`. Options live under
`homeSpec.programs.opencode.plugins.<name>`.

| Option | Default | Description |
|---|---|---|
| `plugins.cc-safety-net.enable` | `true` | CC Safety Net — pre-tool-call guard blocking destructive commands (`git reset --hard`, `rm -rf` on dangerous targets, ...) and secret access (SSH keys, `.env`, `~/.aws`). Policy tuning is runtime state via `cc-safety-net gui`; broken config never blocks |
| `plugins.opencode-mem.enable` | `false` | opencode-mem — persistent project memory with local vector search (embedded libSQL + onnxruntime, autoPatchelf'd for NixOS). Default embedding model downloads from Hugging Face on first use; web UI on `127.0.0.1:4747`; runtime config at `~/.config/opencode/opencode-mem.jsonc` |

The opt-in plugin is enabled for the **dev profile**
(`flake-parts/homeModules/profiles/netsa.nix`), which pairs with
`hostSpec.services.nix-ld.enable = true` on the netsa-tagged dev machines
(nixos, kamrui-h1, ghost) so prebuilt native binaries (onnxruntime) run.

> **v2 note:** plugins are loaded at runtime from the binary's home dir, so
> every plugin must support the v2 opencode runtime (`js/plugin`, config-key
> event names) and the `devInfo()`/v2 server APIs it calls — plugin breakage
> surfaces as errors *inside* the session, not at launch. The opencode VM test
> also validates the `devInfo` port in the bun-built-in (opencode-mem) case.

## Packages

| Package | Contents |
|---|---|
| `cc-safety-net` | dist committed, zero deps |
| `opencode-mem` | bun FODs + tsc/vite build + autoPatchelf (all from `flake-parts/packages/opencode-plugins.nix`) |
