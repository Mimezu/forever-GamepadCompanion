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
- Each quest is one dot, on the flight path flying brings you near, compared in the world's
  yards (C_Map.GetWorldPosFromMapPos): the quest's mark on its map (GetQuestsOnMap: where to go,
  or whom to turn it in to), else its next waypoint; against every path of your side on the
  continent (C_TaxiMap.GetTaxiNodesForMap on the continents' maps: discovered or not, the one
  you stand at too), not only the places in the list. The quest's path is the nearest within
  2,500 yards (a Classic zone's long side), or its own zone's path when that is near as well
  (at most half again as far: Stromgarde's quests all under Hammerfall, not split with Tarren
  Mill). No dot when the nearest is further than that, is where you stand (the Scarlet
  Monastery at Undercity), or is one you can't fly to from here (Stranglethorn's Grom'gol
  undiscovered: nothing under Hammerfall). A point on the other continent: no dot (a log zone
  is where the quest was given, not where it goes). No point known: its log zone's path
  nearest the zone's centre, else the zone's first; none while you stand in that zone. A
  continent: the world id and the continent map (map parents), both. The last opening's
  matches, each with its path or why none and the yards: /gpc flights (SavedVariables
  flightProbe, 40 lines). Read when the map opens.

## Quest note

- Beside the chosen row, past the panel's right edge: a small floating note on the catch card's
  paper (FishingToast.lua's T.Paper / T.Kicker). The place in red capitals; its quests, a dot each:
  turn-ins first, then the ones to do; the level where it fits; 8 lines, then "+n more".
- No dots on the row: no note. Never takes the mouse. Off: Setup > Windows > Quest note.

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
X, L2 and R2 are greyed in the legend when they have nothing to do. L2 shows a gold ringed dot,
R2 a brown one, and "2/3" while you are on their round.

## In the air: the flight's passage (FlightCard.lua, Passage.lua)

- On a taxi, no card: a quiet line at the bottom left in the lure float's manner (no paper, no
  box), on a spot of its own (Edit Mode: its own box, apart from the lure float's and the meal's;
  EditSpots.lua), fading in after takeoff and out on
  landing. A gryphon (a wyvern for the Horde) in a brass rim, the place in old-book letters, the
  time left at the line's end, and the way as a thin line: a dot per stop (gold once passed, a
  soft gold breath as it passes), the destination's larger, a gold bead gliding along it; B's
  word under it. A meal's or the fire's wait uses the same passage (MealCard.lua).
- Time: the game gives none. Each route's time is learned from flights taken (per character,
  flightTimes: from > to, the mean of the last two). Never flown: the straight length (C_TaxiMap
  world points) x 1.2 at 30 yd/s, plus 10 s, marked "~". The stops' places on the line: each
  hop's share of the way.
- B lands at the next stop (TaxiRequestEarlyLanding, Blizzard's own leave button's call): a first
  press names it, a second within 3 s lands. B is an override binding only while on a taxi with
  a stop ahead, changed once B has been up 0.25 s (Sh.Settler), never in a fight.
- A /reload in the air: the flight goes on from what was saved. Off: Setup > Windows > Flight card.

## On the map

- A gold ring on the chosen place, breathing slowly; the route there, stop by stop.

Off: Setup › Windows › Flight list. On by default.
