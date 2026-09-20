# Whisper Dictation

Local, privacy-first push-to-talk speech-to-text for kamrui-h1, built on
[whisper-dictation](https://github.com/jacopone/whisper-dictation)
(whisper.cpp) with Vulkan acceleration on the AMD iGPU. 100% local — no cloud,
works offline.

## Usage

1. Click into any text field
2. Hold <kbd>Ctrl</kbd>+<kbd>Period</kbd>
3. Speak naturally
4. Release the key — the transcription is typed into the focused window

The daemon (`systemd --user` unit `whisper-dictation`) starts automatically
with the KDE Wayland session. Desktop notifications show recording /
transcribing / success states.

## What the module does

`hostSpec.services.whisper-dictation.enable = true;` wires only the
NixOS-specific glue (everything else is upstream stock):

- `programs.ydotool.enable` — system `ydotoold` (uinput text insertion,
  socket `/run/ydotoold/socket`)
- `boot.kernelModules = ["uinput"]`
- Adds the user to the `input` (evdev hotkey capture) and `ydotool` groups
- Runs `whisper-dictation-vulkan` as a user service gated to the user
  (`ConditionUser`) with `YDOTOOL_SOCKET=/run/ydotoold/socket`
- Re-wraps upstream's package with the full Gtk-4.0 typelib closure
  (`glib`, `graphene`, `pango`, `gdk-pixbuf`, `cairo`, `harfbuzz`) —
  upstream's wrapper omits `GI_TYPELIB_PATH` entirely, and
  `Gtk-4.0.typelib` resolves all of those namespaces; with glib alone the
  daemon crash-loops on `Typelib namespace Graphene not found`

Options: `enable`, `user` (default `netsa`).

## Manual configuration (`~/.config/whisper-dictation/config.yaml`)

Edit freely and restart the unit (`systemctl --user restart
whisper-dictation`) after changes. Key settings:

- `input_device: /dev/input/event1` — **pin the push-to-talk keyboard**. On
  kamrui-h1 `event1` is the wired Logitech keyboard's typing interface. If
  dictation ever goes silent after a reboot/replug (node renumbering), check
  `readlink -f /dev/input/by-id/usb-Logitech_LogiG_MKeyboard-event-kbd` and
  update the pin. Do not pin a bare name like `Logitech` (matches the mouse)
  or the dongle's phantom `Wireless Keyboard PID:4023` (never emits keys).
- `hotkey` — `ctrl` + `period` (default; `super`+`period` collides with the
  KDE Plasma emoji picker)
- `whisper.model` — `small` (provisioned), `tiny`, `base`, `medium`
- `whisper.language` — `en` (or `auto`)

## Model

`~/.local/share/whisper/models/ggml-small.bin` is a symlink into the Nix
store (provisioned during the initial deployment). To switch models:

```console
$ curl -L -o ~/.local/share/whisper/models/ggml-base.bin \
    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```

then set `whisper.model: base` in config.yaml.

| Model | Size | Accuracy | Notes |
| --- | --- | --- | --- |
| tiny | 39 MB | ~60% | Fastest, noisy output |
| base | 142 MB | ~70% | Upstream's speed pick |
| small | 466 MB | ~80% | Default here — good balance with iGPU Vulkan |
| medium | 1.5 GB | ~85% | Slower on an iGPU |

## Devices on kamrui-h1

- **Microphone**: the Logitech C270 webcam's mic ("Webcam C270 Mono") is the
  PipeWire default source — recording uses it automatically.
- **Push-to-talk keyboard**: the wired `Logitech LogiG MKeyboard`, pinned via
  `input_device` in config.yaml (see above).
- Text insertion goes through the system `ydotoold` (`/run/ydotoold/socket`).

## Troubleshooting

- **Daemon logs**: `journalctl --user -u whisper-dictation -f`
- **Verbose run** (shows hotkey detection and recording):
  `systemctl --user stop whisper-dictation && whisper-dictation --verbose`
  (restart the unit afterwards)
- **Hotkey does nothing**: confirm the daemon watches `/dev/input/event1`
  (`Found configured device: … at /dev/input/event1` in the journal); verify
  the by-id mapping if nodes renumbered; only the pinned keyboard triggers
- **No text appears**: `systemctl status ydotoold` must be active
- **No audio recorded**: confirm `Webcam C270 Mono` is the default source
  (`wpctl status`)
- **Slow transcription**: lower `whisper.model` (small → base → tiny)
