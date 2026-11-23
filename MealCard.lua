-- The meal card: a slip of the catch card's paper (FishingToast.lua) above the
-- player frame when a meal's buff lands: Well Fed after ten seconds of eating,
-- or a campfire's buff after a minute by the fire. The buff's name, its icon,
-- what it gives (its tooltip's line, short) and for how long. Shows a few
-- seconds, then fades. No sound, no mouse.
-- The buffs are read on UNIT_AURA (player), out of combat only (a meal is never
-- in a fight; in one the auras may be secret): a buff not on the player at the
-- last read is new. It counts as a meal when it is one we know (M.MEALS: Well
-- Fed and the foods that name their own), or when the player was eating or
-- drinking as it landed (the Food / Drink auras, Rumble's REST_SPELLS) and it is
-- their own; as the fire's when the campfire timer aura (Forever's Welcoming
-- Campfire) was on at this read or the one before. A refresh of a buff already
-- on is not new. Pure: tests/MealCard.lua
local _, ns = ...
local Sh = ns.Shared
local M = {}
ns.MealCard = M

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

---------------------------------------------------------------------------
-- What counts (pure)
---------------------------------------------------------------------------
-- Eating and drinking: the auras of sitting with food or a drink, by name (their
-- ids: Rumble's REST_SPELLS, resolved to names at the first read)
M.REST_NAMES = { ["Food"] = true, ["Drink"] = true, ["Refreshment"] = true, ["Food & Drink"] = true, ["Food and Drink"] = true }
-- The fire's timer while you sit by one (Forever's server aura, FrameGambit's find)
M.FIRE_TIMER = { ids = { [1229739] = true }, names = { ["Welcoming Campfire"] = true } }
-- The buffs a meal gives (true), or a fire's ("fire"). Classic-era: most are Well Fed; a few
-- foods name their own; a Basic Campfire's is Cozy Fire
M.MEALS = {
    names = { ["Well Fed"] = true, ["Blessed Sunfruit"] = true, ["Blessed Sunfruit Juice"] = true, ["Grilled Squid"] = true,
        ["Nightfin Soup"] = true, ["Runn Tum Tuber Surprise"] = true, ["Hot Smoked Bass"] = true, ["Cozy Fire"] = "fire" },
    ids = { [19705] = true, [19706] = true, [19708] = true, [19709] = true, [19710] = true, [19711] = true, [24799] = true,
        [24800] = true, [24870] = true, [25661] = true, [25694] = true, [25941] = true, [18125] = true, [18141] = true,
        [18192] = true, [18194] = true, [18222] = true, [22730] = true,
        [7353] = "fire" },   -- Cozy Fire: a Basic Campfire's
}
M.MIN_LAST = 60      -- s: a meal's buff lasts at least a minute (a swallow's 30 s Food does not count)
M.RECENT = 3         -- s: eating or the fire seen this long ago still counts as now
M.HOLD = 5           -- s the card stays

local function Named(set, aura) return (aura.name ~= nil and set.names[aura.name]) or (aura.spellId ~= nil and set.ids[aura.spellId]) or nil end
function M.IsRest(aura) return aura.name ~= nil and M.REST_NAMES[aura.name] == true end
function M.IsFireTimer(aura) return Named(M.FIRE_TIMER, aura) ~= nil end

-- Was it seen now, at the read before, or within M.RECENT s? state.x = { now, before, at }
local function Recent(x, now)
    if not x then return false end
    return x.now == true or x.before == true or (type(x.at) == "number" and now - x.at <= M.RECENT)
end

-- A new buff's kind: "meal", "fire" or nil (not a meal). state: { eating = {...}, fire = {...}, now }
function M.Kind(aura, state)
    if M.IsRest(aura) or M.IsFireTimer(aura) then return nil end
    local known = Named(M.MEALS, aura)
    if known == "fire" then return "fire" end
    if known then return "meal" end
    if (tonumber(aura.duration) or 0) < M.MIN_LAST then return nil end
    -- (theirs: from an item, or a fire; a party member's blessing while you eat is not a meal)
    local own = aura.sourceUnit == nil or aura.sourceUnit == "player"
    if not own then return nil end
    local now = state.now or 0
    if aura.isFromPlayerOrPlayerPet ~= false and Recent(state.eating, now) then return "meal" end
    if Recent(state.fire, now) then return "fire" end
    return nil
end

-- What it gives, from its tooltip's line, short: "Increases Stamina and Spirit by 4 for 15 min."
-- -> "+4 Stamina and Spirit"; "Restores 8 mana per 5 sec." -> "+8 mana per 5 sec"
function M.Gives(desc)
    if type(desc) ~= "string" then return nil end
    desc = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " "):gsub("\n", " ")
    desc = desc:match("^%s*(.-)%s*$")
    local first = desc:match("^(.-)%.%s") or desc:match("^(.-)%.$") or desc
    first = first:gsub("%s+for%s+%d+%s*%a+%.?$", "")   -- (" for 15 min")
    first = first:gsub("%.$", "")
    local what, n = first:match("^[Ii]ncreases%s+(.-)%s+by%s+(%d+%%?)$")
    if what and n then return "+" .. n .. " " .. what:gsub("^your%s+", "") end
    local rest = first:match("^[Rr]estores%s+(.+)$") or first:match("^[Rr]egenerates%s+(.+)$")
    if rest then return "+" .. rest end
    if first == "" then return nil end
    return first
end

-- For how long: "For 15 minutes", "For half an hour", "For an hour", "For 2 hours"
function M.Lasts(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return nil end
    local m = math.floor(seconds / 60 + 0.5)
    if m < 1 then return "For a moment" end
    if m % 60 == 0 then
        local h = m / 60
        return h == 1 and "For an hour" or ("For " .. h .. " hours")
    end
    if m == 30 then return "For half an hour" end
    return "For " .. m .. (m == 1 and " minute" or " minutes")
end

-- The card's words: { kicker, title, line1, line2, hold }
function M.Words(kind, name, gives, duration)
    local w = { kicker = kind == "fire" and "BY THE FIRE" or "A GOOD MEAL", title = tostring(name or ""), hold = M.HOLD }
    local lasts = M.Lasts(duration)
    if gives then w.line1, w.line2 = gives, lasts else w.line1 = lasts end
    return w
end

function M.Enabled() return Sh.CharDB().mealCard ~= false end
function M.SetEnabled(on) Sh.CharDB().mealCard = on and true or false end

---------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------
if not CreateFrame then return end

local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Now() return Call(GetTime) or 0 end

-- Rumble's eating and drinking spells, by name (read once they resolve)
local restNamed = false
local function RestNames()
    if restNamed then return end
    local R = ns.Rumble
    local get = C_Spell and C_Spell.GetSpellName
    if not (R and R.REST_SPELLS and get) then restNamed = true; return end
    local all = true
    for _, ids in pairs(R.REST_SPELLS) do
        for _, id in ipairs(ids) do
            local name = Call(get, id)
            if type(name) == "string" and not secret(name) and name ~= "" then M.REST_NAMES[name] = true else all = false end
        end
    end
    restNamed = all
end

-- The player's buffs, each { name, spellId, icon, duration, sourceUnit, isFromPlayerOrPlayerPet,
-- auraInstanceID, index, key }; nil when they can't be read (secret, in combat)
local function Buffs()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and Call(C_Secrets.ShouldAurasBeSecret) then return nil end
    local list = {}
    local get = C_UnitAuras and C_UnitAuras.GetBuffDataByIndex
    for i = 1, 40 do
        local a
        if get then
            local ok, v = pcall(get, "player", i)
            if not ok then return nil end
            if v == nil then break end
            a = { name = v.name, spellId = v.spellId, icon = v.icon, duration = v.duration, sourceUnit = v.sourceUnit,
                isFromPlayerOrPlayerPet = v.isFromPlayerOrPlayerPet, auraInstanceID = v.auraInstanceID }
        elseif UnitBuff then
            local ok, name, icon, _, _, duration, _, source, _, _, spellId, _, _, mine = pcall(UnitBuff, "player", i)
            if not ok then return nil end
            if name == nil then break end
            a = { name = name, spellId = spellId, icon = icon, duration = duration, sourceUnit = source, isFromPlayerOrPlayerPet = mine }
        else
            break
        end
        if secret(a.name) or secret(a.spellId) or secret(a.duration) or secret(a.sourceUnit) then return nil end
        a.index = i
        a.key = a.auraInstanceID or a.spellId or a.name
        list[#list + 1] = a
    end
    return list
end

-- What a buff gives: its tooltip's first line after the name (never the time left), else
-- the spell's description
local function Describe(a)
    local tip = C_TooltipInfo
    local info
    if tip and tip.GetUnitBuffByAuraInstanceID and a.auraInstanceID then info = Call(tip.GetUnitBuffByAuraInstanceID, "player", a.auraInstanceID) end
    if not info and tip and tip.GetUnitAura and a.index then info = Call(tip.GetUnitAura, "player", a.index, "HELPFUL") end
    if type(info) == "table" and type(info.lines) == "table" then
        for i, line in ipairs(info.lines) do
            local text = type(line) == "table" and line.leftText
            if i > 1 and type(text) == "string" and not secret(text) and text ~= "" and not text:lower():find("remaining", 1, true) then
                return text
            end
        end
    end
    local desc = C_Spell and C_Spell.GetSpellDescription and a.spellId and Call(C_Spell.GetSpellDescription, a.spellId)
    if type(desc) == "string" and not secret(desc) and desc ~= "" then return desc end
    return nil
end

-- The card ---------------------------------------------------------------------------------
local W, H, PAD = 280, 94, 14
local card, motion

-- The frame's top above its art: the modern player frame has empty room over the portrait
M.DEFAULT_GAP = 12
local function Gap(frame)
    local art = frame.PlayerFrameContainer and frame.PlayerFrameContainer.PlayerPortrait or frame.portrait
    local ft, at = Call(frame.GetTop, frame), art and Call(art.GetTop, art)
    if type(ft) ~= "number" or type(at) ~= "number" or secret(ft) or secret(at) then return M.DEFAULT_GAP end
    local fs, cs = Call(frame.GetEffectiveScale, frame) or 1, Call(card.GetEffectiveScale, card) or 1
    local gap = (ft - at) * fs / cs
    if gap < 0 or gap > 60 then return M.DEFAULT_GAP end
    return gap
end

-- Composed above the player frame, centred, its foot 8 px over the portrait's top, wherever
-- Edit Mode put the frame; y: the rise
local function Anchor(y)
    local frame = _G.PlayerFrame
    card:ClearAllPoints()
    if frame and type(frame.GetTop) == "function" then
        card:SetPoint("BOTTOM", frame, "TOP", 0, 8 - Gap(frame) + (y or 0))
    else
        card:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300 + (y or 0))
    end
end

local function Build()
    local T = ns.FishingToast
    if not (T and T.Slip and T.Motion) then return nil end
    local f = T.Slip("GamepadCompanionMealCard", W, H, PAD)
    f:SetFrameStrata("MEDIUM")
    motion = T.Motion(f, Anchor)
    f:SetScript("OnUpdate", function(_, elapsed) motion.Step(elapsed) end)
    return f
end

function M.Phase() return motion and motion.Phase() end
function M.Step(elapsed) return motion and motion.Step(elapsed) end

-- Shows a meal's buff (a: a Buffs() entry) as kind's card; the words shown, or nil
function M.Show(kind, a)
    if not M.Enabled() then return nil end
    if not card then card = Build() end
    if not card then return nil end
    local w = M.Words(kind, a.name, M.Gives(Describe(a)), a.duration)
    ns.FishingToast.FillSlip(card, w, a.icon or "Interface\\Icons\\Spell_Misc_Food", ns.FishingToast.RINGS[1])
    motion.Show(w.hold)
    M.shown = w
    return w
end

function M.Hide() if motion then motion.Hide() end end

-- The reads ----------------------------------------------------------------------------------
local seen, primed = {}, false     -- the buffs on the player at the last read (by key)
local eating = { now = false, before = false, at = -math.huge }
local fire = { now = false, before = false, at = -math.huge }

-- Reads the buffs; a new meal's shows. nil: hidden, or nothing new
function M.Scan(now)
    local list = Buffs()
    if not list then return nil end
    RestNames()
    now = now or Now()
    local here, fresh = {}, {}
    eating.before, eating.now = eating.now, false
    fire.before, fire.now = fire.now, false
    for _, a in ipairs(list) do
        here[a.key] = true
        if M.IsRest(a) then eating.now, eating.at = true, now end
        if M.IsFireTimer(a) then fire.now, fire.at = true, now end
        if primed and not seen[a.key] then fresh[#fresh + 1] = a end
    end
    seen, primed = here, true
    for _, a in ipairs(fresh) do
        local kind = M.Kind(a, { eating = eating, fire = fire, now = now })
        if kind then return M.Show(kind, a) end
    end
    return nil
end

-- A fresh start (login, a loading screen): the buffs on are not new
function M.Reset()
    seen, primed = {}, false
    eating.now, eating.before, eating.at = false, false, -math.huge
    fire.now, fire.before, fire.at = false, false, -math.huge
end

local events = CreateFrame("Frame")
pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then M.Reset() elseif unit ~= "player" then return end
    if InCombat() then return end
    M.Scan()
end)

-- Edit Mode: a sample card rests over the player frame while it's moved
function M.EditMode(on)
    if on then
        if not card then card = Build() end
        if not card then return end
        motion.Hold(true)
        M.shown = M.Words("meal", "Well Fed", "+4 Stamina and Spirit", 900)
        ns.FishingToast.FillSlip(card, M.shown, "Interface\\Icons\\Spell_Misc_Food", ns.FishingToast.RINGS[1])
        motion.Show(M.shown.hold)
    elseif motion then
        motion.Hold(false)
        M.Hide()
    end
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", function() M.EditMode(true) end, M)
    EventRegistry:RegisterCallback("EditMode.Exit", function() M.EditMode(false) end, M)
end
