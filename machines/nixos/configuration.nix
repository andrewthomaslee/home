{pkgs, ...}: {
  hostSpec = {
    hardware = {
      intel.enable = true;
      jovian.enable = true;
    };
    services = {
      motd.sshMotd = builtins.readFile ./sshMotd.sh;
      flatpak.enable = true;
    };
    programs.steam.enable = true;
  };

  nixpkgs.config = {
    cudaSupport = true;
    cudaCapabilities = ["6.1"];
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];
  hardware = {
    nvidia-container-toolkit.enable = true;
    nvidia = {
      modesetting.enable = true;
      open = false;
      powerManagement.enable = true;
      branch = "legacy_580";
    };
  };
  # boot.initrd.kernelModules = [
  #   "nvidia"
  #   "nvidia_modeset"
  #   "nvidiafb"
  #   "nvidia_drm"
  # ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
  ];

  fileSystems."/mnt/bazzite" = {
    device = "/dev/disk/by-uuid/57af61ee-5474-4fb4-b000-0cc86669e090";
    fsType = "btrfs";
    options = ["noatime" "nofail"];
  };
}
