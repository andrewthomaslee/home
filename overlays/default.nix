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

  playit = self.packages.${final.stdenv.hostPlatform.system}.playit;

  k3s = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.k3s_1_35;
  rke2 = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.rke2_1_35;

  vcluster = self.packages.${final.stdenv.hostPlatform.system}.vcluster;
  tfctl = self.packages.${final.stdenv.hostPlatform.system}.tfctl;
  apply-and-reboot = self.packages.${final.stdenv.hostPlatform.system}.apply-and-reboot;
  gamescope = inputs.jovian.packages.${final.stdenv.hostPlatform.system}.gamescope;
}
