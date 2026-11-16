-- Lights (Beta engine): the DualSense light bar as a second channel.
--
-- A base colour (the class's, one picked, or off, steady or breathing),
-- and light events, each with its own effect (a flash, the base flashing
-- brighter, a double blink, a strobe, a glow, a build-up, a heartbeat, a
-- rainbow, a fade), colour (the base's, the spell school's, or one picked)
-- and strength. Events take their cue from Rumble's events (crits, level up,
-- low health, interrupts, Halo rings), the Beta events (hits, kills,
-- whispers...) and casts (a glow building with the cast, a flash as it is
-- released), whether or not those vibrate. Played on Haptics.lua's light
-- voices: the highest priority wins.
local _, ns = ...
local H, L = ns.Haptics, ns.HapticsLab
local LT = {}
ns.Lights = LT

local min, max, floor, sin, cos, pi, abs = math.min, math.max, math.floor, math.sin, math.cos, math.pi, math.abs
local function Now() return GetTime and GetTime() or 0 end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

---------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------
LT.PALETTE = {
    { key = "base", label = "Base" },
    { key = "school", label = "Spell school" },
    { key = "white", label = "White", rgb = { 1, 1, 1 } },
    { key = "red", label = "Red", rgb = { 1, 0.05, 0.02 } },
    { key = "orange", label = "Orange", rgb = { 1, 0.4, 0 } },
    { key = "gold", label = "Gold", rgb = { 1, 0.75, 0.15 } },
    { key = "green", label = "Green", rgb = { 0.2, 1, 0.25 } },
    { key = "teal", label = "Teal", rgb = { 0, 0.9, 0.7 } },
    { key = "cyan", label = "Cyan", rgb = { 0.2, 0.85, 1 } },
    { key = "blue", label = "Blue", rgb = { 0.1, 0.3, 1 } },
    { key = "purple", label = "Purple", rgb = { 0.65, 0.2, 1 } },
    { key = "pink", label = "Pink", rgb = { 1, 0.3, 0.7 } },
}
local PALETTE = {}
for _, c in ipairs(LT.PALETTE) do PALETTE[c.key] = c end

-- Spell schools, by Rumble's cast action
LT.SCHOOL = {
    fire = { 1, 0.35, 0 }, frostSpells = { 0.3, 0.6, 1 }, arcaneSpells = { 0.8, 0.4, 1 },
    shadowSpells = { 0.5, 0, 0.8 }, holy = { 1, 0.85, 0.45 }, healing = { 0.3, 1, 0.4 }, nature = { 0.4, 1, 0.2 },
    shots = { 1, 0.8, 0.3 }, travel = { 0.5, 0.8, 1 }, summon = { 0.6, 0, 1 },
}

---------------------------------------------------------------------------
-- Settings: db.lightBase, db.lightEvents (GamepadCompanionHapticsDB)
---------------------------------------------------------------------------
LT.BASE_MODES = { { "class", "Class" }, { "color", "Colour" }, { "off", "Off" } }

function LT.Base()
    local db = H.DB()
    if type(db.lightBase) ~= "table" then db.lightBase = {} end
    local b = db.lightBase
    b.mode = b.mode or "class"
    b.color = PALETTE[b.color] and PALETTE[b.color].rgb and b.color or "blue"
    b.level = tonumber(b.level) or 0.35
    if b.breathe == nil then b.breathe = false end
    return b
end

function LT.On()
    local db = H.DB()
    return db.engine == true and db.light == true
end

-- The base colour (rgb, full brightness), nil when off
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

-- The school colour of the cast going on (white when none)
function LT.SchoolRGB()
    local V = ns.Rumble
    local action = V and V.castAction
    if action and LT.SCHOOL[action] then return LT.SCHOOL[action] end
    if V and V.castKind and V.castKind ~= "spell" then return { 1, 0.7, 0.3 } end
    return { 1, 1, 1 }
end

function LT.ColorRGB(key)
    if key == "base" then return LT.BaseRGB() or { 1, 1, 1 } end
    if key == "school" then return LT.SchoolRGB() end
    local c = PALETTE[key]
    return c and c.rgb or { 1, 1, 1 }
end

