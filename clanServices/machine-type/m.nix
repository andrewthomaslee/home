{inputs, ...}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];
  config = {
    # hostSpec options
    hostSpec = {
      networking.enable = true;
      services.docker.enable = true;
    };
  };
}
