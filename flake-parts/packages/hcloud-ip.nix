{...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}:
    with pkgs; {
      packages.hcloud-ip = stdenv.mkDerivation rec {
        pname = "hcloud-ip";
        version = "v0.0.1";
        src = fetchurl {
          url = "https://github.com/FootprintDev/hcloud-ip/releases/download/${version}/hcloud-ip-linux64";
          sha256 = "0dvl3qp4cvx994b5jkl7x99fpn5b1vh1gpbja7cdsixmgjyrgc2r";
        };
        meta = {
          description = "CLI utility to assign a floating IP";
          homepage = "https://github.com/FootprintDev/hcloud-ip";
        };
        unpackPhase = "true";
        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/hcloud-ip
          chmod +x $out/bin/hcloud-ip
        '';
      };
    };
}
