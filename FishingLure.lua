-- The fishing lure: which one (yours, or the best in the bags, as Quick use
-- picks food), and a small float at the bottom left while the pole is in hand:
-- the lure on dark water in a brass rim, the water closing over it as its time
-- runs out, a slow bob and a ripple now and then. Quiet: no numbers flashing,
-- no sound. L2 puts the lure on the pole (Fishing.lua, as R2 casts).
local _, ns = ...
local Sh = ns.Shared
local L = {}
ns.FishingLure = L

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end

---------------------------------------------------------------------------
-- The lures (pure: tests/FishingLure.lua)
---------------------------------------------------------------------------
-- Fishing bonus and the Fishing skill they need; a lure's own tooltip wins
-- when it can be read (L.Read), this is the fallback
L.LURES = {
    [6529] = { bonus = 25, skill = 0 },     -- Shiny Bauble
    [6530] = { bonus = 50, skill = 50 },    -- Nightcrawlers
    [6811] = { bonus = 50, skill = 50 },    -- Aquadynamic Fish Lens
    [6532] = { bonus = 75, skill = 100 },   -- Bright Baubles
    [7307] = { bonus = 75, skill = 100 },   -- Flesh Eating Worm
    [6533] = { bonus = 100, skill = 100 },  -- Aquadynamic Fish Attractor
}

