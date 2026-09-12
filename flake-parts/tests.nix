{
  inputs,
  self,
  lib,
  ...
}: let
  # Dynamic VM test sizing specifications:
  # - sm: 2 cores, 4 GB RAM, 30 GB disk (baseline)
  # - md: 4 cores, 8 GB RAM, 60 GB disk (2x)
  # - lg: 6 cores, 12 GB RAM, 90 GB disk (3x)
  sizes = {
    sm = {
      cores = 2;
      memorySize = 4 * 1024; # 4096 MiB
      diskSize = 30 * 1024; # 30720 MiB
    };
    md = {
      cores = 4;
      memorySize = 8 * 1024; # 8192 MiB
      diskSize = 60 * 1024; # 61440 MiB
    };
    lg = {
      cores = 6;
      memorySize = 12 * 1024; # 12288 MiB
      diskSize = 90 * 1024; # 92160 MiB
    };
  };

  # Dedicated directory containing VM test definitions at repo root
  testDir = self + "/vm-tests";

  # Auto-discover all *.nix files (excluding files starting with '_' or '.')
  testFiles =
    if builtins.pathExists testDir
    then
      lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".nix" name && !lib.hasPrefix "_" name && !lib.hasPrefix "." name)
      (builtins.readDir testDir)
    else {};
in {
  perSystem = {system, ...}: let
    testPkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [self.overlays.default];
      config.allowUnfree = true;
    };

    nixosLib = import (inputs.nixpkgs + "/nixos/lib") {};

    # Dynamically generate 3 sized tests (sm, md, lg) for a given test file
    mkSizedTests = filename: _: let
      rawTest = import (testDir + "/${filename}");

      callWith = fn: args:
        if builtins.isFunction fn
        then let
          fnArgs = builtins.functionArgs fn;
        in
          if fnArgs == {}
          then fn args
          else
            fn (
              if fnArgs ? "..."
              then args
              else builtins.intersectAttrs fnArgs args
            )
        else fn;

      sizedTests = lib.mapAttrs' (sizeSuffix: sizeConfig: let
        sizeInfo = sizeConfig // {name = sizeSuffix;};
        testSpec = callWith rawTest {
          inherit inputs self system lib;
          pkgs = testPkgs;
          testPkgs = testPkgs;
          size = sizeInfo;
          sizeName = sizeSuffix;
        };

        baseName = testSpec.name or (lib.removeSuffix ".nix" filename);
        testName = "${baseName}-${sizeSuffix}";
      in
        lib.nameValuePair testName (nixosLib.runTest {
          imports = [
            testSpec
            {
              name = lib.mkForce testName;
              hostPkgs = lib.mkDefault testPkgs;
              requiredFeatures.kvm = lib.mkDefault true;
              qemu.forceAccel = lib.mkDefault true;
              defaults = {
                virtualisation.cores = lib.mkDefault sizeConfig.cores;
                virtualisation.memorySize = lib.mkDefault sizeConfig.memorySize;
                virtualisation.diskSize = lib.mkDefault sizeConfig.diskSize;
              };
            }
          ];
        }))
      sizes;
    in
      sizedTests;

    # Merge all dynamically generated sized tests across all discovered test files
    allVmTests = lib.foldl' lib.mergeAttrs {} (lib.mapAttrsToList mkSizedTests testFiles);
  in {
    # Expose under legacyPackages so tests are excluded from `nix flake check`
    legacyPackages.vmTests = allVmTests;
  };
}
