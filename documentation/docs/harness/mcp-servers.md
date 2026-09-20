# MCP Servers

Every MCP server is declared declaratively by
`flake-parts/homeModules/opencode.nix` under
`homeSpec.programs.opencode.mcp.<name>.enable` and merged into
`programs.opencode.settings.mcp` when OpenCode is enabled (all `mcp.*`
entries live inside `mkIf` on `enable`). No docker, no `npx`/`uvx` runtime
downloads: local servers are hermetic nix packages, remote servers are
hosted.

## All servers

| Option | Default | Server | Kind | Description |
|---|---|---|---|---|
| `mcp.nix.enable` | `true` | `mcp.nixos` | local | mcp-nixos flake package: NixOS / Home Manager / nix-darwin package & option search |
| `mcp.openrouter.enable` | `true` | `mcp.openrouter` | remote | OpenRouter's hosted MCP server (`https://mcp.openrouter.ai/mcp`): live model catalog, pricing, credits, rankings, benchmarks, docs search. Nothing is installed locally — opencode runs the OAuth flow automatically on first use (minted key expires after 7 days, revocable in the OpenRouter dashboard) |
| `mcp.playwright.enable` | `true` | `mcp.playwright` | local | nixpkgs `playwright-mcp` package: browser automation via accessibility snapshots. Fully hermetic — the nixpkgs wrapper pins the browser bundle (`playwright-driver.browsers`) and the playwright node modules into `/nix/store`, so no npx/docker/uvx runtime downloads. Runs `--headless` so it works on displayless agents/VMs; chromium is the default browser |
| `mcp.github.enable` | `true` | `mcp.github` | local *or* remote | GitHub's official MCP server (`github-mcp-server` from the pinned nixpkgs-unstable revision). Auth method selected by `mcp.github.auth` — see [below](#github-mcp-server). Only takes effect when opencode itself is enabled (all `mcp.*` entries live inside `mkIf` on `enable`) |
| `mcp.cloudflare.enable` | `false` | `mcp.cloudflare` | remote | Cloudflare **Code Mode** server (`https://mcp.cloudflare.com/mcp`) — recommended entry point, broad access across Cloudflare's APIs through code execution |
| `mcp."cloudflare-docs".enable` | `false` | `mcp.cloudflare-docs` | remote | Cloudflare **Documentation** server (`https://docs.mcp.cloudflare.com/mcp`) — up-to-date Cloudflare reference information; public, no OAuth needed |
| `mcp."cloudflare-bindings".enable` | `false` | `mcp.cloudflare-bindings` | remote | Cloudflare **Workers Bindings** server (`https://bindings.mcp.cloudflare.com/mcp`) — build Workers applications with storage, AI, and compute primitives |
| `mcp."cloudflare-builds".enable` | `false` | `mcp.cloudflare-builds` | remote | Cloudflare **Workers Builds** server (`https://builds.mcp.cloudflare.com/mcp`) — insights and management for Cloudflare Workers Builds |
| `mcp."cloudflare-browser".enable` | `false` | `mcp.cloudflare-browser` | remote | Cloudflare **Browser Run** server (`https://browser.mcp.cloudflare.com/mcp`) — fetch web pages, convert them to markdown and take screenshots |
| `mcp."cloudflare-containers".enable` | `false` | `mcp.cloudflare-containers` | remote | Cloudflare **Container** server (`https://containers.mcp.cloudflare.com/mcp`) — spin up a sandbox development environment |
| `mcp.mdn.enable` | `false` | `mcp.mdn` | remote | MDN Web Docs server (`https://mcp.mdn.mozilla.net/`) — up-to-date web API/CSS/JS reference from Mozilla |
| `mcp.artifacthub.enable` | `false` | `mcp.artifacthub` | local | ArtifactHub MCP server — Helm-chart tools against artifacthub.io: chart info, default `values.yaml` (with fuzzy search), templates (with fuzzy search). Built hermetically from the `v1.1.1` source pin (`buildNpmPackage` in `flake-parts/packages/artifacthub-mcp.nix`), so no docker/`npx` runtime downloads |
| `mcp.kubernetes.enable` | `false` | `mcp.kubernetes` | local | Kubernetes MCP server (`containers/kubernetes-mcp-server` v0.0.66, hermetic `buildGoModule` in `flake-parts/packages/kubernetes-mcp-server.nix`) — kubectl + helm + KubeVirt toolsets against the user's kubeconfig; stdio is the default transport. **Off by default**: the server exits at startup without a kubeconfig (`~/.kube/config` or `KUBECONFIG`), so enable it per profile/machine once cluster credentials exist — the dev profile (netsa machines) enables it. `mcp.kubernetes.readOnly` (default `false`) adds `--read-only` (only `readOnlyHint` tools exposed) |
| `mcp.typeui.enable` | `false` | `mcp.typeui` | remote | TypeUI hosted design-skills MCP (`https://mcp.typeui.sh/mcp`, OAuth on first use): design systems, UI prompts and layout guidance for AI-first UI work. Enabled for the dev profile |

The opt-in servers (cloudflare ×6, mdn, artifacthub, kubernetes, typeui)
are enabled for the **dev profile** — see
[the harness overview](index.md#profiles).

The Cloudflare/MDN servers are hosted remote servers — no local install, no
secrets; opencode runs the Cloudflare browser OAuth flow automatically on
first tool use (the docs and MDN servers are public). The ArtifactHub
server is a local stdio binary (also installed on the user's PATH like
`playwright-mcp`) and needs no secrets — it queries the public
artifacthub.io API.

`playwright-mcp` is also put on the user's PATH (`home.packages` — note
that `programs.opencode.extraPackages` is *not* a user PATH mechanism) so
the server binary can be probed/reused outside opencode.

## GitHub MCP server

`mcp.github` is **on by default** (`mcp.github.enable`, default `true`) and
supports two **mutually exclusive** auth methods, selected by `mcp.github.auth`:

| `mcp.github.auth` | `mcp.github` entry | Secret |
|---|---|---|
| `"oauth"` (**default**) | `type = "remote"`, `url = "https://api.githubcopilot.com/mcp/"` — GitHub's hosted server; opencode runs the browser OAuth flow automatically on first tool use | none |
| `"pat"` | `type = "local"`, command = the `github-mcp-server-opencode` wrapper (`github-mcp-server stdio`) | PAT file at `mcp.github.patFile` (default: the clan var path below) |

Exclusivity is enforced by the `mcp.github.auth` enum (one method at a time)
plus an eval-time home-manager assertion: `"oauth"` requires
`mcp.github.patFile` to be `null`.

The wrapper reads the PAT file (explicit `mcp.github.patFile` override, else
the canonical `/run/secrets/vars/shared/github-mcp/pat`) and exports
`GITHUB_PERSONAL_ACCESS_TOKEN` before exec'ing the server. The upstream
server exits immediately when that env var is unset, so a readable PAT file
is a hard requirement for the `"pat"` method to work.

### Clan vars provisioning (`flake-parts/nixosModules/github-mcp.nix`)

All github options live under `homeSpec.programs.opencode.mcp.github` —
there is no separate NixOS option tree. The option-less NixOS module
`nixosModules.github-mcp` scans every home-manager user's opencode config
and, for each user with `mcp.github.enable` + `mcp.github.auth = "pat"`
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

The netsa dev machines opt into `"pat"` via the **dev profile**
(`flake-parts/homeModules/profiles/netsa.nix`, applied to netsa on
netsa-tagged machines through the users clan service in `inventory.nix`),
which sets `mcp.github.auth = "pat"`. No per-machine configuration is
needed anywhere.
