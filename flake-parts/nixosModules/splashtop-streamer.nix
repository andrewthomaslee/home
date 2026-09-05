{lib, ...}: {
  flake.nixosModules.splashtop-streamer = {
    pkgs,
    config,
    lib,
    ...
  }: let
    cfg = config.hostSpec.services.splashtop-streamer;
    pkg = pkgs.splashtop-streamer;
    sptDir = "${pkg}/opt/splashtop-streamer";

    shimEntries = [
      "SRAgent"
      "SRChat"
      "SRFeature"
      "SRPortal"
      "SRStreamer"
      "SRUsb"
      "SRUtility"
      "pamtester"
      "SRServer.pem"
      "enc1.bin"
      "enc2.bin"
      "Acknowledgements.txt"
      "libcelt0.so"
      "libcelt0.so.0"
      "libcelt0.so.0.0.0"
      "libcrypto.so"
      "libcrypto.so.3"
      "libssl.so"
      "libssl.so.3"
      "libSRUsbVhciCtrl.so"
      "libSRx264Wrapper.so"
      "libx264.so"
      "libx264.so.164"
      "ossl-modules"
      "script"
    ];

    tmpfilesRules =
      [
        "d /opt/splashtop-streamer 0755 root root -"
        "d /opt/splashtop-streamer/config 2775 splashtop-streamer splashtop-streamer -"
        "C+ /opt/splashtop-streamer/config/ssl 0770 splashtop-streamer splashtop-streamer - ${sptDir}/config/ssl"
        "d /opt/splashtop-streamer/log 2775 splashtop-streamer splashtop-streamer -"
        "d /opt/splashtop-streamer/log/user 0777 splashtop-streamer splashtop-streamer -"
        "d /opt/splashtop-streamer/dump 2775 splashtop-streamer splashtop-streamer -"
        "d /opt/splashtop-streamer/dump/user 0777 splashtop-streamer splashtop-streamer -"
      ]
      ++ map (entry: "C+ /opt/splashtop-streamer/${entry} - - - - ${sptDir}/${entry}") shimEntries;
  in {
    options.hostSpec.services.splashtop-streamer = {
      enable = lib.mkEnableOption "default splashtop-streamer configuration";

      deploymentCode = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "0ABCDEF123";
        description = ''
          Deployment code from your Splashtop admin console, applied on service start
          via `SRUtility --deploy`. Leave null to register manually with
          `splashtop-streamer deploy CODE`.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      nixpkgs.config.allowUnfree = true;

      users.groups.splashtop-streamer = {};
      users.users.splashtop-streamer = {
        isSystemUser = true;
        group = "splashtop-streamer";
        description = "Splashtop Streamer daemon user";
        home = "/opt/splashtop-streamer";
        createHome = false;
      };

      environment.systemPackages = [pkg];

      services.dbus.packages = [pkg];

      security.polkit.extraConfig = builtins.readFile "${pkg}/share/polkit-1/rules.d/com.splashtop.streamer.rules";

      security.pam.services = {
        splashtop = {};
        splashtop-streamer = {};
      };

      systemd.tmpfiles.rules = tmpfilesRules;

      systemd.services.SRStreamer = {
        description = "Splashtop Streamer Daemon";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network.target" "network-online.target"];

        environment.LD_LIBRARY_PATH = "/opt/splashtop-streamer";

        serviceConfig = {
          Type = "simple";
          ExecStart = "/opt/splashtop-streamer/SRFeature";
          WorkingDirectory = "/opt/splashtop-streamer";
          Restart = "always";
          TimeoutStopSec = 30;
        };

        preStart = lib.optionalString (cfg.deploymentCode != null) ''
          /opt/splashtop-streamer/SRUtility --deploy ${lib.escapeShellArg cfg.deploymentCode}
        '';
      };
    };
  };
}
