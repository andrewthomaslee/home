{...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}:
    with pkgs; {
      packages.longhornctl = stdenv.mkDerivation rec {
        pname = "longhornctl";
        version = "v1.12.0";
        src = fetchurl {
          url = "https://github.com/longhorn/cli/releases/download/${version}/longhornctl-linux-amd64";
          hash = "sha256-HX7w5kTNEYWhEgYDug04nJKjJERQru1eZSdcHFLVwIM=";
        };
        meta = {
          description = "Longhorn CLI is a headless way for preflighting, operating and troubleshooting Longhorn cluster.";
          homepage = "https://github.com/longhorn/cli";
        };
        unpackPhase = "true";
        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/longhornctl
          chmod +x $out/bin/longhornctl
        '';
      };
    };
}
