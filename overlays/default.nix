{
  inputs,
  self,
}: final: prev: {
  # add unstable branch of nixpkgs accessable as `pkgs.unstable`
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
  moscripts = inputs.moscripts.packages.${final.stdenv.hostPlatform.system}.default;
  clan-cli = inputs.clan-core.packages.${final.stdenv.hostPlatform.system}.clan-cli;
  kubefetch = inputs.kubefetch.packages.${final.stdenv.hostPlatform.system}.default;
}
