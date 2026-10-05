# OpenShell

NVIDIA [OpenShell](https://docs.nvidia.com/openshell/) — the sandboxed runtime
for AI agents — on this fleet: what is deployed today, and the researched
(but not implemented) plan for a multi-host clan service version.

## Current state: `nixosModules.openshell-gateway`

A single-machine, local-only gateway is implemented as an exported NixOS
module (`flake-parts/nixosModules/openshell-gateway.nix`, exported as
`flake.nixosModules.openshell-gateway`):

- **Gateway**: `openshell-gateway` as a systemd service (dedicated
  `openshell` user), TLS + mTLS on `127.0.0.1:17670`, VM (libkrun) compute
  driver by default (`computeDriver = "docker"` also supported).
- **Secrets**: clan vars generators (`provisionSecrets = true`, default):
  `openshell-local-ca` (shared CA, `ca.key` never deployed),
  `openshell-local-gateway-tls`, `openshell-local-client-tls`,
  `openshell-local-jwt` (Ed25519). Run `clan vars generate <machine>` after
  enabling. `provisionSecrets = false` plus the `*File` options accepts
  externally managed material (this is how the vm test works).
- **CLI**: `pkgs.openshell` installed for all users; the system registry
  `/etc/openshell` seeds a `local` gateway registration with the machine's
  mTLS bundle and sets it active. Home-manager users get the per-user
  mirror automatically (see the per-user mTLS caveat below).
- **The mTLS bundle is per-user CLI state — bridged automatically for
  home-manager users.** Only `active_gateway` and `metadata.json` fall
  back to the system registry; `gateways/<name>/mtls/` is read from
  `~/.config/openshell`. The NixOS module therefore injects a
  home-manager `sharedModules` snippet (guarded by `options ?
  home-manager.sharedModules`, all values `mkDefault`) that sets
  `systemGateway`, `gateway.name` and `gateway.endpoint` for **any
  home-manager user that enables the CLI** — a user needs nothing but
  `homeSpec.programs.openshell.enable = true`; explicit per-user settings
  still win. Without home-manager, a user runs
  `ln -s /etc/openshell ~/.config/openshell` instead.

Enabling (on `ghost` today):

```nix
hostSpec.services.openshell.gateway.enable = true;
```

Packages (`pkgs.openshell`, `pkgs.openshell-gateway`,
`pkgs.openshell-driver-vm`) come from the repo overlay
(`flake-parts/packages/openshell*.nix`: the CLI is built from the pinned
`github:NVIDIA/OpenShell` input; gateway/driver-vm are prebuilt release
binaries, patchelf'd — the release `openshell-driver-vm` embeds its whole VM
runtime, so no separate runtime tarball is needed).

### Hard-won gateway requirements (read before touching the config)

- **Launch authentication is mandatory.** The VM driver rejects sandbox
  creation without a gateway-minted `SandboxLaunchAuthentication`, which
  requires `gateway_jwt` Ed25519 keys — even for a loopback-only plaintext
  gateway. There is no dev flag to disable it.
- **TLS pulls in three identities.** With TLS enabled the gateway wants:
  1. server cert/key (`[openshell.gateway.tls]`),
  2. `client_ca_path` (validates CLI client certs; set ⇒ mTLS required),
  3. a complete `guest_tls_ca/cert/key` bundle — the *supervisor's* client
  identity for dialing the gateway (a plain TLS cert is not enough; startup
  fails). We reuse the machine client cert for `guest_tls_*`.
- **`programs.nix-ld` is required for the VM driver.** The release driver
  embeds its host supervisor as a dynamically linked gnu binary, extracts it
  into `<state_dir>/host-runtime`, and execs it — on NixOS that needs the
  nix-ld loader shim.
- **The driver is spawned, not socket-connected.** The gateway launches
  `openshell-driver-vm` from `[openshell.drivers.vm].driver_dir` and talks
  gRPC over `<state_dir>/run/compute-driver.sock`; the same-UID/PID checks
  are handled internally.
- **`grpc_endpoint` must match the gateway cert SANs** — the host
  supervisor validates the TLS handshake. We use
  `https://127.0.0.1:<port>` and put `IP:127.0.0.1` in the cert.
- `database_url` is env-only (`OPENSHELL_DB_URL`); it must not appear in
  `gateway.toml`. The file is schema `version = 2` with the scalar
  `compute_driver = "vm"` (VM is never auto-detected).
- **The embedded `libkrun.so` needs system libraries at dlopen time.** The
  release driver extracts its embedded runtime into
  `$XDG_DATA_HOME/openshell/vm-runtime/<version>/` and dlopens `libkrun.so`,
  whose transitive deps (`libcap-ng`, `libseccomp`, `libnuma`, openssl)
  are not linked by the driver binary — autoPatchelf cannot see them. The
  `openshell-driver-vm` package therefore wraps the binary with
  `LD_LIBRARY_PATH` (packages: nixpkgs attr is `libcap_ng`, the `.so` is
  `libcap-ng.so.0`).
- CLI exec syntax is `openshell sandbox exec -n <name> -- <cmd>` (the
  sandbox name is a flag; a bare positional becomes part of the command).
- The rolling `vm-runtime` GitHub release tarball (libkrun/libkrunfw/umoci)
  is **not** needed with the release driver binary (everything is embedded);
  it is only for dev builds and the QEMU backend. Do not pin its hash — it
  is rebuilt on demand and the hash rots.

### Testing

`vm-tests/openshell-gateway.nix` (run via `nix run .#vm-test --
openshell-gateway-sm`, or `-- openshell-gateway-lg --driver`): builds a
throwaway CA/certs/JWT-keys store path at build time, feeds them through
the `provisionSecrets = false` overrides, boots the gateway + managed VM
driver in a nested-KVM QEMU machine, and asserts `openshell status`
reports `Connected` + `Authenticated` over mTLS. The `lg` tier
creates a real sandbox — pulls the image, boots a libkrun microVM inside
the test VM, and execs `uname -r` in it (needs external network, so run
it with `--driver`; sandboxed nix builds have no network). Both tiers are
fail-fast: a `wait_unit_or_fail` helper aborts with the unit journal as
soon as the service enters a failed/inactive state instead of hanging
until the driver's `global_timeout`, and every `wait_for_*` carries an
explicit timeout. Verified: lg passes end-to-end in ~20s.

## Future plan: `@andrewthomaslee/openshell` clan service

A multi-host variant where any machine can run a gateway and every machine
is a client of every gateway, modeled as a clan service with `server` /
`client` roles. Status: **researched and designed, then deliberately
deferred** — the single-machine module above is the shipping artifact. This
section preserves the design and everything learned, so the work can be
resumed without re-deriving it.

### Design

- `clanServices/openshell/` with `roles.server` (gateway, also a client of
  all servers) and `roles.client` (CLI + registrations). Every machine in
  the instance is a client of every server — including the servers
  themselves — so the CLI wiring lives in `perMachine`, which reads the
  instance's `roles.server.machines` scope directly (the borgbackup
  pattern); no exports needed.
