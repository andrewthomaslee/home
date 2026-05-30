{
  self,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    customLib,
    ...
  }: let
    clustersDir = customLib.custom.relativeToRoot "kubernetes/clusters";
    clusters = lib.mapAttrsToList (name: type: name) (
      lib.filterAttrs (name: type: type == "directory") (builtins.readDir clustersDir)
    );
  in {
    checks = lib.genAttrs clusters (
      cluster:
        pkgs.runCommand "kustomize-build-${cluster}" {
          nativeBuildInputs = [pkgs.kustomize];
        } ''
          kustomize build ${self}/kubernetes/clusters/${cluster} > $out
        ''
    );
  };
}
