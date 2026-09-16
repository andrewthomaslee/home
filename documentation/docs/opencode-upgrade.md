# OpenCode Nix/K8s Upgrade — Agent Instruction Sheet

One-shot task sheet for an AI agent implementing the OpenCode Nix + Kubernetes
tooling upgrade in this flake. Follow steps in order. Every step has a **Gate**
that must pass before continuing. Do not skip gates.

## Objective

1. Swap the Nix LSP from `nil` to `nixd` with dynamic per-repo flake targeting.
2. Wire Helm/YAML LSP support for Kubernetes work.
3. Add a hermetic `kubernetes-mcp-server` package and enable it by default.
4. Add Nix linters and a Kubernetes/Rancher toolset.
5. Add per-repo override files for this repo and a scaffolding package for
   other repos (e.g. `borg`).
6. Match the VS Code (vscodium) config to the same nixd setup.
7. Flip `homeSpec.programs.headroom.proxy.memory` default to `false`.

## Verified context (why these designs are correct)

- opencode spawns LSP servers with `cwd` = project root
  (`packages/opencode/src/lsp/lsp.ts`), so `toString ./.` inside nixd eval
  expressions anchors to the repo opencode was opened in.
- opencode's LSP client answers `workspace/configuration` requests by looking
  up `item.section` as a dotted path inside the server's `initialization`
  object (`packages/opencode/src/lsp/client.ts`, `configurationValue`).
  nixd requests section `"nixd"`, so its config must be nested under an
  `"nixd"` key inside `initialization`.
- nixd's config root shape is `{nixpkgs, options, formatting, diagnostic}`
  where `options` is a map of arbitrary names to `{expr}`
  (nixd `docs/configuration.md`; verified in
  `nixd/lib/Controller/Configuration.cpp`).
- nixd is a **built-in** opencode LSP (auto-starts when the `nixd` binary is
  on PATH and LSP is enabled). Defining an `lsp.nixd` entry in settings
  **overrides** the built-in (same key) — do NOT use a different key like
  `nix` or both servers may start.
- Config cascade: global `~/.config/opencode/opencode.json` is merged with
  project `opencode.json`; project wins on conflicting keys, non-conflicting
  keys are preserved. This is the per-repo override mechanism.
- Repo is x86_64-linux only. flake-parts auto-imports everything under
  `flake-parts/` via `import-tree`; new `.nix` files must be `git add`-ed
  before Nix can see them.
- Formatter is alejandra. CI runs `nix flake check`.

## Prerequisites

- Work inside `nix develop`.
- Confirm the working tree is clean: `git status`.
- Container tooling is available for Go builds via `buildGoModule` (no extra
  setup needed).

## Step 0 — Pin the exact expression strings

All nixd expressions used in this task. Keep them byte-identical across
files (only the flake path differs, see notes per step).

Hostname selector (machine-agnostic, read at eval time):

```nix
builtins.replaceStrings ["\n"] [""] (builtins.readFile /etc/hostname)
```

Dynamic flake root: `(builtins.getFlake (toString ./.))` — resolves to the
workspace root under opencode. Under VS Code use the absolute path
`/home/netsa/home` instead (VS Code does not guarantee the server process cwd
is the workspace).

Expressions:

| Name | Expression |
|---|---|
| `NIXPKGS_DYN` | `import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }` |
| `NIXPKGS_FALLBACK` | `import (if builtins.pathExists (toString ./. + "/flake.nix") then (builtins.getFlake (toString ./.)).inputs.nixpkgs else (builtins.getFlake "/home/netsa/home").inputs.nixpkgs) { }` |
| `NIXOS_OPTS` | `(builtins.getFlake (toString ./.)).nixosConfigurations.${builtins.replaceStrings ["\n"] [""] (builtins.readFile /etc/hostname)}.options` |
| `HM_OPTS` | `(builtins.getFlake (toString ./.)).nixosConfigurations.${builtins.replaceStrings ["\n"] [""] (builtins.readFile /etc/hostname)}.options.home-manager.users.type.getSubOptions []` |
| `FLAKEPARTS_OPTS` | `(builtins.getFlake (toString ./.)).debug.options` |
| `NIXOS_OPTS_ABS` | same as `NIXOS_OPTS` with `(toString ./.))` → `"/home/netsa/home")` |
| `HM_OPTS_ABS` | same as `HM_OPTS` with the same substitution |

