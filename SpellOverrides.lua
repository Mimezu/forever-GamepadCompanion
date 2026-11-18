-- Your spells: a spell's own choice over the rules (Moments › Your spells).
-- Keyed by the spell's name (every rank shares it). Only what differs is
-- saved: { on = false, feel = key, set = key, volume = 0-1, light = { on,
-- light, color, strength }, sound = id | false, soundVolume = 0-1 } in
-- GamepadCompanionHapticsDB.spells. The rules (Rumble.lua, V.SpellPlan)
-- read Get in the play path: on false plays nothing, feel / set replace the
-- rule's, volume scales it (once, over the moment's own).
--
-- A spell is a moment of its own under the moment it plays in: its key
-- "spell:<moment>:<name>" ("spell:instant:Frost Nova", "spell:release:Flash
-- Heal"). Lights, sounds and volumes take that key like any moment's
-- (ns.SubMoment): its light and sound are the parent moment's until it has
-- its own (light = off, sound = false: none for this spell).
local _, ns = ...
local H = ns.Haptics
local O = {}
ns.SpellOverrides = O

local function DB()
    local db = H.DB()
    if type(db.spells) ~= "table" then db.spells = {} end
    return db.spells
end
O.DB = DB

-- nil when the spell follows the rules
function O.Get(name)
    if type(name) ~= "string" then return nil end
    return DB()[name]
end

local function Tidy(name)
    local o = DB()[name]
    if o and next(o) == nil then DB()[name] = nil end
end

local function Own(name)
    local db = DB()
    if type(db[name]) ~= "table" then db[name] = {} end
    return db[name]
end

-- Off (on = false), or on again (the field cleared)
function O.SetOn(name, on)
    if on == false then Own(name).on = false else Own(name).on = nil end
    Tidy(name)
end

-- An instant's or a quiet spell's feel (on again with it; nil: the rule's)
function O.SetFeel(name, key)
    local o = Own(name)
    o.feel, o.on = key, nil
    Tidy(name)
end

-- A cast-time spell's cast set (on again with it; nil: the rule's; any feel
-- as a set: "feel:<pattern>")
function O.SetSet(name, key)
    local o = Own(name)
    o.set, o.on = key, nil
    Tidy(name)
end

function O.SetVolume(name, v)
    v = math.max(0, math.min(1, tonumber(v) or 1))
    Own(name).volume = v < 1 and v or nil
    Tidy(name)
end

function O.Volume(name)
    local o = O.Get(name)
    return o and o.volume or 1
end

-- Default: back to the rules
function O.Clear(name) DB()[name] = nil end

-- Default for one kind only (a row of the Feel, Light or Sound view)
O.KIND_FIELDS = { feel = { "on", "feel", "set", "volume" }, light = { "light" }, sound = { "sound", "soundVolume" } }
function O.ClearKind(name, kind)
    local o = DB()[name]
    if not o then return end
    for _, f in ipairs(O.KIND_FIELDS[kind] or {}) do o[f] = nil end
    Tidy(name)
end
function O.IsDefault(name, kind)
    local o = O.Get(name)
    if not o then return true end
    for _, f in ipairs(O.KIND_FIELDS[kind] or {}) do if o[f] ~= nil then return false end end
    return true
end

-- One field of a spell's own (light, sound, soundVolume), nil: the parent's
function O.Field(name, field)
    local o = O.Get(name)
    if o == nil then return nil end
    return o[field]
end
function O.SetField(name, field, v)
    if type(name) ~= "string" then return end
    if v == nil then
        local o = DB()[name]
        if o then o[field] = nil end
        Tidy(name)
    else
        Own(name)[field] = v
    end
end

-- A spell's moment key, and back
function O.Key(parent, name) return "spell:" .. parent .. ":" .. name end
function O.Parse(key)
    if type(key) ~= "string" then return nil end
    return key:match("^spell:(%w+):(.+)$")
end

-- The key a parent moment plays under for a spell: its own when it has its
-- own `field` (light, sound), else the parent's
function O.MomentFor(parent, name, field)
    if type(name) ~= "string" or O.Field(name, field) == nil then return parent end
    return O.Key(parent, name)
end

-- A spell's name (nil when secret)
function O.NameOf(id)
    if id == nil or (issecretvalue and issecretvalue(id)) then return nil end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if name == nil and GetSpellInfo then name = GetSpellInfo(id) end
    if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return nil end
    return name
end

-- The key `parent` plays under now for `field`: the spell playing it now
-- (Rumble's V.spellNow, set while a spell's moment fires), or `name`
function O.Now(parent, field, name)
    if not name then
        local now = ns.Rumble and ns.Rumble.spellNow
        if now and now.parent == parent then name = now.name end
    end
    return O.MomentFor(parent, name, field)
end

-- The one door for every kind (Lights, HelperCues, Volume): parent, name, O
function ns.SubMoment(key)
    local parent, name = O.Parse(key)
    if parent then return parent, name, O end
end
