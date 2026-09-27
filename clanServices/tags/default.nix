{
  _class = "clan.service";
  manifest = {
    name = "tags";
    readme = "Machine tags";
  };

  roles = {
    amd = {
      perInstance.nixosModule = ./amd.nix;
      description = "amd";
    };
    dev = {
      perInstance.nixosModule = ./dev.nix;
      description = "Dev Computer";
    };
    intel = {
      perInstance.nixosModule = ./intel.nix;
      description = "intel";
    };
    lan = {
      perInstance.nixosModule = ./lan.nix;
      description = "lan";
    };
    virt = {
      perInstance.nixosModule = ./virt.nix;
      description = "Virtualization host";
    };
    wan = {
      perInstance.nixosModule = ./wan.nix;
      description = "wan";
    };
  };
}
