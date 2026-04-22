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
      # Make pkgs.unstable available in perSystem evaluation as well
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
        config.allowUnfree = true;
      };
    };

    # Formatter
    formatter = pkgs.unstable.alejandra;
    # Mkdocs
    documentation.mkdocs-root = ../documentation;
  };

  flake = {
    # ------ NixOS Modules ------ #
    nixosModules.default = {pkgs, ...}: {
      _module.args = {inherit customLib;};

      nixpkgs = {
        overlays = [self.overlays.default];
        config.allowUnfree = true;
      };

      imports = [
        inputs.determinate.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
      ];

      home-manager = {
        useUserPackages = true;
        backupFileExtension = "hm-backup";
        extraSpecialArgs = {inherit customLib;};
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      boot.loader.grub.enable = lib.mkDefault true;
      boot.loader.grub.efiSupport = lib.mkDefault true;
      boot.loader.grub.efiInstallAsRemovable = lib.mkDefault true;
      disko.devices = lib.mkDefault {
        disk = {
          main = {
            name = "main";
            device = "/dev/sda";
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
                  size = "1G";
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

    # ------ Home-manager Modules ------ #
    homeModules = {
      # Default Home-manager Module for all users
      default = {
        nixpkgs = {
          config.allowUnfree = true;
          overlays = [
            self.overlays.default
          ];
        };
        home.stateVersion = "25.11";
        programs.home-manager.enable = true;
      };
      # Root User's Home-manager Module
      root = {
        imports = [
          self.homeModules.default
          {
            home.username = "root";
            home.homeDirectory = "/root";
          }
        ];
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
    };

    # --- Clan Configuration ------ #
    clan = {
      inventory = import ../inventory.nix {inherit self inputs customLib;};
      specialArgs = {inherit customLib;};
    };
  };
}
