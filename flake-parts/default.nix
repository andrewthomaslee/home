{
  inputs,
  self,
  lib,
  ...
}: let
  # Define custom lib accessable as `customLib.custom`
  customLib = lib.extend (self: super: {custom = import ../lib {inherit lib;};});
  inherit (customLib.custom) relativeToRoot;
in {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    system,
    config,
    self',
    ...
  }: {
    _module.args = {
      inherit customLib;
      # Make pkgs available in perSystem evaluation as well
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
        config.allowUnfree = true;
      };
    };

    # Formatter
    formatter = pkgs.unstable.alejandra;
    # Mkdocs
    documentation.mkdocs-root = relativeToRoot "documentation";
  };

  flake = {
    # ------ NixOS Modules ------ #
    nixosModules.default = {pkgs, ...}: {
      # args passed to all modules
      _module.args = {inherit customLib;};

      # pkgs
      nixpkgs = {
        overlays = [self.overlays.default];
        config.allowUnfree = lib.mkDefault true;
        hostPlatform = lib.mkDefault "x86_64-linux";
      };

      # nixosModules imported
      imports =
        [
          inputs.home-manager.nixosModules.home-manager
        ]
        # Import all NixOS Modules from `flake-parts/nixosModules`
        # Filter out profile modules and clan modules
        ++ (lib.attrValues (lib.filterAttrs (
            n: _:
              n
              != "default"
              && !(lib.hasPrefix "profile-" n)
              && !(lib.hasPrefix "clan-" n)
          )
          self.nixosModules));

      # nix-ld
      programs.nix-ld = {
        enable = true;
        libraries = [pkgs.stdenv.cc.cc];
      };

      # acme
      security.acme = {
        acceptTerms = true;
        defaults.email = lib.mkDefault "andrewthomaslee.business@gmail.com";
      };

      # Often hangs
      systemd.services = {
        NetworkManager-wait-online.enable = lib.mkForce false;
        systemd-networkd-wait-online.enable = lib.mkForce false;
      };

      # Home-manager
      home-manager = {
        useUserPackages = true;
        backupFileExtension = "hm-backup";
        extraSpecialArgs = {inherit customLib;};
      };

      # localization
      i18n.defaultLocale = "en_US.UTF-8";

      # timezone
      time.timeZone = lib.mkDefault "America/Chicago";

      # Services
      services = {
        # Limit log size for journal
        journald.extraConfig = lib.mkDefault "SystemMaxUse=3G";
        # Automatically update firmware
        fwupd.enable = lib.mkDefault true;
        # Enable ACPI
        acpid.enable = lib.mkDefault true;
      };

      # Hardware
      hardware.enableRedistributableFirmware = lib.mkDefault true;

      # System Packages
      environment = {
        enableAllTerminfo = lib.mkDefault true;
        localBinInPath = lib.mkDefault true;
        systemPackages = with pkgs.unstable; [
          git
          nano
          rsync
          fh
        ];
      };

      # Boot
      boot = {
        tmp = {
          useTmpfs = lib.mkDefault false;
          cleanOnBoot = lib.mkDefault true;
        };
        loader.grub = {
          enable = lib.mkDefault true;
          efiSupport = lib.mkDefault true;
          efiInstallAsRemovable = lib.mkDefault true;
        };
      };
    };

    # ------ Home-manager Default Module ------ #
    homeModules = {
      # Default Home-manager Module for all users
      default = {
        nixpkgs = {
          config.allowUnfree = lib.mkDefault true;
          overlays = [
            self.overlays.default
          ];
        };
        home = {
          stateVersion = "25.11";
          keyboard.layout = "us";
        };
        programs.home-manager.enable = true;

        # Import all Home-manager Modules from `flake-parts/homeModules`
        # Filter out profile modules
        imports = lib.attrValues (lib.filterAttrs (
            n: _:
              n
              != "default"
              && !(lib.hasPrefix "profile-" n)
          )
          self.homeModules);
      };
    };

    # ------ Overlays ------ #
    overlays.default = import (relativeToRoot "overlays") {inherit inputs self;};

    # ------ Templates ------ #
    templates = {
      default = {
        path = relativeToRoot "templates/default";
        description = "Dendritic Flake";
      };
      minimal = {
        path = relativeToRoot "templates/minimal";
        description = "Minimal Dendritic Flake";
      };
      clan = {
        path = relativeToRoot "templates/clan";
        description = "Dendritic Clan Flake";
      };
      self = {
        path = relativeToRoot ".";
        description = "This Flake";
      };
    };

    # -- Terranix Modules ------ #
    terranixModules = {
      tofu = import (relativeToRoot "terranixModules/tofu");
      cloudflare = import (relativeToRoot "terranixModules/cloudflare");
    };

    # --- Clan Configuration ------ #
    clan = {
      inventory = import (relativeToRoot "inventory.nix") {inherit self inputs customLib;};
      specialArgs = {inherit customLib inputs self;};
      inherit ((import "${inputs.clan-community}/services/rancher/flake-module.nix" {}).clan) exportInterfaces;
    };
  };
}
