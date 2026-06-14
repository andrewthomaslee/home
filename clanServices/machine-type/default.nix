{
  # lib,
  # config,
  # clanLib,
  # directory,
  ...
}: {
  _class = "clan.service";
  manifest = {
    name = "machine-type";
    readme = "Machine classification/profiles";
  };

  roles = {
    pc = {
      perInstance.nixosModule = ./pc.nix;
      description = "Personal Computer";
    };
    m = {
      perInstance.nixosModule = ./m.nix;
      description = "Machine (Bare Metal)";
    };
    vm = {
      perInstance.nixosModule = ./vm.nix;
      description = "Virtual Machine";
    };
  };

  # Common configuration for all macine types
  perMachine.nixosModule = {
    self,
    inputs,
    lib,
    customLib,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
  in {
    imports = [
      self.nixosModules.default
    ];

    config = {
      # --- hostSpec options --- #
      hostSpec = {
        clan.enable = true;
        networking.tailscale.enable = true;
        services = {
          motd.enable = true;
          openssh.enable = true;
        };
      };

      # --- nixos options --- #

      # Home-manager
      home-manager = {
        useUserPackages = true;
        backupFileExtension = "hm-backup";
        extraSpecialArgs = {inherit customLib;};
        sharedModules = [inputs.plasma-manager.homeModules.plasma-manager];
      };

      # localization
      i18n.defaultLocale = "en_US.UTF-8";
      time.timeZone = "America/Chicago";

      # Services
      services.journald.extraConfig = "SystemMaxUse=1G";

      # Hardware
      hardware = {
        enableRedistributableFirmware = true;
        graphics.enable = true;
      };

      # System Packages
      environment = {
        enableAllTerminfo = true;
        localBinInPath = true;
        systemPackages = with pkgs;
        with self.packages.${system}; [
          rsync
          fh
          apply-and-reboot
          apply-to-boot
        ];
      };
    };
  };
}
