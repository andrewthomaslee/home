_: {
  perSystem = {
    self',
    pkgs,
    config,
    ...
  }: {
    packages = {
      devShell = self'.devShells.default;
      agentShell = self'.devShells.agent;

      # The OpenShell sandbox image as a buildable package (CI: nix build
      # .#agent-image). Loading into the host docker store — where the
      # VM driver resolves images first — is `nix run .#load-agent-image`.
      agent-image = config.devenv.shells.agent.containers.shell.derivation;
    };

    apps.load-agent-image = let
      container = config.devenv.shells.agent.containers.shell;
    in {
      type = "app";
      program = builtins.toString (pkgs.writeShellScript "load-agent-image" ''
        set -euo pipefail
        # copy-container <image-spec> <registry>; "docker-daemon:" loads
        # into the local docker store as devenv-agent:latest.
        exec ${container.copyScript} \
          ${container.derivation} docker-daemon:
      '');
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
