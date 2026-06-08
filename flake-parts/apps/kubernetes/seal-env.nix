{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps = {
      seal-env = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "seal-env";
          runtimeInputs = with pkgs.unstable; [
            kubeseal
            kubectl
          ];
          text = ''
            if [ "$#" -ne 4 ]; then
              echo "Usage: seal-env <env-file> <secret-name> <namespace> <output-file>"
              exit 1
            fi

            ENV_FILE=$1
            SECRET_NAME=$2
            NAMESPACE=$3
            OUTPUT_FILE=$4

            if [ ! -f "$ENV_FILE" ]; then
              echo "Error: env file $ENV_FILE not found"
              exit 1
            fi

            echo "Sealing $ENV_FILE..."
            kubectl create secret generic "$SECRET_NAME" \
              --namespace="$NAMESPACE" \
              --from-env-file="$ENV_FILE" \
              --dry-run=client -o yaml | \
              kubeseal --format=yaml > "$OUTPUT_FILE"

            echo "✅ Done! Sealed secret written to $OUTPUT_FILE"
          '';
        });
      };
    };
  };
}
