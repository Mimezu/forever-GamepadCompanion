# Touchpad zones

PlayStation pads only. `/gpc touch` (or Touchpad in the options window) opens the Touchpad window.

## Window

- **Touchpad zones**: on or off.
- **Press**: Click, Tap or click (a light tap acts as a click), or Touch + click (each zone has a Touch slot for a light tap and a Click slot for a full click; whole pad only).
- **Over windows** (whole pad): an open window keeps the zones. A zone opens, closes or swaps windows; L1 + touchpad focuses. Off: an open window takes the pad, and its own touchpad uses (search boxes) come back.
- **Pad**: Whole pad (L1 + touchpad does Blizzard's focus) or Right half (left half stays Blizzard's).
- **Grid**: whole pad up to 4 × 3, right half up to 2 × 4.
- **Layer**: Base, L2, R2, L2 + R2, held while clicking. An empty zone does what Base does.
- **Tiles**: click one to select it. Drop a spell, item or macro on it to set it.
- **Swipes**: press, slide and let go. Zones act on release, at the finger's spot then (at the press the game still reports the last touch).
- **Right side**: windows, a dropped spell, item or macro, or typed macro text.

## Commands

| Command | Does |
|---|---|
| `/gpc touch` | Window |
| `/gpc touch status` | State in chat |
| `/gpc touch on`, `off` | Zones on or off |
| `/gpc touch mode chord`, `split` | Whole pad or right half |
| `/gpc touch grid 3 2` | Columns and rows |
| `/gpc touch set r1c2 lt map` | Zone, layer, window |
| `/gpc touch set swipe-up` | Swipe, from the cursor |
| `/gpc touch clear r1c2` | Clear |
| `/gpc touch list`, `windows` | Lists |
| `/gpc touch chord PADRSHOULDER` | Focus chord button |
| `/gpc touch input click`, `tap`, `dual` | Press |
| `/gpc touch set r1c1 touch map` | A zone's Touch slot |
| `/gpc touch raw` | What a tap and a click press |
| `/gpc touch over on`, `off` | Over windows |
| `/gpc touch probe`, `debug on` | What the pad reports |
| `/gpc touch restore` | Off, controller config back |

Zones are `r<row>c<col>`, row 1 at the top. Swipes: `swipe-up`, `swipe-down`, `swipe-left`, `swipe-right`.

## How it works

- A touchpad click presses a secure button. Its snippet reads the finger (`GetGamePadState().sticks[4]`) and the triggers, picks the zone or swipe, and runs that macro. It works in combat.
- Whole pad: `PADBACK` is bound to the button while no window has focus. `CTRL-PADBACK` (L1) stays `TOGGLEUIFOCUS`.
- Touch + click: a gamepad config moves the physical click (raw button 20) to `PAD6`, bound as the button's right click; the halves stay `PADBACK`, the left click, pressed by the game's taps. The touch inside a click is skipped.
- Right half: a gamepad config moves raw button 22 to `PAD6`. Off or `restore` puts your config back.
- Blizzard's core set re-binds `PADBACK`; Companion puts its binding back on top out of combat.
- The game's touch cursor is off while Companion has the pad.
- Steps aside while Improved Forever's touchpad corners are on.
- Settings change in combat apply after combat.
- Method from Improved Forever's touchpad corners (markgravity, MIT).

## Not checked in game

- `PAD6` presses reaching bindings (Right half).
- The finger position at release (swipes) and without a click (preview).
