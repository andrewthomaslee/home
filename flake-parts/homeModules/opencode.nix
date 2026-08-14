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
          rke2
          devpod
          docker
          kubernetes
        ];
        tui.theme = "tokyonight";
        settings = {
          model = "deepseek/deepseek-v4-pro";
          small_model = "deepseek/deepseek-v4-flash";
          compaction = {
            auto = true;
            tail_turns = 3;
          };
          lsp = {
            python = {
              command = ["pyrefly"];
              extensions = ["py"];
            };
            gleam = {
              command = ["gleam" "lsp"];
              extensions = ["gleam"];
            };
          };
          formatter = {
            nix = {
              command = ["alejandra"];
              extensions = ["nix"];
            };
            python = {
              command = ["ruff" "format" "-"];
              extensions = ["py"];
            };
            gleam = {
              command = ["gleam" "format"];
              extensions = ["gleam"];
            };
          };
        };
      };
    };
  };
}
