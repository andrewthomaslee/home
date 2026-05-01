{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps.fetch-kubeconfig = {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "fetch-kubeconfig";
        runtimeInputs = with pkgs; [
          rsync
          k3s
          coreutils
        ];
        text = ''
          REMOTE=$1
          CLUSTER=$2
          KUBECONFIG_PATH="$REPO_ROOT/.secrets/kubeconfig/$CLUSTER.yaml"
          mkdir -p "$(dirname "$KUBECONFIG_PATH")"

          echo "==> Fetching kubeconfig from $REMOTE . . ."

          # Fetch kubeconfig
          rsync "root@$REMOTE:/etc/rancher/k3s/k3s.yaml" "$KUBECONFIG_PATH"

          sed -i "s/: default/: $CLUSTER/g" "$KUBECONFIG_PATH"

          # Set the correct server address
          kubectl --kubeconfig="$KUBECONFIG_PATH" config set-cluster "$CLUSTER" --server="https://$REMOTE:6443"
          chmod 660 "$KUBECONFIG_PATH"

          echo "✅ Done!"
        '';
      });
    };
  };
}
