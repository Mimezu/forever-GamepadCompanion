-- Triggers on the stack (Stack.lua, FrameGambit's model): reactions in the player's order, the
-- first match sets each trigger it has (R2 the hand: what you do and what's next; L2 the body:
-- what happens to you), Pass leaves one to the next match, Otherwise: free. A reaction's trigger
-- takes a WoW Helper shape (C:\games\WowHelper\docs\TRIGGERS.md), which may follow a live value
-- (cast progress, the swing, the shot, the GCD, resource, health lost) or a count (combo
-- points). The addon chooses; WoW Helper shapes. The pick goes on the strip's trigger row; the
-- strip's own trigger fields carry a near equivalent for an older helper.
local _, ns = ...
local TS = {}
ns.TriggerStack = TS

local St, K, H = ns.Stack, ns.HelperLink, ns.Haptics
local floor, min, max = math.floor, math.min, math.max
local function Now() return GetTime and GetTime() or 0 end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok or secret(a) or secret(b) then return nil end
    return a, b, c, d
end

TS.CHANNELS = { "R2", "L2" }

---------------------------------------------------------------------------
-- Shapes: WoW Helper's (WowHelperData.triggerShapes, by id), the shipped ones
-- known by heart so a fresh install works (the same ids and words as
-- assets/triggers/triggers.txt). `old`: the strip's own fields for a helper
-- without the trigger row { mode, start, finish, force, grow }.
---------------------------------------------------------------------------
TS.PRESETS = {
    [1] = { key = "resist", label = "Resist", old = { "resist", 3, 0, 8 } },
    [2] = { key = "wall", label = "Wall", old = { "resist", 8, 0, 15 } },
    [3] = { key = "click", label = "Click", old = { "weapon", 4, 8, 7 } },
    [4] = { key = "pulse", label = "Pulse", old = { "vibrate", 0, 5, 3 } },
    [5] = { key = "rising", label = "Rising", old = { "slope", 1, 12, 9 } },
    [6] = { key = "tension", label = "Cast tension", gauge = "strength", old = { "resist", 3, 0, 13, true } },
    [7] = { key = "bowstring", label = "Bowstring", gauge = "strength", old = { "weapon", 4, 8, 7 } },
    [8] = { key = "swing", label = "Swing", gauge = "strength", old = { "weapon", 6, 9, 5 } },
    [9] = { key = "gcd", label = "GCD wall", gauge = "wall", old = { "resist", 6, 0, 10 } },
    [10] = { key = "ready", label = "Ready", old = { "weapon", 9, 11, 4 } },
    [11] = { key = "firm", label = "Firmness", gauge = "strength", old = { "resist", 3, 0, 8 } },
    [12] = { key = "weight", label = "Weight", gauge = "strength", old = { "resist", 2, 0, 9 } },
    [13] = { key = "detents", label = "Detents", count = true, old = { "weapon", 4, 8, 6 } },
    [14] = { key = "gallop", label = "Gallop", old = { "vibrate", 3, 3, 1 } },
    [15] = { key = "drag", label = "Drag", old = { "resist", 0, 0, 2 } },
    [16] = { key = "nibble", label = "Nibble", old = { "vibrate", 5, 3, 6 } },
    [17] = { key = "heart", label = "Heartbeat", gauge = "speed", old = { "vibrate", 0, 5, 0 } },
}
local ID = {}
for id, s in pairs(TS.PRESETS) do ID[s.key] = id end
TS.ID = ID

-- Every shape to pick: WoW Helper's list when it has published one, else the shipped ones
function TS.Shapes()
    local d = type(WowHelperData) == "table" and type(WowHelperData.triggerShapes) == "table" and WowHelperData.triggerShapes
    local out = {}
    for id, s in pairs(TS.PRESETS) do out[id] = s end
    if d then
        for id, s in pairs(d) do
            if type(id) == "number" and type(s) == "table" and type(s.label) == "string" then
                local base = TS.PRESETS[id] or {}
                out[id] = { key = s.key, label = s.label, gauge = s.gauge, count = s.count, own = s.own, old = base.old }
            end
        end
    end
    return out
end
function TS.Shape(id) return id and TS.Shapes()[id] or nil end

-- What a value can follow (each 0-1), and what can be counted
TS.SOURCES = {
    { key = "cast", label = "Cast" },
    { key = "swing", label = "Swing" },
    { key = "shot", label = "Shot timer" },
    { key = "gcd", label = "GCD" },
    { key = "power", label = "Resource" },
    { key = "hurt", label = "Health lost" },
}
TS.COUNTS = { { key = "combo", label = "Combo points" } }
local SOURCE_LABEL = {}
for _, s in ipairs(TS.SOURCES) do SOURCE_LABEL[s.key] = s.label end
for _, s in ipairs(TS.COUNTS) do SOURCE_LABEL[s.key] = s.label end
TS.SOURCE_LABEL = SOURCE_LABEL

---------------------------------------------------------------------------
-- Conditions the triggers add to the stack's (pushed by HelperCues and here)
---------------------------------------------------------------------------
if St then
    St.Condition("autoShot", { label = "Auto shot", category = "player" })
    St.Condition("autoAttack", { label = "Auto attack", category = "player" })
    St.Condition("gcd", { label = "Global cooldown", category = "player" })
    St.Condition("always", { label = "Always", category = "system", test = function() return true end })
end

-- Ready clicks: a chosen spell's cooldown back (a moment, brief). The spells each class
-- watches by default; more join as conditions "ready:<name>".
TS.READY = {
    PALADIN = { "Judgement", "Hammer of Justice" },
    WARRIOR = { "Overpower", "Shield Slam" },
    ROGUE = { "Kick", "Sprint" },
    HUNTER = { "Arcane Shot", "Aimed Shot" },
    MAGE = { "Fire Blast", "Frost Nova" },
    PRIEST = { "Mind Blast" },
    WARLOCK = { "Shadowburn" },
    DRUID = { "Faerie Fire" },
    SHAMAN = { "Earth Shock" },
}
local watched = {}
function TS.Watch(name)
    local key = "ready:" .. name
    if St and not St.Info(key) then
        St.Condition(key, { label = name .. " ready", category = "moment", kind = "moment", duration = 0.35 })
    end
    watched[name] = watched[name] or { cooling = false }
    return key
end

local function Class()
    local _, c = call(UnitClass, "player")
    return c
end
for _, name in ipairs(TS.READY[Class() or ""] or {}) do TS.Watch(name) end

---------------------------------------------------------------------------
-- Recommended stacks: R2 the hand, L2 the body (data; per class, top first)
---------------------------------------------------------------------------
local function R2(id, condition, shape, follows, extra)
    local r = { id = id, condition = condition, on = true, R2 = { shape = ID[shape], follows = follows } }
    for k2, v in pairs(extra or {}) do r[k2] = v end
    return r
end
local function L2(id, condition, shape, follows, extra)
    local r = { id = id, condition = condition, on = true, L2 = { shape = ID[shape], follows = follows } }
    for k2, v in pairs(extra or {}) do r[k2] = v end
    return r
end
local BODY = {
    L2("hurt", "player_health", "weight", "hurt", { operator = "<", threshold = 35 }),
    L2("mounted", "mounted", "gallop"),
    L2("swimming", "swimming", "drag"),
}
local function Ready(list)
    local out = {}
    for _, name in ipairs(list or {}) do
        out[#out + 1] = R2("ready:" .. name, "ready:" .. name, "ready")
    end
    return out
end
local function Join(...)
    local out = {}
    for _, t in ipairs({ ... }) do for _, r in ipairs(t) do out[#out + 1] = r end end
    return out
end
local CASTER = { R2("cast", "cast", "tension", "cast"), R2("shot", "autoShot", "bowstring", "shot"), R2("gcd", "gcd", "gcd", "gcd") }
TS.RECOMMENDED = {
    PALADIN = Join(Ready(TS.READY.PALADIN), { R2("cast", "cast", "tension", "cast"), R2("gcd", "gcd", "gcd", "gcd"),
        R2("swing", "autoAttack", "swing", "swing") }, BODY),
    WARRIOR = Join({ R2("swing", "autoAttack", "swing", "swing"), R2("shot", "autoShot", "bowstring", "shot") },
        { L2("rage", "combat", "firm", "power") }, BODY),
    ROGUE = Join({ R2("combo", "target_hostile", "detents", nil, { R2 = { shape = ID.detents, count = "combo" } }),
        R2("swing", "autoAttack", "swing", "swing") }, { L2("energy", "combat", "firm", "power") }, BODY),
    HUNTER = Join({ R2("shot", "autoShot", "bowstring", "shot"), R2("cast", "cast", "tension", "cast"), R2("gcd", "gcd", "gcd", "gcd") }, BODY),
    DEFAULT = Join(CASTER, BODY),
}

function TS.Recommended(class)
    local list = TS.RECOMMENDED[class or Class() or ""] or TS.RECOMMENDED.DEFAULT
    -- (the ready rows: their conditions exist)
    for _, r in ipairs(list) do
        local name = type(r.condition) == "string" and r.condition:match("^ready:(.+)$")
        if name then TS.Watch(name) end
    end
    return list
end

---------------------------------------------------------------------------
-- The Feel profile's table (Profiles: P.FEEL_TABLES), and the silent move of
-- Setup › Triggers' rules (TriggerRules.lua) into reactions, once
---------------------------------------------------------------------------
local function Store()
    local db = H.DB()
    if type(db.triggerStack) ~= "table" then db.triggerStack = {} end
    return db.triggerStack
end
TS.Store = Store

local OLD_WHEN = { cast = "cast", autoShot = "autoShot", autoAttack = "autoAttack", combat = "combat", lowHp = "lowHp",
    mounted = "mounted", swimming = "swimming", stealth = "stealth", always = "always" }
local OLD_SHAPE = { resist = "resist", wall = "wall", section = "resist", weapon = "click", vibrate = "pulse", slope = "rising" }

-- Old rules -> reactions on top of the class's Recommended ones; each keeps its old bytes
-- (`legacy`: the rule as it was, sent on the strip's own fields, the trigger row empty)
function TS.Migrate()
    local store = Store()
    if type(store.rows) == "table" or store.migrated then return end
    store.migrated = true
    local db = H.DB()
    local old = type(db.link) == "table" and type(db.link.trigRules) == "table" and db.link.trigRules
    if not (old and type(old.list) == "table" and #old.list > 0) then return end
    local T = ns.TriggerRules
    local rows = {}
    for i, r in ipairs(old.list) do
        r = T and T.Clean(r) or r
        local cond = OLD_WHEN[r.when] or "cast"
        local legacy = { effect = r.effect, from = r.from, to = r.to, strength = r.strength, speed = r.speed, grow = r.grow }
        local v = { shape = ID[OLD_SHAPE[r.effect] or "resist"], legacy = legacy, follows = r.grow and "cast" or nil }
        local row = { id = "old" .. i, condition = cond, on = r.on ~= false }
        if r.side == "L2" or r.side == "both" then row.L2 = St.Copy(v) end
        if r.side == "R2" or r.side == "both" then row.R2 = St.Copy(v) end
        rows[#rows + 1] = row
    end
    for _, r in ipairs(TS.Recommended()) do rows[#rows + 1] = St.Copy(r) end
    store.rows, store.nextID = rows, 1
end

---------------------------------------------------------------------------
-- The kind: a channel's value { effect = shape id, value = 0-1 | nil, count = n | nil, legacy }
---------------------------------------------------------------------------
local function Value(row, ch)
    local v = row[ch]
    if type(v) ~= "table" or not v.shape or v.shape == 0 then return nil end   -- (Pass)
    return { effect = v.shape, value = v.follows and St.Value(v.follows) or nil,
        count = v.count and St.Value(v.count) or nil, legacy = v.legacy }
end
TS.Value = Value

local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    if a.effect ~= b.effect or a.count ~= b.count or a.legacy ~= b.legacy then return false end
    local x, y = a.value, b.value
    if (x == nil) ~= (y == nil) then return false end
    return x == nil or math.abs(x - y) < 0.01
end

---------------------------------------------------------------------------
-- Sending: the trigger row (a shape) and the strip's own fields (the old bytes
-- of a moved rule; else the shape's near equivalent for an older helper)
---------------------------------------------------------------------------
local trying   -- { values = { R2 =, L2 = }, until }
local kind

local function OldFields(v)
    local T = ns.TriggerRules
    if v.legacy and T then
        local r = T.Clean(St.Copy(v.legacy))
        r.when, r.side = "cast", "R2"
        return T.Params(r, v.legacy.grow and (v.value or 0) or nil)
    end
    local s = TS.Shape(v.effect)
    local o = s and s.old
    if not o then return "off", 0, 0, 0 end
    local force = o[4]
    if o[5] then force = 2 + floor(max(0, min(1, v.value or 1)) * (force - 2)) end
    return o[1], o[2], o[3], force
end
TS.OldFields = OldFields

-- The kind's own switch (Moments › Triggers › On)
function TS.On() return Store().off ~= true end
function TS.SetOn(on)
    Store().off = (not on) or nil
    if kind then kind:Refresh(true) end
end

-- The link switched (on or off): send the stack's current triggers again
function TS.LinkChanged()
    if kind then kind:Refresh(true) end
end

function TS.Send(result)
    if not (K and K.SetTrigger) then return end
    local on = K.Enabled() and TS.On()
    local pick = {}
    for _, ch in ipairs(TS.CHANNELS) do
        local v = trying and trying.values[ch] or (on and result and result[ch] and result[ch].value) or nil
        if trying and not trying.values[ch] then v = nil end
        if type(v) == "table" and v.effect and v.effect > 0 then
            K.SetTrigger(ch, OldFields(v))
            -- (a moved rule keeps its old bytes: no shape on the row)
            pick[ch == "L2" and "left" or "right"] = v.legacy and { shape = 0 } or { shape = v.effect, value = v.value, count = v.count }
        else
            K.SetTrigger(ch, "off", 0, 0, 0)
        end
    end
    if K.SetTrigRow then K.SetTrigRow((on or trying) and pick or nil) end
end

if St then
    kind = St.Kind("triggers", {
        channels = TS.CHANNELS,
        recommended = TS.Recommended(),
        store = Store,
        value = Value,
        base = function() return { effect = 0 } end,
        same = Same,
        live = true,
        timing = { fadeIn = 0, fadeOut = 0, wait = 0 },
        prepare = function() TS.Migrate() end,
        apply = function(result) TS.Send(result) end,
    })
end
TS.kind = kind

-- Try a reaction: its triggers, whatever holds, for a few seconds (a followed value sweeps 0 -> 1)
function TS.Try(id, seconds)
    local row = kind and kind:Row(id)
    if not row then return false end
    seconds = seconds or 3
    local start = Now()
    local values = {}
    for _, ch in ipairs(TS.CHANNELS) do
        local v = row[ch]
        if type(v) == "table" and v.shape and v.shape > 0 then
            values[ch] = { effect = v.shape, value = v.follows and 0 or nil, count = v.count and 3 or nil, legacy = v.legacy }
        end
    end
    if not next(values) then return false end
    trying = { values = values, id = id, untilT = start + seconds }
    TS.Send(nil)
    local function step()
        if not trying or trying.id ~= id then return end
        local t = Now() - start
        if t >= seconds then
            trying = nil
            kind:Refresh(true)
            return
        end
        for _, v in pairs(values) do if v.value then v.value = min(1, t / (seconds * 0.8)) end end
        TS.Send(nil)
        if C_Timer and C_Timer.After then C_Timer.After(0.1, step) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.1, step) end
    return true
end
function TS.Trying() return trying and trying.id or nil end

---------------------------------------------------------------------------
-- Live values and states, pushed from the game (HelperCues calls Update ~10 times a second)
---------------------------------------------------------------------------
local function Round(v) return v and floor(max(0, min(1, v)) * 100 + 0.5) / 100 or nil end

local GCD_SPELL = 61304
local function Cooldown(spell)
    local api = C_Spell and C_Spell.GetSpellCooldown
    if api then
        local info = call(api, spell)
        if type(info) == "table" then return tonumber(info.startTime), tonumber(info.duration) end
    end
    local s, d = call(GetSpellCooldown, spell)
    return tonumber(s), tonumber(d)
end
TS.Cooldown = Cooldown

local function Gcd()
    local s, d = Cooldown(GCD_SPELL)
    if not (s and d) or d <= 0 or d > 2 then return nil end
    local p = (Now() - s) / d
    if p >= 1 then return nil end
    return max(0, p)
end

-- Ready clicks: a watched spell's cooldown (beyond the GCD) back -> its moment
local function CheckReady()
    for name, w in pairs(watched) do
        local s, d = Cooldown(name)
        local cooling = s and d and d > 1.6 and s > 0 and Now() < s + d
        if w.cooling and not cooling then St.Fire("ready:" .. name) end
        w.cooling = cooling and true or false
    end
end
TS.CheckReady = CheckReady

local function Pct(cur, top)
    cur, top = tonumber(cur), tonumber(top)
    if not (cur and top and top > 0) then return nil end
    return max(0, min(1, cur / top))
end

-- state = { cast, progress, autoShot, autoAttack, lowHp, swingAt, shotAt }
function TS.Update(state)
    if not (St and kind) then return end
    state = state or {}
    St.Set("cast", state.cast)
    St.Set("autoShot", state.autoShot)
    St.Set("autoAttack", state.autoAttack)
    St.Set("lowHp", state.lowHp)
    local g = Gcd()
    St.Set("gcd", g ~= nil)
    if not K.Enabled() then return kind:Refresh() end
    St.SetValue("cast", state.cast and Round(state.progress or 0) or nil)
    St.SetValue("gcd", Round(g))
    local speed = tonumber((call(UnitAttackSpeed, "player")))
    St.SetValue("swing", state.autoAttack and state.swingAt and speed and speed > 0 and Round((Now() - state.swingAt) / speed) or nil)
    local rspeed = tonumber((call(UnitRangedDamage, "player")))
    St.SetValue("shot", state.autoShot and state.shotAt and rspeed and rspeed > 0 and Round((Now() - state.shotAt) / rspeed) or nil)
    St.SetValue("power", Round(Pct(call(UnitPower, "player"), call(UnitPowerMax, "player"))))
    local hp = Pct(call(UnitHealth, "player"), call(UnitHealthMax, "player"))
    St.SetValue("hurt", hp and Round(1 - hp) or nil)
    local combo = tonumber((call(GetComboPoints, "player", "target")))
    St.SetValue("combo", combo)
    CheckReady()
    kind:Refresh()
end

-- A channel's words: "Cast tension · follows Cast", "Detents · Combo points", "Pass"
function TS.Words(v)
    if type(v) ~= "table" or not v.shape or v.shape == 0 then return "Pass" end
    local s = TS.Shape(v.shape)
    local name = s and s.label or ("Shape " .. v.shape)
    if v.legacy then name = name .. " (yours)" end
    if v.follows then name = name .. " · follows " .. (SOURCE_LABEL[v.follows] or v.follows) end
    if v.count then name = name .. " · " .. (SOURCE_LABEL[v.count] or v.count) end
    return name
end

-- What a shape follows unless chosen (its own words: Cast tension follows the cast)
TS.FOLLOWS = { tension = "cast", bowstring = "shot", swing = "swing", gcd = "gcd", firm = "power", weight = "hurt", heart = "hurt" }
function TS.DefaultFollows(shape)
    local s = TS.Shape(shape)
    return s and s.gauge and (TS.FOLLOWS[s.key] or "cast") or nil
end

-- Set a reaction's trigger: a shape (0: Pass), what it follows, what it counts
function TS.SetChannel(id, ch, shape, follows, count)
    local row = kind and kind:Row(id)
    if not row then return end
    if not shape or shape == 0 then
        row[ch] = nil
    else
        local s = TS.Shape(shape)
        row[ch] = { shape = shape, follows = s and s.gauge and (follows or TS.DefaultFollows(shape)) or nil,
            count = s and s.count and (count or "combo") or nil }
    end
    kind:Refresh(true)
end
