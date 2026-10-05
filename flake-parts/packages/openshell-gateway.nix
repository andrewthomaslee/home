_: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }:
    with pkgs; {
      packages.openshell-gateway = stdenv.mkDerivation rec {
        pname = "openshell-gateway";
        version = "0.1.2";

        # Prebuilt release binary (x86_64-unknown-linux-gnu). Same version as
        # the `openshell` CLI built from inputs.openshell.
        src = fetchurl {
          url = "https://github.com/NVIDIA/OpenShell/releases/download/v${version}/openshell-gateway-x86_64-unknown-linux-gnu.tar.gz";
          hash = "sha256-IY2IeEWzoCCrdTXJmF65xmbWk48UQESVf4uCtCiSqts=";
        };

        sourceRoot = ".";

        nativeBuildInputs = [
          autoPatchelfHook
          gzip
        ];

        buildInputs = [
          stdenv.cc.cc.lib
          zlib
        ];

        installPhase = ''
          runHook preInstall
          install -Dm755 openshell-gateway -t $out/bin
          runHook postInstall
        '';

        doInstallCheck = true;
        installCheckPhase = ''
          $out/bin/openshell-gateway --version | grep -q '${version}'
        '';

        meta = {
          description = "NVIDIA OpenShell gateway (prebuilt release binary)";
          homepage = "https://github.com/NVIDIA/OpenShell";
          license = lib.licenses.asl20;
          mainProgram = "openshell-gateway";
          platforms = [system];
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
}
