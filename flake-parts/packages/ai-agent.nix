{
  inputs,
  self,
  ...
}: let
  # VM resource sizing for the KubeVirt Kustomization overlays.
  # The image itself is size-agnostic (root filesystem auto-grows via
  # boot.growPartition + autoResize); sizing happens at deploy time.
  sizes = {
    sm = {
      cores = 2;
      memory = "4Gi";
    };
    md = {
      cores = 4;
      memory = "8Gi";
    };
    lg = {
      cores = 6;
      memory = "12Gi";
    };
  };

  # Helper to build the NixOS KubeVirt VM system configuration (single, unsized)
  mkKubeVirtSystem = system:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        inputs.clan-core.nixosModules.clanCore
        (inputs.nixpkgs + "/nixos/modules/virtualisation/kubevirt.nix")
        inputs.home-manager.nixosModules.home-manager
        self.nixosModules.default
        # Repo overlay: provides pkgs.unstable and the patched opencode
        # package (upstream v2.0.16 nix postInstall is broken).
        {nixpkgs.overlays = [self.overlays.default];}
        ({
          config,
          lib,
          pkgs,
          ...
        }: {
          clan.core.settings = {
            directory = self;
            machine.name = "ai-agent";
          };

          networking.hostName = "ai-agent";
          networking.firewall.allowedTCPPorts = [22 4096];

          # nixpkgs' kubevirt.nix module is BIOS-only (grub on /dev/vda, no ESP).
          # self.nixosModules.default defaults GRUB to EFI, which fails to
          # install on the generated image ("/boot doesn't look like an EFI
          # partition"), so force BIOS mode.
          boot.loader.grub = {
            efiSupport = lib.mkForce false;
            efiInstallAsRemovable = lib.mkForce false;
          };

          # Headless agent VM: no manpages/docs (shrinks the image closure).
          documentation = {
            enable = lib.mkDefault false;
            nixos.enable = lib.mkDefault false;
            man.enable = lib.mkDefault false;
          };

          # Compressed qcow2 (zlib clusters): ~50-60% smaller image and OCI
          # layer with no KubeVirt incompatibility. Overrides the
          # format = "qcow2" hardcoded in nixpkgs' kubevirt.nix.
          system.build.kubevirtImage = lib.mkForce (import (inputs.nixpkgs + "/nixos/lib/make-disk-image.nix") {
            inherit lib config pkgs;
            inherit (config.image) baseName;
            format = "qcow2-compressed";
          });

          # KubeVirt guest integration & cloud-init
          services = {
            qemuGuest.enable = true;
            cloud-init.enable = true;
            openssh.enable = true;
          };

          # Modified netsa user as headless AI agent
          users.users.netsa = {
            isNormalUser = true;
            home = "/home/netsa";
            extraGroups = ["wheel" "docker"];
            linger = true;
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb4q9LWJR54SzRkfmsA5KWA5/SDEG853oFC8TVilCW/"
            ];
          };
          security.sudo.wheelNeedsPassword = false;

          home-manager = {
            useGlobalPkgs = false;
            useUserPackages = true;
            sharedModules = [
              inputs.plasma-manager.homeModules.plasma-manager
            ];
            users.netsa = self.homeModules.profile-netsa-agent;
          };

          # OpenCode Web server service for netsa
          systemd.user.services.opencode-web = {
            description = "OpenCode Web Server (KubeVirt Headless Agent)";
            wantedBy = ["default.target"];
            after = ["network.target" "headroom-proxy.service"];
            environment = {
              HOME = "/home/netsa";
            };
            serviceConfig = {
              # Optional runtime env (e.g. OPENCODE_SERVER_PASSWORD) via
              # cloud-init write_files into /etc/default/opencode-web.
              EnvironmentFile = "-/etc/default/opencode-web";
              # Overlay package: inputs.opencode v2.0.16 with the upstream
              # postInstall completion fix (see overlays/default.nix).
              ExecStart = "${pkgs.opencode}/bin/opencode serve --port 4096 --hostname 0.0.0.0";
              Restart = "always";
              RestartSec = 3;
            };
          };

          system.stateVersion = "26.11";
        })
      ];
    };