-- The lure to put on: setting "auto" (or nil) the best you can use, else that
-- item while it's in the bags. items: { { id, bonus, skill, count, usable } }.
-- usable: the game's own word (false: not yet, red in the bags); skill: the
-- Fishing skill when it could be read (nil: only the game's word counts)
function L.Pick(setting, items, skill)
    skill = tonumber(skill)
    if setting ~= nil and setting ~= "auto" then
        for _, item in ipairs(items) do if item.id == tonumber(setting) then return item end end
        return nil
    end
    local best
    for _, item in ipairs(items) do
        if item.usable ~= false and (not skill or (item.skill or 0) <= skill) then
            if not best or item.bonus > best.bonus
                or (item.bonus == best.bonus and (item.count or 0) > (best.count or 0))
                or (item.bonus == best.bonus and (item.count or 0) == (best.count or 0) and item.id < best.id) then
                best = item
            end
        end
    end
    return best
end

-- Time left as a few quiet words: "9 min", "40 s"
function L.TimeText(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    if seconds >= 60 then return math.ceil(seconds / 60) .. " min" end
    return seconds .. " s"
end

-- A lure's whole time, from what's left: the game says only that. A fresh one
-- (more left than before) sets it, rounded up to the minute (lures last 5 or
-- 10); otherwise the known one stays.
function L.Total(known, before, now)
    if not now then return nil end
    if not known or not before or now > before + 2 or now > known then
        return math.max(60, math.ceil(now / 60) * 60)
    end
    return known
end

---------------------------------------------------------------------------
-- The game: the bags, the skill, the pole's enchant
---------------------------------------------------------------------------
local tips = {}   -- id -> { bonus, skill } read from the tooltip (or false)
function L.Read(id)
    if tips[id] ~= nil then return tips[id] or nil end
    local info = C_TooltipInfo and Call(C_TooltipInfo.GetItemByID, id)
    if not (info and info.lines) then return nil end
    local bonus, skill, lure
    for _, line in ipairs(info.lines) do
        local text = type(line.leftText) == "string" and line.leftText or ""
        local low = text:lower()
        if low:find("fishing pole", 1, true) and low:find("fishing by", 1, true) then
            lure = true
            bonus = tonumber(low:match("fishing by (%d+)"))
        end
        local need = low:match("requires fishing %((%d+)%)")
        if need then skill = tonumber(need) end
    end
    tips[id] = lure and bonus and { bonus = bonus, skill = skill or 0 } or false
    return tips[id] or nil
end

function L.Bags()
    local items, seen = {}, {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return items end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, tonumber((Call(C_Container.GetContainerNumSlots, bag))) or 0 do
            local info = Call(C_Container.GetContainerItemInfo, bag, slot)
            local id = info and tonumber(info.itemID)
            local known = id and (L.Read(id) or L.LURES[id])
            if known then
                if seen[id] then
                    seen[id].count = seen[id].count + (info.stackCount or 1)
                else
                    seen[id] = { id = id, bonus = known.bonus, skill = known.skill or 0, count = info.stackCount or 1,
                        icon = info.iconFileID, name = Call(C_Item.GetItemNameByID, id),
                        usable = Call(C_Item.IsUsableItem, id) ~= false }
                    items[#items + 1] = seen[id]
                end
            end
        end
    end
    return items
end

-- The Fishing skill and its cap (the rank's: 75, 150, 225, 300), each nil when
-- it can't be read. Forever's list is C_SkillInfo (a table a line, as Companion
-- Journal reads it); then the professions; then Classic's own list
function L.SkillInfo()
    local fishing = (PROFESSIONS_FISHING or "Fishing"):lower()
    local function Is(name) return type(name) == "string" and name:lower() == fishing end
    local info = C_SkillInfo
    if info and info.GetNumSkillLines and info.GetSkillLineInfo then
        for i = 1, tonumber((Call(info.GetNumSkillLines))) or 0 do
            local line = Call(info.GetSkillLineInfo, i)
            if type(line) == "table" and not line.isHeader and Is(line.name) then
                return tonumber(line.rank or line.skillRank),
                    tonumber(line.maxRank or line.max or line.skillMaxRank or line.maxSkillRank)
            end
        end
    end
    if GetProfessions and GetProfessionInfo then
        local list = { Call(GetProfessions) }
        for k = 1, 6 do
            local index = list[k]
            if index then
                local name, _, rank, max = Call(GetProfessionInfo, index)
                if Is(name) then return tonumber(rank), tonumber(max) end
            end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, tonumber((Call(GetNumSkillLines))) or 0 do
            local name, header, _, rank, _, _, max = Call(GetSkillLineInfo, i)
            if not header and Is(name) then return tonumber(rank), tonumber(max) end
        end
    end
end

-- The Fishing skill, or nil (then the game's "usable" decides alone)
function L.Skill() return (L.SkillInfo()) end

function L.Setting()
    local char = Sh.CharDB()
    if type(char.fishing) ~= "table" then char.fishing = {} end
    return char.fishing
end

-- The lure L2 puts on now, or nil (the skill: the list's, else the last
-- skill-up's word)
function L.Current()
    return L.Pick(L.Setting().lure or "auto", L.Bags(), L.Skill() or tonumber(L.Setting().skill))
end

---------------------------------------------------------------------------
-- The skill's road (pure: tests/FishingLure.lua). The game tells the client
-- nothing of a water's level or the odds of a point: the server rolls them.
-- Vanilla's server (as rebuilt by MaNGOS) rolls from the skill alone, every
-- catch below 75, then 25 / (skill - 50); the water only decides whether a
-- fish gets away. So: the odds, coloured as a recipe's; the fish your points
-- really take; the rank's cap; a fish lost here
---------------------------------------------------------------------------
-- The odds of a point on a catch (0-1)
function L.Odds(rank)
    rank = tonumber(rank)
    if not rank then return nil end
    if rank < 75 then return 1 end
    return math.min(1, 25 / (rank - 50))
end

-- Coloured as a recipe: orange, yellow, green, grey
L.ODDS_COLOURS = {
    { 0.99, { 1, 0.50, 0.25 } }, { 0.30, { 1, 1, 0 } }, { 0.12, { 0.25, 0.75, 0.25 } }, { 0, { 0.55, 0.55, 0.55 } },
}
function L.OddsColour(odds)
    for _, c in ipairs(L.ODDS_COLOURS) do if (odds or 0) >= c[1] then return c[2] end end
end

-- At the rank's cap: the cap known and reached; else (no cap to read) a cap's
-- number reached and more fish since than its odds explain (3 points' worth)
L.CAPS = { [75] = true, [150] = true, [225] = true }
function L.AtCap(rank, max, since)
    rank, max, since = tonumber(rank), tonumber(max), tonumber(since) or 0
    if not rank then return false end
    if max then return rank >= max and max < 300 end
    return L.CAPS[rank] == true and since >= math.ceil(3 / L.Odds(rank))
end

-- The fish a point took lately: the last few points' average, whole
function L.Pace(list)
    if type(list) ~= "table" or #list == 0 then return nil end
    local sum = 0
    for _, n in ipairs(list) do sum = sum + n end
    return math.max(1, math.floor(sum / #list + 0.5))
end

-- A skill-up message's new Fishing skill, or nil. fmt: the game's
-- SKILL_RANK_UP ("Your skill in %s has increased to %d.")
function L.SkillUp(message, fmt, fishing)
    if type(message) ~= "string" then return nil end
    fmt = type(fmt) == "string" and fmt or "Your skill in %s has increased to %d."
    local pattern = fmt:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    local name, rank = message:match(pattern)
    if not name then return nil end
    if name:lower() ~= (fishing or PROFESSIONS_FISHING or "Fishing"):lower() then return nil end
    return tonumber(rank)
end

-- This stretch of water: the zone and the place in it (a fish lost here)
function L.Water()
    return (Call(GetZoneText) or "") .. "/" .. (Call(GetSubZoneText) or "")
end

-- The pole's lure: seconds left, or nil
local function Left()
    local has, expiration = Call(GetWeaponEnchantInfo)
    if has and tonumber(expiration) then return tonumber(expiration) / 1000 end
end

---------------------------------------------------------------------------
-- The float
---------------------------------------------------------------------------
local SIZE = 52
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local PARCHMENT = { 0.93, 0.86, 0.68 }
local MIST = { 0.66, 0.74, 0.72 }

local float = CreateFrame("Frame", "GamepadCompanionLure", UIParent)
float:SetSize(240, SIZE + 8)
float:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 36, 210)
float:SetFrameStrata("LOW")
float:SetAlpha(0)
float:Hide()

-- the medallion bobs gently, a float on calm water
local medal = CreateFrame("Frame", nil, float)
medal:SetSize(SIZE, SIZE)
medal:SetPoint("LEFT", float, "LEFT", 4, 0)

local function Disc(parent, layer, sub, size, r, g, b, a)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(MASK)
    t:SetSize(size, size)
    t:SetPoint("CENTER")
    t:SetVertexColor(r, g, b, a)
    return t
end

-- a soft shadow on the water under it, a thin brass rim, dark water inside
medal.shadow = Disc(medal, "BACKGROUND", 0, SIZE + 22, 0, 0, 0, 0.45)
medal.rim = Disc(medal, "BACKGROUND", 1, SIZE + 3, 0.62, 0.50, 0.30, 0.95)
medal.water = Disc(medal, "BACKGROUND", 2, SIZE, 0.04, 0.10, 0.12, 0.96)

medal.icon = medal:CreateTexture(nil, "ARTWORK")
medal.icon:SetSize(SIZE - 10, SIZE - 10)
medal.icon:SetPoint("CENTER")
medal.icon:SetTexture("Interface\\Icons\\INV_Misc_Orb_03")
if medal.CreateMaskTexture then
    local mask = medal:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(medal.icon)
    medal.icon:AddMaskTexture(mask)
end
-- a cool sheen over the lure, as seen through water
medal.sheen = Disc(medal, "OVERLAY", 1, SIZE - 10, 0.35, 0.55, 0.60, 0.16)
medal.sheen:SetBlendMode("ADD")

-- the water closing over the lure as its time runs out
medal.tide = CreateFrame("Cooldown", nil, medal, "CooldownFrameTemplate")
medal.tide:SetSize(SIZE - 10, SIZE - 10)
medal.tide:SetPoint("CENTER")
if medal.tide.SetSwipeTexture then medal.tide:SetSwipeTexture(MASK) end
if medal.tide.SetSwipeColor then medal.tide:SetSwipeColor(0.02, 0.07, 0.09, 0.78) end
if medal.tide.SetDrawEdge then medal.tide:SetDrawEdge(false) end
if medal.tide.SetDrawBling then medal.tide:SetDrawBling(false) end
if medal.tide.SetHideCountdownNumbers then medal.tide:SetHideCountdownNumbers(true) end
if medal.tide.SetReverse then medal.tide:SetReverse(true) end

-- ripples: a pale ring of light spreading on the water now and then
local function Ripple(delay)
    local t = Disc(float, "BACKGROUND", -1, SIZE, 0.62, 0.80, 0.84, 0)
    t:ClearAllPoints()
    t:SetPoint("CENTER", medal, "CENTER")
    t:SetBlendMode("ADD")
    local g = t:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    local wait = g:CreateAnimation("Alpha")
    wait:SetFromAlpha(0); wait:SetToAlpha(0); wait:SetDuration(delay); wait:SetOrder(1)
    local grow = g:CreateAnimation("Scale")
    if grow.SetScaleFrom then grow:SetScaleFrom(0.9, 0.9); grow:SetScaleTo(1.9, 1.9) else grow:SetScale(2.1, 2.1) end
    grow:SetDuration(3.2); grow:SetOrder(2); grow:SetSmoothing("OUT")
    local fade = g:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.22); fade:SetToAlpha(0); fade:SetDuration(3.2); fade:SetOrder(2); fade:SetSmoothing("OUT")
    local rest = g:CreateAnimation("Alpha")
    rest:SetFromAlpha(0); rest:SetToAlpha(0); rest:SetDuration(4.5); rest:SetOrder(3)
    return g
end
local ripples = { Ripple(0.4), Ripple(2.6) }

-- the bob: a breath down and up, slow
local bob = medal:CreateAnimationGroup()
bob:SetLooping("BOUNCE")
local drift = bob:CreateAnimation("Translation")
drift:SetOffset(0, -2)
drift:SetDuration(2.4)
drift:SetSmoothing("IN_OUT")

-- the words: the lure's name as in an old book, its time quietly under it
local title = float:CreateFontString(nil, "OVERLAY")
title:SetFont(TITLE_FONT, 16, "")
title:SetShadowColor(0, 0, 0, 0.9)
title:SetShadowOffset(1, -1)
title:SetTextColor(PARCHMENT[1], PARCHMENT[2], PARCHMENT[3])
title:SetPoint("BOTTOMLEFT", medal, "RIGHT", 10, 1)
title:SetJustifyH("LEFT")

local sub = float:CreateFontString(nil, "OVERLAY")
sub:SetFont(BODY_FONT, 11, "")
sub:SetShadowColor(0, 0, 0, 0.9)
sub:SetShadowOffset(1, -1)
sub:SetTextColor(MIST[1], MIST[2], MIST[3])
sub:SetPoint("TOPLEFT", medal, "RIGHT", 11, -3)
sub:SetJustifyH("LEFT")

-- a quiet line under it, now and then: a skill-up, or a water with nothing
-- more to teach
local whisper = float:CreateFontString(nil, "OVERLAY")
whisper:SetFont(BODY_FONT, 10, "")
whisper:SetShadowColor(0, 0, 0, 0.9)
whisper:SetShadowOffset(1, -1)
whisper:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -5)
whisper:SetJustifyH("LEFT")
local WISE = { 0.96, 0.80, 0.42 }

-- fade in and out
local fadeIn = float:CreateAnimationGroup()
local a1 = fadeIn:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.9); a1:SetSmoothing("OUT")
fadeIn:SetScript("OnFinished", function() float:SetAlpha(1) end)
local fadeOut = float:CreateAnimationGroup()
local a2 = fadeOut:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.7); a2:SetSmoothing("IN")
fadeOut:SetScript("OnFinished", function() float:SetAlpha(0); float:Hide() end)

local function Glyph(atlas, size)
    return ("|A:%s:%d:%d|a"):format(atlas, size, size)
end

---------------------------------------------------------------------------
-- What it shows
---------------------------------------------------------------------------
local shown = false
local total, before, spentAt = nil, nil, nil

local function SetLure(icon, lit)
    medal.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Orb_03")
    medal.icon:SetDesaturated(not lit)
    medal.icon:SetAlpha(lit and 1 or 0.55)
    title:SetAlpha(lit and 1 or 0.7)
end

-- The lure on the pole now: the one put on last by L2, else the pick
local function Worn()
    local s = L.Setting()
    local id = tonumber(s.lastLure)
    if id then
        local icon = Call(C_Item.GetItemIconByID, id) or Call(GetItemIcon, id)
        return Call(C_Item.GetItemNameByID, id) or "Lure", icon
    end
end

-- The float's words (pure): title, line under it, lit. left: seconds of lure
-- on the pole (nil: none); spent: it ran out a moment ago; worn: the lure's
-- name; pick: the lure L2 would put on ({ name }), or nil
function L.Words(left, spent, worn, pick)
    if left then return worn or (pick and pick.name) or "Lure", L.TimeText(left), true end
    if spent then return worn or "Lure", "Spent", false end
    if pick then return "No lure", Glyph("Gamepad_Shp_LTrigger_64", 14) .. "  " .. (pick.name or "Lure"), false end
    return "No lure", "None in bags", false
end

-- The quiet line (pure): text and colour, or nil. wiserAt / rank: the last
-- skill-up (GetTime) and its skill; skill, max: now; since: fish since the last
-- point; pace: fish a point took lately; wary: a fish got away in this water
local TRAIN = { 1, 0.82, 0.45 }
local WARY = { 0.85, 0.55, 0.40 }
function L.Whisper(now, wiserAt, rank, skill, max, since, pace, wary)
    if wiserAt and rank and now - wiserAt < 10 then return "Wiser  \194\183  Fishing " .. rank, WISE end
    if L.AtCap(skill, max, since) then return "Train to learn more", TRAIN end
    if wary then return "Strong fish here", WARY end
    if skill then
        local text = "Fishing " .. skill
        if pace then text = text .. "  \194\183  " .. pace .. " fish a point" end
        return text, L.OddsColour(L.Odds(skill))
    end
end

local wiserAt, wiserRank
local wary = {}   -- waters where a fish got away (this session)
function L.WhisperNow(now)
    local s = L.Setting()
    local skill, max = L.SkillInfo()
    skill = skill or tonumber(s.skill)
    local text, color = L.Whisper(now, wiserAt, wiserRank, skill, max, s.since, L.Pace(s.pace), wary[L.Water()])
    whisper:SetText(text or "")
    if color then whisper:SetTextColor(color[1], color[2], color[3]) end
    return text
end

function L.Refresh()
    local left = Left()
    local now = GetTime and GetTime() or 0
    L.WhisperNow(now)
    if left then
        total = L.Total(total, before, left)
        before, spentAt = left, nil
    elseif before then
        -- (just run out: a moment to say so, then what L2 would put on)
        spentAt, before, total = now, nil, nil
    end
    local spent = not left and spentAt ~= nil and now - spentAt < 6
    local worn, wornIcon = Worn()
    local pick = not (left or spent) and L.Current() or (not worn and L.Current()) or nil
    local text, line, lit = L.Words(left, spent, worn, pick)
    SetLure((left or spent) and wornIcon or (pick and pick.icon) or wornIcon, lit)
    title:SetText(text)
    sub:SetText(line)
    if left then medal.tide:SetCooldown(now - (total - left), total) else medal.tide:Clear() end
    return text, line, lit
end

-- Shown while the pole is in hand
function L.Show(on)
    if on == shown then return end
    shown = on
    if on then
        fadeOut:Stop()
        float:Show()
        L.Refresh()
        fadeIn:Play()
        bob:Play()
        for _, r in ipairs(ripples) do r:Play() end
    else
        fadeIn:Stop()
        bob:Stop()
        for _, r in ipairs(ripples) do r:Stop() end
        fadeOut:Play()
    end
end

local function PoleOn()
    local lib = _G.MimezuFishing
    return lib and lib.PoleEquipped and Call(lib.PoleEquipped) == true or false
end

local events = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "BAG_UPDATE_DELAYED",
    "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "LOOT_OPENED", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE", "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
    pcall(events.RegisterEvent, events, ev)
end
events:SetScript("OnEvent", function(_, event, unit, message)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    if event == "CHAT_MSG_SKILL" then
        -- (a point of Fishing: said a moment; the count starts again)
        local rank = L.SkillUp(unit, SKILL_RANK_UP)
        if not rank then return end
        local s = L.Setting()
        -- (the fish that point took, kept for the pace: the last five)
        if type(s.pace) ~= "table" then s.pace = {} end
        if tonumber(s.since) and s.since > 0 then
            table.insert(s.pace, s.since)
            while #s.pace > 5 do table.remove(s.pace, 1) end
        end
        s.skill, s.since, s.waters = rank, 0, nil
        wiserAt, wiserRank = GetTime and GetTime() or 0, rank
    elseif event == "LOOT_OPENED" then
        -- (a fish caught: one more since the last point)
        if not (PoleOn() and Call(IsFishingLoot)) then return end
        local s = L.Setting()
        s.since = (tonumber(s.since) or 0) + 1
    elseif event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
        -- (a fish got away: this water is stronger than the skill)
        local text = type(message) == "string" and message or unit
        if not (PoleOn() and type(text) == "string") then return end
        local lost = ERR_FISH_ESCAPED or "Your fish got away!"
        if text ~= lost then return end
        wary[L.Water()] = true
    end
    L.Show(PoleOn())
    if shown then L.Refresh() end
end)

-- the words once a second while shown (the tide runs by itself)
local tick = 0
float:SetScript("OnUpdate", function(_, elapsed)
    tick = tick - elapsed
    if tick > 0 then return end
    tick = 1
    L.Refresh()
end)

L.frame = float
