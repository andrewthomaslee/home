{
  inputs,
  self,
  ...
}: final: prev: {
  # add unstalble branch of nixpkgs accessable as `pkgs.unstable`
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  # add devenv branch of nixpkgs accessable as `pkgs.unstable-devenv`
  unstable-devenv = import inputs.nixpkgs-devenv {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  # add clan branch of nixpkgs accessable as `pkgs.unstable-clan`
  unstable-clan = import inputs.nixpkgs-clan {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
}
