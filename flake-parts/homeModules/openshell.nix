_: {
  # ------ Home-manager Modules ------ #
  # NVIDIA OpenShell CLI user environment: installs the CLI, wires the
  # gateway endpoint/policy into the shell session, and renders the pure
  # config files the CLI (and a user-run gateway) reads from XDG config.
  #
  # OpenShell v0.1.2 layout (crates/openshell-bootstrap/src/paths.rs):
  #   $XDG_CONFIG_HOME/openshell/gateway.toml     gateway server config
  #   $XDG_CONFIG_HOME/openshell/active_gateway   active gateway name
  #   $XDG_CONFIG_HOME/openshell/gateways/<name>/ gateway registry (CLI-managed)
  # Only pure files are written declaratively. The registry, mTLS material
  # and OIDC tokens are mutable CLI state (plain fs::write, 0600) and are
  # deliberately left to `openshell gateway add`/`login`.
  # `lib` is taken from the home-manager module eval (extended with
  # `lib.hm.dag`) rather than the outer flake-parts scope.
  flake.homeModules.openshell = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.homeSpec.programs.openshell;

    tomlFormat = pkgs.formats.toml {};
    yamlFormat = pkgs.formats.yaml {};

    # gateway.toml is read by the gateway when --config /
    # OPENSHELL_GATEWAY_CONFIG are unset. Schema v2 requires an
    # [openshell] version; an empty file is rejected, so the minimum is
    # merged with whatever the user sets under settings.
    gatewayConfig =
      tomlFormat.generate "openshell-gateway.toml"
      (lib.recursiveUpdate {openshell.version = 2;} cfg.settings);

    # Sandbox policy is passed with --policy or, when unset, taken from
    # OPENSHELL_SANDBOX_POLICY (openshell-cli --policy help). The env var
    # carries an absolute path because home-manager shell-escapes session
    # variable values (lib.escapeShellArg), so "$HOME/..." would not expand.
    policyFile =
      if cfg.sandboxPolicy == null
      then null
      else yamlFormat.generate "openshell-policy.yaml" cfg.sandboxPolicy;
    policyPath =
      if policyFile == null
      then null
      else "${config.xdg.configHome}/openshell/policy.yaml";

    # `gateway add` errors when the gateway already exists (User source),
    # so the activation is gated on the metadata file the command writes.
    register = cfg.gateway.register && cfg.enable;
  in {
    options.homeSpec.programs.openshell = {
      enable = lib.mkEnableOption "the NVIDIA OpenShell CLI user environment";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.openshell;
        description = "OpenShell CLI package to install (pkgs.openshell from the repo overlay).";
      };

      gateway = {
        name = lib.mkOption {
          type = lib.types.str;
          default = "openshell";
          description = "Gateway alias, written to OPENSHELL_GATEWAY and used as the registration name.";
        };
        endpoint = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:17670";
          description = "Gateway endpoint URL, written to OPENSHELL_GATEWAY_ENDPOINT. 17670 is the gateway's built-in default listener (DEFAULT_SERVER_PORT).";
        };
        insecure = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Skip TLS certificate verification (OPENSHELL_GATEWAY_INSECURE).";
        };
        register = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Register the gateway via home.activation on activation. Idempotent: skipped once gateway metadata exists. The command also selects the gateway as active.";
        };
      };

      settings = lib.mkOption {
        type = lib.types.submodule {freeformType = tomlFormat.type;};
        default = {};
        description = ''
          Gateway configuration rendered to $XDG_CONFIG_HOME/openshell/gateway.toml.
          Free-form: any key is accepted and merged under the schema-v2 default
          ([openshell] version = 2). Only affects a gateway that reads this file
          (--config / OPENSHELL_GATEWAY_CONFIG unset); NixOS-managed gateways use
          their own /etc/openshell/gateway.toml.
        '';
      };

      sandboxPolicy = lib.mkOption {
        type = with lib.types; nullOr (submodule {freeformType = yamlFormat.type;});
        default = {
          version = 1;
          filesystem_policy = {
            include_workdir = true;
            # Nix puts every runtime dependency in /nix/store; without it a
            # sandboxed agent cannot execute anything.
            read_only = [
              "/bin"
              "/usr"
              "/lib"
              "/lib64"
              "/etc"
              "/proc"
              "/nix"
              "/nix/store"
              "/dev/urandom"
            ];
            read_write = [
              "/sandbox"
              "/tmp"
              "/home"
              "/env"
              "/dev/null"
            ];
          };
          landlock.compatibility = "best_effort";
        };
        description = ''
          Sandbox policy rendered to $XDG_CONFIG_HOME/openshell/policy.yaml and
          exported as OPENSHELL_SANDBOX_POLICY (the default for
          `openshell sandbox create --policy`). Set to null to write no policy
          and export no variable.
        '';
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Extra environment variables for the shell session.";
      };
    };

    config = lib.mkIf cfg.enable {
      home = {
        packages = [cfg.package];

        sessionVariables = lib.mkMerge [
          {
            OPENSHELL_GATEWAY = cfg.gateway.name;
            OPENSHELL_GATEWAY_ENDPOINT = cfg.gateway.endpoint;
          }
          (lib.mkIf cfg.gateway.insecure {OPENSHELL_GATEWAY_INSECURE = "1";})
          (lib.mkIf (policyPath != null) {OPENSHELL_SANDBOX_POLICY = policyPath;})
          cfg.environment
        ];

        # Declarative local plaintext registration. `gateway add` is the only
        # supported writer of active_gateway/metadata.json; it also selects the
        # gateway as active, so no separate `gateway select` is needed.
        activation.openshellGateway = lib.mkIf register (lib.hm.dag.entryAfter ["writeBoundary"] ''
          if [ ! -e "${config.xdg.configHome}/openshell/gateways/${cfg.gateway.name}/metadata.json" ]; then
            $DRY_RUN_CMD ${lib.getExe cfg.package} gateway add ${lib.escapeShellArg cfg.gateway.endpoint} \
              --local \
              --name ${lib.escapeShellArg cfg.gateway.name} \
              ${lib.optionalString cfg.gateway.insecure "--gateway-insecure"}
          fi
        '');
      };

      xdg.configFile = {
        "openshell/gateway.toml".source = gatewayConfig;
        "openshell/policy.yaml" = lib.mkIf (policyFile != null) {source = policyFile;};
      };
    };
  };
}
