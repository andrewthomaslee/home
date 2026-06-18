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
          python3Minimal
          git
          httpie
          helm-ls
          terraform-ls
          kubectl
          kubernetes-helm
        ];
        tui.theme = "tokyonight";
        settings = {
          model = "google/gemini-3.5-flash";
          small_model = "google/gemini-1.5-flash";
          compaction = {
            auto = true;
            tail_turns = 2;
          };
          lsp = {
            python = {
              command = ["${pyrefly}/bin/pyrefly"];
              extensions = ["py"];
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
          };
        };
      };
    };
  };
}
