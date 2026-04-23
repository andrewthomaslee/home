{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.ksshaskpass = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.ksshaskpass;
  in {
    options.homeSpec.programs.ksshaskpass.enable = lib.mkEnableOption "default ksshaskpass configuration";

    config = lib.mkIf cfg.enable {
      home.packages = [pkgs.kdePackages.ksshaskpass];
      xdg.configFile."environment.d/ssh_askpass.conf".text = ''
        SSH_ASKPASS="/run/current-system/sw/bin/ksshaskpass"
      '';
      xdg.configFile."autostart/ssh-add.desktop".text = ''
        [Desktop Entry]
        Exec=ssh-add -q
        Name=ssh-add
        Type=Application
      '';
      xdg.configFile."plasma-workspace/env/ssh-agent-startup.sh" = {
        text = ''
          #!/bin/sh
          [ -n "$SSH_AGENT_PID" ] || eval "$(ssh-agent -s)"
        '';
        executable = true;
      };
      xdg.configFile."plasma-workspace/shutdown/ssh-agent-shutdown.sh" = {
        text = ''
          #!/bin/sh
          [ -z "$SSH_AGENT_PID" ] || eval "$(ssh-agent -k)"
        '';
        executable = true;
      };
    };
  };
}
