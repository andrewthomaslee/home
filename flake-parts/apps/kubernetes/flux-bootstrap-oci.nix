{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    customLib,
    ...
  }: let
    packagesDir = customLib.custom.relativeToRoot "kubernetes/packages";
    packageDirs = builtins.readDir packagesDir;
    packageNames = builtins.attrNames (lib.filterAttrs (n: v: v == "directory") packageDirs);
  in {
    apps = {
      flux-bootstrap-oci = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "flux-bootstrap-oci";
          runtimeInputs = [
            pkgs.k3s
            pkgs.unstable.fluxcd
          ];
          text = ''
            if [ -z "''${1:-}" ]; then
              echo "Usage: flux-bootstrap-oci <cluster>"
              exit 1
            fi

            CLUSTER=$1
            OUT_DIR="$REPO_ROOT/kubernetes/clusters/$CLUSTER/oci"
            mkdir -p "$OUT_DIR"

            echo "Generating OCI manifests into $OUT_DIR..."

            cat <<EOF > "$OUT_DIR/kustomization.yaml"
            apiVersion: kustomize.config.k8s.io/v1beta1
            kind: Kustomization
            resources:
            EOF

            ${lib.concatMapStringsSep "\n" (pkg: ''
                echo "Generating manifests for ${pkg}..."
                flux create source oci oci-${pkg} \
                  --url="oci://ghcr.io/andrewthomaslee/oci-${pkg}" \
                  --tag="latest" \
                  --interval=5m \
                  --export > "$OUT_DIR/source-oci-${pkg}.yaml"
                echo "  - source-oci-${pkg}.yaml" >> "$OUT_DIR/kustomization.yaml"

                flux create kustomization oci-${pkg} \
                  --source=OCIRepository/oci-${pkg} \
                  --path=. \
                  --prune=true \
                  --interval=5m \
                  --export > "$OUT_DIR/kustomization-${pkg}.yaml"
                echo "  - kustomization-${pkg}.yaml" >> "$OUT_DIR/kustomization.yaml"
              '')
              packageNames}
            echo "Flux OCI Bootstrap Manifests Generated Successfully!"
          '';
        });
      };
    };
  };
}
