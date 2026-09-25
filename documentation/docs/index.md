# Welcome to Andrew's Home Flake

<div align="center">
  <img src="assets/brand/andrewthomaslee-transparent-logo.png" alt="Andrew's Logo" width="400">
</div>

<p align="center">
  <a href="https://github.com/andrewthomaslee/home/releases"><img src="https://img.shields.io/github/v/release/andrewthomaslee/home?include_prereleases&style=for-the-badge" alt="Latest Release"></a>
  <a href="https://github.com/andrewthomaslee/home/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/andrewthomaslee/home/ci.yml?style=for-the-badge" alt="CI Status"></a>
  <a href="https://github.com/andrewthomaslee/home/blob/main/LICENSE"><img src="https://img.shields.io/github/license/andrewthomaslee/home?style=for-the-badge&color=blue" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/andrewthomaslee/home"><img src="https://img.shields.io/badge/github-repo-24292e?logo=github&style=for-the-badge" alt="GitHub Repo"></a>
  <a href="https://flakehub.com/flake/andrewthomaslee/home"><img src="https://img.shields.io/endpoint?url=https://flakehub.com/f/andrewthomaslee/home/badge&style=for-the-badge" alt="FlakeHub"></a>
</p>


<h3 align="center">
  <strong>🏠 Home Repository for my <u>NixOS Machines</u>❄️ and <u>Kubernetes</u>☸️</strong>
</h3>


## Features

### ☸️ **Kubernetes**
`GitOps` • `K3s` • `Helm` • `FluxCD` • `Argo` • `Sealed Secrets`• `Cilium Cluster Mesh` • `Cloudflare Tunnels`

### ❄️ **NixOS**
`Determinate Systems` • `Clan.lol` • `flake-parts` • `dendritic` • `home-manager` • `Tailscale` • `Modded Minecraft Server` • `KDE` • `Wayland`

Networking (`flake-parts/nixosModules/networking.nix`): WAN TCP BBR congestion
control + `fq` qdisc with 16M send buffers for lossy long-RTT uplinks, WiFi
power-save off (NetworkManager `wifi.powersave=2`), and rtw89 low-power /
PCIe-PM disables.

## Machines

| Machine           | Role                                            |
| ----------------- | ----------------------------------------------- |
| `nixos`           | Intel desktop — dev + NVIDIA gaming (jovian)    |
| `kamrui-h1`       | AMD dev + gaming desktop — KDE/Wayland (jovian) |
| `ghost`           | Intel desktop — dev                             |
| `hp-notebook`     | Wife's Intel laptop                             |
| `nixos-installer` | ISO installer image                             |

Steam/gaming is part of the `jovian` NixOS module (`hostSpec.system.jovian.*`); every
jovian-enabled machine runs the Valve jovian kernel.

## Project layout

    flake.nix       # Flake that controls the project
    flake.lock      # Flake's lock file
    inventory.nix   # Clan.lol Inventory of all NixOS machines and Services
    .envrc          # direnv configuration
    .env.schema     # Varlock schema

    machines/       # NixOS Machines
    clanServices/   # Clan.lol Services    
    lib/            # Custom functions accessible via `lib.custom`
    overlays/       # Overlays for Nixpkgs. Adds `pkgs.unstable`

    flake-parts/        # Top-level Flake Part files
                        # Auto-imported via import-tree: every .nix file
                        # here loads, there is no import list to update
        default.nix     # Default flake-parts configuration
        devShells.nix   # Development Shells
        apps/           # Applications `nix run .#<app>`
        packages/       # Packages `nix build .#<package>`
        homeModules/    # Home-manager Modules
        nixosModules/   # NixOS Modules

    documentation/      # MkDocs
        mkdocs.yml      # MkDocs configuration
        docs/           # Documentation source

    .github/workflows/    # GitHub Actions workflows
        ci.yml            # Flake Health Checker ( Run on push )
        machines.yml      # Build Machines + Publish to FlakeHub ( Run on trigger )
        release.yml       # Tagged release + Build Machines + Build Docs & devShells + Publish to FlakeHub ( Run on trigger )

    .devcontainer/          # Devcontainer

    sops/                   # Encrypted Secrets
    vars/                   # Clan.lol implementaion of SOPS

## Flake Outputs

