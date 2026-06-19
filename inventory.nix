{
  self,
  inputs,
  customLib,
}: let
  inherit (customLib.custom) relativeToRoot;
in {
  meta = {
    name = "home";
    description = "monorepo";
    domain = "andrewlee.cloud";
  };

  machines = {
    # Andrew's PCs
    nixos = {
      deploy.targetHost = "root@nixos.armadillo-frog.ts.net";
      tags = ["pc" "intel" "lan" "dev" "netsa" "wife"];
    };
    ghost = {
      deploy.targetHost = "root@ghost.armadillo-frog.ts.net";
      tags = ["pc" "intel" "wan" "dev" "netsa"];
    };

    # Other's PCs
    hp-notebook = {
      deploy.targetHost = "root@hp-notebook.armadillo-frog.ts.net";
      tags = ["pc" "wife" "wan"];
    };

    # Home Servers
    inuc-celeron = {
      deploy.targetHost = "root@inuc-celeron.armadillo-frog.ts.net";
      tags = ["intel" "m"];
    };
    inuc-i5 = {
      deploy.targetHost = "root@inuc-i5.armadillo-frog.ts.net";
      tags = ["intel" "m" "wan"];
    };
    beelink = {
      deploy.targetHost = "root@beelink.armadillo-frog.ts.net";
      tags = ["amd" "m" "wan"];
    };
    kamrui-h1 = {
      deploy.targetHost = "root@kamrui-h1.armadillo-frog.ts.net";
      tags = ["amd" "m" "kde" "wan" "netsa"];
    };

    # Cloud VMs
    hel-1 = {
      deploy.targetHost = "root@hel-1.andrewlee.cloud";
      tags = ["vm"];
    };
    hel-2 = {
      deploy.targetHost = "root@hel-2.andrewlee.cloud";
      tags = ["vm"];
    };
    hel-3 = {
      deploy.targetHost = "root@hel-3.andrewlee.cloud";
      tags = ["vm"];
    };
    hel-4 = {
      deploy.targetHost = "root@hel-4.andrewlee.cloud";
      tags = ["vm"];
    };
    hel-5 = {
      deploy.targetHost = "root@hel-5.andrewlee.cloud";
      tags = ["vm"];
    };
  };

  # --- Clan Services --- #
  instances = {
    machine-type = {
      module.input = "self";
      module.name = "@andrewthomaslee/machine-type";
      roles = {
        pc.tags.pc = {};
        m.tags.m = {};
        vm.tags.vm = {};
      };
    };

    tags = {
      module.input = "self";
      module.name = "@andrewthomaslee/tags";
      roles = {
        dev.tags.dev = {};
        amd.tags.amd = {};
        intel.tags.intel = {};
        lan.tags.lan = {};
        wan.tags.wan = {};
        kde.tags.kde = {};
      };
    };

    # --- Create Users --- #
    # Admin
    root = {
      module.name = "users";
      roles.default = {
        settings = {
          user = "root";
          prompt = false;
        };
        tags = ["all"];
        extraModules = [(relativeToRoot "users/root")];
      };
    };

    # Default User
    netsa = {
      module.name = "users";
      roles.default = {
        settings = {
          user = "netsa";
          share = true;
        };
        tags = ["netsa"];
        extraModules = [(relativeToRoot "users/netsa")];
      };
    };

    # Default Wife
    wife = {
      module.name = "users";
      roles.default = {
        settings = {
          user = "wife";
          share = true;
        };
        tags = ["wife"];
        extraModules = [(relativeToRoot "users/wife")];
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

    # -------- ☸️   Kubernetes   ☸️ -------- #

    # --- K3s Mini PC Cluster --- #
    home = {
      # Feature Branch of clan-community
      # https://git.clan.lol/andrewthomaslee/clan-community/src/branch/feat/rancher/
      module = {
        name = "rancher";
        input = "clan-community";
      };
      roles = {
        # -------- Master Machine -------- #
        master.machines.kamrui-h1.settings = {
          # --- Cluster Level Settings --- #
          domain = "andrewlee.fun";
          distro = "k3s";
          cilium.id = 1;
          longhorn = {
            v2 = {
              enabled = true;
              hugepages.enabled = true;
            };
            helmValues.csi = {
              attacherReplicaCount = 1;
              provisionerReplicaCount = 1;
              resizerReplicaCount = 1;
              snapshotterReplicaCount = 1;
            };
          };
          # --- Node level settings --- #
          services.longhorn.v2.enabled = true;
          wireguard = {
            endpoint = "[2600:1700:5e40:c2e0::11]";
            ipv4 = "172.16.0.1";
          };
        };
        # -------- Manager Nodes -------- #
        manager.machines = {
          beelink.settings = {
            wireguard = {
              endpoint = "[2600:1700:5e40:c2e0::16]";
              ipv4 = "172.16.0.3";
            };
          };
          inuc-i5.settings = {
            wireguard = {
              endpoint = "[2600:1700:5e40:c2e0::13]";
              ipv4 = "172.16.0.4";
            };
          };
        };
        # -------- Worker Nodes -------- #
        worker.machines = {
          inuc-celeron.settings = {
            services.web.enabled = false;
            wireguard = {
              endpoint = "[2600:1700:5e40:c2e0::12]";
              ipv4 = "172.16.0.5";
            };
          };
        };
      };
    };

    # --- RKE2 Hetzner Cloud Cluster --- #
    hcloud = {
      module = {
        name = "rancher";
        input = "clan-community";
      };
      roles = {
        # -------- Master Machine -------- #
        master.machines.hel-1.settings = {
          # --- Cluster Level Settings --- #
          domain = "andrewlee.cloud";
          distro = "rke2";
          cilium.id = 2;
          # --- Node level settings --- #
          wireguard.ipv4 = "172.16.1.1";
        };
        # -------- Manager Nodes -------- #
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
