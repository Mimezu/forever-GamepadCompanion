# Touchpad zones

PlayStation pads only. `/gpc touch` (or Touchpad in the options window) opens the Touchpad window.

## Window

- **Touchpad zones**: on or off.
- **Tap to click**: a light touch presses the pad (the game's GamePadTouchTapButtons).
- **Pad**: Whole pad (L1 + touchpad does Blizzard's focus) or Right half (left half stays Blizzard's).
- **Grid**: whole pad up to 4 × 3, right half up to 2 × 4.
- **Layer**: Base, L2, R2, L2 + R2, held while clicking. An empty zone does what Base does.
- **Tiles**: click one to select it. Drop a spell, item or macro on it to set it.
- **Swipes**: press, slide and let go. Once a swipe is set, zones act on release.
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
| `/gpc touch tap on`, `off` | Tap to click |
| `/gpc touch probe`, `debug on` | What the pad reports |
| `/gpc touch restore` | Off, controller config back |

Zones are `r<row>c<col>`, row 1 at the top. Swipes: `swipe-up`, `swipe-down`, `swipe-left`, `swipe-right`.

## How it works

- A touchpad click presses a secure button. Its snippet reads the finger (`GetGamePadState().sticks[4]`) and the triggers, picks the zone or swipe, and runs that macro. It works in combat.
- Whole pad: `PADBACK` is bound to the button while no window has focus. `CTRL-PADBACK` (L1) stays `TOGGLEUIFOCUS`.
- Right half: a gamepad config moves raw button 22 to `PAD6`. Off or `restore` puts your config back.
- Blizzard's core set re-binds `PADBACK`; Companion puts its binding back on top out of combat.
- The game's touch cursor is off while Companion has the pad.
- Steps aside while Improved Forever's touchpad corners are on.
- Settings change in combat apply after combat.
- Method from Improved Forever's touchpad corners (markgravity, MIT).

## Not checked in game

- `PAD6` presses reaching bindings (Right half).
- The finger position at release (swipes) and without a click (preview).
