_: {
  perSystem = {self', ...}: {
    packages.devShell = self'.devShells.default;
    # ------ Default Dev Shell ------ #
    # Activate: `devenv shell` (CLI mode, full features) or `nix develop`
    # (flake mode, CI/flake consumers). Both evaluate the same shared
    # module in devenv/default.nix. The devenv flakeModule maps
    # devenv.shells.<name> to devShells.<name> automatically.
    devenv.shells.default = {
      imports = [../devenv];
    };
  };
}
