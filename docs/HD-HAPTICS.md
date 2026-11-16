# HD haptics: from rumble pulses to real waveforms

Plan, 2026-11-16. Shared by the addon (Gamepad Companion) and the Rust helper (WoW Helper).

## The two modes, side by side

| | Rumble mode (today) | HD mode (the helper) |
|---|---|---|
| Path | the game's `SetVibration`: two strengths | the helper: waveforms to the actuators (USB audio ch. 3-4, or Bluetooth haptic reports) |
| What can be felt | pulses ≥ 50 ms, rhythm, side; strength changes smoothed away | frequency (pitch), timbre, texture, attack shape, fine timing (ms), true stereo |
| Works | always, any pad | with the helper running |

**Nothing of the old mode is lost.** Every event keeps its rumble feel. An HD version is
added beside it, and the HD one plays when the helper says it is ready. The fallback is
automatic: helper off, Bluetooth without haptics, or Improved Forever loaded.

## The HD feel format

A feel is a list of **layers**, each a short synthesized sound for the actuators:

```
hd = {
  { kind = "tone",  t = 0,    dur = 0.12, freq = 70,  freqTo = 55, amp = 0.9, attack = 0.004, decay = "exp", side = -0.2 },
  { kind = "noise", t = 0.02, dur = 0.30, band = { 80, 220 },      amp = 0.15, attack = 0.02,  decay = "lin" },
  { kind = "click", t = 0.35, freq = 180, amp = 0.3 },
  vary = { pitch = 0.06, time = 0.01, amp = 0.15 },   -- each play a little different
}
```

- **kind:** `tone` (sine, its pitch can glide `freq → freqTo`), `noise` (band-limited:
  rain, sand, gravel), `click` (a 2-4 cycle burst: the crispest micro tap), `pulse`
  (a train of clicks at a rate: ratchets, purrs).
- **freq:** low (40-90 Hz) feels heavy and deep, mid (100-160) solid, high (180-300) light
  and crisp. This is the new dimension the rumble mode never had.
- **vary:** small random changes per play, so a run of crits or footsteps never repeats
  exactly.
- **side:** -1 left .. 1 right, now a true balance between the two actuators.

## Converting what we have (a first draft, then crafted by hand)

1. **Automatic draft** for every feel (54 library + 66 Rumble patterns + yours): each
   pulse becomes a layer. Length → `dur`. Strength → `amp`. Side → `side`. The **weight**
   picks the pitch: strong and long → low tone (60-80 Hz), short and faint → high click
   (200-260 Hz), in between → 110-150 Hz. A pulse ≥ 0.25 s gets a slight downward glide
   (`freqTo`) so it decays like an impact.
2. **Crafting pass, by group**, keeping each feel's soul (its rhythm and contrast) and
   adding what HD allows:
   - **Taps:** crisp `click`s, with pitch giving the size (Dust the highest and faintest).
   - **Impacts:** a low tone body, a noise "crunch" at the start, a short sub tail
     (Thud, Boom, Slam).
   - **Combat:** metal versus wood versus flesh by timbre (Parry: a high ringing tone;
     Block: a low muffled thump; Strike: a dry click).
   - **Weapons:** the sword a high swish (noise sweep), the mace a low thud, the
     bowstring a twang (tone glide 220→90).
   - **Spells:** fire = crackling noise, frost = high sparse ticks with a glassy ring,
     arcane = gliding tones left to right, shadow = a low wobble, holy = a soft rising
     chord.
   - **Nature:** rain = noise drops with random pitch, thunder = a long low rumble,
     bubbles = rising little tones.
   - **Life:** a heartbeat with real lub-dub body; footsteps as soft low taps (later, by
     ground: grass, stone, wood, snow).
   - **Crafts:** the anvil ring, the stitch, the pickaxe's clink.
3. **Each crafted feel is checked on the pad** with A/B against its rumble version.

## Where things live (the decision to make)

The addon can't send waveforms through the pixel strip (48 bits a frame). So:

- **The addon decides _what_ plays:** the event, its feel id, gain, side, intensity and a
  seed for the variation. This is a protocol v2 change: feel ids need more than today's
  127 clip slots.
- **The helper decides _how_ it sounds:** it holds the HD definitions and renders them.

The editor for HD, **recommended in the helper**: a desktop window (Rust, e.g. egui) with
a timeline of layers, the waveform drawn, pitch and envelope handles, Play on the real pad
instantly, and A/B against the rumble version. The in-game editor can't preview HD live
(no waveform channel) and is clumsy for curves.

The in-game editor keeps the rumble mode. It gets a "HD" badge on feels that have an HD
version, and a button to ask the helper to open that feel.

Sharing definitions: the shipped HD library lives in the helper (`feels.toml`, or the
like). Your own HD feels: saved by the helper. The addon learns which feels have HD from
the helper's `ready` signal, or a list written into the addon's folder by the helper.
Addons can read files only at load, so a list written there before `/reload` is seen.

## Steps

1. Protocol v2 (helper + `HelperLink.lua`): `play feel <id> gain side intensity seed`,
   and a "ready, HD" state back (the helper can't talk to the addon, so: the player turns
   HD on, and the helper shows its state in its tray).
2. The helper: the synth (tone, noise, click, pulse layers), the HD library format, the
   automatic draft from the addon's pulses (the helper reads the feel library exported to
   a file).
3. The crafting pass, group by group, on the pad.
4. The HD editor in the helper.
5. The addon: the HD switch (Haptics tab), which events send HD, the fallback, and the
   badges.
