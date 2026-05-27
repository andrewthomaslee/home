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
              ${lib.optionalString (name != "shared" && builtins.elem "shared" kubeNames) ''
                cat ${self'.packages.shared} | jq > $out/shared.json
              ''}
            '';
          };
        in
          pkgs.dockerTools.buildImage {
            name = "flux-${name}";
            tag = "latest";
            copyToRoot = [manifests];
            config.Cmd = ["/bin/true"];
          };
      })
      (builtins.filter (x: x != "shared") kubeNames));
  };
}
