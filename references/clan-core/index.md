# clan-core

[Clan](https://docs.clan.lol) is a toolset for managing a fleet of NixOS
machines declaratively from one flake. `clan-core` is the flake input
that provides that toolset: a flake-parts module (`clan` option), the
`clan` CLI, a library of prebuilt services, a secrets system (vars), and
clanLib. Load this reference when a flake has a `clan-core` input.

Worked examples are from the home repo (`andrewthomaslee/home`) and the
fleet repo (`andrewthomaslee/borg`) — the patterns are generic;
substitute your repo's names.

## Where the docs are

| Topic | URL |
|---|---|
| Docs home (26.05) | https://docs.clan.lol · https://clan.lol/docs/26.05 |
| Inventory intro | https://clan.lol/docs/26.05/guides/inventory/intro-to-inventory |
| Autoincludes | https://clan.lol/docs/26.05/guides/inventory/autoincludes |
| Services intro | https://clan.lol/docs/26.05/guides/services/intro-to-services-revised |
| Service definition | https://clan.lol/docs/26.05/services/definition |
| Vars | https://clan.lol/docs/26.05/guides/vars/intro-to-vars |
| flake-parts guide | https://clan.lol/docs/26.05/guides/flake-parts |
| CLI reference | https://clan.lol/docs/26.05/reference/cli |
| `clan.core` options | https://clan.lol/docs/26.05/reference/clan.core |
| Source (gitea) | https://git.clan.lol/clan/clan-core |

## What it adds to a flake

Plain `nixosConfigurations` already cover per-machine config. clan-core
adds the fleet layer on top:

- **Machine registry** — one `inventory` lists every machine, its SSH
  deploy target, and tags. Adding a machine is adding an entry, not a
  wiring change.
- **Tag-driven config** — services and config attach to tags
  (`pc`, `server`, `dev`, ...), not to machine names. A new machine with
  the right tags automatically gets the right config.
- **Cross-machine services** — clanServices are reusable units with
  roles (client/server, per-machine) and multi-instance support,
  resolved from the inventory.
- **Build-time exports** — services publish facts (node addresses,
  interfaces, MTUs, endpoints) that other services consume during
  evaluation, not at deploy — see [Exports](#exports-and-the-strict-eval-check).
- **Secrets lifecycle** — vars generate, encrypt, store, and deploy
  secrets — see [clan vars](#clan-vars).
- **Operational tooling** — `clan machines update|install|ssh`, `clan
  vars`, `clan secrets`, `clan select`, `clan flash`.

Clan follows a "clan as library" design ([ADR
02](https://clan.lol/docs/26.05/decisions/02-clan-as-library)): every
piece is importable on its own. It composes with flake-parts via
flakeModules, so the flake's other outputs (packages, devShells,
checks) are unaffected.

Machine configs are evaluated statically from the inventory — clan
never contacts a machine to evaluate. `machineClass` defaults to
`"nixos"`; set `"darwin"` explicitly for Macs (there is no
auto-detection: NixOS and nix-darwin module systems differ).

## How it works with flake-parts

```nix
# flake.nix
inputs = {
  clan-core.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";

  # one nixpkgs instance serves the whole graph. Following
  # clan-core/nixpkgs tracks the nixpkgs clan's own CI tests against;
  # following your own nixpkgs instead means you control the pin but
  # drop ahead of clan's testing. Pick one and stay consistent.
  nixpkgs.follows = "clan-core/nixpkgs";

  # clan-core is a flake-parts flake: reuse its instance instead of
  # carrying a second flake-parts.
  flake-parts.follows = "clan-core/flake-parts";
};

outputs = inputs:
  inputs.flake-parts.lib.mkFlake {inherit inputs;} {
    imports = [
      inputs.clan-core.flakeModules.default   # adds the `clan` option
    ];
  };
```

Community flake inputs must follow the same clan-core instance:
`inputs.clan-core.follows = "clan-core"` on the community input.

The `clan` option then configures the fleet. Upstream examples put
everything inline (`clan.meta.name`, `clan.machines.<name> = {...}`);
the home repo keeps the tree modular instead:

```nix
# flake-parts/default.nix (flake output section)
clan = {
  # the fleet definition, as its own file (dendritic style)
  inventory = import (relativeToRoot "inventory.nix") {inherit customLib;};
  # extra module args for machine and service modules
  specialArgs = {inherit customLib inputs self;};
  # register repo-local clanServices under scoped names
  modules = {
    "@andrewthomaslee/machine-type" = relativeToRoot "clanServices/machine-type";
    "@andrewthomaslee/tags" = relativeToRoot "clanServices/tags";
  };
};
```

`clan.meta.name` and `clan.meta.domain` are required and must be unique
across the clans you manage (the home repo sets them inside
`inventory.nix`, as `inventory.meta`).

## How clan evaluates a flake

- **Autoincludes** — every directory under `machines/<name>/` is
  auto-registered as a machine; `configuration.nix`,
  `hardware-configuration.nix`, `facter.json`, and `disko.nix` inside
  are imported automatically. Machine dirs need no import list.
- **`.clan-flake`** — sentinel file that marks the repo root for the
  CLI and clan's Nix evaluation; falls back to `.git`, `.hg`, `.svn`,
  or `flake.nix`.
- **`inventory.json`** — clan-managed install metadata at the repo
  root. It merges into the inventory. Generated by clan tooling — leave
  it alone, same class of file as `flake.lock`.

Machine NixOS modules receive the args configured in
`clan.specialArgs`. If specialArgs are not threaded through, machine
evals die with `attribute '<arg>' missing` (the home repo passes its
`customLib` there; see the circularity exception in the `nix-style`
reference, "repo-root paths") .

## The inventory

`inventory.nix` is the machine source of truth. Two-part mental model:

```nix
inventory = {
  machines = { ... };   # what exists
  instances = { ... };  # what runs on it
};
```

### machines

```nix
inventory.machines = {
  nixos = {
    deploy.targetHost = "root@nixos";   # SSH address for clan deploy tooling
    tags = ["pc" "intel" "lan" "dev"];
  };
};
```

`tags` are labels resolved by instances. Clan provides built-in tags
`all`, `nixos`, and `darwin` (by `machineClass`); every other tag exists
because machines list it.

### instances

An instance puts a service to work: it names the service module, and
says which machines fill which roles:

```nix
inventory.instances = {
  # one user account per person — same service, twice, via module.name
  netsa = {
    module.name = "users";
    module.input = "self";        # optional: which flake input provides it
    roles.default = {
      settings = {
        user = "netsa";
        share = true;
      };
      tags = ["netsa"];            # machines by tag ...
      extraModules = [(relativeToRoot "users/netsa")];
    };
  };
};
```

- **Roles** — each service defines its roles (`default` for uniform
  services, named roles like `client`/`server` for asymmetric ones).
  Assign machines to a role **by tag** (`roles.<role>.tags = [...]`)
  and **by name** (`roles.<role>.machines."<name>" = {}`); both may be
  mixed.
- **Settings** — `roles.<role>.settings` applies role-wide; per-machine
  settings under `roles.<role>.machines.<name>.settings` merge on top.
  `= {}` means "include, nothing extra".
- **`module.name`** — the service module the instance uses. Defaults to
  the instance's attribute name; set it to reuse one service in several
  instances (e.g. `user-sally` and `user-fred`, both
  `module.name = "users"`). Not every service supports multi-instance —
  check its docs.
- **`module.input`** — which flake input provides the module (`"self"`
  for repo-local clanServices, an input name for community flakes).
  Unset means clan-core's own library (`users`, `sshd`, `wifi`,
  `borgbackup`, ...).

Upstream docs put inventory in a `clan.nix` file; the option is
`clan.inventory`, so a repo may split it into its own `inventory.nix`
(dendritic style — the home repo does) or inline it.

## clanServices

clanServices are clan's service model. A service is a module with
`_class = "clan.service"`, declaring roles and the NixOS config each
role applies:

```nix
# clanServices/machine-type/default.nix
{
  _class = "clan.service";
  manifest = {
    name = "machine-type";
    readme = "Machine classification/profiles";
  };

  roles = {
    pc = {
      perInstance.nixosModule = ./pc.nix;   # config for machines in role pc
      description = "Personal Computer";
    };
    iso = {
      perInstance.nixosModule = ./iso.nix;
      description = "nixos-installer";
    };
  };

  # common configuration for every machine of every instance
  perMachine.nixosModule = {self, inputs, lib, pkgs, ...}: {
    imports = [self.nixosModules.default];
    hostSpec.clan.enable = true;
  };
}
```

- `roles.<role>.perInstance.nixosModule` applies to machines holding
  that role in an instance; `perMachine.nixosModule` applies to all
  machines of the service regardless of role.
- Registration: the service lives at a repo path and is registered in
  `flake.clan.modules` under a scoped `@org/name` name (the home repo's
  convention, mirroring community flakes). Inventory instances then set
  `module.name = "@andrewthomaslee/machine-type"` and
  `module.input = "self"`.
- Inside a service module, normal NixOS module rules apply: import your
  repo's own modules (`self.nixosModules.default`), flip the repo's
  option namespace (`hostSpec.*`), and declare
  `clan.core.vars.generators` when the service needs secrets
  ([clan vars](#clan-vars)).

`clanServices/` sits at the repo root, **not** under `flake-parts/` —
import-tree loads `flake-parts/*.nix` as flake-parts modules, while clan
imports clanServices from the paths registered in `flake.clan.modules`.
Mixing them up double-loads or mis-classifies modules.

### The tag-service pattern

The home repo attaches config to tags with one clanService whose roles
are the tags themselves:

```nix
# clanServices/tags/default.nix
{
  _class = "clan.service";
  manifest.name = "tags";
  roles = {
    dev   = {perInstance.nixosModule = ./dev.nix; description = "Dev Computer";};
    intel = {perInstance.nixosModule = ./intel.nix;};
    lan   = {perInstance.nixosModule = ./lan.nix;};
    wan   = {perInstance.nixosModule = ./wan.nix;};
  };
}
```

```nix
# inventory.nix — each role is offered to machines carrying that tag
tags = {
  module.input = "self";
  module.name = "@andrewthomaslee/tags";
  roles = {
    dev.tags.dev = {};
    intel.tags.intel = {};
    lan.tags.lan = {};
    wan.tags.wan = {};
  };
};
```

`lan.nix` just sets `hostSpec.networking.lan.enabled = true`. The
payoff: tagging a machine in the inventory (`tags = ["lan" "dev"]`)
pulls in all its config — no service edit, no machine edit beyond the
tags.

### Community services

Official services ship in clan-core (see the [services
reference](https://clan.lol/docs/26.05/services/definition)). Community
flakes (e.g. [clan-community](https://git.clan.lol/clan/clan-community))
add more; they must follow the repo's clan-core input. The home repo
imports a community service's interface directly:

```nix
# inherit exportInterfaces from a community service flake-module
inherit
  ((import "${inputs.clan-community}/services/rancher/flake-module.nix" {}).clan)
  exportInterfaces
  ;
```

## Exports and the strict-eval check

ClanServices exchange facts **at build time** through exports: a service
publishes values (node IPs, interface names, MTUs, endpoints), and
consumer services select them during evaluation instead of asking for
addresses in settings. `inventory.nix` stays the single source of truth
— derived facts come from exports, never hardcoded.

Worked examples are from the borg repo (`andrewthomaslee/borg`), where
the `lan` transport service exports peer addresses/interfaces and the
`rke2` service consumes them.

### Publishing

A service declares which export interfaces it may emit, then publishes
values with `mkExports` (available in the args of `perInstance` and
`perMachine`):

```nix
# clanServices/lan/default.nix (condensed)
{
  _class = "clan.service";
  manifest = {
    name = "lan";
    exports.out = ["peer" "netif"];   # export interfaces this service emits
  };

  roles.default.perInstance = {mkExports, settings, ...}: {
    exports = mkExports {
      peer.hosts = [{plain = settings.ipv4;}];
      netif = {
        interface = settings.interface;
        inherit (settings) mtu;
      };
    };
  };
}
```

`mkExports` scopes every key under the emitting context
(`service:instance:role:machine` — a service may only export to its own
service scope; out-of-scope keys or an unregistered interface name in
`manifest.exports.out` throw at eval).

### Consuming

Consumers receive the whole exports tree and select with `clanLib`
helpers. Export keys are `service:instance:role:machine` scope strings;
`clanLib.selectExports` parses them into
`serviceName/instanceName/roleName/machineName` for filtering,
`clanLib.getExport` fetches one scope (throws with the full scope
breakdown if missing):

```nix
# a consumer service's perInstance (condensed from borg's rke2)
{
  peerHosts,
  exports,
  machine,
  ...
}: {
  # every machine's peer hosts in the named lan instance
  lanPeers = clanLib.selectExports
    (scope: scope.serviceName == "lan" && scope.instanceName == settings.network)
    exports;

  # one machine's netif export
  myNetif = clanLib.getExport {
    serviceName = "lan";
    instanceName = settings.network;
    machineName = machine.name;
  } exports;
}
```

### Export interfaces

An export interface is the shared option set for one export name.
Declare it once and register it in the flake's `clan` block; every
exporter of that name gets its options merged into its `mkExports`
value, so the schema cannot drift between producers:

```nix
# flake-parts/default.nix — clan block
exportInterfaces.netif = relativeToRoot "clanServices/lan/netif-interface.nix";
```

```nix
# clanServices/lan/netif-interface.nix
{lib, ...}: {
  options.mtu = lib.mkOption {
    type = lib.types.nullOr lib.types.int;
    default = null;   # every option needs a default — see below
    description = "Link MTU of the interface (null = leave default)";
  };
}
```

clan-core ships built-in interfaces (`peer`, `networking`, `endpoints`,
`auth`, `generators`); a repo registers its own under
`clan.exportInterfaces.<name>`. Services reference a name only after it
exists — `manifest.exports.out` naming an unregistered interface throws
with the list of available ones.

**Every export-interface option needs a `default` — or every exporter
must set it.** An option left undefined passes every other static gate
(formatter, lint, machine evals, VM tests) and only explodes when the
clan CLI deep-evaluates the exports tree during
`clan machines install/update` (via `clan select 'clan.?exports'`):
"accessed but has no value defined", mid bring-up, on the operator box.
This exact failure motivated the check below.

### The strict-eval check

Force the same deep evaluation inside `nix flake check` so an undefined
export leaf surfaces as a red check instead of a deploy-time failure:

```nix
# flake-parts/checks.nix — pattern from andrewthomaslee/borg
{
  self,
  ...
}: {
  perSystem = {pkgs, ...}: {
    checks.clan-exports-strict-eval = pkgs.runCommand "clan-exports-strict-eval" {
      # exportsJson forces every export leaf at *eval* time: checks are
      # evaluated (not built) by `nix flake check`, so a throw in the
      # toJSON fails the check — the same deep eval `clan machines
      # install/update` performs via `clan select 'clan.?exports'`.
      exportsJson = builtins.toJSON self.clan.exports;
    } "touch $out";
  };
}
```

Add the check once any service sets `manifest.exports.out` — with no
exports, `self.clan.exports` is empty and the check passes trivially.
The check serializes with `builtins.toJSON` to mirror
`nix eval .#clan.exports --json`; do not extend it to
`clan.exportInterfaces` (see below).

## The clan CLI

The CLI is the fleet's control plane. It needs `CLAN_DIR` pointing at
the repo root (the home repo's devShell shellHook sets it via varlock —
see the `nix-style` reference, "DevShell and the agent") and the flake
must be in the git tree.

| Command | What it does |
|---|---|
| `clan machines list` | list machines from the inventory |
| `clan machines create <name>` | scaffold a machine dir |
| `clan machines update <machine>` | deploy config over SSH |
| `clan machines install <machine>` | first-time install |
| `clan ssh <machine>` | ssh to a machine |
| `clan vars generate/list/get <machine>` | secrets workflow (below) |
| `clan secrets get <name>` | decrypt a secret (machine age keys) |
| `clan select` | query nixos values from the flake |
| `clan show` / `clan state` | clan meta / machine state |
| `clan flash` / `clan backups` / `clan templates` / `clan init` | imaging, backups, scaffolding |

Scripting notes:

- The CLI prints lines like `warning: unknown setting 'eval-cores'` on
  stdout. Filter any line starting with `warning:` before feeding output
  to a parser. The home repo's `get-keys` app
  (`flake-parts/apps/get-keys.nix`) wraps the CLI in Python with that
  filter to extract machine age keys for provisioning.
- The CLI is available as a package:
  `inputs'.clan-core.packages.clan-cli` (use it in devShell
  `runtimeInputs` or apps).

## How machines get updated

Two deployment styles are available; they are orthogonal to inventory,
tags, and vars, which remain the source of truth either way:

- **Pull-based (the home repo's style)** — CI publishes a release to
  FlakeHub; machines run the `apply-*` packages (`apply-now home`,
  `apply-and-reboot home` for a clean remote reboot). `fh apply`
  mechanics: the `determinate` reference. CI never SSH-pushes; the
  `deployment.requireExplicitUpdate` option (set in
  `flake-parts/nixosModules/clan.nix`) makes machines refuse implicit
  remote updates, so a stray `clan machines update` fails loudly instead
  of silently racing the pull flow.
- **Push-based (`clan machines update <machine>`)** — direct SSH deploy
  from the operator box; needs `deploy.targetHost` in the inventory. Use
  for first-time installs (`clan machines install`) and ad-hoc bring-up.

`clan machines install <machine>` is still the first-time path: it
partitions (disko), installs, and bootstraps vars; after that, updates
flow through the chosen style.

## clan vars

Vars are clan's secrets and generated-values system. A **generator** is
a named unit that produces one or more **files** — either by prompting
the operator, by running a script, or both. Files marked secret are
encrypted at rest in the repo and decrypted on the target machine at
activation; public files (keys' public halves, generated certs
metadata) are stored as plain `value` files.

The system exists so secrets are never in Nix source, never in plaintext
in the store, and still live **in the flake repo** — encrypted — so a
flake checkout is self-contained.

### Declaring generators

Declared in NixOS module land, anywhere a module evaluates (the home
repo declares them in `flake-parts/nixosModules/*.nix`, next to the
config that consumes them):

```nix
# flake-parts/nixosModules/tailscale.nix
config = lib.mkIf cfg.enable {
  # prompt-only generator: value comes from the operator, stored once
  clan.core.vars.generators.tailscale = {
    share = true;                       # one var under vars/shared/
    prompts.auth_key.persist = true;    # keep the answer across regenerations
  };

  services.tailscale.authKeyFile =
    config.clan.core.vars.generators.tailscale.files.auth_key.path;
};
```

```nix
# script generator: runs in a sandbox, writes files to $out
clan.core.vars.generators."storagebox-ssh-${cfg.boxUser}" = {
  share = true;
  files.ssh-private-key = {};                 # secret (default)
  files.ssh-public-key.secret = false;        # public var, stored as value
  runtimeInputs = with pkgs; [openssh];
  script = ''
    mkdir -p $out
    ssh-keygen -t ed25519 -f $out/ssh-private-key -N "" -C "${cfg.boxUser}-storagebox"
    mv $out/ssh-private-key.pub $out/ssh-public-key
  '';
};
```

Generator option anatomy:

- `share = true` — store one copy under `vars/shared/` (for vars many
  machines consume) instead of per-machine copies.
- `files.<name>` — declared outputs. `secret = true` (default)
  encrypts; `secret = false` stores plaintext. Extra consumer wiring:
  `owner`, `mode` (`"0400"`), `neededFor = "services"` installs the
  decrypted file before the units that read it start.
- `prompts.<name>` — ask the operator for a value instead of computing.
  `type = "hidden"` for secrets, `persist = true` to keep an existing
  answer when regenerating.
- `runtimeInputs` / `script` — the computation half; `$out` is where
  produced files must be written. Script and prompts can combine.

Two generators with the same name from different modules must merge —
declare with `config.clan.core.vars.generators = lib.mkMerge (...)`
(the home repo does that in `github-mcp.nix` and `morph-api-key.nix`,
where generators are conditionally created per user).

### Storage layout

Encrypted vars are committed to the flake repo:

```
vars/
├── shared/
│   └── openssh-ca/
│       ├── ssh_host_ed25519_key.pub/value   # public: plaintext
│       └── ssh_host_ed25519_key/secret      # secret: encrypted
└── per-machine/
    └── nixos/
        └── <generator>/
            └── <file>/(secret|value)
```

The `vars/` directory belongs to clan tooling. Never hand-edit an
encrypted `secret` file — create or rotate values through the CLI.

### Consuming a var

Read generated files through the generator's file options — a store
path materialized at build time:

```nix
services.tailscale.authKeyFile =
  config.clan.core.vars.generators.tailscale.files.auth_key.path;

fileSystems."/mnt/box".options = [
  "sftp_key_file=${config.clan.core.vars.generators."storagebox-ssh-box".files."ssh-private-key".path}"
];
```

Never copy a var's value into config; always reference `.path` so the
encrypted-in-repo / decrypted-on-target model holds.

### Workflow

```bash
# 1. after adding a service or generator: generate missing vars
clan vars generate <machine>          # prompts interactively; empty input auto-generates

# 2. inspect
clan vars list <machine>              # secrets shown as ********
clan vars get <machine> <generator>/<file>   # decrypt and print one value

# 3. deploy (or push vars directly)
clan machines update <machine>        # home repo: fh apply instead
clan vars upload <machine>            # push generated vars to a machine
```

- `clan vars generate` is idempotent — existing vars are skipped; rerun
  after adding a generator.
- Rotate: `clan vars generate <machine> --generator <name>
  --regenerate` (per-generator) or `--regenerate` (everything), then
  redeploy.
- `clan vars get` output is for consoles and provisioning scripts, not
  for pasting into Nix.

### Keys and backends

- Vars are encrypted with an **age key** at
  `~/.config/sops/age/keys.txt`, auto-created on the first
  `clan vars generate`. **Back it up** — lose it and the vars are
  unrecoverable.
- Every machine also gets its own age keypair, stored as a var/secret
  of its own. The target machine decrypts its vars at activation using
  that private key (sops backend upload directory defaults to
  `/var/lib/sops-nix/key.txt`).
- **Backends**: `age` (default) and `sops`. The sops backend enables
  one-shot provisioning: the machine's age key is extracted with
  `clan secrets get <machine>-age.key`, injected into a fresh VM (e.g.
  terraform cloud-init writes `/var/lib/sops-nix/key.txt`), and the
  machine decrypts everything on first boot — no manual
  secrets-upload step after provisioning. See the borg repo docs
  (`documentation/docs/clan/sops.md`) for the full terraform/CI pattern.

### CI and scripted use

- CI needs the admin age key as `SOPS_AGE_KEY` to decrypt vars. This
  repo exports it via varlock from `.env` in the devShell shellHook; on
  GitHub Actions, store it as a secret and set the env var directly.
- When a machine key is extracted into CI, mask it
  (`echo "::add-mask::$KEY"` in Actions) so it never lands in logs.

### The home repo's vars

| Vars | Generator | Consumer |
|---|---|---|
| `tailscale` auth key | `flake-parts/nixosModules/tailscale.nix` | `services.tailscale.authKeyFile` |
| `storagebox-ssh-<user>` keypair | `flake-parts/nixosModules/storagebox.nix` | rclone sftp mount option |
| `github-mcp` PAT | `flake-parts/nixosModules/github-mcp.nix` (mkMerge, per-user) | opencode MCP config |
| `morph-api-key` | `flake-parts/nixosModules/morph-api-key.nix` | morph API service |
| `openssh-ca`, `pki-root-ca`, `cloudflare-warp`, `rancher-*` | committed under `vars/shared/` | CA/host trust, rancher agents |

`vars/per-machine/<machine>/` exists for every inventory machine — new
machines get their dir on first `clan vars generate`.

## Testing clanServices with NixOS VM tests

clanServices are plain NixOS config in the end, so the hermetic VM-test
harness tests them directly. The test file imports the repo's
`nixosModules.default` (not the clan machinery) and flips the
`hostSpec.*` options the service's `perInstance`/`perMachine` modules
would set — see the `vm-tests` reference for the full hermeticity rule,
size variants, and the agent loop. The clan-specific additions:

- Import `inputs.clan-core.nixosModules.clanCore` and set minimal
  `clan.core.settings = {directory = self; machine.name = "<test>";}`
  when the module under test reads `clan.core.*` (the opencode test
  does this so vars-to-sops wiring evaluates).
- Give the test machine sshd so clan's sops backend can derive its age
  key from the SSH host key (no provisioned key exists for a
  non-inventory test VM).
- Fake secrets as `/etc` plain files with an option override pointing
  at them (`patFile = "/etc/vm-github-pat"`-style) instead of real clan
  vars.

Example: `vm-tests/opencode.nix` in the home repo wires
`clan.core.settings` + fake PAT/key files and asserts MCP server
configs and generated files end-to-end inside the VM.

## Gotchas

- **`git add` before eval** — clan evaluates machine configs and
  services from the git tree; untracked files are invisible to Nix.
- **`inventory.json` is clan-managed** — regenerated by tooling; never
  hand-edit (same class as `flake.lock`, `disko.nix`, `facter.json`).
- **Tags must resolve** — a role assigned by tag matches only machines
  carrying that tag; keep tag sets consistent between `machines` and
  `instances`, or config silently applies to nothing.
- **Export options need a default** — an export-interface option
  without a `default` (unset by some exporter) passes all static gates
  and only throws when the clan CLI deep-evaluates exports during
  `install/update`; gate it with `checks.clan-exports-strict-eval`
  (see [Exports](#exports-and-the-strict-eval-check)).
- **Don't `--json` the interfaces** — `nix eval
  .#clan.exportInterfaces --json` can never pass: clan's `apply` wrap
  embeds `mkOption` functions in the applied value. Evaluate interfaces
  through clan's submodule wrap instead (the borg repo's
  `clan-export-interfaces-strict-eval` does this); serialize only
  `clan.exports`.
- **Machine-eval arg circularity** — machine modules get args via
  `clan.specialArgs`, but a module's *config value* cannot use them
  (see the `relativeToRoot` exception in the `nix-style` reference).
- **`deployment.requireExplicitUpdate`** — the home repo sets it
  (`flake-parts/nixosModules/clan.nix`) so machines refuse implicit
  remote updates; pull-based deployment instead.
