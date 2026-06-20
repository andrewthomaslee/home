{...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.steam = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.hostSpec.programs.steam;
    pureGamescope =
      (import pkgs.path {
        inherit (pkgs) system;
        config.allowUnfree = true;
      }).gamescope;
  in {
    options.hostSpec.programs.steam = {
      enable = lib.mkEnableOption "default steam configuration";
      amd = lib.mkOption {
        type = lib.types.bool;
        default = config.hostSpec.hardware.amd.enable or false;
        description = "has amd";
        example = true;
      };
    };

    config = lib.mkIf cfg.enable {
      hardware.graphics.enable32Bit = true;
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
      environment.systemPackages = with pkgs; [
        cmake # Cross-platform, open-source build system generator
        steam-rom-manager # App for adding 3rd party games/ROMs as Steam launch items
        steam-run
        (pkgs.heroic.override {
          extraPkgs = p:
            with p; [
              pureGamescope
              gamemode
              mangohud
              winetricks
              cabextract
            ];
        })
      ];

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
          extraCompatPackages = with pkgs; [
            proton-ge-bin
          ];
        };
        gamescope = {
          enable = true;
          package = pureGamescope;
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
        appimage = {
          enable = true;
          binfmt = true;
        };
      };
    };
  };
}
