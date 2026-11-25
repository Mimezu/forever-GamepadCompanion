-- The meal card: a slip of the catch card's paper (FishingToast.lua) above the
-- player frame when a meal's buff lands: Well Fed after ten seconds of eating,
-- or a campfire's buff after a minute by the fire. The buff's name, its icon,
-- what it gives (its tooltip's line, short) and for how long. Shows a few
-- seconds, then fades: a short toast, never a lasting thing. No sound, no mouse. The wait
-- before it (a buff food eaten, the fire's minute) is on the passage at the bottom left.
-- The buffs are read on UNIT_AURA (player), out of combat only (a meal is never
-- in a fight; in one the auras may be secret): a buff not on the player at the
-- last read, landed in the last M.FRESH s, is new. It counts as a meal when it is one we know (M.MEALS: Well
-- Fed and the foods that name their own), or when the player was eating or
-- drinking as it landed (the Food / Drink auras, Rumble's REST_SPELLS) and it is
-- their own; as the fire's when the campfire timer aura (Forever's Welcoming
-- Campfire) was on at this read or the one before. A refresh of a buff already
-- on is not new. The waits on the passage: a buff food's ten seconds (known by the item used or
-- the spell cast: MealFoods.lua), the fire's minute (Welcoming Campfire, each minute sat), the
-- sleeping bag's minute per Well-Rested stack. Each one found is written to
-- GamepadCompanionTraceDB.meal. Pure: tests/MealCard.lua
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
        ["Nightfin Soup"] = true, ["Runn Tum Tuber Surprise"] = true, ["Hot Smoked Bass"] = true, ["Cozy Fire"] = "fire",
        ["Camp Benefits"] = "fire" },   -- (Forever's, after a sit by a camp's fire, 2026-11-22)
    ids = { [19705] = true, [19706] = true, [19708] = true, [19709] = true, [19710] = true, [19711] = true, [24799] = true,
        [24800] = true, [24870] = true, [25661] = true, [25694] = true, [25941] = true, [18125] = true, [18141] = true,
        [18192] = true, [18194] = true, [18222] = true, [22730] = true,
        [7353] = "fire",     -- Cozy Fire: a Basic Campfire's
        [1229741] = "fire" },   -- Camp Benefits (Forever's, Wowhead Forever 2026-11-25)
}
-- The sleeping bag (Cozy Sleeping Bag, item 211527; Wowhead Forever 2026-11-25): Unroll Bag
-- (429961) lays it out; lying in it, a hidden tracking aura (429960) gives a Well-Rested stack
-- (429959, +1% XP, 2 h) each full minute, three at most
M.BAG = { unroll = { [429961] = true }, track = { [429960] = true }, rested = { [429959] = true },
    restedNames = { ["Well-Rested"] = true }, tick = 60, stacks = 3, life = 20 * 60,
    icon = "Interface\\Icons\\INV_Misc_Bag_BigBagOfEnchantments" }
function M.IsRested(aura) return (aura.spellId ~= nil and M.BAG.rested[aura.spellId]) or (aura.name ~= nil and M.BAG.restedNames[aura.name]) or false end
M.FIRE_MINUTE = 60   -- s: the fire's minute, when its timer has no time to read
M.PENDING = 5        -- s: a buff food used this close to an eating aura's start is the one eaten
M.MIN_LAST = 60      -- s: a meal's buff lasts at least a minute (a swallow's 30 s Food does not count)
M.RECENT = 3         -- s: eating or the fire seen this long ago still counts as now
M.HOLD = 5           -- s the card stays
M.FRESH = 5          -- s: a buff that landed longer ago than this is not new (one already on, sent again)

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
    if M.IsRest(aura) or M.IsFireTimer(aura) or M.IsRested(aura) then return nil end
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

-- Did it just land? Its time run so far, from its length and when it ends; one sent again after
-- a hearthstone or a loading screen has run for minutes (2026-11-23: Well Fed's card after a
-- hearth). No time to read (a buff without one): it may be new
function M.Fresh(aura, now)
    local d, e = tonumber(aura.duration) or 0, tonumber(aura.expirationTime) or 0
    if d <= 0 or e <= 0 then return true end
    return d - (e - (now or 0)) <= M.FRESH
