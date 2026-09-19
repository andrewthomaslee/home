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

  k3s = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.k3s_1_35;
  rke2 = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.rke2_1_35;

  # Whisper Dictation — speech-to-text (vulkan variant uses the GPU via RADV)
  whisper-dictation = inputs.whisper-dictation.packages.${final.stdenv.hostPlatform.system}.default;
  whisper-dictation-vulkan = inputs.whisper-dictation.packages.${final.stdenv.hostPlatform.system}.whisper-dictation-vulkan;

  tfctl = self.packages.${final.stdenv.hostPlatform.system}.tfctl;
  longhornctl = self.packages.${final.stdenv.hostPlatform.system}.longhornctl;
  vcluster = self.packages.${final.stdenv.hostPlatform.system}.vcluster;
  splashtop-streamer = self.packages.${final.stdenv.hostPlatform.system}.splashtop-streamer;
  headroom = self.packages.${final.stdenv.hostPlatform.system}.headroom;
  headroom-slim = self.packages.${final.stdenv.hostPlatform.system}.headroom-slim;
  artifacthub-mcp = self.packages.${final.stdenv.hostPlatform.system}.artifacthub-mcp;
  kubernetes-mcp-server = self.packages.${final.stdenv.hostPlatform.system}.kubernetes-mcp-server;
  opencode-nixd-scaffold = self.packages.${final.stdenv.hostPlatform.system}.opencode-nixd-scaffold;
  # OpenCode plugins (hermetic builds; entries referenced by store path).
  cc-safety-net = self.packages.${final.stdenv.hostPlatform.system}.cc-safety-net;
  opencode-morph-fast-apply = self.packages.${final.stdenv.hostPlatform.system}.opencode-morph-fast-apply;
  opencode-mem = self.packages.${final.stdenv.hostPlatform.system}.opencode-mem;
  opencode-devcontainers = self.packages.${final.stdenv.hostPlatform.system}.opencode-devcontainers;

  apply-and-reboot = self.packages.${final.stdenv.hostPlatform.system}.apply-and-reboot;
  apply-to-reboot = self.packages.${final.stdenv.hostPlatform.system}.apply-to-reboot;
  apply-now = self.packages.${final.stdenv.hostPlatform.system}.apply-now;
  apply-test = self.packages.${final.stdenv.hostPlatform.system}.apply-test;
  apply-dry-activate = self.packages.${final.stdenv.hostPlatform.system}.apply-dry-activate;
}
