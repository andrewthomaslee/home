# Shared devenv module — evaluated by BOTH entry points:
#   1. devenv CLI (`devenv shell`): root devenv.nix imports this directory.
#   2. flake-parts (`nix develop`): flake-parts/devShells.nix imports it.
#
# Hard rule: no flake-only references (`inputs`, `self'`) here. This module
# evaluates inside devenv's own module system, where `inputs` means
# devenv.yaml inputs, not the flake's. Flake values that packages need are
# injected as pkgs attributes via overlays:
#   - flake mode: overlays/default.nix provides `unstable` and `clan-cli`.
#   - CLI mode: the root devenv.nix overlay provides the same attributes
#     from the devenv.yaml inputs (pinned to the same revs as flake.lock).
{pkgs, ...}:
with pkgs; let
  # One-stop wrapper for the code-agent sandbox lifecycle: builds the
  # image from this flake, loads it into docker under a content-hash tag
  # (never mutable `latest`), and creates an openshell sandbox named
  # `<name>-<shorthash>` with the repo policy + the kimi/github
  # providers. An existing sandbox of the same name prompts for
  # delete-and-replace (bypass with -y). Subcommands: create (default),
  # delete, connect, exec.
  code-sandbox-exec = ''
    set -euo pipefail

    usage() {
      cat >&2 <<'USAGE'
    usage: code-sandbox [create] [name] [options]   build + load image, create sandbox
           code-sandbox delete <name>               delete a sandbox
           code-sandbox connect <name>              attach to a sandbox (Ctrl-P Ctrl-Q detaches)
           code-sandbox exec <name> -- <cmd...>     run a command in a sandbox
           code-sandbox ssh-config                  append ssh configs for ALL active sandboxes

    options:
      -y, --yes          don't prompt when the sandbox already exists (delete + recreate)
          --cpu N        CPUs for the sandbox (default: 4)
          --memory SIZE  memory for the sandbox (default: 8Gi)
      -h, --help         this help
          --no-ssh-config           don't append the Remote-SSH config (default: append)
          --ssh-config-file FILE    where to append it (default: ~/.ssh/config.local)

    The sandbox is named <name>-<imghash> (default name: code), and the
    image is loaded as code-agent:<imghash> — both content-addressed, so
    an existing sandbox name means an older image and prompts for
    replacement. Recreate to pick up image or policy changes; only
    network policy tweaks hot-reload.

    Unless disabled, the generated Remote-SSH config is appended to the
    ssh config file as a managed, per-sandbox comment-delimited block —
    re-running replaces the block for that sandbox instead of
    duplicating it.
    USAGE
      exit "''${1:-0}"
    }

    # Append (or replace) the generated Remote-SSH config for one sandbox
    # as a managed, comment-delimited block — idempotent across re-runs.
    append_ssh_config() {
      mkdir -p "$(dirname "$ssh_config_file")"
      tmp="$ssh_config_file.code-sandbox.tmp"
      if [ -f "$ssh_config_file" ]; then
        sed "/^# code-sandbox: $1\$/,/^# end code-sandbox: $1\$/d" \
          "$ssh_config_file" >"$tmp"
      else
        : >"$tmp"
      fi
      {
        echo "# code-sandbox: $1"
        openshell sandbox ssh-config "$1"
        echo "# end code-sandbox: $1"
      } >>"$tmp"
      chmod 600 "$tmp"
      mv "$tmp" "$ssh_config_file"
      echo "code-sandbox: ssh config for '$1' appended to $ssh_config_file"
    }

    cmd="create"
    if [ $# -gt 0 ] && [ "$1" != "''${1#-}" ]; then
      :
    elif [ $# -gt 0 ]; then
      case "$1" in
        create | delete | connect | exec | ssh-config) cmd="$1"; shift ;;
        -h | --help) usage 0 ;;
        *) usage 1 ;;
      esac
    fi

    name="" yes=0 cpu=4 memory="8Gi" ssh_config=1 ssh_config_file="$HOME/.ssh/config.local"
    while [ $# -gt 0 ]; do
      case "$1" in
        -y | --yes) yes=1; shift ;;
        --cpu) cpu="''${2:?--cpu needs a value}"; shift 2 ;;
        --memory) memory="''${2:?--memory needs a value}"; shift 2 ;;
        --ssh-config) ssh_config=1; shift ;;
        --no-ssh-config) ssh_config=0; shift ;;
        --ssh-config-file) ssh_config_file="''${2:?--ssh-config-file needs a value}"; shift 2 ;;
        -h | --help) usage 0 ;;
        --) shift; break ;;
        -*)
          if [ "$cmd" = exec ]; then break; fi
          echo "code-sandbox: unknown option: $1" >&2; usage 1 ;;
        *)
          if [ -z "$name" ]; then name="$1"; shift
          elif [ "$cmd" = exec ]; then break
          else echo "code-sandbox: unexpected argument: $1" >&2; usage 1
          fi ;;
      esac
    done

    case "$cmd" in
      delete)
        [ -n "$name" ] || { echo "code-sandbox: delete needs a sandbox name" >&2; usage 1; }
        exec openshell sandbox delete "$name"
        ;;
      connect)
        [ -n "$name" ] || { echo "code-sandbox: connect needs a sandbox name" >&2; usage 1; }
        exec openshell sandbox connect "$name"
        ;;
      exec)
        [ -n "$name" ] || { echo "code-sandbox: exec needs a sandbox name" >&2; usage 1; }
        exec openshell sandbox exec -n "$name" -- "$@"
        ;;
      ssh-config)
        [ -z "$name" ] || { echo "code-sandbox: ssh-config takes no sandbox name (it syncs all of them)" >&2; usage 1; }
        sandbox_list="$(mktemp)"
        # Redirect, never pipe the CLI (EPIPE panic, exit 101).
        openshell sandbox list >"$sandbox_list" 2>/dev/null || true
        # First column is the name; drop header/separator lines.
        sandbox_names="$(awk 'NF && $1 !~ /^[Nn][Aa][Mm][Ee]|^-+$/ {print $1}' "$sandbox_list")"
        rm -f "$sandbox_list"
        [ -n "$sandbox_names" ] || { echo "code-sandbox: no active sandboxes found" >&2; exit 1; }
        for sb in $sandbox_names; do
          append_ssh_config "$sb"
        done
        exit 0
        ;;
    esac

    # ---- create ----
    repo_root="$(git rev-parse --show-toplevel)"
    policy="$repo_root/openshell/policies/code-agent.yaml"
    [ -f "$policy" ] || { echo "code-sandbox: policy not found: $policy" >&2; exit 1; }

    echo "code-sandbox: building code-agent-image ..."
    img="$(nix build .#code-agent-image --no-link --print-out-paths)"
    shorthash="$(basename "$img" | cut -c1-8)"
    tag="code-agent:$shorthash"
    name="''${name:-code}-$shorthash"

    echo "code-sandbox: loading image as $tag ..."
    nix run .#load-code-agent-image
    docker tag code-agent:latest "$tag"

    exists=0
    if openshell sandbox inspect "$name" >/dev/null 2>&1; then
      exists=1
    else
      # No `openshell ... | grep -q`: the CLI panics (exit 101) on EPIPE —
      # redirect to a file first (documented lesson in the openshell guide).
      sandbox_list="$(mktemp)"
      openshell sandbox list >"$sandbox_list" 2>/dev/null || true
      if awk '{print $1}' "$sandbox_list" | grep -qx "$name"; then
        exists=1
      fi
      rm -f "$sandbox_list"
    fi
    if [ "$exists" = 1 ]; then
      if [ "$yes" != 1 ]; then
        printf "code-sandbox: sandbox '%s' already exists (older image). Delete and recreate? [y/N] " "$name"
        read -r ans
        case "$ans" in
          y | Y | yes | YES) ;;
          *) echo "code-sandbox: aborted."; exit 1 ;;
        esac
      fi
      openshell sandbox delete "$name"
    fi

    echo "code-sandbox: creating sandbox '$name' (cpu=$cpu memory=$memory) ..."
    openshell sandbox create --name "$name" --from "$tag" \
      --policy "$policy" \
      --provider kimi-for-coding --provider github-agent \
      --cpu "$cpu" --memory "$memory" \
      --detach -- bash -l

    echo "code-sandbox: done. Attach with:  code-sandbox connect $name"

    # Append the generated Remote-SSH config (the equivalent of
    # `openshell sandbox ssh-config $name >> ~/.ssh/config.local`).
    if [ "$ssh_config" = 1 ]; then
      append_ssh_config "$name"
    fi
  '';

  packages = [
    # core
    bashInteractive
    clan-cli

    #linters
    alejandra
    deadnix
    statix
    actionlint

    # lsp
    nixd

    # runtime
    bun
    skopeo
    python3Minimal
  ];
