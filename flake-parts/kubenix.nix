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
    # Search for all kubernetes files in the kubernetes directory and generate a list of names to then generate packages and apps for managing the manifests
    kubeDir = customLib.custom.relativeToRoot "kubernetes";
    kubeFiles = builtins.readDir kubeDir;
    nixFiles = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) kubeFiles;
    kubeNames = map (lib.removeSuffix ".nix") (builtins.attrNames nixFiles);
  in {
    # Dynamically generate packages for each kubernetes file
    packages = lib.genAttrs kubeNames (
      name:
        (inputs.kubenix.evalModules.${system} {
          module = kubeDir + "/${name}.nix";
        }).config.kubernetes.result
    );

    # Dynamically generate app to update all kubernetes manifests
    apps.kubenix = {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "kubenix";
        runtimeInputs = with pkgs.unstable; [
          jq
          coreutils
        ];
        text = let
          clusters = builtins.filter (x: x != "shared") kubeNames;
          hasShared = builtins.elem "shared" kubeNames;

          clusterCmds =
            lib.concatMapStringsSep "\n" (cluster: ''
              echo "Generating manifests for ${cluster}..."
              mkdir -p "$REPO_ROOT"/kubernetes/clusters/${cluster}
              cat ${self'.packages.${cluster}} | jq > "$REPO_ROOT"/kubernetes/clusters/${cluster}/${cluster}.yaml
            '')
            clusters;

          sharedCmds = lib.optionalString hasShared (lib.concatMapStringsSep "\n" (cluster: ''
              echo "Copying shared manifests to ${cluster}..."
              mkdir -p "$REPO_ROOT"/kubernetes/clusters/${cluster}
              cat ${self'.packages.shared} | jq > "$REPO_ROOT"/kubernetes/clusters/${cluster}/shared.yaml
            '')
            clusters);
        in ''
          ${clusterCmds}
          ${sharedCmds}
          echo "All manifests updated successfully!"
        '';
      });
    };
  };
}
