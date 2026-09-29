# clanservices — authoring clan.service modules

How to author a clanService in the official clan-core style. The module
mechanics below apply in **any** clan flake; the Registration and
Verification sections describe the home flake repo's conventions
(github.com/andrewthomaslee/home). Sources of truth (cloned at
`~/clan-core`):

- Module spec: `lib/inventory/distributed-service/service-module.nix`
  (the authoritative option definitions — read it before exotic use)
- Authoring guide: `docs/src/guides/services/community.md`
- Exports guide: `docs/src/guides/services/exports.md`
- Working examples: `clanServices/hello-world` (minimal), `sshd`
  (roles + vars + certificates), `borgbackup` (vars, constraints)

Scope: authoring and static verification only. Runtime/VM testing of
services is intentionally out of scope here.

## Module skeleton

A clanService is a module with `_class = "clan.service"`, registered
under `clan.modules`, instantiated through `inventory.instances`. One
directory per service under the repo-root `clanServices/` tree:

```
clanServices/
  my-service/
    flake-module.nix   # registration (see Registration below)
    default.nix        # the service module
    README.md          # manifest.readme source
    role.nix           # optional: split role implementations
```

Minimal skeleton (the `hello-world` shape):

```nix
{
  _class = "clan.service";
  manifest.name = "clan-core/hello-world";
  manifest.description = "Minimal example clan service that greets the world";
  manifest.categories = [ "Development" ];
  manifest.readme = builtins.readFile ./README.md;

  roles.morning = {
    description = "A morning greeting machine";
    interface = {lib, meta, ...}: {
      options.greeting = lib.mkOption {
        type = lib.types.str;
        default = "Good morning";
        description = "The greeting to use";
      };
    };
    perInstance = {
      settings, instanceName, machine, roles, meta, ...
    }: {
      nixosModule = {...}: {
        environment.etc.hello.text = "${settings.greeting} World!";
      };
    };
  };

  # All machines of this service, regardless of role:
  perMachine = {machine, meta, ...}: {
    nixosModule = {pkgs, ...}: {
      environment.systemPackages = [ /* ... */ ];
    };
  };
}
```

## Manifest options

All under `manifest.` in the service module (`types.str` unless noted):

| Option | Type/default | Notes |
|---|---|---|
| `name` | str, required | Error-context name; official convention is `<forge>/<service>` (`clan-core/sshd`, `@andrewthomaslee/tags`) |
| `description` | str, default `"No description"` | Short, one line |
| `readme` | str, default `""` | **Eval warning if empty**; official services use `builtins.readFile ./README.md` |
| `categories` | listOf enum, default `["Uncategorized"]` | Freedesktop menu registry: Audio, AudioVideo, Desktop, Development, Education, Game, Graphics, Network, Office, Science, Settings, Social, System, Uncategorized, Utility, Video |
| `maintainers` | listOf (str or submodule), default `[]` | Str is coerced to `{name}`; submodule fields: `name`, `github`, `email`, `matrix` |
| `constraints.maxInstances` | nullOr positive int, default `null` | Non-null → enforced as an error-level `cliCheck` when exceeded |
| `constraints.roles.<r>.minMachines` / `.maxMachines` | nullOr unsigned/positive int, default `null` | Per-role machine-count bounds, enforced as `cliChecks`; keys must match defined roles |
| `features.API` | bool | Auto-converts every `roles.<r>.interface` to a JSON schema; interfaces must be JSON-serializable (assertion) |
| `exports.out` / `exports.inputs` | listOf str, default `[]` | Export interfaces this service provides / consumes |

Also emitted as eval **warnings** (not errors): missing `role.description`,
missing/empty `manifest.readme`.

## Roles

`roles.<roleName>` — a role is one behavior of the service. Services with
no roles throw at eval ("The service must define its roles").

- `description` — short text explaining the role's effect on a machine.
  Warns when missing; always write it.
- `interface` — a **deferred module** declaring the role's settings
  options. Machine-agnostic: `config` of a machine is **not** available
  here; `meta` (e.g. `meta.domain`, `meta.name`) is a module argument.
  Settings set in inventory land under `roles.<r>.settings` /
  `roles.<r>.machines.<m>.settings`.
