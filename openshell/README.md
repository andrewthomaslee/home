# OpenShell on this fleet

Working notes + artifacts for using the local OpenShell gateway (VM driver)
from this repo. Concepts and the gateway itself:
[documentation/docs/openshell/index.md](../documentation/docs/openshell/index.md).

## Concepts in 60 seconds

- **Gateway** — the control plane (`openshell-gateway` systemd service,
  loopback + mTLS). Owns sandboxes, providers, policies.
- **CLI** — `openshell`, talks to the gateway as a client over mTLS.
- **Compute driver** — what actually runs sandboxes. Here: **vm**
  (openshell-driver-vm): every sandbox is its own libkrun microVM.
- **Sandbox** — a workload instance: an OCI image's rootfs as a microVM
  root disk, a canonical main process, optional attached providers and a
  policy.
- **Policy** — the security contract: filesystem (read-only/read-write
  paths), Landlock, process identity, and `network_policies` (which binary
  may reach which host:port, with L7 method/path rules). FS/Landlock are
  static (recreate to change); network rules hot-reload via
  `openshell policy set`.
- **Provider** — a named bundle of credentials (API keys, tokens) created
  from a **profile** and attached to a sandbox. The gateway only injects
  the credential into requests to endpoints the profile declares, and the
  profile's endpoint/binary bindings become part of the effective policy.
- **Profile** — gateway catalog entry describing a service: credential env
  vars, endpoints, allowed binaries. Profiles live in
  `openshell/profiles/`.
- **Explicit proxy** — on the VM driver there is no transparent TCP; every
  egress goes through the in-sandbox HTTP(S) proxy (env `HTTP(S)_PROXY` +
  a supervisor CA bundle are set by the supervisor) and is admitted or
  denied per policy. pi honors the proxy via its global undici
  `EnvHttpProxyAgent`; git/nix use `SSL_CERT_FILE`/`NIX_SSL_CERT_FILE` and
  the proxy env.

## 1. Smoke-test the VM driver

Verified on ghost (kernel `6.12.76`, 2 vCPU / 2 GiB defaults):

```bash
openshell sandbox create --name smoketest --detach -- sleep infinity
openshell sandbox exec -n smoketest -- uname -r          # 6.12.76 (libkrun)
openshell sandbox exec -n smoketest -- sh -c 'ls /dev/kvm'   # No such file
openshell sandbox exec -n smoketest -- python3 -c "import socket; s=socket.socket(); s.settimeout(5); s.connect((\"1.1.1.1\",443))"
# PermissionError: [Errno 13]   ← deny-by-default egress
openshell logs smoketest --tail --source sandbox
openshell sandbox delete smoketest
```

**No `/dev/kvm` inside sandboxes** — nixos vm tests run under QEMU TCG
(software emulation). `-sm` tests are feasible; bigger tiers need much
more `--memory` and patience. Build vm-test *derivations* freely; run the
tests on the host (`.#vm-test` uses host KVM).

CI-equivalent (nested KVM, from the repo root):
`nix run .#vm-test -- openshell-gateway-lg --driver`.

## 2. The agent image (devenv container → sandbox VM)

The sandbox image IS the devenv `agent` shell
(`devenv/default.nix` + `devenv/agent.nix`) built by devenv's container
module: the stock entrypoint sources the whole shell envScript, so every
devenv package (pi, nix, git, gh, bun, linters, …) is available
in-sandbox. User 1000, `HOME=/env`, nix DB initialized.

Build + load (pure flake eval from the git tree — preferred over
`devenv container copy`, which evals with the CLI/PWD state; the
worktree is never baked in either way, `copyToRoot` is forced to just
the skeleton in `devenv/agent.nix`):

```bash
nix run .#load-agent-image          # → devenv-agent:latest in docker
docker inspect -f '{{json .Config.Entrypoint}}' devenv-agent:latest
```

The VM driver resolves images from the host docker store first (the
gateway's `openshell` user is in the `docker` group — after changing
`extraGroups` in flake-parts/nixosModules/openshell-gateway.nix, restart
`openshell-gateway.service`). Fallback is an OCI registry pull.

Baked into the image (all in `devenv/agent.nix`):

