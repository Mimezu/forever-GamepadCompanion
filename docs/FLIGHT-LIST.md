# Flight list

At a flight master, in the gamepad UI only, a list beside the game's flight map: every place you can
fly to from here, chosen with the pad. The map stays the game's; it only reflects the row you are on.

## Zones (the default view)

- Places grouped by zone. Your own zone first, then the zones worth flying to:
  turn-ins (x30), open quests (x10, up to 5), your level's fit, the last place flown to, near.
  Zones you can't pay for sink to the end.
- A zone's row: its name and levels in the quest colours (red, orange, yellow, green, grey). Grey
  zones' places are dimmed (capitals never).
- A place's row: its name, its quests as dots in an ink ring (gold: to turn in, brown: to do; 5 of
  each at most), the cost. The chosen row: an amber band, a dark ink bar and a pointer.
- Inside a zone: nearest first. The list starts on the nearest place in your zone, else in the
  best zone. A zone's score counts its places' dots.
- Each quest is one dot, on the flight path nearest it, compared in the world's yards
  (C_Map.GetWorldPosFromMapPos): the quest's mark on its map (GetQuestsOnMap: where to go, or
  whom to turn it in to), else its next waypoint; the paths from C_TaxiMap on the continents'
  maps. No point known: its log zone's path nearest the zone's centre, else the zone's first.
  Read when the map opens.

## Controls (out of combat, while the map is open)

| Button | Does |
| --- | --- |
| D-pad up / down | the place before / after (wraps; held: repeats) |
| D-pad left / right | the zone before / after (Nearest: the first / last place) |
| L1 / R1 | a page up / down |
| A / B | fly there / close |
| X | Again: the last place flown to from here |
| Y | Nearest (one list, no zones) / Zones |
| L2 | Turn-ins: the place with the most gold dots; again: the next |
| R2 | Quests: the place with the most brown dots; again: the next |

L2 and R2: while the list shows, override bindings on the list's own frame (as the fishing pole's,
Fishing.lua). They change only once both triggers have been up a quarter second (Sh.Settler: never
mid-press), out of combat; a fight drops them at once. The list gone, they go back to the bars.
X, L2 and R2 are greyed in the legend when they have nothing to do.

## On the map

- A gold ring on the chosen place, breathing slowly; the route there, stop by stop.

Off: Setup › Windows › Flight list. On by default.
