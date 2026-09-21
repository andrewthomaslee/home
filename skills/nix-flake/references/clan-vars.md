# clan vars

Vars are clan's secrets and generated-values system. A **generator** is a
named unit that produces one or more **files** — either by prompting the
operator, by running a script, or both. Files marked secret are encrypted
at rest in the repo and decrypted on the target machine at activation;
public files (keys' public halves, generated certs metadata) are stored
as plain `value` files.

The system exists so secrets are never in Nix source, never in plaintext
in the store, and still live **in the flake repo** — encrypted — so a
flake checkout is self-contained. Load this reference with
[clan-core.md](clan-core.md); the vars workflow assumes the clan CLI and
`CLAN_DIR` are set up.

Worked examples are from the home repo (`andrewthomaslee/home`, the
public flake this skill ships in) — the patterns are generic; substitute
your repo's names.

## Declaring generators

Declared in NixOS module land, anywhere a module evaluates — the home
repo declares them in `flake-parts/nixosModules/*.nix`, next to the
config that consumes them:

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
- `files.<name>` — declared outputs. `secret = true` (default) encrypts;
  `secret = false` stores plaintext. Extra consumer wiring:
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

## Storage layout

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

- `secret` files are encrypted with the age/sops backend.
- `value` files are plaintext.
- Per-machine vars are for one machine; `share = true` vars land in
  `vars/shared/`.

The `vars/` directory belongs to clan tooling. Never hand-edit an
encrypted `secret` file — create or rotate values through the CLI.

## Consuming a var

Read generated files through the generator's file options — a store path
materialized at build time:

```nix
services.tailscale.authKeyFile =
  config.clan.core.vars.generators.tailscale.files.auth_key.path;

fileSystems."/mnt/box".options = [
  "sftp_key_file=${config.clan.core.vars.generators."storagebox-ssh-box".files."ssh-private-key".path}"
];
```

Never copy a var's value into config; always reference `.path` so the
encrypted-in-repo / decrypted-on-target model holds.

## Workflow

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
- Rotate: `clan vars generate <machine> --generator <name> --regenerate`
  (per-generator) or `--regenerate` (everything), then redeploy.
- `clan vars get` output is for consoles and provisioning scripts, not
  for pasting into Nix.

## Keys and backends

- Vars are encrypted with an **age key** at `~/.config/sops/age/keys.txt`,
  auto-created on the first `clan vars generate`. **Back it up** — lose
  it and the vars are unrecoverable.
- Every machine also gets its own age keypair, stored as a var/secret of
  its own. The target machine decrypts its vars at activation using that
  private key (sops backend upload directory defaults to
  `/var/lib/sops-nix/key.txt`).
- **Backends**: `age` (default) and `sops`. The sops backend enables
  one-shot provisioning: the machine's age key is extracted with
  `clan secrets get <machine>-age.key`, injected into a fresh VM
  (e.g. terraform cloud-init writes `/var/lib/sops-nix/key.txt`), and the
  machine decrypts everything on first boot — no manual secrets-upload
  step after provisioning. See the borg repo docs
  (`documentation/docs/clan/sops.md`) for the full terraform/CI pattern.

## CI and scripted use

- CI needs the admin age key as `SOPS_AGE_KEY` to decrypt vars. This
  repo exports it via varlock from `.env` in the devShell shellHook; on
  GitHub Actions, store it as a secret and set the env var directly.
- The CLI prints lines like `warning: unknown setting 'eval-cores'` on
  stdout — filter any line starting with `warning:` before parsing. The
  home repo's `get-keys` app (`flake-parts/apps/get-keys.nix`) wraps the
  CLI in Python with that filter to build a machine → age-key JSON map
  for provisioning.
- When a machine key is extracted into CI, mask it
  (`echo "::add-mask::$KEY"` in Actions) so it never lands in logs.

## Example: the home repo's vars

All examples above are from the home repo (`andrewthomaslee/home`); this
table maps its generators so you can translate to your own tree:

| Vars | Generator | Consumer |
|---|---|---|
| `tailscale` auth key | `flake-parts/nixosModules/tailscale.nix` | `services.tailscale.authKeyFile` |
| `storagebox-ssh-<user>` keypair | `flake-parts/nixosModules/storagebox.nix` | rclone sftp mount option |
| `github-mcp` PAT | `flake-parts/nixosModules/github-mcp.nix` (mkMerge, per-user) | opencode MCP config |
| `morph-api-key` | `flake-parts/nixosModules/morph-api-key.nix` | morph API service |
| `openssh-ca`, `pki-root-ca`, `cloudflare-warp`, `rancher-*` | committed under `vars/shared/` | CA/host trust, rancher agents |

`vars/per-machine/<machine>/` exists for every inventory machine — new
machines get their dir on first `clan vars generate`.

## Gotchas

- **Generate then deploy** — a new generator produces nothing on the
  machine until `clan vars generate` has run and the machine redeployed.
- **Shared vs per-machine** — `share = true` stores one copy; without it
  clan generates a copy per machine (correct for machine-specific
  secrets like host keys, wasteful for fleet-wide ones).
- **`persist = true` on prompts** — without it, a `--regenerate` run
  re-prompts and overwrites; with it, the operator's answer survives.
- **Public halves** — mark `secret = false` deliberately; anything meant
  for `authorized_keys`, CA bundles, or public-key pinning should stay a
  `value` file.
- **git add after generate** — new `vars/` entries are files in the git
  tree; untracked vars are invisible to Nix and won't deploy.

## Docs

- [Vars intro](https://clan.lol/docs/26.05/guides/vars/intro-to-vars) ·
  [Vars concepts](https://clan.lol/docs/26.05/guides/vars/vars-concepts)
- [Custom generators](https://clan.lol/docs/26.05/guides/vars/vars-custom-generators) ·
  [Advanced examples](https://clan.lol/docs/26.05/guides/vars/vars-advanced-examples) ·
  [Troubleshooting](https://clan.lol/docs/26.05/guides/vars/vars-troubleshooting)
- [age backend](https://clan.lol/docs/26.05/guides/vars/age/age-backend) ·
  [sops secrets](https://clan.lol/docs/26.05/guides/vars/sops/secrets)
- [`clan.core.vars` options](https://clan.lol/docs/26.05/reference/clan.core/vars) ·
  [Vars CLI](https://clan.lol/docs/26.05/reference/cli/vars)
