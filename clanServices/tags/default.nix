{
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
    lan = {
      perInstance.nixosModule = ./lan.nix;
      description = "lan";
    };
    wan = {
      perInstance.nixosModule = ./wan.nix;
      description = "wan";
    };
    kde = {
      perInstance.nixosModule = ./kde.nix;
      description = "kde";
    };
  };
}
