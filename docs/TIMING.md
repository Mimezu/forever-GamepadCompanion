# Timing: feels in step with the game

Every moment whose feel should line up with an animation or a game sound: what triggers it, when that
arrives against what you see or hear, and how its feel is timed. `Timing.lua` holds the offsets, the
one sync and the link lead.

## The audit

| Moment | Trigger | Event vs the real moment | Source |
|---|---|---|---|
| Your melee swing: hit, crit, miss, dodge, parry, block | `UNIT_COMBAT` target (CLEU `SWING_*` where readable) | **unproven**: believed to arrive as the attack animation starts, the blow and its sound later | **impact offset** per model·form·weapon·hand; defaults per weapon; signed sync = override (logs the raw pairs: a measurement) |
| Extra attacks (Windfury, Sword Spec), parry-hasted swings | same | come sooner than the swing timer | counted as swings (the hand due nearest) |
| Heroic Strike, Cleave, Maul, Raptor Strike | `SUCCEEDED` then the blow | the blow is the swing | swing (no "just after an ability" guard) |
| Ranged shot | the shot spell's `SUCCEEDED` | at the release; the arrow's impact depends on distance | offset "ranged" (default 0) |
| Hit taken; you dodge, parry, block | `UNIT_COMBAT` player | the enemy's animation: unknown | at once |
| Spell cast | `UNIT_SPELLCAST_START`, shaped by `UnitCastingInfo` start/end | the cast bar is the truth (haste included); release at `SUCCEEDED` | event |
| Channel | `CHANNEL_START`, known tick interval | pushback shortens, the ticks keep their phase | event (unchanged) |
| Footsteps, wading | `PLAYER_STARTED_MOVING` + rate/offset per model and gait | the cycle starts with the move | learned rate + offset (sync); each step latched from the frame it begins |
| Landing | `IsFalling` ending, every frame (+1 frame for water) | the feet touching | event |
| Jump | `JumpOrAscendStart` hook | the press | event |
| Mount, dismount | `IsMounted`, **every frame** (was a 10 Hz poll, up to 100 ms late) | the change | event |
| Mining | cast start + swing period / first strike | the pickaxe swings | learned period + offset (sync); each strike latched |
| Herbalism, skinning, opening | the cast's loop | not tied to the animation | pattern loop (unchanged) |
| Fishing | cast start → the throw (bobber at 1.1 s) | follows the cast | animation-length guess |
| Eating, drinking | the server's eat tick (`V.RestMotion`) | the hand to the mouth | event |
| Loot, quest done, level up | `CHAT_MSG_LOOT`, `QUEST_TURNED_IN`, `PLAYER_LEVEL_UP` | with the game's sound | event |

## The model

- **Offsets**: seconds after the swing's news, in game time, keyed `race-sex[-fForm]|kind|hand`
  (kind: dagger, oneHand, twoHand, polearm, staff, fist, unarmed, form, ranged; hand: main, off,
  ranged). The attack animation doesn't scale with weapon speed; when the swing comes round sooner
  than the animation (`UnitAttackSpeed`, `UnitRangedDamage`), the animation plays faster and the
  impact moves in proportion: `offset × interval / anim`.
- **Resolution**: yours (sync, or set by hand) → learned (WoW Helper's slot, `Timing.Learn`; needs a
  shared clock before it can be trusted) → the weapon's default × the model's factor (1 until measured).
- **One sync**: `Timing.StartSync{ name, onTap, onUpdate, onStop }` owns the single R2/L2 watcher;
  footsteps (rate fit), mining (period fit) and hits (signed median) each bring their own `onTap`. One
  at a time. Hits: each squeeze pairs with the nearest news within half a swing, before or after it;
  the median of six, refused when they spread over 60 ms; the feels stay quiet while you squeeze.
- **Link lead**: with WoW Helper on, its measured addon→pad latency (`Timing.SetLinkLatency`) is taken
  off whatever is scheduled ahead (`Timing.After`, never below 0), and the step and strike clocks run
  that much ahead. Feels sent at once can't go out early.
- **Pulses**: a step or strike starts on the frame it begins and plays whole, so a slow frame never
  shortens or loses one.

## Open

- Measure the swing news against the hit sound (the hit sync's log) before trusting the defaults.
- Per-model factors, a backpedal gait, channel ticks with haste, herbalism and skinning in step.
