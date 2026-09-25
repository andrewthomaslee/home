{
  inputs,
  self,
  pkgs,
  ...
}: let
  # Store paths interpolated into testScript. pkgs here is the test pkgs
  # (flake-parts/tests.nix passes testPkgs with the repo overlay), so this
  # matches the opencode-desktop the machine actually installs.
  desktopCli = "${pkgs.opencode-desktop}/opt/opencode-desktop/resources/opencode-cli";
in {
  # OpenCode Desktop (Electron) VM test: boots the packaged app under Xvfb,
  # screenshots the display, and asserts the full startup chain —
  # window mapped, bundled CLI staged and spawned, background service
  # ready. Diagnostics (app log, window tree, service registration) are
  # printed into the master log and copied out as artifacts BEFORE any
  # assertion, so a red run always explains itself.
  #
  # This test exists because the desktop app hangs on its splash screen
  # ("opencode" logo, never progresses) — the captured logs + screenshots
  # show exactly which startup step stalls.
  name = "opencode-desktop";
  globalTimeout = 10 * 60;

  nodes.machine = {pkgs, ...}: {
    imports = [
      inputs.clan-core.nixosModules.clanCore
      self.nixosModules.default
    ];

    clan.core.settings = {
      directory = self;
      machine.name = "opencode-desktop-test";
    };

    networking.hostName = "opencode-desktop-test";

    # clan-core's vars -> sops-nix deployment needs a key source; the VM
    # test machine is not in inventory so there is no provisioned age key.
    # Enabling sshd lets sops-nix derive its host key from the SSH host key.
    services.openssh.enable = true;

    users.users.alice = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      linger = true;
    };

    home-manager = {
      useGlobalPkgs = false;
      useUserPackages = true;
      sharedModules = [
        inputs.plasma-manager.homeModules.plasma-manager
      ];
      users.alice = {
        imports = [
          self.homeModules.default
        ];
        home.stateVersion = "26.11";
        homeSpec.programs.opencode = {
          enable = true;
          # The point of this test: the Electron desktop app.
          enableDesktop = true;
          # Lean closure: no k3s/rke2/devcontainer toolset needed here.
          fullDevTools = false;
        };
      };
    };

    # In-VM X harness: Xvfb virtual display + screenshot/window tooling.
    environment.systemPackages = with pkgs; [
      dejavu_fonts
      jq
      scrot
      xdotool
      xorg.xwininfo
      xorg.xorgserver
    ];
    fonts.packages = [pkgs.dejavu_fonts];

    systemd.user.services = {
      # Virtual display the app renders into; scrot/xdotool target :1.
      opencode-xvfb = {
        description = "Xvfb virtual display (opencode-desktop VM test)";
        wantedBy = ["default.target"];
        serviceConfig = {
          ExecStart = "${pkgs.xorg.xorgserver}/bin/Xvfb :1 -screen 0 1280x800x24 -nolisten tcp";
          Restart = "always";
          RestartSec = "2";
        };
      };
      # The app itself; started manually by the test script after Xvfb.
      # Logs land in /home/alice/desktop.log (append) AND the journal —
      # the log file is pulled out as an artifact.
      opencode-desktop = {
        description = "OpenCode Desktop (VM test)";
        after = ["opencode-xvfb.service"];
        wants = ["opencode-xvfb.service"];
        environment = {
          DISPLAY = ":1";
          # Chromium/Electron console messages (renderer errors!) on stderr.
          ELECTRON_ENABLE_LOGGING = "1";
        };
        serviceConfig = {
          ExecStart = "${pkgs.opencode-desktop}/bin/opencode-desktop";
          # Red runs keep the app state for post-mortem; restarts are done
          # manually by the test script.
          Restart = "no";
          StandardOutput = "append:/home/alice/desktop.log";
          StandardError = "append:/home/alice/desktop.log";
        };
      };
    };
  };

  testScript = let
    suAlice = cmd: "su - alice -c '" + cmd + "'";
    userCtl = cmd: suAlice ("export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; " + cmd);
  in ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    # 1. Static packaging checks: the app on PATH and the bundled CLI runs.
    machine.succeed("su - alice -c 'opencode --version'")
    machine.succeed("test -x ${pkgs.opencode-desktop}/bin/opencode-desktop")
    machine.succeed("${suAlice "${desktopCli} --version"} > /tmp/cli-version.out")
    print(machine.succeed("cat /tmp/cli-version.out"))

    # 2. Xvfb up (units are NixOS-level: /etc/systemd/user; HM activation
    # may still race the user-manager boot, so reload first).
    machine.succeed("test -f /etc/systemd/user/opencode-xvfb.service")
    machine.succeed("${userCtl "systemctl --user daemon-reload"}")
    machine.succeed("${userCtl "systemctl --user start opencode-xvfb.service"}")
    machine.wait_until_succeeds("test -S /tmp/.X11-unix/X1", timeout=60)

    # 3. Launch the desktop app.
    machine.succeed("${userCtl "systemctl --user start opencode-desktop.service"}")

    # 4. Give the app a first window to appear, then ALWAYS capture
    #    diagnostics — app log, window tree, processes, registration file —
    #    and copy them out BEFORE any assertion. A red run still explains
    #    itself in the master log and the artifact directory. The app
    #    writes its own logs to ~/.config/<app>/logs/<stamp>/ (electron-log);
    #    desktop.log only carries Chromium/Electron console noise.
    machine.sleep(20)
    machine.execute("${suAlice "find ~/.config -path '*logs*' -name '*.log' 2>/dev/null | head -20"}")
    print(machine.execute("${suAlice "xwininfo -root -tree 2>&1 | head -40 || true"}")[1])
    print(machine.execute("pgrep -af 'opencode|electron' || true")[1])
    print(machine.execute("${suAlice "cat ~/.local/state/opencode/service.json 2>/dev/null || echo NO_SERVICE_JSON"}")[1])
    print(machine.execute("${suAlice "ls -la ~/.config/*/cli/*/ 2>/dev/null || echo NO_CLI_STAGE"}")[1])
    print(machine.execute("${suAlice "cat ~/.config/*/logs/*/main.log 2>/dev/null || echo NO_APP_LOG"}")[1])
    machine.copy_from_machine("/home/alice/desktop.log", "chromium.log")
    machine.execute("${suAlice "mkdir -p /home/alice/artifacts; for f in ~/.config/*/logs/*/*.log; do cp $f /home/alice/artifacts/app-$(basename $(dirname $f))-$(basename $f) 2>/dev/null; done; cp ~/.local/state/opencode/service.json /home/alice/artifacts/ 2>/dev/null; ls ~/.config/*/cli/*/ > /home/alice/artifacts/cli-stage.txt 2>/dev/null; true"}")
    machine.execute("${suAlice "cp ~/.local/state/opencode/service.json /home/alice/service.json 2>/dev/null; true"}")
    machine.copy_from_machine("/home/alice/artifacts", "app-artifacts")

    # Screenshot #0: whatever the display shows after startup.
    machine.succeed("${suAlice "DISPLAY=:1 scrot -o /home/alice/desktop-0.png"}")
    machine.copy_from_machine("/home/alice/desktop-0.png", "desktop-0.png")

    # 5. Health assertions: the app window is mapped, the staged v2 CLI
    # sidecar process is running, and the background service reported
    # ready (the line the main process logs once the renderer can talk
    # to the backend — the step after which the splash must go away).
    # App log scope files land in ~/.config/<app>/logs/<stamp>/main.log.
    machine.wait_until_succeeds(
      "${suAlice "DISPLAY=:1 xdotool search --name OpenCode"}", timeout=120
    )
    machine.wait_until_succeeds(
      "pgrep -f 'opencode-cli serve --service' > /dev/null", timeout=120
    )
    machine.wait_until_succeeds(
      "${suAlice "grep -h -q background.service.ready ~/.config/*/logs/*/main.log"}", timeout=120
    )

    # 6. Still alive (not a crash-looper): 15s later the main process and
    # the sidecar must both still be running, and the second screenshot
    # shows the settled UI.
    machine.sleep(15)
    machine.succeed("pgrep -f 'opencode-desktop' > /dev/null")
    machine.succeed("pgrep -f 'opencode-cli serve --service' > /dev/null")
    machine.succeed("${suAlice "DISPLAY=:1 scrot -o /home/alice/desktop-1.png"}")
    machine.copy_from_machine("/home/alice/desktop-1.png", "desktop-1.png")

    # 7. Final app-log dump for the master log (tail).
    print(machine.execute("${suAlice "tail -60 ~/.config/*/logs/*/main.log 2>/dev/null"}")[1])
  '';
}
