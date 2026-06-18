{inputs, ...}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];
  config = {
    # hostSpec options
    hostSpec = {
      networking.lan.enabled = true;
      services.docker.enable = true;
    };
  };
}
