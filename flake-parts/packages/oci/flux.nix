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
    packages = builtins.listToAttrs (map (name: {
        name = "oci-${name}";
        value = let
          manifests = pkgs.stdenv.mkDerivation {
            name = "${name}-manifests";
            nativeBuildInputs = [pkgs.jq];
            buildCommand = ''
              mkdir -p $out
              cat ${self'.packages.${name}} | jq > $out/${name}.json
              echo "resources:" > $out/kustomization.yaml
              echo "  - ${name}.json" >> $out/kustomization.yaml
              ${lib.optionalString (name != "shared" && builtins.elem "shared" kubeNames) ''
                cat ${self'.packages.shared} | jq > $out/shared.json
                echo "  - shared.json" >> $out/kustomization.yaml
              ''}
            '';
          };
        in
          pkgs.dockerTools.buildImage {
            name = "flux-${name}";
            copyToRoot = [manifests];
            config.Cmd = ["/bin/true"];
          };
      })
      (builtins.filter (x: x != "shared") kubeNames));
  };
}
