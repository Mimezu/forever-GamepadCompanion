# From Companion layouts to Blizzard Edit Mode (0.4.0)

Up to 0.3.2, Companion placed frames in the gamepad UI from its own saved snapshots, because
Blizzard could not save a layout for the controller. Build 70338 fixed that:

- Custom layouts carry an input type (keyboard or gamepad).
- Gamepad layouts are reconciled against the gamepad preset, so keyboard bars no longer
  creep back in after a patch.
- The client keeps a separate active layout for each input type and switches by itself.
- The controller action bar is an Edit Mode system (position, Compact, Show Empty Bars,
  Button Prompts, Highlight, Expand).

## What happens to your layout

On each character that had a Companion layout in use, the first time you are in the gamepad
UI, out of combat and outside Edit Mode, Companion does this once:

1. It builds a Blizzard character layout named "<Character> Gamepad" (or "... 2" if the
   name is taken).
   - It starts from Blizzard's gamepad preset.
   - It takes every frame from the gamepad layout you were using, so the controller bar
     block keeps its position and its Compact/Expand settings.
   - It then places every frame your Companion layout saved: position, size, cast bar
     size, chat size, group frame sizes, tracker height, minimap, cooldown viewers.
2. It saves the layout through `C_EditMode.SaveLayouts` and reads it back. The values are
   rounded beforehand the way the client stores them, so the readback matches.
3. It selects the layout as your gamepad layout. (0.4.0 also tried to reload the UI;
   the game blocks that for addons, so 0.4.1 no longer does.)

Every login, out of combat, Companion also checks your other gamepad layouts. Layouts
saved before build 70338 lack the controller action bar system. Edit Mode hides the bar
when the active layout lacks it, and the bar then cannot be selected in Edit Mode. Companion
gives those layouts the gamepad preset's systems, as Blizzard's own patch-time check does.
Frames you moved keep their positions. Keyboard layouts are not touched.

If Blizzard did not keep the selection, Companion says so once and names the layout to
pick in Edit Mode.

If you log in with the keyboard UI, nothing happens until you switch to the gamepad.
Companion does not retry a failed conversion by itself; `/gpc edit` shows why it failed.

Your old Companion layouts stay in `GamepadCompanionEditModeDB` as a backup. The last six
conversions, with the Blizzard layouts as they were before, are kept in `nativeExportHistory`.

## Commands

- `/gpc edit`: what happened on this character.
- `/gpc edit convert [Companion layout]`: make the Blizzard layout again, for example after
  you deleted it. In the gamepad UI it also selects it and reloads.
- `/gpc edit list`: your Companion layouts and Blizzard's gamepad layouts.

## Notes

- A frame Blizzard has no gamepad system for is skipped and named in chat.
- A saved value outside Blizzard's slider range is also named in chat; it keeps Blizzard's
  value. One example: a cooldown viewer opacity captured during a Frame Gambit fade.
- Blizzard keeps 5 character layouts per character. If they are full, delete one in Edit
  Mode, then type `/gpc edit convert`.
- Edit Mode may remember the active layout per specialization (the character cache has one
  slot per spec). If another spec still shows the old layout, select "<Character> Gamepad"
  once in Edit Mode there.
