# Shaman and Druid

What each feels, spell by spell (2026-11-20). Spell lists are the client's own (WoW Helper's
`--spells`, `--spell-kinds`); `tests/ShamanDruidCoverage.lua` checks every ID of both classes.

## Who plays them in Forever (CharBaseInfo, ChrRaces)

| Class | Alliance | Horde |
|---|---|---|
| Shaman | Dwarf | Orc, Tauren, Troll, Windshaper Skyborne |
| Druid | Night Elf, High Order Skyborne | Tauren, Windshaper Skyborne |

## Where the code is

- `Shaman.lua`, `Druid.lua`: patterns and each spell (Rumble's `V.CLASS_SPELLS`, as `V.MAGE`).
- `Forms.lua`: beast forms: swings (claws, paw), no footsteps (travel form, Ghost Wolf ride),
  the return to your own shape.
- `ComboPoints.lua`: points a finisher spends (read as it is sent). Rogues can use it.
- Rumble hooks: `V.AddPatterns`, `V.ClassSpellOf`, `V.RuleGain`, entry fields `melee`, `magic`,
  `avoidOnly`, `scale`, `shift`; `V.FormSwing`.

## How a spell is felt

| Kind | When | Examples |
|---|---|---|
| Bolt | Its own impact at the wound (its school only) | Lightning Bolt, Chain Lightning (3 hops), Lava Burst, Starfire, Wrath |
| Magic instant | As it lands, a magic wound only | Shocks, Molten Blast, Moonfire, Sunfire, Starsurge |
| Weapon strike | At the weapon's (or form's) impact | Stormstrike, Lava Lash, Claw, Shred, Rake, Ravage, Swipe, Primal Bite, Maul |
| Finisher | Strength by points: 1 = 0.35 .. 5 = full | Ferocious Bite, Rip, Savage Roar |
| At the cast | A small feel | Totems by element, imbues, shields, forms, roars, buffs |
| Released | At the cast's end | Ghost Wolf, Entangling Roots, Hibernate, Chain Heal, Healing Rain, resurrections |
| Channel | One feel per tick over the real length | Hurricane (10), Tranquility (5) |

Timing in forms: the form is in Timing's model key (`6-3-f5`), swings are kind `form`; nothing
hard-coded (docs/TIMING.md).

## Not checked in game

- Chain Lightning always plays 3 hops (the targets it really hit are not visible).
- Reincarnation: Alive is quiet only if the spell's event comes before PLAYER_ALIVE.
- Combo points read at UNIT_SPELLCAST_SENT: confirm they are not spent yet then.
- The return to your own shape waits 0.25 s (a shift between forms passes through 0).
- Cat and bear have no footsteps at all (paw steps need the beast models' cadence).
- Moonkin swings stay the weapon's.
