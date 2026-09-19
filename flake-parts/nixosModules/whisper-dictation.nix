{
  inputs,
  lib,
  ...
}: {
  # ------ NixOS Modules ------ #
  # Whisper Dictation — local push-to-talk speech-to-text (whisper.cpp).
  # https://github.com/jacopone/whisper-dictation
  #
  # Usage: hold the hotkey, speak, release — text is pasted into the focused
  # window. Recording uses the PipeWire default source; transcription uses
  # the whisper-dictation-vulkan package (Vulkan/RADV on AMD, ANV on Intel).
  flake.nixosModules.whisper-dictation = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.hostSpec.services.whisper-dictation;

    # Upstream pins its own nixpkgs tree; reuse its glib so the GLib-2.0
    # typelib matches the gtk4/pygobject closure exactly.
    upstreamPkgs =
      inputs.whisper-dictation.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};

    package = pkgs.symlinkJoin {
      name = "whisper-dictation-vulkan";
      paths = [pkgs.whisper-dictation-vulkan];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = let
        # Full typelib closure for Gtk-4.0 (upstream's wrapper only ships the
        # gtk4 + gobject-introspection dirs). Missing dirs are harmless.
        typelibDirs =
          map (a: "${upstreamPkgs.${a}.out}/lib/girepository-1.0")
          ["glib" "graphene" "pango" "gdk-pixbuf" "cairo" "harfbuzz"];
      in ''
        # pygobject must resolve GLib/Graphene/Pango/... typelibs to import
        # Gtk (ui.py is imported at daemon startup).
        wrapProgram $out/bin/whisper-dictation \
          --prefix GI_TYPELIB_PATH : "${lib.concatStringsSep ":" typelibDirs}"
      '';
    };
  in {
    options.hostSpec.services.whisper-dictation = {
      enable = lib.mkEnableOption ''
        whisper-dictation: local push-to-talk speech-to-text daemon
        (whisper.cpp). Requires the user to be in the input group (granted by
        this module) and a graphical (KDE/Wayland) session.
      '';

      package = lib.mkOption {
        type = lib.types.package;
        default = package;
        description = ''
          whisper-dictation package (vulkan variant; rewrapped to add glib's
          GI typelib dir upstream misses). Use `pkgs.whisper-dictation` for a
          CPU-only build.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "netsa";
        description = ''
          User that runs the daemon. Added to the `input` (evdev hotkey
          capture) and ydotool groups. The user service is gated to this
          user with ConditionUser.
        '';
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "small";
        description = ''
          Whisper ggml model to provision: tiny, base, small, medium,
          large-v3. Fetched from huggingface (ggerganov/whisper.cpp) into the
          Nix store and symlinked into ~/.local/share/whisper/models. If
          changing, also set modelHash.
        '';
      };

      modelHash = lib.mkOption {
        type = lib.types.str;
        default = "sha256-G+OpsgY4Z7k35k4ux0gzZKeZF+FX+pjF2UtcH//qmHs=";
        description = ''
          sha256 of ggml-`model`.bin. Obtain with:
          nix store prefetch-file --hash-type sha256 --json \
            https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-<model>.bin
        '';
      };

      language = lib.mkOption {
        type = lib.types.str;
        default = "en";
        description = "Transcription language code (en, it, ...) or auto.";
      };

      hotkey = {
        modifiers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["ctrl"];
          description = ''
            Push-to-talk modifiers: super, ctrl, alt, shift. Note: super+period
            conflicts with the KDE Plasma emoji picker.
          '';
        };
        key = lib.mkOption {
          type = lib.types.str;
          default = "period";
          description = ''
            Push-to-talk key supported by upstream config.py: period, comma,
            space, slash, semicolon.
          '';
        };
      };

      inputDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Evdev device NAME substring of the push-to-talk keyboard, e.g.
          "LogiG MKeyboard" or "Wireless Keyboard PID:4023". null =
          auto-detect. Only a single keyboard is monitored; the name must be
          specific (never a bare "Logitech" — it would match the mouse) and
          by-id paths never match (upstream compares /dev/input/eventN only).
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      # ydotoold system daemon (socket /run/ydotoold/socket, group-gated) and
      # the ydotool CLI.
      programs.ydotool.enable = true;

      # /dev/uinput must exist for ydotoold.
      boot.kernelModules = ["uinput"];

      users.users.${cfg.user}.extraGroups = [
        "input" # evdev hotkey capture
        config.programs.ydotool.group # ydotool socket access
      ];

      # Model file (immutable store copy) + one-time config seed. The `C`
      # rule installs config.yaml only when missing, so user edits survive
      # rebuilds. Store files have epoch mtimes, so `C` never overwrites.
      systemd.tmpfiles.rules = let
        home = "/home/${cfg.user}";
        modelFile = pkgs.fetchurl {
          url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${cfg.model}.bin";
          sha256 = cfg.modelHash;
        };
        configYaml = (pkgs.formats.yaml {}).generate "whisper-dictation-config.yaml" {
          # Sections must be complete: upstream does a shallow merge with its
          # built-in defaults.
          input_device = cfg.inputDevice;
          hotkey = {
            modifiers = cfg.hotkey.modifiers;
            key = cfg.hotkey.key;
          };
          whisper = {
            model = cfg.model;
            language = cfg.language;
            threads = 4;
            use_gpu = true;
          };
          processing = {
            remove_filler_words = true;
            auto_capitalize = true;
            auto_punctuate = false;
          };
          typing = {
            key_delay = 0;
            key_hold = 0;
            start_delay = 0.3;
          };
        };
      in [
        "d ${home}/.config/whisper-dictation 0755 ${cfg.user} users - -"
        "C ${home}/.config/whisper-dictation/config.yaml 0644 ${cfg.user} users - ${configYaml}"
        "d ${home}/.local/share/whisper/models 0755 ${cfg.user} users - -"
        "L+ ${home}/.local/share/whisper/models/ggml-${cfg.model}.bin - - - - ${modelFile}"
      ];

      # User daemon — starts with the KDE Wayland session.
      systemd.user.services.whisper-dictation = {
        description = "Whisper Dictation - local push-to-talk speech-to-text";
        unitConfig = {
          # Only start for the configured user (a second desktop user would
          # lack the input/ydotool groups and restart-loop).
          ConditionUser = cfg.user;
        };
        after = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        wantedBy = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = "${cfg.package}/bin/whisper-dictation";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = [
            "PYTHONUNBUFFERED=1"
            # ydotoold is a system service (programs.ydotool); the CLI needs
            # this to find the socket instead of its /run/user default.
            "YDOTOOL_SOCKET=/run/ydotoold/socket"
          ];
        };
      };
    };
  };
}
