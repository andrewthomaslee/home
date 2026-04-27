{...}: {
  perSystem = {
    pkgs,
    lib,
    inputs',
    ...
  }: let
    # ------ Common Configuration ------ #
    packages =
      [
        inputs'.clan-core.packages.clan-cli
      ]
      ++ (with pkgs.unstable; [
        bash
        bun
        fluxcd
        flux9s
      ]);
    shellHook = ''
      export REPO_ROOT
      REPO_ROOT=$(git rev-parse --show-toplevel)
      export CLAN_DIR
      CLAN_DIR=$REPO_ROOT
      eval "$(bunx varlock load --format shell)"
    '';
  in {
    # ------ Pure Dev Shell ------ #
    # Activate: `nix develop .#default`
    devShells.default = pkgs.mkShell {
      inherit shellHook packages;
    };
  };
}
