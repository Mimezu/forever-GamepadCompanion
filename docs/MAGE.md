# Mage

What a mage feels, spell by spell (2026-11-20). Made for an Undead female mage with Skinning and
Tailoring; it works for any mage. The data is `V.MAGE` and the mage patterns in `Rumble.lua`; the
HD versions are WoW Helper's (`assets/hd/feels.txt`, `src/spellfeel.rs` SHIPPED_SPELLS).

The spell list is the client's own: WoW Helper's `--spells` and `--spell-kinds` read Forever's
tables (SpellName, SpellMisc, SpellEffect...). `tests/MageCoverage.lua` checks every one of the
265 mage spell IDs (every rank, the runes, the Undead racials, the wand) against what it plays.

## How a spell is felt

| Kind | When | Example |
|---|---|---|
| Bolt | Cast: its family's loop. Release: a launch (WoW Helper). Impact: its own feel at the wound, after the flight (0.15–2.5 s, its school only) | Fireball, Frostbolt, Pyroblast, Scorch, Arcane Blast, Frostfire Bolt |
| Instant at the target | As it lands | Fire Blast, Ice Lance, Arcane Barrage |
| Around you | At the cast, both hands | Frost Nova, Arcane Explosion, Blast Wave, Cone of Cold, Dragon's Breath |
| Released | At the release, no wait | Flamestrike (a breath, the eruption, the ground burning), Polymorph (a soft pop) |
| Channel | One feel per tick, from the channel's real length over its count (haste-proof); a faint hum under it | Arcane Missiles (3, 4, 5 by rank; the last firmer, hands by turns), Blizzard (8 ticks of uneven shards), Evocation, Cannibalize (a bite every 2 s) |
| At the cast | A small feel | Blink, Counterspell, Ice Block, Ice Barrier, Mana Shield, the armors, Arcane Intellect, cooldowns |
| Cast loop | Its own set | Conjures (crystals), Teleports and Portals (Hearthstone's), runes engraved (Enchanting's) |

A spell's crit plays its own impact at full; Critical hit: ranged adds its crack if you turn it on.

## Professions

- **Skinning:** the knife (Cut) while it lasts; the hide pulled free as it succeeds (the
  succeeded marker carries it for WoW Helper). Nothing of mining's: its sound is Gathering's.
- **Tailoring:** stitches and a snip. Bolts of cloth: wound onto the bolt and patted down.

## Her model

- **Steps:** her run's stride is 666 ms (the Undead male's 600). Calibrated on Alberich's measured
  run: 2.91 steps/s running, 1.92 walking, until WoW Helper learns hers.
- **Swings:** her one-hand and staff attack animations are as long as the Undead male's: the
  measured kind defaults (staff 0.14 s, dagger 0.095 s, one-hand 0.12 s). WoW Helper learns hers.
- **Voices:** her own sound set (fall grunts: kit 1362; 29 emotes, 75 takes).

## Not checked in game

Arcane Missiles' first missile at one period in (the spell's data has no start-at-apply);
Flamestrike's eruption delay (0.35 s, a feel, not the server's); Blizzard's first shards at 1 s.
