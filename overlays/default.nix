{
  inputs,
  self,
}: final: _prev: {
  # add unstable branch of nixpkgs accessable as `pkgs.unstable`
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  clan-cli = inputs.clan-core.packages.${final.stdenv.hostPlatform.system}.clan-cli;
  devenv = inputs.devenv.packages.${final.stdenv.hostPlatform.system}.devenv;

  zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
  moscripts = inputs.moscripts.packages.${final.stdenv.hostPlatform.system}.default;
  kubefetch = inputs.kubefetch.packages.${final.stdenv.hostPlatform.system}.default;

  tfctl = self.packages.${final.stdenv.hostPlatform.system}.tfctl;
  longhornctl = self.packages.${final.stdenv.hostPlatform.system}.longhornctl;

  openshell = self.packages.${final.stdenv.hostPlatform.system}.openshell;
  openshell-gateway = self.packages.${final.stdenv.hostPlatform.system}.openshell-gateway;
  openshell-driver-vm = self.packages.${final.stdenv.hostPlatform.system}.openshell-driver-vm;
  headroom = self.packages.${final.stdenv.hostPlatform.system}.headroom;
  headroom-slim = self.packages.${final.stdenv.hostPlatform.system}.headroom-slim;
  artifacthub-mcp = self.packages.${final.stdenv.hostPlatform.system}.artifacthub-mcp;
  kubernetes-mcp-server = self.packages.${final.stdenv.hostPlatform.system}.kubernetes-mcp-server;

  # AI coding agents from numtide/llm-agents.nix (from-source/bundled
  # builds; binaries: pi, kimi, claude). All sandbox + shell agents come
  # from this flake input so versions track one pin. Taken from the
  # input's own package set, not its overlay, so the numtide binary cache
  # still hits (see the llm-agents input comment in flake.nix).
  kimi-code = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.kimi-code;
  pi-coding-agent = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.pi;
  claude-code = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.claude-code;

  apply-and-reboot = self.packages.${final.stdenv.hostPlatform.system}.apply-and-reboot;
  apply-to-reboot = self.packages.${final.stdenv.hostPlatform.system}.apply-to-reboot;
  apply-now = self.packages.${final.stdenv.hostPlatform.system}.apply-now;
  apply-test = self.packages.${final.stdenv.hostPlatform.system}.apply-test;
  apply-dry-activate = self.packages.${final.stdenv.hostPlatform.system}.apply-dry-activate;
}
