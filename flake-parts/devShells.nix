{...}: {
  perSystem = {
    pkgs,
    lib,
    inputs',
    self',
    ...
  }:
    with pkgs; {
      packages.devShell = self'.devShells.default;
      # ------ Default Dev Shell ------ #
      # Activate: `nix develop`
      devShells.default = mkShell {
        packages =
          [
            clan-cli
          ]
          ++ (with unstable; [
            bash
            bun
            disko
          ]);
        shellHook = ''
          export REPO_ROOT
          REPO_ROOT=$(git rev-parse --show-toplevel)
          export CLAN_DIR
          CLAN_DIR=$REPO_ROOT
          eval "$(bunx varlock load --format shell)"
        '';
      };
    };
}