```console
$ nix flake show
warning: unknown setting 'lazy-trees'
warning: Git tree '/home/netsa/home' is dirty
git+file:///home/netsa/home
├───allSystems: unknown
├───apps
│   └───x86_64-linux
│       ├───apply-and-reboot: app: Apply latest NixOS configuration + delayed reboot to allow Terraform/SSH to exit cleanly
│       ├───fetch-kubeconfig: app: no description
│       ├───get-keys: app: no description
│       ├───update-flake-show: app: no description
│       ├───vm-test: app: no description
│       └───watch-documentation: app: Run mkdocs in watch mode over your documentation folder. Automatically rebuilds your docs on changes.
├───clan: unknown
├───clanInternals: unknown
├───darwinConfigurations: unknown
├───darwinModules: unknown
├───debug: unknown
├───devShells
│   └───x86_64-linux
│       └───default: development environment 'nix-shell'
├───formatter
│   └───x86_64-linux: package 'alejandra-4.0.0'
├───homeConfigurations: unknown
├───homeModules: unknown
├───legacyPackages
│   └───x86_64-linux omitted (use '--legacy' to show)
├───nixosConfigurations
│   ├───ghost: NixOS configuration
│   ├───hp-notebook: NixOS configuration
│   ├───kamrui-h1: NixOS configuration
│   ├───kubevirt-agent: NixOS configuration
│   ├───nixos: NixOS configuration
│   └───nixos-installer: NixOS configuration
├───nixosModules
│   ├───amd: NixOS module
│   ├───bluetooth: NixOS module
│   ├───clan: NixOS module
│   ├───clan-machine-ghost: NixOS module
│   ├───clan-machine-hp-notebook: NixOS module
│   ├───clan-machine-kamrui-h1: NixOS module
│   ├───clan-machine-nixos: NixOS module
│   ├───clan-machine-nixos-installer: NixOS module
│   ├───default: NixOS module
│   ├───docker: NixOS module
│   ├───flatpak: NixOS module
│   ├───github-mcp: NixOS module
│   ├───intel: NixOS module
│   ├───jovian: NixOS module
│   ├───kde: NixOS module
│   ├───lan: NixOS module
│   ├───longhorn: NixOS module
│   ├───morph-api-key: NixOS module
│   ├───motd: NixOS module
│   ├───nix: NixOS module
│   ├───nix-ld: NixOS module
│   ├───ollama: NixOS module
│   ├───openssh: NixOS module
│   ├───rancher: NixOS module
│   ├───sound: NixOS module
│   ├───splashtop-streamer: NixOS module
│   ├───storagebox: NixOS module
│   ├───tailscale: NixOS module
│   ├───wan: NixOS module
│   ├───warp: NixOS module
│   ├───wayland: NixOS module
│   └───whisper-dictation: NixOS module
├───overlays
│   └───default: Nixpkgs overlay
├───packages
│   └───x86_64-linux
│       ├───ai-agent: package 'docker-image-ai-agent.tar.gz'
│       ├───ai-agent-oci: package 'ai-agent-oci'
│       ├───apply-and-reboot: package 'apply-and-reboot'
│       ├───apply-dry-activate: package 'apply-dry-activate'
│       ├───apply-now: package 'apply-now'
│       ├───apply-test: package 'apply-test'
│       ├───apply-to-boot: package 'apply-to-reboot'
│       ├───artifacthub-mcp: package 'artifacthub-mcp-1.1.1'
│       ├───cc-safety-net: package 'cc-safety-net-2.4.1'
│       ├───devShell: package 'nix-shell'
│       ├───documentation: package 'mkdocs-flake-documentation'
│       ├───get-keys: package 'get-keys'
│       ├───hcloud-ip: package 'hcloud-ip-v0.0.1'
│       ├───headroom: package 'headroom-ai-0.37.0'
│       ├───headroom-slim: package 'headroom-ai-0.37.0'
│       ├───kubernetes-mcp-server: package 'kubernetes-mcp-server-0.0.66'
│       ├───kubevirt-image: package 'nixos-disk-image'
│       ├───longhornctl: package 'longhornctl-v1.12.0'
│       ├───opencode-mem: package 'opencode-mem-2.26.0'
│       ├───opencode-morph-fast-apply: package 'opencode-morph-fast-apply-1.11.0'
│       ├───opencode-nixd-scaffold: package 'opencode-nixd-scaffold'
│       ├───splashtop-streamer: package 'splashtop-streamer-3.8.2.0'
│       ├───tfctl: package 'tfctl-0.16.4'
│       └───vcluster: package 'vcluster-v0.36.1'
└───templates
    └───self: template: This Flake
```