- The CLI natively supports multiple gateways (`gateway add/list/select`,
  `-g`/`OPENSHELL_GATEWAY` per command); the system registry holds many
  `gateways/<name>/` entries with one `active_gateway` fallback.
- Vars generators: shared instance CA (`ca.key` `deploy = false`), per-server
  `gateway-tls` (SANs: machine name, `<machine>.<domain>`, `dnsName`),
  shared `guest-tls` (supervisor identity), per-server Ed25519 `jwt`, and
  per-machine `client-tls` (the machine-wide CLI identity, mode 0644 —
  per-machine, *not* per-user, matching the host-SSH-key threat model).
- Role settings carry `provisionCerts` + `*File` overrides so external PKI
  material works without generators (same escape hatch as the module).
- Split into pure factories (`config.nix` TOML builder, `server-module.nix`,
  `client-module.nix`) + thin clan glue, so tests can import the factories
  without clan machinery — exactly the layering the nixosModule uses today.

### Transport research

clan-core ships `mycelium`, `wireguard`, `yggdrasil`, `zerotier`;
clan-community has `wireguard-star`. All follow one pattern: a vars
generator for node keys, then `exports peer.hosts` populated via
`clanLib.getPublicValue` so consumers get overlay IPs at eval time. **This
fleet already runs Tailscale on every machine** (`tailscale0` is a trusted
interface), so the planned default was: gateway bound to `0.0.0.0` with the
firewall port scoped to `tailscale0`, clients dialing `<machine>` via
MagicDNS, `bindInterface = "tailscale0"` as the server role default
(`"all"` as escape hatch). Mycelium/wireguard would only matter for
machines without Tailscale.

