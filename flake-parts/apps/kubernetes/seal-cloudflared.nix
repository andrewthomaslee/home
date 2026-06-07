{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps = {
      seal-cloudflared = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "seal-cloudflared";
          runtimeInputs = with pkgs; [
            kubeseal
            kubectl
            coreutils
            findutils
            gnused
            gnugrep
            git
          ];
          text = ''
            if [ "$#" -ne 2 ]; then
              echo "Usage: seal-cloudflared <source-folder> <dest-folder>"
              exit 1
            fi

            FOLDER=$1
            DEST_DIR=$2

            CERT_FILE="$FOLDER/cert.pem"
            # Find the json file
            CRED_FILE=$(find "$FOLDER" -maxdepth 1 -name "*.json" | head -n 1)

            if [ ! -f "$CERT_FILE" ]; then
              echo "Error: cert.pem not found in $FOLDER"
              exit 1
            fi

            if [ -z "$CRED_FILE" ] || [ ! -f "$CRED_FILE" ]; then
              echo "Error: json credentials file not found in $FOLDER"
              exit 1
            fi

            echo "Sealing cert.pem..."
            kubectl create secret generic cloudflared-cert \
              --namespace=cloudflare \
              --from-file=cert.pem="$CERT_FILE" \
              --dry-run=client -o yaml | \
              kubeseal --format=yaml > "$DEST_DIR/sealed-cloudflared-cert.yaml"

            echo "Sealing credentials.json..."
            kubectl create secret generic cloudflared-credentials \
              --namespace=cloudflare \
              --from-file=credentials.json="$CRED_FILE" \
              --dry-run=client -o yaml | \
              kubeseal --format=yaml > "$DEST_DIR/sealed-cloudflared-credentials.yaml"

            echo "✅ Done! Sealed secrets written to $DEST_DIR"
          '';
        });
      };
    };
  };
}
