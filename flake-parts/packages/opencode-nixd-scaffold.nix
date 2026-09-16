{...}: {
  perSystem = {pkgs, ...}: {
    # opencode-nixd-scaffold — scaffolds per-repo nixd overrides for OpenCode
    # (`opencode.json`) and optionally VS Code (`.vscode/settings.json`).
    # Python source lives beside this module so no Nix string escaping of the
    # embedded nixd expressions is needed. Run inside any flake repo root.
    packages.opencode-nixd-scaffold =
      pkgs.writers.writePython3Bin
      "opencode-nixd-scaffold" {
        # Embedded nixd expressions exceed pycodestyle's 79-col limit by design.
        flakeIgnore = ["E501" "W503" "E265"];
      } (builtins.readFile ./opencode-nixd-scaffold.py);
  };
}
