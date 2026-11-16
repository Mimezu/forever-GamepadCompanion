# Haptics: where Rumble stands, and how far it can go

Analysis, 2026-11-15 (GPC 0.12.0).

## 0. Built in 0.13.0: the Beta tab (untested in game)

Everything in sections 3 and 4 that needs no outside program, behind one switch
(**Beta engine**, top right of the tab, off by default):

| Section | What | Code |
|---|---|---|
| Probes | 10 probes (section 6 and more), each step played raw, answers saved; **Report** gives text to paste back | `HapticsLab.lua` `L.PROBES` |
| Calibrate | floor / ceiling / curve per grip, found with a rising ramp | `Haptics.lua` `H.Calibrated` |
| Feels | 51 library feels in 9 groups; click plays, Shift loops, right-click edits a copy | `HapticsLab.lua` `LIB` |
| Editor | envelope or keyframes, grain, noise, sparks, pan, kick, duck; draw keys on the canvas; **Record L2 R2**; Export / Import a line | `BetaPage.lua` |
| Events | 33 more events, each with a feel (live ones: footsteps, riding, heartbeat by health, cast tension) | `HapticsLab.lua` `L.EVENTS` |
| Light | class colour, cast colour by school, low-health pulse, level up / kill / whisper / hit flashes | `HapticsLab.lua` `L.LIGHTS` |
| Engine | mix mode, send rate, resend, overdrive, triggers mirror, battery; live graph and sends per second | `Haptics.lua` driver |

With the engine on, Rumble's own patterns go through the mixer (its calibration
replaces `HIGH_FLOOR`) and Rumble's grid lists the beta feels (`x_` keys). Off,
Rumble is exactly as before. Saved in `GamepadCompanionHapticsDB` (account).

**First in game:** Probes (all ten, then Report), then Calibrate, then the Feels
groups Taps and Grain: they tell us whether short taps and fast grain survive the
pad's rumble emulation, which decides what to keep.

## 0.1 Probe results, 2026-11-16 (Windows, DualSense, 100 fps)

| Probe | Result | So |
|---|---|---|
| Shortest tap (5 each) | real 20-30 ms: 1-2 of 5; 31-53 ms: 3-4; 49 ms and more: 5 | the pad needs ~45-50 ms; not frame jitter |
| Soft short taps | 50 ms at 35%: 5; 75 ms at 20%: 5; 33 ms at 35%: 1-2 | length decides, not strength: subtle = 50 ms and soft |
| Hold, sent once | faded (60% and 100%) | keep re-sending (0.1 s) |
| Update rate | 5 Hz: pulses; 10-60 Hz: buzz | ticks at 5 Hz or under; faster is texture |
| Stopping | set to 0 and Stop: both clean | either |
| Channels | Low = left, High = right; triggers not answered | trigger types: still unknown |
| Weak levels | 5% felt on both grips | no floor (the right's 0.5 was the Mac's) |
| Top end | 60 / 80 / 100% each stronger | full range usable |
| Left vs right | left stronger at 50% and 100% | right is the lighter motor |
| Light bar | red, green, blue seen | SetLedColor works |
| User | loves the subtle short taps | build the subtle vocabulary on 50 ms, low strength |

| Triggers (squeeze test) | every trigger-only variation: nothing; trigger and grip: grip only | LTrigger / RTrigger do nothing on a DualSense: trigger effects need the helper |
| Update rate (asked again) | 5 to 60 Hz: countable pulses, even when very close | no blending: on / off never becomes a buzz; texture must come another way |
| Overdrive (first version) | mostly only B felt (15 ms full, then 40%), A (40 ms at 40%) missed | a kick may save short soft taps: counted in 0.13.5 |
| Overdrive (5 taps each) | 25 ms: 1-2 plain, 3-4 kicked; 33 ms: 3-4 plain, 1-2 kicked; 40 ms at 25%: 1-2 plain, 3-4 kicked; 8 ms kick: 3-4 | a little help at best, within the noise of 5 taps: not a fix; 50 ms stays the floor |
| Wobble (30-100%, never off) | 3 to 25 Hz: nearly steady, "very slightly varying" | while running, strength changes are smoothed away; only on / off edges are crisp |

