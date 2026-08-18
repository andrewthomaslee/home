{...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.github-runners = {
    pkgs,
    lib,
    config,
    ...
  }:
    with pkgs; let
      inherit (lib) types;
      inherit (config.networking) hostName;
      inherit (config.nixpkgs.hostPlatform) system;
      inherit (config.clanServices.rancher.node.settings) cpu zone region;
      labels =
        if cpu == null
        then [zone region]
        else [cpu zone region];

      for = lib.flip map;
      forAttr = lib.flip lib.mapAttrsToList;
      # For input n, return [1..n]
      range =
        lib.genList (i: i + 1);
      # Poor man's zero-padding for numbers upto 99.
      paddedNum = n:
        if n < 10
        then "0${toString n}"
        else toString n;

      extraLabels = [hostName system] ++ labels;

      # Packages that will be made available to all runners.
      extraPackages = let
        # https://github.com/actions/upload-pages-artifact/blob/56afc609e74202658d3ffba0e8f6dda462b719fa/action.yml#L40
        gtar = runCommand "gtar" {} ''
          mkdir -p $out/bin
          ln -s ${lib.getExe gnutar} $out/bin/gtar
        '';
      in [
        gtar
        # For nix builds
        fh
        nix
        nixci
        cachix

        # Tools in standard GitHub Runners
        coreutils
        which
        jq
        yq

        # My CI tools
        cosign
        docker
        httpie
      ];

      # Runner configuration
      user = "github-runner";
      group = "github-runner";
      common = {
        inherit extraLabels user group;
        enable = true;
        replace = true;
        ephemeral = true;
        noDefaultLabels = true;
        extraPackages = extraPackages ++ config.hostSpec.services.github-nix-ci.runnerSettings.extraPackages;
      };
    in {
      options = {
        hostSpec.services.github-nix-ci = lib.mkOption {
          type = types.submodule {
            options = {
              runnerSettings = {
                extraPackages = lib.mkOption {
                  type = types.listOf types.package;
                  default = [];
                  description = ''
                    Extra packages to be installed on all runners
                  '';
                };
              };

              orgRunners = lib.mkOption {
                type = types.attrsOf (types.submodule ({
                  config,
                  name,
                  ...
                }: {
                  options = {
                    num = lib.mkOption {
                      type = types.int;
                      default = 1;
                    };

                    tokenFile = lib.mkOption {
                      type = types.path;
                      description = "The path to the token file for this runner";
                      default = "/var/run/secrets/vars/github-runners-${name}/token";
                    };

                    url = lib.mkOption {
                      type = types.str;
                      default = "https://github.com/${name}";
                      readOnly = true;
                    };

                    output.runners = lib.mkOption {
                      type = types.raw;
                      default = lib.listToAttrs (for (range config.num) (
                        i:
                          lib.nameValuePair "${hostName}-${name}-${paddedNum i}"
                          (common
                            // {
                              inherit (config) tokenFile url;
                            })
                      ));
                    };
                  };
                }));
                default = {};
              };

              personalRunners = lib.mkOption {
                type = types.attrsOf (types.submodule ({
                  config,
                  name,
                  ...
                }: {
                  options = {
                    num = lib.mkOption {
                      type = types.int;
                      default = 1;
                    };

                    tokenFile = lib.mkOption {
                      type = types.path;
                      description = "The path to the token file for this runner";
                      default = "/var/run/secrets/vars/github-runners-${config.output.user}-${config.output.repo}/token";
                    };

                    url = lib.mkOption {
                      type = types.str;
                      default = "https://github.com/${config.output.user}/${config.output.repo}";
                      readOnly = true;
                    };

                    output.user = lib.mkOption {
                      type = types.str;
                      default = let
                        parts = lib.splitString "/" name;
                      in
                        if lib.length parts == 2
                        then builtins.elemAt parts 0
                        else builtins.abort "Invalid user/repo";
                    };
                    output.repo = lib.mkOption {
                      type = types.str;
                      default = let
                        parts = lib.splitString "/" name;
                      in
                        if lib.length parts == 2
                        then builtins.elemAt parts 1
                        else builtins.abort "Invalid user/repo";
                    };
                    output.runners = lib.mkOption {
                      type = types.raw;
                      default =
                        lib.listToAttrs
                        (for (range config.num) (
                          i:
                            lib.nameValuePair "${hostName}-${config.output.user}-${config.output.repo}-${paddedNum i}"
                            (common
                              // {
                                inherit (config) tokenFile url;
                              })
                        ));
                    };
                  };
                }));
                default = {};
              };

              output.runner.owner = lib.mkOption {
                type = types.str;
                default = "github-runner";
                description = "The owner of the runner process";
              };
            };
          };
          default = {};
        };
      };
      config = let
        personalRunners = forAttr config.hostSpec.services.github-nix-ci.personalRunners (_: cfg: cfg.output.runners);
        orgRunners = forAttr config.hostSpec.services.github-nix-ci.orgRunners (_: cfg: cfg.output.runners);
        runners = personalRunners ++ orgRunners;

        orgGenerators =
          lib.mapAttrs' (name: _: {
            name = "github-runners-${name}";
            value = {
              share = true;
              prompts.token = {
                description = "github runner for ${name}";
                display.group = "github";
                type = "hidden";
                persist = true;
              };
              files.token = {
                owner = user;
                group = group;
              };
            };
          })
          config.hostSpec.services.github-nix-ci.orgRunners;

        personalGenerators =
          lib.mapAttrs' (_: cfg: {
            name = "github-runners-${cfg.output.user}-${cfg.output.repo}";
            value = {
              share = true;
              prompts.token = {
                description = "github runner for ${cfg.output.user}/${cfg.output.repo}";
                display.group = "github";
                type = "hidden";
                persist = true;
              };
              files.token = {
                owner = user;
                group = group;
              };
            };
          })
          config.hostSpec.services.github-nix-ci.personalRunners;
      in {
        clan.core.vars.generators = orgGenerators // personalGenerators;
        # Each org gets its own set of runners. There will be at max `num` parallels
        # CI builds for this org / host combination.
        services.github-runners = builtins.foldl' (a: b: lib.mkMerge [a b]) {} runners;

        users.users.${user} = {
          inherit group;
          isSystemUser = true;
        };
        users.groups.${group} = {};
        nix.settings.trusted-users = [user];
      };
    };
}
