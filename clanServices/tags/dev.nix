{
  lib,
  inputs,
  pkgs,
  ...
}: {
  imports = [];
  config = {
    # hostSpec options
    hostSpec = {
      services = {
        docker.enable = true;
        storagebox.enable = true;
        nix.enable = true;
      };
    };

    # nixos options
    security.sudo.wheelNeedsPassword = false;
    boot.binfmt.emulatedSystems = ["aarch64-linux"];

    # In your configuration
    environment.systemPackages = [
      inputs.whisper-dictation.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Enable auto-start
    systemd.user.services.whisper-dictation = {
      enable = true;
      wantedBy = ["graphical-session.target"];
    };

    specialisation = {
      warp.configuration = {
        hostSpec.networking = {
          tailscale = {
            enable = lib.mkForce false;
            systray = lib.mkForce false;
          };
          warp.enable = lib.mkForce true;
        };
      };
    };
  };
}
