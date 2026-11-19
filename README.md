# Gamepad Companion

Binds every button of a PlayStation pad in WoW Forever's gamepad UI, adds touchpad zones, and moves and resizes the controller bars.

## Install

Put the `GamepadCompanion` folder in `World of Warcraft\_forever_\Interface\AddOns\`.

## Use

- `/gpc` opens the window. Side tabs: Controller, Moments, Gestures, Setup, Bars, Tools, Help (Lab: Tools › Lab).
- Controller: click a button on the drawing, then Choose what it runs: spells, items, macros, Quick use, Halo rings, windows, pets, typed macros. Every button takes them all. Or drop one on it.
- Hold L2 / R2 to see their layer. The touchpad's zones and settings are on the same page.
- Moments: what the pad does when, as Feel, Light or Sound; each moment Try, Default, Edit. Patterns from Improved Forever: Vibration (MIT; licenses/).
- Gestures: what each WoW Helper gesture runs. Setup: WoW Helper link, range, base colour, triggers, timing. See [UX](docs/UX.md), [Haptics](docs/HAPTICS.md).
- Bars: where the controller bars sit, and their size. Offsets from Blizzard's spot.
- Tools: Blizzard's spellbook, macros, Edit Mode and gamepad options; spread view; window key; minimap icon.
- Also: Esc > Options > AddOns > Gamepad Companion, and the minimap icon.
- Bindings are per character; a new character starts from a copy.
- Changes made in combat apply after combat.

| Command | Does |
|---|---|
| `/gpc` | Window |
| `/gpc bars` | Bars page |
| `/gpc rumble` | Moments (`test`: each motor) |
| `/gpc light` | Moments: Light |
| `/gpc gestures`, `/gpc setup` | Their tab |
| `/gpc lab` | Lab: mixer, editor, probes |
| `/gpc debug` | What vibrates and why |
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
- [Helper: triggers, true haptics, speaker](docs/HELPER.md) · [helper\README](helper/README.md)
- [Adaptive triggers (idea)](docs/ADAPTIVE-TRIGGERS.md)
- [Edit Mode layouts](docs/EDIT-MODE.md)
- [Features and tests](docs/FEATURES.md)
- [Addon API (Frame Gambit)](docs/INTEGRATION.md)
- [Changelog](CHANGELOG.md)
