{lib, ...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.github-mcp = {
    config,
    lib,
    ...
  }: let
    cfg = config.hostSpec.programs.githubMcp;
  in {
    options.hostSpec.programs.githubMcp = {
      enable = lib.mkEnableOption "GitHub MCP server for opencode";
      # User that runs opencode and owns the deployed PAT secret file.
      user = lib.mkOption {
        type = lib.types.str;
        default = "netsa";
        description = "User account that runs opencode and owns the GitHub PAT secret.";
      };
      # Auth method for the GitHub MCP server (mutually exclusive, enforced
      # by homeSpec.programs.opencode assertions):
      #   oauth: remote hosted server (https://api.githubcopilot.com/mcp/);
      #          opencode runs the browser OAuth flow on first use.
      #   pat:   local stdio server reading the clan-var-deployed PAT file.
      auth = lib.mkOption {
        type = lib.types.enum ["oauth" "pat"];
        default = "oauth";
        description = "GitHub MCP authentication method (oauth remote server or clan-var PAT file).";
      };
    };

    config = lib.mkIf cfg.enable {
      # Static-ish guard: the wiring below targets home-manager.users.${cfg.user},
      # which requires the user to exist. Checked via assertions (NOT via a
      # mkIf condition on config.users.users — that would recurse, since
      # home-manager useUserPackages feeds back into users.users).
      assertions = [
        {
          assertion = config.users.users ? ${cfg.user};
          message = "hostSpec.programs.githubMcp: user '${cfg.user}' does not exist on this machine — create it or point hostSpec.programs.githubMcp.user at an existing user.";
        }
      ];

      # Provision the clan var generator only for the PAT method — the
      # oauth method needs no secret at all. Provisioning (interactive):
      #   clan vars set github-mcp pat <machine>   (or: clan vars generate)
      # sops-nix then deploys it (owner = cfg.user, mode 0400) to:
      #   /run/secrets/vars/shared/github-mcp/pat
      clan.core.vars.generators."github-mcp" = lib.mkIf (cfg.auth == "pat") {
        share = true;
        prompts.pat = {
          persist = true;
          type = "hidden";
          description = "GitHub Personal Access Token for github-mcp-server";
        };
        files.pat = {
          owner = cfg.user;
          mode = "0400";
          neededFor = "services";
        };
      };

      home-manager.users.${cfg.user}.homeSpec.programs.opencode =
        {
          enableGithubMcp = true;
          githubMcpAuth = cfg.auth;
        }
        // (lib.optionalAttrs (cfg.auth == "pat") {
          # sops-nix deploys secret "vars/<rel_dir>/<file>" to
          # /run/secrets/<secret-name> (sops-nix default path).
          githubPatFile = "/run/secrets/vars/shared/github-mcp/pat";
        });
    };
  };
}
