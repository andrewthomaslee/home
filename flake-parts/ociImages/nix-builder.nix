_: {
  # ------ Per-System ------ #
  # OCI image for OpenShell sandboxes that run `nix build` on flake
  # projects. See pi-agent.nix for the image-delivery story (local docker
  # store first, registry fallback) and openshell/policies/nix-build.yaml
  # for the matching network policy (cache.nixos.org + GitHub fetch hosts).
  perSystem = {pkgs, ...}: {
    packages.nix-builder-image = pkgs.dockerTools.buildLayeredImage {
      name = "nix-builder";
      tag = "latest";

      contents = with pkgs; [
        nix
        git
        gh
        curl
        cacert
        gnutar
        gzip
        xz
        bashInteractive
        coreutils
      ];

      fakeRootCommands = ''
        # Owned 1000:1000: USER-less images run as UID/GID 1000 and the
        # nix-build policy grants /nix and the workdir to that identity.
        mkdir -p sandbox
        chown 1000:1000 sandbox
      '';

      config = {
        Env = [
          "NIX_CONFIG=experimental-features = nix-command flakes"
        ];
        WorkingDir = "/sandbox";
      };
    };
  };
}
