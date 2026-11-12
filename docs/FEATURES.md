# Features

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

- **Touchpad zones** (PlayStation pads, off by default): clicking the touchpad runs what
  the zone under your finger holds (a game window, a spell, an item or a macro), with L2, R2
  and L2 + R2 layers like the crossbar. It works in combat. See "Touchpad zones" below.

Open it with `/gpc`. `/gpc help` lists the commands.

## Tests

From the client root, with `lua5.1` or `luajit` (plain `lua` is 5.4 and fails):

```
lua5.1 Interface/AddOns/GamepadCompanion/tests/NativeMigration.lua Interface/AddOns/GamepadCompanion
```

The other suites in `tests/` take the same argument. NativeMigration reads your real
SavedVariables and Blizzard's 70338 Edit Mode files from
`StorageInvestigation/forever-ui-70338`.
