# Changelog

## 0.13.2 — 2026-11-16

- Beta, Shortest tap: 5 taps per step, "how many felt?", 16 to 75 ms; each tap's real length measured
- Beta, Soft short taps: 33-75 ms at 20-60%
- Beta: Cap 60 fps for the probes (put back on a second click or when the tab closes); answers logged with fps in the Report
- Beta engine: Shortest pulse (Off, 25-50 ms) keeps short taps long enough to be felt; a feel shorter than a frame still plays
- Feels: Dust (33 ms), Graze (40 ms), Feather (50 ms at 50%): the subtle taps

## 0.13.1 — 2026-11-16

- Camera keeps the lower framing after Alt+Z

## 0.13.0 — 2026-11-15

- Beta tab (haptics lab, untested in game): Probes, Calibrate, Feels, Editor, Events, Light, Engine
- Beta engine: one mixer at frame rate (was 0.1 s steps); voices mix and duck; per-side calibration; overdrive; triggers mirror; softer on low battery
- 51 new feels: taps under 0.1 s, grain 8-45 Hz, noise, sparks, detents, curves, pans, rhythms, signals, extremes
- Editor: envelope or keyframes, grain, noise, pan; record a feel by squeezing L2 / R2; share as a line of text
- 33 more events: hits, dodges, kills, combo points, errors, landing, water, mounts, loot, quests, whispers, footsteps, riding, heartbeat by health, cast tension
- Light bar: class colour, cast colour by school, low-health pulse, flashes
- Probes find what the pad really does; answers kept, a report to copy
- Beta engine on: Rumble runs through the mixer and its grid offers the new feels. Off: Rumble unchanged

## 0.12.0 — 2026-11-14

- Window key: a keyboard key opens and closes the window (Key Bindings > Gamepad Companion); set it on Tools or in Settings
- Settings page: Esc > Options > AddOns > Gamepad Companion: Open, /gpc, minimap icon, window key
- Minimap icon: click opens the window, drag round the edge; on/off on Tools or in Settings

## 0.11.1 — 2026-11-12

- Rumble for Halo rings: open a ring, slot change, fire the ring, close the ring (needs Halo 0.9.28)

## 0.11.0 — 2026-11-12

- Rumble page: the motors on game events and casts, ported from Improved Forever: Vibration 0.6.3 (MIT)
- Its 48 patterns, 15 events, cast sets and Match the action / weapon / move; strength; Try; motor test
- Off while Improved Forever: Vibration is loaded; settings per character

## 0.10.0 — 2026-11-12

- One window with side tabs: Controller (main), Bars, Tools, Help
- Bars page redesigned: bar list, arrows and typed values side by side, size and resets
- Tools page: Blizzard's windows, spread view, Edit Mode layouts, profile
- Help is a page; the separate options, help and controller windows are gone
- Window styles A / B / C removed: one Forever look
- L2 / R2 names throughout (was LT / RT)

## 0.9.2 — 2026-11-12

- Touchpad preview: no panel, the pad floats

## 0.9.1 — 2026-11-12

- Touchpad preview restyled: Forever panel, the pad as drawn on the Controller page, glowing finger, fades in and out

## 0.9.0 — 2026-11-12

- Choose: a picker for spells (by spellbook line), items, macros, Halo rings, windows, typed macros
- Bind L1, R1, L3, R3, Create, Options, PS and Mute on every layer
- Halo rings on buttons and touchpad zones
- Bindings are per character; a new character starts from a copy
- The Touchpad window is gone: `/gpc touch` opens the Controller page on the touchpad
- Fixed: L3, R3, Options and the shoulders showed Not bound while the page was open

## 0.8.1 — 2026-11-12

- Controller page: bigger d-pad and face buttons in recessed wells
- Touchpad settings and bindings in the side card; pick a zone on the drawing
- Cleaner button labels

## 0.8.0 — 2026-11-12

- Controller page (`/gpc pad`): the whole DualSense, every bar slot on every layer and page
- Drop, pick up and clear actions on it; other buttons show what they run
- Holding L2 / R2 shows that layer; pressed buttons light up

## 0.7.3 — 2026-11-11

- Tap time: 350 ms by default, 150 to 600

## 0.7.2 — 2026-11-11

- Fixed: Touch + click and Right half said No controller

## 0.7.1 — 2026-11-11

- Fixed: taps ran the middle zone instead of the one tapped
- Taps work out of combat only; clicks work everywhere

## 0.7.0 — 2026-11-11

- Touch + click: a light tap and a full click run different actions
- Press: Click, Tap or click, Touch + click
- `/gpc touch raw` shows what a tap and a click press

## 0.6.5 — 2026-11-11

- Fixed: a swipe also ran a zone (crossing the middle, tap after swipe)

## 0.6.4 — 2026-11-11

- Fixed: a quick press could count as a swipe from the last touch

## 0.6.3 — 2026-11-11

- Fixed: a direct press used the last touch's spot; zones now act on release

## 0.6.2 — 2026-11-11

- Zones work over open windows: same zone closes, another swaps
- Over windows check box, on by default

## 0.6.1 — 2026-11-11

- Fixed: touchpad zones did nothing once a swipe was set
- Fixed: zones stopped after a zone opened a window
- Tap to click: a light touch presses the pad
- Zones whose window isn't found show in red

