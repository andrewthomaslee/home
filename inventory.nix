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
      deploy.targetHost = "root@localhost";
    };
    ghost = {
      tags = ["developer"];
      deploy.targetHost = "root@localhost";
    };

    # Headless Servers
    kamrui-p1 = {
      tags = ["server"];
      deploy.targetHost = "root@localhost";
    };
    hel-1 = {
      tags = ["server"];
      deploy.targetHost = "root@localhost";
    };

    # Other's PCs
    hp-notebook = {
      tags = ["normal"];
      deploy.targetHost = "root@localhost";
    };
  };

  instances = {
    # --- Profiles --- #
    # For Andrew's PCs
    developer = {
      module.name = "importer";
      roles.default.tags = ["developer"];
      roles.default.extraModules = [self.nixosModules.profile-developer];
    };
    # For Headless Servers
    server = {
      module.name = "importer";
      roles.default.tags = ["server"];
      roles.default.extraModules = [self.nixosModules.profile-server];
    };
    # For Other's PCs
    normal = {
      module.name = "importer";
      roles.default.tags = ["normal"];
      roles.default.extraModules = [self.nixosModules.profile-normal];
    };

    # --- Create Users --- #
    root = {
      module.name = "users";
      roles.default.tags = ["all"];
      roles.default.settings = {
        user = "root";
        share = true;
      };
    };
    netsa = {
      module.name = "users";
      roles.default.tags = ["all"];
      roles.default.settings = {
        user = "netsa";
        share = true;
      };
    };

    # --- SSH Keys Services --- #
    # https://clan.lol/docs/unstable/services/official/sshd
    sshd = {
      roles.server.tags = ["all"];
      roles.client.tags = ["all"];
      roles.server.settings = {
        authorizedKeys.clan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb4q9LWJR54SzRkfmsA5KWA5/SDEG853oFC8TVilCW/";
        hostKeys.rsa.enable = true;
      };
    };
  };
}
