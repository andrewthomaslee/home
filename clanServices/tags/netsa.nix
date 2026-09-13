{lib, ...}: {
  # netsa-tagged dev machines: GitHub MCP uses the clan-var PAT method.
  # The "github-mcp" generator + sops deployment is derived automatically
  # by nixosModules/github-mcp from this setting (only while opencode is
  # enabled for netsa). Provision the secret with:
  #   clan vars set github-mcp pat <machine>
  home-manager.users.netsa.homeSpec.programs.opencode.githubMcpAuth = lib.mkDefault "pat";
}
