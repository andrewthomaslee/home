{...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}:
    with pkgs; {
      packages.vcluster = stdenv.mkDerivation rec {
        pname = "vcluster";
        version = "v0.36.1";
        src = fetchurl {
          url = "https://github.com/loft-sh/vcluster/releases/download/${version}/vcluster-linux-arm64";
          hash = "sha256-Qsl3qRszqfkwEH0yvVjQVBai8JtoHXB3PKScCEjdIVI=";
        };
        meta = {
          description = "vCluster - Create fully functional virtual Kubernetes clusters - Each vcluster runs inside a namespace of the underlying k8s cluster. It's cheaper than creating separate full-blown clusters and it offers better multi-tenancy and isolation than regular namespaces.";
          homepage = "www.vcluster.com";
        };
        unpackPhase = "true";
        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/vcluster
          chmod +x $out/bin/vcluster
        '';
      };
    };
}
