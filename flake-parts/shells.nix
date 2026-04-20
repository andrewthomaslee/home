{inputs, ...}: let
  # See https://github.com/cachix/devenv/issues/1764
  devenvRootFileContent = builtins.readFile inputs.devenv-root.outPath;
  root =
    if devenvRootFileContent != ""
    then devenvRootFileContent
    else "${inputs.devenv-root}";
in {
  perSystem = {pkgs, ...}: let
    # --- Common Configuration --- #
    packages = with pkgs.unstable; [
      alejandra
      bun
    ];
    shellHook = ''
      export REPO_ROOT
      REPO_ROOT=$(git rev-parse --show-toplevel)
      eval "$(bunx varlock load --format shell)"
    '';
  in {
    # Pure Dev Shell
    # Activate: `nix develop .#pure`
    devShells.pure = pkgs.mkShell {
      inherit shellHook packages;
      buildInputs = with pkgs; [
        bashInteractive
        bash
      ];
    };

    # Devenv Development Shell
    # Activate: `direnv allow`
    # https://devenv.sh/reference/options/
    devenv.shells.default = {
      inherit packages;
      enterShell = shellHook;
      devenv = {inherit root;};
      devcontainer = {
        enable = true;
        settings = {
          updateContentCommand = "";
          customizations.vscode.extensions = [
            "mkhl.direnv"
            "jnoortheen.nix-ide"
          ];
        };
      };

      # Commands to run for tests
      enterTest = ''
        bun --version
      '';
    };
  };
}
