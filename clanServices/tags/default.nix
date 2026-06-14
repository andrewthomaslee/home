{
  # lib,
  # config,
  # clanLib,
  # directory,
  ...
}: {
  _class = "clan.service";
  manifest = {
    name = "tags";
    readme = "Machine tags";
  };

  roles = {
    dev = {
      perInstance.nixosModule = ./dev.nix;
      description = "Dev Computer";
    };
    amd = {
      perInstance.nixosModule = ./amd.nix;
      description = "amd";
    };
    intel = {
      perInstance.nixosModule = ./intel.nix;
      description = "intel";
    };
  };
}