in {
  # ------ Packages ------ #
  inherit packages;

  # ------ Scripts ------ #
  # code-sandbox: one-stop code-agent sandbox lifecycle (create/delete/
  # connect/exec) — see the code-sandbox-exec let-binding above.
  scripts.code-sandbox = {
    exec = code-sandbox-exec;
    description = "Build, load, and manage the OpenShell code-agent sandbox";
  };

  # ------ Environment ------ #
  # Repo root + clan dir (required by the clan CLI), and the gitignored
  # .env loaded via varlock when present. Both are guarded so the same
  # module also works in a fresh agent clone (no .env, no prior git repo).
  enterShell = ''
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git config core.fileMode false
      export REPO_ROOT="$(git rev-parse --show-toplevel)"
      export CLAN_DIR="$REPO_ROOT"
    fi
    if [ -f "$PWD/.env" ]; then
      eval "$(bunx varlock@1.21.1 load --format shell)"
    fi
  '';

  # devenv needs to query the working directory; pure evals (flake
  # consumers) have no PWD fallback — point them at a writable scratch dir
  # instead of failing eval.
  devenv.root = let
    pwd = builtins.getEnv "PWD";
  in
    if pwd == ""
    then "/tmp/devenv-pure-root"
    else pwd;

  # The repo loads secrets via varlock in enterShell, not .env — silence
  # devenv's "consider dotenv" hint.
  dotenv.disableHint = true;
}
