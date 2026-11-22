# Flight list

At a flight master, in the gamepad UI only, a list beside the game's flight map: every place you can
fly to from here, chosen with the pad. The map stays the game's; it only reflects the row you are on.

## Zones (the default view)

- Places grouped by zone. Your own zone first, then the zones worth flying to:
  turn-ins (x30), open quests (x10, up to 5), your level's fit, the last place flown to, near.
  Zones you can't pay for sink to the end.
- A zone's row: its name and levels in the quest colours (red, orange, yellow, green, grey), and
  its quests: a gold dot and count to turn in, a brown dot and count to do. Grey zones' places
  are dimmed (capitals never).
- A place's row: its name, its quests as dots (gold: to turn in, brown: to do; 5 of each at
  most), the cost.
  The chosen row: an amber band, a dark ink bar and a pointer.
- Inside a zone: nearest first. The list starts on the nearest place in your zone,
  else in the best zone.
- Quests come from the game's quest log when the map opens (C_QuestLog): each one goes to the
  flight path nearest its point on the zone's map (GetQuestsOnMap: where to go, or whom to turn
  it in to; C_TaxiMap for the paths). No point: its log zone only (the zone's count, no dot).

## Controls (out of combat, while the map is open)

| Button | Does |
| --- | --- |
| D-pad up / down | the place before / after (wraps; held: repeats) |
| D-pad left / right | the zone before / after (Nearest: the first / last place) |
| L1 / R1 | a page up / down |
| A / B | fly there / close |
| X | Again: the last place flown to from here |
| Y | Nearest (one list, no zones) / Zones |
| L2 | Turn-ins: the flight path with the most gold dots; again: the next |
| R2 | Quests: the flight path with the most brown dots; again: the next |

L2 and R2 are only read, never taken or rebound: the game still gets them (L2 its bar, R2 its Ctrl).
Two ways in, one press: the button's own press on the panel, and the pad's state each frame.
X, L2 and R2 are greyed in the legend when they have nothing to do.

## On the map

- A gold ring on the chosen place, breathing slowly; the route there, stop by stop.

Off: Setup › Windows › Flight list. On by default.
