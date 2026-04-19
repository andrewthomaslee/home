{
  self,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    inputs',
    self',
    config,
    ...
  }: {
    _module.args = {};
  };

  flake = {
    # Default NixOS Module
    nixosModules.default = {
      pkgs,
      config,
      inputs',
      self',
      ...
    }: {
      _module.args = {};
    };

    templates = {
      default = {
        path = ../templates/default;
        description = "A basic dendritic flake";
      };
    };
  };
}
