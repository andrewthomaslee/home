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

1. **`headroom-opencode-<sm|md|lg>`** (`vm-tests/headroom-opencode.nix`):
   - 1 KVM VM, home-manager profile with headroom + opencode enabled.
   - Asserts binaries on PATH (headroom, opencode, playwright-mcp,
     github-mcp-server), `opencode.json` generation (headroom MCP + plugin
     + provider override + `mcp.openrouter`/`mcp.playwright` entries),
     `headroom-proxy.service` healthcheck (`/livez`), stdio JSON-RPC MCP
     CCR compression roundtrip (`/etc/vm-mcp-probe.py`), a second stdio
     probe driving the Playwright MCP server (`initialize` → `tools/list`,
     asserting `browser_navigate`/`browser_snapshot`/`browser_click`), and
     a third stdio probe driving the `github-mcp-server-opencode` wrapper
     (PAT method with a fake `/etc/vm-github-pat` — a successful
     `tools/list` proves the PAT file was read and exported, since the
     server exits without it).
   - A second lightweight user (`bob`) exercises the other exclusive auth
     branch: `mcp.github` must be the `remote` oauth entry
     (`https://api.githubcopilot.com/mcp/`).
2. **`headroom-opencode-web-<sm|md|lg>`**
   (`vm-tests/headroom-opencode-web.nix`):
   - Tests a KubeVirt AI agent machine using the headless `netsa` profile
     ([profile-netsa-agent](kubevirt-agent.md)).
   - Asserts headless dev tooling on `netsa`'s PATH, `opencode.json`
     generation (headroom MCP + plugin + `mcp.openrouter`/`mcp.playwright`
     entries), OpenCode Web HTTP access on port 4096
     (`<title>OpenCode</title>`), Headroom proxy `/livez`, and MCP CCR
     roundtrip (`/etc/vm-mcp-probe.py`).

## Running

```bash
nix run .#vm-test -- --list                             # list all test names
nix run .#vm-test -- headroom-opencode-sm               # sandboxed (CI-style)
nix run .#vm-test -- headroom-opencode-sm --driver      # driver mode: logs + artifacts
nix run .#vm-test -- headroom-opencode-web-sm --driver  # driver mode for web test
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
