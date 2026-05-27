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
            inputs'.kubefetch.packages.default
            k3s
            clan-cli
            vcluster
            playit
          ]
          ++ (with pkgs.unstable; [
            bash
            bun
            k9s
            fluxcd
            flux9s
            cilium-cli
            kubernetes-helm
            kubectl-cnpg
            kubeseal
            cloudflared
            dive
          ]);
        shellHook = ''
          export REPO_ROOT
          REPO_ROOT=$(git rev-parse --show-toplevel)
          export CLAN_DIR
          CLAN_DIR=$REPO_ROOT

          mkdir -p "$REPO_ROOT"/.secrets/kubeconfig
          eval "$(bunx varlock load --format shell)"

          export KUBECONFIG
          KUBECONFIG=$(find "$REPO_ROOT/.secrets/kubeconfig" -type f 2>/dev/null | paste -sd ":" -)
          kubectl config get-contexts
        '';
      };
    };
}
