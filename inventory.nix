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
      deploy.targetHost = "root@192.168.1.253";
      tags = ["pc" "intel" "lan" "dev" "netsa" "wife"];
    };
    ghost = {
      deploy.targetHost = "root@192.168.1.252";
      tags = ["pc" "intel" "wan" "dev" "netsa"];
    };

    # Other's PCs
    hp-notebook = {
      deploy.targetHost = "root@192.168.1.246";
      tags = ["pc" "wife" "wan"];
    };

    # Home Servers
    inuc-celeron = {
      deploy.targetHost = "root@192.168.1.249";
      tags = ["intel" "m"];
    };
    inuc-i5 = {
      deploy.targetHost = "root@192.168.1.248";
      tags = ["intel" "m" "wan"];
    };
    beelink = {
      deploy.targetHost = "root@192.168.1.250";
      tags = ["amd" "m" "wan"];
    };
    kamrui-h1 = {
      deploy.targetHost = "root@192.168.1.251";
      tags = ["amd" "m" "kde" "wan" "netsa"];
    };

    # Hetzner
    hmetal = {
      deploy.targetHost = "root@[2a01:4f9:2a:b8d::2]";
      tags = ["m"];
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
              attacherReplicaCount = 2;
              provisionerReplicaCount = 2;
              resizerReplicaCount = 2;
              snapshotterReplicaCount = 2;
            };
          };
          # --- Node level settings --- #
          cpu = "amd";
          services.longhorn.v2.enabled = true;
          wireguard = {
            endpoint = "[2600:1700:5e40:c2e0::11]";
            ipv4 = "172.16.0.1";
          };
        };
        # -------- Manager Nodes -------- #
        manager.machines = {
          beelink.settings = {
            cpu = "amd";
            wireguard = {
              endpoint = "[2600:1700:5e40:c2e0::16]";
              ipv4 = "172.16.0.3";
            };
          };
          inuc-i5.settings = {
            cpu = "intel";
            services.web.enabled = false;
            wireguard = {
              endpoint = "[2600:1700:5e40:c2e0::13]";
              ipv4 = "172.16.0.4";
            };
          };
        };
        # -------- Worker Nodes -------- #
        worker.machines = {
          inuc-celeron.settings = {
            cpu = "intel";
            services.web.enabled = false;
            wireguard = {
              endpoint = "[2600:1700:5e40:c2e0::12]";
              ipv4 = "172.16.0.5";
            };
          };
        };
      };
    };

    # --- RKE2 Hetzner Robot/Cloud Cluster --- #
    hcloud = {
      module = {
        name = "rancher";
        input = "clan-community";
      };
      roles = {
        # -------- Master Machine -------- #
        master.machines.hmetal.settings = {
          # --- Cluster Level Settings --- #
          domain = "andrewlee.cloud";
          distro = "rke2";
          cilium.id = 2;
          defaultCpu = "intel";
          longhorn = {
            v2 = {
              enabled = true;
              hugepages.enabled = true;
            };
            helmValues = {
              persistence = {
                dataEngine = "v2";
                defaultClassReplicaCount = 1;
                defaultDataLocality = "best-effort";
              };
              defaultSettings = {
                v1DataEngine = false;
                defaultReplicaCount = 1;
                replicaSoftAntiAffinity = true;
                defaultDataLocality = "strict-local";
              };
              csi = {
                attacherReplicaCount = 1;
                provisionerReplicaCount = 1;
                resizerReplicaCount = 1;
                snapshotterReplicaCount = 1;
              };
            };
          };

          # --- Node level settings --- #
          services.longhorn.v2.enabled = true;
          wireguard = {
            endpoint = "[2a01:4f9:2a:b8d::2]";
            ipv4 = "172.16.1.1";
          };
        };
      };
    };
  };
}