---------------------------------------------------------------------------
-- Effects: each gives a light function (now, voice) -> r, g, b or nil
-- ctx: { active = fn() (a state's: still going?), progress = fn() 0-1 }
---------------------------------------------------------------------------
local function scaled(c, k) return c[1] * k, c[2] * k, c[3] * k end

local function hue(h)
    h = (h % 1) * 6
    local x = 1 - abs(h % 2 - 1)
    local i = floor(h)
    local t = ({ { 1, x, 0 }, { x, 1, 0 }, { 0, 1, x }, { 0, x, 1 }, { x, 0, 1 }, { 1, 0, x } })[i + 1]
    return t[1], t[2], t[3]
end

LT.EFFECTS = {
    { key = "flash", label = "Flash", fn = function(c, level)
        return function(now, v)
            local t = (now - v.start) / 0.45
            if t >= 1 then return nil end
            return scaled(c, level * (1 - t) ^ 2)
        end
    end },
    { key = "boost", label = "Base brighter", fn = function(c, level)
        -- the base colour jumping to full and settling back (a crit)
        return function(now, v)
            local t = now - v.start
            if t >= 0.7 then return nil end
            local base = LT.Base().level
            local k = t < 0.06 and level or level + (base - level) * ((t - 0.06) / 0.64) ^ 0.7
            return scaled(c, max(base, k))
        end
    end },
    { key = "double", label = "Double blink", fn = function(c, level)
        return function(now, v)
            local t = now - v.start
            if t >= 0.5 then return nil end
            if t < 0.12 or (t >= 0.24 and t < 0.36) then return scaled(c, level) end
            return 0, 0, 0
        end
    end },
    { key = "strobe", label = "Strobe", fn = function(c, level)
        return function(now, v)
            local t = now - v.start
            if t >= 0.6 then return nil end
            if (t % 0.12) < 0.06 then return scaled(c, level) end
            return 0, 0, 0
        end
    end },
    { key = "fade", label = "Fade in and out", fn = function(c, level)
        return function(now, v)
            local t = now - v.start
            if t >= 1.6 then return nil end
            local k = t < 0.3 and t / 0.3 or t < 0.7 and 1 or 1 - (t - 0.7) / 0.9
            return scaled(c, level * k)
        end
    end },
    { key = "rainbow", label = "Rainbow", fn = function(c, level)
        return function(now, v)
            local t = now - v.start
            if t >= 2.4 then return nil end
            local r, g, b = hue(t / 1.2)
            local k = level * (t > 1.8 and (2.4 - t) / 0.6 or 1)
            return r * k, g * k, b * k
        end
    end },
    -- States: while something lasts
    { key = "glow", label = "Glow", state = true, fn = function(c, level, ctx)
        return function(now, v)
            if ctx.active and not ctx.active() then return nil end
            local k = 0.55 + 0.45 * sin((now - v.start) * 2 * pi * 0.9)
            return scaled(c, level * k)
        end
    end },
    { key = "build", label = "Build up", state = true, fn = function(c, level, ctx)
        -- brighter as it goes, a quickening shimmer near the end (a cast)
        return function(now, v)
            if ctx.active and not ctx.active() then return nil end
            local p = ctx.progress and ctx.progress() or min(1, (now - v.start) / 2)
            local shimmer = 1 - 0.25 * p * (0.5 + 0.5 * sin((now - v.start) * 2 * pi * (2 + 8 * p)))
            return scaled(c, level * (0.12 + 0.88 * p * p) * shimmer)
        end
    end },
    { key = "heartbeat", label = "Heartbeat", state = true, fn = function(c, level, ctx)
        return function(now, v)
            if ctx.active and not ctx.active() then return nil end
            local t = (now - v.start) % 0.9
            local k = t < 0.12 and 1 - t / 0.12 * 0.4 or t < 0.25 and 0.25 or t < 0.35 and 0.75 or
                max(0.12, 0.75 - (t - 0.35) / 0.4)
            return scaled(c, level * k)
        end
    end },
    { key = "breathe", label = "Breathe", state = true, fn = function(c, level, ctx)
        return function(now, v)
            if ctx.active and not ctx.active() then return nil end
            local k = 0.3 + 0.7 * (0.5 - 0.5 * cos((now - v.start) * 2 * pi / 3.2))
            return scaled(c, level * k)
        end
    end },
}
local EFFECT = {}
for _, e in ipairs(LT.EFFECTS) do EFFECT[e.key] = e end

---------------------------------------------------------------------------
-- Light events, each with its default effect, colour and strength
---------------------------------------------------------------------------
LT.GROUPS = { "Combat", "Casting", "World", "Social" }
LT.EVENTS = {
    { key = "crit", group = "Combat", label = "Critical hit", effect = "boost", color = "base", level = 1, on = true },
    { key = "critTaken", group = "Combat", label = "Critical hit taken", effect = "double", color = "red", level = 0.9, on = true },
    { key = "hitTaken", group = "Combat", label = "Hit taken", effect = "flash", color = "red", level = 0.3, on = false },
    { key = "avoid", group = "Combat", label = "Dodge, parry, block", effect = "flash", color = "white", level = 0.25, on = false },
    { key = "kill", group = "Combat", label = "Target killed", effect = "flash", color = "white", level = 0.8, on = true },
    { key = "lowHp", group = "Combat", label = "Low health", effect = "heartbeat", color = "red", level = 0.85, on = true, state = true },
    { key = "combat", group = "Combat", label = "In combat", effect = "breathe", color = "orange", level = 0.35, on = false, state = true },
    { key = "cast", group = "Casting", label = "Casting", effect = "build", color = "school", level = 0.9, on = true, state = true },
    { key = "release", group = "Casting", label = "Spell released", effect = "flash", color = "school", level = 1, on = true },
    { key = "interrupted", group = "Casting", label = "Interrupted", effect = "strobe", color = "red", level = 0.9, on = true },
    { key = "instant", group = "Casting", label = "Instant ability", effect = "flash", color = "school", level = 0.45, on = false },
    { key = "halo", group = "Casting", label = "Halo ring open", effect = "glow", color = "cyan", level = 0.5, on = true, state = true },
    { key = "haloUse", group = "Casting", label = "Halo ring fired", effect = "flash", color = "cyan", level = 0.85, on = true },
    { key = "levelUp", group = "World", label = "Level up", effect = "rainbow", color = "gold", level = 1, on = true },
    { key = "questDone", group = "World", label = "Quest done", effect = "fade", color = "gold", level = 0.7, on = true },
    { key = "loot", group = "World", label = "Loot", effect = "flash", color = "gold", level = 0.4, on = false },
    { key = "death", group = "World", label = "Death", effect = "fade", color = "red", level = 0.6, on = true },
    { key = "alive", group = "World", label = "Back to life", effect = "fade", color = "white", level = 0.6, on = true },
    { key = "whisper", group = "Social", label = "Whisper", effect = "double", color = "purple", level = 0.8, on = true },
    { key = "readyCheck", group = "Social", label = "Ready check", effect = "strobe", color = "gold", level = 0.8, on = true },
    { key = "invite", group = "Social", label = "Invites, duels", effect = "double", color = "green", level = 0.7, on = true },
}
local EVENT = {}
for _, e in ipairs(LT.EVENTS) do EVENT[e.key] = e end
LT.EVENT = EVENT

-- (priority: states under events; an alarm over a flash)
local PRIO = { combat = 1, halo = 2, cast = 3, lowHp = 4, interrupted = 7, critTaken = 7, levelUp = 8 }

function LT.Settings(key)
    local db = H.DB()
    if type(db.lightEvents) ~= "table" then db.lightEvents = {} end
    local e = EVENT[key]
    local s = db.lightEvents[key]
    if type(s) ~= "table" then
        s = { on = e.on, effect = e.effect, color = e.color, level = e.level }
        db.lightEvents[key] = s
    end
    if not EFFECT[s.effect] then s.effect = e.effect end
    if not PALETTE[s.color] then s.color = e.color end
    s.level = tonumber(s.level) or e.level
    return s
end

function LT.Effect(key) return EFFECT[key] end

---------------------------------------------------------------------------
-- Playing
---------------------------------------------------------------------------
local states = {}   -- key -> ctx while a state lasts

-- Start an event's light (a state: ctx.active says while it lasts)
local function Play(key, ctx, force)
    if not (LT.On() or force) then return end
    local s = LT.Settings(key)
    if not (s.on or force) then return end
    local e = EFFECT[s.effect]
    local rgb = LT.ColorRGB(s.color)
    if not ctx then
        local start = Now()
        ctx = { active = function() return Now() - start < 1.2 end }
    end
    -- (a one-off effect on a state: once at its start)
    H.Light("lt_" .. key, e.fn(rgb, s.level, ctx or {}), PRIO[key] or 5)
end

function LT.Fire(key) if EVENT[key] and not EVENT[key].state then Play(key) end end

function LT.StartState(key, ctx)
    if not EVENT[key] then return end
    ctx = ctx or {}
    local alive = true
    ctx.stop = function() alive = false end
    local own = ctx.active
    ctx.active = function() return alive and (not own or own()) end
    states[key] = ctx
    Play(key, ctx)
end

function LT.EndState(key)
    local ctx = states[key]
    if ctx then ctx.stop() end
    states[key] = nil
    H.LightStop("lt_" .. key)
end

-- Try: as the game would (a state for 3 s, a cast filling up)
function LT.Try(key)
    local e = EVENT[key]
    if not e then return end
    local start = Now()
    local ctx = { active = function() return Now() - start < 3 end,
        progress = function() return min(1, (Now() - start) / 2.5) end }
    Play(key, ctx, true)
    if key == "cast" then
        C_Timer.After(2.5, function() Play("release", nil, true) end)
    end
end

-- The base colour, steady or breathing
function LT.ApplyBase()
    local rgb = LT.On() and LT.BaseRGB()
    if not rgb then return H.LightStop("lt_base") end
    local b = LT.Base()
    H.Light("lt_base", function(now, v)
        local k = b.level
        if b.breathe then k = k * (0.45 + 0.55 * (0.5 - 0.5 * cos((now - v.start) * 2 * pi / 4))) end
        return rgb[1] * k, rgb[2] * k, rgb[3] * k
    end, 0)
end

---------------------------------------------------------------------------
-- Cues: Rumble's events and the Beta events (wrapped, so a light plays
-- whether or not the event vibrates), and casts
---------------------------------------------------------------------------
local FROM_RUMBLE = { crit = "crit", critRanged = "crit", critted = "critTaken", interrupted = "interrupted",
    instant = "instant", levelUp = "levelUp", haloUse = "haloUse" }
local FROM_LAB = { hitTaken = "hitTaken", avoid = "avoid", kill = "kill", questDone = "questDone", loot = "loot",
    death = "death", alive = "alive", whisper = "whisper", readyCheck = "readyCheck", invite = "invite" }

local function Wrap()
    local V = ns.Rumble
    if V and not V.lightsWrapped then
        V.lightsWrapped = true
        local fire, endLoop = V.Fire, V.EndLoop
        V.Fire = function(key, ...)
            fire(key, ...)
            if FROM_RUMBLE[key] then LT.Fire(FROM_RUMBLE[key]) end
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

-- An event about this cast (another spell's failed attempt mid-cast doesn't
-- count; hidden or missing IDs: it does)
local function SameCast(guid)
    if guid == nil or cast.guid == nil or secret(guid) or secret(cast.guid) then return true end
    return guid == cast.guid
end

frame:SetScript("OnEvent", function(_, event, unit, guid)
    if event == "ADDON_LOADED" then
        if unit == "GamepadCompanion" then Wrap() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then return LT.ApplyBase() end
    if event == "PLAYER_REGEN_DISABLED" then return LT.StartState("combat") end
    if event == "PLAYER_REGEN_ENABLED" then return LT.EndState("combat") end
    if unit and unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
        local s, e = CastTimes(channel)
        cast.start, cast.finish, cast.channel = s or Now(), e or (Now() + 1.5), channel
        cast.guid, cast.stopped = guid, nil
        LT.StartState("cast", { progress = function()
            local span = cast.finish - cast.start
            return span > 0 and min(1, max(0, (Now() - cast.start) / span)) or 1
        end })
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        local s, e = CastTimes(false)
        if s and cast.start then cast.start, cast.finish = s, e end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- (before or just after its STOP)
        if cast.start and not cast.channel and SameCast(guid) and (not cast.stopped or Now() - cast.stopped < 0.5) then
            cast.start = nil
            LT.EndState("cast")
            LT.Fire("release")
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local ran = cast.start and cast.finish and Now() >= cast.finish - 0.3
        cast.start = nil
        LT.EndState("cast")
        if ran then LT.Fire("release") end
    elseif event == "UNIT_SPELLCAST_STOP" then
        -- (how it ended comes with SUCCEEDED or INTERRUPTED, either order)
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

-- The light bar on or off (Light tab), the base applied again
function LT.SetOn(on)
    H.DB().light = on == true
    H.LightStop()
    for key in pairs(states) do states[key] = nil end
    LT.ApplyBase()
end
