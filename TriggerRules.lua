-- Trigger rules: the player's own setup of the adaptive trigger motors
-- (WoW Helper drives them). A rule: when a state holds (casting, auto shot,
-- low health, mounted...), a trigger (R2, L2, both) takes an effect (resist,
-- wall, zone, click, pulse, rising) with its zone and strength. The first
-- rule that holds wins its trigger: the list's order is the priority.
-- Recommended: the three the addon always had (cast tightens R2, auto shot
-- clicks it, low health shakes L2). Pure logic: no frames, testable.
local _, ns = ...
local T = {}
ns.TriggerRules = T

local floor, max, min = math.floor, math.max, math.min

-- States a rule can follow (all continuous: the trigger holds while true)
T.WHEN = {
    { key = "cast", label = "Casting" },          -- a cast or a channel
    { key = "autoShot", label = "Auto shot" },
    { key = "autoAttack", label = "Auto attack" },
    { key = "combat", label = "In combat" },
    { key = "lowHp", label = "Low health" },
    { key = "mounted", label = "Mounted" },
    { key = "swimming", label = "Swimming" },
    { key = "stealth", label = "Stealth" },
    { key = "always", label = "Always" },
}
T.WHEN_LABEL = {}
for _, w in ipairs(T.WHEN) do T.WHEN_LABEL[w.key] = w.label end

-- Effects, as HelperLink's trigger modes (wall: resistance at full force)
T.EFFECTS = {
    { key = "resist", label = "Resist", mode = "resist", uses = { from = true, strength = true } },
    { key = "wall", label = "Wall", mode = "resist", uses = { from = true } },
    { key = "section", label = "Zone", mode = "section", uses = { from = true, to = true, strength = true } },
    { key = "weapon", label = "Click", mode = "weapon", uses = { from = true, to = true, strength = true } },
    { key = "vibrate", label = "Pulse", mode = "vibrate", uses = { from = true, strength = true, speed = true } },
    { key = "slope", label = "Rising", mode = "slope", uses = { from = true, to = true, strength = true } },
}
T.EFFECT = {}
for _, e in ipairs(T.EFFECTS) do T.EFFECT[e.key] = e end

T.SIDES = { { "R2", "R2" }, { "L2", "L2" }, { "both", "Both" } }
T.MAX = 6
-- WoW Helper's pulse speeds (protocol force 0-15 -> Hz)
T.SPEED_HZ = { 5, 8, 10, 13, 16, 20, 25, 30, 35, 40, 50, 60, 80, 100, 150, 200 }

local function Int(v, lo, hi, def)
    v = tonumber(v)
    if not v then return def end
    return max(lo, min(hi, floor(v + 0.5)))
end

-- A rule made whole (any saved shape, never trusted)
function T.Clean(r)
    r = type(r) == "table" and r or {}
    local when = T.WHEN_LABEL[r.when] and r.when or "cast"
    local side = (r.side == "L2" or r.side == "both") and r.side or "R2"
    local effect = T.EFFECT[r.effect] and r.effect or "resist"
    r.on = r.on ~= false
    r.when, r.side, r.effect = when, side, effect
    r.from = Int(r.from, 0, 15, 3)
    r.to = Int(r.to, 0, 15, 15)
    r.strength = Int(r.strength, 1, 15, 6)
    r.speed = Int(r.speed, 0, 15, 3)
    r.grow = r.grow == true
    return r
end

-- The Recommended three; old switches (cues.castTrigger...) carried over
function T.Defaults(cues)
    cues = type(cues) == "table" and cues or {}
    return {
        T.Clean({ on = cues.castTrigger ~= false, when = "cast", side = "R2", effect = "resist", from = 3, strength = 13, grow = true }),
        T.Clean({ on = cues.shotTrigger ~= false, when = "autoShot", side = "R2", effect = "weapon", from = 4, to = 8, strength = 7 }),
        T.Clean({ on = cues.lowTrigger ~= false, when = "lowHp", side = "L2", effect = "vibrate", from = 0, strength = 5, speed = 3 }),
    }
end

-- The saved rules, seeded IN PLACE (the table may be a profile's: Profiles points it)
function T.Ensure(store, cues)
    if type(store) ~= "table" then return nil end
    if store.v ~= 1 or type(store.list) ~= "table" then
        store.v, store.list = 1, T.Defaults(cues)
    end
    for i, r in ipairs(store.list) do store.list[i] = T.Clean(r) end
    while #store.list > T.MAX do table.remove(store.list) end
    return store.list
end

function T.Reset(store)
    if type(store) ~= "table" then return end
    store.v, store.list = 1, T.Defaults()
end

-- A rule's trigger parameters: mode name, start, finish, force (0-15). p: cast progress 0-1
function T.Params(r, p)
    local e = T.EFFECT[r.effect]
    local s = r.strength
    if r.grow and p then s = min(15, 2 + floor(max(0, min(1, p)) * max(0, s - 2))) end
    if r.effect == "wall" then return "resist", r.from, 0, 15 end
    if r.effect == "resist" then return "resist", r.from, 0, s end
    if r.effect == "vibrate" then return "vibrate", r.from, s, r.speed end
    return e.mode, r.from, max(r.from, r.to), s
end

local function Holds(r, state)
    if r.when == "always" then return true end
    return state[r.when] and true or false
end

-- Each trigger's effect now: { R2 = {mode,start,finish,force} or nil, L2 = ... }.
-- state: { cast = bool, autoShot = ..., progress = 0-1 }; trying: a rule shown now, first
function T.Evaluate(list, state, trying)
    local out = {}
    local function Take(r)
        local mode, a, b, c = T.Params(r, state.progress)
        local sides = r.side == "both" and { "R2", "L2" } or { r.side }
        for _, side in ipairs(sides) do
            if not out[side] then out[side] = { mode, a, b, c } end
        end
    end
    if trying then Take(T.Clean(trying)) end
    for _, r in ipairs(list or {}) do
        if r.on and Holds(r, state) then Take(r) end
    end
    return out
end

-- A row's name: "Casting · R2 · Resist"
function T.Label(r)
    local e = T.EFFECT[r.effect]
    return (T.WHEN_LABEL[r.when] or "?") .. " · " .. (r.side == "both" and "Both" or r.side) .. " · " .. (e and e.label or "?")
end

function T.Pct(v) return floor((v or 0) * 100 / 15 + 0.5) .. "%" end
function T.Hz(v) return (T.SPEED_HZ[(v or 0) + 1] or 0) .. " Hz" end