- `perInstance` — see next section.

Role-name conventions (from the community guide): mutual peers → `peer`;
client/server topology → `client` + `server`; single-behavior services →
one role named `default`. Machines with no relation to each other
probably should not be one multi-host service.

Splitting role implementations into files keeps `default.nix` readable
while the interface stays visible in one place:

```nix
# default.nix
{
  roles.evening = {
    description = "An evening greeting machine";
    interface = {lib, ...}: { /* options */ };
  };
  imports = [ ./evening.nix ];  # adds roles.evening.perInstance
}

# evening.nix
{
  roles.evening.perInstance = {...}: {
    nixosModule = {...}: { /* ... */ };
  };
}
```

## perInstance

`roles.<r>.perInstance` maps over every instance × machine of that role.
Arguments:

| Arg | Shape |
|---|---|
| `settings` | This machine's evaluated role settings (`instances.<i>.roles.<r>.machines.<m>` merged over role-wide) |
| `instanceName` | str |
| `machine` | `{ name; roles = [ "client" ... ]; }` — roles of **this machine** in this instance |
| `roles` | All roles of the instance with their machines: `roles.<r>.machines.<m>.settings` (cross-role reads) |
| `meta` | Inventory meta (`meta.domain`, `meta.name`) |
| `exports` | Fleet-wide export scope (read) |
| `mkExports` | `data → { "<scopeKey>" = data; }` — the only sanctioned way to write exports |
| `extendSettings` | `module → settings` — experimental; machine-config-dependent defaults |

Returns an attrset of:

- `nixosModule` — deferred module imported into each target machine.
  Produced **once per instance**: when a service supports multiple
  instances, namespace everything global (`systemd.services."webly-${instanceName}"`)
  so all produced modules can coexist without conflicts.
- `darwinModule` — same for nix-darwin machines (`launchd.daemons`).
- `exports` — experimental; see Exports.

Machine-config-dependent settings (experimental, `perInstance` only):

```nix
perInstance = {extendSettings, ...}: {
  nixosModule = {config, ...}:
    let
      # New settings with ipRanges defaulting to this machine's value.
      # Local only: other machines never see extendSettings results.
      localSettings = extendSettings {
        ipRanges = lib.mkDefault config.network.ip.range;
      };
    in {...};
};
```

## perMachine

`perMachine` maps over every machine that participates in **any**
instance of the service. Arguments: `machine` (`{name; roles}` — roles
across all instances), `instances` (full scope:
`instances.<i>.roles.<r>.machines.<m>.settings`), `meta`, `exports`,
`mkExports`.

**There is no `settings` argument** — accessing it throws. Settings are
always role-scoped; use `roles.<r>.perInstance` or read through
`instances.<i>.roles.<r>.machines.<m>.settings`.

Returns `nixosModule` / `darwinModule` / `exports` (one per machine).

## Exports (experimental)

Structured data shared between machines/instances/services (IPs, ports,
discovery info). Scope-keyed internally as
`service:instance:role:machine` — never touch scope keys directly, use
the helpers.

Write (only at the scope matching your context — ownership is validated,
mismatches are eval errors):

```nix
roles.peer.perInstance = {mkExports, ...}: {
  exports = mkExports {
    peer.host.plain = "192.192.192.12";
  };
};
```

Read:

```nix
perMachine = {exports, clanLib, ...}: {
  nixosModule = {...}: {
    vpnConfigs = clanLib.selectExports {service = "vpn";} exports;
  };
};
```

Helper functions: `clanLib.selectExports {service|instance|role|machine}` (wildcard default), `clanLib.getExport {...}`, `clanLib.buildScopeKey`, `clanLib.parseScope`. Scope rules: `perInstance` writes only its own matching scope; `perMachine` only machine scope; a service only ever writes its own service scope. Declare consumed/provided interfaces in `manifest.exports.{inputs,out}`.

## Vars (secrets)

