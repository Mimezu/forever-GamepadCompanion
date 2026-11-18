-- Lights: the DualSense's lights, one light model with two renderers
-- (C:\games\WowHelper\docs\LIGHTS.md).
--
-- A light is a short sequence: bar keys (time, colour, brightness, ease),
-- player LED keys, mic keys; once, or while a state lasts (a loop, and a
-- build that can follow a cast's progress). The presets come from WoW Helper
-- (LightPresets.lua, generated); the player's own from its data addon
-- (WowHelperData.lights). Each moment picks a light, a colour, a strength.
--
-- Link off: this file plays the bar itself (~30 Hz through Haptics.lua's
-- light voices; the highest priority wins). Link on: WoW Helper plays every
-- lane precisely; the game only sets the steady colour of what holds (never
-- clears it) and sends the lights on the strip's light row.
--
-- What holds is Stack.lua's: the states in the player's order (Dead or ghost,
-- Low health, Casting, In combat, Movement, Resting…), each setting only the
-- channels it has (bar, mic, dots), over Otherwise (the base colour). Moments
-- (crits, whispers) play over it and hand back.
local _, ns = ...
local H, L = ns.Haptics, ns.HapticsLab
local LT = {}
ns.Lights = LT

local min, max, floor = math.min, math.max, math.floor
local function Now() return GetTime and GetTime() or 0 end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

---------------------------------------------------------------------------
-- Colours (the strip's tint index: docs/LIGHTS.md section 4)
---------------------------------------------------------------------------
LT.PALETTE = {
    { key = "own", label = "Own" },
    { key = "base", label = "Base" },
    { key = "school", label = "Spell school" },
    { key = "white", label = "White", rgb = { 1, 1, 1 }, tint = 1 },
    { key = "red", label = "Red", rgb = { 1, 0.05, 0.02 }, tint = 2 },
    { key = "orange", label = "Orange", rgb = { 1, 0.4, 0 }, tint = 3 },
    { key = "gold", label = "Gold", rgb = { 1, 0.75, 0.15 }, tint = 4 },
    { key = "green", label = "Green", rgb = { 0.2, 1, 0.25 }, tint = 5 },
    { key = "teal", label = "Teal", rgb = { 0, 0.9, 0.7 }, tint = 6 },
    { key = "cyan", label = "Cyan", rgb = { 0.2, 0.85, 1 }, tint = 7 },
    { key = "blue", label = "Blue", rgb = { 0.1, 0.3, 1 }, tint = 8 },
    { key = "purple", label = "Purple", rgb = { 0.65, 0.2, 1 }, tint = 9 },
    { key = "pink", label = "Pink", rgb = { 1, 0.3, 0.7 }, tint = 10 },
}
local PALETTE = {}
for _, c in ipairs(LT.PALETTE) do PALETTE[c.key] = c end

-- Spell schools, by Rumble's cast action (tint 11-20)
LT.SCHOOL = {
    fire = { 1, 0.35, 0 }, frostSpells = { 0.3, 0.6, 1 }, arcaneSpells = { 0.8, 0.4, 1 },
    shadowSpells = { 0.5, 0, 0.8 }, holy = { 1, 0.85, 0.45 }, healing = { 0.3, 1, 0.4 }, nature = { 0.4, 1, 0.2 },
    shots = { 1, 0.8, 0.3 }, travel = { 0.5, 0.8, 1 }, summon = { 0.6, 0, 1 },
}
local SCHOOL_TINT = { fire = 11, frostSpells = 12, arcaneSpells = 13, shadowSpells = 14, holy = 15, healing = 16,
    nature = 17, shots = 18, travel = 19, summon = 20 }
-- Classes (tint 21-29)
local CLASS_TINT = { WARRIOR = 21, PALADIN = 22, HUNTER = 23, ROGUE = 24, PRIEST = 25, SHAMAN = 26, MAGE = 27,
    WARLOCK = 28, DRUID = 29 }

---------------------------------------------------------------------------
-- The lights: presets, then the player's own (WoW Helper's data addon)
---------------------------------------------------------------------------
LT.GROUPS = { "Resting", "Basics", "Combat", "Casting", "World", "Social" }

-- every light: presets by id (an edited preset replaced), then the player's own
local lightsCache = {}
function LT.Lights()
    local d = type(WowHelperData) == "table" and WowHelperData or nil
    local dl = d and d.lights
    if lightsCache.list and lightsCache.presets == ns.LIGHT_PRESETS and lightsCache.data == d and lightsCache.lights == dl then
        return lightsCache.list
    end
    local list = LT.BuildLights()
    lightsCache.list, lightsCache.presets, lightsCache.data, lightsCache.lights = list, ns.LIGHT_PRESETS, d, dl
    return list
end

function LT.BuildLights()
    local list, seen, mine = {}, {}, {}
    local d = type(WowHelperData) == "table" and WowHelperData or nil
    for _, l in ipairs(d and type(d.lights) == "table" and d.lights or {}) do
        if type(l) == "table" and tonumber(l.id) and type(l.bar) == "table" then mine[tonumber(l.id)] = l end
    end
    for _, l in ipairs(ns.LIGHT_PRESETS or {}) do
        list[#list + 1] = mine[l.id] or l
        seen[l.id] = true
    end
    local yours = {}
    for id, l in pairs(mine) do if not seen[id] then yours[#yours + 1] = l end end
    table.sort(yours, function(a, b) return a.id < b.id end)
    for _, l in ipairs(yours) do l.yours = true; list[#list + 1] = l end
    return list
end

function LT.Light(id)
    if id == nil then return nil end
    for _, l in ipairs(LT.Lights()) do if l.id == id then return l end end
end

function LT.LightByKey(key)
    for _, l in ipairs(ns.LIGHT_PRESETS or {}) do if l.key == key then return l end end
end

-- A light's length (its last key, or its loop's end)
function LT.Length(l)
    local n = l.loop and l.loop[2] or 0
    for _, lane in ipairs({ l.bar or {}, l.leds or {}, l.mic or {} }) do
        for _, k in ipairs(lane) do if k[1] > n then n = k[1] end end
    end
    return n
end

---------------------------------------------------------------------------
-- Sampling (as WoW Helper's lights.rs: linear light, perceptual brightness)
---------------------------------------------------------------------------
local function lin(c)
    if c <= 0.04045 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function Ease(e, u)
    u = max(0, min(1, u))
    if e == "step" then return u >= 1 and 1 or 0 end
    if e == "in" then return u * u * u end
    if e == "out" then return 1 - (1 - u) ^ 3 end
    if e == "smooth" then return u * u * (3 - 2 * u) end
    return u
end
LT.Ease = Ease

-- a key's colour (linear), nil for dark
local function KeyRGB(col, ctx)
    local c
    if col == "tint" then c = ctx.tint elseif col == "base" then c = ctx.base elseif type(col) == "table" then c = col end
    if not c then return nil end
    return { lin(c[1]), lin(c[2]), lin(c[3]) }
end

-- The bar at time t: r, g, b (0-1, linear light), or nil (no bar lane)
-- ctx = { tint = {r,g,b}, base = {r,g,b}, strength = 0-1 }
function LT.Sample(l, t, ctx)
    local keys = l.bar
    if not keys or #keys == 0 then return nil end
    local function colour(i)
        local c = KeyRGB(keys[i][2], ctx)
        if c then return c end
        for j = i - 1, 1, -1 do c = KeyRGB(keys[j][2], ctx); if c then return c end end
        for j = i + 1, #keys do c = KeyRGB(keys[j][2], ctx); if c then return c end end
        return { 0, 0, 0 }
    end
    local function level(i) return keys[i][2] == "dark" and 0 or keys[i][3] end
    local c, lv
    if t <= keys[1][1] then
        c, lv = colour(1), level(1)
    else
        for i = 2, #keys do
            if t < keys[i][1] then
                local a, b = keys[i - 1], keys[i]
                local u = Ease(b[4], (t - a[1]) / max(1e-6, b[1] - a[1]))
                local ca = a[2] == "dark" and colour(i) or colour(i - 1)
                local cb = b[2] == "dark" and ca or colour(i)
                c = { ca[1] + (cb[1] - ca[1]) * u, ca[2] + (cb[2] - ca[2]) * u, ca[3] + (cb[3] - ca[3]) * u }
                lv = level(i - 1) + (level(i) - level(i - 1)) * u
                break
            end
        end
        if not c then c, lv = colour(#keys), level(#keys) end
    end
    local p = max(0, min(1, lv * (ctx.strength or 1))) ^ 2.2
    return c[1] * p, c[2] * p, c[3] * p
end

-- A hold's time with its loop (no loop: stays on the last key)
function LT.LoopTime(l, t)
    local lp = l.loop
    if lp and lp[2] - lp[1] > 0.01 and t > lp[2] then return lp[1] + (t - lp[1]) % (lp[2] - lp[1]) end
    return min(t, LT.Length(l))
end

---------------------------------------------------------------------------
-- Settings: db.lightBase, db.lightEvents (GamepadCompanionHapticsDB)
---------------------------------------------------------------------------
LT.BASE_MODES = { { "class", "Class" }, { "color", "Colour" }, { "off", "Off" } }
LT.RESTING = { { "steady", "Steady" }, { "breathe", "Breathe" }, { "ember", "Ember" } }
LT.MIC_MODES = { { "off", "Off" }, { "on", "On" } }   -- Otherwise's mic (a state sets its own)

-- The dots under the touchpad and the mic (orange) while a moment's light plays: the strip's
-- codes (WoW Helper's lights::Dots / MicMode; 0 = the light's own, made in WoW Helper)
LT.DOTS = {
    { key = "pass", label = "Pass" },   -- (a state: what is below shows through)
    { key = "light", label = "Light's", code = 0 },
    { key = "off", label = "Off", code = 1 },
    { key = "all", label = "All", code = 2 },
    { key = "centre", label = "Centre", code = 3 },
    { key = "pair", label = "Pair", code = 4 },
    { key = "ends", label = "Ends", code = 5 },
    { key = "spark", label = "Spark", code = 6 },
    { key = "fill", label = "Fill", code = 7 },
    { key = "sweep", label = "Sweep", code = 8 },
    { key = "ring", label = "Ring", code = 9 },
    { key = "1", label = "1", code = 10 }, { key = "2", label = "2", code = 11 }, { key = "3", label = "3", code = 12 },
    { key = "4", label = "4", code = 13 }, { key = "5", label = "5", code = 14 },
}
LT.MICS = {
    { key = "pass", label = "Pass" },
    { key = "light", label = "Light's", code = 0 },
    { key = "off", label = "Off", code = 1 },
    { key = "on", label = "On", code = 2 },
    { key = "pulse", label = "Pulse", code = 3 },
    { key = "blink", label = "Blink", code = 4 },
}
local DOTS, MICS = {}, {}
for _, d in ipairs(LT.DOTS) do DOTS[d.key] = d end
for _, m in ipairs(LT.MICS) do MICS[m.key] = m end
LT.DOT, LT.MIC = DOTS, MICS

-- strength: 8 steps (what the strip carries), 0-7 -> 1/8 .. 1
function LT.Strength(s) return (s + 1) / 8 end
local function Steps(level) return max(0, min(7, floor((tonumber(level) or 1) * 8 + 0.5) - 1)) end

function LT.Base()
    local db = H.DB()
    if type(db.lightBase) ~= "table" then db.lightBase = {} end
    local b = db.lightBase
    b.mode = b.mode or "class"
    b.color = PALETTE[b.color] and PALETTE[b.color].rgb and b.color or "blue"
    b.level = tonumber(b.level) or 0.35
    if b.light == nil then b.light = b.breathe and "breathe" or "steady" end   -- (0.27: breathe yes / no)
    if not LT.LightByKey(b.light) then b.light = "steady" end
    b.breathe = nil
    -- the mic light: in combat by default (0.29 saved "off" without asking: once)
    -- (0.28 wrote "off" without asking: that one meant In combat; a fresh profile is Off, as
    -- Recommended: L8)
    if b.micV ~= 2 then b.mic, b.micV = (b.mic == "off") and "combat" or (b.mic or "off"), 2 end
    return b
end

function LT.On()
    local db = H.DB()
    return db.engine == true and db.light == true
end

-- The base colour (rgb), nil when off
function LT.BaseRGB()
    local b = LT.Base()
    if b.mode == "off" then return nil end
    if b.mode == "class" then
        local class = UnitClass and select(2, UnitClass("player"))
        local c = class and (RAID_CLASS_COLORS or {})[class]
        if c then return { c.r, c.g, c.b } end
        return { 1, 1, 1 }
    end
    return PALETTE[b.color].rgb
end

function LT.SchoolRGB()
    local V = ns.Rumble
    local action = V and V.castAction
    if action and LT.SCHOOL[action] then return LT.SCHOOL[action] end
    if V and V.castKind and V.castKind ~= "spell" then return { 1, 0.7, 0.3 } end
    return { 1, 1, 1 }
end

function LT.ColorRGB(key)
    if key == "base" or key == "own" then return LT.BaseRGB() or { 1, 1, 1 } end
    if key == "school" then return LT.SchoolRGB() end
    local c = PALETTE[key]
    return c and c.rgb or { 1, 1, 1 }
end

-- A colour key -> the strip's tint index (0: the light's own)
function LT.Tint(key)
    if key == "own" then return 0 end
    if key == "school" then
        local V = ns.Rumble
        return V and SCHOOL_TINT[V.castAction] or 1
    end
    if key == "base" then
        local b = LT.Base()
        if b.mode == "class" then
            local class = UnitClass and select(2, UnitClass("player"))
            return CLASS_TINT[class] or 1
        end
        return PALETTE[b.color].tint or 8
    end
    return PALETTE[key] and PALETTE[key].tint or 0
end

---------------------------------------------------------------------------
-- Moments, each with its default colour and strength (0-7); its light is
-- the preset of the same key
---------------------------------------------------------------------------
LT.EVENTS = {
    { key = "crit", group = "Combat", label = "Critical hit", color = "base", strength = 7, on = true },
    { key = "critTaken", group = "Combat", label = "Critical hit taken", color = "red", strength = 6, on = true },
    { key = "hitTaken", group = "Combat", label = "Hit taken", color = "red", strength = 2, on = false },
    { key = "avoid", group = "Combat", label = "Dodge, parry, block", color = "white", strength = 2, on = false },
    { key = "kill", group = "Combat", label = "Target killed", color = "white", strength = 5, on = true },
    { key = "lowHp", group = "Combat", label = "Low health", color = "red", strength = 6, on = true, state = true },
    { key = "combat", group = "Combat", label = "In combat", color = "orange", strength = 2, on = false, state = true },
    { key = "cast", group = "Casting", label = "Casting", color = "school", strength = 6, on = true, state = true, school = true },
    { key = "release", group = "Casting", label = "Spell released", color = "school", strength = 7, on = true, school = true },
    { key = "interrupted", group = "Casting", label = "Interrupted", color = "red", strength = 6, on = true, school = true },
    { key = "instant", group = "Casting", label = "Instant ability", color = "school", strength = 3, on = false, school = true },
    { key = "halo", group = "Casting", label = "Halo ring open", color = "cyan", strength = 3, on = true, state = true },
    { key = "haloUse", group = "Casting", label = "Halo ring fired", color = "cyan", strength = 6, on = true },
    { key = "levelUp", group = "World", label = "Level up", color = "gold", strength = 7, on = true },
    { key = "questDone", group = "World", label = "Quest done", color = "gold", strength = 5, on = true },
    { key = "loot", group = "World", label = "Loot", color = "gold", strength = 4, on = false },
    { key = "death", group = "World", label = "Death", color = "red", strength = 4, on = true },
    { key = "alive", group = "World", label = "Back to life", color = "white", strength = 4, on = true },
    { key = "whisper", group = "Social", label = "Whisper", color = "purple", strength = 5, on = true },
    { key = "readyCheck", group = "Social", label = "Ready check", color = "gold", strength = 5, on = true },
    { key = "invite", group = "Social", label = "Invites, duels", color = "green", strength = 5, on = true },
    -- States (Stack.lua's conditions; FrameGambit's words): off until chosen, so nobody's look changes
    { key = "dead", group = "States", label = "Dead or ghost", look = "breathe", color = "white", strength = 1, on = false, state = true },
    { key = "afk", group = "States", label = "Away", look = "breathe", color = "base", strength = 1, on = false, state = true },
    { key = "taxi", group = "States", label = "On flight path", look = "breathe", color = "base", strength = 2, on = false, state = true },
    { key = "stealth", group = "States", label = "Stealthed", look = "breathe", color = "purple", strength = 1, on = false, state = true },
    { key = "swimming", group = "States", label = "Swimming", look = "breathe", color = "teal", strength = 2, on = false, state = true },
    { key = "mounted", group = "States", label = "Mounted", look = "steady", color = "base", strength = 4, on = false, state = true },
    { key = "moving", group = "States", label = "Movement", look = "steady", color = "base", strength = 3, on = false, state = true },
    { key = "rested", group = "States", label = "Resting", look = "breathe", color = "gold", strength = 2, on = false, state = true },
}
-- The states' Recommended order, top first (the first true one sets each channel)
LT.STACK = { "dead", "afk", "lowHp", "cast", "halo", "taxi", "stealth", "combat", "swimming", "mounted", "moving", "rested" }
-- Each moment's Recommended dots and mic (what its preset used to do on its own): data, so a
-- row shows it, the picker changes it and Default brings it back
local PATTERNS = {
    crit = { "spark" }, critTaken = { "ends" }, kill = { "all" }, lowHp = { "pair", "pulse" },
    cast = { "fill" }, release = { "all" }, halo = { "ring" }, haloUse = { "spark" }, levelUp = { "fill" },
    questDone = { "centre" }, alive = { "spark" }, whisper = { "off", "pulse" }, readyCheck = { "all", "pulse" },
    invite = { "off", "pulse" },
}
local EVENT = {}
for _, e in ipairs(LT.EVENTS) do
    local p = PATTERNS[e.key] or {}
    -- (a moment or a state with no pattern leaves the channel: Pass, 0 on the strip: L2)
    local none = "pass"
    e.dots, e.mic = p[1] or none, p[2] or none
    EVENT[e.key] = e
end
LT.EVENT = EVENT

-- A moment's definition: its own, or a sub-moment's (a spell's,
-- ns.SubMoment: "spell:instant:Frost Nova") as its parent's, under its name
local subDefs = {}
local function Sub(key)
    if EVENT[key] or not ns.SubMoment then return nil end
    return ns.SubMoment(key)
end
-- (a reaction of the stack: a light moment that lasts, named by its condition)
local stack
local rowDefs = {}
local function RowDef(key)
    local row = stack and stack:Row(key)
    if not row then return nil end
    local St = ns.Stack
    local base = EVENT[row.condition]
    local d = rowDefs[key]
    if not d then
        d = setmetatable({}, { __index = function(t, f)
            local row = rawget(t, "row")   -- (the row now, not the first one: L11)
            local base = EVENT[row.condition]
            if f == "label" then return St.Words(row) end
            if base and base.state and base[f] ~= nil then return base[f] end
            return ({ key = key, state = true, group = "States", look = "steady", color = "base", strength = 3,
                dots = "pass", mic = "pass", on = true })[f]
        end })
        rowDefs[key] = d
    end
    d.row = row
    return d
end

local function Def(key)
    local rd = RowDef(key)
    if rd then return rd end
    if EVENT[key] then return EVENT[key] end
    local parent, name = Sub(key)
    local pe = parent and EVENT[parent]
    if not pe then return nil end
    local d = subDefs[key]
    if not d then
        d = setmetatable({ key = key, label = name, parent = parent }, { __index = pe })
        subDefs[key] = d
    end
    return d
end
LT.Def = Def

-- (priority: states under events; an alarm over a flash; a spell's as its moment's)
local PRIO = { combat = 1, halo = 2, cast = 3, lowHp = 4, interrupted = 7, critTaken = 7, levelUp = 8 }
local function Prio(key)
    local d = Def(key)
    return PRIO[key] or (d and d.parent and PRIO[d.parent]) or 5
end

-- a moment's default light id (its own preset)
function LT.DefaultLight(key)
    local e = EVENT[key]
    local p = LT.LightByKey(e and e.look or key)
    return p and p.id
end

-- 0.27 effects -> a preset (the moment's own when it was the default)
local OLD_DEFAULT = { crit = "boost", critTaken = "double", hitTaken = "flash", avoid = "flash", kill = "flash",
    lowHp = "heartbeat", combat = "breathe", cast = "build", release = "flash", interrupted = "strobe", instant = "flash",
    halo = "glow", haloUse = "flash", levelUp = "rainbow", questDone = "fade", loot = "flash", death = "fade",
    alive = "fade", whisper = "double", readyCheck = "strobe", invite = "double" }
local OLD_SHAPE = { flash = "flash", boost = "crit", double = "double", strobe = "interrupted", fade = "pulse",
    rainbow = "rainbow", glow = "glow", build = "cast", heartbeat = "heartbeat", breathe = "combat" }

-- A sub-moment's light: its own (saved by its owner), else a copy of its
-- parent's (not saved: LT.Own makes it its own)
local function SubSettings(key, own)
    local parent, name, O = Sub(key)
    local s = O.Field(name, "light")
    if type(s) ~= "table" then
        local p = LT.Settings(parent)
        s = { on = p.on, light = p.light, color = p.color, strength = p.strength, dots = p.dots, mic = p.mic }
        if not own then return s end
        O.SetField(name, "light", s)
    end
    local p = EVENT[parent]
    if not LT.Light(s.light) then s.light = LT.Settings(parent).light end
    if not PALETTE[s.color] then s.color = p.color end
    s.strength = max(0, min(7, floor(tonumber(s.strength) or p.strength)))
    if not DOTS[s.dots] then s.dots = LT.Settings(parent).dots end
    if not MICS[s.mic] then s.mic = LT.Settings(parent).mic end
    s.on = s.on ~= false
    return s
end

-- A moment's light to change (a sub-moment's made its own first)
function LT.Own(key)
    if Sub(key) then return SubSettings(key, true) end
    return LT.Settings(key)
end

-- A reaction's light: the row itself ({ on, light, color, strength, dots, mic })
local function RowSettings(key)
    local d = RowDef(key)
    if not d then return nil end
    local s = d.row
    if s.light == nil then s.light = LT.DefaultLight(s.condition) or (LT.LightByKey(d.look) or {}).id end
    if s.light ~= 0 and not LT.Light(s.light) then s.light = (LT.LightByKey(d.look) or {}).id end
    if not PALETTE[s.color] then s.color = d.color end
    s.strength = max(0, min(7, floor(tonumber(s.strength) or d.strength)))
    if not DOTS[s.dots] then s.dots = d.dots end
    if not MICS[s.mic] then s.mic = d.mic end
    s.on = s.on ~= false
    return s
end

function LT.Settings(key)
    local rs = RowSettings(key)
    if rs then return rs end
    if Sub(key) then return SubSettings(key, false) end
    local db = H.DB()
    if type(db.lightEvents) ~= "table" then db.lightEvents = {} end
    local e = EVENT[key]
    local s = db.lightEvents[key]
    if type(s) ~= "table" then
        s = { on = e.on, light = LT.DefaultLight(key), color = e.color, strength = e.strength, dots = e.dots, mic = e.mic }
        db.lightEvents[key] = s
    end
    if not DOTS[s.dots] then s.dots = e.dots end   -- (before 0.46: the preset's own, now data)
    if not MICS[s.mic] then s.mic = e.mic end
    if s.effect then
        -- migrate once: the moment's own light, or the shape it had
        local own = s.effect == OLD_DEFAULT[key]
        local p = own and LT.LightByKey(key) or LT.LightByKey(OLD_SHAPE[s.effect] or key)
        s.light = p and p.id or LT.DefaultLight(key)
        s.strength = Steps(s.level)
        s.effect, s.level = nil, nil
    end
    -- (0: a state's bar passes; an unknown id was deleted in WoW Helper)
    if not (e.state and s.light == 0) and not LT.Light(s.light) then s.light = LT.DefaultLight(key) end
    if not PALETTE[s.color] then s.color = e.color end
    s.strength = max(0, min(7, floor(tonumber(s.strength) or e.strength)))
    return s
end

function LT.IsDefault(key)
    if RowDef(key) then return stack:Recommended(key) == nil or stack:IsDefault(key) end
    local _, name, O = Sub(key)
    if O then return O.Field(name, "light") == nil end
    local e, s = EVENT[key], LT.Settings(key)
    return s.on == e.on and s.light == LT.DefaultLight(key) and s.color == e.color and s.strength == e.strength
        and s.dots == e.dots and s.mic == e.mic
end

-- A moment's dots and mic as the strip's codes
function LT.Patterns(key)
    local s = LT.Settings(key)
    -- (Pass: 0, the light's own lanes, none on a preset: the hold's mic and dots go on)
    return (DOTS[s.dots] or DOTS.pass).code or 0, (MICS[s.mic] or MICS.pass).code or 0
end

-- Its dots and mic in a few words, for its row ("Spark · Mic pulse"); nil when both are off
function LT.PatternWords(key)
    local s = LT.Settings(key)
    local parts = {}
    if s.dots ~= "off" and s.dots ~= "pass" then parts[#parts + 1] = (s.dots == "light" and "Dots: light's" or (#s.dots == 1 and (s.dots .. " dots") or DOTS[s.dots].label)) end
    if s.mic ~= "off" and s.mic ~= "pass" then parts[#parts + 1] = "Mic " .. (s.mic == "light" and "light's" or MICS[s.mic].label:lower()) end
    return #parts > 0 and table.concat(parts, " · ") or nil
end

-- The moments whose light uses the mic (Setup's Mic light: Used by)
function LT.MicMoments()
    local list = {}
    for _, e in ipairs(LT.EVENTS) do
        if not e.state then
            local s = LT.Settings(e.key)
            if s.on and s.mic ~= "off" and s.mic ~= "pass" then list[#list + 1] = e.label end
        end
    end
    -- (the reactions as they are now: L14)
    for _, row in ipairs(stack and stack:Rows() or {}) do
        if row.on ~= false and row.mic and row.mic ~= "off" and row.mic ~= "pass" then list[#list + 1] = ns.Stack.Words(row) end
    end
    return list
end

function LT.Default(key)
    if RowDef(key) then return stack:Default(key) end
    local _, name, O = Sub(key)
    if O then return O.SetField(name, "light", nil) end
    H.DB().lightEvents[key] = nil
end

---------------------------------------------------------------------------
-- Who draws: WoW Helper when the link is on (v2), else the game
---------------------------------------------------------------------------
local function K() return ns.HelperLink end

function LT.HelperDrives()
    local k = K()
    return k ~= nil and k.Enabled() and k.V2() and H.DB().lightGameOnly ~= true
end

local states = {}   -- key -> ctx while a state lasts

-- a light voice for the game's renderer: fn(now, v) -> r, g, b or nil
local function Voice(l, ctx, active, progress)
    local fit = l.fit and l.loop and progress
    return function(now, v)
        local el = now - v.start
        local t
        if l.kind == "once" then
            if el > LT.Length(l) then return nil end
            t = el
        else
            if active and not active() then return nil end
            if fit then
                local p = progress()
                if p < 1 then
                    t = p * l.loop[1]
                else
                    v.full = v.full or now
                    t = LT.LoopTime(l, l.loop[1] + (now - v.full))
                end
            else
                t = LT.LoopTime(l, el)
            end
        end
        local r, g, b = LT.Sample(l, t, ctx)
        if r == nil then return 0, 0, 0 end
        return r, g, b
    end
end
LT.Voice = Voice

local function Ctx(colorKey, strength)
    return { tint = LT.ColorRGB(colorKey), base = LT.BaseRGB() or { 0, 0, 0 }, strength = LT.Strength(strength) }
end
LT.Ctx = Ctx

---------------------------------------------------------------------------
-- The stack (Stack.lua): states in the player's order over Otherwise
---------------------------------------------------------------------------
local St = ns.Stack
local Store, FromStates, Recommended   -- (below; Migrate uses them)

-- Silently, once: the mic card's "In combat" becomes the In combat state's mic
-- (its bar passing when it had no light), a state's "off" dots / mic become
-- Pass (before the stack nothing was below them)
local Repair
local function Migrate()
    local b = LT.Base()
    if b.stackV == 1 then FromStates(); return Repair() end
    b.stackV = 1
    local db = H.DB()
    for key, s in pairs(type(db.lightEvents) == "table" and db.lightEvents or {}) do
        local e = EVENT[key]
        if e and e.state and type(s) == "table" then
            if s.dots == "off" then s.dots = "pass" end
            if s.mic == "off" then s.mic = "pass" end
        end
    end
    FromStates()
    if b.mic == "combat" then
        local ev = type(db.lightEvents) == "table" and db.lightEvents or {}
        db.lightEvents = ev
        local s = ev.combat
        if type(s) ~= "table" then
            local e = EVENT.combat
            s = { on = e.on, light = LT.DefaultLight("combat"), color = e.color, strength = e.strength, dots = "pass", mic = "pass" }
            ev.combat = s
        end
        if not s.on then s.on, s.light = true, 0 end
        s.mic, b.mic = "on", "off"
        -- (rows already there: the same on In combat's)
        local row = stack and type(Store().rows) == "table" and stack:Row("combat")
        if row then row.on, row.mic = true, "on"; if row.light == nil or not s.light or s.light == 0 then row.light = 0 end end
    end
    Repair()
end
LT.Migrate = Migrate

-- Once: profiles where the reactions were made before 0.48's conversion ran (L1): a state's
-- copied "off" mic / dots (then the "none" default) become Pass, as its 0.48 setting says;
-- moments' unasked "off" (0.46's default) becomes Pass (L2)
Repair = function()
    local store, b, db = Store(), LT.Base(), H.DB()
    local ev = type(db.lightEvents) == "table" and db.lightEvents or {}
    if not store.repairL1 then
        store.repairL1 = true
        if type(store.rows) == "table" then
            for _, row in ipairs(store.rows) do
                local was = ev[row.id]
                if EVENT[row.id] and EVENT[row.id].state and type(was) == "table" then
                    if row.mic == "off" and was.mic == "pass" then row.mic = "pass" end
                    if row.dots == "off" and was.dots == "pass" then row.dots = "pass" end
                end
            end
        end
    end
    if not b.passV then
        b.passV = 1
        for key, s in pairs(ev) do
            local e = EVENT[key]
            if e and not e.state and type(s) == "table" then
                if s.mic == "off" and e.mic == "pass" then s.mic = "pass" end
                if s.dots == "off" and e.dots == "pass" then s.dots = "pass" end
            end
        end
    end
end

-- The stack's order is the Feel profile's (db.lightStack)
Store = function()
    local db = H.DB()
    if type(db.lightStack) ~= "table" then db.lightStack = {} end
    return db.lightStack
end

-- What Otherwise shows: the base light in the base colour, the base mic, no dots
local function BaseValue(ch)
    local b = LT.Base()
    if ch == "bar" then return "base" end
    if ch == "mic" then return b.mic == "on" and "on" or "off" end
    return "off"
end

-- A channel's value from a reaction (nil: it passes)
local function LayerValue(row, ch)
    local s = LT.Settings(row.id)
    if ch == "bar" then return s.light ~= 0 and row.id or nil end
    local v = ch == "mic" and s.mic or s.dots
    if v == "pass" then return nil end
    return v
end

-- The Recommended reactions: the states, in LT.STACK's order, as shipped
Recommended = function()
    local rows = {}
    for _, key in ipairs(LT.STACK) do
        local e = EVENT[key]
        rows[#rows + 1] = { id = key, condition = key, on = e.on, light = LT.DefaultLight(key), color = e.color,
            strength = e.strength, dots = e.dots, mic = e.mic }
    end
    return rows
end

-- 0.48's states (an order and each state's light in lightEvents) become reactions, once
FromStates = function()
    local store = Store()
    if type(store.rows) == "table" or store.fromStates then return end
    store.fromStates = true   -- (once: Default afterwards means as shipped)
    local db = H.DB()
    local saved = type(db.lightEvents) == "table" and db.lightEvents or {}
    local any = type(store.order) == "table"
    for _, key in ipairs(LT.STACK) do if type(saved[key]) == "table" then any = true end end
    if not any then return end
    local order = type(store.order) == "table" and store.order or LT.STACK
    local rows, seen = {}, {}
    local rec = {}
    for _, r in ipairs(Recommended()) do rec[r.id] = r end
    local function take(key)
        if seen[key] or not rec[key] then return end
        seen[key] = true
        local row, s = St.Copy(rec[key]), saved[key]
        if type(s) == "table" then
            for _, f in ipairs({ "on", "light", "color", "strength", "dots", "mic" }) do if s[f] ~= nil then row[f] = s[f] end end
        end
        rows[#rows + 1] = row
    end
    for _, key in ipairs(order) do take(key) end
    for _, key in ipairs(LT.STACK) do take(key) end
    store.rows, store.order = rows, nil
end

-- What the bar shows now -> state key (nil: Otherwise), light, colour key, strength, progress fn
local function Holding()
    local r = stack and stack:Now()
    local key = r and r.bar.row and r.bar.row.id or nil
    if key then
        local s = LT.Settings(key)
        local row = r.bar.row
        local ctx = states[key] or states[row.condition]
        for _, q in ipairs(row.requirements or {}) do ctx = ctx or states[q] end
        return key, LT.Light(s.light), s.color, s.strength, ctx and ctx.progress
    end
    local b = LT.Base()
    if not LT.On() or b.mode == "off" then return nil end
    return nil, LT.LightByKey(b.light), "base", Steps(b.level)
end
LT.Holding = Holding

-- A channel's code on the strip (a light's own lanes only with its own bar)
local function Code(list, res, barRow, default)
    local v = list[res.value]
    if not v then return default end
    if v.code == 0 and res.row ~= barRow then return default end
    return v.code or default
end

-- The stack's result, drawn: by WoW Helper (the light row, the steady colour
-- under it) or by the game (the bar)
local lastStep, lastIdx
local function MicWord(code)
    return (code == MICS.on.code) and "on" or (code == MICS.pulse.code or code == MICS.blink.code) and "pulse" or "off"
end

local function Draw()
    Migrate()   -- (once; here: the Feel profile's tables are in place by now)
    local k = K()
    local key, l, color, strength, progress = Holding()
    -- the mic, whoever draws the bar (lights off: Off): L3
    if k and k.SetMic then
        local r0 = stack:Now()
        k.SetMic(LT.On() and MicWord(Code(MICS, r0.mic, r0.bar.row, MICS.off.code)) or "off")
    end
    if LT.HelperDrives() then
        if not (k and k.SetLight) then return end
        if not LT.On() then
            H.LightStop("lt_base")
            return k.SetLight(nil)
        end
        local r = stack:Now()
        local p = progress and progress()
        lastStep = p and (1 + floor(max(0, min(1, p)) * 14 + 0.5)) or 0
        local barRow = r.bar.row
        local mic = Code(MICS, r.mic, barRow, MICS.off.code)
        k.SetLight({ version = k.LightVersion(),
            hold = l and l.id or 0, holdTint = LT.Tint(color or "base"), holdStrength = strength or 0,
            progress = lastStep, resting = key == nil, holdDots = Code(DOTS, r.dots, barRow, DOTS.off.code), holdMic = mic })
        if l then
            local rr, g, b = LT.Sample(l, l.loop and l.loop[1] or 0, Ctx(color, strength))
            if rr then return H.Light("lt_base", function() return rr, g, b end, 0) end
        end
        return H.LightStop("lt_base")
    end
    if k and k.SetLight then k.SetLight(nil) end
    if not (LT.On() and l) then return H.LightStop("lt_base") end
    -- from what shows now to the new one: Fade in when a higher reaction takes over, Fade out
    -- when it hands back
    local r = stack:Now()
    local idx = r.bar.row and select(2, stack:Row(r.bar.row.id)) or 1e9
    local fade = (lastIdx and idx < lastIdx) and r.timing.fadeIn or r.timing.fadeOut
    lastIdx = idx
    local fr, fg, fb, lit = 0, 0, 0, false
    if H.LedNow then fr, fg, fb, lit = H.LedNow() end
    local voice = Voice(l, Ctx(color, strength), nil, progress)
    local from = lit and fade > 0 and { fr, fg, fb } or nil
    H.Light("lt_base", function(now, v)
        local nr, ng, nb = voice(now, v)
        local u = from and (now - v.start) / fade or 1
        if u >= 1 or not nr then return nr, ng, nb end
        return from[1] + (nr - from[1]) * u, from[2] + (ng - from[2]) * u, from[3] + (nb - from[3]) * u
    end, 0)
end

-- (re-drawn when a setting changes; the stack calls it when what wins changes)
function LT.SendHold()
    if stack then stack:Refresh(true) end
end

-- Start a moment's light: over the stack, then back to it (not while hushed: lights at rest)
local function Play(key, ctx, force)
    if not (LT.On() or force) then return end
    if not force and St and St.Is("hush") then return end
    local s = LT.Settings(key)
    if not (s.on or force) then return end
    local l = LT.Light(s.light)
    if not l then return end
    if LT.HelperDrives() then
        return K().LightCue(l.id, LT.Tint(s.color), s.strength, LT.Patterns(key))
    end
    if not ctx then
        local start = Now()
        ctx = { active = function() return Now() - start < 1.2 end }
    end
    H.Light("lt_" .. key, Voice(l, Ctx(s.color, s.strength), ctx.active, ctx.progress), Prio(key))
end

function LT.Fire(key)
    local d = Def(key)
    if d and not d.state then Play(key) end
end

-- The light `key` plays now: the spell playing it's own, else its own
-- (SpellOverrides: a spell with a light of its own)
local function Spelled(key, name)
    local O = ns.SpellOverrides
    return O and O.Now(key, "light", name) or key
end
LT.Spelled = Spelled

-- A state this module knows of (Low health, Casting, Halo): on the stack
function LT.StartState(key, ctx)
    if not EVENT[key] then return end
    ctx = ctx or {}
    local alive = true
    ctx.stop = function() alive = false end
    local own = ctx.active
    ctx.active = function() return alive and (not own or own()) end
    states[key] = ctx
    if St then St.Set(key, true); stack:Refresh(true) end
end

function LT.EndState(key)
    local ctx = states[key]
    if ctx then ctx.stop() end
    states[key] = nil
    if St then St.Set(key, false) end
end

-- Try a moment's light (or another light for it): a state for 3 s, a cast
-- filling up. With the link, WoW Helper plays it.
function LT.Try(key, lightId)
    local e = Def(key)
    if not e then return end
    local s = LT.Settings(key)
    local l = LT.Light(lightId or s.light)
    if not l then return end
    if LT.HelperDrives() then
        local dots, mic = LT.Patterns(key)
        -- (a Try goes out even while hushed: L2-5)
        if l.kind == "once" then return K().Preview(K().LightCue, l.id, LT.Tint(s.color), s.strength, dots, mic) end
        K().SetLight({ version = K().LightVersion(), hold = l.id, holdTint = LT.Tint(s.color), holdStrength = s.strength, progress = 0, holdDots = dots, holdMic = mic })
        if C_Timer then C_Timer.After(3, LT.SendHold) end
        return
    end
    local start = Now()
    local active = function() return Now() - start < 3 end
    local progress = function() return min(1, (Now() - start) / 2.5) end
    H.Light("lt_" .. key, Voice(l, Ctx(s.color, s.strength), active, progress), 9)
    if key == "cast" and C_Timer then
        C_Timer.After(2.5, function() LT.Try("release") end)
    end
end

-- Otherwise (the base colour, its light, its mic) or a state changed: draw again
function LT.ApplyBase() LT.SendHold() end
LT.ApplyMic = LT.ApplyBase

-- The stack: states in the player's order, three channels
if St then
    stack = St.Kind("lights", {
        channels = { "bar", "mic", "dots" },
        recommended = Recommended(),
        store = Store,
        value = function(row, ch) if not LT.On() then return nil end return LayerValue(row, ch) end,
        base = BaseValue,
        apply = function() Draw() end,
        timing = { fadeIn = 0.25, fadeOut = 0.4, wait = 0 },
        prepare = function() Migrate() end,   -- (the one load step, in order: L1)
    })
end
LT.stack = stack

---------------------------------------------------------------------------
-- Cues: Rumble's events and the Beta events (wrapped, so a light plays
-- whether or not the event vibrates), and casts
---------------------------------------------------------------------------
local FROM_RUMBLE = { crit = "crit", critRanged = "crit", critted = "critTaken", interrupted = "interrupted",
    instant = "instant", levelUp = "levelUp", haloUse = "haloUse" }
local FROM_LAB = { hitTaken = "hitTaken", dodge = "avoid", parry = "avoid", block = "avoid", missedYou = "avoid", kill = "kill", questDone = "questDone", loot = "loot",
    death = "death", alive = "alive", whisper = "whisper", readyCheck = "readyCheck", invite = "invite" }

local function Wrap()
    local V = ns.Rumble
    if V and not V.lightsWrapped then
        V.lightsWrapped = true
        local fire, endLoop = V.Fire, V.EndLoop
        V.Fire = function(key, ...)
            fire(key, ...)
            if FROM_RUMBLE[key] then LT.Fire(Spelled(FROM_RUMBLE[key])) end
            if key == "lowHp" then LT.StartState("lowHp") end
            if key == "haloOpen" then LT.StartState("halo") end
            if key == "haloUse" or key == "haloClose" then LT.EndState("halo") end
        end
        V.EndLoop = function(key, ...)
            endLoop(key, ...)
            if key == "lowHp" then LT.EndState("lowHp") end
        end
    end
    if L and not L.lightsWrapped then
        L.lightsWrapped = true
        local fire = L.Fire
        L.Fire = function(key, ...)
            fire(key, ...)
            if FROM_LAB[key] then LT.Fire(FROM_LAB[key]) end
        end
    end
end
Wrap()

-- Casts: a state while it lasts (its progress from the cast bar), a flash
-- when a cast (not a channel, not an instant) goes off
local cast = { start = nil }
local function CastTimes(channel)
    local info = channel and UnitChannelInfo or UnitCastingInfo
    if not info then return nil end
    local s, e = select(4, info("player"))
    if not (s and e) or secret(s) or secret(e) then return nil end
    return s / 1000, e / 1000
end

local frame = CreateFrame("Frame")
for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_DELAYED" }) do
    if not pcall(frame.RegisterUnitEvent, frame, ev, "player") then pcall(frame.RegisterEvent, frame, ev) end
end
for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
    pcall(frame.RegisterEvent, frame, ev)
end

local function SameCast(guid)
    if guid == nil or cast.guid == nil or secret(guid) or secret(cast.guid) then return true end
    return guid == cast.guid
end

-- (a cast's spell, by name: its own release light)
local function CastSpell(spellID)
    local O = ns.SpellOverrides
    return O and O.NameOf(spellID) or nil
end

frame:SetScript("OnEvent", function(_, event, unit, guid, spellID)
    if event == "ADDON_LOADED" then
        if unit == "GamepadCompanion" then Wrap() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then return end   -- (the stack's)
    if unit and unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
        local s, e = CastTimes(channel)
        cast.start, cast.finish, cast.channel = s or Now(), e or (Now() + 1.5), channel
        cast.guid, cast.stopped, cast.spell = guid, nil, CastSpell(spellID)
        LT.StartState("cast", { progress = function()
            if not cast.start then return 1 end
            local span = cast.finish - cast.start
            return span > 0 and min(1, max(0, (Now() - cast.start) / span)) or 1
        end })
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        local s, e = CastTimes(false)
        if s and cast.start then cast.start, cast.finish = s, e end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if cast.start and not cast.channel and SameCast(guid) and (not cast.stopped or Now() - cast.stopped < 0.5) then
            cast.start = nil
            LT.EndState("cast")
            LT.Fire(Spelled("release", cast.spell))
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local ran = cast.start and cast.finish and Now() >= cast.finish - 0.3
        cast.start = nil
        LT.EndState("cast")
        if ran then LT.Fire(Spelled("release", cast.spell)) end
    elseif event == "UNIT_SPELLCAST_STOP" then
        if cast.start and not cast.channel and SameCast(guid) then
            cast.stopped = Now()
            LT.EndState("cast")
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        if cast.start and (cast.channel and event == "UNIT_SPELLCAST_INTERRUPTED" or not cast.channel and SameCast(guid)) then
            cast.start = nil
            LT.EndState("cast")
        end
    end
end)

-- With the link: a state's progress on the strip in 15 steps (WoW Helper
-- interpolates between them)
local ticker = 0
function LT.Tick(elapsed)
    ticker = ticker + (elapsed or 0)
    if ticker < 0.05 then return end
    ticker = 0
    if not (LT.HelperDrives() and next(states)) then return end
    local _, _, _, _, progress = Holding()
    if progress and 1 + floor(max(0, min(1, progress())) * 14 + 0.5) ~= lastStep then LT.SendHold() end
end
frame:SetScript("OnUpdate", function(_, elapsed) LT.Tick(elapsed) end)

-- The lights on or off, the base applied again
function LT.SetOn(on)
    H.DB().light = on == true
    H.LightStop()
    for key in pairs(states) do states[key] = nil end
    LT.ApplyBase()
end

-- The link changed (on, off, v1 / v2): who draws changes
function LT.LinkChanged()
    H.LightStop()
    LT.ApplyBase()
    LT.ApplyMic()
end
