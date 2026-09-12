{
  inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.opencode = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.opencode;
    headroomCfg = config.homeSpec.programs.headroom;
    headroomEnabled = config.homeSpec.programs.headroom.enable or false;
    headroomProxyUrl = "http://${headroomCfg.proxy.host}:${toString headroomCfg.proxy.port}/v1";
  in {
    options.homeSpec.programs.opencode.enable = lib.mkEnableOption "default opencode configuration";
    config = lib.mkIf cfg.enable {
      # add skills to config
      xdg.configFile."opencode/skills".source = inputs.agents.lib.mkSkills {
        inherit pkgs;
        customSkills = "${inputs.skills-anthropic}/skills";
        externalSkills = [
          # Include all skills from anthropics/skills
          # {src = inputs.skills-anthropic;}
          # Or cherry-pick specific skills:
          # { src = inputs.skills-anthropic; selectSkills = [ "mcp-builder" ]; }
        ];
      };

      home.packages = with inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}; [
        opencode-desktop
      ];
      programs.opencode = {
        enable = true;
        package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
        extraPackages = with pkgs.unstable; [
          actionlint
          uv
          nix
          pyrefly
          nil
          alejandra
          ruff
          podman
          python3
          git
          httpie
          helm-ls
          terraform-ls
          kubernetes-helm
          gleam
          jq
          yq
          bun
          nodejs-slim_latest
          go_latest
          devcontainer
          k3d
          k3s
          rke2
          devpod
          docker
          kubernetes
        ];
        tui.theme = "tokyonight";
        settings = lib.mkMerge [
          {
            model = "deepseek/deepseek-v4-pro";
            small_model = "deepseek/deepseek-v4-flash";
            compaction = {
              auto = true;
              tail_turns = 3;
            };
            permission = {
              read = {
                "/nix/store/**" = "allow";
                "/tmp/**" = "allow";
              };
              external_directory = {
                "/nix/store/**" = "allow";
                "/tmp/**" = "allow";
              };
            };
            lsp = {
              python = {
                command = ["pyrefly" "lsp"];
                extensions = [".py" ".pyi"];
              };
              # Built-in pyright would try a runtime npm auto-download of
              # pyright-langserver (non-hermetic on NixOS) and duplicate the
              # .py/.pyi LSP already provided by pyrefly.
              pyright.disabled = true;
              nix = {
                command = ["nil"];
                extensions = [".nix"];
              };
              gleam = {
                command = ["gleam" "lsp"];
                extensions = [".gleam"];
              };
            };
            formatter = {
              nix = {
                command = ["alejandra" "$FILE"];
                extensions = [".nix"];
              };
              ruff = {
                command = ["ruff" "format" "$FILE"];
                extensions = [".py" ".pyi"];
              };
              gleam = {
                command = ["gleam" "format" "$FILE"];
                extensions = [".gleam"];
              };
            };
          }
          (lib.mkIf headroomEnabled {
            mcp = {
              headroom = {
                type = "local";
                command = ["${lib.getExe headroomCfg.package}" "mcp" "serve"];
                enabled = true;
              };
            };
            plugin = [
              "${headroomCfg.package}/${pkgs.unstable.python313.sitePackages}/headroom/providers/opencode/_dist/entry.opencode.js"
            ];
            provider = {
              deepseek = {
                options = {
                  baseURL = headroomProxyUrl;
                };
              };
              anthropic = {
                options = {
                  baseURL = headroomProxyUrl;
                };
              };
              openai = {
                options = {
                  baseURL = headroomProxyUrl;
                };
              };
            };
          })
        ];
      };
    };
  };
}
