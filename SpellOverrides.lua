-- Your spells: a spell's own choice over the rules (Moments › Your spells).
-- Keyed by the spell's name (every rank shares it). Only what differs is
-- saved: { on = false, feel = key, set = key, volume = 0-1 } in
-- GamepadCompanionHapticsDB.spells. The rules (Rumble.lua, V.SpellPlan)
-- read Get in the play path: on false plays nothing, feel / set replace the
-- rule's, volume scales it (once, over the moment's own).
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

-- An instant's or a quiet spell's feel (on again with it)
function O.SetFeel(name, key)
    local o = Own(name)
    o.feel, o.on = key, nil
    Tidy(name)
end

-- A cast-time spell's cast set (on again with it)
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
