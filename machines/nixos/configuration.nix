{config, ...}: {
  hostSpec = {
    services.motd.sshMotd = builtins.readFile ./sshMotd.sh;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidiafb"
    "nvidia_drm"
  ];

  fileSystems."/mnt/bazzite" = {
    device = "/dev/disk/by-uuid/57af61ee-5474-4fb4-b000-0cc86669e090";
    fsType = "btrfs";
    options = ["noatime" "nofail"];
  };
}
