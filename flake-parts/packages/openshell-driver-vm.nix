_: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }:
    with pkgs; {
      packages.openshell-driver-vm = stdenv.mkDerivation rec {
        pname = "openshell-driver-vm";
        version = "0.1.2";

        # Prebuilt release binary. The release build embeds the full VM
        # runtime (libkrun/libkrunfw, guest openshell-sandbox, host
        # supervisor, guest init, umoci) via build.rs
        # OPENSHELL_VM_RUNTIME_COMPRESSED_DIR, so this single binary is
        # self-contained — no OPENSHELL_VM_RUNTIME_DIR is needed for the
        # default libkrun backend. The embedded host supervisor is a gnu
        # binary extracted to the driver's state dir at runtime, which is
        # why the consuming service requires programs.nix-ld.
        src = fetchurl {
          url = "https://github.com/NVIDIA/OpenShell/releases/download/v${version}/openshell-driver-vm-x86_64-unknown-linux-gnu.tar.gz";
          hash = "sha256-BC4tWntaHz0RLvNGxFoRPzMcLjnJBkTT1QAYIKKpqhI=";
        };

        sourceRoot = ".";

        nativeBuildInputs = [
          autoPatchelfHook
          gzip
          makeWrapper
        ];

        buildInputs = [
          stdenv.cc.cc.lib
          zlib
        ];

        # The runtime-extracted embedded libkrun is dlopen'd from the
        # driver's state dir; its transitive deps (not linked by the driver
        # binary itself, so autoPatchelf misses them) resolve through
        # LD_LIBRARY_PATH.
        runtimeLibs = with pkgs; [
          libcap_ng
          libseccomp
          numactl
          openssl
        ];

        # e2fsprogs (mke2fs/debugfs) is needed host-side to create the
        # bootstrap/overlay ext4 disks; umoci and the rest are embedded.
        propagatedBuildInputs = [e2fsprogs];

        installPhase = ''
          runHook preInstall
          install -Dm755 openshell-driver-vm $out/libexec/openshell/openshell-driver-vm
          mkdir -p $out/bin
          # Conventional lookup location for a gateway-spawned driver.
          ln -s $out/libexec/openshell/openshell-driver-vm $out/bin/openshell-driver-vm
          runHook postInstall
        '';

        postFixup = ''
          wrapProgram $out/libexec/openshell/openshell-driver-vm \
            --prefix PATH : ${lib.makeBinPath [e2fsprogs]} \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
        '';

        doInstallCheck = true;
        installCheckPhase = ''
          $out/bin/openshell-driver-vm --version | grep -q '${version}'
        '';

        meta = {
          description = "NVIDIA OpenShell VM (libkrun) compute driver (prebuilt release binary)";
          homepage = "https://github.com/NVIDIA/OpenShell";
          license = lib.licenses.asl20;
          mainProgram = "openshell-driver-vm";
          platforms = [system];
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
}
