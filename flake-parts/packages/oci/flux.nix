{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    self',
    customLib,
    ...
  }: let
    kubeDir = customLib.custom.relativeToRoot "kubernetes";
    kubeFiles = builtins.readDir kubeDir;
    nixFiles = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) kubeFiles;
    kubeNames = map (lib.removeSuffix ".nix") (builtins.attrNames nixFiles);
  in {
    # oci container per kubenix file holding manifests for flux
    packages = builtins.listToAttrs (builtins.concatMap (name: let
        manifests = pkgs.stdenv.mkDerivation {
          name = "${name}-manifests";
          nativeBuildInputs = [pkgs.jq];
          buildCommand = ''
            mkdir -p $out
            echo "resources:" > $out/kustomization.yaml
            ${lib.optionalString (name != "shared" && builtins.elem "shared" kubeNames) ''
              cat ${self'.packages.shared} | jq > $out/shared.json
              echo "  - shared.json" >> $out/kustomization.yaml
            ''}
            cat ${self'.packages.${name}} | jq > $out/${name}.json
            echo "  - ${name}.json" >> $out/kustomization.yaml
          '';
        };
      in [
        {
          name = "manifests-${name}";
          value = manifests;
        }
        {
          name = "oci-${name}";
          value = pkgs.dockerTools.buildImage {
            name = "flux-${name}";
            copyToRoot = [manifests];
            config.Cmd = ["/bin/true"];
          };
        }
      ])
      (builtins.filter (x: x != "shared") kubeNames));
  };
}