in {
  flake = {
    # Top-level NixOS machine configuration for the KubeVirt AI agent
    nixosConfigurations.kubevirt-agent = mkKubeVirtSystem "x86_64-linux";
  };

  perSystem = {
    pkgs,
    system,
    lib,
    ...
  }: let
    yaml = pkgs.formats.yaml {};
    registryOwner = "andrewthomaslee";
    imageName = "ghcr.io/${registryOwner}/ai-agent";

    # formats.yaml emits a `%YAML 1.1` directive header which kustomize's
    # parser rejects ("did not find expected <document start>"); strip it.
    yamlFile = name: value:
      pkgs.runCommand name {} ''
        sed '/^%YAML/d' ${(yaml.generate name value)} > $out
      '';

    # 1. Bootable QCOW2 disk image (single, unsized — grows at deploy time)
    qcow2Image = (mkKubeVirtSystem system).config.system.build.kubevirtImage;

    # 2. OCI ContainerDisk image (for GHCR): /disk/root.qcow2
    containerdiskImage = pkgs.dockerTools.buildImage {
      name = imageName;
      tag = "latest";
      copyToRoot = pkgs.runCommand "containerdisk-root" {} ''
        mkdir -p $out/disk
        cp ${qcow2Image}/*.qcow2 $out/disk/root.qcow2
      '';
    };

    # 3. KubeVirt Custom Resources evaluated via Kubenix (baseline = sm)
    evalResult = inputs.kubenix.evalModules.${system} {
      module = {kubenix, ...}: {
        imports = [kubenix.modules.k8s];

        kubernetes = {
          customTypes = [
            {
              group = "kubevirt.io";
              version = "v1";
              kind = "VirtualMachine";
              attrName = "virtualmachines";
            }
          ];

          resources = {
            virtualmachines."ai-agent" = {
              metadata = {
                name = "ai-agent";
                labels = {
                  "app.kubernetes.io/name" = "ai-agent";
                  "app.kubernetes.io/instance" = "ai-agent";
                  "app.kubernetes.io/size" = "sm";
                };
              };
              spec = {
                running = true;
                template = {
                  metadata.labels.app = "ai-agent";
                  spec = {
                    domain = {
                      cpu.cores = sizes.sm.cores;
                      resources.requests = {
                        cpu = "${toString sizes.sm.cores}";
                        memory = sizes.sm.memory;
                      };
                      resources.limits = {
                        cpu = "${toString sizes.sm.cores}";
                        memory = sizes.sm.memory;
                      };
                      devices = {
                        disks = [
                          {
                            name = "containerdisk";
                            disk.bus = "virtio";
                          }
                          {
                            name = "cloudinitdisk";
                            disk.bus = "virtio";
                          }
                        ];
                        interfaces = [
                          {
                            name = "default";
                            masquerade = {};
                          }
                        ];
                      };
                    };
                    networks = [
                      {
                        name = "default";
                        pod = {};
                      }
                    ];
                    volumes = [
                      {
                        name = "containerdisk";
                        containerDisk.image = "${imageName}:latest";
                      }
                      {
                        name = "cloudinitdisk";
                        cloudInitNoCloud.userData = ''
                          #cloud-config
                          write_files:
                            - path: /etc/default/opencode-web
                              permissions: "0644"
                              content: |
                                # Runtime overrides for opencode-web.service (EnvironmentFile).
                                # OPENCODE_SERVER_PASSWORD=<set-me-for-public-access>
                                OPENCODE_ENABLE_WEB=true
                                OPENCODE_PORT=4096
                        '';
                      }
                    ];
                  };
                };
              };
            };

            services."ai-agent" = {
              metadata = {
                name = "ai-agent";
                labels.app = "ai-agent";
              };
              spec = {
                type = "ClusterIP";
                selector.app = "ai-agent";
                ports = [
                  {
                    name = "opencode-web";
                    port = 4096;
                    targetPort = 4096;
                  }
                  {
                    name = "ssh";
                    port = 22;
                    targetPort = 22;
                  }
                ];
              };
            };
          };
        };
      };
    };

    objects = evalResult.config.kubernetes.objects;
    vmObj = builtins.head (builtins.filter (o: o.kind == "VirtualMachine") objects);
    svcObj = builtins.head (builtins.filter (o: o.kind == "Service") objects);

    # Base manifests (KubeVirt VM + Service)
    baseVmYaml = yamlFile "virtualmachine.yaml" vmObj;
    baseSvcYaml = yamlFile "service.yaml" svcObj;
    baseKustYaml = yamlFile "kustomization.yaml" {
      apiVersion = "kustomize.config.k8s.io/v1beta1";
      kind = "Kustomization";
      resources = [
        "virtualmachine.yaml"
        "service.yaml"
      ];
      labels = [
        {pairs = {"app.kubernetes.io/part-of" = "ai-agent";};}
      ];
    };

    # Root kustomization: default build = sm baseline
    rootKustYaml = yamlFile "kustomization.yaml" {
      apiVersion = "kustomize.config.k8s.io/v1beta1";
      kind = "Kustomization";
      resources = ["base"];
    };

    # Per-size overlays: strategic-merge patches on cpu/memory + size label
    mkOverlayFiles = sizeName: sizeCfg: {
      "kustomization.yaml" = yamlFile "kustomization.yaml" {
        apiVersion = "kustomize.config.k8s.io/v1beta1";
        kind = "Kustomization";
        resources = ["../../base"];
        patches = [{path = "patch.yaml";}];
        labels = [
          {pairs = {"app.kubernetes.io/size" = sizeName;};}
        ];
      };
      "patch.yaml" = yamlFile "patch.yaml" {
        apiVersion = "kubevirt.io/v1";
        kind = "VirtualMachine";
        metadata.name = "ai-agent";
        spec.template.spec.domain = {
          cpu.cores = sizeCfg.cores;
          resources.requests = {
            cpu = "${toString sizeCfg.cores}";
            inherit (sizeCfg) memory;
          };
          resources.limits = {
            cpu = "${toString sizeCfg.cores}";
            inherit (sizeCfg) memory;
          };
        };
      };
    };

    # Manifests package: kustomization.yaml at root + base/ + overlays/{sm,md,lg}.
    # Validates every kustomization with the kustomize CLI at build time.
    kustomizeDir = pkgs.runCommand "ai-agent-oci" {} ''
      mkdir -p $out/base $out/overlays/sm $out/overlays/md $out/overlays/lg

      install -m 0644 ${rootKustYaml} $out/kustomization.yaml
      install -m 0644 ${baseKustYaml} $out/base/kustomization.yaml
      install -m 0644 ${baseVmYaml} $out/base/virtualmachine.yaml
      install -m 0644 ${baseSvcYaml} $out/base/service.yaml

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (sizeName: sizeCfg: let
          files = mkOverlayFiles sizeName sizeCfg;
        in ''
          install -m 0644 ${files."kustomization.yaml"} $out/overlays/${sizeName}/kustomization.yaml
          install -m 0644 ${files."patch.yaml"} $out/overlays/${sizeName}/patch.yaml
        '')
        sizes)}

      # Validate: root (baseline) and each overlay must build with the
      # kustomize CLI before the package is considered green.
      ${pkgs.kustomize}/bin/kustomize build $out > /dev/null
      for size in sm md lg; do
        ${pkgs.kustomize}/bin/kustomize build $out/overlays/$size > /dev/null
      done
    '';
  in {
    packages = {
      # Bootable NixOS KubeVirt QCOW2 disk image
      kubevirt-image = qcow2Image;
      # OCI containerdisk image (for GHCR)
      ai-agent = containerdiskImage;
      # Kustomization manifests (base + sm/md/lg overlays), Kubenix-evaluated
      ai-agent-oci = kustomizeDir;
    };
  };
}