**What this pad is, through the game:** a drum, not a speaker. What you feel is
pulses of 50 ms or more: their rhythm, their side, and how strong each one starts.
Changing the strength of a vibration that is already running (swells, wobble,
grain, noise) mostly flattens out. Triggers: nothing. Light bar: works. So the
vocabulary is rhythms of short soft pulses (what the player liked), placed left /
right, plus the light bar; curves and textures need the helper (true haptics).

Applied in 0.13.3: Shortest pulse 50 ms and no floor by default; taps 50 ms and soft;
detents at 5 Hz or under. Still open: 60 fps run, triggers, overdrive.

## 1. What we do today

Engine (`Rumble.lua`), all through one call: `C_GamePad.SetVibration("Low"|"High", 0..1)`.

| Piece | How it works | Limit |
|---|---|---|
| Patterns (57) | steps `{low, high, seconds}`, each step >= 0.1 s, re-sent every 0.1 s by `C_Timer` | 10 Hz grid: no grain finer than 100 ms |
| Shaper | `OnUpdate`, a function of time, sent every 0.05 s | 20 Hz; only casts, channels, release, fishing, eat/drink |
| Strength | one linear gain (`intensity`) | no per-motor curve |
| Right motor | any value > 0 lifted to 0.5..1 (`HIGH_FLOOR`) | half its range thrown away; the left has no floor at all (values 0.05-0.15 in Frost, Hearth, Draw, Hex are likely unfelt) |
| Stereo | pan in Sweep, Arcane, Cleave, Whirl, channel ticks, crit combos | static per pattern, never driven by the game |
| Voices | one: the newest pattern replaces the one playing; loops stack and resume | no mixing: a crit during a cast cuts the cast feel, the heartbeat stops while you cast |
| Variation | crit combos: random strength / length / pan | nothing else reacts to the game (crit size, health, rage...) |
| Events | 19: crits x3, auto attack, shots, low HP, jump, cast x4 moments x3 kinds, instants, eat, drink, Halo x4, level up | see section 4 for what is missing |

What is good and worth keeping: Match the action / move / weapon, the cast build-up
tied to cast progress, channel ticks swelling per missile, eat/drink synced to the
character's hand animation. That is already beyond most PC games.

## 2. What the DualSense is, and what reaches it

