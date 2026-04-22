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
  };

  instances = {
    importer = {
      roles.default.tags.all = {};
      roles.default.extraModules = [self.nixosModules.default];
    };

    user-root = {
      module.name = "users";
      roles.default.tags.all = {};
      roles.default.settings = {
        user = "root";
        share = true;
      };
      roles.default.extraModules = [
        {
          home-manager.users.root = self.homeModules.root;
        }
      ];
    };
  };
}
