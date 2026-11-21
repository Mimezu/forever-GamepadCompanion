-- Class passes in files of their own (Warrior.lua, Rogue.lua): each registers here, before
-- Rumble.lua loads, what it adds: its patterns, its cast sets, a gathering of its own, and the
-- rule of each of its spells. Rumble asks this file (V.SpellRule, CastReleased, Names): one
-- small hook per place, whatever the number of classes.
--
-- A rule row: { move, when, why, ids, opts } (by the first rank's ID: every rank shares its
-- name). move nil: quiet by design (why says what plays instead). opts: ranged (its blow comes
-- from afar), volume (0-1), magic (only a magic wound is its), avoid (no blow of its own: its
-- window takes only a dodge, parry, miss), and a class's own (a rogue's finisher).
local _, ns = ...
local CF = { list = {} }
ns.ClassFeels = CF

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
CF.secret, CF.Now, CF.SpellName = secret, Now, SpellName

-- The player's class token ("WARRIOR"), nil when hidden
function CF.Class()
    if not UnitClass then return nil end
    local _, class = UnitClass("player")
    if secret(class) then return nil end
    return class
end

-- m: { class, PATTERNS, CAST_ACTIONS, GATHER = { action = { ids } }, GATHER_FINISH = { action = key },
--      RULES = { rows }, Rule(spellID, name, rule) (may change a rule's move or volume as it is used),
--      Released(action, spellID) (true: the cast's end is handled there) }
function CF.Register(m)
    CF.list[#CF.list + 1] = m
    return m
end

-- (Rumble at load: everything the classes add)
function CF.Patterns()
    local out = {}
    for _, m in ipairs(CF.list) do for _, p in ipairs(m.PATTERNS or {}) do out[#out + 1] = p end end
    return out
end
function CF.CastActions()
    local out = {}
    for _, m in ipairs(CF.list) do for _, a in ipairs(m.CAST_ACTIONS or {}) do out[#out + 1] = a end end
    return out
end
function CF.GatherFinish()
    local out = {}
    for _, m in ipairs(CF.list) do for k, v in pairs(m.GATHER_FINISH or {}) do out[k] = v end end
    return out
end
-- (a gathering of a class's own, by name: Pick Lock is lockpicking, not any Opening)
function CF.GatherNames()
    local out = {}
    for _, m in ipairs(CF.list) do
        for action, ids in pairs(m.GATHER or {}) do
            for _, id in ipairs(ids) do
                local n = SpellName(id)
                if n and not secret(n) then out[n] = action end
            end
        end
    end
    return out
end

-- Each class's rules by name, built once its names are loaded
local function Build(m)
    if m.byName and not (m.rebuildAt and Now() >= m.rebuildAt) then return end
    m.byName, m.rebuildAt = {}, nil
    for _, r in ipairs(m.RULES or {}) do
        local o = r[5] or {}
        for _, id in ipairs(r[4]) do
            local n = SpellName(id)
            if n and not secret(n) then
                local e = { move = r[1], when = r[2], why = r[3], first = r[4][1] }
                for k, v in pairs(o) do e[k] = v end
                m.byName[n] = e
            else
                -- (a name not loaded yet at login: built again later)
                m.rebuildAt = Now() + 10
            end
        end
    end
end
function CF.Forget() for _, m in ipairs(CF.list) do m.byName = nil end end

local function Mine(m)
    return m.class == nil or CF.Class() == m.class
end

-- A spell's own rule (nil: no class here knows it): { move, when, why, ranged, volume, magic }.
-- A copy: a class may set its move or volume for this use (a finisher by the points spent)
function CF.Rule(spellID, name)
    if type(name) ~= "string" or secret(name) then return nil end
    for _, m in ipairs(CF.list) do
        if Mine(m) then
            Build(m)
            local base = m.byName[name]
            if base then
                local r = {}
                for k, v in pairs(base) do r[k] = v end
                if m.Rule then m.Rule(spellID, name, r) end
                return r
            end
        end
    end
    return nil
end

-- A cast's entry, as a mage's V.MAGE (Rumble's cast branch): a rune engraved is Enchanting's
-- shimmer (a class with ENGRAVE; English names, as the mage's)
CF.ENGRAVE = { set = "enchanting" }
function CF.Cast(_, name)
    if type(name) ~= "string" or secret(name) or not name:find("^Engrave ") then return nil end
    for _, m in ipairs(CF.list) do
        if m.ENGRAVE and Mine(m) then return CF.ENGRAVE end
    end
    return nil
end

-- A class's cast done (Rumble's CastReleased): true when handled there
function CF.Released(action, spellID)
    for _, m in ipairs(CF.list) do
        if m.Released and Mine(m) and m.Released(action, spellID) then return true end
    end
    return false
end

-- (shared by the classes: a pattern of a class's own, played as a spell's moment, its light and
-- sound with it; gain 0-1)
function CF.Play(name, move, gain)
    local V = ns.Rumble
    if not (V and V.FireAs and move) then return end
    V.instantMove = move
    V.fireGain = gain and gain < 1 and gain or nil
    V.FireAs(name, "instant")
    V.fireGain = nil
end

-- (and a frame for a class's own events: Listen(event, unit...))
function CF.Frame(handlers)
    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
        local h = handlers[event]
        if h then h(...) end
    end)
    local function Listen(event, ...)
        if select("#", ...) > 0 and pcall(frame.RegisterUnitEvent, frame, event, ...) then return end
        pcall(frame.RegisterEvent, frame, event)
    end
    return frame, Listen
end
