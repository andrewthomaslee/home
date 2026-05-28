{
  self,
  inputs,
  customLib,
}: {
  meta = {
    name = "home";
    description = "monorepo";
    domain = "andrewlee.cloud";
  };

  machines = {
    # Andrew's PCs
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
      tags = ["normal"];
    };

    # Home Servers
    kamrui-p1 = {
      deploy.targetHost = "root@kamrui-p1.armadillo-frog.ts.net";
      tags = ["server"];
    };
    inuc-celeron = {
      deploy.targetHost = "root@192.168.1.249";
      tags = ["server"];
    };
    inuc-i5 = {
      deploy.targetHost = "root@192.168.1.248";
      tags = ["server"];
    };

    # Cloud VMs
    # eu
    hel-1 = {
      deploy.targetHost = "root@hel-1.andrewllee.cloud";
      tags = ["vms"];
    };
    hel-2 = {
      deploy.targetHost = "root@hel-2.andrewllee.cloud";
      tags = ["vms"];
    };
    hel-3 = {
      deploy.targetHost = "root@hel-3.andrewllee.cloud";
      tags = ["vms"];
    };

    # us-west
    hil-1 = {
      deploy.targetHost = "root@hil-1.andrewllee.cloud";
      tags = ["vms"];
    };
    hil-2 = {
      deploy.targetHost = "root@hil-2.andrewllee.cloud";
      tags = ["vms"];
    };
    hil-3 = {
      deploy.targetHost = "root@hil-3.andrewllee.cloud";
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
        master.machines.kamrui-p1.settings = {
          domain = "andrewlee.fun";
          distro = "k3s";
          cilium.clustermesh.enable = false;
          traefik.enable = false;
          wireguard = {
            ipv4 = "172.16.0.1";
            endpoint = "192.168.1.251";
          };
        };
        worker.machines = {
          inuc-celeron.settings.wireguard = {
            ipv4 = "172.16.0.2";
            endpoint = "192.168.1.249";
          };
          inuc-i5.settings.wireguard = {
            ipv4 = "172.16.0.3";
            endpoint = "192.168.1.248";
          };
        };
      };
    };

    hcloud-eu = {
      module = {
        name = "rancher";
        input = "clan-community";
      };
      roles = {
        master.machines.hel-1.settings = {
          distro = "rke2";
          cilium.id = 2;
          traefik.enable = true;
          wireguard.ipv4 = "172.16.1.1";
        };
        manager.machines = {
          hel-2.settings.wireguard.ipv4 = "172.16.1.2";
          hel-3.settings.wireguard.ipv4 = "172.16.1.3";
        };
      };
    };

    hcloud-us-west = {
      module = {
        name = "rancher";
        input = "clan-community";
      };
      roles = {
        master.machines.hil-1.settings = {
          distro = "rke2";
          cilium.id = 3;
          traefik.enable = true;
          wireguard.ipv4 = "172.16.3.1";
        };
        manager.machines = {
          hil-2.settings.wireguard.ipv4 = "172.16.3.2";
          hil-3.settings.wireguard.ipv4 = "172.16.3.3";
        };
      };
    };
  };
}
