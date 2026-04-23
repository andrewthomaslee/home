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
    server = {
      deploy.targetHost = "root@server.ccc";
      tags = ["server"];
    };
    developer = {
      deploy.targetHost = "root@developer.ccc";
      tags = ["developer"];
    };
    normal = {
      deploy.targetHost = "root@normal.ccc";
      tags = ["normal"];
    };
  };

  instances = {
    # --- Import profiles to tagged machines --- #
    # For Andrew's PCs
    developer = {
      module.name = "importer";
      roles.default.tags.developer = {};
      roles.default.extraModules = [self.nixosModules.developer];
    };
    # For Headless Servers
    server = {
      module.name = "importer";
      roles.default.tags.server = {};
      roles.default.extraModules = [self.nixosModules.server];
    };
    # For Other's PCs
    normal = {
      module.name = "importer";
      roles.default.tags.normal = {};
      roles.default.extraModules = [self.nixosModules.normal];
    };

    # --- Create Users --- #
    root = {
      module.name = "users";
      roles.default.tags.all = {};
      roles.default.settings = {
        user = "root";
        share = true;
      };
    };
    netsa = {
      module.name = "users";
      roles.default.tags.all = {};
      roles.default.settings = {
        user = "netsa";
        share = true;
      };
    };
  };
}
