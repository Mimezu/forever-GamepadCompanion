# Node names (NodeSense.lua) — experimental

The node compass (WoW Helper) draws an arrow on the screen's edge for each gold dot it sees on
the minimap. With a mouse you hover a dot to read "Mithril Deposit"; with a pad you can't. Node
names reads them for you and WoW Helper colours each arrow by what it is.

## How
- The Forever client has `Minimap:UpdateMouseoverAtPoint(x, y)` and
  `Minimap:SetUsingSoftCursor(on)` (made for the gamepad soft cursor) and
  `C_TooltipInfo.GetMinimapMouseover()`. Out of combat, while a node tracking is on, a hidden
  sweep "hovers" a grid over the minimap (step 0.07 radius, about 450 points, 40 a frame, once a
  second) and reads the names under each point. Hits of one name close together make a dot.
- Only the live dots: no database.
- The point's units aren't documented. Seven readings are tried (`S.READINGS`: screen, cursor,
  local, local from the top, from the centre, 0-1, 0-1 from the top). The one that finds dots is
  kept (account-wide). Where two find them (a mirror), the way a still dot slides as you walk
  decides. `/gpc nodes forget` searches again.
- The dots go to WoW Helper in the node row (HelperLink.lua: 54 cells, cyan first, six rows up or
  from cell 117 on one line): up to 6, each with its place (radius/127 units), its kind, wanted
  and gatherable. Vectors: `tests/fixtures/helperlink-node-vectors.txt`.

## Colours (WoW Helper)
Copper orange, tin pale grey, silver white, iron rust, gold gold, mithril sky blue, truesilver
pale cyan, dark iron violet, thorium green (rich: deep green), herbs leaf green, unknown gold.
Not what you're looking for: faint. Above your skill: greyed.

## Settings
- Setup › Nodes: Name the arrows (on/off), Looking for (Any, Any ore, an ore, Any herb).
- `/gpc ore mithril` (or `any`, `ore`, `herb`, `darkiron`, `richthorium`...), `/gpc nodes`: the
  state and the last trace lines. `/gpc nodes off | on | forget`.

## Trace
`GamepadCompanionTraceDB.nodes` (SavedVariables GamepadCompanion.lua): "search: screen 3, cursor
0, ..." (dots each reading found), "reading: screen", "dots: Mithril Deposit 0.26,0.16; ...",
"blocked" (the call refused), "no API".
