{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.ssh = {config, ...}: let
    cfg = config.homeSpec.programs.ssh;
  in {
    options.homeSpec.programs.ssh.enable = lib.mkEnableOption "default ssh configuration";
    config = lib.mkIf cfg.enable {
      # for DevPod
      home.sessionVariables.SSH_CONFIG_PATH = "~/.ssh/config.local";

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        includes = lib.mkDefault ["~/.ssh/config.local"];
      };
    };
  };
}
