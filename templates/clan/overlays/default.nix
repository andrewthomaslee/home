{
  inputs,
  self,
  ...
}: final: prev: {
  # add devenv branch of nixpkgs accessable as `pkgs.unstable-devenv`
  unstable-devenv = import inputs.nixpkgs-devenv {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
}
