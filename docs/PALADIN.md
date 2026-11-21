# Paladin

What a paladin feels, spell by spell (2026-11-20). The feels a paladin had before stay as they
were (a guessed Blow too); this pass gave a feel only to what played nothing. Data: `Paladin.lua` (`PD.SPELLS`), its own patterns (`PD.PATTERNS`,
registered with `V.AddPatterns`) and `V.CLASS_SPELLS.PALADIN`; HD: WoW Helper's `assets/hd/feels.txt`. `tests/PaladinCoverage.lua`
checks all 253 paladin spell IDs of the client (every rank, the runes, the class mounts).

## Kept

| Feel | Spells |
|---|---|
| Seal | the seals, the blessings |
| Judgement, at the blow | Judgement, Exorcism, Holy Strike, Crusader Strike, Divine Storm, Hammer of the Righteous, Shield of Righteousness |
| Surge | Consecration laid down |
| Bash | Hammer of Justice, Rebuke |
| Ward | Divine Shield, Divine Protection, Blessing of Protection, Holy Shield |
| Crescendo | Lay on Hands |
| Shock | Holy Shock |
| Mend | Purify, Cleanse |
| Blow, at the hit | Avenger's Shield, Hand of Reckoning |
| Casts | Healing (Holy Light, Flash of Light, Divine Light, Summon Warhorse, Summon Charger), Holy (Hammer of Wrath, Holy Wrath, Redemption), Nature (Turn Undead) |

## Added

| Feel | When | Spells |
|---|---|---|
| Aura | cast | every aura; Divine Sacrifice, Horn of Lordaeron, Voice of Truth |
| Seal | cast | Greater Blessings, Blessing and Hand of Sacrifice, Seal of Fury, Oath of Light |
| Empower | cast | Righteous Fury, Aura Mastery, Inspiration Exemplar |
| Wings | cast | Avenging Wrath |
| Glow | cast | Divine Favor, Beacon of Light |
| Ward | cast | Divine Intervention, Sacred Shield, Templar's Bulwark |
| Micro tick | cast | Sense Undead |
| Hallowed | each second, 8 s | Consecration's ground |

Consecration's ground: faint, by turns from either hand; fainter towards its 8-yard edge, none once
you walk out (where the client gives your position), mount or die. Its rumble waits for whatever
plays (a blow, a swing: never cut short; dropped after 0.5 s); its HD goes on time.

## Not checked in game

The rune spells' real IDs (matched by name); Consecration's first tick at 1 s; whether the
client gives your position in dungeons (else every tick plays).
