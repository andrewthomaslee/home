{...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}:
    with pkgs; let
      source = stdenv.mkDerivation {
        name = "helm-cnpg";
        src = fetchTarball {
          url = "https://github.com/cloudnative-pg/charts/releases/download/cloudnative-pg-v0.28.2/cloudnative-pg-0.28.2.tgz";
          sha256 = "sha256:0ik5vp3c9cfvh4a0141hxz84yj26g40vl8d6zsrwsvbx8q04hqpg";
        };
        installPhase = ''
          mkdir -p $out
          cp -a $src/. $out/
        '';
      };
    in {
      # oci container for cnpg helm chart
      packages.oci-cnpg = dockerTools.buildImage {
        name = "home/oci/helm/cnpg";
        copyToRoot = [source];
      };
    };
}