- **Hardware:** no spinning motors. Two voice-coil actuators (one per grip), driven
  like loudspeakers: any waveform up to ~1 kHz, attack in a few ms. On PS5 games
  send audio to them (USB: channels 3-4 of the pad's 4-channel audio device).
- **Plus:** two adaptive triggers (resistance, clicks, trigger vibration), light bar,
  player LEDs, mic LED, speaker, gyro, touchpad.
- **What WoW sends:** SDL's HIDAPI PS5 driver in *rumble emulation*: two 8-bit
  amplitudes, the firmware fakes a heavy (left) and a light (right) motor at fixed
  frequencies, with its own smoothing ramp. That ramp is the likely reason short taps
  vanished on the Mac and why the right side needs >= 0.5.
- **So with the API alone** we control: amplitude per side, over time. Not frequency,
  not waveform. "Different" feels can only come from the **envelope**: attack, decay,
  amplitude modulation rate (grain), left/right balance, and how they move.

| DualSense feature | Used? | Reachable how |
|---|---|---|
| Two actuators, amplitude | yes (10-20 Hz updates) | API, could go to frame rate |
| Actuator frequency / waveform (true HD haptics) | no | helper only (USB audio) |
| `LTrigger` / `RTrigger` vibration | no | API, but SDL ignores it on a DualSense (works on Xbox impulse triggers) |
| Adaptive trigger resistance | no | helper only (parked: ADAPTIVE-TRIGGERS.md) |
| Light bar | no (Rumble) | API: `C_GamePad.SetLedColor` |
| Player LEDs, mic LED, speaker | no | not in the API |
| Battery level | no | API: `C_GamePad.GetPowerLevel` |
| Global strength CVar | no | `GamePadVibrationStrength` |

## 3. Pushing the API to its limit (addon only)

### 3.1 One engine: a mixer at frame rate
Replace `C_Timer` steps + shaper with a single `OnUpdate` mixer:
- every voice is a curve sampled each frame (60-144 Hz instead of 10);
- voices **mix** (per side: max, or sum with a soft clip), each with a priority and a
  *duck* (a crit dips the cast hum for 150 ms instead of killing it);
- send only on change (dedupe at 1/255), plus a keep-alive if the client lets it fade;
- one place for the output curve (3.2) and the light bar (3.6).

### 3.2 Calibration: a per-motor curve
A one-minute wizard: "tap when you feel it" while each side ramps up, then a few
"which is stronger" pairs. Stores per side: floor (first felt), knee, ceiling. The
mixer maps 0..1 to that curve (perceptually linear, gamma ~0.5-0.7). Replaces the
hard-coded `HIGH_FLOOR`, fixes the unfelt low values, adapts to USB vs Bluetooth and
to an Xbox pad.

### 3.3 Smaller and different: the vocabulary we don't use yet
All expressible as envelopes once updates are per-frame:
- **Overdrive taps:** a 30-40 ms spike at 1.0 then the real level, to punch through
  the firmware ramp. The way to get crisp ticks smaller than today's Micro tick.
- **Grain (AM):** amplitude modulated at 8-40 Hz. 8 Hz = purr, 15 = engine, 30 =
  buzz/static. The main "texture" knob we have.
- **Noise:** random amplitude jitter: gravel, fire, sand, a horse's gallop on a road.
- **Detents:** tiny ticks spaced evenly: a wheel turning, a lock, a menu sliding.
- **Ramps with curves:** ease-in / ease-out / exponential instead of linear steps.
- **Motion across the pad:** pan moving continuously (constant-power), not left /
  middle / right steps: a blade crossing, a missile passing.
- **Silence as a signal:** a hum that cuts out exactly when something happens.

### 3.4 The game drives the feel (modulation)
- **Heartbeat rate from danger:** faster as health drops when health is readable
  (out of combat / warning off); in combat use the warning only (Forever hides HP).
- **Cast build-up:** already there; add a tightening grain toward the end (rate
  rises with progress) so the release lands harder.
- **Crit size, rage, combo points, energy:** strength or grain from the value, when
  not secret.
- **Pan from the action:** main hand left / off hand right; channel missiles already
  alternate.

### 3.5 Events we don't feel yet
Feasibility on Forever: OK = plain events; ? = may be secret in combat.

| Group | Event | Source | Feasible |
|---|---|---|---|
| Combat | hit taken (non-crit), scaled by size | `UNIT_COMBAT` player WOUND | ? amount |
| Combat | you dodge / parry / block / resist | `UNIT_COMBAT` action | ? |
| Combat | each melee swing (swing timer feel) | `UNIT_COMBAT` target WOUND while meleeing | ? |
| Combat | target dies (your kill) | `UNIT_HEALTH` target / `PLAYER_TARGET_CHANGED` + dead | OK |
| Combat | you're stunned / feared / silenced | `LOSS_OF_CONTROL_ADDED` if present, else `UnitIsControlled`-style checks | ? |
| Combat | enemy starts casting on you | `UNIT_SPELLCAST_START` target + targettarget == player | ? |
| Resource | combo point gained, 5 points full | `UNIT_POWER_UPDATE` COMBO_POINTS | OK |
| Resource | rage full, out of mana | `UNIT_POWER_UPDATE` | ? |
| Ready | GCD over / key cooldown ready | `SPELL_UPDATE_COOLDOWN` | OK |
| Error | "Not enough mana", "Out of range"... | `UI_ERROR_MESSAGE` | OK |
| Move | landing after a fall, scaled by fall time | `IsFalling` edges in the mixer | OK |
| Move | into water (splash), mount / dismount, taxi take-off and landing | `MIRROR_TIMER`, `PLAYER_MOUNT_DISPLAY_CHANGED`, `UnitOnTaxi` | OK |
| World | loot, money, item received | `CHAT_MSG_LOOT`, `PLAYER_MONEY` | OK |
| World | quest accepted / complete, skill up (profession) | `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `CHAT_MSG_SKILL` | OK |
| World | death, resurrect, rested | `PLAYER_DEAD`, `PLAYER_ALIVE`/`PLAYER_UNGHOST` | OK |
| Social | whisper, ready check, duel / group / summon request | `CHAT_MSG_WHISPER`, `READY_CHECK`, ... | OK |
| UI | GPC / Halo cursor detents, Hold-to bars (V.Hold exists), confirm / deny | our own UI | OK |

### 3.6 Light bar as a second channel
`SetLedColor` from the same mixer: cast colour by school (fire orange, frost blue),
build-up brightness with progress, heartbeat red pulse at low health, gold flash on
level up, class colour at rest. Cheap, and it doubles the feedback. (Check it does
not fight Improved Forever or Touchpad code that may set it.)

### 3.7 Housekeeping
- Lower strength on low battery (`GetPowerLevel`), stop loops while AFK.
- Respect `GamePadVibrationStrength` (or set it to 1 and own the gain).
- Settings export string so feels can be shared.

## 4. The editor

### 4.1 Data model (replaces steps; old patterns convert 1:1)
```
pattern = {
  length = 0.6, loop = false,
  left  = { {t, v, ease}, ... },   -- keyframes, ease: hold|linear|in|out|smooth
  right = { {t, v, ease}, ... },
  grain = { rate = 0..40 Hz, depth = 0..1, noise = 0..1 },  -- applied on top
  pan   = { {t, -1..1}, ... },     -- optional, replaces separate left/right
}
```
A **parametric** form covers most feels with six sliders and is easy to edit with a
pad: attack, hold, decay, peak, grain rate, grain depth, pan (and pan sweep).
Keyframes are for the rest.

### 4.2 The window (Rumble page, "Edit" next to Try)
- Two lanes (Left / Right) on a time axis, or one lane + pan lane; points dragged
  with mouse, or moved with the D-pad / sticks (A adds, X deletes, bumpers pick).
- Playhead and live output meter while it plays; loop toggle.
- Presets as starting points (every built-in pattern is one), Duplicate, Save as.
- Each saved pattern appears in every event's grid like the built-in ones.

### 4.3 Record with the triggers (the pad-native way)
Hold L2 / R2: their analog depth drives the left / right motors live, recorded at
frame rate into keyframes (simplified afterwards). You *feel* what you draw. Then
trim, loop, save. No other WoW addon does this, and it fits a gamepad addon perfectly.
(Trigger axes are readable via `GetDeviceMappedState`; while recording, the triggers'
bindings must be ignored: record out of combat, in the editor only.)

## 5. Beyond the API: a helper program

Same transport as ADAPTIVE-TRIGGERS.md (corner pixels read by a small program).
One helper, three gains:

1. **Adaptive triggers** (the parked plan): R2 stiffens as a cast builds, a click per
   shot, a wall at full rage.
2. **True HD haptics (USB):** the helper plays short waveform clips (WAV) to the pad's
   haptic audio channels: real frequencies, the "rain on an umbrella" feel. The addon
   only sends an event ID + strength; patterns become clips (the editor could export
   a curve to a clip with a chosen carrier frequency). Bluetooth needs a different,
   harder path (audio over report 0x32+): USB first.
3. **Audio-to-haptics:** the helper listens to WoW's audio output and turns low
   frequencies into haptics: everything in the game rumbles, no event list needed.
   Mix with the addon's patterns rather than replace them.

Risks: pixels need windowed / borderless; Blizzard's view on screen-reading helpers
is unknown (it only reads pixels and writes to the pad, no input).

## 6. Probes before building (in game, ~15 min)

1. **Shortest felt tap on Windows:** one `SetVibration` at 1.0 then Stop after 16,
   33, 50, 75 ms. Was 100 ms on the Mac; decides 3.1 / 3.3.
2. **Does a value hold?** Set once, no re-send, for 3 s: fades or stays.
3. **Update-rate ceiling:** a 30 Hz square wave on Low: felt as a buzz, or smeared?
4. **Floors per side:** ramp each side 0 -> 1 over 5 s; note where it starts.
5. **Triggers:** `/gpc rumble test` steps 3-4 (LTrigger / RTrigger) on the DualSense.
6. **Light bar:** `SetLedColor` works on Forever, and nothing else resets it.

## 7. Suggested order

1. Probes (section 6).
2. Mixer + calibration (3.1, 3.2): every existing pattern immediately feels better.
3. New vocabulary (3.3) as new built-in patterns; a few new events (3.5: hit taken,
   dodge/parry, kill, combo points, landing, UI errors, GCD ready).
4. Light bar (3.6).
5. Editor: parametric first, then keyframes, then Record with triggers (4).
6. Helper (5), starting with the trigger test already planned.
