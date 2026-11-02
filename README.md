# Gamepad Companion

Extra controls for Blizzard's Forever gamepad UI. Version 0.4.1, for build 1.60.1.70338.

## What it does

- **Bar layout.** Move and resize each trigger bar (Base, LT, RT, LT + RT) and the
  stance bar, measured from Blizzard's spot. In Compact mode one "Action bars" entry moves
  all four. Base also carries the 1-2-3 page selector, the shoulder icons and the
  targeting/shortcut bars.
- **Class buttons.** Move and resize the round LB + LT / RB + RT buttons (forms, auras,
  stances, pet menus), and hide the two-icon prompt under them.
- **Spread view.** Lays the four bars side by side, with your form action sets on the
  left, so you can drag spells, items and macros onto them. Spells and Macros open next
  to the window.
- **Camera.** Keeps dynamic camera pitch on and character centring off in the gamepad UI.
- **Window styles** A (controller, default), B (Legacy window) and C (classic):
  `/gpc style A|B|C`.

Open it with `/gpc`. `/gpc help` lists the commands.

## Blizzard Edit Mode does the rest

Since build 70338, Blizzard Edit Mode has real gamepad layouts. Blizzard keeps one active
layout for the keyboard and one for the gamepad, and switches between them by itself. In
the gamepad UI, Edit Mode moves frames and the controller action bar block. That block
has its own settings there:

- Compact Action Bar
- Show Empty Bars
- Button Prompts
- Highlight
- Expand: enlarges the bar you are holding.

Companion's Compact / Standard and Edit Mode buttons open Edit Mode.

Companion's own Edit Mode placement (Save here / Load / Import / Copy and the Layouts
panel) is gone. See [EDIT-MODE.md](EDIT-MODE.md) for how your saved layout became a
Blizzard layout.

Companion's bar offsets are added on top of the block's position in Edit Mode. To move
everything together, use Edit Mode. To move one trigger bar, use Companion.

## Frame Gambit

Frame Gambit decides when bars fade or appear; Companion decides where they are and how
big. Frame Gambit reads bar state through `GamepadCompanionAPI` (see INTEGRATION.md).

## Tests

From the client root, with `lua5.1` or `luajit` (plain `lua` is 5.4 and fails):

```
lua5.1 Interface/AddOns/GamepadCompanion/tests/NativeMigration.lua Interface/AddOns/GamepadCompanion
```

The other suites in `tests/` take the same argument. NativeMigration reads your real
SavedVariables and Blizzard's 70338 Edit Mode files from
`StorageInvestigation/forever-ui-70338`.
