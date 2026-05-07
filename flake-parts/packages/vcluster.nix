{...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}: {
    packages.vcluster = pkgs.stdenv.mkDerivation rec {
      pname = "vcluster";
      version = "0.34.0";
      src = pkgs.fetchurl {
        url = "https://github.com/loft-sh/vcluster/releases/download/v${version}/vcluster-linux-amd64";
        hash = "sha256-wRWXRktQbEbzSX+isjnJ250DGsRPXSKdo9Co+CMwPCw=";
      };
      meta = {
        description = "vCluster CLI - Create fully functional virtual Kubernetes clusters";
        homepage = "https://www.vcluster.com/";
        mainProgram = "vcluster";
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
