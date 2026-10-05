_: {
  perSystem = {self', ...}: {
    packages = {
      devShell = self'.devShells.default;
      agentShell = self'.devShells.agent;
    };

    devenv.shells = {
      # ------ Default Dev Shell ------ #
      # Activate: `devenv shell` (CLI mode, full features) or `nix develop`
      # (flake mode, CI/flake consumers). Both evaluate the same shared
      # module in devenv/default.nix. The devenv flakeModule maps
      # devenv.shells.<name> to devShells.<name> automatically.
      default = {
        imports = [../devenv];
      };
      # Agent sandbox variant, entered with `nix develop .#agent`. Shares the
      # generic image (containers.shell.copyToRoot is forced empty in the
      # shared module) and layers the agent-runtime module on top.
      agent = {
        imports = [../devenv ../devenv/agent.nix];
      };
    };
  };
}
