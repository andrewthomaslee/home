# MCP Servers

MCP servers are declared by `flake-parts/homeModules/agents.nix` under
`homeSpec.agents.opencode.mcp.<name>.enable` and merged into
`programs.opencode.settings.mcp.servers` when opencode is enabled (each
entry lives inside `mkIf` on its option). No docker, no `npx`/`uvx`
runtime downloads: local servers are hermetic nix packages, remote
servers are hosted.

## All servers

| Option | Default | Server | Kind | Description |
|---|---|---|---|---|
| `mcp.nix.enable` | `true` | `mcp.nixos` | local | mcp-nixos flake package: NixOS / Home Manager / nix-darwin package & option search |
| `mcp.github.enable` | `true` | `mcp.github` | local *or* remote | GitHub's official MCP server (`github-mcp-server` from nixpkgs-unstable). Auth method selected by `mcp.github.auth` — see [below](#github-mcp-server) |
| `mcp.artifacthub.enable` | `false` | `mcp.artifacthub` | local | ArtifactHub MCP server — Helm-chart tools against artifacthub.io: chart info, default `values.yaml` (with fuzzy search), templates (with fuzzy search). Built hermetically from the `v1.1.1` source pin (`buildNpmPackage` in `flake-parts/packages/artifacthub-mcp.nix`), so no docker/`npx` runtime downloads; no secrets — it queries the public artifacthub.io API |
| `mcp.kubernetes.enable` | `false` | `mcp.kubernetes` | local | Kubernetes MCP server (`containers/kubernetes-mcp-server`, hermetic `buildGoModule` in `flake-parts/packages/kubernetes-mcp-server.nix`) against the user's kubeconfig; stdio is the default transport. **Off by default**: the server exits at startup without a kubeconfig (`~/.kube/config` or `KUBECONFIG`), so enable it per profile/machine once cluster credentials exist. `mcp.kubernetes.readOnly` (default `false`) adds `--read-only` (only `readOnlyHint` tools exposed) |
| `mcp.varlock-docs.enable` | `false` | `mcp.varlock-docs` | remote | Varlock docs MCP server (`https://docs.mcp.varlock.dev/mcp`) — searches the varlock.dev documentation; public, no auth |

Additionally, when `homeSpec.programs.headroom.enable` is on, the
headroom MCP server is merged unconditionally (no `mcp.*` option):
`mcp.servers.headroom = { type = "local"; command = ["headroom" "mcp" "serve"]; }`.
See [Headroom](headroom.md).

The opt-in servers (`artifacthub`, `kubernetes`, `varlock-docs`) are off
by default; enable them per profile or machine, e.g. the dev profile or
a machine that has cluster credentials.

## GitHub MCP server

`mcp.github` is **on by default** (`mcp.github.enable`, default `true`)
and supports two **mutually exclusive** auth methods, selected by
`mcp.github.auth`:

| `mcp.github.auth` | `mcp.github` entry | Secret |
|---|---|---|
| `"oauth"` (**default**) | `type = "remote"`, `url = "https://api.githubcopilot.com/mcp/"` — GitHub's hosted server; opencode runs the browser OAuth flow automatically on first tool use | none |
| `"pat"` | `type = "local"`, command = the `github-mcp-server-opencode` wrapper (`github-mcp-server stdio`) | PAT file at `mcp.github.patFile` (default: the clan var path below) |

Exclusivity is enforced by the `mcp.github.auth` enum (one method at a
time) plus an eval-time home-manager assertion: `"oauth"` requires
`mcp.github.patFile` to be `null`.

The wrapper reads the PAT file (explicit `mcp.github.patFile` override,
else the canonical `/run/secrets/vars/shared/github-mcp/pat`) and
exports `GITHUB_PERSONAL_ACCESS_TOKEN` before exec'ing the server. The
upstream server exits immediately when that env var is unset, so a
readable PAT file is a hard requirement for the `"pat"` method to work.

### Clan vars provisioning (`flake-parts/nixosModules/github-mcp.nix`)

All github options live under `homeSpec.agents.opencode.mcp.github` —
there is no separate NixOS option tree. The option-less NixOS module
`nixosModules.github-mcp` scans every home-manager user's opencode
config and, for each user with opencode + `mcp.github.enable` +
`mcp.github.auth = "pat"`, declares the shared clan vars generator:

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
`/run/secrets/vars/shared/github-mcp/pat` (owner = user, mode `0400`)
and the wrapper picks it up on every MCP server start. Machines using
the default `"oauth"` method declare no generator and need no secret at
all.

To opt a profile into `"pat"`, set
`homeSpec.agents.opencode.mcp.github.auth = "pat";` in the profile (the
generator then provisions the PAT automatically).
