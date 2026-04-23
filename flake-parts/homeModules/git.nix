{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.git = {config, ...}: let
    cfg = config.homeSpec.programs.git;
  in {
    options.homeSpec.programs.git.enable = lib.mkEnableOption "default git configuration";

    config = lib.mkIf cfg.enable {
      programs = {
        lazygit.enable = true;

        git = {
          enable = true;
          lfs.enable = true;

          ignores = [
            ".secrets"
            "result*"
            "result-*"
            ".direnv"
            ".devenv"
            ".env"
            ".env.*"
            "!.env.schema"
            ".venv"
            ".terraform*"
            "terraform.tfstate*"
            "config.tf.json"
          ];

          settings = {
            extraConfig = {
              init.defaultBranch = "main";

              pull = {
                rebase = true;
                autostash = true;
                twohead = "ort";
              };

              push = {
                default = "simple";
                autoSetupRemote = true;
              };

              branch = {
                autoSetupRebase = "always";
                autoSetupMerge = "always";
              };

              rebase = {
                stat = true;
                autoStash = true;
                autoSquash = true;
                updateRefs = true;
              };

              help.autocorrect = 10;
            };

            signing = {
              format = "ssh";
              key = "/home/netsa/.ssh/id_ed25519.pub";
              signByDefault = true;
            };

            aliases = {
              s = "status";
              d = "diff";
              a = "add";
              c = "commit";
              p = "push";
              o = "checkout";
              co = "checkout";
              uncommit = "reset --soft HEAD^";
              comma = "commit --amend";
              reset-pr = "reset --hard FETCH_HEAD";
              force-push = "push --force-with-lease";
            };

            user = {
              email = "andrewthomaslee.business@gmail.com";
              name = "andrewthomaslee";
            };
          };
        };
      };
    };
  };
}
