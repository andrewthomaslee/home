{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps = {
      flux-bootstrap = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "flux-bootstrap";
          runtimeInputs = [
            pkgs.k3s
            pkgs.unstable.fluxcd
          ];
          text = ''
            CLUSTER=$1
            kubectl config use-context "$CLUSTER"
            flux install
            flux create source oci cluster-manifests \
              --url=oci://ghcr.io/andrewthomaslee/kube-infra/clusters/"$CLUSTER" \
              --tag=latest \
              --interval=1m \
              --secret-ref=ghcr-read-secret \
              --namespace=flux-system \
              --export | kubectl apply -f -

            flux create kustomization cluster-manifests \
              --source=OCIRepository/cluster-manifests \
              --path="./" \
              --prune=true \
              --interval=1m \
              --namespace=flux-system \
              --export | kubectl apply -f -
          '';
        });
      };
    };
  };
}
