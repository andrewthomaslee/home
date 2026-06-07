{pkgs, ...}: {
  hostSpec = {
    hardware.intel.enable = true;
    services = {
      motd.sshMotd = builtins.readFile ./sshMotd.sh;
      ollama = {
        enable = true;
        package = pkgs.unstable.ollama-cuda;
        loadModels = [
          "gemma4:e4b"
          "gemma4:e2b"
          "qwen3.5:4b"
          "deepseek-v2:16b-lite-chat-q2_K"
          "codellama:7b-instruct"
          "codellama:7b-python"
          "codegemma:7b-instruct-q4_K_M"
          "codegemma:7b-code-q4_K_M"
          "phi4-mini:3.8b-q4_K_M"
        ];
      };
    };
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    powerManagement.enable = true;
    branch = "latest";
  };
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidiafb"
    "nvidia_drm"
  ];

  environment.systemPackages = with pkgs.unstable; [
    nvitop
    glmark2
    llmfit
  ];

  fileSystems."/mnt/bazzite" = {
    device = "/dev/disk/by-uuid/57af61ee-5474-4fb4-b000-0cc86669e090";
    fsType = "btrfs";
    options = ["noatime" "nofail"];
  };
}