**Gate 0** — verify the hostname selector evaluates:

```bash
cd /home/netsa/home
nix eval --impure --raw --expr 'builtins.replaceStrings ["\n"] [""] (builtins.readFile /etc/hostname)'
# expect: kamrui-h1
```

Note: `nix eval --expr` **without** `--impure` will fail with "access to
absolute path is forbidden in pure evaluation mode". That is the CLI's own
pure-eval default, NOT how nixd behaves: nixd links libnixexpr with default
`pure-eval = false` (no pure-eval handling exists in nixd's source), so its
eval workers accept `readFile /etc/hostname`. Do not "fix" anything based on
the bare-CLI failure.

Contingency (only if nixd logs readFile errors at runtime): replace the
hostname selector in ALL expressions with:

```nix
builtins.head (builtins.attrNames (builtins.getFlake (toString ./.)).nixosConfigurations)
```

(option declarations are near-identical across machines of the same flake, so
any machine's options tree is fine for LSP completion).

## Step 1 — `kubernetes-mcp-server` package

Create `flake-parts/packages/kubernetes-mcp-server.nix`:

```nix
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  ...
}: let
  version = "0.0.66";
in
  buildGoModule {
    pname = "kubernetes-mcp-server";
    inherit version;

    src = fetchFromGitHub {
      owner = "containers";
      repo = "kubernetes-mcp-server";
      rev = "v${version}";
      hash = ""; # fill via Gate 1a
    };

    vendorHash = ""; # fill via Gate 1a

    env.CGO_ENABLED = "0";

    ldflags = ["-s" "-w" "-X main.version=${version}"];

    # Upstream embeds build info; if the build fails on a `toolchain`
    # directive in go.mod, pin `go = pkgs.go_1_24;` (or newer) on the
    # buildGoModule invocation and retry.

    meta = {
      description = "MCP server for Kubernetes and OpenShift";
      homepage = "https://github.com/containers/kubernetes-mcp-server";
      license = lib.licenses.asl20;
      mainProgram = "kubernetes-mcp-server";
      platforms = ["x86_64-linux"];
    };
  }
```

Start with `hash = lib.fakeHash; vendorHash = lib.fakeHash;` (add `lib` to the
function args), then run the gate twice to harvest real hashes.

**Gate 1a** — hash harvesting:

```bash
git add flake-parts/packages/kubernetes-mcp-server.nix
nix build .#kubernetes-mcp-server 2>&1 | grep -E "got:|specified:"
```

Copy the two `got:` sha256 strings into `hash` / `vendorHash`.

**Gate 1b** — binary works:

```bash
nix build .#kubernetes-mcp-server
./result/bin/kubernetes-mcp-server --help 2>&1 | head -30
```

Record the exact read-only flag name from `--help` output (expected
`--read-only-tools` or `--read-only`). Use that literal string in Step 3.

## Step 2 — Overlay exposure

In `overlays/default.nix`, next to the existing `headroom` /
`headroom-slim` / `artifacthub-mcp` entries, add:

```nix
kubernetes-mcp-server =
  self.packages.${final.stdenv.hostPlatform.system}.kubernetes-mcp-server;
```

**Gate 2** — `nix eval .#nixosConfigurations.kamrui-h1.pkgs.kubernetes-mcp-server.version`
returns `0.0.66`.

## Step 3 — opencode home-module changes

File: `flake-parts/homeModules/opencode.nix`.

### 3a. New options (inside `options.homeSpec.programs.opencode`)

```nix
# Kubernetes MCP server (containers/kubernetes-mcp-server, hermetic Go build).
enableK8sMcp = lib.mkOption {
  type = lib.types.bool;
  default = true;
  description = "Enable the Kubernetes MCP server in opencode settings.";
};
k8sMcpReadOnly = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Run the Kubernetes MCP server in read-only mode.";
};
```

### 3b. Packages

- In the always-on `extraPackages` list (first `with pkgs.unstable;` block):
  - **remove** `nil`
  - **add**: `nixd`, `statix`, `deadnix`, `nix-output-monitor`,
    `yaml-language-server`
- In the `fullDevTools` blocks (both `home.packages` and `extraPackages`):
  - **add**: `kustomize`, `kubeconform`, `stern`, `kubectx`,
    `kubectl-neat`, `helm-docs`, `rancher`, `etcd`, `kubevirt`,
    `kubernetes-helmPlugins.helm-diff`

### 3c. LSP config (inside `settings.lsp`)

**Remove** the entire existing `nix = { command = ["nil"]; ... }` entry.

**Add** (keep `python`, `gleam`, `pyright.disabled` as-is):

```nix
nixd = {
  command = ["nixd"];
  extensions = [".nix"];
  env.NIX_PATH = "nixpkgs=${inputs.nixpkgs}";
  initialization.nixd.nixpkgs.expr = "<NIXPKGS_FALLBACK>";
};
helm_ls = {
  command = ["helm_ls" "serve"];
  extensions = [".yaml" ".yml"];
};
```

Notes:
- `initialization.nixd.nixpkgs.expr` — the config is nested under the
  `"nixd"` key (see Verified context). In Nix attr syntax:
  `initialization.nixd.nixpkgs.expr = "…";`
- `env.NIX_PATH` uses this flake's pinned nixpkgs input as the out-of-box
  default for non-flake directories; `NIXPKGS_FALLBACK` prefers the opened
  repo's flake and falls back to this repo's flake.
- Do NOT add a separate `yaml` LSP entry. `helm_ls` automatically launches
  `yaml-language-server` (installed in 3b) for non-template YAML files;
  two competing YAML servers would double the diagnostics.
- Intentionally no `options` exprs in the global config: foreign repos get
  nixpkgs-only completion; exact-structure overrides live in per-repo files
  (Step 4/7).

### 3d. MCP config

Add to the `settings = lib.mkMerge [...]` list:

```nix
(lib.mkIf cfg.enableK8sMcp {
  mcp = {
    kubernetes = {
      type = "local";
      command =
        ["${lib.getExe pkgs.kubernetes-mcp-server}" "--stdio"]
        ++ lib.optional cfg.k8sMcpReadOnly "<READ_ONLY_FLAG_FROM_GATE_1B>";
      enabled = true;
    };
  };
})
```

**Gate 3** — module evaluates:

```bash
git add -A
nix eval .#nixosConfigurations.kamrui-h1.config.home-manager.users.netsa.homeSpec.programs.opencode.enableK8sMcp
# expect: true
nix eval --json .#nixosConfigurations.kamrui-h1.config.home-manager.users.netsa.programs.opencode.settings.lsp.nixd
# expect: JSON with command ["nixd"], env.NIX_PATH, initialization.nixd.nixpkgs.expr
```

## Step 4 — Per-repo override for THIS repo: `opencode.json`

Create `opencode.json` at the repo root (committed, machine-agnostic — the
hostname is resolved inside nixd at eval time, not baked in):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {
    "nixd": {
      "command": ["nixd"],
      "extensions": [".nix"],
      "initialization": {
        "nixd": {
          "nixpkgs": {
            "expr": "import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }"
          },
          "options": {
            "nixos": {
              "expr": "(builtins.getFlake (toString ./.)).nixosConfigurations.${builtins.replaceStrings [\"\\n\"] [\"\"] (builtins.readFile /etc/hostname)}.options"
            },
            "home-manager": {
              "expr": "(builtins.getFlake (toString ./.)).nixosConfigurations.${builtins.replaceStrings [\"\\n\"] [\"\"] (builtins.readFile /etc/hostname)}.options.home-manager.users.type.getSubOptions []"
            },
            "flake-parts": {
              "expr": "(builtins.getFlake (toString ./.)).debug.options"
            }
          }
        }
      }
    }
  }
}
```

JSON escaping matters: the Nix string `"\n"` inside the replaceStrings list
must be `"\\n"` in JSON; all inner Nix double quotes are `\"`.

**Gate 4** — validate every expression, run from repo root (`--apply` is a
CLI flag — keep it outside the expression):

```bash
nix eval --impure --raw --expr 'builtins.toString (builtins.attrNames ((builtins.getFlake (toString ./.)).inputs.nixpkgs.lib))' >/dev/null && echo nixpkgs-expr-ok
nix eval --impure --raw --expr 'builtins.toString (builtins.length (builtins.attrNames ((builtins.getFlake (toString ./.)).nixosConfigurations.${builtins.replaceStrings ["\n"] [""] (builtins.readFile /etc/hostname)}.options)))'
# expect: a positive integer (63 on kamrui-h1 today)
nix eval --impure --raw --expr 'builtins.toString (builtins.length (builtins.attrNames ((builtins.getFlake (toString ./.)).nixosConfigurations.${builtins.replaceStrings ["\n"] [""] (builtins.readFile /etc/hostname)}.options.home-manager.users.type.getSubOptions [])))'
# expect: a positive integer (38 on kamrui-h1 today)
```

Also validate the JSON parses: `jq -e .lsp.nixd.initialization.nixd.options < opencode.json`.

## Step 5 — Per-repo override for THIS repo: `.vscode/settings.json`

Create `.vscode/settings.json` at the repo root. Use **absolute** flake paths
here (VS Code's server cwd is unreliable), but keep the hostname dynamic:

```json
{
  "nix.enableLanguageServer": true,
  "nix.serverPath": "nixd",
  "nix.formatterPath": "alejandra",
  "nix.serverSettings": {
    "nixd": {
      "formatting": {"command": ["alejandra"]},
      "nixpkgs": {
        "expr": "import (builtins.getFlake \"/home/netsa/home\").inputs.nixpkgs { }"
      },
      "options": {
        "nixos": {
          "expr": "(builtins.getFlake \"/home/netsa/home\").nixosConfigurations.${builtins.replaceStrings [\"\\n\"] [\"\"] (builtins.readFile /etc/hostname)}.options"
        },
        "home-manager": {
          "expr": "(builtins.getFlake \"/home/netsa/home\").nixosConfigurations.${builtins.replaceStrings [\"\\n\"] [\"\"] (builtins.readFile /etc/hostname)}.options.home-manager.users.type.getSubOptions []"
        },
        "flake-parts": {
          "expr": "(builtins.getFlake \"/home/netsa/home\").debug.options"
        }
      }
    }
  }
}
```

**Gate 5** — `jq -e .nix.serverSettings.nixd < .vscode/settings.json` parses.

## Step 6 — flake-parts debug option (required by `FLAKEPARTS_OPTS`)

In `flake.nix`, inside the flake-parts module (same level as `systems` /
`imports`), add:

```nix
debug = true;
```

**Gate 6**:

```bash
nix eval .#debug.options --apply 'a: builtins.length (builtins.attrNames a)'
# expect: a positive integer
```

## Step 7 — `opencode-nixd-scaffold` package (per-repo automation)

Create `flake-parts/packages/opencode-nixd-scaffold.nix`:

```nix
{
  lib,
  writeShellScriptBin,
  python3,
  ...
}:
  writeShellScriptBin "opencode-nixd-scaffold" ''
    set -euo pipefail
    VSCODE=0; FORCE=0
    for arg in "$@"; do
      case "$arg" in
        --vscode) VSCODE=1 ;;
        --force) FORCE=1 ;;
        *) echo "usage: opencode-nixd-scaffold [--vscode] [--force]"; exit 1 ;;
      esac
    done
    ROOT=$(pwd)
    HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname)
    HOSTNAME=$(printf '%s' "$HOSTNAME" | tr -d '\n')

    # nixd expressions: dynamic ./. for opencode (its LSP cwd == project root),
    # absolute path for VS Code (server cwd unreliable there).
    exec python3 - "$ROOT" "$HOSTNAME" "$VSCODE" "$FORCE" <<'PYEOF'
    import json, os, sys
    root, hostname, vscode, force = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4] == "1"
    hostsel = f'builtins.replaceStrings ["\\n"] [""] (builtins.readFile /etc/hostname)'
    dyn = {
        "nixpkgs": {"expr": "import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }"},
        "options": {
            "nixos": {"expr": f"(builtins.getFlake (toString ./.)).nixosConfigurations.${{{hostsel}}}.options"},
            "home-manager": {"expr": f"(builtins.getFlake (toString ./.)).nixosConfigurations.${{{hostsel}}}.options.home-manager.users.type.getSubOptions []"},
        },
    }
    def write(path, data):
        if os.path.exists(path) and not force:
            sys.exit(f"{path} exists; refusing (use --force)")
        os.makedirs(os.path.dirname(path), exist_ok=True) if "/" in path.lstrip("./") else None
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        print(f"wrote {path}")
    write("opencode.json", {
        "$schema": "https://opencode.ai/config.json",
        "lsp": {"nixd": {"command": ["nixd"], "extensions": [".nix"],
                          "initialization": {"nixd": dyn}}},
    })
    if vscode:
        q = lambda s: json.dumps(s)
        absroot = root.replace('"', '')
        vs = {
            "nix.enableLanguageServer": True,
            "nix.serverPath": "nixd",
            "nix.formatterPath": "alejandra",
            "nix.serverSettings": {"nixd": {
                "formatting": {"command": ["alejandra"]},
                "nixpkgs": {"expr": f"import (builtins.getFlake {q(absroot)}).inputs.nixpkgs {{ }}"},
                "options": {
                    "nixos": {"expr": f"(builtins.getFlake {q(absroot)}).nixosConfigurations.${{{hostsel}}}.options"},
                    "home-manager": {"expr": f"(builtins.getFlake {q(absroot)}).nixosConfigurations.${{{hostsel}}}.options.home-manager.users.type.getSubOptions []"},
                },
            }},
        }
        write(".vscode/settings.json", vs)
    PYEOF
  ''
```

Implementation notes:
- **Nix `''` string escaping is mandatory**: the script body sits inside a
  Nix `''…''` string. Every literal `${` (the bash `${var}` forms and the
  Python f-string `{{{hostsel}}}` output) must be written as `''${`, and any
  literal `''` as `'''`, or Nix will try to interpolate it. Keep the Python
  code at column 0 inside the string (Nix `''` strings do NOT strip
  indentation) or Python will raise `IndentationError`.
- Keep the script's JSON generation via `python3` — hand-rolled heredoc
  escaping of the nested Nix-in-JSON strings is error-prone.
- If the f-string `${...}` collides with shell expansion inside the Nix
  heredoc, simplify: build the expression strings with `+` concatenation
  instead of f-string interpolation.
- Add the package to the always-on opencode `extraPackages` (or
  `home.packages` in the opencode module) so it is on PATH.
- Add to `overlays/default.nix` like Step 2 if machines need it as
  `pkgs.opencode-nixd-scaffold`.

**Gate 7**:

```bash
nix build .#opencode-nixd-scaffold
mkdir -p /tmp/nix-shell.*/opencode/scaffold-test && cd /tmp/nix-shell.*/opencode/scaffold-test
/nix/store/<result>/bin/opencode-nixd-scaffold --vscode
jq -e .lsp.nixd.initialization.nixd.options.nixos.expr opencode.json
jq -e .nix.serverSettings.nixd.options.nixos.expr .vscode/settings.json
cd /home/netsa/home
```

## Step 8 — VS Code (vscodium) global config

File: `flake-parts/homeModules/vscode.nix`.

1. Replace the whole `nix = { ... }` userSettings block (currently
   `serverPath = "nil"` + `serverSettings.nil`) with:

```nix
nix = {
  enableLanguageServer = true;
  serverPath = "nixd";
  formatterPath = "alejandra";
  serverSettings.nixd = {
    formatting.command = ["alejandra"];
    nixpkgs.expr = "import (builtins.getFlake \"/home/netsa/home\").inputs.nixpkgs { }";
    options.nixos.expr = "NIXOS_OPTS_ABS";
    options.home-manager.expr = "HM_OPTS_ABS";
  };
};
```

2. In `home.packages`, remove `nil`, add `nixd`.
3. The extension `jnoortheen.nix-ide` stays — it drives nixd via
   `nix.serverPath`.

The user-level exprs point at the home flake (safe default for random repos);
per-repo `.vscode/settings.json` (Step 5, scaffolded by Step 7) overrides per
workspace. If `osConfig.networking.hostName` is accessible in this module you
may bake the real hostname instead of the readFile selector — either is fine.

**Gate 8** — `nix eval .#nixosConfigurations.kamrui-h1.config.home-manager.users.netsa.programs.vscodium.profiles.default.userSettings.nix.serverPath`
returns `"nixd"`.

## Step 9 — Headroom memory default flip

1. `flake-parts/homeModules/headroom.nix`: change `proxy.memory` default
   `true` → `false`.
2. `flake-parts/homeModules/profiles/netsa-agent.nix`: remove the now-redundant
   `memory = false;` line, keep `learn = false;`, and shrink the comment to
   one line: `# memory pulls embedding models at startup; blocked offline VMs`.
3. `documentation/docs/headroom/index.md`: update the `proxy.memory` default
   in the options table.

**Gate 9**:

```bash
nix eval .#nixosConfigurations.kamrui-h1.config.home-manager.users.netsa.homeSpec.programs.headroom.proxy.memory
# expect: false
```

Note: the running `headroom-proxy.service` keeps `--memory` until the next
`fh apply` — expected, no action.

## Step 10 — Docs and nav

1. Create `documentation/docs/opencode-upgrade.md` only if a change-log page
   is wanted; otherwise record the change in the existing opencode section of
   `documentation/docs/headroom/index.md` (the module table near
   "flake-parts/homeModules/opencode.nix") — add rows/notes for:
   `enableK8sMcp` (default true), `k8sMcpReadOnly` (default false), nixd LSP
   with per-repo overrides, new K8s toolset packages.
2. Add new files to the file-map table in that doc if present:
   `flake-parts/packages/kubernetes-mcp-server.nix`,
   `flake-parts/packages/opencode-nixd-scaffold.nix`,
   repo-root `opencode.json`, repo-root `.vscode/settings.json`.
3. `documentation/mkdocs.yml`: add a nav entry
   `OpenCode: opencode-upgrade.md` (or the chosen page) if a new page exists.

## Step 11 — Final verification

```bash
cd /home/netsa/home
git add -A
nix fmt .
nix fmt -- --check .           # must exit 0
nix flake check --show-trace   # must pass (same as CI)
nix build .#nixosConfigurations.kamrui-h1.config.system.build.toplevel
```

Post-deploy manual checks (document, don't execute):

```bash
fh apply now home   # or apply-and-reboot
opencode debug config | jq '.lsp.nixd.initialization.nixd.options | keys'
# in an opencode session inside /home/netsa/home: ask the agent to edit a .nix
# file and confirm option completion/diagnostics come from nixd
# in a borg clone: confirm no eval errors and package completion works
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| nixd errors `attribute 'kamrui-h1' missing` in a foreign repo | hostname selector resolved but repo lacks that machine | harmless; only that option worker fails. For full support, run `opencode-nixd-scaffold` in the repo or add its own `opencode.json` |
| nixd logs `workspace/configuration: parse error` | config not nested under `"nixd"` key | fix the `initialization` shape: `initialization.nixd.<config>` |
| Two Nix LSP servers starting | LSP entry keyed `nix` instead of `nixd` (built-in `nixd` still auto-starts) | rename the settings key to `nixd` |
| `readFile /etc/hostname` errors at runtime | only if nixd ever restricts eval (currently it does not: pure-eval defaults false in libnixexpr) | swap hostname selector for `builtins.head (builtins.attrNames ...nixosConfigurations)` in all files |
| `getFlake` fails with `--impure` required | expr eval without flake context | nixd eval workers run with flakes enabled; if testing manually always use `nix eval --expr` from repo root |
| Go build fails on `toolchain` directive | go.mod requires newer Go | add `go = pkgs.go_1_24;` (or newer) to `buildGoModule` |
| `helm_ls` starts but no YAML diagnostics | `yaml-language-server` missing from PATH | confirm it is in `extraPackages` (Step 3b) |
| Project `opencode.json` ignored | opencode started outside the repo / above it | opencode searches cwd upward to the nearest git dir; run from inside the repo |
| Global `env.NIX_PATH` lost in this repo | config merge replaced `lsp.nixd.env` | add the same `env` block to the repo `opencode.json` |

## References

- nixd configuration & `workspace/configuration` shape:
  https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
- flake-parts debug: https://flake.parts/debug
- opencode config cascade: https://opencode.ai/docs/config/
- opencode LSP (initialization options, built-ins): https://opencode.ai/docs/lsp/
- opencode client config lookup:
  `packages/opencode/src/lsp/client.ts` (`configurationValue`)
- opencode LSP spawn cwd: `packages/opencode/src/lsp/lsp.ts`
- kubernetes-mcp-server: https://github.com/containers/kubernetes-mcp-server
- helm-ls (auto-launches yaml-language-server): https://github.com/mrjosh/helm-ls
- Repo conventions: `AGENTS.md` (root)
