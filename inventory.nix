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
    domain = "andrewlee.fun";
  };

  machines = {
    # Andrew's PCs
    nixos = {
      deploy.targetHost = "root@nixos";
      tags = ["pc" "intel" "lan" "dev" "netsa" "wife"];
    };
    ghost = {
      deploy.targetHost = "root@ghost";
      tags = ["pc" "intel" "wan" "dev" "netsa"];
    };
    # Wife's PCs
    hp-notebook = {
      deploy.targetHost = "root@192.168.1.246";
      tags = ["pc" "intel" "wan" "wife"];
    };

    nixos-installer.tags = ["iso"];
  };

  # --- Clan Services --- #
  instances = {
    machine-type = {
      module.input = "self";
      module.name = "@andrewthomaslee/machine-type";
      roles = {
        pc.tags.pc = {};
        iso.tags.iso = {};
      };
    };

    tags = {
      module.input = "self";
      module.name = "@andrewthomaslee/tags";
      roles = {
        dev.tags.dev = {};
        # amd.tags.amd = {};
        intel.tags.intel = {};
        lan.tags.lan = {};
        wan.tags.wan = {};
      };
    };

    # installer = {
    #   module.name = "installer";
    #   roles.iso.tags.iso = {};
    # };

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
  };
}
