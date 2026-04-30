{...}: {
  perSystem = {
    pkgs,
    lib,
    inputs',
    ...
  }: {
    # ------ Default Dev Shell ------ #
    # Activate: `nix develop`
    devShells.default = pkgs.mkShell {
      packages =
        [
          inputs'.clan-core.packages.clan-cli
          inputs'.kubefetch.packages.default
          pkgs.k3s
        ]
        ++ (with pkgs.unstable; [
          bash
          bun
          fluxcd
          flux9s
          cilium-cli
          kubernetes-helm
          kubeseal
          cloudflared
        ]);
      shellHook = ''
        eval "$(bunx varlock load --format shell)"
        export REPO_ROOT
        REPO_ROOT=$(git rev-parse --show-toplevel)
        export CLAN_DIR
        CLAN_DIR=$REPO_ROOT
        export KUBECONFIG
        KUBECONFIG=$(find "$REPO_ROOT/.secrets/kubeconfig" -type f 2>/dev/null | paste -sd ":" -)

        kubectl config get-contexts
      '';
    };
  };
}
