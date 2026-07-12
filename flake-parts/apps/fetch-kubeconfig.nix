{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps = {
      fetch-kubeconfig = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "fetch-kubeconfig";
          runtimeInputs = with pkgs; [
            rsync
            kubectl
            coreutils
          ];
          text = ''
            REMOTE=$1
            CLUSTER=$2
            TYPE=''${3:-k3s}

            if [[ "$TYPE" != "k3s" && "$TYPE" != "rke2" ]]; then
              echo "Error: TYPE must be either 'k3s' or 'rke2'. Got: $TYPE"
              exit 1
            fi

            if [ "$TYPE" = "k3s" ]; then
              KUBECONFIG_SRC="root@$REMOTE:/etc/rancher/k3s/k3s.yaml"
            else
              KUBECONFIG_SRC="root@$REMOTE:/etc/rancher/rke2/rke2.yaml"
            fi

            KUBECONFIG_PATH="$REPO_ROOT/.secrets/kubeconfig/$CLUSTER.yaml"
            mkdir -p "$(dirname "$KUBECONFIG_PATH")"

            echo "==> Fetching kubeconfig from $REMOTE (type: $TYPE) . . ."

            # Fetch kubeconfig
            rsync "$KUBECONFIG_SRC" "$KUBECONFIG_PATH"

            sed -i "s/: default/: $CLUSTER/g" "$KUBECONFIG_PATH"

            # Set the correct server address
            kubectl --kubeconfig="$KUBECONFIG_PATH" config set-cluster "$CLUSTER" --server="https://$REMOTE:6443"
            chmod 660 "$KUBECONFIG_PATH"

            echo "✅ Done!"
          '';
        });
      };
    };
  };
}
