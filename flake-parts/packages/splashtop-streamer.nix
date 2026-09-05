{inputs, ...}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }:
    with pkgs; {
      packages.splashtop-streamer = stdenv.mkDerivation {
        pname = "splashtop-streamer";
        version = "3.8.2.0";

        src = inputs.splashtop-streamer;

        nativeBuildInputs = [
          dpkg
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = [
          gtk3
          glib
          gdk-pixbuf
          cairo
          pango
          libnotify
          pulseaudio
          opus
          fuse
          libproxy
          linux-pam
          systemd
          libuuid
          zlib
          libxcb
          xcbutilkeysyms
          wayland
          pipewire
          webkitgtk_4_1
        ];

        sourceRoot = ".";

        unpackPhase = ''
          runHook preUnpack
          dpkg-deb -x $src/Splashtop_Streamer_Ubuntu_amd64.deb streamer-root
          runHook postUnpack
        '';

        preFixup = ''
          addAutoPatchelfSearchPath $out/opt/splashtop-streamer
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out/opt $out/bin $out/share
          cp -r streamer-root/opt/splashtop-streamer $out/opt/
          cp -r streamer-root/usr/share/. $out/share/

          substituteInPlace $out/opt/splashtop-streamer/script/splashtop-streamer \
            --replace 'SPT_SCR_DIR="$(dirname "$(readlink -e "$0")")"' 'SPT_SCR_DIR="$(dirname "$0")"'

          cat > $out/bin/.splashtop-streamer-chooser <<EOF
          #!${bash}/bin/bash
          if [ -x /opt/splashtop-streamer/script/splashtop-streamer ]; then
            exec /opt/splashtop-streamer/script/splashtop-streamer "\$@"
          fi
          SELF="\$(readlink -f "\$0")"
          exec "\$(dirname "\$SELF")/../opt/splashtop-streamer/script/splashtop-streamer" "\$@"
          EOF
          chmod +x $out/bin/.splashtop-streamer-chooser
          makeWrapper $out/bin/.splashtop-streamer-chooser $out/bin/splashtop-streamer \
            --prefix LD_LIBRARY_PATH : ${webkitgtk_4_1.out}/lib \
            --prefix PATH : ${
            lib.makeBinPath [
              bash
              coreutils
              gnugrep
              gnused
              gawk
              util-linux
              procps
              curl
              systemd
              zip
              lshw
              xrandr
              xinput
              pulseaudio
            ]
          }

          cat > $out/bin/.splashtop-utility-chooser <<EOF
          #!${bash}/bin/bash
          if [ -x /opt/splashtop-streamer/SRUtility ]; then
            exec /opt/splashtop-streamer/SRUtility "\$@"
          fi
          SELF="\$(readlink -f "\$0")"
          cd "\$(mktemp -d)"
          exec "\$(dirname "\$SELF")/../opt/splashtop-streamer/SRUtility" "\$@"
          EOF
          chmod +x $out/bin/.splashtop-utility-chooser
          makeWrapper $out/bin/.splashtop-utility-chooser $out/bin/splashtop-streamer-utility \
            --prefix PATH : ${
            lib.makeBinPath [
              bash
              coreutils
              gnugrep
              gnused
              gawk
              util-linux
              curl
              systemd
            ]
          }
          runHook postInstall
        '';

        meta = with lib; {
          description = "Splashtop Remote Streamer — remotely access your desktop from any device, anywhere";
          homepage = "https://www.splashtop.com/";
          license = licenses.unfree;
          platforms = ["x86_64-linux"];
          sourceProvenance = with sourceTypes; [binaryNativeCode];
        };
      };
    };
}
