{
  clanLib,
  config,
  lib,
  ...
}: let
  # Shared interface options
  sharedInterface = {lib, ...}: {
    options = {};
  };
in {
  _class = "clan.service";
  manifest.name = "blank";
  manifest.description = "blank";
  manifest.categories = [];
  manifest.readme = builtins.readFile ./README.md;
  manifest.exports.out = [];

  exports =
    lib.mapAttrs' (instanceName: _: {
      name = clanLib.buildScopeKey {
        inherit instanceName;
        serviceName = config.manifest.name;
      };
      value = {};
    })
    config.instances;

  # role-1
  roles.role-1 = {
    description = "role 1";
    interface = {lib, ...}: {
      imports = [sharedInterface];
      options = {};
    };

    perInstance = {
      instanceName,
      settings,
      roles,
      machine,
      mkExports,
      ...
    }: {
      exports =
        mkExports {
        };

      nixosModule = {
        config,
        pkgs,
        lib,
        ...
      }: {
      };

      darwinModule = {
        config,
        pkgs,
        lib,
        ...
      }: {
      };
    };
  };

  # role-2
  roles.role-2 = {
    description = "role 2";
    interface = {lib, ...}: {
      imports = [sharedInterface];
      options = {};
    };
    perInstance = {
      settings,
      instanceName,
      roles,
      machine,
      mkExports,
      ...
    }: {
      exports =
        mkExports {
        };

      nixosModule = {
        config,
        pkgs,
        lib,
        ...
      }: {
      };
      darwinModule = {
        config,
        pkgs,
        lib,
        ...
      }: {
      };
    };
  };

  # Maps over all machines and produces one result per machine, regardless of role
  perMachine = {
    instances,
    machine,
    ...
  }: {
    nixosModule = {
      pkgs,
      lib,
      ...
    }: {
    };
    darwinModule = {
      pkgs,
      lib,
      ...
    }: {
    };
  };
}
