# Stack: one state stack for every output (lights now, triggers next)

`Stack.lua`, modelled on FrameGambit's list (its words: the list is checked top to bottom,
**first true wins**, On/Off per row, Up/Down, **Otherwise** at the bottom). No dependency on it.

```
Moments (crits, spells, whispers)   on top, brief: each kind plays them itself, then hands back
States, in the player's order       the first true one sets each channel it has; Pass: below shows
Otherwise (the base)                always true
```

## Conditions (shared)

Read on their events only (no OnUpdate): `dead` Dead or ghost, `afk` Away, `stealth` Stealthed,
`combat` In combat, `swimming`, `mounted`, `moving` Movement, `rested` Resting, `taxi` On flight
path. Pushed by their module with `Stack.Set(key, on)`: `lowHp` Low health, `cast` Casting,
`halo` Halo ring open. Add one with `Stack.Condition(key, { label =, test = fn, events = {…} })`
(no `test`: pushed).

## A kind registers its channels

```lua
local k = ns.Stack.Kind("triggers", {
    channels = { "L2", "R2" },
    layers = { { key = "lowHp" }, { key = "combat" }, { key = "moving", when = "moving" } },  -- when: its condition (default: key)
    recommended = { "lowHp", "combat", "moving" },     -- the order, top first
    store = function() return db.triggerStack end,    -- a Feel profile table; .order is saved there
    enabled = function(key) return settings(key).on end,
    value = function(key, ch) return settings(key)[ch] end,   -- nil: passes to what is below
    base = function(ch) return "free" end,             -- Otherwise
    apply = function(result) ... end,   -- result[ch] = { value =, layer = key | "base" }; only on a change
    same = function(a, b) return a == b end,           -- optional: compare two values
})
k:Order()          -- keys, top first (saved order; a new state at its Recommended place)
k:Move(key, -1|1)  -- up / down one place (saved)
k:SetOrder(list); k:DefaultOrder(); k:IsDefaultOrder()
k:Active(key)      -- its condition holds now
k:Refresh(force)   -- re-resolve (force: a setting changed); calls apply when the result changed
k:Now()            -- the last result (what wins each channel)
ns.Stack.Refresh() -- every kind
```

The states are moments with a Recommended value and Default (lights: `LT.EVENTS`, `state =
true`, group States); the order is in the Feel profile (`lightStack`, in `P.FEEL_TABLES`).

## Lights

Channels: `bar` (a state's light, colour, strength; `light = 0` passes), `mic`, `dots` (`pass`
passes). Otherwise: the base colour and its light (Setup › Light), the base mic, no dots. With
WoW Helper the result goes out as the light row's hold (bar from one state, mic and dots from
others); without it the game plays the bar. Moments › Light › States: the list (Up/Down, the
picker with Pass, Try, Default, "Now: Bar, Mic"), Otherwise at the bottom.

Silent migration (once): the old mic card's "In combat" becomes the In combat state's mic (its
bar passing if it had no light); a state's saved "off" dots/mic become Pass.
