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
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/home/*" boot
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
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/home/*" boot
        '';
      };
      apply-now = pkgs.writeShellApplication {
        name = "apply-now";
        runtimeInputs = with pkgs; [
          fh
        ];
        text = ''
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/home/*" switch
        '';
      };
      apply-test = pkgs.writeShellApplication {
        name = "apply-test";
        runtimeInputs = with pkgs; [
          fh
        ];
        text = ''
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/home/*" test
        '';
      };
      apply-dry-activate = pkgs.writeShellApplication {
        name = "apply-dry-activate";
        runtimeInputs = with pkgs; [
          fh
        ];
        text = ''
          fh apply nixos "https://flakehub.com/f/andrewthomaslee/home/*" dry-activate
        '';
      };
    };
  };
}
