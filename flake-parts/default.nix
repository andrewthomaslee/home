{
  inputs,
  self,
  lib,
  ...
}: let
  # Define custom lib accessable as `customLib.custom`
  customLib = lib.extend (self: super: {custom = import ../lib {inherit lib;};});
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
    formatter = pkgs.alejandra;
    # Mkdocs
    documentation.mkdocs-root = ../documentation;
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
          inputs.determinate.nixosModules.default
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
        systemPackages = with pkgs; [
          git
          nano
          rsync
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

      # disk
      disko.devices = lib.mkDefault {
        disk = {
          main = {
            name = "main";
            device = lib.mkDefault "/dev/sda";
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                "boot" = {
                  size = "1M";
                  type = "EF02";
                  priority = 1;
                };
                ESP = {
                  type = "EF00";
                  size = "2G";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = ["umask=0077"];
                  };
                };
                nixos = {
                  size = "100%";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/";
                    mountOptions = ["noatime"];
                  };
                };
              };
            };
          };
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
    overlays.default = import ../overlays {inherit inputs self;};

    # ------ Templates ------ #
    templates = {
      default = {
        path = ../templates/default;
        description = "Dendritic Flake";
      };
      minimal = {
        path = ../templates/minimal;
        description = "Minimal Dendritic Flake";
      };
      clan = {
        path = ../templates/clan;
        description = "Dendritic Clan Flake";
      };
    };

    # --- Clan Configuration ------ #
    clan = {
      inventory = import ../inventory.nix {inherit self inputs customLib;};
      specialArgs = {inherit customLib inputs self;};
      modules = {
        "@andrewthomaslee/cluster-mesh" = ../clanServices/cluster-mesh;
        "@andrewthomaslee/kubernetes" = ../clanServices/kubernetes;
      };
    };
  };
}
