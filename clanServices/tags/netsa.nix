{lib, ...}: {
  # netsa-tagged dev machines: GitHub MCP uses the clan-var PAT method, and
  # the Cloudflare remote MCP servers are enabled (off by default elsewhere).
  # The "github-mcp" generator + sops deployment is derived automatically
  # by nixosModules/github-mcp from githubMcpAuth (only while opencode is
  # enabled for netsa). Provision the secret with:
  #   clan vars set github-mcp pat <machine>
  home-manager.users.netsa.homeSpec.programs.opencode = {
    githubMcpAuth = lib.mkDefault "pat";
    # Cloudflare MCP servers: on for netsa dev machines
    enableCloudflareMcp = lib.mkDefault true;
    enableCloudflareDocsMcp = lib.mkDefault true;
    enableCloudflareBindingsMcp = lib.mkDefault true;
    enableCloudflareBuildsMcp = lib.mkDefault true;
    enableCloudflareBrowserMcp = lib.mkDefault true;
    enableCloudflareContainersMcp = lib.mkDefault true;
    # MDN Web Docs MCP: on for netsa dev machines
    enableMdnMcp = lib.mkDefault true;
  };
}