### Clan-native VM testing (clan machinery, mock fleets)

clan-core has first-class support for testing services against **mock
inventories**:

- `perSystem.clan.nixosTests.<name>` (clan-core
  `lib/flake-parts/clan-nixos-test.nix`) accepts a test module that sets
  `clan.directory`, a mock `clan.inventory` (machines + instances +
  `clan.modules` registrations), and `testScript`; upstream
  `hello-world`/`wifi`/`borgbackup`/`syncthing` ship `tests/vm/default.nix`
  this way. It becomes `checks.<system>.<name>` via `nixosLib.runTest` +
  `clan-core.modules.nixosTest.clanTest`.
- **Vars generators run automatically at test build** through
  `varsExecutor.generateVarsDerivation` (IFD on the host system, fixed test
  age key) — no pre-generation. `clan-generate-test-vars` exists only for
  expensive/prompt generators.
- `test.useContainers = true` (default, nspawn) is mutually exclusive with
  user `nodes.<name>`; a gateway test needs `useContainers = false` +
  `nodes` (systemd, KVM, kernel modules).
- Name resolution in the mock fleet: an `importer` instance with
  `roles.default.extraModules` setting `networking.extraHosts`
  (syncthing-test pattern), plus static `eth0` addresses on the nodes.
- Machine pkgs come from the machine's own nixpkgs config (`overridePkgs`
  is only forced for the vars-eval config), so an `importer` instance
  spreading `nixpkgs.overlays` injects the service's packages — keeping the
  service itself free of any building/fetching (packages must come from the
  consuming flake's overlay).
- **CI caveat:** `clan.nixosTests` land in `checks`, and this repo's CI is
  GitHub `ubuntu-latest` — **no KVM**. VM tests must stay in
  `legacyPackages.vmTests` (via `flake-parts/tests.nix`) and be run with
  `nix run .#vm-test`, never through `clan.nixosTests`, until CI has KVM
  runners.

### Lessons learned (implementation gotchas)

- **Nix language**: the pipe operator (`|>`) is not enabled on this flake's
  Nix — use `lib.pipe`/nesting. `builtins.pathExists` guards are needed for
  `readDir`-based autodiscovery of optional directories.
- **Clan service scoping**: `config` is not in scope in `perMachine`/
  `perInstance` outer `let` bindings (lexical scoping) — functions that
  resolve vars generator paths must take `config` as an explicit parameter
  and be called inside the `nixosModule` body. `perMachine` has **no
  `settings` argument** (role settings read via
  `instances.<i>.roles.<r>.machines.<m>.settings`); `perInstance` results
  are `{nixosModule = ...}` attrsets — `concatLists` over them fails,
  extract `.nixosModule`.
- **OpenShell CLI in scripts**: piping `openshell ... | grep -q` makes the
  CLI panic on EPIPE (exit 101) — redirect to a file first, then grep.
- **Sandboxed nix builds have no external network** — any tier pulling a
  container image only works in `--driver` mode (driver runs outside the
  sandbox).
- **The release `openshell-driver-vm` binary is glibc-dynamic** — needs
  `autoPatchelfHook` on NixOS.
- Open question never resolved (clan-core at the pinned rev): during a
  `clanTest` machine eval, an import of `<serviceDir>/tests/default.nix`
  was demanded even though nothing referenced it — likely an undocumented
  auto-discovery convention (cf. the unused `lib/clanTest/relativeDir.nix`
  infra). If the clan service is revived, place a `tests/default.nix`
  shim or investigate `clanInternals.inventoryClass` first.
