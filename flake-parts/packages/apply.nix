{...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}: {
    packages = {
      apply-and-reboot = pkgs.writeShellApplication {
        name = "apply-and-reboot";
        runtimeInputs = with pkgs; [
          fh
          systemd
          coreutils
        ];
        text = ''
          REPO=$1
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/$REPO/*" boot
          sleep 10
          systemctl reboot
        '';
      };
      apply-to-boot = pkgs.writeShellApplication {
        name = "apply-to-reboot";
        runtimeInputs = with pkgs; [
          fh
        ];
        text = ''
          REPO=$1
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/$REPO/*" boot
        '';
      };
      apply-now = pkgs.writeShellApplication {
        name = "apply-now";
        runtimeInputs = with pkgs; [
          fh
        ];
        text = ''
          REPO=$1
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/$REPO/*" switch
        '';
      };
      apply-test = pkgs.writeShellApplication {
        name = "apply-test";
        runtimeInputs = with pkgs; [
          fh
        ];
        text = ''
          REPO=$1
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/$REPO/*" test
        '';
      };
      apply-dry-activate = pkgs.writeShellApplication {
        name = "apply-dry-activate";
        runtimeInputs = with pkgs; [
          fh
        ];
        text = ''
          REPO=$1
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/$REPO/*" dry-activate
        '';
      };
    };
  };
}
