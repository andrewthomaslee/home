{inputs, ...}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];
  config = {
    # hostSpec options
    hostSpec = {
      networking = {
        warp.headless = true;
        lan.enabled = true;
      };
      services.docker.enable = true;
    };
  };
}