Services that need secrets define clan vars generators inside the
`nixosModule` (pattern from `borgbackup`/`sshd`):

```nix
clan.core.vars.generators.borgbackup = {
  files."borgbackup.ssh.pub".secret = false;
  files."borgbackup.ssh" = { };
  files."borgbackup.repokey" = { };
  runtimeInputs = [pkgs.coreutils pkgs.openssh pkgs.xkcdpass];
  script = ''
    ssh-keygen -t ed25519 -N "" -C "" -f "$out"/borgbackup.ssh
    xkcdpass -n 6 -d - > "$out"/borgbackup.repokey
  '';
};
# Consume elsewhere in the same module:
# config.clan.core.vars.generators.borgbackup.files."borgbackup.ssh".path
```

`files.<f>.secret` (default true), `files.<f>.deploy` (default true;
`false` for files only other machines read, e.g. CA public keys),
generator-level `share = true` for fleet-shared vars. Generate with
`clan vars generate <machine>`; secrets live in the repo's `vars/` tree,
never in Nix source. Full vars reference: the `clan-core` opencode
reference.

## Passing self / pkgs into a service

Dependencies must be passed in manually. Two upstream-blessed ways:

```nix
# 1. importApply — simpler (preserves error locations)
clan.modules."@andrewthomaslee/messaging" =
  lib.modules.importApply ./clanServices/messaging {inherit self;};

# 2. wrapper module — downstream can override the injected value
clan.modules."@andrewthomaslee/messaging" = {
  options.myClan = lib.mkOption {default = self;};
  imports = [./clanServices/messaging];
};
```

Note: a clan flake can inject arguments fleet-wide via `clan.specialArgs`
(e.g. `self`, `inputs`, a custom lib) — check the target flake's clan
config before reaching for either trick. If the needed value is already
injected, service modules take it as a plain module argument. Use
`importApply`/wrapper only when the value is not injected, or must be
overridable per consumer (wrapper), or must stay out of global scope
(`importApply`).

## Registration (this repo, upstream style)

Adopted from clan-core's `clanServices/` layout: a directory
auto-importer plus one `flake-module.nix` per service.

- `clanServices/flake-module.nix` — imports every
  `clanServices/*/flake-module.nix` (readDir-based; the clan-core
  pattern).
- `clanServices/<name>/flake-module.nix` — registers the service:

```nix
{...}: let
  module = ./default.nix;
in {
  clan.modules."@andrewthomaslee/my-service" = module;

  # Upstream also wires clan.nixosTests here; this repo intentionally
  # does not (no VM testing — static gates only).
}
```

- `flake-parts/default.nix` imports `clanServices/flake-module.nix`
  once; there is no hand-maintained module list.

The `@andrewthomaslee/` prefix is the namespacing the community guide
recommends (collision-free with `clan-core/*` modules). `inventory.nix`
is the instance source of truth:

```nix
instances.my-service = {
  module.input = "self";
  module.name = "@andrewthomaslee/my-service";
  roles.default.tags = ["all"];
  # or explicit machines / role settings:
  # roles.server.machines."kamrui-h1".settings.port = 8080;
};
```

## Verification (static only)

Static gates and checks; no VM tests, no machine builds:

1. `git add` the new service tree first — Nix evaluates from the git
   tree, and `readDir`-based auto-import misses untracked directories.
2. Lint loop (mandatory): `nix fmt .` → `statix check .` →
   `deadnix --fail .`.
3. `nix flake check --show-trace` — evaluates every machine (this is
   where interface JSON-serializability, export scope ownership,
   constraint `cliChecks`, and missing-description/readme warnings
   surface). VM tests live under `legacyPackages` and are **not** run by
   `flake check`.
4. Eval probes without building:
   `nix eval .#nixosConfigurations.<machine>.config.system.build.toplevel.drvPath`
   (derivation only), and for a service option:
   `nix eval .#nixosConfigurations.<machine>.config.clan.<...> --json`.
5. Warnings check: eval output mentions missing role descriptions or
   empty `manifest.readme` — fix before declaring done.
