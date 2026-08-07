{pkgs, ...}: {
  hostSpec = {
    hardware.jovian.enable = true;
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

  environment.systemPackages = with pkgs;
  with pkgs.unstable; [
    nvtopPackages.full
  ];

  boot.kernelParams = [
    "video=DP-2:3440x1440@165.00" # for ASUS ultra wide
    "initcall_blacklist=simpledrm_platform_driver_init"
    "nvidia_drm.fbdev=0"
  ];

  fileSystems = {
    "/mnt/sata" = {
      device = "/dev/disk/by-id/ata-Samsung_SSD_860_EVO_500GB_S5B2NR0N426114V";
      fsType = "ext4";
      options = ["noatime" "nofail"];
    };
    "/mnt/hdd" = {
      device = "/dev/disk/by-uuid/f7244784-88e5-48ed-9d2a-37f5d3f7f217";
      fsType = "ext4";
      options = ["noatime" "nofail"];
    };
  };
}
