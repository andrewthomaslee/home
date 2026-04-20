{inputs, ...}: let
  # See https://github.com/cachix/devenv/issues/1764
  devenvRootFileContent = builtins.readFile inputs.devenv-root.outPath;
  root =
    if devenvRootFileContent != ""
    then devenvRootFileContent
    else "${inputs.devenv-root}";
in {
  perSystem = {pkgs, ...}: let
    # ------ Common Configuration ------ #
    packages = with pkgs.unstable-devenv; [
      bun
    ];
    shellHook = ''
      export REPO_ROOT
      REPO_ROOT=$(git rev-parse --show-toplevel)
      eval "$(bunx varlock load --format shell)"
    '';
  in {
    # ------ Pure Dev Shell ------ #
    # Activate: `nix develop .#pure`
    devShells.pure = pkgs.mkShell {
      inherit shellHook packages;
      buildInputs = with pkgs.unstable-devenv; [
        bashInteractive
        bash
      ];
    };

    # ------ Devenv Dev Shell ------ #
    # https://devenv.sh/reference/options/
    # Activate: `direnv allow` or `nix develop --no-pure-eval --override-input devenv-root "file+file://$PWD/.devenv/root"`
    devenv.shells.default = {
      inherit packages;
      enterShell = shellHook;
      devenv = {inherit root;};
      devcontainer = {
        enable = true;
        settings = {
          updateContentCommand = "";
          postCreateCommand = "git config --global --add safe.directory /workspaces/home";
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
