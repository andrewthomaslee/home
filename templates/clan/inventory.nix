{
  self,
  inputs,
  customLib,
}: {
  meta = {
    # TODO: change to your info
    name = "ccc";
    description = "ccc";
    domain = "ccc";
  };

  machines = {
    # TODO: change to your machines
    node-1 = {
      tags = ["server"];
      deploy.targetHost = "root@node-2";
    };
    node-2 = {
      tags = ["server"];
      deploy.targetHost = "root@node-2";
    };
  };

  # --- Clan Services --- #
  instances = {
    # --- Profiles --- #
    # For Headless Servers
    server = {
      module.name = "importer";
      roles.default = {
        tags = ["server"];
        extraModules = [self.nixosModules.profile-server];
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
    # TODO: change default user to your default user
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
        authorizedKeys.clan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb4q9LWJR54SzRkfmsA5KWA5/SDEG853oFC8TVilCW/"; # TODO: change ssh key
        hostKeys.rsa.enable = true;
      };
    };

    # https://clan.lol/docs/unstable/services/official/pki
    pki.roles.default.tags = ["all"];

    # https://clan.lol/docs/unstable/services/official/emergency-access
    emergency-access.roles.default.tags = ["all"];
  };
}
