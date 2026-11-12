# Gamepad Companion

Binds every button of a PlayStation pad in WoW Forever's gamepad UI, adds touchpad zones, and moves and resizes the controller bars.

## Install

Put the `GamepadCompanion` folder in `World of Warcraft\_forever_\Interface\AddOns\`.

## Use

- `/gpc` opens the window. Side tabs: Controller, Rumble, Bars, Tools, Help.
- Controller: click a button on the drawing, then Choose what it runs: spells, items, macros, Halo rings, windows, typed macros. Or drop one on it.
- Hold L2 / R2 to see their layer. The touchpad's zones and settings are on the same page.
- Rumble: the motors on game events and casts, each with its pattern (from Improved Forever: Vibration, MIT; see licenses/).
- Bars: where the controller bars sit, and their size. Offsets from Blizzard's spot.
- Tools: Blizzard's spellbook, macros, Edit Mode and gamepad options; spread view.
- Bindings are per character; a new character starts from a copy.
- Changes made in combat apply after combat.

| Command | Does |
|---|---|
| `/gpc` | Window |
| `/gpc bars` | Bars page |
| `/gpc rumble` | Rumble page (`test`: each motor) |
| `/gpc on`, `/gpc off` | My bar layout or Blizzard's |
| `/gpc reset` | Reset both bar layouts |
| `/gpc gamepad` | Blizzard gamepad options |
| `/gpc edit` | Gamepad Edit Mode layout |
| `/gpc touch` | Controller page, touchpad |
| `/gpc pad` | Controller page |
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
