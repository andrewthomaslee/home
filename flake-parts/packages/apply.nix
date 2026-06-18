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
    };
  };
}
