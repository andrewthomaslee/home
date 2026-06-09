{
  self,
  inputs,
  customLib,
}: let
  extraGroups = [
    "docker"
    "wheel"
    "networkmanager"
    "audio"
    "libvirtd"
    "tty"
    "dialout"
    "video"
    "storage-users"
  ];
in {
  meta = {
    name = "home";
    description = "monorepo";
    domain = "andrewlee.cloud";
  };

  machines = {
    # Andrew's PCs
    kamrui-h1 = {
      deploy.targetHost = "root@kamrui-h1.armadillo-frog.ts.net";
      tags = ["developer" "wife"];
    };
    nixos = {
      deploy.targetHost = "root@nixos.armadillo-frog.ts.net";
      tags = ["developer"];
    };
    ghost = {
      deploy.targetHost = "root@ghost.armadillo-frog.ts.net";
      tags = ["developer"];
    };

    # Other's PCs
    hp-notebook = {
      deploy.targetHost = "root@hp-notebook.armadillo-frog.ts.net";
      tags = ["normal" "wife"];
    };

    # Home Servers
    inuc-celeron = {
      deploy.targetHost = "root@inuc-celeron.armadillo-frog.ts.net";
      tags = ["server"];
    };
    inuc-i5 = {
      deploy.targetHost = "root@inuc-i5.armadillo-frog.ts.net";
      tags = ["server"];
    };

    # Cloud VMs
    # eu
    hel-1 = {
      deploy.targetHost = "root@hel-1.andrewlee.cloud";
      tags = ["vms"];
    };
    hel-2 = {
      deploy.targetHost = "root@hel-2.andrewlee.cloud";
      tags = ["vms"];
    };
    hel-3 = {
      deploy.targetHost = "root@hel-3.andrewlee.cloud";
      tags = ["vms"];
    };
    hel-4 = {
      deploy.targetHost = "root@hel-4.andrewlee.cloud";
      tags = ["vms"];
    };
    hel-5 = {
      deploy.targetHost = "root@hel-5.andrewlee.cloud";
      tags = ["vms"];
    };
  };

  # --- Clan Services --- #
  instances = {
    # --- Profiles --- #
    # For Andrew's PCs
    developer = {
      module.name = "importer";
      roles.default = {
        tags = ["developer"];
        extraModules = [self.nixosModules.profile-developer];
      };
    };
    # For Headless Servers
    server = {
      module.name = "importer";
      roles.default = {
        tags = ["server"];
        extraModules = [self.nixosModules.profile-server];
      };
    };
    # For Other's PCs
    normal = {
      module.name = "importer";
      roles.default = {
        tags = ["normal"];
        extraModules = [self.nixosModules.profile-normal];
      };
    };
    # For Cloud VMs
    vms = {
      module.name = "importer";
      roles.default = {
        tags = ["vms"];
        extraModules = [self.nixosModules.profile-vms];
      };
    };

    # --- Create Users --- #
    # Admin
    root = {
      module.name = "users";
      roles.default = {
        tags = ["all"];
        settings = {
          user = "root";
          share = true;
        };
      };
    };
    # Default User
    netsa = {
      module.name = "users";
      roles.default = {
        tags = ["all"];
        settings = {
          user = "netsa";
          share = true;
        };
        extraModules = [
          {
            users.users.netsa = {
              isNormalUser = true;
              home = "/home/netsa";
              description = "andrewthomaslee";
              inherit extraGroups;
            };
          }
        ];
      };
    };

    # Default Wife
    wife = {
      module.name = "users";
      roles.default = {
        tags = ["wife"];
        settings = {
          user = "wife";
          share = true;
        };
        extraModules = [
          {
            home-manager.users.wife = self.homeModules.profile-normal;
            users.users.wife = {
              isNormalUser = true;
              home = "/home/wife";
              description = "wife";
              inherit extraGroups;
            };
          }
        ];
      };
    };

    # https://clan.lol/docs/unstable/services/official/sshd
    sshd.roles = {
      server.tags = ["all"];
      client.tags = ["all"];
      server.settings = {
        authorizedKeys.clan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb4q9LWJR54SzRkfmsA5KWA5/SDEG853oFC8TVilCW/";
        hostKeys.rsa.enable = true;
      };
    };

    # https://clan.lol/docs/unstable/services/official/pki
    pki.roles.default.tags = ["all"];

    # https://clan.lol/docs/unstable/services/official/emergency-access
    emergency-access.roles.default.tags = ["all"];

    home = {
      module = {
        name = "rancher";
        input = "clan-community";
      };
      roles = {
        master.machines.kamrui-h1.settings = {
          domain = "andrewlee.fun";
          distro = "k3s";
          cilium.helmValues.ingressController.enabled = false;
          traefik.enable = false;
          longhorn.helmValues = {
            defaultSettings.guaranteedInstanceManagerCPU = 6;
            longhornUI.replicas = 1;
            csi = {
              attacherReplicaCount = 1;
              provisionerReplicaCount = 1;
              resizerReplicaCount = 1;
              snapshotterReplicaCount = 1;
            };
          };
          wireguard = {
            endpoint = "[2600:1700:5e40:c2e0::11]";
            ipv4 = "172.16.0.1";
          };
        };
        worker.machines = {
          inuc-celeron.settings = {
            services.web = false;
            wireguard = {
              endpoint = "[2600:1700:5e40:c2e0::12]";
              ipv4 = "172.16.0.2";
            };
          };
          inuc-i5.settings = {
            wireguard = {
              endpoint = "[2600:1700:5e40:c2e0::13]";
              ipv4 = "172.16.0.3";
            };
          };
        };
      };
    };

    hcloud = {
      module = {
        name = "rancher";
        input = "clan-community";
      };
      roles = {
        master.machines.hel-1.settings = {
          domain = "andrewlee.cloud";
          distro = "rke2";
          cilium.id = 2;
          wireguard.ipv4 = "172.16.1.1";
        };
        manager.machines = {
          hel-2.settings.wireguard.ipv4 = "172.16.1.2";
          hel-3.settings.wireguard.ipv4 = "172.16.1.3";
          hel-4.settings.wireguard.ipv4 = "172.16.1.4";
          hel-5.settings.wireguard.ipv4 = "172.16.1.5";
        };
      };
    };
  };
}
