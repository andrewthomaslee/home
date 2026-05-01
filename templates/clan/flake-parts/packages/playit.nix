{...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}: {
    packages.playit = pkgs.stdenv.mkDerivation {
      pname = "playit";
      version = "0.17.1";
      src = pkgs.fetchurl {
        url = "https://github.com/playit-cloud/playit-agent/releases/download/v0.17.1/playit-linux-amd64";
        hash = "sha256-541GPZOqHj7Dagbe1aH0/oeZBf3OuGXfj0zvYST4pVU=";
      };
      meta = {
        description = "playit.gg is a global proxy that allows anyone to host a server without port forwarding. We use tunneling. Only the server needs to run the program, not every player!";
        homepage = "https://playit.gg";
      };
      unpackPhase = "true";
      installPhase = ''
        mkdir -p $out/bin
        cp $src $out/bin/playit
        chmod +x $out/bin/playit
      '';
    };
  };
}
