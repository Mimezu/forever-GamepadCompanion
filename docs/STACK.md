# Stack: one state stack for every output (lights now, triggers next)

`Stack.lua` ports FrameGambit's model and words (no runtime dependency on it). A kind's
**reactions** are checked top to bottom; the **first match wins**, per channel; **Otherwise**
when nothing matches. Moments (crits, spells, whispers) play on top and hand back.

| FrameGambit | Stack (Gamepad Companion) |
|---|---|
| Reactions (gambits), top to bottom, first match wins | Same, per **channel**: a reaction sets the channels it has, an empty one passes (**Pass**) to the next match |
| Output: one opacity per frame | Channels: lights `bar`, `mic`, `dots`; triggers `L2`, `R2` (with live gauges) |
| On / Off per row, drag `::` and Up/Down | Same (Up/Down also on the pad) |
| Otherwise (`atRest`) | Otherwise: the base colour (lights), free (triggers) |
| Requirements, "All must be true", conflict pairs | Same (`AddRequirement` refuses a conflict and says which) |
| Families: System, Player, Target, Travel, Group & instances, Events… | Player, Target, Travel, Group & instances, System, Events (the pad's conditions; no mouse, chat, pets, party %) |
| Percentage conditions with `< <= = ~= >= >` | Same words: Health percentage, Power percentage, Target health percentage |
| Event conditions with a duration that restarts | Same (New private message 10 s, XP gained 5 s, Looted 4 s, Quest turned in, Level up) |
| Fade-in, fade-out, wait before fade-out per target | Per kind: Fade in, Fade out (the game's bar cross-fades; WoW Helper fades on its own), Wait (a reaction that stops matching holds) |
| The teal row: the rule controlling the frame | The teal row(s): driving a channel now ("Now: Bar, Mic") |
| Polled at up to 20 Hz, sleeping when idle | Event-driven only; pushed conditions and gauge values from the modules |
| Profiles, Cinematic second profile, export / import | The reactions live in the Feel profile (`lightStack` in `P.FEEL_TABLES`): its export / import carry them; no second profile system |
| Moments: quest, loot, XP, chat | Our own moments are GPC's moment table (on top of the stack); event conditions only for "hold a while after" |

Conditions that are nearly FrameGambit's own evaluators (`combat`, `moving`/Movement, `dead`,
`stealth`, `mounted`, `swimming`, `underwater`, `taxi`, `resting`, `group`/`raid`/`solo`,
`indoors`/`outdoors`, target ones, health %): candidates for a shared helper later.

## Conditions

`Stack.Condition(key, { label, category, kind = "state"|"moment", test = fn, value = fn -> 0-100,
events = { … }, duration = s })`. No `test`/`value`: pushed by its module: `Stack.Set(key, on)`
(Low health, Casting, Halo ring open), `Stack.Fire(key)` (an event), `Stack.SetValue(key, v)`
(a gauge source: cast progress, swing, GCD, combo points…). `Stack.CATEGORIES`,
`Stack.OPERATORS`, `Stack.Conflict(row, key)`, `Stack.Matches(row)`, `Stack.Words(row)`.

## A kind

```lua
local k = ns.Stack.Kind("triggers", {
    channels = { "L2", "R2" },
    recommended = { { id = "lowHp", condition = "player_health", operator = "<", threshold = 35, on = true, R2 = {…} }, … },
    store = function() return db.triggerStack end,   -- Feel-profile table: .rows, .nextID, .timing
    value = function(row, ch) return row[ch] end,    -- nil: passes; may read Stack.Value(row.source)
    base = function(ch) return { effect = 0 } end,   -- Otherwise
    apply = function(result) end,  -- result[ch] = { value =, row = row|nil }, result.timing; on a change
    live = true,                   -- re-resolve when a gauge value moves
    timing = { fadeIn = 0.2, fadeOut = 0.2, wait = 0 },
    prepare = function() end,      -- migrate an older saved form into .rows, once
})
k:Rows(); k:Row(id); k:Add(condition); k:Remove(id); k:Move(id, ±1); k:MoveTo(id, n); k:SetOn(id, on)
k:AddRequirement(id, cond) -- true, or false + the conflicting key;  k:RemoveRequirement(id, cond)
k:Timing(); k:SetTiming("fadeIn"|"fadeOut"|"wait", s)
k:Default(id?); k:IsDefault(id?); k:Recommended(id)
k:Refresh(force); k:Now(); k:Driving()  -- { [row id] = { channels } }: the teal rows
```

## Lights

Reactions are light moments that last (`LT.Def(id)`, `LT.Settings(id)` = the row: `on`,
`light` (0 = Pass), `color`, `strength`, `dots`, `mic`). The Recommended ones are the states in
`LT.STACK`'s order. Moments › Light › States: the list (On, ▲▼ and drag, the condition's words —
a percentage's operator on a click —, `+` requirements, the light picker with Pass, Try,
Default, ×), `+ Add reaction`, Otherwise, Fade in / Fade out / Wait. Silent migration: 0.48's
order and states' lights become reactions; the old mic "In combat" is In combat's mic.

## The strip

The light row is one row inward of the v2 strip (yellow marker, 17 or 23 cells); the triggers'
row two rows inward (red marker). A reader finds each by its marker at its fixed offset.
