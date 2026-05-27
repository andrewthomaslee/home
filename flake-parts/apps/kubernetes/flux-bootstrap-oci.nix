{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps = {
      flux-bootstrap-oci = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "flux-bootstrap-oci";
          runtimeInputs = [
            pkgs.kubectl
            pkgs.unstable.fluxcd
          ];
          text = ''
            if [ -z "''${1:-}" ]; then
              echo "Usage: flux-bootstrap-oci <cluster>"
              exit 1
            fi

            CLUSTER=$1
            kubectl config use-context "$CLUSTER"

            echo "Installing Flux controllers..."
            flux install

            echo "Configuring OCI Source (Idempotent)..."
            flux create source oci flux-system \
              --url="oci://ghcr.io/andrewthomaslee/flux-$CLUSTER" \
              --tag-semver="0.3.x" \
              --interval=10m \
              --export | kubectl apply -f -

            echo "Configuring Kustomization (Idempotent)..."
            flux create kustomization flux-system \
              --source=OCIRepository/flux-system \
              --path=. \
              --prune=true \
              --interval=10m \
              --export | kubectl apply -f -

            echo "Flux OCI Bootstrap Complete!"
          '';
        });
      };
    };
  };
}
