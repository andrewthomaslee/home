{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    # VM test runner with two modes:
    #
    #   sandboxed (default, CI-style):
    #     nix run .#vm-test -- <name> [builder]
    #     Builds the test derivation; the driver runs inside the Nix
    #     build sandbox, the exit code is the test result and the log
    #     is the build log (-L).
    #
    #   driver (AI-agent / debugging friendly):
    #     nix run .#vm-test -- <name> --driver [options]
    #     Builds only the `.driver` output and runs the new standalone
    #     nixos-test-driver(1) OUTSIDE the sandbox, capturing:
    #       <out>/master.log   full master log (stdout, grep-able)
    #       <out>/log.xml      same log as XML (driver LOGFILE env)
    #       <out>/junit.xml    JUnitXML per-subtest report
    #       <out>/out/         files pulled from VMs (copy_from_machine,
    #                          screenshots) via the driver's -o flag
    #     VM state lives in <out>/tmp/vm-state-<machine> (each run gets
    #     its own tmp dir so parallel runs never collide on state or
    #     QEMU images). Green runs clean it; red runs keep it for
    #     post-mortem and `-K`/`--keep-state` can resume from it.
    #
    #   nix run .#vm-test -- --list                    list test names
    #   options for --driver:
    #     --keep-state   keep VM state between runs (driver -K)
    #     --interactive  drop into the ptpython REPL (driverInteractive -I)
    #     --out DIR      artifact directory (default /tmp/home-vm-tests/<name>)
    #     --timeout SEC  external watchdog (default: global_timeout + 300)
    apps.vm-test = {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "vm-test";
        runtimeInputs = with pkgs; [
          git
          nix
          jq
          gnused
          coreutils
        ];
        text = ''
          REPO_ROOT=$(git rev-parse --show-toplevel)
          VM_TESTS="legacyPackages.${pkgs.system}.vmTests"

          usage() {
            cat <<'EOF'
          Usage:
            nix run .#vm-test -- --list
            nix run .#vm-test -- <name> [builder]           sandboxed run (CI-style)
            nix run .#vm-test -- <name> --driver [options]  driver run (logs + artifacts)

          Driver options:
            --keep-state    keep VM state between runs (resumable with -K)
            --interactive   drop into the test-driver Python REPL
            --out DIR       artifact directory (default /tmp/home-vm-tests/<name>)
            --timeout SEC   external watchdog (default: global_timeout + 300)
          EOF
          }

          die() { echo "vm-test: $*" >&2; exit 2; }

          LIST=0 DRIVER=0 KEEP_STATE=0 INTERACTIVE=0 OUT="" TIMEOUT=""
          NAME="" BUILDER=""
          while [ $# -gt 0 ]; do
            case "$1" in
              --list) LIST=1 ;;
              --driver) DRIVER=1 ;;
              -K|--keep-state) KEEP_STATE=1; DRIVER=1 ;;
              -I|--interactive) INTERACTIVE=1; DRIVER=1; KEEP_STATE=1 ;;
              --out) [ $# -ge 2 ] || die "--out needs a value"; OUT="$2"; shift ;;
              --timeout) [ $# -ge 2 ] || die "--timeout needs a value"; TIMEOUT="$2"; shift ;;
              -h|--help) usage; exit 0 ;;
              -*) die "unknown option: $1 (see --help)" ;;
              *) if [ -z "$NAME" ]; then NAME="$1"; elif [ -z "$BUILDER" ]; then BUILDER="$1"; else die "too many positional args"; fi ;;
            esac
            shift
          done

          if [ "$LIST" = 1 ]; then
            nix eval --json "$REPO_ROOT#$VM_TESTS" --apply 'x: builtins.attrNames x' | jq -r '.[]'
            exit 0
          fi

          [ -n "$NAME" ] || { usage >&2; exit 2; }

          # --- sandboxed (CI-style) mode --------------------------------
          if [ "$DRIVER" = 0 ]; then
            if [ -n "$BUILDER" ]; then
              exec nix build --impure --store "ssh-ng://$BUILDER" --expr "(builtins.getFlake (toString $REPO_ROOT)).$VM_TESTS.$NAME" -L
            else
              exec nix build --impure --expr "(builtins.getFlake (toString $REPO_ROOT)).$VM_TESTS.$NAME" -L
            fi
          fi

          # --- driver mode ----------------------------------------------
          ATTR="driver"; [ "$INTERACTIVE" = 1 ] && ATTR="driverInteractive"
          echo "vm-test: building $NAME.$ATTR ..." >&2
          DRIVER=$(nix build --no-link --print-out-paths "$REPO_ROOT#$VM_TESTS.$NAME.$ATTR" | tail -1)
          DRIVER_BIN="$DRIVER/bin/nixos-test-driver"

          # Watchdog: the driver's own global_timeout plus grace.
          CONFIG=$(sed -n 's/.*--config \([^ ]*\).*/\1/p' "$DRIVER_BIN")
          GLOBAL_TIMEOUT=$(jq -r '.global_timeout // 0' "$CONFIG")
          WATCHDOG=''${TIMEOUT:-$((GLOBAL_TIMEOUT + 300))}

          OUT="''${OUT:-''${TMPDIR:-/tmp}/home-vm-tests/$NAME}"
          mkdir -p "$OUT/out"

          # Per-run tmp dir (XDG_RUNTIME_DIR is what the driver's
          # get_tmp_dir() prefers) so parallel runs never share
          # vm-state-<machine> dirs or QEMU disk images.
          export XDG_RUNTIME_DIR="$OUT/tmp"
          mkdir -p "$XDG_RUNTIME_DIR"

          if [ "$INTERACTIVE" = 1 ]; then
            echo "vm-test: interactive REPL for '$NAME' (state: $XDG_RUNTIME_DIR)" >&2
            exec "$DRIVER_BIN" -K -o "$OUT/out"
          fi

          echo "vm-test: running '$NAME' (watchdog: ''${WATCHDOG}s, artifacts: $OUT)" >&2
          START=$(date +%s)
          DRIVER_ARGS=(-o "$OUT/out" --junit-xml "$OUT/junit.xml")
          if [ "$KEEP_STATE" = 1 ]; then
            DRIVER_ARGS+=(-K)
          fi
          set +e
          LOGFILE="$OUT/log.xml" timeout --foreground "$WATCHDOG" "$DRIVER_BIN" \
            "''${DRIVER_ARGS[@]}" 2>&1 | tee "$OUT/master.log"
          STATUS=''${PIPESTATUS[0]}
          set -e
          ELAPSED=$(( $(date +%s) - START ))

          if [ "$STATUS" -ne 0 ]; then
            [ "$STATUS" = 124 ] && echo "vm-test: '$NAME' hit the ''${WATCHDOG}s watchdog (hung run)" >&2
            echo "vm-test: '$NAME' FAILED after ''${ELAPSED}s (exit $STATUS)" >&2
            echo "vm-test: artifacts in $OUT (vm state kept for post-mortem, resume with -K)" >&2
            tail -n 40 "$OUT/master.log" >&2
            exit "$STATUS"
          fi

          # Green: reclaim VM disk state unless asked to keep it.
          if [ "$KEEP_STATE" = 0 ]; then
            rm -rf "$OUT/tmp"
          fi
          echo "vm-test: '$NAME' PASSED in ''${ELAPSED}s (artifacts: $OUT)" >&2
        '';
      });
    };
  };
}
