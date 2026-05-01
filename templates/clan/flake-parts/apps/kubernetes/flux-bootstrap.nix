{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps.flux-bootstrap = {
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
          flux bootstrap github \
            --token-auth \
            --owner=andrewthomaslee \
            --repository=home \
            --branch=main \
            --path=kubernetes/clusters/"$CLUSTER" \
            --personal
        '';
      });
    };
  };
}