end

-- One sentence, short: "Increases Stamina and Spirit by 4 for 15 min" -> "+4 Stamina and Spirit";
-- "Faction Banner: Spirit increased by 14" -> "+14 Spirit"; "Restores 8 mana per 5 sec" ->
-- "+8 mana per 5 sec"; nil: not a gain
local function Gain(s)
    s = s:match("^%s*(.-)%s*$"):gsub("%.$", "")
    s = s:gsub("%s+for%s+%d+%s*%a+$", "")              -- (" for 15 min")
    local what, n = s:match("^[Ii]ncreases%s+(.-)%s+by%s+(%d+%%?)$")
    if what and n then return "+" .. n .. " " .. what:gsub("^your%s+", "") end
    -- (Forever's camp: "<what gives it>: <stat> increased by <n>")
    what, n = s:match("^[^:]-:%s*(.-)%s+increased%s+by%s+(%d+%%?)$")
    if not what then what, n = s:match("^(.-)%s+increased%s+by%s+(%d+%%?)$") end
    -- ("Attack Power is increased by 20")
    if what then what = what:gsub("%s+[Ii]s$", ""):gsub("%s+[Aa]re$", "") end
    if what and n and what ~= "" then return "+" .. n .. " " .. what:gsub("^[Yy]our%s+", "") end
    local rest = s:match("^[Rr]estores%s+(.+)$") or s:match("^[Rr]egenerates%s+(.+)$")
    if rest then return "+" .. rest end
    return nil
end

-- What it gives, from its tooltip, short: each gain found ("+14 Spirit", two at most, " · "
-- between), else its first sentence that isn't a heading ("...the following camp benefits:")
function M.Gives(desc)
    if type(desc) ~= "string" then return nil end
    desc = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", "\n")
    local gains, first = {}, nil
    for line in (desc .. "\n"):gmatch("(.-)\n") do
        for sentence in (line:gsub("%.%s+", ".\1") .. "\1"):gmatch("(.-)\1") do
            local s = sentence:match("^%s*(.-)%s*$")
            if s ~= "" then
                local g = Gain(s)
                if g then
                    if #gains < 2 then gains[#gains + 1] = g end
                elseif not first and not s:find(":%s*$") then
                    first = s:gsub("%.$", "")
                end
            end
        end
    end
    if #gains > 0 then return table.concat(gains, " · ") end
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

-- The wait (pure): a buff food's ten seconds, the fire's minute, on the passage at the bottom
-- left (Passage.lua: no card, a quiet line and the time) till the buff lands; then the card,
-- a short toast. Plain food and water: no wait
M.WAIT = 10          -- s of eating before the buff, when the food doesn't say
M.LATE = 3           -- s past the wait the buff may still land; then the passage goes

-- A buff food, from its eating aura's spell text: { wait, title, gives }, or nil (no buff).
-- "...If you spend at least 10 seconds eating you will become well fed and gain 6 Stamina
-- and Spirit for 15 min."
function M.FoodBuff(desc)
    if type(desc) ~= "string" or desc == "" then return nil end
    local text = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " ")
    local low = text:lower()
    -- (Forever's: "at least 10 sec eating, you will become well fed")
    local wait = tonumber(low:match("at least (%d+) sec%a* %a+ing") or low:match("(%d+) sec%a* eating")
        or low:match("(%d+) sec%a* drinking"))
    local fed = low:find("well fed", 1, true) ~= nil
    if not (wait or fed) then return nil end
    local n, what = text:match("[Gg]ain%s+(%d+%%?)%s+(.-)%s+for%s+%d")
    if not n then n, what = text:match("[Gg]ain%s+(%d+%%?)%s+(.-)%.") end
    return { wait = wait or M.WAIT, title = fed and "Well Fed" or nil, gives = n and ("+" .. n .. " " .. what) or nil }
end

-- The buff foods by item and by the spell their use casts (MealFoods.lua)
M.BUFF_FOODS = ns.MealFoods or {}
M.FOOD_SPELLS = {}
for _, e in pairs(M.BUFF_FOODS) do M.FOOD_SPELLS[e[1]] = e[2] end
local function Listed(gives) return { wait = M.WAIT, title = "Well Fed", gives = gives ~= "" and gives or nil } end

-- A used item's buff: the list, else its tooltip's text (text); nil: no buff (bread, water)
function M.ItemFood(item, text)
    local e = item and M.BUFF_FOODS[item]
    if e then return Listed(e[2]), "list" end
    local food = M.FoodBuff(text)
    if food then return food, "tooltip" end
    return nil
end

-- A cast spell's buff: the list, else its own text (desc); nil: none (the plain Food spell)
function M.SpellFood(spell, desc)
    local gives = spell and M.FOOD_SPELLS[spell]
    if gives then return Listed(gives), "list" end
    local food = M.FoodBuff(desc)
    if food then return food, "text" end
    return nil
end

-- The time to go, counted down to the second: "0:07"
function M.Clock(left)
    local s = math.max(0, math.ceil((tonumber(left) or 0) - 0.05))
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

-- The passage's words and way for a wait (kind "meal", "fire" or "bag") from start to ends, at now
local LOOKS = {
    meal = { icon = "Interface\\Icons\\Spell_Misc_Food", title = "Well Fed" },
    fire = { icon = "Interface\\Icons\\Spell_Fire_Fire", title = "Camp Benefits", sub = "By the fire" },
    bag = { icon = M.BAG.icon, title = "Well-Rested", sub = "+1% XP" },
}
function M.WaitSpec(kind, title, gives, icon, start, ends, now)
    local span = math.max(0.1, ends - start)
    local look = LOOKS[kind] or LOOKS.meal
    return { icon = icon or look.icon, title = title or look.title, clock = M.Clock(ends - now),
        frac = math.max(0, math.min(1, (now - start) / span)), sub = gives or look.sub }
end

-- The bag's next stack: its line under the name ("+2% XP"), from the stacks on (0-2)
function M.BagGives(stacks)
    return ("+%d%% XP"):format(math.min(M.BAG.stacks, (tonumber(stacks) or 0) + 1))
end

-- When an aura began: its end less its length, else now
function M.Start(a, now)
    local d, e = tonumber(a.duration) or 0, tonumber(a.expirationTime) or 0
    if d > 0 and e > 0 then return e - d end
    return now
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
            a = { name = v.name, spellId = v.spellId, icon = v.icon, duration = v.duration, expirationTime = v.expirationTime,
                sourceUnit = v.sourceUnit, isFromPlayerOrPlayerPet = v.isFromPlayerOrPlayerPet, auraInstanceID = v.auraInstanceID,
                applications = v.applications }
        elseif UnitBuff then
            local ok, name, icon, count, _, duration, expires, source, _, _, spellId, _, _, mine = pcall(UnitBuff, "player", i)
            if not ok then return nil end
            if name == nil then break end
            a = { name = name, spellId = spellId, icon = icon, duration = duration, expirationTime = expires, sourceUnit = source,
                isFromPlayerOrPlayerPet = mine, applications = count }
        else
            break
        end
        if secret(a.name) or secret(a.spellId) or secret(a.duration) or secret(a.sourceUnit) or secret(a.expirationTime) or secret(a.applications) then return nil end
        a.index = i
        -- (by the buff, not its instance: the game sends the buffs on again under new
        -- instance ids after a hearthstone)
        a.key = a.spellId or a.name
        list[#list + 1] = a
    end
    return list
end

-- One aura on the player by its spell id, as a Buffs() entry (a hidden one, or one the buff
-- list leaves out); nil: not on, or unreadable
local function PlayerAura(id)
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return nil end
    local ok, v = pcall(get, id)
    if not ok or type(v) ~= "table" or secret(v) then return nil end
    if secret(v.name) or secret(v.duration) or secret(v.expirationTime) then return nil end
    return { name = v.name, spellId = id, icon = v.icon, duration = v.duration, expirationTime = v.expirationTime,
        auraInstanceID = v.auraInstanceID, applications = v.applications, key = id }
end

-- What a buff gives: its tooltip's first line after the name (never the time left), else
-- the spell's description
local function Describe(a)
    local tip = C_TooltipInfo
    local info
    if tip and tip.GetUnitBuffByAuraInstanceID and a.auraInstanceID then info = Call(tip.GetUnitBuffByAuraInstanceID, "player", a.auraInstanceID) end
    if not info and tip and tip.GetUnitAura and a.index then info = Call(tip.GetUnitAura, "player", a.index, "HELPFUL") end
    if type(info) == "table" and type(info.lines) == "table" then
        -- (every line after the name: Forever's camp names its gains under a heading,
        -- "Gained the following camp benefits:" then "Faction Banner: Spirit increased by 14.")
        local out = {}
        for i, line in ipairs(info.lines) do
            local text = type(line) == "table" and line.leftText
            if i > 1 and type(text) == "string" and not secret(text) and text ~= "" and not text:lower():find("remaining", 1, true) then
                out[#out + 1] = text
            end
        end
        if #out > 0 then return table.concat(out, "\n") end
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

-- Above the meal's passage line, wherever Edit Mode put it (the card follows the wait it ends);
-- no passage: above the player frame, centred, its foot 8 px over the portrait's top; y: the rise
local function Anchor(y)
    local frame = _G.PlayerFrame
    card:ClearAllPoints()
    local line = ns.Passage and ns.Passage.Frame and ns.Passage.Frame("meal")
    if line then
        card:SetPoint("BOTTOMLEFT", line, "TOPLEFT", 0, 8 + (y or 0))
    elseif frame and type(frame.GetTop) == "function" then
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

-- The wait shown on the passage: { kind, id, start, ends, title, gives, icon }
local wait
function M.Waiting() return wait end

-- The wait over: the buff landed (its card follows), or gone (stood up, too late, a fight)
local function EndWait()
    if not wait then return end
    wait = nil
    if ns.Passage then ns.Passage.Hide("meal") end
end
M.EndWait = EndWait

local function Spec(now)
    return M.WaitSpec(wait.kind, wait.title, wait.gives, wait.icon, wait.start, wait.ends, now)
end

-- On the passage till the buff lands: kind, id (the eating or the timer aura), start, ends
function M.Wait(kind, id, start, ends, title, gives, icon)
    if not (M.Enabled() and ns.Passage) then return nil end
    wait = { kind = kind, id = id, start = start, ends = ends, title = title, gives = gives, icon = icon }
    ns.Passage.Show("meal", Spec(Now()))
    return wait
end

-- Each frame while waiting: the way and the time; gone a while after the wait with no buff
local function Tick()
    if not wait then return end
    local now = Now()
    if wait.ends - now < -M.LATE then
        if M.Trace then M.Trace(wait.kind .. ": no buff by the end") end
        EndWait()
        return
    end
    if ns.Passage then ns.Passage.Update("meal", Spec(now)) end
end
M.Tick = Tick
local waiter = CreateFrame("Frame")
waiter:SetScript("OnUpdate", function() Tick() end)

-- Shows a meal's buff (a: a Buffs() entry) as kind's card; the words shown, or nil
function M.Show(kind, a)
    EndWait()
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

-- The trace: GamepadCompanionTraceDB.meal, the last 40 lines (each wait found, and why)
local function Trace(line)
    if type(GamepadCompanionTraceDB) ~= "table" then GamepadCompanionTraceDB = {} end
    local t = GamepadCompanionTraceDB
    t.meal = type(t.meal) == "table" and t.meal or {}
    if t.meal[#t.meal] and t.meal[#t.meal]:sub(t.meal[#t.meal]:find(" ") + 1) == line then return end
    t.meal[#t.meal + 1] = ("%.2f %s"):format(Now(), line)
    while #t.meal > 40 do table.remove(t.meal, 1) end
end
M.Trace = Trace

-- A food's buff from its eating aura's own spell text: a food whose eating spell is its own.
-- Forever's buff foods eat under bread's Food aura: no buff here, the item used or the spell
-- cast says it (M.ItemUsed, M.SpellCast). Kept once read; an empty text, not loaded yet, is
-- read again
local foods = {}
local function FoodOf(a)
    local id = a.spellId
    if id == nil then return nil end
    if foods[id] ~= nil then return foods[id] or nil end
    local desc = C_Spell and C_Spell.GetSpellDescription and Call(C_Spell.GetSpellDescription, id)
    if type(desc) == "string" and secret(desc) then desc = nil end
    local food = M.SpellFood(id, desc)
    Trace(("eat: %s %s; spell text %q -> %s"):format(tostring(id), tostring(a.name),
        type(desc) == "string" and desc:sub(1, 140) or "none", food and ("buff, wait " .. food.wait) or "no buff"))
    if not food and (type(desc) ~= "string" or desc == "") then
        if C_Spell and C_Spell.RequestLoadSpellData then Call(C_Spell.RequestLoadSpellData, id) end
        return nil
    end
    foods[id] = food or false
    return food
end

-- A buff food just used (the item, or its spell cast): { at, food, how }. The eating aura that
-- starts within M.PENDING s of it is that food's
local pending
function M.Ate(food, how, now)
    now = now or Now()
    pending = { at = now, food = food, how = how }
    Trace(("eat: %s -> buff, wait %d"):format(how, food.wait))
    if not InCombat() then M.Scan(now) end
end

-- An item used (an action button, a bag slot, a macro's /use): a buff food's wait follows
local function ItemText(item)
    local tip = C_TooltipInfo and C_TooltipInfo.GetItemByID and Call(C_TooltipInfo.GetItemByID, item)
    local text = {}
    for _, line in ipairs(type(tip) == "table" and type(tip.lines) == "table" and tip.lines or {}) do
        local s = type(line) == "table" and line.leftText
        if type(s) == "string" and not secret(s) then text[#text + 1] = s end
    end
    return #text > 0 and table.concat(text, "\n") or nil
end
function M.ItemUsed(item)
    if InCombat() or item == nil or secret(item) then return nil end
    item = tonumber(item)
    if not item then return nil end
    local food, how = M.ItemFood(item, not M.BUFF_FOODS[item] and ItemText(item) or nil)
    if food then M.Ate(food, ("item %d (%s)"):format(item, how)) end
    return food
end

-- The sleeping bag: out (when laid), since (the tracking aura first seen), the Well-Rested
-- stacks and their end at the last read
local bag = { stacks = 0 }
local function InBag(now, tracker)
    if tracker then return true end
    return bag.out ~= nil and now - bag.out <= M.BAG.life and Call(IsResting) == true
end
local function BagWait(now, why)
    if wait then return end
    Trace(("bag: %s -> wait %s"):format(why, M.Clock(M.BAG.tick)))
    M.Wait("bag", "bag@" .. now, now, now + M.BAG.tick, nil, M.BagGives(bag.stacks), M.BAG.icon)
end

-- A spell cast: the bag laid out, or a buff food's own spell ("Nutritious Food")
function M.SpellCast(spell)
    if InCombat() or spell == nil or secret(spell) then return nil end
    spell = tonumber(spell)
    if not spell then return nil end
    if M.BAG.unroll[spell] then
        local now = Now()
        bag.out = now
        BagWait(now, "Unroll Bag")
        return "bag"
    end
    local desc
    if not M.FOOD_SPELLS[spell] then
        desc = C_Spell and C_Spell.GetSpellDescription and Call(C_Spell.GetSpellDescription, spell)
        if type(desc) ~= "string" or secret(desc) then desc = nil end
    end
    local food, how = M.SpellFood(spell, desc)
    if food then M.Ate(food, ("cast %d (%s)"):format(spell, how)) end
    return food
end

-- Resting changed: in the bag (laid out lately), or up from it
function M.Resting(on, now)
    now = now or Now()
    if not bag.out or now - bag.out > M.BAG.life then return end
    if on then
        BagWait(now, "resting by the bag")
    elseif wait and wait.kind == "bag" then
        Trace("bag: up from the bag")
        EndWait()
    end
end

-- The bag at each read: the tracking aura (when the game shows it), Well-Rested's stacks; a
-- stack landed ends the minute, and while still in the bag the next minute starts (three at most)
local function BagRead(list, now, wasPrimed)
    local rested, tracker
    for _, a in ipairs(list) do
        if not rested and M.IsRested(a) then rested = a end
        if not tracker and a.spellId ~= nil and M.BAG.track[a.spellId] then tracker = a end
    end
    if not tracker then
        for id in pairs(M.BAG.track) do tracker = PlayerAura(id); if tracker then break end end
    end
    local stacks = rested and math.max(1, tonumber(rested.applications) or 1) or 0
    local exp = rested and tonumber(rested.expirationTime) or nil
    local landed = rested ~= nil and wasPrimed and (bag.exp == nil or (exp ~= nil and exp > bag.exp + 5) or stacks > bag.stacks)
    bag.stacks, bag.exp = stacks, exp
    local entered = tracker ~= nil and bag.since == nil
    if tracker and not bag.since then bag.since = now end
    if not tracker and bag.since then
        bag.since = nil
        Trace("bag: tracking aura gone")
        if wait and wait.kind == "bag" then EndWait() end
    end
    if landed then
        Trace(("bag: Well-Rested %d/%d"):format(stacks, M.BAG.stacks))
        if wait and wait.kind == "bag" then EndWait() end
    end
    if (landed or entered) and stacks < M.BAG.stacks and InBag(now, tracker) then
        BagWait(now, entered and "tracking aura" or "next stack")
    end
end

local lastRest, lastTimer   -- the eating and the fire's minute already waited on (their ids)
local function Id(a, now)
    if a.auraInstanceID then return a.auraInstanceID end
    local d = tonumber(a.duration) or 0
    return (a.key or "") .. "@" .. (d > 0 and math.floor(M.Start(a, now) + 0.5) or "on")
end

-- The fire's timer: in the buffs, else asked for by its id
local function Timer(list)
    for _, a in ipairs(list) do if M.IsFireTimer(a) then return a end end
    for id in pairs(M.FIRE_TIMER.ids) do
        local a = PlayerAura(id)
        if a then return a end
    end
    return nil
end

-- The waits: a buff food's eating (ahead of the others), the fire's minute (each one, the camp's
-- benefits on or not: sitting on renews them); gone when the eating or the minute ends early
local function Waits(list, now)
    local rest
    for _, a in ipairs(list) do
        if not rest and M.IsRest(a) then rest = a end
    end
    local timer = Timer(list)
    if wait and now < wait.ends - 0.5 then
        local source = (wait.kind == "meal" and rest) or (wait.kind == "fire" and timer) or nil
        if wait.kind ~= "bag" and (not source or Id(source, now) ~= wait.id) then
            Trace(wait.kind .. ": ended early")
            EndWait()
        end
    end
    if not rest then lastRest = nil end
    if not timer then lastTimer = nil end
    if pending and now - pending.at > M.PENDING then pending = nil end
    if rest and Id(rest, now) ~= lastRest and not (wait and wait.kind == "meal") then
        local start = M.Start(rest, now)
        local food
        if pending and math.abs(start - pending.at) <= M.PENDING then
            food = pending.food
            pending = nil
        else
            -- (used well into an eating that began before it: not this eating's)
            if pending and start < pending.at - M.PENDING then
                Trace("eat: " .. pending.how .. " not this eating's")
                pending = nil
            end
            food = FoodOf(rest)
        end
        if food then
            lastRest = Id(rest, now)
            if now < start + food.wait then
                Trace(("eat: %s %s -> wait %s"):format(tostring(rest.spellId), tostring(rest.name), M.Clock(start + food.wait - now)))
                M.Wait("meal", lastRest, start, start + food.wait, food.title, food.gives, rest.icon)
            end
        end
    end
    if timer and Id(timer, now) ~= lastTimer and not wait then
        lastTimer = Id(timer, now)
        local d, e = tonumber(timer.duration) or 0, tonumber(timer.expirationTime) or 0
        local start, ends
        if d > 0 and e > 0 then start, ends = e - d, e else start, ends = now, now + M.FIRE_MINUTE end
        Trace(("fire: %s %s, %s left -> %s"):format(tostring(timer.spellId), tostring(timer.name), M.Clock(ends - now),
            now < ends and "wait" or "over"))
        if now < ends then M.Wait("fire", lastTimer, start, ends, nil, nil, timer.icon) end
    end
end

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
        -- (new, or while waiting one of its kind sent again: Well Fed eaten while still on,
        -- the camp's benefits renewed by another minute sat)
        local known = Named(M.MEALS, a)
        local again = wait ~= nil and seen[a.key] and known ~= nil and wait.kind == (known == "fire" and "fire" or "meal")
        if primed and (not seen[a.key] or again) and M.Fresh(a, now) then
            a.again = again and true or false
            fresh[#fresh + 1] = a
        end
    end
    local wasPrimed = primed
    seen, primed = here, true
    local st = { eating = eating, fire = fire, now = now }
    for _, a in ipairs(fresh) do
        local kind = M.Kind(a, st)
        if kind == "fire" and a.again then
            -- (renewed while sitting on: the minute's done, no card each minute)
            Trace("fire: " .. tostring(a.name) .. " renewed")
            EndWait()
        elseif kind then
            Trace(("card: %s %s"):format(kind, tostring(a.name)))
            return M.Show(kind, a)
        end
    end
    BagRead(list, now, wasPrimed)
    Waits(list, now)
    return nil
end

-- A fresh start (login, a loading screen): the buffs on are not new
function M.Reset()
    EndWait()
    lastRest, lastTimer, pending = nil, nil, nil
    bag.since, bag.exp, bag.stacks = nil, nil, 0
    seen, primed = {}, false
    eating.now, eating.before, eating.at = false, false, -math.huge
    fire.now, fire.before, fire.at = false, false, -math.huge
end

local events = CreateFrame("Frame")
pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "PLAYER_REGEN_DISABLED")
pcall(events.RegisterEvent, events, "PLAYER_UPDATE_RESTING")
events:SetScript("OnEvent", function(_, event, unit, _, spell)
    -- (a fight: no meal; the wait goes)
    if event == "PLAYER_REGEN_DISABLED" then EndWait(); return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then if unit == "player" then M.SpellCast(spell) end; return end
    if event == "PLAYER_UPDATE_RESTING" then if not InCombat() then M.Resting(Call(IsResting) == true) end; return end
    if event == "PLAYER_ENTERING_WORLD" then M.Reset() elseif unit ~= "player" then return end
    if InCombat() then return end
    M.Scan()
end)

-- The items used: an action button's, a bag slot's, a macro's /use (after the game's own call;
-- reads only)
if hooksecurefunc then
    if type(UseAction) == "function" then
        hooksecurefunc("UseAction", function(slot)
            if InCombat() then return end
            local kind, id = Call(GetActionInfo, slot)
            if kind == "item" then M.ItemUsed(id) end
        end)
    end
    if C_Container and type(C_Container.UseContainerItem) == "function" then
        hooksecurefunc(C_Container, "UseContainerItem", function(b, slot)
            if InCombat() then return end
            local info = Call(C_Container.GetContainerItemInfo, b, slot)
            if type(info) == "table" then M.ItemUsed(info.itemID) end
        end)
    end
    local function ByName(name)
        if InCombat() or type(name) ~= "string" then return end
        local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
        M.ItemUsed((Call(instant, name)))
    end
    if type(UseItemByName) == "function" then hooksecurefunc("UseItemByName", ByName) end
    if C_Item and type(C_Item.UseItemByName) == "function" and C_Item.UseItemByName ~= UseItemByName then
        hooksecurefunc(C_Item, "UseItemByName", ByName)
    end
end

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
