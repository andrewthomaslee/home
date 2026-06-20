{
  # inputs,
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
      programs.opencode = with pkgs.unstable; {
        enable = true;
        package = opencode;
        extraPackages = [
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
          kubectl
          kubernetes-helm
          gleam
        ];
        tui.theme = "tokyonight";
        settings = {
          model = "minimax/minimax-m3";
          small_model = "google/gemma-4-26b-a4b-it:free";
          compaction = {
            auto = true;
            tail_turns = 2;
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
