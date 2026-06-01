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
      flux-update-infra = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "flux-update-infra";
          runtimeInputs = [
            pkgs.k3s
            pkgs.unstable.fluxcd
            pkgs.yq-go
          ];
          text = ''
            INFRA_DIR="''${REPO_ROOT:-/home/netsa/home}/kubernetes/infra/packages"

            # Create or update main kustomization.yaml
            if [ ! -f "$INFRA_DIR/kustomization.yaml" ]; then
              mkdir -p "$INFRA_DIR"
              cat <<EOF > "$INFRA_DIR/kustomization.yaml"
            apiVersion: kustomize.config.k8s.io/v1beta1
            kind: Kustomization
            resources:
            EOF
            fi

            generate_package() {
              local pkg=$1
              local pkg_dir="$INFRA_DIR/$pkg"
              mkdir -p "$pkg_dir"

              echo "Generating OCI manifests into $pkg_dir..."

              # Add package to main kustomization.yaml if not present
              if ! grep -q "  - $pkg" "$INFRA_DIR/kustomization.yaml"; then
                echo "  - $pkg" >> "$INFRA_DIR/kustomization.yaml"
              fi

              # Create package kustomization.yaml
              cat <<EOF > "$pkg_dir/kustomization.yaml"
            apiVersion: kustomize.config.k8s.io/v1beta1
            kind: Kustomization
            resources:
              - source-oci-home-oci-packages-$pkg.json
              - kustomization-home-oci-packages-$pkg.json
            EOF

              echo "Generating manifests for $pkg..."
              flux create source oci "home-oci-packages-$pkg" \
                --url="oci://ghcr.io/andrewthomaslee/home/infra/packages/$pkg" \
                --tag="latest" \
                --interval=5m \
                --export | yq -o=json > "$pkg_dir/source-oci-home-oci-packages-$pkg.json"

              flux create kustomization "home-oci-packages-$pkg" \
                --source="OCIRepository/home-oci-packages-$pkg" \
                --path=. \
                --prune=true \
                --interval=5m \
                --export | yq -o=json > "$pkg_dir/kustomization-home-oci-packages-$pkg.json"
            }

            echo "Generating manifests for all packages..."
            for p in ${builtins.concatStringsSep " " packageNames}; do
              generate_package "$p"
            done
            echo "Flux OCI Infra Manifests Generated Successfully for all packages!"
          '';
        });
      };
    };
  };
}
