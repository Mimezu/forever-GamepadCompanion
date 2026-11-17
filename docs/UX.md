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
| **Shape** | open it in WoW Helper to make or refine (HD feel, light sequence, sound) | Edit HD, Craft |
| **Edit** | edit in place, in the same program (the Lab's editor without WoW Helper) | Shape (for that) |
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
- Header = the kind and its On; the left card is the kind's master: Feel: Strength, Try,
  Motors. Light: what the bar shows now. Sound: the link's state. Stop under each. (Sound
  volume: later, with WoW Helper's levels.) One "why" line naming its kind ("Crit · Feel · 3s ago"); click: switches kind and jumps
  to the row. Debug is in Lab.
- **One row widget** (`HUI.MomentRow`, today's `ChoiceRow` generalised): icon, name, marks, a
  plate (opens the kind's picker), Try, Default (greyed when unchanged), Edit. A Light plate
  shows effect + swatch; its picker holds effect, colour and strength.
- **Shape / Edit**: one button, its word follows where it goes. With WoW Helper's data and the
  HD link: **Shape**, opening the moment in WoW Helper. Without: **Edit**, a copy in the addon's
  editor (Lab, with Back). Choose in game, shape in WoW Helper.
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

## 8. Built (0.27.0)

Stages 1-4 in the addon (commits "Tabs for a player…", "Moments: Feel | Light | Sound…",
"Words…"). Stage 5 pieces already live through the setup flow's API: per-moment sounds, Edit →
WoW Helper with its data, Setup's data line, gesture names. WoW Helper's page rename (Motion →
Gestures) is the WoW Helper main session's.

Build review (0.27.0), fixed: Edit falls back to Lab's editor when the link is off; True haptics
has its switch again (Setup › Triggers); reopening never lands on a hidden Lab; Setup no longer
cancels a running sync when closed; a cast's line finds its row; Strength is a shared Stepper;
Light and Sound rows mark their feel; row tooltips per page; Lab's second "why" line removed;
every command in Help. Kept: no "More with WoW Helper" line (every moment can have a sound).

Later: "Edit" → "Shape" on the rows (user, via the vibration session: "choose in game, shape
in WoW Helper"); the label follows its target. (Lab's editor also has a "Shape" form mode:
Lab only, left as is.)

## 9. Your spells (draft v2, 2026-11-17)

The user: a view of the class's abilities and spells showing what each one plays, editable
later, always back to Default.

**Place:** Moments, a group **Your spells** right after Abilities, in every kind (Feel edits;
Light and Sound show the moment's light or sound, read-only, with marks). Not a new tab.
"Spells ›" on the Spell casting and Your abilities rows opens it; the "why" line of a spell
("Fireball · Feel") finds its row.

```
┌ Attacks        ┐┌ Your spells   [Fire] [Frost] [Arcane] [General]          ‹ 1/2 › ┐
│ Defense        ││ 🔥 Fireball      At the cast        [▣ Fire set    ▾] 100%  Default │
│ Abilities      ││ ❄ Frost Nova     At the hit · Guess [▣ Shock       ▾] 100%  Default │
│ Your spells 14 ││ ⚔ Attack         At the hit         [Auto attack ›]                 │
│ Moving …       ││ ✚ Renew          Nothing            [▣ Off         ▾]       Default │
└────────────────┘└────────────────────────────────────────────────────────────────────┘
```

- **One row a spell name** (ranks share it; settings are keyed by name), spellbook order,
  12 a page (‹ › on the pad; page 1 on a new tab). Passives and off-spec out (Picker's
  `SpellLines`). Secret names in combat: rebuilt only out of combat.
- **Second line: when only** — At the hit · At the cast · While channelling · Nothing; plus
  **Guess** when the rules don't know the spell (they guess from name and school).
- **The plate follows the spell's moment:**
  - a cast-time spell (moment `spell`): a **cast set** (the Spell casting row's picker: one
    feel can't stand for build, release and pushback);
  - an instant ability (moment `instant`) or a spell the rules leave quiet (a heal, a buff:
    Nothing): a **feel** (the shared palette, Off first);
  - a spell that belongs to another moment (Attack, Shoot, Mining, crafting, food): a link
    plate, **"<moment> ›"**, read-only, jumping to that row.
- Volume beside the plate (it multiplies the moment's own volume, once); **Default** clears
  the spell's own choice (greyed when it has none). A spell the rules leave quiet reads
  **None**; **Off** only when the player chose it (then Default lights). An Off spell dims its
  read-only Light row too. **Try** only once `V.TrySpell` exists (no stand-in). Crits keep
  the Crit feel (tooltip).
- **Order of who wins:** the moment Off (the spell row dims: "Off: Your abilities") › the
  spell's own choice › the moment's fixed choice › the rules.
- **One source of truth:** `V.SpellPlan(spellID)` returns the **effective** plan, see the
  contract (`spell-plan-proposal.md`); overrides in `SpellOverrides.lua`
  (`db.spells[name] = { on, feel, set, volume }`, only what differs).

Review: round 1 BLOCK (two deciders for one spell, rank keys, overrides skipped by early
returns, timing per spell untrue, Try stand-in); round 2 **SIGN OFF** with Default = clear the
override, None vs Off.

## 10. Profiles (draft v2, 2026-11-17)

The user: defaults that feel good for any class; profiles for controls; profiles for feel
(vibration, light, sound). Other characters must never change Alberich's.

**Three things, each character picks two:**

| | Holds | Where it lives today |
|---|---|---|
| **Recommended** (shipped, read-only) | the calm set tuned on Alberich: Hit off, target's dodge/parry/block off, one heartbeat, combo points off, helper clips off, the earlier impacts, the landing fade; class touches only where needed (combo points for rogue and druid, shots for hunters) | new `Recommended.lua` |
| **Controls** profile | buttons, layers, touchpad, gestures, the Controller page's settings | `GamepadCompanionCharDB` (per character) |
| **Feel** profile | moments (feel, light, sound, volume, on/off), Strength, base colour, spell overrides, landing and steps | `CharDB.vibration` + `HapticsDB` events, lightEvents, lightBase, link.sounds, volume.feel/sound, spells, land*, stepNudge |

**Account-wide:** calibration, mixer, battery, the link and cues, the Sounds volume, learned
timings, your feels library, Lab.

**Storage:** `GamepadCompanionHapticsDB.profiles = { controls = {name = t}, feel = {name = t} }`,
`.use["Name-Realm"] = { controls = name, feel = name }`, `.lastOfClass[CLASS]`. The live tables
stay where the code reads them; a profile is **copied in** at login and on a switch, and
**copied back** at logout, /reload and before a switch. Never shared tables (SavedVariables
split them on reload).

**Migration (once):** a full copy of today's tables to `backup`, first. Alberich-Noir gets
Controls "Alberich" and Feel "Alberich" = exactly today. Any other existing character, at its
first login: its own copies (named after it), never shared. A new character: Recommended for
its class (Feel), its class's last Controls copy or empty (Controls).

**UI:** two chips in the window footer, left of the version: **Controls: Alberich ▾ ·
Feel: Melee ▾**. One menu for both: the profiles (pick = switch) · **New** (from Recommended)
· **Copy** · **Rename** · **Recommended** (reset, asks) · **Delete** (not in use; asks) ·
**Share** (copy a text, or paste one). One text window (`HUI.TextWindow`).
Tools › Profile shows the same two chips (one control each: the footer's are the same widget).
