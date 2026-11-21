# Flight list

At a flight master, in the gamepad UI only, a list beside the game's flight map: every place you can
fly to from here, chosen with the pad. The map stays the game's; it only
reflects the row you are on.

## Layout

- A slim panel on the map's right edge, the map frame's own chrome, parchment
  inside. Title: Fly to.
- Top: the green flight icon and where you are (not a row, not selectable).
- Rows, nearest first: the place in ink, its zone under it, a pip per stop
  on the way, the cost in coins on the right (red when you can't pay it).
- The row you are on: a warm band of light. Scrolls to keep it in view.
- Bottom: Blizzard's legend glyphs: Fly, Close, Near / A-Z.

## Controls (out of combat, while the map is open)

| Button | Does |
| --- | --- |
| D-pad up / down | the row before / after (wraps; held: repeats) |
| L1 / R1 | a page up / down (stops at the ends) |
| D-pad left / right | the first / last row |
| A | fly there |
| B | close the map |
| Y | sort: nearest first, or by name |

The list takes only those presses, one at a time, on its own frame (as the
Companion window does, Focus.lua); everything else passes on. In combat it
takes nothing. Mouse: hover a row to choose it, click to fly.

## On the map

- A gold ring on the chosen place, breathing slowly, a soft glow inside.
- The route there as a gold line, stop by stop.

Off: Setup › Windows › Flight list. On by default.
