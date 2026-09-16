{lib, ...}: {
  # netsa-tagged dev machines: GitHub MCP uses the clan-var PAT method, and
  # the Cloudflare remote MCP servers are enabled (off by default elsewhere).
  # The "github-mcp" generator + sops deployment is derived automatically
  # by nixosModules/github-mcp from githubMcpAuth (only while opencode is
  # enabled for netsa). Provision the secret with:
  #   clan vars set github-mcp pat <machine>
  # nix-ld for the netsa dev machines (nixos, kamrui-h1, ghost): lets
  # prebuilt native binaries (e.g. opencode-mem's onnxruntime-node) run.
  hostSpec.services.nix-ld.enable = true;

  home-manager.users.netsa.homeSpec.programs.opencode = {
    mcp.github.auth = lib.mkDefault "pat";
    # Cloudflare MCP servers: on for netsa dev machines
    mcp.cloudflare.enable = lib.mkDefault true;
    mcp."cloudflare-docs".enable = lib.mkDefault true;
    mcp."cloudflare-bindings".enable = lib.mkDefault true;
    mcp."cloudflare-builds".enable = lib.mkDefault true;
    mcp."cloudflare-browser".enable = lib.mkDefault true;
    mcp."cloudflare-containers".enable = lib.mkDefault true;
    # MDN Web Docs MCP: on for netsa dev machines
    mcp.mdn.enable = lib.mkDefault true;
    # ArtifactHub MCP (Helm charts): on for netsa dev machines
    mcp.artifacthub.enable = lib.mkDefault true;
  };
}
