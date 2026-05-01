{
  inputs,
  self,
}: final: prev: {
  # add unstable branch of nixpkgs accessable as `pkgs.unstable`
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  k3s = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.k3s;
}
