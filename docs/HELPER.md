# Helper link protocol

The single source of truth for the addon -> helper link. Addon side: `HelperLink.lua`
(`K.Encode`, `K.Decode`). Helper side: `helper/protocol.py` (`encode`, `decode`). Both are checked
against the same vectors, `tests/fixtures/helperlink-vectors.txt` (written by
`lua5.1 tests/HelperLink.lua . --write`, read by `python helper/gpc_helper.py --selftest`).

Why pixels: addons can't use files, the network or processes live. The addon draws a strip of
coloured cells; the helper reads it from the screen (windowed or borderless only) and drives the
DualSense: adaptive triggers (HID output report) and true haptics (USB audio channels 3-4).
Background: `ADAPTIVE-TRIGGERS.md`, `HAPTICS.md` section 5.

## The strip

- 18 cells in one row at the very top-left of the screen (the game window's client area).
- Each cell is a solid square of **S physical pixels** (S = 4 by default, 1-16; saved as
  `GamepadCompanionHapticsDB.link.cell`). The addon sizes it from `GetPhysicalScreenSize()` and the
  frame's effective scale: one pixel = `(768 / physical height) / effective scale` UI units.
- Frame: parent nil (shown with the UI hidden), strata `TOOLTIP`, shown only while the link is on.
- Each colour channel is on or off: **>= 160 on, <= 96 off**, anything between is invalid (the
  whole frame is dropped). So 3 bits per cell (R, G, B), and gamma or brightness don't matter.
- Cell 0 = magenta (1,0,1) and cell 1 = green (0,1,0) are markers. The helper scans a small area
  (320 x 40 px) for the magenta block's top-left corner, takes its width as S, checks the green
  cell, and samples every cell's centre (`x + i*S + S/2`, `y + S/2`).

## The 48 data bits (cells 2-17)

Bit `n` is in data cell `n // 3`, channel `n % 3` (0 R, 1 G, 2 B). Values are little-endian
(lowest bit first).

| Bits | Field | |
|---|---|---|
| 0-3 | `seq` | sequence number, +1 (mod 16) each time a new event is shown |
| 4-18 | L2 trigger | mode (3), start (4), finish (4), force (4) |
| 19-33 | R2 trigger | same layout |
| 34-41 | `event` | 0 none; 1-127 haptic clip (channels 3-4); 128-255 speaker sound (channels 1-2) |
| 42-44 | `gain` | 0-7: the clip plays at (gain + 1) / 8 of its level x the helper's `--volume` |
| 45-47 | checksum | XOR of the 15 three-bit groups in bits 0-44 (= XOR of data cells 0-14) |

A single wrong bit always fails the checksum.

## Trigger modes

Values are 0-15; the helper maps them to the DualSense's 10 zones (`round(v * 9 / 15)`) and 8
strengths (`1 + round(v * 7 / 15)`).

| Mode | Name | start | finish | force | Effect sent (default) |
|---|---|---|---|---|---|
| 0 | off | | | | 0x05 off |
| 1 | resist | from | | strength | 0x21 feedback |
| 2 | section | from | to | strength | 0x21 with zones from..to only |
| 3 | weapon | click start (zone 2-7) | release (zone 3-8) | strength | 0x25 weapon |
| 4 | vibrate | from | amplitude | frequency (table, 5-200 Hz) | 0x26 vibration |
| 5 | slope | from | full at | end strength | 0x21, strengths rising 1 -> force (progress) |
| 6-7 | (reserved) | | | | off |

With `--legacy-triggers` the helper sends the old raw modes instead (0x01 resistance, 0x02
section / weapon, 0x06 vibration, parameters x17 to 0-255).

## Timing

- Trigger states are **continuous**: the helper applies them when they change (written to the pad
  on change only, at most every 20 ms).
- Events are **edge-triggered by `seq`**: the helper plays the event when `seq` changes. The first
  frame it ever reads (or the first after losing the strip) is a baseline: nothing plays.
- The addon shows each event for **at least 3 frames and at least 50 ms** (so a 60 Hz reader sees
  it on 3 reads at any frame rate), then clears `event` and `gain` to 0 with `seq` unchanged.
  Further events wait in a queue (8 at most; more are dropped).
- The helper acts on a frame once it has read it **twice in a row** (`--confirm 2`), so a single
  misread frame never fires anything.
- No valid strip for 1 s (link off, a menu over it, the window moved): both triggers off. No game
  window for 10 s: the helper resets the triggers, stops audio and exits.

## Event ids

Names match `HelperLink.lua` `K.CLIPS` / `K.SOUNDS` and `helper/clips.py` (the selftest checks).

| Id | Haptic clip | | Id | Speaker sound |
|---|---|---|---|---|
| 1 | micro_tap | 200 Hz, 40 ms, faint | 128 | click |
| 2 | micro_tap_left | left grip only | 129 | coin |
| 3 | micro_tap_right | right grip only | 130 | chime (3 notes) |
| 4 | thump | 75 Hz, decaying | 131 | thud |
| 5 | heartbeat | lub-dub | 132 | heartbeat_thump |
| 6 | crackle | sparse 170-240 Hz grains | 133 | error (buzz) |
| 7 | rumble_rise | 60 -> 110 Hz, swelling | | |
| 8 | release_hit | click + 90 Hz hit | | |
| 9 | swing_light | 160 Hz, left -> right | | |
| 10 | swing_heavy | 90 Hz, left -> right | | |
| 11 | landing_soft | | | |
| 12 | landing_hard | | | |

## Addon API (`ns.HelperLink`)

- `K.SetEnabled(on)`, `K.Enabled()`: saved in `GamepadCompanionHapticsDB.link.on`.
- `K.SetTrigger(side, mode, start, finish, force)`: side `"left"`/`"L2"` or `"right"`/`"R2"`;
  mode a number or a `K.MODES` name.
- `K.Play(event, gain)`: an id or a name from `K.CLIPS` / `K.SOUNDS`; gain 0-7 (default 4).
  Ignored while the link is off.
- `K.SetCellSize(px)`, `K.Encode(state)`, `K.Decode(cells)`.
