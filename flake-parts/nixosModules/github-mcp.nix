{lib, ...}: {
  # ------ NixOS Modules ------ #
  # Self-configuring GitHub MCP support. All user-facing options live under
  # homeSpec.programs.opencode (homeModules/opencode.nix) — this module has
  # none of its own. For every home-manager user whose opencode config has
  # mcp.github.enable + mcp.github.auth = "pat", it declares the clan vars
  # generator provisioning the PAT; sops-nix deploys it to
  #   /run/secrets/vars/shared/github-mcp/pat
  # (owner = user, mode 0400, neededFor = services), where the opencode
  # wrapper picks it up at MCP server start.
  #
  # Provisioning (interactive, no fake values in the repo):
  #   clan vars set github-mcp pat <machine>   (or: clan vars generate)
  #
  # NOTE: this scan mirrors the option paths in homeModules/opencode.nix by
  # hand (defensive `or` access to avoid fixpoint recursion). If you rename
  # or restructure those options, update BOTH places — a stale scan
  # silently stops declaring the generator (regression seen when the flat
  # githubMcpAuth option was renamed to mcp.github.auth).
  #
  # NOTE: assumes at most one pat-mode user per machine (shared generator);
  # conflicting owners would fail the merge at eval time.
  flake.nixosModules.github-mcp = {
    config,
    lib,
    ...
  }: {
    # Read-only scan of home-manager.users (attrsOf hmModule submodule —
    # merged option values, mkIf flattened). The module never writes to
    # home-manager.users, so no fixpoint recursion is possible.
    config.clan.core.vars.generators = lib.mkMerge (
      lib.mapAttrsToList
      (
        userName: hmUser: let
          oc = hmUser.homeSpec.programs.opencode or null;
          gh =
            if oc != null
            then (oc.mcp or {}).github or {}
            else {};
        in
          lib.mkIf
          (
            oc
            != null
            && (oc.enable or false)
            && (gh.enable or false)
            && ((gh.auth or "oauth") == "pat")
          )
          {
            "github-mcp" = {
              share = true;
              prompts.pat = {
                persist = true;
                type = "hidden";
                description = "GitHub Personal Access Token for github-mcp-server";
              };
              files.pat = {
                owner = userName;
                mode = "0400";
                neededFor = "services";
              };
            };
          }
      )
      config.home-manager.users
    );
  };
}
