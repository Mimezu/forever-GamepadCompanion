# Gamepad Companion

Moves and resizes the controller action bars and class buttons in WoW Forever's gamepad UI, and adds touchpad zones for PlayStation pads.

## Install

Put the `GamepadCompanion` folder in `World of Warcraft\_forever_\Interface\AddOns\`.

## Use

- `/gpc` opens the window. Pick a bar tab, then move it with the arrows.
- Offsets are measured from Blizzard's spot. The whole bar block moves in Blizzard Edit Mode.
- Compact or Standard is a Blizzard setting: Edit Mode > controller bar > Compact Action Bar.
- Spread view shows all 4 bars side by side, for dragging spells onto them.
- Changes made in combat apply after combat.
- `/gpc touch` opens the Touchpad window: zones, grid, swipes, what each runs.

| Command | Does |
|---|---|
| `/gpc` | Window |
| `/gpc on`, `/gpc off` | My layout or Blizzard's |
| `/gpc reset` | Reset both layouts |
| `/gpc style A`, `B`, `C` | Window style |
| `/gpc gamepad` | Blizzard gamepad options |
| `/gpc edit` | Gamepad Edit Mode layout |
| `/gpc touch` | Touchpad window |
| `/gpc help` | Commands in chat |

## Data

`WTF\Account\<account>\SavedVariables\GamepadCompanion.lua`

## Tests

From the client root, with `lua5.1`:

```
lua5.1 Interface/AddOns/GamepadCompanion/tests/NativeMigration.lua Interface/AddOns/GamepadCompanion
```

## More

- [Touchpad zones](docs/TOUCHPAD.md)
- [Edit Mode layouts](docs/EDIT-MODE.md)
- [Features and tests](docs/FEATURES.md)
- [Addon API (Frame Gambit)](docs/INTEGRATION.md)
- [Changelog](CHANGELOG.md)
