_: {
  perSystem = {pkgs, ...}: {
    # opencode-nixd-scaffold — scaffolds per-repo nixd option trees for VS
    # Code (`.vscode/settings.json`). Python source lives beside this module
    # so no Nix string escaping of the embedded nixd expressions is needed.
    # Run inside any flake repo root. (The former `opencode.json` lsp output
    # was dropped: OpenCode v2 no longer runs language servers.)
    packages.opencode-nixd-scaffold =
      pkgs.writers.writePython3Bin
      "opencode-nixd-scaffold" {
        # Embedded nixd expressions exceed pycodestyle's 79-col limit by design.
        flakeIgnore = ["E501" "W503" "E265"];
      } (builtins.readFile ./opencode-nixd-scaffold.py);
  };
}