## 0.6.0 — 2026-11-11

- Touchpad window: `/gpc touch` or the Touchpad button
- Grid of your choice, up to 4 × 3
- Swipe up, down, left and right
- Typed macro text on any zone or swipe
- Drop spells, items and macros on zones

## 0.5.1 — 2026-11-11

- Shorter labels, tooltips, messages and help
- README fits on one screen; details in `docs/`

## 0.5.0 — 2026-11-11

- Touchpad zones for PlayStation pads: open windows, cast spells, use items
- L2, R2 and L2 + R2 layers for the zones
- Mode B: whole pad is zones; L1 + touchpad focuses windows
- Mode A: right half is zones; left half stays Blizzard's
- Finger preview above the crossbar
- Off by default: `/gpc touch on`

## 0.4.3 — 2026-11-05

- Removed the login repair of gamepad layouts; Blizzard does it now
- Fixed: Gamepad options button could break the gamepad UI until reload
- Fixed: `/gpc gamepad` didn't say why it failed

## 0.4.2 — 2026-11-02

- Fixed: class buttons jumped away from their open radial menu

## 0.4.1

- Fixed: controller action bar missing after the layout conversion
- Fixed: conversion's reload was blocked
- Says once which gamepad layout to pick in Edit Mode
- `/gpc edit` shows the gamepad layout in use

## 0.4.0

- Frames now move in Blizzard Edit Mode; Companion's own layouts removed
- Your Companion layout becomes a Blizzard layout once, kept as backup
- Removed Active zoom; use Expand in Edit Mode
- "Edit Mode" button opens Blizzard Edit Mode
- New `/gpc edit convert` and `/gpc edit list`

## 0.3.2

- Compact / Standard now point to Edit Mode, where Blizzard moved the setting
- Companion layouts no longer move the controller bar block

## 0.3.1

- Class buttons keep their spot while the radial menu is open

## 0.3.0

New

- Window styles A, B and C (`/gpc style`)
- Compact / Standard switch Blizzard's compact bar setting
- Enabled is a check box

Changed

- Aligned window rows, shorter help window, new Window styles topic
- `/gpc on`, `/gpc off` confirm in chat; `/gpc help` lists commands

Fixed

- Windows blacked out by Frame Gambit's Cinematic mode
- Unconfirmed typed values stayed on screen
- `/gpc options` opened Blizzard's settings

## 0.2.2

- Spread view in Compact mode shows all 4 bars

## 0.2.1

- `/gpc edit export` makes a Blizzard gamepad layout from your Companion layout

## 0.2.0

- Separate Compact and Standard layouts
- Move, resize and hide the prompt of class buttons
- Rebuilt options window: tabs, reset, copy between layouts, fine steps
- New `/gpc gamepad`

## 0.1.26

- New `/gpc edit native` turns keyboard layouts into gamepad layouts
- Custom layouts saved as gamepad layouts

## 0.1.25

- Stance tab: move and resize the stance bar
- Copy layouts from your other characters
- Imports skip missing frames instead of failing
- Camera keeps dynamic pitch on and centring off
- Less background work when nothing needs it
- Commands accept any capitalization

## 0.1.24

- Form bars stay visible in Frame Gambit's Cinematic mode

## 0.1.23

- Drag spells, items and macros onto form bars
- Form bars use Blizzard's button art

## 0.1.22

- Spread view shows your form bars and names them
- Captions on each bar in Spread view
- Window matches the other Forever addons

## 0.1.21

- Fixed: cooldown viewers blinking with Frame Gambit fades

## 0.1.20

- Fixed: errors from cooldown viewer settings

## 0.1.19

- Fixed: blocked action when restoring cooldown viewers
- New `/gpc edit retry`

## 0.1.18

- New `/gpc edit error` shows the last blocked action

## 0.1.17

- Saves and restores all cooldown viewer settings

## 0.1.16

- Saves the gamepad cast bar's position and size

## 0.1.15

- Objective tracker keeps its saved spot and height

## 0.1.14

- Saves minimap, party frame and objective text settings
- New `/gpc edit recover` restores an overwritten layout
- New `/gpc edit diagnose`

## 0.1.13

- Save and load frame layouts beside Blizzard Edit Mode
- Import from Blizzard layouts

## 0.1.12

- Turned off the Edit Mode integration after a client freeze

## 0.1.11

- Gamepad Edit Mode helper merged in: `/gpc edit`

## 0.1.10

- Macros button opens Blizzard's macro window safely

## 0.1.9

- Spells button opens the spellbook safely

## 0.1.8

- Spread view, with Spells and Macros buttons
- Bars shown while the window is open

## 0.1.7

- Shoulder icons and page numbers stay put during zoom

## 0.1.6

- Shoulder icons centred over the buttons
- Shoulder buttons held, for Frame Gambit conditions

## 0.1.5

- Page selector follows the Base bar

## 0.1.4

- Shoulder art and shortcut bars follow the Base bar

## 0.1.3

- Frame Gambit fades react at once to bar changes

## 0.1.2

- Bar controls and active zoom back

## 0.1.1

- Paused after a blocked action

## First version

- Move and resize each controller bar
- Bigger active bar outside combat
- Bar state for Frame Gambit
