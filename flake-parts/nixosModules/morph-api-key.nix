_: {
  # ------ NixOS Modules ------ #
  # Self-configuring Morph Fast Apply API key provisioning, mirroring
  # nixosModules/github-mcp. For every home-manager user whose opencode
  # config has plugins."morph-fast-apply".enable, it declares the clan
  # vars generator provisioning the key; sops-nix deploys it to
  #   /run/secrets/vars/shared/morph-api-key/api-key
  # (owner = user, mode 0400, neededFor = services), where the opencode
  # wrapper (homeModules/opencode) exports it as MORPH_API_KEY.
  #
  # The opencode module sets the canonical apiKeyFile default only when
  # the morph plugin is enabled, so the generator stays inert until the
  # plugin is turned on.
  #
  # Provisioning (interactive, no fake values in the repo):
  #   clan vars set morph-api-key api-key <machine>   (or: clan vars generate)
  flake.nixosModules.morph-api-key = {
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
        in
          lib.mkIf
          (
            oc
            != null
            && (oc.enable or false)
            && ((oc.plugins or {})."morph-fast-apply" or {}).enable or false
          )
          {
            "morph-api-key" = {
              share = true;
              prompts.api-key = {
                persist = true;
                type = "hidden";
                description = "Morph Fast Apply API key (morphllm.com)";
              };
              files.api-key = {
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
