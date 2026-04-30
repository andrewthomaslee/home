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

    # Dynamically generate apps for each kubernetes file to update the manifests
    apps = lib.genAttrs kubeNames (name: {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = name;
        runtimeInputs = with pkgs.unstable; [
          jq
          coreutils
        ];
        text =
          if name != "shared"
          then ''
            mkdir -p "$REPO_ROOT"/kubernetes/clusters/${name}
            cat ${self'.packages.${name}} | jq > "$REPO_ROOT"/kubernetes/clusters/${name}/${name}.json
          ''
          else ''
            mkdir -p "$REPO_ROOT"/kubernetes/shared
            cat ${self'.packages.${name}} | jq > "$REPO_ROOT"/kubernetes/shared/${name}.json
          '';
      });
    });
  };
}
