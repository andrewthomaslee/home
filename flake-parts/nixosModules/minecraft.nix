{
  inputs,
  self,
  lib,
  ...
}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.minecraft = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.hostSpec.services.minecraft;
  in {
    imports = [
      inputs.nix-minecraft.nixosModules.minecraft-servers
    ];

    options.hostSpec.services.minecraft = {
      enable = lib.mkEnableOption "Minecraft";
      jvmOpts = lib.mkOption {
        type = lib.types.str;
        default = "-Xms8G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1";
        description = "JVM Options";
        example = lib.literalExpression ''
          "-Xms4G -Xmx4G -XX:+UseG1GC -XX:ParallelGCThreads=4 -XX:+DisableExplicitGC"
        '';
      };
      whitelist = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        description = "Whitelisted players";
        example = lib.literalExpression ''
          {
            netsammateo = "06c0f83a-7ffe-466c-be19-b3c247b1438c";
            sapphyy = "7ef1c05d-86b9-49fc-a3cf-ed1918818e2f";
          }
        '';
        default = {};
      };
      serverProperties = lib.mkOption {
        type = lib.types.attrs;
        description = "Server properties";
        example = lib.literalExpression ''
          {
            gamemode = "survival";
            difficulty = "normal";
            simulation-distance = "16";
            motd = "❄️ NixOS Minecraft ⛏️";
          }
        '';
        default = {
          gamemode = "survival";
          difficulty = "hard";
          simulation-distance = "12";
          motd = "❄️ NixOS Modded Minecraft ⛏️";
          force-gamemode = true;
        };
      };
      operators = lib.mkOption {
        type = lib.types.attrs;
        description = "Operators";
        example = lib.literalExpression ''
          {
            username1 = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
            username2 = {
              uuid = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy";
              level = 3;
              bypassesPlayerLimit = true;
            };
          }
        '';
        default = {};
      };
      symlinks = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        description = "Symlinks to mods";
        example = lib.literalExpression ''
          {
            mods = pkgs.linkFarmFromDrvs "mods" (
              builtins.attrValues {
                Fabric-API = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/i5tSkVBH/fabric-api-0.141.3%2B1.21.11.jar";
                  sha512 = "c20c017e23d6d2774690d0dd774cec84c16bfac5461da2d9345a1cd95eee495b1954333c421e3d1c66186284d24a433f6b0cced8021f62e0bfa617d2384d0471";
                };
                Travelers-Backpack = fetchurl {
                  url = "https://cdn.modrinth.com/data/rlloIFEV/versions/jDSDEMgY/travelersbackpack-fabric-1.21.11-10.11.5.jar";
                  sha512 = "06ce904071582935bfb206fd071fcd20e968edb72a151ab677c6763b85497c19327ff5d24575ceaec510a517fb14f05bda660cfdf06cea3f5d6b9ff28fd9a903";
                };
              }
            );
          }
        '';
        default = {
          mods = pkgs.linkFarmFromDrvs "mods" (
            builtins.attrValues {
              Fabric-API = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/i5tSkVBH/fabric-api-0.141.3%2B1.21.11.jar";
                sha512 = "c20c017e23d6d2774690d0dd774cec84c16bfac5461da2d9345a1cd95eee495b1954333c421e3d1c66186284d24a433f6b0cced8021f62e0bfa617d2384d0471";
              };
            }
          );
        };
      };
      files = lib.mkOption {
        type = lib.types.attrs;
        description = "Files to copy to server data directory";
        default = {};
      };
      fabric = {
        serverVersion = lib.mkOption {
          type = lib.types.str;
          default = "1_21_11";
          description = "Fabric server version";
          example = lib.literalExpression ''
            "1_21_1"
          '';
        };
        loaderVersion = lib.mkOption {
          type = lib.types.str;
          default = "0.18.4";
          description = "Fabric loader version";
          example = lib.literalExpression ''
            "0.16.2"
          '';
        };
      };
    };

    config = lib.mkIf cfg.enable {
      nixpkgs.overlays = [inputs.nix-minecraft.overlay];

      clan.core.vars.generators.minecraft = {
        prompts.seed = {
          description = "world seed";
          display.group = "minecraft";
        };
        files.seed.secret = false;
        runtimeInputs = [pkgs.coreutils];
        script = ''
          mkdir -p $out
          cp $prompts/* $out/
        '';
      };

      # Minecraft
      services.minecraft-servers = {
        enable = true;
        eula = true;
        openFirewall = true;

        servers.fabric = {
          enable = true;

          # Specify the custom minecraft server package
          package = pkgs.fabricServers."fabric-${cfg.fabric.serverVersion}".override {
            inherit (cfg.fabric) loaderVersion;
          }; # Specific fabric loader version

          serverProperties =
            {
              level-seed = config.clan.core.vars.generators.minecraft.files.seed.value;
            }
            // lib.optionalAttrs (cfg.whitelist != {}) {
              white-list = true;
              enforce-whitelist = true;
            }
            // cfg.serverProperties;
          inherit (cfg) jvmOpts whitelist symlinks operators files;
        };
      };

      # playit.gg proxy
      environment.systemPackages = [self.packages.${pkgs.system}.playit];
      systemd.services.playit = {
        description = "playit proxy";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          User = "playit";
          Group = "playit";
          Type = "simple";
          ExecStart = "${self.packages.${pkgs.system}.playit}/bin/playit -s";
          Restart = "always";
          RuntimeDirectory = "playit";
          StateDirectory = "playit";
          WorkingDirectory = "/var/lib/playit";
          # hardening options
          NoNewPrivileges = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          SystemCallFilter = "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
        };
      };

      users = {
        groups.playit = {};
        users.playit = {
          group = "playit";
          isSystemUser = true;
        };
      };
    };
  };
}
