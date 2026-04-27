{...}: {
  perSystem = {
    pkgs,
    lib,
    inputs',
    ...
  }: let
    # ------ Common Configuration ------ #
    packages = [
      pkgs.bash
      pkgs.unstable.bun
      pkgs.unstable.fluxcd
      pkgs.unstable.flux9s
      inputs'.clan-core.packages.clan-cli
    ];
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
