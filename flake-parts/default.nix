{
  inputs,
  self,
  lib,
  ...
}: let
  # Define custom lib accessable as `customLib.custom`
  customLib = lib.extend (_self: _super: {custom = import ../lib {inherit lib;};});
  inherit (customLib.custom) relativeToRoot;
in {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    system,
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
    nixosModules.default = {...}: {
      # args passed to all modules
      _module.args = {inherit customLib;};

      # customLib (and thus relativeToRoot) for home-manager modules — set
      # here, not per clan service, so non-clan consumers (KubeVirt VM
      # packages, test VMs) get it too.
      home-manager.extraSpecialArgs = {inherit customLib;};

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
          stateVersion = "26.11";
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
    # Scaffold a new repo from this one: `nix flake init -t .#self`
    templates.self = {
      path = relativeToRoot ".";
      description = "This Flake";
    };

    # --- Clan Configuration ------ #
    clan = {
      inventory = import (relativeToRoot "inventory.nix") {inherit customLib;};
      specialArgs = {inherit customLib inputs self;};
      inherit ((import "${inputs.clan-community}/services/rancher/flake-module.nix" {}).clan) exportInterfaces;
      modules = {
        "@andrewthomaslee/machine-type" = relativeToRoot "clanServices/machine-type";
        "@andrewthomaslee/tags" = relativeToRoot "clanServices/tags";
      };
    };
  };
}
