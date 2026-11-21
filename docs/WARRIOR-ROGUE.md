# Warrior and Rogue

What a warrior and a rogue feel, spell by spell (2026-11-20). The data is `Warrior.lua` and
`Rogue.lua`, registered through `ClassFeels.lua`; the HD versions are WoW Helper's
(`assets/hd/feels.txt`, `src/spellfeel.rs` SHIPPED_SPELLS).

The spell lists are the client's own (WoW Helper `--spells`, `--spell-kinds`, the rune
abilities named in Forever's SpellName). `tests/fixtures/warrior-spells.txt` (172 ranks, 91
names) and `rogue-spells.txt` (213 ranks, 110 names) say what each must play;
`tests/Warrior.lua` and `tests/Rogue.lua` check every one.

## When

| Kind | When | Example |
|---|---|---|
| A blow | At the weapon's impact (the hit frame, as timed for swings) | Mortal Strike, Execute, Whirlwind, Backstab, Eviscerate |
| On the next swing | That swing, felt as the ability | Heroic Strike, Cleave |
| Thrown | Where it lands (the ranged impact WoW Helper learned) | Shuriken Toss, Poisoned Knife, Between the Eyes |
| No blow of its own | At the cast; a dodge of it still shows | Concussion Blow, Disarm, Sap, Cheap Shot, Kidney Shot |
| Around you | At the cast | Thunder Clap, Shockwave, shouts, Fan of Knives |
| Charge, Intercept | The run at once, the crash when its stun lands on the target | |
| Slam | A wind-up loop while cast, the blow at the impact | |

## Materials

- **Warrior:** steel on bodies, a shield's wood and iron boss, boots on the ground, a chest
  swelling for a shout, the blood pounding (Bloodrage, Death Wish, Recklessness).
- **Rogue:** thin points between ribs, two daggers at once, a wire, a cosh, powder, a cloak.
  Stealth is a breath held; leaving it, a breath out (not when an opener broke it).
- **Area blows** are bodies one after another, left to right: never one blob.

## Finishers

By the combo points spent (read before or just after the client drops them):
Eviscerate one cut (1-2), a cross cut (3-4), a flurry (5). Kidney Shot, Rupture, Expose
Armor, Slice and Dice, Between the Eyes, Crimson Tempest, Blade Dance: fainter with fewer
points, full at five.

## Casts

- **Slam:** its own set (Wind-up). WoW Helper: a faint wind-up, its release quiet.
- **Poison on a blade** (every rank): a cloth along the steel, then Coated.
- **Poisons** (the craft): a pestle grinding, Alchemy's cork.
- **Pick Lock, Disarm Trap:** picks raking the pins, the lock giving. Opening a chest keeps
  Opening's tumbler.
- **Engrave:** Enchanting's shimmer.

## Quiet by design

Rend, Sunder Armor, Taunt, Feint, Distract, Redirect; procs and talents set off by another
(Flurry, Sweeping Strikes' extra blow, Hack and Slash...). Rage and energy: no tick (energy
comes every 2 s, all the time; rage has none). Energy or rage full: the Lab's Full.

## Not in Forever's client

Intervene and Envenom: their runes exist, the abilities have no name in SpellName (no rule).

## Not checked in game

Charge's crash by its stun aura (source unit, timing); the combo points' order against the
cast's news; Stealth's leave with each opener; Slam's blow window after a 1.5 s cast; the
rune ability IDs (Shadowstep, Fan of Knives, Crimson Tempest, Blunderbuss, Gladiator Stance,
Rampage); no HD feel felt on a pad.
