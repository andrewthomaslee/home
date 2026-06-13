{lib, ...}: {
  hostSpec.hardware.amd.enable = true;

  networking.networkmanager.enable = lib.mkForce true;
}
