{...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}: {
    packages.tfctl = pkgs.stdenv.mkDerivation rec {
      pname = "tfctl";
      version = "0.16.3";
      src = pkgs.fetchurl {
        url = "https://github.com/flux-iac/tofu-controller/releases/download/v${version}/tfctl_Linux_amd64.tar.gz";
        hash = "sha256-7Y8TnA8G12YThdl69hmEbLvZg1OMjj1wvtIm5WixSwM=";
      };
      meta = {
        description = "tfctl CLI - A GitOps OpenTofu and Terraform controller for Flux ";
        homepage = "https://github.com/flux-iac/tofu-controller";
        mainProgram = "tfctl";
      };
      unpackPhase = ''
        tar xf $src
      '';
      installPhase = ''
        mkdir -p $out/bin
        cp tfctl $out/bin/tfctl
        chmod +x $out/bin/tfctl
      '';
    };
  };
}
