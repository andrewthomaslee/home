{inputs, ...}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];
  config = {
    # --- hostSpec options --- #
    hostSpec = {
      networking.tailscale.systray = true;
      hardware = {
        bluetooth.enable = true;
        sound.enable = true;
      };
      services = {
        kde.enable = true;
        wayland.enable = true;
      };
    };
  };
}
