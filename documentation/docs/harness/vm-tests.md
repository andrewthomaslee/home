# VM Tests

NixOS VM tests live in the dedicated `vm-tests/` directory at the
repository root. They are auto-discovered, exposed in three global-timeout
tiers, and deliberately **not** part of `nix flake check` (static checks
never boot a VM). See also the
[OpenShell gateway test's own header](../openshell/index.md#6-testing).

## Discovery and tiers

Every `vm-tests/<test-name>.nix` (a function
`{self, inputs, pkgs, lib, size, sizeCfg}` returning a `runNixOSTest`
derivation) is auto-discovered by `flake-parts/tests.nix` and exposed as
`legacyPackages.vmTests."<name>-<size>"`. The three tiers differ **only**
in the driver `global_timeout` — resource sizing (cores/RAM/disk) is not
tiered here; tests read `size` themselves to gate expensive phases:

| Size | Suffix | `global_timeout` |
|---|---|---|
| Small | `-sm` | 1200 s |
| Medium | `-md` | 2400 s |
| Large | `-lg` | 5400 s |

The runner app is `flake-parts/apps/vm-test.nix`
(`nix run .#vm-test -- …`).

## Available test suites (`nix run .#vm-test -- --list`)

**`openshell-gateway-<sm|md|lg>`** (`vm-tests/openshell-gateway.nix`) —
the OpenShell gateway nixosModule exercised hermetically: a throwaway
PKI (CA + leaf certs + Ed25519 JWT keys) is generated at build time and
handed to the module via the `provisionSecrets = false` overrides, so no
clan vars machinery is needed. Asserts, for a non-root user with the
openshell CLI enabled:

- the gateway unit comes up and the managed VM-driver subprocess spawns
  its UDS (`sm`/`md`/`lg`),
- the CLI's system registration + mTLS bundle are in place and
  `openshell status` reports Connected/Authenticated for both root and
  the user (`sm`/`md`/`lg`),
- **lg only**: creates a real sandbox (pulls the `nvcr.io` image, boots
  a nested libkrun microVM) and execs `uname -r` in it. Sandboxed nix
  builds have no external network, so this tier needs driver mode:
  `nix run .#vm-test -- openshell-gateway-lg --driver`.

## Running

```bash
nix run .#vm-test -- --list                     # list all test names
nix run .#vm-test -- openshell-gateway-sm       # sandboxed (CI-style)
nix run .#vm-test -- openshell-gateway-lg --driver   # driver mode: logs + artifacts
```

**Sandbox mode** (default): builds the full test derivation; the driver
runs inside the Nix build sandbox, exit code = test result, log = build
log (`-L`).

**Driver mode** (`--driver`): builds only the `.driver` output and runs
the standalone `nixos-test-driver` outside the sandbox:

| Flag | Effect |
|---|---|
| `--out DIR` | artifact dir (default `/tmp/home-vm-tests/<name>`) |
| `--keep-state` (`-K`) | keep VM state between runs (resumable) |
| `--interactive` (`-I`) | drop into the test-driver Python REPL |
| `--timeout SEC` | external watchdog (default `global_timeout` + 300 driver / 3900 sandboxed) |

Artifacts after a driver run:

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

Requirements: `/dev/kvm` (software emulation is impractically slow;
nested-KVM tiers like `openshell-gateway-lg` additionally need external
network in driver mode).
