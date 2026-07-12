{pkgs, ...}: {
  imports = [];
  config = {
    # hostSpec options
    hostSpec = {};

    environment.systemPackages = with pkgs.unstable; [
      fluxcd
      kubectl
    ];
  };
}
