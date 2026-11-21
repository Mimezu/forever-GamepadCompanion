# Priest and Warlock

What a priest and a warlock feel, spell by spell (2026-11-20). The data is `Priest.lua` and
`Warlock.lua` (through `ClassSpells.lua`); the HD versions are WoW Helper's (`assets/hd/feels.txt`,
`src/spellfeel.rs` SHIPPED_SPELLS).

The spell lists are the client's own (WoW Helper's `--spells`, `--spell-kinds`, the spell probe).
`tests/PriestWarlock.lua` checks all 589 spell IDs (every rank, the runes, the warlock's stones).

## How a spell is felt

| Kind | When | Example |
|---|---|---|
| Bolt | Its loop; a launch (WoW Helper); its own feel at the wound, after the flight | Shadow Bolt, Soul Fire, Incinerate, Chaos Bolt, Haunt |
| No flight | At the release | Smite, Holy Fire, Mind Blast, Immolate, Searing Pain, Fear |
| Heal | At the release, by its size | Lesser Heal, Heal, Greater Heal, Flash Heal, Prayer of Healing |
| Channel | One feel per tick, from its real length | Mind Flay 3 (by turns), Penance 3 (the first at once), Drain Life 5, Drain Soul 5, Hellfire 15, Rain of Fire 4 |
| Around you | Both hands | Holy Nova, Psychic Scream, Howl of Terror, Immolation Aura |
| DoT, curse | Faint, at the cast | Shadow Word: Pain, Corruption, the curses and banes |
| Summon | A faint circle while drawn; the demon's own arrival | Imp crackles, Voidwalker heavy, Succubus a whip, Felguard a stomp |
| Stone | Grit forming; a clack in the palm | Create Healthstone; using one: warmth |
| At the cast | A small feel | Power Word: Shield, Fade, Inner Fire, Life Tap, Shadowform, Metamorphosis |

## Moments (Feels › Abilities)

- **Soul Shard**: one more in your bags. On.
- **DoT ticks**: a faint prick per tick of your DoTs. Off.
- Your demon: Pet group (arrives, leaves, dies; its blows and the blows on it off). While you
  summon or sacrifice, its own feel says it.

## Not checked in game

Penance's first bolt at the start; Mind Sear, Starshards and Wrack at 6 ticks; a DoT tick inside a
Shadow Bolt's window taken as its impact; the Imp's fire wounds (Critical hit: ranged, off);
Soul Shard by bag count; HD feels only measured.
