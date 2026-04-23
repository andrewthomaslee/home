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
    hp-notebook.tags = ["normal"];

    nixos.tags = ["developer"];
    ghost.tags = ["developer"];

    kamrui-p1.tags = ["server"];
    hel-1.tags = ["server"];
  };

  instances = {
    # --- Import profiles to tagged machines --- #
    # For Andrew's PCs
    developer = {
      module.name = "importer";
      roles.default.tags.developer = {};
      roles.default.extraModules = [self.nixosModules.profile-developer];
    };
    # For Headless Servers
    server = {
      module.name = "importer";
      roles.default.tags.server = {};
      roles.default.extraModules = [self.nixosModules.profile-server];
    };
    # For Other's PCs
    normal = {
      module.name = "importer";
      roles.default.tags.normal = {};
      roles.default.extraModules = [self.nixosModules.profile-normal];
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