- `/env/.pi/agent/models.json` — pi's built-in `kimi-coding` provider
  reads its key from `$KIMI_API_KEY` (injected by the attached OpenShell
  provider; never baked). `PI_PROVIDER=kimi-coding`,
  `PI_MODEL=kimi-for-coding`.
- `/env/.config/nix/nix.conf` — flakes; `sandbox = false` and
  `filter-syscalls = false` (the microVM is the isolation boundary; the
  supervisor's seccomp stack blocks nix's builder-child filter, and an
  unprivileged guest can't run the namespace sandbox); FlakeHub
  substituters + public keys mirroring the host.
- git credential helper via env (`GIT_CONFIG_*`) using `$GITHUB_TOKEN`
  from the github provider — no `gh auth setup-git` needed.
- A custom container entrypoint that pins `HOME=/env` and re-points
  `NIX_SSL_CERT_FILE` at the supervisor CA bundle after the envScript
  (nix's setup hook would otherwise override it and nix would distrust
  the policy proxy's TLS interception).

## 3. Providers

```bash
# kimi-for-coding: key already in pi's auth.json — feed via env.
export KIMI_API_KEY=$(jq -r '."kimi-coding".key' ~/.pi/agent/auth.json)
openshell profile import --file openshell/profiles/kimi-for-coding.yaml   # once
openshell provider create --name kimi-for-coding --type kimi-for-coding \
  --credential KIMI_API_KEY

# github: DEDICATED bot account, fine-grained PAT (see README section
# "GitHub bot token"). --from-existing would import YOUR gh identity —
# do not use it for agent sandboxes.
export GITHUB_TOKEN=github_pat_...
openshell profile import --file openshell/profiles/github-agent.yaml      # once
openshell provider create --name github-agent --type github-agent \
  --credential GITHUB_TOKEN
```

Verify: `openshell provider list`, `openshell provider get kimi-for-coding`.

### GitHub bot token

1. Create a dedicated GitHub account for the agent (machine account).
2. On that account: **Settings → Developer settings → Personal access
   tokens → Fine-grained tokens → Generate new token**.
3. Resource owner: your user/org. Repository access: **Only select
   repositories** — just the repos the agent may touch.
4. Permissions: **Contents: Read and write** (clone/push), **Pull
   requests: Read and write** (agent opens PRs), **Issues: Read and
   write** (optional), **Metadata: Read** (mandatory/auto). Skip
   everything else — no Actions, no Administration.
5. Expiration per your paranoia; note that rotating means re-running
   `provider update github-agent --credential GITHUB_TOKEN`.
6. If an org enforces SAML SSO, authorize the token (Configure SSO).

If the org moves to a GitHub App later, the same `github-agent` profile
shape holds; only the credential minting changes.

## 4. The agent sandbox

```bash
openshell sandbox create --name agent --from devenv-agent:latest \
  --provider kimi-for-coding --provider github-agent \
  --policy openshell/policies/devenv-agent.yaml \
  --cpu 4 --memory 8Gi --detach -- bash -l
```

Run things **through the image entrypoint** (it sets PATH + HOME + CA
bundle). Get its path from the docker inspect one-liner above, then:

```bash
EP=$(docker inspect -f '{{json .Config.Entrypoint}}' devenv-agent:latest | tr -d '[]"')

# pi (interactive): connect and run through the entrypoint
openshell sandbox connect agent
# or one-shot:
openshell sandbox exec -n agent -- $EP 'pi -p "Reply with exactly: OK"'

# clone + build the repo (GITHUB_TOKEN is injected by the provider)
openshell sandbox exec -n agent -- $EP 'git clone $REPO_URL /tmp/home && cd /tmp/home && nix build .#checks.x86_64-linux.lint -L'
```

**⚠️ envsubst pitfall**: the entrypoint runs the command string through
`envsubst`, so `$VAR`/`${VAR}` are expanded *before* your shell sees
them. Use `$(...)` (survives) or ship scripts as base64 (`echo <b64> |
base64 -d > /tmp/x.sh && sh /tmp/x.sh`).

What works in the sandbox (verified on ghost):

- pi → kimi-for-coding API through the policy proxy (provider-injected
  key + baked models.json).
- `nix eval` / `nix build` with locked flakes: eval, fetch
  (channels/releases/codeload/api.github.com), substitution
  (cache.nixos.org + FlakeHub caches), and real builder runs.
- git clone/push to admitted GitHub endpoints with the token helper.
- deny-by-default: direct sockets (`1.1.1.1:443`) get EPERM; watch
  `openshell logs agent --tail --source sandbox` for `DENIED` lines.

### nixos vm tests inside the sandbox

Build the test derivations freely (`nix build .#checks...` includes
nothing KVM). Running tests inside = QEMU TCG (no `/dev/kvm`), so
`-sm` only, with `--memory 8Gi` or more, minutes not seconds. Prefer
running `.#vm-test` on the host.

## 5. Iterate on policy

```bash
openshell logs agent --tail --source sandbox     # NET:OPEN/HTTP ... DENIED lines
openshell policy get agent --base | sed '1,/^---$/d' > /tmp/p.yaml
# edit /tmp/p.yaml (network_policies only for hot reload)
openshell policy set agent --policy /tmp/p.yaml --wait
openshell policy list agent
```

Filesystem/Landlock/process changes require recreating the sandbox.
Narrow additive grants: `openshell policy update agent
--add-endpoint host:443:read-only:rest:enforce --rule-name ... --wait`.

## 6. Where policies and profiles should live

- **Profiles**: gateway catalog, not per-user. They carry no secrets —
  keep them as files in `openshell/profiles/` (versioned), import with
  `profile import`. Provider *creation* stays manual (it holds secrets);
  the commands above are the runbook.
- **Sandbox policy default**: `homeSpec.programs.openshell.sandboxPolicy`
  (flake-parts/homeModules/openshell.nix) renders
  `~/.config/openshell/policy.yaml` + `OPENSHELL_SANDBOX_POLICY` — a
  per-user default for every `openshell sandbox create`. Good for a
  personal baseline.
- **Per-use-case policies**: `openshell/policies/`, passed with
  `--policy` at create time (overrides the env default). This is the
  sweet spot: the baseline travels with the user, the contract
  travels with the use case.
- **Gateway-global policy** (`openshell policy set --global`) exists but
  locks policy control for ALL sandboxes on the gateway — avoid.
- **NixOS module level**: machine/gateway concerns only (driver, sizing,
  secrets, the `docker` group), not per-user policy.

## Pitfalls already hit on this fleet

- `openshell ... | grep -q` panics the CLI on EPIPE (exit 101) — redirect
  to a file, then grep.
- `openshell sandbox exec -n NAME -- cmd` — the name is a flag; a bare
  positional becomes part of the remote command.
- Never bake credentials into images: providers inject at runtime; pi's
  `models.json` `"apiKey": "$VAR"` interpolation picks them up.
- The supervisor sets `HOME` to the workdir and stacks ~5 seccomp
  filters on workloads; the image entrypoint and `filter-syscalls =
  false` exist because of that (see section 2).
- Grant `/dev` (ro) + `/dev/ptmx` + `/dev/pts` (rw) in the policy or nix
  dies opening a pseudoterminal master.
- The built-in `github` profile is read-only; pushing needs
  `openshell/profiles/github-agent.yaml`.
- Provider-injected credential env values are opaque supervisor handles
  (`openshell:…`), not the raw secret — the policy proxy swaps the real
  credential in at egress. Consequences: tools that validate token format
  locally (`gh auth status`) report the env token as "invalid" even
  though real API calls through the proxy work; and a rotated secret only
  reaches new processes (restart long-running agents).
- nixpkgs-wrapped CLIs (e.g. `gh` → `bin/.gh-wrapped`) must be pinned by
  their kernel-resolved exe path in profile/policy `binaries` — the
  supervisor matches `/proc/<pid>/exe`, not the symlink (the DENIED log
  line says this too).

## Shell completions

`homeSpec.programs.openshell.completions.enable` (default true) installs
bash/fish/zsh completions generated from the installed CLI at package
build time (`home.packages` → `openshell-completions`). Requires the
shell's completion loader — `programs.bash.enableCompletion` is already
enabled for netsa. Apply with the normal home/nixos deploy (`apply-now
home` or `sudo nixos-rebuild switch`).
