# Philosophy: Gamepad Companion + WoW Helper

The pad should feel like the world, not like a game menu. It works the moment you plug it in.
Anything you notice, you can change from where you noticed it, and you can always go back.

(From the design audit of 2026-11-18, `Migration/design-audit-2026-11-18.md`. Where the code
doesn't match yet, the audit's migration plan says when it will.)

## Moments
- Everything the pad does is a **moment**: a crit, a landing, the ore breaking loose.
- Every moment is one row. Nothing the pad does should live only in code.
- A moment has **when** (what in the game sets it off, and its thresholds: the When chip) and
  **what plays**: a feel, a sound, a light, a trigger. Any of them can be none.
- Parts of a moment (a cast's release, a pickaxe strike, one spell) are moments too, with
  their own row, inheriting from their parent until they have their own choice.
- Moment numbers sent to WoW Helper are append only: a number is never moved or reused.

## Who decides what
- **Gamepad Companion chooses**: when, which feel, sound, light and trigger, how strong, on or
  off. Per profile, per class.
- **WoW Helper shapes**: what a feel, sound, light or trigger effect is made of, the sound
  library, and the timing it measures on the pad.
- WoW Helper may **propose** a choice ("Use for Loot"); the game accepts it. The helper never
  changes what a moment plays on its own.
- One setting, one place. If both programs show it, one of them only links to the other.

## Defaults
- **Recommended** ships, tuned to be faint, analog and calm, with class touches only where
  they help.
- Then your **profile**, then **your tweaks**. Each layer stores only what differs.
- **Default** means one thing: one row (or one stepper) back to Recommended. **Reset** is the
  same for a whole thing at once: a group, a profile, a bar layout (a layout's Recommended is
  neutral). They agree. Every Default and Reset offers **Undo** for a few seconds, and an Undo
  goes away once something newer changed (Lab's tuning Default is the exception: Lab is a lab).
- Every row that differs from Recommended shows a **gold dot**, its When included; its group's
  count shows a ring. WoW Helper proposing something shows "+", never the dot.
- Nothing needs setup. WoW Helper adds HD feel, sound and light; without it, the pad still
  rumbles well.
- Three tiers, no switch; each moment's active full feel decides:
  - no WoW Helper: the addon's basic rumble;
  - with WoW Helper: its basic HD feels;
  - a full feel made in WoW Helper: that moment plays it (the addon plays its plain version
    faintly underneath). The rest stay as they were.

## Finding things
- **Just felt**: the last moments, in both programs; click one to open it, right-click: **Again**.
- **One search** finds any moment, spell, state, feel, sound or light.
- Every row links: **Shape** opens it in WoW Helper (without it, with Lab on, **Edit** opens
  Lab). Every feel, sound and light should list **Used by**, each name a link (today only the
  mic light does: planned).
- One setting, one place: a moment's When is on its feel row; learned timing is in Moments ›
  Learned (Setup links there).

## Feel
- Faint and short by default; strength is earned by rare, big moments (rhythm and contrast).
- Analog and immersive: real materials, real space. Never gamey, never chiptune.
- Ambient feels step back whenever anything else plays.

## Words
- A few words, Apple-style. One control per action.
- Moment, Feel, Light, Sound, Trigger, Gesture. Try, Default, Shape, Edit, When.
- Strength (the master), Volume (a moment), Level (a sound's own). "HD" is only a badge and
  its switch.
