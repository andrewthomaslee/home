{inputs, ...}: {
  # ------ Per-System ------ #
  perSystem = {
    system,
    customLib,
    lib,
    self',
    pkgs,
    ...
  }: let
    # Search for all folders in the kubernetes/packages directory
    packagesDir = customLib.custom.relativeToRoot "kubernetes/packages";
    packageDirs = builtins.readDir packagesDir;
    packageNames = builtins.attrNames (lib.filterAttrs (n: v: v == "directory") packageDirs);

    # Generate the base kubenix evaluated JSON for each package
    kubenixPackages = lib.genAttrs packageNames (
      name:
        (inputs.kubenix.evalModules.${system} {
          module = packagesDir + "/${name}/default.nix";
          specialArgs = {inherit pkgs;};
        }).config.kubernetes.result
    );

    # Generate the manifests directory and OCI artifact for each package
    ociPackages = builtins.listToAttrs (builtins.concatMap (name: let
        evaluated = kubenixPackages.${name};
        manifests = pkgs.stdenv.mkDerivation {
          name = "${name}-manifests";
          nativeBuildInputs = [pkgs.jq];
          src = packagesDir + "/${name}";
          buildCommand = ''
            mkdir -p $out

            # Copy all contents except default.nix
            if [ -d $src ]; then
              cp -r $src/. $out/
              chmod -R u+w $out
              rm -f $out/default.nix
            fi

            # Save the evaluated JSON from kubenix
            cat ${evaluated} | jq > $out/${name}.json

            # Generate kustomization.yaml including all resources
            echo "resources:" > $out/kustomization.yaml
            for f in $(ls $out | grep -E '\.(yaml|yml|json)$' | grep -v 'kustomization.yaml'); do
              echo "  - $f" >> $out/kustomization.yaml
            done
          '';
        };
        oci = pkgs.dockerTools.buildImage {
          name = "home/infra/packages/${name}";
          copyToRoot = [manifests];
          config.Labels."org.opencontainers.image.description" = "pre-packaged ${name} manifests";
        };
      in [
        {
          name = "manifests-${name}";
          value = manifests;
        }
        {
          name = "oci-${name}";
          value = oci;
        }
      ])
      packageNames);
  in {
    # Dynamically generate packages
    packages = kubenixPackages // ociPackages;

    # Dynamically generate app to update all kubernetes manifests locally if desired for inspection
    apps.kubenix = {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "kubenix";
        runtimeInputs = with pkgs.unstable; [
          jq
          coreutils
        ];
        text = let
          cmds =
            lib.concatMapStringsSep "\n" (name: ''
              echo "Generating manifests for ${name}..."
              mkdir -p "$REPO_ROOT"/kubernetes/packages/${name}/result
              cp -rf ${self'.packages."manifests-${name}"}/* "$REPO_ROOT"/kubernetes/packages/${name}/result
            '')
            packageNames;
        in ''
          ${cmds}
          echo "All manifests updated successfully!"
        '';
      });
    };
  };
}
