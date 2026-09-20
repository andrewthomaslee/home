# KubeVirt AI Agent

A headless [OpenCode harness](index.md) machine that runs as a KubeVirt
`VirtualMachine` in Kubernetes. Its outputs:

- **Headless agent profile**: `flake.homeModules.profile-netsa-agent` in
  `flake-parts/homeModules/profiles/netsa-agent.nix`.
- **Bootable QCOW2 image**: `packages.kubevirt-image` (single, unsized,
  **compressed qcow2**, ~2 GB).
- **OCI ContainerDisk**: `packages.ai-agent` →
  `ghcr.io/andrewthomaslee/ai-agent` (~2.2 GB layer).
- **Kustomize manifests**: `packages.ai-agent-oci` (Kubenix-evaluated,
  kustomize-CLI-validated).
- **NixOS machine config**: `nixosConfigurations.kubevirt-agent`.

## How the KubeVirt machine is produced

The pipeline is fully deterministic, from flake evaluation to a running
`VirtualMachine` in Kubernetes:

```
nix eval  nixosConfigurations.kubevirt-agent
  ├─ modules: nixpkgs virtualisation/kubevirt.nix + self.nixosModules.default
  │           + home-manager + profile-netsa-agent
  ├─ BIOS GRUB on /dev/vda (kubevirt.nix is BIOS-only; GRUB EFI is forced off),
  │  console=ttyS0, growPartition + autoResize root filesystem
  ├─ qemu-guest-agent (KubeVirt uses it to report VM IP/status to the k8s API),
  │  cloud-init, sshd, headroom proxy + opencode-web user services (netsa)
  └─ system.build.kubevirtImage
        → make-disk-image.nix boots a throwaway install VM inside the build
          sandbox, installs the closure and produces a **compressed qcow2**
          (format = "qcow2-compressed", zlib clusters)
        → dockerTools.buildImage wraps it as /disk/root.qcow2
          (packages.ai-agent, a KubeVirt containerDisk)
        → CI pushes it to ghcr.io/andrewthomaslee/ai-agent:<tag>
        → Kubenix evaluates the VirtualMachine CR (containerDisk volume +
          cloudInitNoCloud userData + sized cpu/memory) and the Service
          (opencode-web 4096 + ssh 22)
        → kubectl apply -k … spawns the VM
```

The QCOW2 image and OCI containerDisk are **single, unsized artifacts**:
the root filesystem auto-grows on boot (`boot.growPartition` +
`autoResize`), so one image serves every VM size. Resource sizing happens
at **deploy time** through the Kustomization overlays.

## Manifests package layout (`packages.ai-agent-oci`)

```
result/
├── kustomization.yaml          # root build = sm baseline
├── base/
│   ├── kustomization.yaml      # labels + resources
│   ├── virtualmachine.yaml     # VM "ai-agent" (containerDisk + cloudInit)
│   └── service.yaml            # ClusterIP: 4096 (opencode-web), 22 (ssh)
└── overlays/
    ├── sm/                     # 2 cores / 4Gi  (baseline)
    ├── md/                     # 4 cores / 8Gi  (2x)
    └── lg/                     # 6 cores / 12Gi (3x)
```

Every `kustomization.yaml` is validated with the `kustomize` CLI during the
package build (root + all three overlays). The overlays apply a
strategic-merge patch on `spec.template.spec.domain` (cpu cores + memory
requests/limits) and a `app.kubernetes.io/size` label.

## Deploying

```bash
# from a built manifests package
nix build .#ai-agent-oci
kubectl apply -k result/overlays/lg     # or sm / md, or result/ for baseline

# from the published OCI artifact
oras pull ghcr.io/andrewthomaslee/ai-agent-manifests:latest
kubectl apply -k latest/overlays/lg
```

Runtime configuration is injected via the `cloudInitNoCloud` volume: the VM
writes `/etc/default/opencode-web` (e.g. `OPENCODE_SERVER_PASSWORD`,
`OPENCODE_PORT`) which the `opencode-web.service` unit picks up through
`EnvironmentFile`.

## Image optimization (trim + compress)

The agent image is aggressively slimmed without touching desktop profiles
(all trims are behind defaulted options):

| Optimization | Change | Savings |
|---|---|---|
| `homeSpec.programs.opencode.enableDesktop = false` | skips `opencode-desktop` + Electron/GTK chain | ~4 GB |
| `homeSpec.programs.opencode.fullDevTools = false` | skips k3s/rke2/k3d/devpod/devcontainer/podman/gleam/terraform-helm LSPs/go_latest; **keeps docker, kubectl, helm, k9s, bun, go, uv** | ~3.5 GB |
| `packages.headroom-slim` | core+proxy+code+mcp deps only (no torch/sentence-transformers/OCR); validated by the [MCP E2E test](vm-tests.md) | ~2.7 GB |
| documentation/manpages off | agent VM needs no docs | ~0.1 GB |
| `qcow2-compressed` image format | zlib-compressed qcow2 clusters (KubeVirt-compatible) | image 12 GB → **2.0 GB**, OCI layer 6.9 GB → **2.2 GB** |

Desktop profiles (`profile-netsa`, `profile-wife`) keep the defaults
(`enableDesktop = true`, `fullDevTools = true`, full `pkgs.headroom`) and
are unchanged. `packages.headroom` (full) is also untouched.

## CI publishing

`.github/workflows/oci.yml` (manual dispatch) and the `Release` workflow
both invoke `.github/workflows/_oci.yml`, which:

1. Builds `.#ai-agent` → pushes `ghcr.io/andrewthomaslee/ai-agent:<tag>` +
   `:latest`.
2. Builds `.#ai-agent-oci` → pushes the whole manifests directory as an
   OCI artifact at `ghcr.io/andrewthomaslee/ai-agent-manifests:<tag>` +
   `:latest` via `oras` (artifact type
   `application/vnd.kustomize.v1+tar`).

## VM test

`vm-tests/headroom-opencode-web.nix` exercises the same machine definition
(unsized) as `headroom-opencode-web-<size>`: it asserts the headless
developer tooling is on `netsa`'s PATH, the Headroom proxy healthcheck, the
OpenCode web UI on port 4096, and the MCP CCR roundtrip — see
[VM Tests](vm-tests.md).
