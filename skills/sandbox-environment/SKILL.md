---
name: sandbox-environment
description: Deep reference for the OpenShell code-agent sandbox OCI image — full admitted-egress host list with the reasoning, nix registry/substituter setup with trusted keys, the baked MCP trio's failure modes, VSCodium Remote-SSH contract, and troubleshooting recipes. Load when working inside the OpenShell code-agent sandbox and the inline APPEND_SYSTEM.md/SYSTEM.md/CLAUDE.md briefing is not enough (policy misses, cache failures, MCP errors, image layout questions).
---

# Sandbox environment — deep reference

Deep reference for the `code-agent` OpenShell sandbox image (built by
`flake-parts/ociImages/code-agent.nix` in the home repo). The inline
briefing baked into every agent's system prompt
(`~/.pi/agent/APPEND_SYSTEM.md`, `~/.kimi-code/SYSTEM.md`,
`~/.claude/CLAUDE.md`) is the summary; this skill is the detail. Keep
the briefing token-lean — extend THIS file when reference material
grows.

## Layout and runtime facts

- microVM (OpenShell VM driver), uid/gid 1000 (`agent`), workdir
  `/sandbox`, `HOME=/home/agent` in the image Env but the supervisor
  points HOME at `/sandbox` — both roots carry identical per-agent
  config, so either works.
- `/etc` is root-owned read-only. `/nix/store` stays agent-writable on
  purpose (runtime `nix profile install` adds need it); an agent can
  corrupt its own toolset, but the blast radius ends at the disposable
  VM. `/tmp` is mode 1777. Long-running scratch space: `/sandbox`.
- The VSCodium Remote-SSH server is pre-baked at
  `/sandbox/.vscodium-server/bin/<commit>` (also `/home/agent/...`); the
  in-VM sshd runs extension commands with a store-only PATH, which is
  why the image also carries a `/usr/local/bin` toolchain and an
  `/etc/profile` PATH prefix for login shells.
- Foreign glibc ELFs resolve via `/lib64/ld-linux-x86-64.so.2` +
  copied glibc/gcc libs + pregenerated `/etc/ld.so.cache` (nixpkgs
  glibc's compiled-in search path covers no FHS dirs).

## Network: full admitted list

Egress is deny-by-default. Admitted hosts (from
`openshell/policies/code-agent.yaml`):

| Host | Access | Why |
|---|---|---|
| `github.com` | read (GET/HEAD/OPTIONS) + `git-upload-pack` | clone/fetch |
| `github.com` `/**/git-receive-pack` (via github-agent profile) | POST | `git push` |
| `api.github.com` | read; read-write with github-agent provider | gh + github MCP |
| `codeload.github.com`, `raw.githubusercontent.com`, `gist.github.com`, `*.githubusercontent.com` asset hosts | read | tarballs, raw files, release assets (VSCodium fallback download) |
| `*.nixos.org` | read | cache.nixos.org substitution, releases/channels/tarballs |
| `*.cachix.org` | read | community binary caches |
| `cache.flakehub.com`, `edge.cache.flakehub.com`, `api.flakehub.io` | read | FlakeHub caches |
| `cache.geninf.io`, `cache.clan.lol` | read | clan niks3 caches |
| `git.clan.lol` | read-write git transport | clan repos |
| `api.kimi.com` | — | kimi-for-coding API |
| `api.anthropic.com`, `platform.claude.com` | — | claude API + startup preflight |

Everything else is DENIED. Do not retry dead hosts in a loop — report
the blocked host. The policy hot-reloads: `openshell policy get/set`
from the HOST (not inside the sandbox) changes network rules without
recreating the sandbox; filesystem/image changes require recreation.

## nix setup

- Flakes on; `sandbox = false` + `filter-syscalls = false` (the
  supervisor's seccomp stack blocks nix's builder-child BPF filter).
- Registry: `nixpkgs` is pinned in-image to
  `github:NixOS/nixpkgs/nixos-unstable` (`/etc/nix/registry.json`) —
  the default indirection via channels.nixos.org is NOT admitted. First
  resolution fetches the nixpkgs tarball (~50MB) from the admitted
  github endpoints into `~/.cache/nix`; later runs reuse the cache. A
  baked-in nixpkgs checkout was dropped deliberately: it was the
  image's heaviest payload, and nix2container copyToRoot rewrites
  dumped the tree at the image root rather than its store path.
- Substituters + trusted keys baked in `/etc/nix/nix.conf` (also
  `$NIX_CONFIG`): FlakeHub caches (keys `cache.flakehub.com-3` through
  `-10`), clan niks3 (`cache.geninf.io-1`, `cache.clan.lol-1` — objects
  may be signed under either).
- For a Cachix-backed package, name cache + key explicitly:
  `NIX_CONFIG="$NIX_CONFIG extra-substituters = https://<cache>.cachix.org extra-trusted-public-keys = <cache>.cachix.org-1:…" nix profile install …`
- No `/dev/kvm`: builds fall back to TCG and crawl. Substitution-only
  is the intended path for unbaked packages — never let a from-source
  build start.
- Do NOT run `nix flake check` or the NixOS VM tests (`nix run
  .#vm-test`) in-sandbox: they build heavy derivations and need KVM.
  Checks, builds and VM tests are CI's job — the fleet CI is not wired
  up yet, so flag the gap rather than running them.

## MCP trio failure modes

- `headroom` — `headroom mcp serve`; wrapper maps the injected
  `$ANTHROPIC_AUTH_TOKEN` onto `ANTHROPIC_API_KEY`. Broken when the
  claude-code provider is missing.
- `nixos` — `mcp-nixos`; fully local, always works.
- `github` — `github-mcp-server` wrapper mapping the `$GITHUB_TOKEN`
  handle onto `GITHUB_PERSONAL_ACCESS_TOKEN`. Errors at startup without
  the github-agent provider attached (its profile admits read-write
  api.github.com and substitutes the real token at egress for the
  pinned binary). Harmless otherwise; ignore or recreate with
  `--provider github-agent`.
- There is deliberately NO kubernetes MCP server. Use `kubectl`/`helm`
  directly; cluster API egress rides an attached provider or
  port-forward.

## Identity and secrets

- Git identity: `andrewthomaslee-agent` bot; github.com-scoped
  credential helper feeds git the provider-injected `$GITHUB_TOKEN`.
- Provider env values are OPAQUE HANDLES, not real secrets —
  `gh auth status` failing is expected; egress substitution is what
  authenticates. Real keys never enter the image.
- Nothing secret is baked in. API keys arrive only via attached
  providers (`kimi-for-coding`, `claude-code`, `github-agent`).

## Recipes

- New package at runtime (NOT pre-baked): `nix profile install nixpkgs#<pkg>`.
- Repo work: clone `github.com/external-systems/home` first — the
  sandbox is clean, not a checkout.
- DENIED spam in `openshell logs`: add a narrow rule via
  `openshell policy set` from the host.
- Sandbox feels stale (missing baked files): the image hash-named
  sandbox lifecycle is `code-sandbox` in the dev shell — re-run it to
  rebuild, reload and recreate.
