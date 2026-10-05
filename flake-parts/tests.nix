# Auto-discovered NixOS VM tests (nixosLib.runTest modules) from vm-tests/.
# Each vm-tests/<name>.nix must be a function `{self, inputs, pkgs, lib, size, sizeCfg}`
# returning a nixosTest derivation. Every file gets three size variants
# exposed as legacyPackages.vmTests."<name>-<size>" (sm/md/lg) — the names
# the `vm-test` app (flake-parts/apps/vm-test.nix) expects. Sizes only carry
# the driver global_timeout; tests read `size` to gate expensive phases.
{
  lib,
  self,
  inputs,
  ...
}: let
  vmTestsDir = ../vm-tests;
  testFiles = lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n) (
    builtins.readDir vmTestsDir
  );

  sizes = {
    sm.global_timeout = 1200;
    md.global_timeout = 2400;
    lg.global_timeout = 5400;
  };
in {
  perSystem = {pkgs, ...}: {
    legacyPackages.vmTests =
      lib.concatMapAttrs (
        file: _: let
          name = lib.removeSuffix ".nix" file;
        in
          lib.mapAttrs' (
            size: sizeCfg:
              lib.nameValuePair "${name}-${size}" (import (vmTestsDir + "/${file}") {
                inherit self pkgs lib inputs size sizeCfg;
              })
          )
          sizes
      )
      testFiles;
  };
}
