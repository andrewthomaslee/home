{lib, ...}: {
  # netsa-tagged dev machines (nixos, kamrui-h1, ghost): machine-level
  # hostSpec options only. All netsa opencode (MCP/plugin) opt-ins live in
  # the home-manager dev profile (flake-parts/homeModules/profiles/netsa.nix),
  # which the netsa user service applies on exactly these machines.
  #
  # nix-ld: lets prebuilt native binaries (e.g. opencode-mem's
  # onnxruntime-node) run alongside the dev-profile plugins.
  hostSpec.services.nix-ld.enable = true;
}
