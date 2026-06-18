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

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
  ];

  fileSystems = {
    "/mnt/bazzite" = {
      device = "/dev/disk/by-uuid/57af61ee-5474-4fb4-b000-0cc86669e090";
      fsType = "btrfs";
      options = ["noatime" "nofail"];
    };
    "/mnt/hdd" = {
      device = "/dev/disk/by-uuid/f7244784-88e5-48ed-9d2a-37f5d3f7f217";
      fsType = "ext4";
      options = ["noatime" "nofail"];
    };
  };
}
