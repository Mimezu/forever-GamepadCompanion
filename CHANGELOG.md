# Changelog

## 0.44.2 — 2026-11-18

- Mining: the first strike, then the crack on the cast's end (its end time from the game), a little ahead for the pad's delay: the ore cracking loose is felt with its sound. No second strike a period on (it landed before the crack; the game plays no steady second strike). When the cast succeeds, the crack already playing goes on, not again

## 0.44.1 — 2026-11-18

- Mining in time with the pickaxe: WoW Helper heard its strikes at 1.49 s after the cast starts (1.42-1.55 over 20 casts) and again 1.4 s later; the guess was 0.5 s, then every 1 s, so only one strike in three landed near a real one. New guess: 1.49 s, then every 1.4 s
- The pickaxe's HD feel goes with each strike, on the strikes' own clock (it was sent every second from the cast's start, out of step with both the swings and the rumble)
- A first strike later than the marker can carry (1.26 s) goes as "unknown", so WoW Helper uses its own measured guess

## 0.44.0 — 2026-11-18

- **Procs felt as they land:** Wolfsbane's pillar of fire (Blazewind Blast, Holystorm) now has its own feel, **Pillar**: a sharp strike rising into a short rolling rumble. It's faint by default and full on a crit (the proc's own feel, not the Crit feel). It used to play nothing, because you never cast it.
  - WoW Forever gives addons no combat log, so a proc is known only by its wound on your target. A wound counts as a proc when no cast, ability or swing of yours claims it and its school is mixed (two schools or more, like Holystorm) and not one your own spells deal. Your own mixed schools come from WoW Helper's spell kinds.
  - A proc of a single school (fire, holy...) still plays nothing: it can't be told apart from a DoT's tick.
  - Known procs (`V.PROCS`, and `WowHelperData.procs` when WoW Helper writes it) play as themselves. Any other mixed-school proc plays as **Other procs**.
- **Your spells › Procs**, a new last tab: Blazewind Blast and Other procs, each with its feel, Off, a volume, Try and Default. Light and sound follow the Abilities moment, as for any ability.

## 0.43.0 — 2026-11-18

- **Skin: Gilded**, a third choice (Tools › Skin: v2 | Gilded | Blizzard), from Astra's sheet with flat gold glyphs (style-sheet-v2B): cards in dark leather with a thin gold rule, an angled plaque behind each page's name, gold glyph tiles on the side tabs and page names (Controller, Moments, Gestures, Setup, Bars, Help; Tools and Lab keep theirs), joined choices filled with gold, switches with a gold knob and rim. Blizzard's native frame and close button stay; the feel icons are unchanged
- Skins switch at once; whatever a skin doesn't draw falls back to the flat look
- `Media\gilded-*`: ten 32-bit TGAs (tiles 128, plaque 64 in three pieces, leather 256)

## 0.42.0 — 2026-11-18

- **Skin v2** (the default): calm textures inside Blizzard's own frame, made with Astra from your feel icons and hand-finished (flat, neutral, seamless): a near-black background, a quiet card surface, a faint header strip under each page's name, a thin gold divider under card titles. The native frame, borders, close button, side tabs and every feel icon are unchanged
- **Tools › Skin: v2 | Blizzard**, at once, no reload. A texture that fails to load leaves today's flat look
- `Media\`: four 32-bit TGAs (256 × 256, 256 × 256, 256 × 32, 256 × 4), 564 KB

## 0.41.0 — 2026-11-18

A visual pass (two critiques, one iteration): richer look, same simplicity.

- **Switches** for every on / off: a rounded track, a knob, gold when on
- **Joined choices**: a row of choices is one control (one well, dividers, the chosen one filled and underlined): Feel | Light | Sound, layers, pages, touch input and mode, and every choice row
- **Value tracks**: a stepper shows where its value sits in its range (a click on the track sets it); a list shows pips
- **Depth**: cards with a warm title band, a soft shadow and a gradient; Setup's cards with an icon; headings with a fading rule; every other moment row warmer, a hover, a bar in its state's colour (a light's own colour on Light)
- **The shell**: each page's name with its tab's icon; pages, popups and group panels fade in; the status with a dot (green: done, orange: warning, grey: a state); a **WoW Helper** dot in the footer (linked, not read, off) that opens Setup
- Light swatches update 20 times a second instead of every frame

## 0.40.0 — 2026-11-17

- **Gestures, redesigned**: only the gestures that exist (recorded in WoW Helper, or given an action), one calm card; each its name, its action's icon, the action on its plate (**Choose** when there's none, never a red Off), and a quiet **×** to take it off. The key chord WoW Helper presses is only in the plate's tooltip. No gestures yet: "No gestures yet · Record them in WoW Helper › Gestures"
- Sweep of the pages the passes left behind: Controller's status says a state, not "Drag: pick up · Drop: bind"; **Touch zones** (was "Zones") and the zone editor dims while they're off; its tooltips name their buttons; Tools in few words ("While this window is open", "Shown by Blizzard"); the rumble patterns' credit moved from Moments to Help › Credits; Setup's Base colour card hugs its content

## 0.39.2 — 2026-11-17

- Long names: a label cut short (a 40-letter spell on a plate, a row's name) shows in full on hover
- Long lists: a picker with more than 12 rows pages ("‹ 5/6 ›"), opening on the chosen one's page (a 200-sound library no longer runs off screen)
- docs/UX.md opens with the taste checklist every UI pass starts from

## 0.39.1 — 2026-11-17

- Spell table: a fear or a taunt around you (Psychic Scream, Challenging Shout) plays Burst, as agreed, before the control rule (Psychic Scream would have played Shock)

## 0.39.0 — 2026-11-17

- Spell coverage (every class's spells checked): stuns and interrupts with no hit (Sap, Cheap Shot, Kidney Shot, Hammer of Justice, Concussion Blow, Bash, Disarm, Counterspell, Repentance, Sweeping Strikes, Blade Flurry) are felt as you cast them; a dodge or parry of one still shows. They no longer take the next swing's feel
- Quiet: routine debuffs and DoTs (Rend, Sunder and Expose Armor, Garrote, Rupture, Rip, Slice and Dice, curses, Shadow Word: Pain, Corruption, Hunter's Mark, Faerie Fire...), single taunts, Pick Pocket, Distract, Feint
- Summons: harmful ones on the ground (Searing, Magma, Earthbind Totem, traps, Flare) Surge; pets and creatures (Call Pet, Shadowfiend...) a short Ritual; helpful totems nothing
- Damaging casts (Fireball, Frostbolt, Shadow Bolt, Smite...): the release is silent, the spell is felt as it lands: the next wound of its school on your target (Judgement for holy and arcane, Shock for the others)
- An ability we know nothing of no longer takes a swing or a pet's blow: only a magic wound. Hit no longer plays for every wound on your target (DoT ticks, pets, the party): only your swings and abilities. One blow is no longer felt twice (Your abilities and Hit)
- Ready for WoW Helper's spell table (`WowHelperData.spellKinds`): what each spell does, its school and a channel's tick, for every spell without a list

## 0.38.0 — 2026-11-17

- **Your spells** shows: each spell's row says what plays for it (at the hit, at the cast, while channelling, nothing), its feel or cast set, and why, from the very rule that plays it (`V.SpellPlan`, one code path)
- A spell's own choice plays: Off plays nothing (no cast, no interrupted either); another feel or cast set replaces the rule's; its volume scales it once, over the moment's. A heal or buff given a feel plays at the cast. Try plays it
- Fix: a looping moment (a cast, eating) at a volume under 100% lost its shape and stopped playing; now it keeps it at that volume

## 0.37.0 — 2026-11-17

Release UI pass: two reviews (a new player, a UI designer), fixes, a re-check (docs/UX-AUDIT.md).

- Tabs always in one order: Controller, Moments, Gestures, Setup, Bars, Tools, Help (Lab last)
- **Edit** only with Tools › Lab or WoW Helper, and your own copy opens again instead of a second one
- Plain words everywhere a player looks: Try names the moment (no "rumble (HD link off)"), "Detail" (was HD), "Not read yet", "Feel off", "Base colour", "As it ships", "Synced / Not synced"; no "Game / WoW Helper" on each light, no ticking seconds on the last moment, no "Guess"
- Setup: both columns line up; **USB feels** on the WoW Helper card (was "True haptics" among the triggers); the hit delay labelled; "Battery —" when unknown
- Profile menus: plain words, open upward from the footer; "Class start"; "Back to Recommended?"
- Gestures: cards hug their rows; the footer status no longer runs under the chips; Help › Profiles rewritten

## 0.36.0 — 2026-11-17

- **Profiles.** Each character uses a **Controls** profile (buttons, layers, touchpad, gestures, bars) and a **Feel** profile (moments: feel, light, sound, volume, on or off; Strength; base colour; your spells; landing and steps; trigger cues), by name, account-wide. Two chips in the window's footer, each with its menu: switch (reloads), New, Copy, Rename, For new <class>, Reset, Delete, Share (a text to copy, or paste one to add it). The pad's own settings stay account-wide: calibration, mixer, battery, the link, the Sounds volume, learned timings, your feels
- **Recommended**: a new character's Feel starts calm (no Hit, no target dodges, parries, blocks, one heartbeat, no combo points except rogues and druids, no helper clips), or from the profile its class starts from
- **Nothing changes for an existing character**: at its first login it gets its own Controls and Feel, named after it, exactly as before (Alberich: "Alberich" × 2). The account's settings as they were are kept in `profiles.before`; `/gpc profiles restore` puts them back
- Live = the profile: the places the code reads point at the character's profiles from the first load; at logout only the profiles are saved. Design reviewed three times (signed off); tests for migration, isolation across saves, a load without a name, a logout that never ran; a dry run on the real saved files matched exactly
- The text window (export, names, Share) is one shared widget

## 0.35.0 — 2026-11-17

- **Your spells** (Moments, after Abilities): your spellbook by tab, a row a spell name (ranks share it), 11 a page. Each says when it is felt (At the hit, At the cast, While channelling, Nothing; Guess when the rules don't know it) and what plays: a cast set for a cast-time spell, a feel for an instant or a quiet spell (a heal: None), a link to its moment for Attack, Shoot, gathering, crafting, food. Pick your own, Off, a volume; Default goes back to the rules. Saved by name in `spells` (`SpellOverrides.lua`)
- Shown once the rules answer per spell (`V.SpellPlan` in Rumble.lua, contract in docs/UX.md §9); the play path then honours your choices. Design reviewed twice (signed off)

## 0.34.1 — 2026-11-17

- Your abilities: Consecration and other ground effects with no direct hit (totems, traps, Blizzard-like rains) are felt as you cast them, with a new feel, **Surge**: a firm low push into the ground, then a warm spread to both sides. Their later ticks add nothing. (Consecration waited for a direct hit that never comes.) No ember pulse while it burns: whether you're still in it can't be tracked reliably

## 0.34.0 — 2026-11-17

- WoW Helper learns gathering strikes while you gather: with the HD link on, mining, herbalism and skinning send a marker as the cast starts, succeeds and stops. WoW Helper hears the tool, learns the first strike and the rhythm, and once it knows them plays each strike in HD itself (the addon sends no HD for that cast)
- Its learned strikes come back at load (`WowHelperData.strikeTiming`) for the rumble's mining strikes: above the guess, under a sync or a setting of yours. Setup › Timing › Mining says "learned · 30"

## 0.33.3 — 2026-11-17

- Swings were late: WoW Helper heard a two-hander's impact 0.165 s after the swing's news (24 hits), not the 0.35 s guessed. New defaults, all melee scaled alike (x0.47): two-hand 0.165, polearm 0.15, staff 0.14, one-hand 0.12, dagger, fist, unarmed and forms 0.095. Ranged stays 0 (the shot's news is its release)
- A saved hit timing equal to an old guess (kept by touching the control) is cleared, once, so the new default and WoW Helper's learned values apply; a value you chose stays

## 0.33.2 — 2026-11-17

- Your abilities: any attack ability you use that lands on your target is felt, even one not in the lists (Forever's new ones, Holy Strike): its family from its name (Holy, Arcane, Judgement: a bright strike; Shadow, Frost, Fire, Bolt: a shock; Strike: a heavy strike; Slam, Bash: a bash; Stab; Cleave) or, when the name says nothing, from its damage's school, else Blow. A weapon strike lands at the weapon's impact, a shot at the ranged timing. Heals and buffs never (the game's helpful-spell check). An unknown one now waits 0.5 s for its result (was 0.4)

## 0.33.1 — 2026-11-17

- Swings a few ms late: the rumble is now sent 30 ms early for the game's own delay (up to a frame, then Bluetooth), and, with WoW Helper on, by its published link delay, 30 ms until it publishes one (none was published, so nothing was taken off). Hits, shots, abilities, footsteps and mining strikes; the impact defaults unchanged

## 0.33.0 — 2026-11-17

- WoW Helper learns your hit timing while you fight: with the HD link on, each melee swing and shot sends a marker the moment its news arrives (the weapon type and hand, your race and sex, the addon's delay, the result). WoW Helper hears the impact, learns each weapon's delay, and plays the blow's HD feel itself at the impact it learned; the addon doesn't send that cue again
- Its learned delays come back at load (`WowHelperData.hitOffsets`) for the rumble too: above the guesses, under a value you set or synced. Setup › Timing › Hits says "learned · 42" (hits heard)
- WoW Helper's measured link delay (`linkLatency`), when it writes one, is applied

## 0.32.1 — 2026-11-17

- Fight log: the last 600 moments kept in the saved settings (`GamepadCompanionHapticsDB.fightLog`, written on /reload and logout): seconds since login, the moment, its feel, rumble or rumble+HD, the gain, and why it played (the game event, or "swing hit main hand +0.25" at a blow's impact); combat on (with the target's name) and off between them

## 0.32.0 — 2026-11-17

- **Your abilities** (Attacks; was Abilities, "Match the move"): your own attack abilities felt as they land on your target, at the blow, each its own: Match the ability. A heavy strike (Heroic Strike, Mortal Strike), a stab (Sinister Strike, Backstab), a bash (Shield Bash, Hammer of Justice), a sweep (Cleave, Whirlwind), a bright strike (Judgement, Arcane Shot), **Blow** (new) for any other. Paired with your own cast: others' damage, pets' and DoT ticks never set it off
- A crit plays the Crit feel; a miss, dodge, parry or block on your target its own moment, at the same blow. Seals, shouts, shields still play as you use them
- Heroic Strike, Cleave, Maul, Raptor Strike: the swing they ride on is felt as the ability, not a plain swing. Arcane Shot is an ability now (was a plain shot)
- The ability's Now line shows its feel

## 0.31.5 — 2026-11-17

- Landings under your real jump (Setup › Timing › Landing, "Soft at"): quieter and quieter the shorter the drop, eased, down to a faint tap for a step down a stair (30% of a real jump's landing), never silent, never above a real jump, no step at the minimum. The rumble, WoW Helper's HD cue (gain and intensity), its sound and clip all fade alike; a drop into water too. Drops from 0.08 s count (were 0.25 s); real jumps unchanged

## 0.31.4 — 2026-11-16

- Looping moments (casts and channels, Hearthstone, eating, drinking, low health): their HD feel through WoW Helper plays again each cycle while the loop lasts, in step with the rumble (was once at the start, then silent). A cast swells toward its end (intensity 4, as designed, to 6); a cancelled or interrupted cast stops at once. Volumes as before

## 0.31.3 — 2026-11-16

- Critical hit (melee and ranged): its own feel, **Crit**: a hard, sharp strike with a short bright ring, above any plain hit (was Tick, shared with Halo open). A saved Tick moves once; a feel picked by hand stays

## 0.31.2 — 2026-11-16

- New defaults after WoW Helper's HD strength pass (your own picks untouched): **Low mana** plays Alert (it shared Dive with Death; a saved Dive that was only the old default moves once); **Mount** and **Dismount** at 50% volume. Money was already Coin
- A row's Default resets its volume too
- Checked: on a landed swing, Auto attack (graze) and Hit (strike) stack at the one impact by design; the engine's own Hit stays quiet while Rumble claims the swing, so no double

## 0.31.1 — 2026-11-16

- Hit sync says what it sees, live: "swings 4 · squeezes 3 · paired 2"; "Can't read R2 from the pad" when the triggers give nothing; both lists logged on every squeeze (`timing.log`)
- Easier to finish: five pairs; one stray squeeze left out; a hand's wander up to about 120 ms kept. Uneven keeps listening (the oldest squeezes give way) instead of starting over
- Setup › Timing › Hits: **Try** (the next six swings each play your weapon's swing at the impact, even with Auto attack off) and the seconds in 20 ms steps: earlier / later by feel, no squeezing

## 0.31.0 — 2026-11-16

- **Sync pass** (docs/TIMING.md): every moment checked against the animation or sound it stands for; one place for the timing (`Timing.lua`)
- Hits: the impact offset per model (race, sex, druid form), kind of weapon and hand (main, off, ranged), and in proportion when attacks come faster than the animation. Defaults per weapon; your sync or setting on top; a slot for values WoW Helper learns
- Hit sync: a squeeze may come before or after the swing's news (pairs with the nearest); six, the median, refused if uneven; the feels stay quiet while you squeeze; the raw pairs kept (`timing.log`)
- Extra attacks (Windfury, Sword Specialization) and parry-hasted swings count as swings; Heroic Strike, Cleave, Maul and Raptor Strike's blow is the swing
- Footsteps and mining strikes: each starts on the frame it begins and plays whole (a slow frame no longer shortens or drops one)
- Mount and dismount: on the frame they happen (were up to 100 ms late)
- One sync for footsteps, mining and hits (starting one stops another)
- WoW Helper's link delay: `Timing.SetLinkLatency` takes it off delayed hits and runs the step and strike clocks that much ahead, while WoW Helper is on

## 0.30.2 — 2026-11-16

- A sound added in WoW Helper (ids 1000+) now plays: Try on Moments › Sound sends it as the moment's sound (it went out as an HD feel id and played nothing). In play it already did
- The link's two kinds of id never mix again: K.Play is for the built-in touch clips only (1-127), K.PlaySound for sounds (built-in names or WoW Helper's ids), HD feels through K.PlayFeel and the moment cue

## 0.30.1 — 2026-11-16

- **Try** plays a moment as the game does: with WoW Helper linked and HD on (Setup › WoW Helper: Auto), its HD feel goes to WoW Helper on top of the rumble, as one cue with the moment's number and volume (it was the rumble alone). The footer says what played: "Level up: rumble + HD", "rumble + HD draft" (no crafted HD version yet), or "rumble (link off)", "(HD link off)", "(HD off)"
- Moments › Sound › Try: the moment's cue at its volume, as in play; the footer names the sound
- Moments › Light › Try: the footer says who drew it, "WoW Helper" or "game light"
- Moments › Feel › Strength › Try: the pulse in HD too

## 0.30.0 — 2026-11-16

- Weapon hits at the impact, not the swing's start: the game tells of a swing as its animation starts, so each swing's feel (and its WoW Helper cue and clip) now waits for the blow to land, by kind of weapon: dagger, fist, unarmed 0.20 s, one-hand 0.25, staff 0.30, polearm 0.32, two-hand 0.35; ranged shots 0 (fired at the release). A guess until set
- A swing's result keeps its own feel at that moment: a crit the crit's, a parry, block, dodge or miss on your target the Beta engine's (Target parries...), a hit the swing and Hit
- Setup › Timing › **Hits**: the delay for the weapon in hand, and **Sync**: attack and squeeze R2 on each impact you hear; six squeezes, the median kept for that weapon (shooting: for ranged)

## 0.29.3 — 2026-11-16

- Blocks and parries sharp (were "too subtle and fluid"): no faint lead-in, no fading taps after. A parry is two crisp hits, strike then ring (Parry, Clash); a block one dense hit (Block, Shield thud). Each as strong and as long as before. Dodges unchanged

## 0.29.2 — 2026-11-16

- `/gpc water` (temporary probe): each second, every signal the client might give for water (IsSubmerged and IsSwimming with and without a unit, falling, flying, indoors, outdoors, speeds, position, mirror timers), printed and kept in the saved settings (`waterProbe`). `/gpc water dry`, `wading`, `swim` label the lines; `/gpc water` again stops. To find what tells shallow water apart, since Wading never started in game

## 0.29.1 — 2026-11-16

- Auto attack: a feel only for a melee swing that really lands (hit, miss, dodge, parry, block), from UNIT_COMBAT on your target (the combat log's `SWING_*` where readable). Turning auto attack on out of range, turned away or at a dead target plays nothing (was a timer from the moment auto attack went on). Main or off hand: the one due by weapon speed; a blow too soon for either hand, a spell's wound, a blow just after an ability, or anything while shooting is not a swing. WoW Helper's swing clips and HD feels follow, as they ride on the same event
- Shooting: unchanged, already one feel per shot fired (the shot spell's `UNIT_SPELLCAST_SUCCEEDED`); Auto Shot turned on alone plays nothing

## 0.29.0 — 2026-11-16

- **Volumes.** Each moment has its own volume beside its plate, 0-100%, full by default: Feel rows for its vibration (the game's motors and WoW Helper's HD feel), Sound rows for its sound. Moments › Sound: **Volume** for every sound, with Try (Vibration's is Strength, Moments › Feel). Saved in `volume` (`Volume.lua`)
- Sounds were tied to the vibration's strength (80% sent them at 6 of 7); now full unless turned down, and WoW Helper shapes each sound's own level
- To WoW Helper: a cue's `gain` is its sound's volume when it has a sound, else its feel's; the HD feel's strength rides in `intensity` (4 = as designed). WoW Helper applies `gain` to the speaker from its next version

## 0.28.0 — 2026-11-16

- **Lights are sequences now**, one light model shared with WoW Helper (C:\games\WowHelper\docs\LIGHTS.md): bar keys (colour, brightness, ease), player LEDs, the mic; once, or while it lasts (a loop; Casting builds with the cast bar). 32 crafted presets (`LightPresets.lua`, generated by WoW Helper): every moment its own, shapes (Flash, Glint, Double, Pulse, Glow, Heartbeat, Rainbow), resting (Steady, Breathe, Ember). Faint by default; brightness is perceptual
- **One light picker** on a moment's Light plate: the lights that fit it (playing in their tiles), its colour (School only on spells), its strength in 8 steps, Off, Try. Your own lights from WoW Helper (*Yours*) after a /reload
- **Link on: WoW Helper draws the lights**, every lane, smoothly, on a second row of the corner strip; the game sets only the steady colour under it (never clears it). Link off: the game plays the bar as before. Each plate says which: WoW Helper or Game
- Setup › **Light**: resting light (Steady, Breathe, Ember), colour, brightness, **Mic** (off, on in combat, on; WoW Helper only)
- Old light settings move over once (each moment's own light, or the shape it had; strength to 8 steps)
- New files: restart WoW once (not just /reload)

## 0.27.0 — 2026-11-16

- **New tabs, no Beta:** Controller · **Moments** · **Gestures** · **Setup** · Bars · Tools · Help. **Lab** (mixer, live graph, probes, the feel editor, link details, Debug) only with Tools › Lab. Old keys and commands still work (`/gpc rumble`, `/gpc beta`). Plan and review notes: [docs/UX.md](docs/UX.md)
- **Moments** (was Rumble + Haptics › Light): Feel | Light | Sound in the header, the same eight groups for each. One row everywhere: plate, Try, Default, Edit, and marks for the moment's other kinds (click: there). A light: effect, then colour, and a level. A sound: per moment (WoW Helper's sounds once its data is read), None, Default. The last-moment line, top right, finds its row
- **Edit** opens the feel in WoW Helper once its data is there, else a copy in Lab's editor, with Back
- **Setup**: WoW Helper (Link, HD Auto | Off, its data), range (Find left / right: the faintest felt), low battery, battery, base colour, trigger cues, timing (footsteps and mining sync, landing)
- **Gestures**: its own tab; names from WoW Helper's data when there
- Words: Moment, Feel, Light, Sound, Gesture; Try, Default, Edit everywhere (Feel it, Reset gone)
- `/gpc light`, `/gpc gestures`, `/gpc setup`, `/gpc lab`

## 0.26.0 — 2026-11-16

- **Wading** (Moving): footsteps in shallow water, their own event and switch, on by default (land Footsteps stay off). Each step a faint wet slap and a fainter spray, on the Steps timing. Shallow water = `IsSubmerged()` and not swimming: untested in this client, so `/gpc debug` shows a Water line (wading / submerged / swimming)
- Landing in water: shallow water splashes instead of the thud; a jump into deep water plays one splash, scaled by the air time (no thud, no second Into water). A landing waits one frame for the swim to start
- Mining: a short firm knock and a faint ring on each swing, timed from the cast's start, and a crack when the ore breaks loose (was a 150 ms hit at 90% looping on its own clock: a plain rumble). Swing and first strike on the Rumble tab (Steps and landing → Mining), a guess (1.00 s, first 0.50 s) until set or synced (squeeze R2 on each strike, over a cast or two). Gathering's Try plays a vein mined
- The gathering spell names are looked up again until all are known (a name not loaded at login no longer turns mining into a plain spell for the session)

## 0.25.0 — 2026-11-16

- Gestures (Haptics tab): twelve slots for WoW Helper's motion gestures, each a spell, item, macro, window, Halo ring or typed macro (`/dance`) from the Choose picker. The helper presses Ctrl+Shift+Alt+F1-F12; bound per character, out of combat

## 0.24.1 — 2026-11-16

- Export: the game's sound kits by name (`soundkits`), for WoW Helper's list of WoW sounds

## 0.24.0 — 2026-11-16

- Helper link protocol v2 (the default): the wide strip, 34 cells, CRC-8; clips and sounds in their own fields; HD feels by id, side and intensity; the mic LED. Checked against WoW Helper's 81 vectors. **HD link** off on the Helper card goes back to v1
- Every feel has a stable HD id (128-4095), written in the export (`feels[key].hd`)
- Cue group **HD feels** (off by default): each event's feel sent to the helper by its id

## 0.23.0 — 2026-11-16

- Touchpad, chord mode: L1 + touchpad is Focus UI while a window is open, even when L1 is no modifier of its own: a free modifier (Alt) is lent to L1 while a gamepad window is open and given back when it closes (L1 alone does nothing meanwhile); plain touches and the click stay zones

## 0.22.6 — 2026-11-16

- Touchpad preview movable: Move on the Controller page's touchpad panel shows it, drag it anywhere, Done (or closing the page) ends; its place is kept

## 0.22.5 — 2026-11-16

- Controller: double-click a layer row (Every layer) to open Choose for that layer (touchpad zones, buttons, bar slots)

## 0.22.4 — 2026-11-16

- Rain: drops closer together again (as faint)

## 0.22.3 — 2026-11-16

- Rain subtler still: about half again as strong, drops further apart

## 0.22.2 — 2026-11-16

- Helper link: the strip in the bottom-left corner; the helper is now WowHelper.exe (C:\games\WowHelper); the Helper page says so

## 0.22.1 — 2026-11-16

- The battery is now the minimap icon: the controller's charge drawn in it (green to red, critical blinking, wired in blue); click opens the window, drag moves it round the minimap; its tooltip names the level. The separate gauge is gone

## 0.22.0 — 2026-11-16

- Battery gauge: the controller's charge in a small battery, top centre (drag it anywhere; hides with the interface): four steps coloured green to red, critical blinking, wired in blue; /gpc battery shows or hides it

## 0.21.2 — 2026-11-16

- Rain gentler: half as strong, sparser, less boost when heavy; thunder softer
- Weather and water step aside: while anything else plays (a jump, a hit...), they dip to a tenth

## 0.21.1 — 2026-11-16

- The feel library and each event's choice written out for the helper (GamepadCompanionHapticsDB.export, on logout and /reload), to draft the HD versions (docs/HD-HAPTICS.md)

## 0.21.0 — 2026-11-16

- One system: the engine is always on (its switch is gone); the Beta tab is now Haptics (light, feels, editor, tuning, helper, probes; /gpc haptics)
- Debug window and headers name things by their group ("Moving · Jump: Micro tick"), no longer Beta or Rumble; the arrow that showed as a box is gone

## 0.20.2 — 2026-11-16

- Weather from the game itself: C_Weather.GetCurrentWeather and WEATHER_CHANGED (in the client, unlisted; the wardrobe's outfit conditions use them). Rain, heavy rain with thunder, snow, sandstorm, outdoors; denser and a little stronger when heavier. On again by default; embers stay by zone, off
- Debug window: what the game reports (type and intensity) for a weather voice; the Probes report shows the raw values

## 0.20.1 — 2026-11-16

- Weather by zone off by default (and switched off once): the game tells addons no weather, so it "rained" in sunshine; still there to switch on, labelled by zone, not the sky

## 0.20.0 — 2026-11-16

- Rumble tab: every vibration in one place. Strength and the motors, then 8 groups (Attacks, Defense, Abilities, Moving, Care, Weather, Progress, Social) and Steps and landing; Rumble's events, the Beta engine's and the cast sets side by side
- Each row: its feel from the one palette (Off and Match the... first, then every feel by group), Try, Default (the feel it ships with), Edit (a copy of your own, assigned, open in the editor)
- Debug button and the latest reason in the Rumble tab's header
- Beta tab: Events moved to the Rumble tab; Feels is the palette with a preview, Play, Loop, Edit a copy

## 0.19.0 — 2026-11-16

- Debug window (Beta header, /gpc debug): see-through, stays up while playing: both motors and the light bar now, every vibration and light playing with its reason, the last cues; the Beta header shows the latest reason
- New events: your hit, your miss; the target dodges, parries, blocks; you dodge, parry, block apart; missed you; bandage (while it lasts), potion; underwater (while your breath runs); weather by zone, outdoors: rain, thunder, snow, sand, embers (the game tells addons no weather)
- New bespoke feels for each (Combat, Nature groups); events regrouped: Attacks, Defense, Abilities, Moving, Care, Weather, Progress, Social
- One palette: Rumble's own patterns are in the feel library too (Basics, Moves, Weapons, Spells, Crafts), usable on any event; the picker is the grouped palette with big tiles, Off first

## 0.18.0 — 2026-11-16

- Helper (first version, untested with the pad): an outside program (helper\, Python 3.12, no installs) reading a few pixels the addon draws top left, for what the game can't drive: adaptive triggers, true haptics and the speaker (USB)
- Cues: a cast tightens R2 until released, auto shot clicks R2, low health shakes L2; clips for crits, releases, landings, swings; sounds for loot, quests, errors, whispers; each group on or off
- Beta, Helper page: link on, cell size, cues, both triggers by hand, every clip and sound to try

## 0.17.0 — 2026-11-16

- Light: a real feature. A base colour (class, one of 10, or off; brightness; breathing) and 21 light events, each with its effect (flash, base brighter, double blink, strobe, fade, rainbow; glow, build up, heartbeat, breathe while it lasts), colour (base, spell school or one of 10) and strength
- Light choreography: a crit flashes the base colour bright, a cast glows and builds in its school's colour then flashes on release, low health beats red, level up runs a rainbow, a whisper blinks purple; lights play whether or not the event vibrates
- Beta tab redesigned after the Rumble tab: Events and Light by group, each row with its icon, its choice on a plate opening a grid (Off first), and Try; Engine and Calibrate one Tune page; Steps and landing a group of Events
- Light on by default

## 0.16.1 — 2026-11-16

- Rumble, Auto attack: every swing, on the weapon's swing timer, main hand (leaning right) and off hand (left, softer)
- Auto attack: Match the weapon: dagger, fist, light slash (sword), chop (axe), knock (mace) faint and quick; heavy slash, heavy chop, thud (two-handed mace), sweep (polearm) long

## 0.16.0 — 2026-11-16

- Rumble patterns retuned for rhythm and contrast (with the Beta engine): faint micro taps for small things, long rumbles for big ones, professions and spells as rhythms; the old steps stay for when the engine is off
- Spell casts: the family's faint rhythm building up, the release a long hit trailing off in taps; channels a pulse per tick; fishing, eating and drinking as pulses
- Shapes run every frame (were 20 a second, a 50 ms tap could be skipped)
- Beta engine on by default

## 0.15.3 — 2026-11-16

- Beta, landing: the lightest 30% barely there (4% to 8%), then steep to full

## 0.15.2 — 2026-11-16

- Beta, landing: more contrast: a hop is a faint micro tap (about 7%), strength rises steeply toward heavy landings; a light landing shrinks the chosen feel instead of playing it whole

## 0.15.1 — 2026-11-16

- Controller: holding L2 shows the L2 layer, R2 the R2 layer (L2 showed R2, R2 nothing: the pad's buttons were read one off)
- Controller: pressed buttons light the right button
- Controller: a trigger held when the window closed no longer sticks on reopening

## 0.15.0 — 2026-11-16

- Beta, feels retuned for rhythm and contrast: very faint 50 ms micro taps (5-30%) against long rumbles (0.2-0.5 s), often in one feel (taps leading into a rumble, a rumble trailing off in taps)
- Beta, live voices: footsteps and riding fainter, heartbeat a longer lub and a faint dub, cast tension fainter; a hop's landing fainter
- Shared feels keep 6 digits (was 4)

## 0.14.9 — 2026-11-16

- Beta engine: back to sending every frame by default (10/s made everything long; landing now takes its length from its own settings)

## 0.14.8 — 2026-11-16

- Beta, landing: a full landing plays the chosen feel's strongest pulse at full (Flick's 80% went out at 74%)

## 0.14.7 — 2026-11-16

- Beta, landing: any feel chosen for Landing is stretched with the landing's weight (up to Landing longest), not only the default Thud; the readout names the feel played

## 0.14.6 — 2026-11-16

- Beta engine: feels read every frame, sends limited (10/s by default): a vibration starting goes out at once (none missed), changes and stops wait for the next send, so each pulse lasts at least a send's interval (felt much stronger in game)

## 0.14.5 — 2026-11-16

- Beta, landing: the heaviest reach full output whatever Rumble's strength (a light one still follows it); the card shows what was sent (peak and length)

## 0.14.4 — 2026-11-16

- Beta, landing: heavier is longer too (a hop 60 ms, a full landing up to 0.4 s, centred), with longer echoes; Landing longest setting

## 0.14.3 — 2026-11-16

- Beta, Steps and landing (Events): Run steps and Walk steps per second, set by hand from the sync
- Beta, landing: Soft at and Full at (air time), 0.5 to 1.2 s by default (was 0.55 to 2.35, so a jump was always soft); the last landing's air time and strength shown

## 0.14.2 — 2026-11-16

- Beta, Footsteps sync: Sync run and Sync walk apart, each with its own result; a walk sync done running (or the reverse) is refused
- Beta, footsteps: switching walk and run while moving starts the new gait's cycle; walking's own guess until synced

## 0.14.1 — 2026-11-16

- Beta, footsteps: in time with the run, counted from the moment you start moving (and from each landing)
- Beta, Footsteps sync (Events): run and squeeze R2 on each footfall; your step rate and timing saved per race and sex, walking and running apart; Nudge to fine-tune
- Beta, landing: checked every frame; a hop is a soft short pulse, a fall stronger and longer with echoes, a big drop a boom; air times in the Report

## 0.14.0 — 2026-11-16

- Beta: feels rebuilt as rhythms of pulses (each 50 ms or more, with its own strength and side), from the probe results: 54 feels in Taps, Doubles, Rolls, Impacts, Motion, Life, Signals, Extremes
- Beta, live voices (heartbeat, footsteps, riding, cast tension): fixed-length pulses at any speed
- Beta, editor: Pulses mode (click to add, drag for time and strength, wheel for length, side of new pulses); converts to and from Keys and Shape
- Beta, Record L2 R2: tap a rhythm, each squeeze a pulse on its side, as deep as you pressed

## 0.13.5 — 2026-11-16

- Beta, Overdrive probe redone: count 5 taps, plain against kicked (15 ms at full first), 25-40 ms
- Beta, Wobble probe: strength going up and down without switching off, 3 to 25 Hz
- Results so far in docs/HAPTICS.md: trigger channels do nothing on a DualSense; fast on / off is felt as pulses, never a buzz

## 0.13.4 — 2026-11-16

- Beta, Trigger test (Probes): a window; each squeeze of L2 or R2 plays the next of 7 variations on that side (trigger full, while held, one tap, pulses, soft, grip check, both); mark each Trigger, Grip or Nothing; live L2 / R2 depth; in the Report
- Each channel: grips only now
- Update rate: answers Separate pulses, Rough buzz, Steady no flicker, Nothing (asked again)

## 0.13.3 — 2026-11-16

- Beta, from the probe results: taps held to 50 ms by default (shorter ones were felt only sometimes); no floor on either grip (5% felt on both)
- Taps 50 ms and soft (Pin, Dust, Graze, Feather, Clicks, Ready); detents at 5 Hz or under (faster felt as a buzz)
- Probes: a what-to-do line on each; tap lengths no longer copied onto other probes

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
