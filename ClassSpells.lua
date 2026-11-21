-- A class's own spells, for its class file (Priest.lua, Warlock.lua): its patterns into Rumble,
-- its spells' entries (Rumble's V.CLASS_SPELLS, asked through V.MageOf), and its DoTs' ticks.
-- Loaded right after Rumble.lua: the patterns must be in before the Lab reads them.
local _, ns = ...
local CS = {}
ns.ClassSpells = CS
local V = ns.Rumble

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
CS.SpellName = SpellName
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok or secret(a) then return nil end
    return a, b, c
end
CS.call = call

-- One pulse: t and length in seconds (50 ms or more), strength 0-1, side -1 left .. 1 right
function CS.Pu(t, len, s, side) return { t, len, s, side or 0 } end

function CS.PlayerClass()
    local _, class = call(UnitClass, "player")
    return class
end

---------------------------------------------------------------------------
-- A class's spells into Rumble's V.CLASS_SPELLS (every rank by its name there, for that class's
-- player only; "Engrave ..." an enchanting's shimmer). rules: { entry, { first rank IDs... } };
-- any = true: anyone's (a Healthstone eaten by a priest): by its IDs, in V.MAGE's table.
-- An entry is V.MAGE's: move + when ("cast" / "hit"), impact (a cast's feel at its wound),
-- burst (at its release), tick + ticks (a channel's, per tick), set (a cast's loop: its own,
-- before its family's).
---------------------------------------------------------------------------
function CS.Register(class, rules)
    local own = V.CLASS_SPELLS[class] or {}
    V.CLASS_SPELLS[class] = own
    for _, r in ipairs(rules) do
        local entry = r[1]
        if entry.set then entry.classSet = true end
        for _, id in ipairs(r[2]) do
            if r.any then
                entry.byId = true
                V.MAGE[id] = entry
            else
                own[id] = entry
            end
        end
    end
    -- (a spell's entry for you: your class's, or anyone's)
    return function(spellID, name) return V.MageOf(spellID, name) end
end

---------------------------------------------------------------------------
-- Damage over time: each tick a faint feel (the Lab's DoT ticks, off by default). WoW Forever
-- gives addons no combat log: a tick is a wound on your target no swing or spell of yours
-- claimed, of the school of a DoT of yours on it, while you aren't channelling.
---------------------------------------------------------------------------
CS.DOTS = {}            -- class -> { spellID = school mask }
CS.TICK_GAP = 0.3
function CS.AddDots(class, list)
    CS.DOTS[class] = CS.DOTS[class] or {}
    for id, school in pairs(list) do CS.DOTS[class][id] = school end
end

local dotNames, dotClass
local function DotNames()
    local class = CS.PlayerClass()
    if dotNames and dotClass == class then return dotNames end
    local names, full = {}, true
    for id, school in pairs(CS.DOTS[class] or {}) do
        local n = SpellName(id)
        if n and not secret(n) then names[n] = school else full = false end
    end
    -- (a name not loaded yet: asked again next time)
    if full then dotNames, dotClass = names, class end
    return names
end

-- The schools of your DoTs on the target now (a mask; 0: none)
local onTarget = 0
function CS.TargetDots()
    local names = DotNames()
    if not next(names) then onTarget = 0; return 0 end
    local mask = 0
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    for i = 1, 40 do
        local name
        if get then
            local ok, a = pcall(get, "target", i, "HARMFUL|PLAYER")
            if not ok or type(a) ~= "table" then break end
            name = a.name
        else
            break
        end
        local school = not secret(name) and name and names[name]
        if school and math.floor(mask / school) % 2 == 0 then mask = mask + school end
    end
    onTarget = mask
    return mask
end

local lastTick = -math.huge
-- A wound on your target (UNIT_COMBAT): a tick of yours? Then DoT ticks plays
function CS.TargetWound(action, school)
    if secret(action) or action ~= "WOUND" or secret(school) or type(school) ~= "number" or onTarget == 0 then return false end
    -- (a channel's ticks are its own; a swing's or a spell's claimed: Rumble's)
    if call(UnitChannelInfo, "player") then return false end
    if V and V.ClaimsResult and V.ClaimsResult(action, school) then return false end
    local hit = false
    for _, b in ipairs({ 2, 4, 8, 16, 32, 64 }) do
        if math.floor(school / b) % 2 == 1 and math.floor(onTarget / b) % 2 == 1 then hit = true end
    end
    if not hit or Now() - lastTick < CS.TICK_GAP then return false end
    lastTick = Now()
    local L = ns.HapticsLab
    if L and L.Fire and L.EVENT and L.EVENT.dotTick then L.Fire("dotTick") end
    return true
end

local frame = CreateFrame("Frame")
CS.frame = frame
for _, e in ipairs({ "UNIT_AURA", "UNIT_COMBAT", "PLAYER_TARGET_CHANGED" }) do
    if e == "PLAYER_TARGET_CHANGED" or not pcall(frame.RegisterUnitEvent, frame, e, "target") then pcall(frame.RegisterEvent, frame, e) end
end
frame:SetScript("OnEvent", function(_, event, unit, action, _, _, school)
    if event == "PLAYER_TARGET_CHANGED" then return CS.TargetDots() end
    if unit ~= "target" then return end
    if event == "UNIT_AURA" then return CS.TargetDots() end
    if event == "UNIT_COMBAT" then return CS.TargetWound(action, school) end
end)
