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
            pkgs.yq-go
          ];
          text = ''
            if [ -z "''${1:-}" ]; then
              echo "Usage: flux-bootstrap-oci <cluster> [package|all]"
              exit 1
            fi

            CLUSTER=$1
            PACKAGE=''${2:-all}
            CLUSTER_OCI_DIR="$REPO_ROOT/kubernetes/clusters/$CLUSTER/oci"

            # Create or update main kustomization.yaml
            if [ ! -f "$CLUSTER_OCI_DIR/kustomization.yaml" ]; then
              mkdir -p "$CLUSTER_OCI_DIR"
              cat <<EOF > "$CLUSTER_OCI_DIR/kustomization.yaml"
            apiVersion: kustomize.config.k8s.io/v1beta1
            kind: Kustomization
            resources:
            EOF
            fi

            generate_package() {
              local pkg=$1
              local pkg_dir="$CLUSTER_OCI_DIR/packages/$pkg"
              mkdir -p "$pkg_dir"

              echo "Generating OCI manifests into $pkg_dir..."

              # Add package to main kustomization.yaml if not present
              if ! grep -q "packages/$pkg" "$CLUSTER_OCI_DIR/kustomization.yaml"; then
                echo "  - packages/$pkg" >> "$CLUSTER_OCI_DIR/kustomization.yaml"
              fi

              # Create package kustomization.yaml
              cat <<EOF > "$pkg_dir/kustomization.yaml"
            apiVersion: kustomize.config.k8s.io/v1beta1
            kind: Kustomization
            resources:
              - source-oci-$pkg.json
              - kustomization-$pkg.json
            EOF

              echo "Generating manifests for $pkg..."
              flux create source oci "oci-$pkg" \
                --url="oci://ghcr.io/andrewthomaslee/oci-$pkg" \
                --tag="latest" \
                --interval=5m \
                --export | yq -o=json > "$pkg_dir/source-oci-$pkg.json"

              flux create kustomization "oci-$pkg" \
                --source="OCIRepository/oci-$pkg" \
                --path=. \
                --prune=true \
                --interval=5m \
                --export | yq -o=json > "$pkg_dir/kustomization-$pkg.json"
            }

            if [ "$PACKAGE" = "all" ]; then
              echo "Generating manifests for all packages..."
              for p in ${builtins.concatStringsSep " " packageNames}; do
                generate_package "$p"
              done
              echo "Flux OCI Bootstrap Manifests Generated Successfully for all packages!"
            else
              generate_package "$PACKAGE"
              echo "Flux OCI Bootstrap Manifests Generated Successfully for $PACKAGE!"
            fi
          '';
        });
      };
    };
  };
}
