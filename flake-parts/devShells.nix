{inputs, ...}: let
  # See https://github.com/cachix/devenv/issues/1764
  devenvRootFileContent = builtins.readFile inputs.devenv-root.outPath;
  root =
    if devenvRootFileContent != ""
    then devenvRootFileContent
    else "${inputs.devenv-root}";
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    # ------ Common Configuration ------ #
    packages = with pkgs.unstable-devenv; [
      bash
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
    };

    # ------ Devenv Dev Shell ------ #
    # https://devenv.sh/reference/options/
    # Activate: `direnv allow` or `nix develop --no-pure-eval --override-input devenv-root "file+file://$PWD/.devenv/root"`
    devenv.shells.default = {
      inherit packages;
      enterShell = shellHook;
      devenv = {inherit root;};
      languages.nix.enable = true;

      # Commands to run for tests
      enterTest = ''
        bun --version
      '';
    };
  };
}
