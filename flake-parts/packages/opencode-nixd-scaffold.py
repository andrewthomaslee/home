#!/usr/bin/env python3
"""Scaffold per-repo nixd option trees for VS Code.

Run inside any flake repo root:

    opencode-nixd-scaffold [--force] [--vscode]

With --vscode (now the only target), writes `.vscode/settings.json` using
the absolute repo path (VS Code's server cwd is unreliable).

OpenCode used to be scaffolded with an `opencode.json` lsp block; OpenCode
v2 no longer runs language servers, so that output was dropped. The
hostname is resolved inside nixd at eval time via /etc/hostname, so the
generated file is machine-agnostic.
"""

import json
import os
import sys

HOSTSEL = 'builtins.replaceStrings ["\\n"] [""] (builtins.readFile /etc/hostname)'


def nixos_expr(flake):
    return f"(builtins.getFlake {flake}).nixosConfigurations.${{{HOSTSEL}}}.options"


def hm_expr(flake):
    return f"(builtins.getFlake {flake}).nixosConfigurations.${{{HOSTSEL}}}.options.home-manager.users.type.getSubOptions []"


def write(path, data, force):
    if os.path.exists(path) and not force:
        sys.exit(f"{path} exists; refusing (use --force)")
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"wrote {path}")


def main():
    force = False
    for arg in sys.argv[1:]:
        if arg == "--force":
            force = True
        else:
            sys.exit("usage: opencode-nixd-scaffold [--force] [--vscode]")

    root = os.getcwd()
    quoted_root = json.dumps(root)  # Nix-safe double-quoted absolute path

    # Absolute paths: VS Code does not guarantee the language-server
    # process cwd is the workspace root.
    abs_options = {
        "nixos": {"expr": nixos_expr(quoted_root)},
        "home-manager": {"expr": hm_expr(quoted_root)},
    }
    abs_settings = {
        "nix.enableLanguageServer": True,
        "nix.serverPath": "nixd",
        "nix.formatterPath": "alejandra",
        "nix.serverSettings": {
            "nixd": {
                "formatting": {"command": ["alejandra"]},
                "nixpkgs": {
                    "expr": f"import (builtins.getFlake {quoted_root}).inputs.nixpkgs {{ }}"
                },
                "options": abs_options,
            }
        },
    }
    write(".vscode/settings.json", abs_settings, force)


if __name__ == "__main__":
    main()
