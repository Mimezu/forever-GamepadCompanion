# Gamepad Companion helper

Reads the addon's corner strip and drives the DualSense: adaptive triggers and true haptics.
Python 3.12, standard library only. Protocol: `../docs/HELPER.md`.

```
python gpc_helper.py --list            # game window, DualSense, audio outputs (writes nothing)
python gpc_helper.py --selftest        # protocol, clips, report bytes (no hardware)
python gpc_helper.py --dry-run -v      # read the strip, print what it would do, send nothing
python gpc_helper.py --run             # the real thing
python gpc_helper.py --demo-triggers   # each trigger effect, 4 s each (asks first)
python gpc_helper.py --demo-audio      # each built-in clip (asks first)
```

In game: turn the link on (Gamepad Companion), start the helper, play. Ctrl+C stops it.

| Option | |
|---|---|
| `-v` | log every change |
| `--volume 0.5` | master gain for clips |
| `--no-audio` | triggers only |
| `--legacy-triggers` | old effect modes (0x01 / 0x02 / 0x06) |
| `--transport usb\|bt` | override detection |
| `--foreground` | read the foreground window if no WoW window |
| `--audio-device N` | audio device from `--list` |
| `--confirm N` | same reads before acting (2) |

## Limits

- **Display mode:** windowed or borderless only. Full screen is unreadable.
- **USB:** triggers and 4-channel audio (speaker 1-2, haptics 3-4). In Windows Sound
  settings keep the controller at 4 channels (Quadraphonic): in stereo, haptics may leak
  into the speaker.
- **Bluetooth:** triggers only. No audio device.
- Writes only trigger bits: the game's rumble and light bar stay as they are.
- On exit (Ctrl+C, window closed, game gone 10 s): triggers off, audio stopped.
- Not with DS4Windows exclusive mode, HidHide or DualSenseX.
