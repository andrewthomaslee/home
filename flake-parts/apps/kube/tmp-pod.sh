# --- Defaults ---
NAMESPACE="kube-system"
IMAGE="jonlabelle/network-tools"
POD_NAME="net-tools-$(date +%s)"
TARGET_NODE=""

# --- Help Function ---
usage() {
    echo "Usage: $0 [-n <namespace>] [-i <image>] [-h <host/node>]"
    echo "  -n  Namespace (default: $NAMESPACE)"
    echo "  -i  Image (default: $IMAGE)"
    echo "  -h  Host/Node to run on (optional)"
    exit 1
}

# --- Parse Flags ---
# We use getopts. Note that 'h' is now for Host, not Help.
while getopts ":n:i:h:" opt; do
  case ${opt} in
    n) NAMESPACE="$OPTARG" ;;
    i) IMAGE="$OPTARG" ;;
    h) TARGET_NODE="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# --- Execution ---
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl could not be found."
    exit 1
fi

# Build base arguments
ARGS=(run -n "$NAMESPACE" -it --rm --image "$IMAGE" "$POD_NAME")

echo "----------------------------------------"
echo "🛠  Image:     $IMAGE"
echo "📂 Namespace: $NAMESPACE"

if [ -n "$TARGET_NODE" ]; then
    echo "📍 Node:      $TARGET_NODE"
    # Create the JSON override for the nodeName
    OVERRIDE_JSON="{\"spec\": {\"nodeName\": \"$TARGET_NODE\"}}"
    ARGS+=(--overrides="$OVERRIDE_JSON")
else
    echo "🤖 Node:      (Scheduler Choice)"
fi
echo "----------------------------------------"

# Run the command
kubectl "${ARGS[@]}"