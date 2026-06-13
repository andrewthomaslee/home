{inputs, ...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.jovian = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.hostSpec.config.jovian;
  in {
    options.hostSpec.config.jovian = {
      enable = lib.mkEnableOption "default jovian configuration";
      steamui = lib.mkEnableOption "steam big picture";
      amd = lib.mkEnableOption "has amd";
    };

    imports = [
      inputs.jovian.nixosModules.default
    ];

    config = lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs.unstable; [
        cmake # Cross-platform, open-source build system generator
        steam-rom-manager # App for adding 3rd party games/ROMs as Steam launch items
      ];

      jovian = {
        hardware.has.amd.gpu = cfg.amd;
        steam.enable = cfg.steamui;
      };

      services.orca.enable = false; # Disable screen reader

      # Steam
      #
      # Set game launcher: gamemoderun %command%
      #   Set this for each game in Steam, if the game could benefit from a minor
      #   performance tweak: YOUR_GAME > Properties > General > Launch > Options
      #   It's a modest tweak that may not be needed. Jovian is optimized for
      #   high performance by default.
      programs = {
        steam = {
          enable = true;
          remotePlay.openFirewall = true;
          dedicatedServer.openFirewall = true;
          localNetworkGameTransfers.openFirewall = true;
        };
        gamemode = {
          enable = true;
          settings = lib.optionalAttrs cfg.amd {
            general.renice = 10;
            gpu = {
              apply_gpu_optimisations = "accept-responsibility"; # For systems with AMD GPUs
              gpu_device = 0;
              amd_performance_level = "high";
            };
          };
        };
      };
      networking.networkmanager.enable = lib.mkForce true; # Steam UI needs networkmanager
    };
  };
}
