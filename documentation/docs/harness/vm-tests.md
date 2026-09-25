# VM Tests

The [OpenCode harness](index.md) (OpenCode + headroom + MCP servers) is
validated by NixOS VM tests. VM tests live in the dedicated `vm-tests/`
directory at the repository root. They are auto-discovered, dynamically
scaled into 3 resource sizes, and exposed at
`legacyPackages.vmTests.<name>-<size>`. They are deliberately **not** part
of `nix flake check` (static checks never boot a VM).

## Sizing schema

Every VM test defined in `vm-tests/<test-name>.nix` automatically generates
three size variants (engine: `flake-parts/tests.nix`, runner app:
`flake-parts/apps/vm-test.nix`):

| Size | Suffix | Cores | RAM | Disk |
|---|---|---|---|---|
| **Small** (Baseline) | `-sm` | 2 cores | 4 GB (`4096 MiB`) | 30 GB (`30720 MiB`) |
| **Medium** (2x) | `-md` | 4 cores | 8 GB (`8192 MiB`) | 60 GB (`61440 MiB`) |
| **Large** (3x) | `-lg` | 6 cores | 12 GB (`12288 MiB`) | 90 GB (`92160 MiB`) |

## Available test suites (`nix run .#vm-test -- --list`)

1. **`opencode-<sm|md|lg>`** (`vm-tests/opencode.nix`):
   - 1 KVM VM, two home-manager users on one machine (OpenCode v2).
   - **alice** — full desktop profile with headroom + opencode: asserts
     binaries on PATH (headroom, opencode, playwright-mcp,
     github-mcp-server), native V2 `opencode.json` generation
     (`mcp.servers.*` entries incl. headroom/openrouter/playwright, the
     `providers.deepseek.settings.baseURL` proxy override, the ordered
     `permissions` array, `agents.title.model`, and the `plugins` list),
     the devenv MCP fallback project, `headroom-proxy.service` healthcheck
     (`/livez`), stdio JSON-RPC MCP CCR compression roundtrip
     (`/etc/vm-mcp-probe.py`), a second stdio probe driving the Playwright
     MCP server (`initialize` → `tools/list`, asserting
     `browser_navigate`/`browser_snapshot`/`browser_click`), a third stdio
     probe driving the `github-mcp-server-opencode` wrapper (PAT method
     with a fake `/etc/vm-github-pat` — a successful `tools/list` proves
     the PAT file was read and exported, since the server exits without
     it), and a devenv MCP probe (`/etc/vm-devenv-probe.py`) proving the
     wrapper fell back to the pinned `~/.config/devenv-agent` project
     (fully offline: devenv itself is pinned as a `path:` input).
   - **netsa** — headless agent profile ([profile-netsa-agent](kubevirt-agent.md))
     plus the other exclusive auth branch (`mcp.servers.github` must be the
     `remote` oauth entry, `https://api.githubcopilot.com/mcp/`), the
     six Cloudflare remote MCP servers, MDN, the Morph Fast Apply V2 plugin
     with a fake `/etc/vm-morph-key` (MORPH_API_KEY wrapper export), a
     second headroom proxy on port 8788, its own MCP CCR roundtrip
     (`/etc/vm-web-mcp-probe.py`), and the home-manager native
     `programs.opencode.web` service (`opencode serve` HTTP title check
     on port 4096).

2. **`opencode-desktop-<sm|md|lg>`** (`vm-tests/opencode-desktop.nix`):
   - Boots the packaged **OpenCode Desktop** (Electron) app under an Xvfb
     virtual display and screenshots the real rendering (`scrot` at two
     points, pulled out as artifacts). This test exists because the
     desktop app hung on its splash screen; the captured app log, window
     tree, process list and service-registration file diagnose exactly
     which startup step stalls.
   - Startup chain asserted: the bundled sidecar launcher present and
     runnable (`resources/opencode-cli --version`), the app window mapped
     (`xdotool search --name OpenCode`), the staged v2 CLI sidecar process
     alive (`opencode-cli serve --service`), and the main-process log line
     `v2 CLI background service ready` in the app's own electron-log
     (`~/.config/ai.opencode.desktop/logs/<stamp>/main.log`).
   - Diagnostics are captured and copied out as artifacts **before** any
     assertion (`chromium.log`, `desktop-0.png`/`desktop-1.png`,
     `app-artifacts/` with the app `main.log`, the service registration
     `service.json` and the CLI stage dir listing), so a red run always
     explains itself.
   - Two upstream Nix-packaging bugs are fixed in `overlays/default.nix`
     (see the opencode/opencode-desktop entries there): the bundled CLI
     must be a self-contained launcher (the wrapped binary's shim loses
     its `.opencode-wrapped` sibling when the app copies it into the user
     profile), and the CLI's service registration filename must be the
     flat `service.json` the desktop client polls (`OPENCODE_CHANNEL`
     baked as `latest`).

## Running

```bash
nix run .#vm-test -- --list                     # list all test names
nix run .#vm-test -- opencode-sm                # sandboxed (CI-style)
nix run .#vm-test -- opencode-lg --driver       # driver mode: logs + artifacts
```

**Sandbox mode** (default): builds the full test derivation; the driver
runs inside the Nix build sandbox, exit code = test result, log = build
log (`-L`).

**Driver mode** (`--driver`): builds only the `.driver` output and runs the
standalone `nixos-test-driver` outside the sandbox:

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

!!! note "VM test machines need a sops key source"
    Both test machines are **not in inventory** (no provisioned clan age
    key), so clan-core's vars → sops-nix deployment fails evaluation with
    "No key source configured for sops". Both nodes therefore set
    `services.openssh.enable = true` — sops-nix derives its key from the
    VM's SSH host key. Keep that line if you touch the test configs.
