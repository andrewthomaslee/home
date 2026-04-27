{
  self,
  inputs,
  customLib,
}: {
  meta = {
    name = "ccc";
    description = "ccc";
    domain = "ccc";
  };

  machines = {
    # Andrew's PCs
    nixos = {
      tags = ["developer"];
      deploy.targetHost = "root@nixos.armadillo-frog.ts.net";
    };
    ghost = {
      tags = ["developer"];
      deploy.targetHost = "root@ghost.armadillo-frog.ts.net";
    };

    # Headless Servers
    kamrui-p1 = {
      tags = ["server" "home-server" "home-agent"];
      deploy.targetHost = "root@kamrui-p1.armadillo-frog.ts.net";
    };
    hel-1 = {
      tags = ["server" "helsinki-server" "helsinki-agent"];
      deploy.targetHost = "root@hel-1.armadillo-frog.ts.net";
    };

    # Other's PCs
    hp-notebook = {
      tags = ["normal"];
      deploy.targetHost = "root@hp-notebook.armadillo-frog.ts.net";
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

    # Cluster Mesh
    cm = {
      module = {
        name = "@andrewthomaslee/cluster-mesh";
        input = "self";
      };
      roles.peer.machines = {
        kamrui-p1.settings = {
          endpoint = "home.andrewlee.fun";
          port = 51823;
          ipv4 = "10.67.67.1";
          ipv6 = "fd67:67::1";
        };
        hel-1.settings = {
          endpoint = "hel-1.andrewlee.cloud";
          port = 51820;
          ipv4 = "10.67.67.2";
          ipv6 = "fd67:67::2";
        };
      };
    };

    # Kubernetes Cluster for Home
    home = {
      module = {
        name = "@andrewthomaslee/kubernetes";
        input = "self";
      };
      roles = {
        init = {
          machines.kamrui-p1.settings = {
            clusterCidr = "10.42.0.0/16,fd42::/56";
            serviceCidr = "10.43.0.0/16,fd43::/112";
          };
          extraModules = [
            {
              services.k3s.manifests.cilium.source = self.packages.x86_64-linux.kubenix-home; # TODO: make system agnostic
            }
          ];
        };
        server.tags = ["home-server"];
        default.tags = ["home-agent"];
      };
    };

    # Kubernetes Cluster for Helsinki
    helsinki = {
      module = {
        name = "@andrewthomaslee/kubernetes";
        input = "self";
      };
      roles = {
        init = {
          machines.hel-1.settings = {
            clusterCidr = "10.52.0.0/16,fd52::/56";
            serviceCidr = "10.53.0.0/16,fd53::/112";
          };
          extraModules = [
            {
              services.k3s.manifests.cilium.source = self.packages.x86_64-linux.kubenix-helsinki; # TODO: make system agnostic
            }
          ];
        };
        server.tags = ["helsinki-server"];
        default.tags = ["helsinki-agent"];
      };
    };
  };
}
