{
  self,
  inputs,
  customLib,
}: {
  meta = {
    name = "home";
    description = "monorepo";
    domain = "andrewlee.fun";
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

    # Headless Servers
    kamrui-p1 = {
      deploy.targetHost = "root@kamrui-p1.armadillo-frog.ts.net";
      tags = ["server"];
    };
    inuc-celeron = {
      deploy.targetHost = "root@inuc-celeron.armadillo-frog.ts.net";
      tags = ["server"];
    };
    inuc-i5 = {
      deploy.targetHost = "root@inuc-i5.armadillo-frog.ts.net";
      tags = ["server"];
    };

    # Cloud VMs
    hel-1 = {
      deploy.targetHost = "root@hel-1.armadillo-frog.ts.net";
      tags = ["server" "vms"];
    };
    hel-2 = {
      deploy.targetHost = "root@hel-2.armadillo-frog.ts.net";
      tags = ["server" "vms"];
    };
    hel-3 = {
      deploy.targetHost = "root@hel-3.armadillo-frog.ts.net";
      tags = ["server" "vms"];
    };

    # Other's PCs
    hp-notebook = {
      deploy.targetHost = "root@hp-notebook.armadillo-frog.ts.net";
      tags = ["normal"];
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
        extraModules = with inputs.packer.nixosModules; [
          default
          hcloud
          ext4
        ];
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
          distro = "k3s";
          cilium.id = 1;
          traefik.enable = false;
          wireguard = {
            ipv4 = "172.16.0.1";
            endpoint = "home.andrewlee.fun";
            port = 51823;
          };
        };
        worker.machines = {
          inuc-celeron.settings.wireguard = {
            ipv4 = "172.16.0.2";
            endpoint = "home.andrewlee.fun";
            port = 51825;
          };
          inuc-i5.settings.wireguard = {
            ipv4 = "172.16.0.3";
            endpoint = "home.andrewlee.fun";
            port = 51826;
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
  };
}
