# UX: one structure for Gamepad Companion and WoW Helper

v3, 2026-11-16. Owner: the UX session. Feature content belongs to its own session
(setup flow: sounds, HD, the helper's data addon; lights: light editor; WoW Helper main:
gestures; crafting: feel data). This page fixes where things live and what they are called.

## 1. Audit (0.26.0): a player who wants the pad to feel good

First wants: *too strong / too weak*, *turn that buzz off*, *what was that?*, *my colour on the
light bar*, *is WoW Helper working?*

- **Vibration in two tabs.** Rumble (per-moment feels, strength) and Haptics (the old Beta:
  light, feels, editor, mixer, helper, gestures, probes) with floor and ceiling.
- **One moment, three places.** Critical hit: feel on Rumble, light on Haptics › Light, sound
  hard-coded behind a checkbox in Haptics › Helper. Two row widgets for one idea.
- **Two "why did it buzz" lines**, each with its own Debug.
- **Lab next to the light bar colour**: mix, send rate, overdrive, cell size, HD link v1/v2,
  triggers by hand, raw clip buttons, probes.
- **Two editors, one word.** Addon (rumble pulses, L2/R2 recording) and helper (HD layers).
- **Different words.** Try / Feel it / Play / Test steps; Rumble / Haptics / Vibration; Motion /
  Gestures; cues / events.
- **A second tab bar** inside one side tab (Haptics), the only one.
- **The link is off by default** and nothing on the vibration page says so.

## 2. Vocabulary (both programs)

| Word | Means | Not |
|---|---|---|
| **Moment** | something in game: a crit, a landing, a whisper | event, cue |
| **Feel** | a vibration pattern | haptic, rumble pattern, clip |
| **Light** | an effect + colour on the light bar | LED, lightbar |
| **Sound** | a speaker sound | clip |
| **Gesture** | a pad movement that runs an action | motion |
| **Try** | play once, now | Feel it, Play, Test |
| **Default** | back to what it ships with | Reset, Revert |
| **Edit** | open it in the editor (WoW Helper when linked) | Shape, Craft |
| **WoW Helper** | the outside program | helper link, strip |

"HD" is only a badge.

## 3. Addon tabs

```
Controller   buttons, layers, touchpad                    (unchanged)
Moments      what the pad does when: Feel | Light | Sound
Gestures     what each gesture runs
Setup        WoW Helper, the pad's range, light bar base, triggers, timing, battery
Bars · Tools · Help                                       (unchanged; Help rewritten)
Lab          only with Tools › Lab: mixer, live, probes, editor, triggers by hand, link details
```

No Feels tab: the feel picker is the library; Edit opens the addon editor, or WoW Helper once
its data is there.

### Moments (was Rumble + Haptics › Light)

```
 Moments  [ Feel | Light | Sound ]   [✓] On   Strength [−] 60% [+]   [Stop]   Crit · Feel · 3s ago ›
┌ Attacks   8/10 ┐┌ Attacks ───────────────────────────────────────────────────────────┐
│ Defense   9/11 ││ ⚔ Critical hit  ● ♪   [▣ Heavy hit      ▾]   Try  Default  Edit     │
│ Abilities      ││ ⚔ Hit taken     ●     [▣ Thud           ▾]   Try  Default  Edit     │
│ Moving         ││ ...                                                                 │
│ Care           │└─────────────────────────────────────────────────────────────────────┘
│ Weather        │
│ Progress       │
│ Social         │
└────────────────┘
```

- **One kind at a time** (segmented switch), **the same eight groups for every kind**
  (`ns.Moments` puts each light moment in one of them), so the player keeps their place.
- **Marks** after a row's name show its other kinds (● in its light colour, ♪ for a sound);
  clicking a mark switches kind and selects that row. Nothing is hidden by the switch.
- Feel = Rumble's 68; Light = the 21 light moments (Dodge, parry, block is one light moment);
  Sound = always shown: the five built-in sounds today (subtitle "More with WoW Helper"), every
  moment once the setup flow's per-moment sound and WoW Helper's data land.
- Header = that kind's master: Feel: On, Strength, Stop. Light: On, Stop. Sound: On, Volume,
  Stop. One "why" line naming its kind ("Crit · Feel · 3s ago"); click: switches kind and jumps
  to the row. Debug is in Lab.
