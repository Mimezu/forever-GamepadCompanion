# Flight list

At a flight master, in the gamepad UI only, a list beside the game's flight map: every place you can
fly to from here, chosen with the pad. The map stays the game's; it only reflects the row you are on.

## Zones (the default view)

- Places grouped by zone. Your own zone first, then the zones worth flying to:
  turn-ins (x30), open quests (x10, up to 5), your level's fit, the last place flown to, near.
  Zones you can't pay for sink to the end.
- A zone's row: its name and levels in the quest colours (red, orange, yellow, green, grey), a
  ? per quest to turn in, a ! per open quest. Grey zones' places are dimmed (capitals never).
- A place's row: its name, its stops on the way ("2 stops"; direct: nothing), the cost.
  The chosen row: an amber band, a dark ink bar and a pointer.
- Inside a zone: nearest first. The list starts on the nearest place in your zone,
  else in the best zone.
- Quests come from the log when the map opens; closed log headers are opened to count, then closed.
  Headers that are no zone (class, dungeon) count for nothing.

## Controls (out of combat, while the map is open)

| Button | Does |
| --- | --- |
| D-pad up / down | the place before / after (wraps; held: repeats) |
| D-pad left / right | the zone before / after (Nearest: the first / last place) |
| L1 / R1 | a page up / down |
| A / B | fly there / close |
| X | Again: the last place flown to from here |
| Y | Nearest (one list, no zones) / Zones |
| L2 | Turn-ins: the zone with the most; again: the next |
| R2 | Quests: the zone with the most open; again: the next |

L2 and R2 are only read, never taken or rebound: the game still gets them (L2 its bar, R2 its Ctrl).
X, L2 and R2 are greyed in the legend when they have nothing to do.

## On the map

- A gold ring on the chosen place, breathing slowly; the route there, stop by stop.

Off: Setup › Windows › Flight list. On by default.
