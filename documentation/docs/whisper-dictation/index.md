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

## Enabling

```nix
# machines/<name>/configuration.nix
hostSpec.services.whisper-dictation.enable = true;
```

The module (`flake-parts/nixosModules/whisper-dictation.nix`, gated behind
`hostSpec.services.whisper-dictation.*`) wires everything:

- `programs.ydotool.enable` — system `ydotoold` (uinput text insertion)
- `boot.kernelModules = ["uinput"]`
- Adds the user to the `input` (evdev hotkey capture) and `ydotool` groups
- Provisions the Whisper model into the Nix store and symlinks it to
  `~/.local/share/whisper/models/`
- Seeds `~/.config/whisper-dictation/config.yaml` **only if missing** — edit
  freely afterwards; rebuilds never overwrite your changes
- Runs `whisper-dictation-vulkan` as a user service gated to `netsa`
  (`ConditionUser`)

## Options

| Option | Default | Description |
| --- | --- | --- |
| `enable` | `false` | Enable the daemon + integrations |
| `package` | `whisper-dictation-vulkan` | Vulkan build uses the GPU (RADV on AMD); `pkgs.whisper-dictation` for CPU-only |
| `user` | `"netsa"` | User running the daemon (gets `input` + `ydotool` groups) |
| `model` | `"small"` | ggml model: `tiny`, `base`, `small`, `medium`, `large-v3` |
| `modelHash` | *(sha256 of `small`)* | Set alongside `model` (`nix store prefetch-file --hash-type sha256 --json <url>`) |
| `language` | `"en"` | Transcription language code, or `auto` |
| `hotkey.modifiers` | `["ctrl"]` | Push-to-talk modifiers (`super`, `ctrl`, `alt`, `shift`) |
| `hotkey.key` | `"period"` | Push-to-talk key (`period`, `comma`, `space`, `slash`, `semicolon`) |
| `inputDevice` | `null` | Evdev keyboard NAME substring to pin the hotkey device; `null` = auto-detect |

### Model sizes

| Model | Size | Accuracy | Notes |
| --- | --- | --- | --- |
| tiny | 39 MB | ~60% | Fastest, noisy output |
| base | 142 MB | ~70% | Upstream's speed pick |
| **small** | 466 MB | ~80% | Default here — good balance with iGPU Vulkan |
| medium | 1.5 GB | ~85% | Slower on an iGPU |
| large-v3 | 3 GB | ~90% | Needs `modelHash` change |

## Devices on kamrui-h1

- **Microphone**: the Logitech C270 webcam's mic ("Webcam C270 Mono") is the
  PipeWire default source — recording uses it automatically.
- **Hotkey keyboard**: auto-detected (daemon prefers evdev devices whose name
  contains "keyboard" — currently the wired `Logitech LogiG MKeyboard`). To
  pin it, set in `~/.config/whisper-dictation/config.yaml`:
  `input_device: "LogiG MKeyboard"` (wired) or
  `input_device: "Wireless Keyboard PID:4023"` (wireless). Use an exact name
  substring — a bare `Logitech` matches the mouse, and by-id paths never
  match.

## Tweaks

Edit `~/.config/whisper-dictation/config.yaml` (seeded once by the module,
yours afterwards): hotkey, language, model, typing speed, filler-word
removal. Command-line overrides also exist when running the binary manually.

## Troubleshooting

- **Daemon logs**: `journalctl --user -u whisper-dictation -f`
- **Hotkey does nothing**: check the daemon found a keyboard in the logs; a
  session predating the `ydotool` group needs one re-login; only the pinned
  (or auto-detected) keyboard triggers push-to-talk
- **No text appears**: `systemctl status ydotoold` must be active
  (socket `/run/ydotoold/socket`)
- **No audio recorded**: confirm `Webcam C270 Mono` is the default source
  (`wpctl status`)
- **Slow transcription**: lower `whisper.model` (small → base → tiny), or
  force CPU with `whisper.use_gpu: false`
