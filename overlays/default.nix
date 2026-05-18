{
  inputs,
  self,
}: final: prev: {
  # add unstable branch of nixpkgs accessable as `pkgs.unstable`
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  clan-cli = inputs.clan-core.packages.${final.stdenv.hostPlatform.system}.clan-cli;

  zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
  moscripts = inputs.moscripts.packages.${final.stdenv.hostPlatform.system}.default;
  kubefetch = inputs.kubefetch.packages.${final.stdenv.hostPlatform.system}.default;

  k3s = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.k3s_1_34;

  vcluster = self.packages.${final.stdenv.hostPlatform.system}.vcluster;
  playit = self.packages.${final.stdenv.hostPlatform.system}.playit;

  python314-wrapped = final.writeShellScriptBin "python" ''
    export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
    exec ${prev.python314}/bin/python "$@"
  '';
}
