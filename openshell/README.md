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
  may reach which host:port, with L7 method/path rules). Static fields need
  a recreate; `network_policies` hot-reload via `openshell policy set`.
- **Provider** — a named bundle of credentials (API keys, tokens) created
  from a **profile** and attached to a sandbox. The gateway only injects
  the credential into requests to endpoints the profile declares, and the
  profile's endpoint/binary bindings become part of the effective policy.
- **Profile** — gateway catalog entry describing a service: credential env
  vars, endpoints, allowed binaries. Profiles here:
  `openshell/profiles/`.
- **Explicit proxy** — on the VM driver there is no transparent TCP; every
  egress goes through the in-sandbox HTTP(S) proxy (env `HTTP(S)_PROXY` is
  set by the supervisor) and is admitted or denied per policy. Node fetch
  honors it via pi's global undici `EnvHttpProxyAgent`; curl/git/nix honor
  it as usual.

## 1. Smoke-test the VM driver

```bash
openshell sandbox create --name smoketest --detach -- sleep infinity
openshell sandbox exec -n smoketest -- uname -r          # a libkrun kernel
openshell sandbox exec -n smoketest -- curl -sI https://cache.nixos.org   # expect DENIED (default policy)
openshell logs smoketest --tail --source sandbox          # NET:OPEN [MED] DENIED ...
openshell sandbox delete smoketest
```

CI-equivalent (nested KVM, from the repo root):
`nix run .#vm-test -- openshell-gateway-lg --driver` —
boots a real sandbox and execs `uname -r` inside a microVM.

## 2. Build the sandbox images (flake OCI images)

```bash
nix build .#pi-agent-image .#nix-builder-image
docker load < result   # also: result-2  (nix-builder)
docker image ls        # pi-agent:latest, nix-builder:latest
```

The VM driver resolves images from the **host docker store first**
(`inspect_image`), then falls back to an OCI registry pull. The gateway's
`openshell` user is in the `docker` group to make the local path work
(change in `flake-parts/nixosModules/openshell-gateway.nix`; restart
`openshell-gateway.service` after deploy).

## 3. Providers

```bash
# kimi-for-coding: key already lives in pi's auth.json — feed it via env.
export KIMI_API_KEY=$(jq -r '."kimi-coding".key' ~/.pi/agent/auth.json)
openshell profile import --file openshell/profiles/kimi-for-coding.yaml
openshell provider create --name kimi-for-coding --type kimi-for-coding \
  --credential KIMI_API_KEY

# github: DEDICATED bot account, fine-grained PAT (contents:rw on the
# repos the agent may touch, nothing else). --from-existing would import
# YOUR gh identity — do not use it for agent sandboxes.
export GITHUB_TOKEN=github_pat_...
openshell profile import --file openshell/profiles/github-agent.yaml
openshell provider create --name github-agent --type github-agent \
  --credential GITHUB_TOKEN
```

Verify: `openshell provider list`, `openshell provider get kimi-for-coding`.

## 4. Sandboxes

pi coding agent (kimi-for-coding + the bot's GitHub identity; everything
else denied):

```bash
openshell sandbox create --name pi-dev --from pi-agent:latest \
  --provider kimi-for-coding --provider github-agent \
  --policy openshell/policies/pi-coding-agent.yaml \
  -- bash -l
openshell sandbox connect pi-dev
# inside: git clone https://github.com/<org>/<repo>   # gh auth setup-git once
# inside: pi            # PI_PROVIDER/PI_MODEL are baked into the image
```

nix build (pure builder; upload a project, build it):

```bash
openshell sandbox create --name nix-builder --from nix-builder:latest \
  --policy openshell/policies/nix-build.yaml \
  --cpu 4 --memory 8Gi -- bash -l
openshell sandbox upload nix-builder .
openshell sandbox exec -n nix-builder -- nix build .#checks.x86_64-linux.lint -L
```

Caveats for the builder:

- The VM overlay disk defaults to 4 GiB sparse — a real `nix build` can
  fill it. Raise
  `hostSpec.services.openshell.gateway.vm.overlayDiskMiB` (e.g. 16384)
  and rebuild the machine config, or `nix-collect-garbage` inside.
- If a build with sandboxed derivations misbehaves inside the microVM,
  `nix build --option sandbox false` or add `sandbox = false` to
  `NIX_CONFIG` for diagnosis.
- Private flake inputs: attach `--provider github-agent` at create.
- `--upload` needs the project from a git work tree (`.gitignore` is
  honored); or clone from inside as shown for pi-dev.

## 5. Iterate on policy (the loop that matters)

Policy misses show up as denials, not crashes:

```bash
openshell logs pi-dev --tail --source sandbox     # NET:OPEN/HTTP ... DENIED lines
openshell policy get pi-dev --base | sed '1,/^---$/d' > /tmp/p.yaml
# edit /tmp/p.yaml (network_policies / network_middlewares only)
openshell policy set pi-dev --policy /tmp/p.yaml --wait
openshell policy list pi-dev                       # latest rev = loaded
```

Filesystem/Landlock/process changes require recreating the sandbox.
`openshell policy update --add-endpoint ... --rule-name ... --wait` covers
narrow additive network grants without a full YAML round-trip.

## 6. Declarative defaults (home-manager)

`homeSpec.programs.openshell.sandboxPolicy` (flake-parts/homeModules/
openshell.nix) renders `~/.config/openshell/policy.yaml` and exports
`OPENSHELL_SANDBOX_POLICY` — it is the default for every
`openshell sandbox create` in your shell. Per-create `--policy` overrides
it. Keep the shared baseline there; keep the per-use-case files in
`openshell/policies/` for `--policy` at create time.

## Pitfalls already hit on this fleet

- `openshell ... | grep -q` panics the CLI on EPIPE (exit 101) — redirect
  to a file, then grep.
- `openshell sandbox exec -n NAME -- cmd` — the name is a flag; a bare
  positional becomes part of the remote command.
- Never bake credentials into images: providers inject at runtime; pi's
  `models.json` `"apiKey": "$VAR"` interpolation picks them up.
- The built-in `github` profile is read-only; pushing needs the
  `github-agent` profile above (or your own variant).
