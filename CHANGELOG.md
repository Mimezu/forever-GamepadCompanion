# Changelog

## Unreleased (0.71.2)

- Spell ranks: a slot the game refused no longer leaves the others behind, and empty bars at login no longer skip a rank
- **Spell ranks**: a pad slot at a spell's top rank moves up to each rank you train. A lower rank stays, whoever put it there. Choose under the Controller card: Rank  < Highest >. Nothing moves on a character's first login
- Fixed: L1 / R1 change tabs in the window (they went to the game's modifier highlight). The pad legend no longer overlaps; L1 / R1 on the controller read "Modifier"
- **Pad in the window**: the window has the pad as soon as it opens, like Blizzard's. L1 / R1 change tabs at once, glyphs by the side tabs; a new tab starts on its first control. Left / right change a value row
- **Hunter**: every hunter spell has its own feel (tests/Hunter.lua lists all 76). Aimed Shot draws the string, then the arrow lands as a shot; Multi-Shot fans two more arrows; stings and Black Arrow creep in after the shot; Concussive and Scatter Shot daze; Volley rains small arrows over both hands; Feign Death drops, Disengage leaps, aspects breathe in
- **Traps**: laid, armed 2 s later, a snap when one springs on an enemy
- **Pet** (new group): arrives, leaves, tamed, attack / follow / stay, its death, eating, happier or less. All fainter than your own. Its crit and a heavy blow on it: off by default. Its plain hits: never felt
- Fixed: your pet's crits played as your Crit, its misses and dodges as yours. Now quiet
- **Dazed** in your own Cheetah or Pack: a wobble
- Hunter defaults: ranged crits on
- **Skyborne**: Walk on Air lifts you; Skysight and Read Leyline a far look. WoW Helper's learned shot, swing, step and gathering timing now applies to a Skyborne (it was kept under race 15 and never read back)
- Fixed: Arcane Shot ranks 2-8 were timed as melee; now as a shot from afar, like rank 1
- Just played names the game's sound WoW Helper adds: the fishing cast's, the reel, your yell on a fall
- Fishing: the cast no longer plays the Gathering sound. With WoW Helper you hear the cast's own whoosh, feel a throw forward, then a small splash as the bobber lands
- Fishing: Fish hooked comes sooner (WoW Helper calls the bite 200 ms into its splash, not 600 ms), and R2 has a light pull the whole time the line is out. The catch no longer ends in a pickaxe-like knock
- Underwater, still: bubbles further apart and softer (swimming unchanged)
- Node compass: the arrows follow your camera. Worked out from the sticks: exact while you move, the right stick while you stand
- **Node compass** (with WoW Helper): while Find Minerals, Herbs or Treasure is on, the strip also sends the minimap (place, zoom, rotation) and your facing. WoW Helper finds the live node dots and points to them
- Fixed: a Judgement right after a seal was sometimes not felt. Your abilities' 0.15 s gap is now per ability, not shared
- Fixed: a blank realm at login made your character a new one, with fresh default profiles ("Alberich 2"). Now it finds your character by name; the stray one is dropped and its profiles stay in the list
- L1 and R1 locked: Blizzard's target bars, on every layer (L1, R1, both together, with L2 / R2). Nothing of ours goes there; saved actions on them drop
- Fixed: Focus UI on a touchpad zone stuck the whole pad on Focus UI. Blizzard functions (Focus UI, Radial) now go on buttons only, where their binding never moves; zones that had one are cleared, with a word in chat
- Gamepad map: Blizzard's again. OpenMap's controller view, turned on earlier in this version, is turned back off once; OpenMap's menu � The map still has it
- No automatic Focus UI chord on the touchpad: L1 + click is zones like any click, and L1 is no longer lent a modifier while a window is open (both broke bindings). Put Focus UI where you like: Choose › Gamepad › Focus UI. A modifier lent by an older version is given back once
- Fixed: the touchpad stuck on Focus UI after L1 + touchpad. 0.67.4's L1 chord (the click rebound while L1 was held) is gone; the zones work as before
- Sound › Social: **Emote voices**, its volume (always the game's own voice)
- Moments opens lighter: a moment's volume chip refreshes with its row, only on screen (it ran for all ~200 rows on every refresh)
- **/gpc perf**: Moments timing, step by step, in chat (on / off)
- Moments opens without the ~0.4 s freeze: a group's rows are built the first time that group shows (all 8 groups x 3 kinds at once were ~200 rows, laid out together on the first show)
- The window opens faster: each page is built the first time it shows, not all on the first open (~0.3 s)
- Fixed: a bar change or a minimap drag with the fishing line out left Interact's reach long. Its record now stays put
- Fixed: Share › Import refused a Controls profile with a rank macro ("Frostbolt(Rank 1)")
- Fixed: the Hush key and chip said "Hush off" while Hush stayed on in a rested area
- Fixed: a looping rumble (without HD) lost its strength after the first cycle
- Fixed: Choose opened on page 1 after an earlier search, not on the current action's page
- Lighter in play: Rumble's settings checked once, not every frame; the touchpad read only when needed; unit events only for you and your target; the L2 / R2 watcher idle without layer actions; food tooltips, footstep timing, sky and sound names kept; the Controller page redraws once per burst; one save per bar move or Undo; unused code gone
- Triggers: the 10 Hz update resolves the stack once at its end, so a tick sends finished values only
- **Mage**: every mage spell its own feel (docs/MAGE.md). Bolts land on the target after their flight; Frost Nova and Arcane Explosion in both hands; Flamestrike erupts, then burns
- Arcane Missiles: one feel per missile, on its tick (haste too); the last a touch firmer. Blizzard: a storm of uneven shards each second
- A mage's spell crit plays its own impact at full
- Skinning: the hide pulled free as it succeeds. Tailoring: bolts of cloth wound and patted down
- Undead female: her own steps (a longer stride) until WoW Helper learns them
- Mage Recommended: Low mana, Enemy casts at you, Aggro on
- Mining: the ore cracking loose is felt firmer than a strike, and plays even when the cast ends a moment early
- Mining with WoW Helper: it plays the strike and the crack from the first cast, not only once it has learned your timing. A timing it learned with no steady second strike is no longer ignored

## 0.69.2 — 2026-11-20

- **Fishing leaves R2's settings alone.** R2 casts and catches through an override binding on R2 itself, which fires while R2 is also the gamepad's Ctrl (checked in game), so R2's modifier (GamePadEmulateCtrl) is no longer switched off while a pole is in hand, and Blizzard's R2 bar keeps paging. A record left by 0.68.0-0.69.1 puts R2 back once at login, then is cleared
- R2's binding never changes mid-press: after the cast, R2 turns into Catch only once you let go of it (read from the pad); after a catch, back to Cast the same way. A change with nothing to change leaves the binding alone

## 0.67.9 — 2026-11-20

- **L2 / R2 layers on L1, R1, L3, R3, Create, Options, PS and Mic, in combat too**: each button Companion runs is bound once to a secure click that reads L2 / R2 at the press (the touchpad's way) and runs that layer's action, Base's when the layer is empty. Nothing is rebound while a trigger is held for these; the bindings change only when the settings do. A key the game leaves free (PS, Mic) works with an empty Base
- A button whose Base is Blizzard's (plain Options: Radial) keeps it. Its L2 / R2 actions, and a Blizzard function (Radial, Focus UI) on a layer, run out of combat, by 0.67.8's watcher, now only for those keys and for a layer that has one. In combat that button runs its Base. The card says "out of combat" for them
- Macro and spell changes no longer rebind the buttons (only their actions change)

## 0.67.8 — 2026-11-20

- Back: L2 / R2 layers on L1, R1, L3, R3, Create, Options, PS and Mic, out of combat (0.67.6's). Blizzard's R2 bar was broken by Halo's chord relay, not by these

## 0.69.1 — 2026-11-20

- **Fishing never leaves R2's modifier changed** (it could break Blizzard's R2 bar). While a pole is in hand R2 stops being the gamepad's Ctrl so it can cast; what it was is now kept for the whole account (it was per character: another character, or a reload while fishing, could leave R2 as None), and put back when the pole comes off, when R2 fishing is off, on every logout and /reload, and at login before anything else. Login fishes again only if a pole is in hand. A record left by 0.68.0 heals at login. If you changed R2 yourself meanwhile, yours stays. Interact's reach goes back the same way

## 0.69.0 — 2026-11-20

- **Emote voices** (Rumble › Social, on): a voiced emote (/laugh, /cheer, /flirt, /joke, /bye, /no, /chicken... 48 in WoW Forever) by you or a player nearby plays the game's own voice on the pad's speaker, for that character's race and sex, the moment the game plays it. A voice only, no rumble; its Try plays your character's laugh. WoW Helper overrides it with a full feel, as any moment
- Who: you, or a player the client knows (target, focus, mouseover, party, raid, nameplates, or its player cache); race or sex unknown, nothing. Which emote: its chat line, matched against the lines WoW Helper reads from the game in your client's language (WowHelperData.emoteVoices). Off with Hush, the speaker's switch, or the moment's
- Sent as WoW Helper's marker 99 (an older WoW Helper ignores it): the emote id in side/gain/intensity/level, race and sex in the seed. Shared vectors: `tests/fixtures/helperlink-emote-vectors.txt`. At login, marker 99 with emote 0 has WoW Helper make your voices ready ahead

## 0.68.1 — 2026-11-20

- Fishing's moments renumbered before anyone used them: Bobber lands 93, **Fish hooked 94, Catch 95** (Catch was 96, which is WoW Helper's footstep marker "running": a catch would have read as a step). Nibbles goes with no number
- **95 is the last moment number**: 96-127 are WoW Helper's markers (footsteps 96-98, emote voices 99, gathering 100-109, swings 110-126). A test now says so. A new moment needs another field on the strip

## 0.67.5 — 2026-11-20

- Underwater bubbles reach WoW Helper: each bubble is an HD cue, so they're felt while WoW Helper drives the pad (before, only without HD)
- Closer bubbles: every 0.3-0.7 s holding still, very faint; the faster you swim, the closer (a fast swim ~0.13-0.3 s) and a little stronger
- Weather taps (rain, snow, sand, embers) send their HD cues the same way

## Unreleased

- Moments opens faster: only the rows on screen refresh (a page holds ~200 rows, a group ~12); the rest refresh as they show

## 0.67.4 — 2026-11-20

- Fixed: L1 + touchpad never ran Focus UI (Forever's gamepad bar keeps L1: no modifier reaches a binding). Now, while L1 is held out of combat, the touchpad click is Focus UI; on release, the zones again
- The touchpad preview: no title (the pad says it)

## 0.67.3 — 2026-11-20

- Fixed: L2, R2 and L2 R2 actions on L1, R1, L3, R3, Create, Options, PS and Mic never ran (Forever's gamepad bar takes L2 / R2 for itself: no Shift or Ctrl reaches the binding). Now, while L2 / R2 is held out of combat, the button runs that layer's action; on release, its base one. In combat: the base action

## 0.68.0 — 2026-11-20

- **Fishing**. A fishing pole in your hands turns R2 into the line: **R2 casts**; while the line is out, **R2 catches** (the game's Interact, on the bobber). The pole off, R2 is yours again (and its Ctrl layer). A short word says so: "R2 casts", "R2 is back". Bindings change out of combat only
- **Choose › Quick use › Fishing pole**: one press, your best pole from the bags (the best you can use); the next, back to the weapons you held. No pole: "No fishing pole in your bags". The same swap is a Halo slice: one shared file, `MimezuFishing.lua`, ships in both addons
- The cast is felt as a cast now (Cast, a new pattern, Fishing's default): the pole drawn back, whipped forward, the line leaving the tip toward the right hand, the spool running out in fine ticks. Its HD feel plays once, not every 1.2 s through the wait. WoW Helper carries the motion on into R2's own motor
- Three new moments under Abilities (93-95), each with its feel, sound and volumes, and overridable with full feels in WoW Helper; Nibbles is an event of its own with no moment number (96 and up are WoW Helper's markers), so WoW Helper can't replace it with a full feel:
  - **Bobber lands** (93): a soft wet knock 1.1 s after the cast. WoW Helper adds the game's own small splash on the pad's speaker
  - **Nibbles**: faint, now and then while you wait (at most three a cast). A stand-in: the game says nothing until the bite, so these never mean anything
  - **Fish hooked** (94): strong. Never sent from here: WoW Forever tells addons nothing when a fish bites (its events, the bobber's soft target and its cursor stay the same). WoW Helper hears the bite's splash and plays it, then R2 tugs and resists like a reel
  - **Catch** (95): the reel winding in, in step with the game's own reel sound, on a fishing loot. WoW Helper plays that sound on the pad's speaker too
- While the line is out, Interact reaches 30 yards (the game's soft target reach is 10; the bobber lands farther). Back as it was when the line comes in
- Trigger shapes 18-21 (Line out, Tug, Reel, Line) are known by name; WoW Helper plays them itself while fishing
- Shared vectors with WoW Helper: `tests/fixtures/helperlink-fishing-vectors.txt`. Tests: `tests/Fishing.lua`

## 0.67.2 — 2026-11-20

- Choose › Gamepad: Radial (Blizzard's radial menu), on any button, like Focus UI: a key binding, not a bar slot

## 0.67.1 — 2026-11-20

- Underwater: the bubbles closer (every 0.45-1.1 s, was 1.2-2.9), still very faint holding still; swimming, closer again (0.3-0.8 s) and a little stronger

## 0.67.0 — 2026-11-20

- **Fall damage**, a new moment (Moving, under Landing). A landing that hurts now plays one cue, not two: the hardest landing, a bit heavier (the thud a quarter longer, an echo more), in place of the landing and of Hit taken
- WoW Helper adds your character's own pain yell on the pad's speaker, the one the game plays, picked at random among that race and sex's takes. Nothing to set up; a full feel made for Fall damage in WoW Helper plays instead
- How it's known: WoW Forever gives addons no combat log, so a fall is a wound on you (UNIT_COMBAT) that arrives just after a fall long enough to hurt (1 s or more below where it began; a jump's own arc doesn't count). Such a landing waits up to half a second for its wound; with none, the landing plays then. Where the combat log is readable, its falling damage says it outright
- The strip: Fall damage's cue (moment 92) carries your race and sex in its seed byte (race id in bits 0-6, female bit 7, as the swing markers already do), so the yell starts with the thud. Hush sends neither. Vectors shared with WoW Helper: `tests/fixtures/helperlink-fall-vectors.txt`

## 0.66.0 — 2026-11-20

- **Triggers: drag to reorder**, as FrameGambit's cards: pick a row up anywhere but its buttons (the `::` grip lights on hover), a copy follows the cursor, the rows close up around the slot it will land in, and the new order is saved on release. Otherwise stays last. The ▲▼ buttons (drawn as empty squares) are gone
- Each row reads left to right on one middle line: grip, On, **+** requirements, the name, then **L2** and **R2** (wider, no longer cut short), Try, Default, ×. Default is on every row, greyed where there is nothing to go back to, so the columns line up
- The name sits on the middle line; a second line (Now, Matches) only when there is one. A rule moved from the old Setup list says **Old rule**
- Otherwise: one **Free** plate across the L2 and R2 columns
- Triggers' left column: **Now R2** and **Now L2** on two lines (names at 14, values at 120, as Strength), Stop under them
- Footer: **WoW Helper · read 00:16** (the time alone, on one line; the full date in its tooltip)

## 0.65.0 — 2026-11-20

- **Gestures: always 12 slots**, one per number (the F key WoW Helper presses). The action stays on its number, so the gesture in WoW Helper and the action here can each change alone
- Each card: its number engraved large, the gesture's name and motion, the action's icon in a round gold socket, the action plate. No gesture at that number in WoW Helper: a small amber reminder, "Record in WoW Helper"
- The record card and the empty state are gone (the 12 slots say it)

## 0.64.1 — 2026-11-20

- Gesture cards: the action's icon, large, in place of the motion drawing (hard to read). The motion stays in words under the name

## 0.64.0 — 2026-11-19

- **The spell on the strip**, for WoW Helper's per-spell feels: a spell row (13 cells, blue first: seq, phase, spell id, CRC-8), three rows up, or from cell 76 on one line (89 cells). Drawn only once WoW Helper says it reads it (`WowHelperData.spellRow`)
- Phases: casting started with the cast's cue, released with the release cue (a channel run to its end too; an instant once), stopped on an interrupt or a cancel; each in the same frame as its cue, or alone at the next frame when no cue went
- A spell id secret in combat (or past 20 bits) goes as 0: the phase only

## 0.63.0 — 2026-11-19

- **Each craft is a moment of its own** under Crafting (`craft:cooking`…, 83-91), as Gathering's actions are: its own feel, sound and volumes, Crafting's until it has its own; nested under Crafting on Moments, sent to WoW Helper with Crafting as parent
- **Smelting** is a craft of its own, known by its smelt casts (Smelt Copper… Elementium) or Mining's window: Bellows, a deep slow heave
- Recommended craft feels, faint and each its own: First Aid has Wrap (cloth wound round, pulled taut), no longer Tailoring's Stitch; Anvil and Punch are softer; every craft has a finish, once as it's made (Quench, Snip, Cinch, Cork, Plated, Clunk, Chime, Tied off, Pour)

## 0.62.0 — 2026-11-19

- Choose › Gamepad › Focus UI: Blizzard's focus on a pad button, a WoW Helper gesture or a touchpad zone
- Zones: out of combat only (the key follows the finger); buttons and gestures work in combat too. Not on bar slots or swipes
- Fixed: a Lua error in the touchpad preview when not on Touch + click

## 0.61.2 — 2026-11-19

- Quick use (food, drink, potions) stays on a bar slot: its macro was deleted at once, as the game reports an item macro's slot as the item

## 0.61.1 — 2026-11-19

- `/gpc touch status` also shows open windows, focus and Blizzard's binding sets: why the click is zones or Blizzard's

## 0.61.0 — 2026-11-19

- Setup › Bags › Bag grid (on): in the gamepad bag the d-pad moves item by item, no wrap, and the cursor returns to the bag after loot. Moved from Gear Glance 2.4.2
- `/gpc nav`: bag cursor log (`clear` to start over)

## 0.60.1 — 2026-11-19

- Setup › HD shows Off, dimmed, while Link is off: no WoW Helper, the game's own rumble
- ✓ and ✗ (Learned, Help's checks) drawn with the game's ready-check icons: its font has no such glyphs, they showed as boxes

## 0.60.0 — 2026-11-19

- **Autorun turns too** (Setup › Camera, on): with Turn Player with Camera on "when moving", the camera now turns the character during autorun too (the game didn't count autorun as moving). Only while autorun is on, through a temporary value the game never saves; your choice is untouched, and changing it mid-autorun is respected. Other choices: nothing changes

## 0.59.4 — 2026-11-19

- One HD switch: Setup › HD. Lab › Link's checkbox, also named "HD", switched the strip to its old format (no light row, so WoW Helper never heard HD was off, and the rumble stayed masked); it's gone, and a strip left on the old format comes back once

## 0.59.3 — 2026-11-19

- Bank: the bank's bar is a child of the bank, as Blizzard's bag bar is of the bags: the bank's scale and layer, shown the moment the bank opens, gone when it closes

## 0.59.2 — 2026-11-19

- Bank: the bag bar's □ now reads **Send to bank** on every item while the bank is open, whatever Blizzard would put there (Use, Equip, Open…); their label again when it closes. It had kept Blizzard's label: the live client keeps its prompts elsewhere than the older UI code 0.58.1 was built from
- Bank: the bank's own bar (Select · Send to bags · Close) is now built with the live client's legend calls; in 0.58.1 it never appeared

## 0.59.1 — 2026-11-19

- HD off now reaches WoW Helper (light row bit 3): with HD feels off, WoW Helper leaves the pad on the game's own rumble, while sounds, lights, triggers and timing keep working. Needs WoW Helper from 2026-11-19 (HD-RELEASE)

## 0.59.0 — 2026-11-19

- **Mailbox: Open All works with the pad.** Blizzard hides the Open All button in gamepad mode, and □ clicks the hidden button: the first item came out, then nothing (its stepper only runs on a shown button). Companion now runs Blizzard's own stepper while the button is hidden: same pacing, COD and GM mail skipped as theirs
- Stops when the mailbox closes; waits out combat; "Bags full" when the bags fill
- Stands down by itself when the button is shown (mouse mode) or once Blizzard fixes it, so nothing opens twice

## 0.58.1 — 2026-11-19

- Bank: the bank gets the bag window's legend bar, Blizzard's own, placed under the bank as theirs is under the bags: ✕ Select · □ Send to bags · ○ Close (□ lit on a bank slot holding an item)
- While the bank is open, the bag bar's □ reads **Send to bank**; Use again once it closes (set after their refresh, nothing written into Blizzard's tables)
- Square sends any bag item, cloth and reagents too (Blizzard's own □ only acts on items it can Use, Equip, Open or Read)
- The 0.58.0 single hint under the bank is gone (the bar replaces it)

## 0.58.0 — 2026-11-19

- **Bank: Square moves the slot under the pad cursor**: a bank slot to the bags, a bag slot to the bank, as a right-click does. The hovered slot works too
- A hint under the bank in Blizzard's own legend: the pad's Square glyph + "Move to bags" / "Move to bank", only on a slot holding an item
- Square (the game's PAD3) is Companion's only while the bank is open and out of combat; it goes back to the game on close and as combat starts

## 0.57.3 — 2026-11-19

- Under HD removed: tested in game, the DualSense plays only WoW Helper's HD while it runs, whatever the game's rumble says; with WoW Helper closed the game's rumble is the backup and should play in full. So the game's rumble always plays at full (full feels' backups too), and nothing doubles

## 0.57.2 — 2026-11-19

- **Lab › Link › Under HD** (0-100 %, as shipped 100 %): how much of the game's own rumble plays while WoW Helper plays HD, for every moment. Only on a PlayStation pad with the link and HD on; any other pad keeps the rumble at full. The triggers' rumble is never touched
- One setting: the full feels' separate faint rule (30 %) is gone; Under HD covers them too

## 0.57.1 — 2026-11-19

- Full feels on an Xbox pad: the plain rumble plays at full. It is faint under HD only on a PlayStation pad with the link on, since WoW Helper plays HD only on a DualSense

## 0.57.0 — 2026-11-19

- **Full feels without a switch**: Lab › Mode is gone. Each moment's active full feel decides: a moment WoW Helper has a full feel for (`WowHelperData.plain`) plays its plain version (faint under HD); every other moment plays as before
- Only those moments show the full feel's name and Edit; every other row is as before
- The old `feelMode` setting is ignored, not rewritten

## 0.56.0 — 2026-11-19

- **Every button takes every action**: bar slots now take Quick use, Halo rings, windows, typed macros and pets too, as the touchpad does (one accept set)
- Such a slot runs a character macro Companion makes (`gpc:q:food`…), with the touchpad's macro text; Quick use bodies follow the picks; the slot shows the action (Quick use · Food), not the macro
- A macro no slot holds any more is deleted; macros Companion didn't make are never touched; "Macros full" leaves the slot as it was. Out of combat only
- The picker's Macros list leaves Companion's own macros out

## 0.55.4 — 2026-11-19

- Lab › Link: Cell size goes down to 1 px

## 0.55.3 — 2026-11-19

- Triggers: the hurt rule (L2 Weight) follows **Low health**, as the heartbeat does: the game's own warning in combat, where health is secret. Since 0.50.0 it read health as a percentage, which can't be read in combat (the source of 0.55.2's errors). Your saved rule moves over once if it was still as shipped; a changed one stays yours

## 0.55.2 — 2026-11-19

- Lights and triggers no longer break in combat: health and movement speed are secret values there, and the stack did math on them (BugGrabber: 6,873 + 11,196 errors in one session). A secret value now reads as unknown; Movement follows the game's start and stop events; one condition failing never stops the others
- The Hush key no longer loads the key-binding header twice

## 0.55.1 — 2026-11-18

- Learned · gathering: Mining reads "1.49 s · then crack" (its second hit is the crack at the cast's end, not a repeat); the timing plate is wider, so it fits

## 0.55.0 — 2026-11-18

- **Full feels** (Lab › Mode: Classic | Full feels; Classic by default, as before): WoW Helper owns what a moment plays, the game keeps when. A moment with WoW Helper's plain version (`WowHelperData.plain`) plays its rumble and bar colour instead of its Classic feel and light; faint (30 %, Recommended) under WoW Helper's HD, so a crashed WoW Helper still leaves a tap. Gathering's actions have Gathering's until they have their own; each mining strike plays it. The strip's moment, touch and sound stay as today, so an older WoW Helper still works
- Full feels: moment rows show the full feel's name and Edit (opens it in WoW Helper); the pickers, Default, Shape, Try and proposals are hidden, not deleted
- Lab › Strip: Stacked | One line (34 + 23 + 19 = 76 cells on one row), one line only once WoW Helper says it reads it (`WowHelperData.stripOneLine`)
- Only new settings are written (`feelMode`, `link.strip`): events, lights, sounds, spells and profiles stay as they are

## 0.54.0 — 2026-11-18

- **Mining, Herbalism, Skinning, Fishing and Opening are moments of their own** under Gathering (`gather:mining`…), as a spell is: each its own feel, sound and volumes, Gathering's until it has its own; nested under Gathering on Moments (Feel and Sound), with Try and in Search
- Each mining strike and the crack play the action's sound with its feel, once a strike, whoever times them (before, only WoW Helper's learned timing had a sound); the gathering marker carries the action's own moment
- WoW Helper's sound proposals for these moments: Accept / Dismiss on their Sound rows
- A group with more moments than fit scrolls with the wheel ("1–12 of 16")

## 0.53.13 — 2026-11-18

- Help › Commands lists `/gpc bars nudge` (move a bar without Edit Mode)

## 0.53.12 — 2026-11-18

- Night review 2, **Addon UI**, the rest:
  - **U2-7**: /gpc opens Start here once (pad or WoW Helper not ready), then your last page: playing without WoW Helper is fine
  - **U2-14**: Setup › Timing no longer repeats hits and mining (Moments › Learned has them): its **Learned ›** opens them; the dead "WoW Helper ›" button and the second Try are gone
  - **UI-7**: Help's Bars picture shows what the topic says (Edit Mode, a bar picked and dragged), no old preview or Compact | Standard; Setup's picture says Read, never Linked
  - **U2-12**: the Edit Mode class-button test now fails on the old maths (its button and page scales differ)
  - docs/PHILOSOPHY.md matches the code: Default (a row) and Reset (a whole thing) both go to Recommended with Undo; "+" for proposals; Again; Edit without WoW Helper; Used by still planned

## 0.53.11 — 2026-11-18

- Night review 2, **Addon UI**:
  - **U2-5**: Undo on a States row works the light or feel out again at once (it waited for the next event)
  - **U2-6**: the group list fits above the footer however many groups there are; Triggers' view lists Triggers alone
  - **U2-17**: a group WoW Helper proposes something in shows "+" by its count (the gold dot means changed)
  - **U2-18**: fewer words: "Pad speaker · WoW Helper", "Off · Blizzard's bars", "Layout blocked", "Faintest feel: just felt"
  - **U2-19**: the Improved Forever line no longer sits over a group button (the status says it)
  - **U2-20**: Again on Just felt says "not here" when it can't play that moment, instead of nothing

## 0.53.10 — 2026-11-18

- Night review 2, **Triggers**:
  - **T2-2 / T2-3**: only the Setup trigger rules you changed move to Moments › Triggers (Alberich: Casting · Both). A rule left as shipped is its Recommended reaction now (Cast tension, Weight); one turned off or removed turns that reaction off; an emptied list keeps every trigger reaction off. Profiles moved by 0.50-0.53.9 are repaired once: the shipped copies go unless changed since
  - **T2-4**: Default (a row's, and the list's) offers Undo for 5 s; the old rules are kept in the profile
  - **T2-7**: hidden cooldowns in combat: no error, no GCD wall. **T2-9**: every 1/100 a gauge moves reaches the pad. **T2-10**: a moved "grow" rule outside a cast is at full strength, as before
  - **T2-12**: a moved rule reads "Resist · old"; the plates read "Weight · Health lost". **T2-13**: Stop ends a trigger Try. **T2-8**: the shape list is built once per WoW Helper list
  - **T2-14**: WoW Helper's 61 generated trigger-row vectors checked here too

## 0.53.9 — 2026-11-18

- **The second night review, haptics** (V-1, H2-5, H2-7…H2-9): the tests now catch a local used before its declaration (Low health's error in 0.53.0): tests/Globals.lua reads every global each file uses, and the test harnesses no longer turn an unknown global into a silent no-op (only game names listed in tests/fixtures/game-globals.txt). It found one more: Try on a Feel row now sends its HD feel too
- Footsteps and mining timing set in Lab before 0.52.3 go, once (nothing was left to clear them): WoW Helper's learned timing applies
- Learned: more nodes than fit scroll ("1–9 of 24"); Try plays the action's own feel (a herb rustles) at its learned first strike and rhythm, a weapon's swing at its learned delay
- Light-only moments go to WoW Helper flagged: it offers no feel or sound for them

## 0.53.8 — 2026-11-18

- **Hush, the second night review** (L2-1…L2-14): a pending Wait no longer spins a timer while hushed, and runs out then instead of starting again after (L2-1, L2-2). The footer chip sits left of WoW Helper with No pad beside it, in the window's colours, and the status line makes room (L2-3)
- **Hush without the mouse** (L2-4): a key binding (Hush), `/gpc hush on | off | resting`, and a Hush button on Feel › States (Off, On, When resting) that the pad's ring reaches
- **Try works while hushed** (L2-5): a light's or a sound's Try is a preview and goes out; Light › States says "Hushed · at rest"
- **The States lists' Default has Undo** (L2-6), says "Recommended", and Undo stays only while nothing changed since
- **Reactions removed in 0.49 or 0.50 stay removed** (L2-7): those versions didn't write removals down, so a Recommended reaction a list from then lacks was removed by you
- **Less work per event** (L2-8): the reactions and their timing are read once until they change
- **Feel › States**: a dragged row lands where it's dropped when the light list is scrolled (L2-9); a reaction you add takes its 50 % at once (L2-10); Hush is offered only there, where it can show (L2-13)
- **The light row's version** comes from WoW Helper's data in every case, a Try's too (L2-12)
- **A moment's light picker** shows one Pass (Light's was the same thing on a moment, L2-14); a state keeps both
- Tests that checked nothing now check something (L2-11)

## 0.53.7 — 2026-11-18

- **Every popover Default has Undo** (night review 2, U2-16): the volume and When steppers' Default offer Undo for 5 s, like the rows
- **When lives on the feel row only** (U2-11): one setting, one place; the sound row no longer has its own copy. Low health's stepper names its limit: hidden health in a fight uses the game's 35 %
- **The When chip** is as wide as its words (Landing's no longer cut, U2-10) and steps aside while WoW Helper proposes something on the row (U2-9)

## 0.53.6 — 2026-11-18

- **The Feel tour stops** (night review 2, U2-8): the same button reads Stop while it plays; closing the window (Esc, the pad's B) or a fight starting stops it. It doesn't start with Feel off, with Improved Forever's vibration on, or in a fight, and Just felt names only what played
- Help › Start here's **Feel it** plays the tour (one control for one thing, U2-15)

## 0.53.5 — 2026-11-18

- Night review 2, Safety:
  - **F2-1**: the pad's ring never clicks a button that runs an action (Edit Mode, Macros, Spells: InsecureActionButtonTemplate, a type attribute): a click from addon code would run them tainted
  - **F2-2**: the window open, the pad still plays: nothing is taken until the d-pad engages the ring; then A, B, X, Y and the d-pad; L2 / R2 only where the page uses them; L1 / R1 never taken (the tabs step on release); another button or the mouse moved gives it all back
  - **F2-7**: L1 + the touchpad (Blizzard's Focus UI) steps no tab. **F2-8**: a popup opened or closed, the focus starts again inside what's in reach
  - **F2-6**: the Undo in reach of the ring; the legend beside it, not over it
  - **F2-4**: a proposal's id as WoW Helper writes it ("12"): a light and a sound stored as numbers, an unknown light refused; written, read back, and only then accepted (a test per kind, with text ids)
  - **F2-3**: Your spells' Default offers Undo (the trigger rows' is the Triggers session's, T2-4)
  - **F2-9**: Search's index built when the field is entered, filtered per key. **F2-10**: Ctrl+F wired on the first show out of combat
  - **F2-12**: WoW Helper's old "use" (a live swap) gone: its picks come as proposals only
  - **F2-11**: the focus test stubs a real action button and fires the combat events

## 0.53.4 — 2026-11-18

- **Undo belongs to its own change** (night review 2, U2-4): a pick on the same row, or a newer message, takes the Undo away, and a stale Undo can no longer put an old choice back over a newer one ("changed since · not undone")

## 0.53.3 — 2026-11-18

- **The palette's hover preview stops** (night review 2, U2-2): hovering a looping feel (Footsteps, Purr, Bandage, Rain…) no longer leaves the pad humming until /reload. The preview plays once, and stops when the pointer leaves, the palette closes or a fight starts
- **The preview plays only as Try would** (U2-3): not with Feel off, not while Improved Forever's vibration is on, never in a fight (Hush already applied)

## 0.53.2 — 2026-11-18

- **Low health plays again** (night review 2, U2-1): 0.53.0 read health before the helper that guards hidden values was defined, so every health change raised an error and Low health never started. A test now fails if it comes back

## 0.53.0 — 2026-11-18

- **When chips:** moments that wait for a level show it under their name: Low health "When: below 35 %", Heartbeat "below 50 %", Out of mana "below 15 %", Landing "soft 0.50 s · full 1.20 s". A click opens a stepper with Default (Landing asks which first). It's part of the moment: a changed level shows the gold dot, the row's Default and Reset group put it back, and it's saved in the Feel profile
- **Low health at your level:** when your health can be read, Low health starts below the level you set (the game's red warning, fixed at 35 %, still decides while health is hidden in a fight)
- **Landing's Soft at / Full at left Setup › Timing:** they're on the Landing row's When chip now (Moments › Moving), with the same saved values
- The levels are data (When.lua), not numbers in the code

## 0.52.10 — 2026-11-18

- **Search** above Moments' groups (**Ctrl+F**): every moment in Feel, Light and Sound, your spells, the States and Triggers lists. Results show as rows, each with its group, kind and choice in grey; a click (or Enter for the first) opens it where it lives; Escape clears. Picking a group steps the results aside
- Reset group sits inside the group card's title band

## 0.52.9 — 2026-11-18

- **What you changed, at a glance:** a gold dot on a moment's name when it differs from Recommended (its choice or its volume), in every kind, Your spells and the States too; a small gold ring by a group's count when anything in it differs
- **Reset group** in each group card's title band: every changed moment there back to Recommended, with Undo for 5 s (greyed when nothing differs)

## 0.52.8 — 2026-11-18

- **Casts reach their own rows:** a cast's cue goes to WoW Helper as Spell casting, Gathering or Crafting (moments 22-24), not as the light-only "Casting" (72), so a sound picked on those rows now plays. A sound picked on the old Casting row moves to Spell casting, once
- **Cancelled and Pushed back have numbers** (76, 77; they went as 0, "?" in WoW Helper's log) and their own sound rows
- **Sound shows no light-only moments:** Critical hit taken is listed once (the light's twin, 69, is gone from Sound), and so are the other moments that only light (In combat, Avoid, Casting, the Halo). WoW Helper reads them as "… (light)"
- Lab's HD switch is named **HD** (was "HD link")

## 0.52.7 — 2026-11-18

- **One meaning of Default:** a moment's Default now goes to Recommended for your class, the same as the Feel profile's Reset. They used to disagree on Hit, Miss, the dodges and parries, Hit taken, Combo points, Out of mana and the other moments Recommended turns off (Default turned them back on). Default's tip and its Undo line say "Recommended". A test checks both agree for every moment, per class.

## 0.52.6 — 2026-11-18

- **The pad in the window** (a focus ring, out of combat): the d-pad moves to the nearest control that way; **A** picks, **B** closes the popup or the window, **X** Try, **Y** Default (the focused row's); **L1 / R1** the side tabs; **L2 / R2** Moments' groups. A legend of glyphs replaces the status line while the pad is in use; the mouse hides it. In a popup the ring stays in it
- In combat the window lets go of the pad entirely: every press is the game's. Out of combat each handled press stops there, every other passes on. Our own ring, not Blizzard's SmartNavigation (its tables taint when written; its grid is derailed by custom widgets; it knows no Try or Default)
- Hooks for pages: gpcTry / gpcDefault on a row, gpcFocusSkip, Focus.SetTrigger, Focus.SetProvider, Focus.OnFocus

## 0.52.5 — 2026-11-18

- **Learned**, in Moments: under Attacks, **Learned · weapons**: the weapon in each hand and every one WoW Helper learned, its hit timing, "Learned ✓ · 40 hits" or "Learning…", Try. Under Abilities, **Learned · gathering**: Mining (and herbs, skinning once learned) with its first strike and rhythm, then each ore or herb it learned from (Copper Vein, Tin Vein…), Try. Read only: WoW Helper owns them (Reset there)
- WoW Helper learns per ore and herb too: each gathering cast tells it the node (by its name; another language than English: per action only)

## 0.52.4 — 2026-11-18

- **The Feel tour**: **Play the tour** on Help › Start here and Help › Moments: footsteps, a swing, a crit, loot, a level up, a whisper, in 25 s, each named in Just felt as it plays
- **Help › Fix it**: Nothing is felt · WoW Helper not read · Sounds silent · Lights stay class colour; each with its checks, live (Pad, Feel on, Link on, Read at login, Sounds on, Light on), and Go there

## 0.52.3 — 2026-11-18

- Night review, haptics (the addon's side): what WoW Helper learned is mirrored at each load (a Reset there goes here too, and is no longer sent back as the addon's own delay); its link latency clears when it no longer publishes one; the hit defaults come from its one table (the copy here only without it)
- Lab no longer sets timing (step rates, the nudge, mining's swing and first strike: WoW Helper's), the floor (Setup's; read here) or Low battery (Setup's); the old USB clip buttons are gone
- A spell's own cue goes without its parent's number (WoW Helper took the spell's sound for "Your abilities"), and its feel plays at its own volume over its parent's
- Markers keep their order; 0.30.0's old hit delays are dropped, not brought back

## 0.52.2 — 2026-11-18

- Lights, after the night review (L1-L16): the mic stays In combat's while you cast in combat (old profiles read in the right order, and repaired); a crit or a kill no longer blanks the mic and dots (a moment leaves them unless you pick Off); the mic goes off with the lights and is sent with the game's lights too; a fresh character starts as Recommended (Default greyed)
- Light row version 1 only to a WoW Helper that reads it (an older one keeps working on version 0)
- States: Wait counts from when a reaction stops; Fade in / Fade out shown only when the game draws the light; each percentage requirement has its own operator and threshold (click the words); the light picker's Dots row wraps
- Basics: the helper's new name for the shapes (LightPresets.lua regenerated from WoW Helper)

## 0.52.1 — 2026-11-18

- Night review, Addon UI:
  - **UI-1, UI-2**: icon paths whole again ("Interface\\Icons\\…"): Choose › Windows and Quick use showed blank tiles, the Triggers card too. A test reads every Lua file for escapes Lua drops
  - **Picker**: Mounts and Pets were always empty (a helper kept only 4 of the journal's values); now listed
  - **UI-3**: a popup never holds the keyboard in combat; Escape still closes it; after the fight it takes Escape and B again
  - **UI-4**: Setup's Faintest feel rows let go of the keys on leave and when a fight starts; a press in combat nudges nothing
  - **UI-5, UI-12**: Lab's Default leaves the faintest feel to Setup; Setup's check climbs no higher than the floor; the result shows what was stored
  - **UI-7**: Help's Bars and Setup topics describe today's controls (Edit Mode, Faintest feel, Resting light)
  - **UI-8, UI-9**: names, not sentences ("Not yet", "First match wins"); **Off** everywhere (no None); the States × says **Remove**
  - **UI-10**: Just felt's tooltip says Just lit / Just played in those views
  - **UI-11**: tests read the icon paths (Windows, Quick use) and run Quick use, Mounts and Pets with the journals stubbed
  - **UI-13**: item info only rescans the bags for our items still unnamed; **UI-14**: the spellbook's count isn't rebuilt on every refresh

## 0.52.0 — 2026-11-18

Bars in Edit Mode, after the night review (B1-B18):
- **Reset layout and Copy from … say so and offer Undo** for 5 s, every bar back (B2); the Edit Mode dialog's Reset turns into Undo for 5 s
- **A click on a bar takes the bar**: our boxes sit above Blizzard's controller-block selection where they overlap; its margin still takes the block (B1)
- **`/gpc bars nudge`**: the bar dialog without Edit Mode (a bar to pick, arrows, Scale, Reset), should Edit Mode misbehave (B3)
- Class buttons move by what you drag at any scale (offsets are in their page's units) (B4)
- After a fight with Edit Mode open, the boxes come back (B5); a fight mid-drag ends the drag cleanly (B6)
- No boxes over hidden bars, nor in the keyboard UI (B7); with My bar layout off the page says Edit Mode shows Blizzard's bars only (B8)
- One Edit Mode button (the Bars page's; Tools' went) (B9, B10); the status says "Ready", not "Bars shown while open" (B11)
- The dialog: "Prompts · both" (one setting for both class buttons) (B15), Escape lets the bar go before Edit Mode closes, a clear corner when the bar fills the middle (B16), stays put while dragged (B17), its spot not saved by the client (B14)
- Headers, docs/EDIT-MODE.md and dead locals (B12, B13); tests: page-unit scales, Blizzard's selection level, the fight, Reset layout's Undo, a hook counter that can fail (B18)

## 0.51.3 — 2026-11-18

- Leftover sentences gone: Bars' "Drag a bar · click it…" (its tooltip keeps it); Tools' notes under Spells, Macros, Edit Mode and Gamepad options (Edit Mode's moves to its tooltip; Gamepad options' limit stays in its tooltip). Spread view keeps its limit line

## 0.51.2 — 2026-11-18

- **WoW Helper's proposals**: a pick made in WoW Helper (Copy, Use for) reaches the game as a proposal, not a live change. After /reload the row reads **Proposed · Coin tap** with **Accept** and **Dismiss**; the group's count shows a gold dot. Accept writes it as your own pick; Dismiss keeps it quiet until WoW Helper proposes another. Reads `WowHelperData.proposals[moment] = { kind, id, name }`

## 0.51.1 — 2026-11-18

- **Shape, always there**: dim when WoW Helper can't take it; a click says "Start WoW Helper · Setup" and the footer's WoW Helper chip brightens once (Lab on: Edit, as before)
- **Sounds with the link off**: one card where the groups go, **Sounds play on the pad's speaker** · Needs WoW Helper · **Setup**, not 60 dim rows
- **Default, then Undo**: "Critical hit: as it ships · **Undo**" for 5 s (its choice and its volume back); the same for States › Default
- **The plate flashes gold** (0.4 s) on Try, Default and a pick
- **Volume as a chip**: "80%" after the plate, a click opens its slider with Default; the plate grows to 200 px
- **Feels hovered 300 ms play faint** (half), once; the pick plays full
- **Again**: a right-click on Just felt plays the last moment once more
- **Groups**: a new **Interface** group (Halo ring open, tick, use, close; Error); Death and Alive in **Defense**; Instant's light with its feel in Attacks. One group per moment across Feel, Light and Sound (a test)

## 0.51.0 — 2026-11-18

- **Hush**: a chip in the footer. Feels at 30 %, the light at rest, triggers free, no sounds. Right-click: also while resting
- **Feel › States**: how strong every feel is, by reaction, like the light's list: Hush 30 %, Resting 30 %, In an instance 50 %, In raid full (the last three off until you turn them on); Otherwise full
- The States lists: "Matches" (was True now); Otherwise right under the rows; "1–11 of 14" and a thumb when there are more; ▲▼ easier to hit
- A reaction shipped later joins your list at its place; one you removed stays removed

## 0.50.1 — 2026-11-18

- **The footer says what it knows**: **WoW Helper · read 18:02** (green: its data file read at login), **not read** (orange), **off** (grey); never "Linked". Setup's WoW Helper card says the same. **No pad** (grey) beside it while the game sees no pad; Try says "No pad"
- **/gpc opens Help › Start here** while the pad or WoW Helper isn't ready; a 4th tile, **Feel it**, plays Critical hit, Loot and Level up one after another
- Setup words: **HD: On / Off** (limit: Bluetooth only); **Faintest feel** (was Range; its sentence gone); **Resting light** (was Base colour) with **Resting: Steady | Breathe | Ember** (Shape is the verb only); WoW Helper card: **Run WowHelper.exe**, the limit "Windowed or borderless"; Timing: a **WoW Helper ›** button instead of its note
- Moments › States: Otherwise reads **Resting light**
- Help › Commands: **/gpc moments** first; /gpc rumble "same as moments"

## 0.49.0 — 2026-11-18

- **States follow FrameGambit's gambits**: Moments › Light › States is a list of reactions, checked top to bottom, the first match wins; **Otherwise** when nothing matches. **+ Add reaction** from the families (Player, Target, Travel, Group & instances, System, Events), **×** removes, drag or ▲▼ to reorder, On / Off
- **Requirements** (+): a reaction can need several conditions, all must be true; ones that can't hold together are refused
- **Percentages**: Health, Power, Target health with Less than … More than (click the words); **events** hold a while and restart (a whisper: 10 s)
- Each reaction sets only its own channels (bar, mic, dots); **Pass** leaves one to the next match. The teal row is the one driving the light now ("Now: Bar, Mic")
- **Fade in, Fade out, Wait** for the whole list (the game's bar cross-fades; Wait keeps a reaction a moment after it stops)
- 0.48's states and their order carry over silently; Default puts the reactions as they ship
- For the triggers next: `Stack.lua` with gauge values and counts (docs/STACK.md)

## 0.48.2 — 2026-11-18

- **Bars: one place, Blizzard's Edit Mode.** The Bars page keeps only what Edit Mode has no place for: My bar layout, a large **Edit in Edit Mode**, the layout in use (Compact or Standard, set in Edit Mode), and the whole layout's Copy from Standard / Compact and Reset layout
- Gone from the page, all in Edit Mode now (0.47): the bar list, the preview, the arrows and steps, X / Y / Scale, the button prompt and each bar's Reset (click a bar in Edit Mode for its scale, prompt and Reset)

## 0.48.1 — 2026-11-18

- Bars in Edit Mode: the dialog no longer sits on the bar you picked. It goes above the bar when there is room, else below, else beside it, else the top right corner, always on screen and never over the bar, so the bar stays easy to grab and drag with the dialog open
- The dialog can be dragged anywhere and keeps that spot for the session (as Blizzard's own); a close button lets the bar go

## 0.48.0 — 2026-11-18

- **Lights stack like FrameGambit's list**: Moments › Light › **States**, top first, the first true one wins: Dead or ghost, Away, Low health, Casting, Halo ring, On flight path, Stealthed, In combat, Swimming, Mounted, Movement, Resting, then **Otherwise** (the base colour). Up / Down, Default for the order
- Each state sets only what it has: the bar, the mic, the dots; **Pass** leaves one to the state below (In combat can light the mic while Movement colours the bar). Moments (crits, spells, whispers) play over it and hand back
- New states are off until you turn them on, so nothing changes by itself; the old mic "In combat" is now the In combat state's mic
- The order is your Feel profile's. Setup › Light's "Resting" row is now "Shape" (Steady, Breathe, Ember)
- One module, `Stack.lua` (docs/STACK.md): triggers will use it next

## 0.47.3 — 2026-11-18

- **Gestures: the square draws the gesture.** WoW Helper's `gestureInfo` (its path, 16 points in -1..1) drawn as a line with a start dot and an end arrow; the subtitle is its motion and mode ("Shake twice · Standard"), or a calm "Not ready". The WoW Helper column's Recognition: On or Off (`gesturesEnabled`). Older data (the names alone) keeps the quiet dot

## 0.47.1 — 2026-11-18

- Bars in Edit Mode follow the suite's Edit Mode pattern (social_diary's toast, Plumber on this client): Edit Mode is listened to, never hooked. Our own boxes in Edit Mode's colours (blue, gold once picked, the name on it), no Blizzard template; a click anywhere else lets ours go (was a hook on Blizzard's pick); a fight ends it

## 0.47.0 — 2026-11-18

- **Bars in Blizzard Edit Mode.** In Edit Mode each bar Companion places (Base, L2, R2, L2 + R2, the compact stack, Stance, the class buttons) has Blizzard's own selection box: click to pick it, drag to move it (it snaps to Edit Mode's grid when Snap is on), arrows and the d-pad nudge it (Shift: 1). Its dialog: Scale, the button prompt (class buttons), Reset. Blizzard still moves the controller bar block; Compact / Expand stay Blizzard's. Values stay Companion's (per Compact / Standard); Blizzard's layouts are never written
- Bars page: an **Edit Mode** button beside My bar layout (the page stays until Edit Mode is confirmed in game)
- Tools: the Edit Mode layouts card (the old one-time conversion: `/gpc edit convert` and `/gpc edit list` remain), the Profiles card (the footer's chips do it) and the Visibility read-out are gone; the window key and minimap icon move up

## 0.46.5 — 2026-11-18

- Timing is WoW Helper's, one place (as the design audit split it): Setup › Timing shows it read-only, in WoW Helper's words ("Learning…", "Learned ✓"); Reset and the one Pad delay are on WoW Helper's Timing card. Hits keep Try. A hit, mining or footstep timing once synced or set here is cleared, once, so what WoW Helper learns applies
- The timing defaults are one table: WoW Helper publishes them (`timingDefaults`: mining's first strike, period and crack; running and walking steps); the addon's own numbers are only its fallback without WoW Helper

## 0.46.4 — 2026-11-18

- **Setup › Range, redone: no reaction time.** Each grip has a slider (Left, Right) that plays the faint feels' micro-tap (33 ms) at its level, every 0.6 s, while you hover it or just after a change: slide down until you can't feel it, then one step up. − and +, the wheel, a click on the track, and while hovered the arrow keys and the d-pad
- **Check** (per side): a yes/no test, one tap at a time, "Felt?" Yes / No / Again; it steps down after a Yes and up after a No, halving the step at each turn, and settles in about 6-10 taps on the lowest level you felt. The slider shows the result to nudge
- "Faint feels start here" says what the floor does. Low battery and the battery stay in the card (hidden while a check runs)
- Find left / Find right and their rising ramp are gone from Setup (Lab's ceiling still uses the ramp)

## 0.46.3 — 2026-11-18

- **Help, a codex**: topics down the left with their glyphs (three new: Touchpad, Profiles, Credits); a topic: a small picture drawn from the addon's own art and widgets, a few numbered points that match the picture's marks, and Go there
  - Pictures: the pad with its parts marked, the touchpad's zones and a swipe, a real moment row (feel, Try, Default) under Feel | Light | Sound, the gesture loop (recorded, keys pressed, the action), the bar slots, Setup's three cards, the footer's chips
  - **Start here** first: Connect the pad, Start WoW Helper, Play, each ticked from the live state and each opening its page
  - **Commands**: a two-column table. Credits: short
- Help moves out of Options.lua into HelpPage.lua

## 0.46.1 — 2026-11-18

- Setup › Timing is a status now: WoW Helper learns by listening, so no Sync buttons. Hits (the weapon in hand), Mining, Footsteps (run, walk): "Learning…", "Learned ✓" (and how many) or "Yours", each with one Reset (back to what WoW Helper learns); Hits keeps Try. The hit delay shows read-only; a nudge by hand is WoW Helper's one Pad delay. Landing's Soft at and Full at stay in the card (not learned: yours)
- Footsteps learned by listening: with the HD link on, the addon tells WoW Helper when a step cycle starts (running, walking, after a landing) and stops; WoW Helper learns the steps' rhythm from their sound (louder on wood or stone) and the addon's footsteps use it from the next load, under a sync of yours
- Wading isn't detected by sound yet: the card says so

## 0.46.0 — 2026-11-18

- **Dots and Mic are light channels**, next to the light bar (WoW Helper draws them): a moment's light picker has a **Dots** row (Off, All, Centre, Pair, Ends, Spark, Fill, Sweep, Ring, 1-5) and a **Mic · orange** row (Off, On, Pulse, Blink); a light of yours made in WoW Helper can keep its own (Light's)
- What the lights did on their own is now each moment's **Recommended**, shown and changeable: Critical hit Spark, Low health Pair and the mic pulsing, Casting Fill, Level up Fill, Whisper and Invites the mic, Ready check All and the mic… Default brings it back
- A moment's Light row says its dots and mic ("Spark", "Pair · Mic pulse")
- Setup › Mic light: the resting mic (Off, In combat, On), the moments that use it, and Moments to set them
- The light row on the strip is version 1 (dots and mic per light): update WoW Helper too

## 0.45.9 — 2026-11-18

- **Gestures, redrawn**: a grid of cards that fills the page, and a WoW Helper column
  - A card: the motion (its path drawn when WoW Helper sends one, else a quiet dot), the name in title case, what it is (WoW Helper's words; nothing when they only repeat the name), the action on its plate with its icon (a lone /sit reads Sit), a quiet × on hover
  - The cards share the page's height: few gestures, tall cards with the motion large; many, compact ones
  - The last card: Record in WoW Helper (none when all 12 slots are taken). No gestures: a calm empty state over the grid
  - WoW Helper column: Link, how many, its gesture mode, and the last 5 gestures that ran (as they run, no polling)
  - Reads WoW Helper's richer gesture data when it comes ({ name, mode, desc, path }); today's names alone still work
- **Joined choices: the highlight sits inside its cell** (it ran under the well's rim): highlight, hover and underline inset 4 px on every side, on every page and skin
- Cards keep their edges when resized

## 0.45.7 — 2026-11-18

- **Bars**, redrawn: one strip for the layout (Compact | Standard, as set in Edit Mode; Copy and Reset layout beside it), then the bars, a **live preview** of the screen, and the picked bar's values
- The preview: every bar of the layout as a box, the picked one gold. Click a box to pick its bar, drag it to move it; arrow keys and the pad's d-pad nudge it while the pointer is over the screen. Arrows and Step 1 / 10 / 50 under it
- One set of values: X and Y typed (their +/- buttons went: the arrows do that), Scale with +/-, the class buttons' prompt, one Reset for the bar
- Gone: the second X / Y readout inside the arrows, and the "Arrows: 10 px · 0.05 scale" line (the arrows never stepped the scale)

## 0.45.6 — 2026-11-18

- **Side tabs: one set of glyphs** in the feel icons' style (a cream line, a dark edge, a green accent): Controller the pad, Moments the pad with waves, Gestures a swipe, Setup sliders, Bars slots, Tools a wrench, Help a book, Lab a flask. Also before each page's name. The open page's glyph bright, hovered a little less, the rest dim; Gilded warms them to gold (its old glyph tiles are gone). Blizzard's tab frame stays. A missing file falls back to the old icon

## 0.45.5 — 2026-11-18

- **One picker a kind, every row:** cast-time spells (Healing, Holy, Fire...) and the Abilities cast rows (Spell casting, Gathering, Crafting) open the Feel picker every moment opens, not a short list of their own. Their sets sit on top as tiles with their icons (Off, the spell's own set as it ships; Match the action and Alerts only on the cast rows), and any feel below can be a cast's: it plays while casting, with the usual alerts if the cast ends badly. A test opens every row's picker in Feel, Light and Sound.
- **Off, not None,** on a feel that plays nothing: a spell the rules leave quiet reads Off, as its picker does, and the picker opens on Off. It's still as it ships (Default stays greyed). Sound keeps None, as its list says.
- **Nothing plays, nothing to set:** a row that's Off (or a sound row on None) hides its volume and Try, in every group and in Your spells.
- **Surge and Blow have icons** (they were blank), drawn like the rest; so has Crit (Impact's). A test fails if any feel in the picker has no icon.
- **Felt at the cast:** Lay on Hands (Crescendo, a full warm swell), Purify and Cleanse (Mend, faint), Will of the Forsaken and Escape Artist (Shock, breaking free), Arcane Torrent (Burst), Cannibalize (Munch). Sense Undead and the self-buff racials (Stoneform, Berserking, Blood Fury, Shadowmeld, Perception) stay quiet, as buffs do.

## 0.45.4 — 2026-11-18

- **Size: 90% or 100%** (Tools header, 90% by default): the whole window at that scale, its popups with it, the action picker too. Saved account-wide (`uiScale`). A small screen still shrinks it further
- **Controller page**: the pad on a full-height card, a 16 px margin all round, centred above the status line (no empty band under it). The touchpad card's first row (Touch zones, Preview, Move) no longer runs together

## 0.45.3 — 2026-11-18

- Choose › More › **Quick use**: Food, Drink, Health potion, Mana potion, Trinket 1, Trinket 2, Random mount, Random pet, for any pad button, zone or gesture
  - Food and drink: conjured first, then the highest level you can use; Well Fed food only when nothing else is left
  - Health potion: a healthstone first, else the best potion; potions chain, so a press uses the next one in the bags
  - Picked out of combat (bags change, combat ends, level up); in combat the last pick stays. The icon shows the pick, or "No food" and the like
- Choose › More › **Mounts** and **Pets**: a chosen mount or companion

## 0.45.2 — 2026-11-18

- **Just felt** replaces the grey line in Moments' header: a small chip with the last moment's icon and name, then its feel, quieter. Light and Sound show what last lit or played (Just lit, Just played). It goes quiet as it ages. A click lists the last 10 with how long ago; each one jumps to its row. Updates as moments play, no polling
- **The skin reaches every control**: buttons, joined choices, search fields and tiles take v2's surface or Gilded's leather (a gold rim on buttons), on every page: Controller, Moments, Gestures, Setup, Bars, Tools, Help, Lab. Controller: the pad drawing sits on a card, the touchpad zones take the skin. The action picker's list, search, tiles and paging too
- **Choose: one tile a spell**: the spellbook lists every rank; the picker shows the highest only (the rank already chosen stays)

## 0.45.1 — 2026-11-18

- Choose › Windows: Forever's windows, from its own bindings and gamepad radial. New: Reputation, Currency, Honor, Legacy, Mounts, Pets, Toys, Who, Raid, Chat Channels, Calendar, Macros, Clock, Shop, Support
- World Map removed (Forever's map is Quests & Map; zones set to it open Quests & Map)
- A window with no button on this client runs its toggle instead (Social did nothing)
- Order: character, then social, then system

## 0.45.0 — 2026-11-18

- **Your spells follows Feel, Light and Sound** like every other group (it showed feels in every view):
  - **Light:** each spell's own light, with the same picker as any moment's (light, colour, strength, Off, Try). Until you pick one, a spell shows the light of the moment it plays in: Instant ability for instants and procs, Spell released for casts.
  - **Sound:** each spell's own sound on the pad's speaker, from the same list as any moment's (built-in and WoW Helper's library), or None, with a volume and Try.
  - A linked spell (Attack, Shoot, gathering) shows its moment's light or sound as a link to its row.
  - **Default** resets only the view you're in: the feel, the light, or the sound and its volume.
  - The count beside Your spells on the left, as for every group.
- **They play:** when a spell lands (at the hit, at the cast, a proc as its wound lands, a cast when it's released), its own light and sound play in place of the moment's. A spell that plays no feel (a heal, or its feel Off) still plays its own light and sound at the cast. A crit keeps the Critical hit light and sound.
- Saved with the spell's feel choice (`GamepadCompanionHapticsDB.spells`: `light`, `sound`, `soundVolume`), so they belong to the Feel profile.
- **Spell released's sound now plays** when a cast (or a channel run to its end) is released; the row was there but nothing sent it.
- One model for all of it: a spell is a moment of its own under the moment it plays in (`spell:instant:Frost Nova`), which Lights, sounds and volumes take like any moment's key.

## 0.44.3 — 2026-11-18

- Every popup closes: a × in its header, Escape, the pad's B (Circle), and for pickers a click anywhere else. The key closes the popup only, not the window under it. One shared behaviour (S.Popup) for the feel picker, the grid popups (sounds, cast sets, trigger rules, profile menus, confirms), the light picker, the action picker, the text window and the trigger test
- Popups take the skin: v2's surface, header band and divider; Gilded's leather, gold rim and gold rule; Blizzard's flat look. They switch with Tools › Skin like the window. The action picker takes the window's background
- The text window's Close, the action picker's Cancel and the trigger test's Close are gone: the × does it

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