- **One row widget** (`HUI.MomentRow`, today's `ChoiceRow` generalised): icon, name, marks, a
  plate (opens the kind's picker), Try, Default (greyed when unchanged), Edit. A Light plate
  shows effect + swatch; its picker holds effect, colour and strength.
- **Edit**: with WoW Helper's data, opens the feel in WoW Helper; without it, opens the addon's
  editor (it lives in Lab, opened from the row with a Back button; Lab need not be switched on).
  A player without WoW Helper can still make a feel.
- Edit on Light rows: hidden until WoW Helper has light data (the lights session's editor).
  Sound rows: no Edit (sounds are made in WoW Helper › Sounds).
- Light-only moments (In combat, Spell released, Halo ring open, Interrupted, …) appear only
  under Light; the ● mark on related Feel rows points to them.
- The segment appears with the Light kind (stage 3), never as a one-option control.
- `ns.Moments` maps kinds to saved keys; **no saved key changes** (the helper reads them). The
  moment numbers come from the setup flow's append-only `HelperCues.MOMENTS`.

### Setup (was Pad)

```
┌ WoW Helper ────────────┐ ┌ Range ─────────────────┐ ┌ Base colour ────────────┐
│ [✓] Link               │ │ Faintest  L 4% · R 6%  │ │ Class|Colour|Off  Now ▇ │
│ Run WowHelper.exe      │ │ [Find left][Find right]│ │ ■■■■■ ■■■■■             │
│ Windowed or borderless │ │ Low battery Softer|Same│ │ Brightness [−] 60% [+]  │
│ HD  Auto|Off           │ │ Battery  80%           │ │ Breathe  No|Yes         │
│ Data 18:02 · 14 sounds │ └────────────────────────┘ └─────────────────────────┘
└────────────────────────┘ ┌ Triggers ──────────────┐ ┌ Timing ─────────────────┐
                           │ Cast: R2 tightens      │ │ Footsteps [Sync run][…] │
                           │ Auto shot: R2 clicks   │ │ Mining    [Sync]        │
                           │ Low health: L2 shakes  │ │ Landing   soft – full   │
                           └────────────────────────┘ └─────────────────────────┘
```

- No "running" dot (the strip is one-way). "Data 18:02" once WoW Helper's data addon is read.
- HD Auto = HD while linked over Bluetooth; Off = rumble only. One switch, here only.
- Light On is in Moments (Light) only; Setup has the base colour only.
- Footsteps sync greyed while Footsteps is off. Step rates and nudge: Lab.

### Gestures

Twelve rows of `MomentRow` with the action picker (`ns.Picker`). Row name: the gesture's name
from WoW Helper's data (`gestures = { [3] = "Flick up" }`), else "Gesture 3"; second line the
key (Ctrl Shift Alt F3). Subtitle: "Record in WoW Helper › Gestures". Kept as its own tab: gestures aren't on the pad picture the Controller
page is built around.

### Lab (Tools › Lab)

Mixer, Live graph, Ceiling and Curve per grip, Probes, the addon feel editor (record L2/R2,
import/export), Triggers by hand, Link details (HD link v1/v2, cell size), raw clip and sound
buttons, Debug window. Nothing a player needs.

### Commands

`/gpc rumble` → Moments (Feel), `/gpc light` → Moments (Light), `/gpc beta`, `/gpc haptics`
→ Lab when on, else Moments. All in Help › Commands.

## 4. WoW Helper pages

```
Moments    (setup flow) read-only: recent moments, each moment's feel · light · sound
Feels      list + HD editor
Sounds     Library | From WoW
Lights     (lights session)
Gestures   (was Motion): record, test; each slot's action from the export
Status     link, pad, battery, log; "Waiting for link: Gamepad Companion › Setup"
```

Same words, the same list-left / detail-right shape, the same verbs. The helper finds the WTF
account folder instead of a fixed one (setup flow / main session).

## 5. DRY widgets (addon)

- `HUI.MomentRow` replaces `ChoiceRow`, the Light tab's hand-made rows and the Gestures rows.
- One plate (icon or colour swatch, name, off in red).
- Pickers all on `HUI.Popup`: feels, lights (effect + colour), sounds, actions (`ns.Picker`).
- `HUI.Stepper` / `HUI.Choice` for every level and choice (Rumble's hand-made strength goes).
- One "why" line.

## 6. Stages

1. Shell: tab list, Tools › Lab switch; BetaPage split into Setup, Gestures, Lab.
2. Moments = the Rumble page renamed, `MomentRow`, header master, Edit → editor with Back.
3. Light and Sound kinds (segment, same groups, marks); base colour in Setup.
4. Words; Help; command aliases; tests; 0.27.0.
5. With the setup flow: per-moment sounds, HD badge, Edit → WoW Helper, data line, gesture names.

## 7. Review notes

Round 1 (reviewer, new-player view), taken:
- One plate per row with a kind switch, not three plates (light and sound columns would be
  70-90% blank; lights cover several feel moments at once).
- Strength in the Moments header, not on another tab.
- No Feels tab; editor to Lab until WoW Helper can hand feels back.
- "Pad" next to "Controller" reads the same: Setup. Link first in Setup, no status dot.
- Timing, battery, the USB/HD rule, visible Default, Stop, command aliases, Help rewrite.
- Saved keys never renamed; staged build.

Not taken: Gestures inside Controller (the Controller page is a pad picture; gestures have no
place on it, and a 12-row list needs a page).

Round 2, taken:
- Same eight groups for every kind; marks for a moment's other kinds, clickable.
- Sound segment always shown (five built-in sounds work with just the link).
- Edit always has a place: the addon editor without WoW Helper, WoW Helper with it.
- One control per action: Light On only in Moments; Setup's card is "Base colour".
- Gesture names from WoW Helper's data; the key meanwhile.
- The "why" line names its kind and switches to it; no one-option segment; `/gpc light` in Help.
- UX.md owns layout and words; the setup flow's Screens follow it.

Round 3: **signed off** by the reviewer, with three text fixes applied (the Feels-tab note,
Edit on Light and Sound rows, light-only moments only under Light).
