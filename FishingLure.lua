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

-- The cast ring (pure): the share of the cast left, 0-1, from the channel's
-- start and end (ms, as UnitChannelInfo gives them) and now (s)
function L.CastLeft(startMs, endMs, now)
    startMs, endMs = tonumber(startMs), tonumber(endMs)
    if not (startMs and endMs) or endMs <= startMs then return nil end
    return math.max(0, math.min(1, (endMs / 1000 - now) / ((endMs - startMs) / 1000)))
end

-- Each piece of the ring (0-1) for the share left: the pieces from the top,
-- clockwise, up to it are drawn, the last one partly (a smooth glide)
function L.Beads(left, n)
    local out, lit = {}, (left or 0) * n
    for i = 1, n do out[i] = math.max(0, math.min(1, lit - (i - 1))) end
    return out
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
L.HOME = { 36, 210 }   -- its spot (bottom-left, UIParent units) until moved in Edit Mode
float:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", L.HOME[1], L.HOME[2])
float:SetMovable(true)
float:SetClampedToScreen(true)
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

-- The cast ring, in place of Blizzard's cast bar while you fish: one clean
-- thin line of pale blue around the float, drained clockwise from the top as
-- the line's time runs out, its light breathing slowly. Drawn as short line
-- pieces on the float itself (so it bobs with it and never covers the lure)
local PIECES, RING_R = 72, SIZE / 2 + 6
local PALE = { 0.62, 0.82, 0.95 }
local BREATH = 3.2   -- s, one slow breath
local pieces = {}
local function Spot(share) -- a point on the ring, share 0-1 clockwise from the top
    local a = share * 2 * math.pi
    return RING_R * math.sin(a), RING_R * math.cos(a)
end
for i = 1, PIECES do
    local line = medal.CreateLine and medal:CreateLine(nil, "OVERLAY", nil, 3)
    if line then
        line:SetThickness(1.5)
        line:SetColorTexture(PALE[1], PALE[2], PALE[3], 1)
        line:SetAlpha(0)
        pieces[i] = line
    end
end
local ringAlpha, ringWant, cast = 0, 0, nil   -- cast: { start, end } ms, the line out
local lastLeft = 1                           -- (the share shown last: kept as the ring fades out)

local function DrawRing(now, elapsed)
    -- (fade in on the cast, out when the line comes in)
    local step = (elapsed or 0) / 0.5
    ringAlpha = ringWant > ringAlpha and math.min(ringWant, ringAlpha + step) or math.max(ringWant, ringAlpha - step)
    if cast then lastLeft = L.CastLeft(cast[1], cast[2], now) or lastLeft end
    local shares = L.Beads(lastLeft, PIECES)
    -- (its light breathing: 0.55-0.9 of full, slow)
    local breath = 0.725 + 0.175 * math.sin(now * 2 * math.pi / BREATH)
    for i, line in ipairs(pieces) do
        local v = shares[i]
        if v > 0 and ringAlpha > 0 then
            local x1, y1 = Spot((i - 1) / PIECES)
            local x2, y2 = Spot((i - 1 + v) / PIECES)
            line:SetStartPoint("CENTER", medal, x1, y1)
            line:SetEndPoint("CENTER", medal, x2, y2)
            line:SetAlpha(ringAlpha * breath)
        else
            line:SetAlpha(0)
        end
    end
end


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

-- A point of Fishing, celebrated quietly (about two seconds, no sound): a warm
-- bloom swells from the float like sun catching the water, a few motes of light
-- rise off it, and the line comes up into place in bright gold, then settles
local celebration = {}
do
    local bloom = Disc(float, "OVERLAY", 6, SIZE, 1, 0.82, 0.45, 0)
    bloom:ClearAllPoints()
    bloom:SetPoint("CENTER", medal, "CENTER")
    bloom:SetBlendMode("ADD")
    local g = bloom:CreateAnimationGroup()
    local grow = g:CreateAnimation("Scale")
    if grow.SetScaleFrom then grow:SetScaleFrom(0.8, 0.8); grow:SetScaleTo(1.8, 1.8) else grow:SetScale(2.2, 2.2) end
    grow:SetDuration(1.4); grow:SetSmoothing("OUT")
    local rise = g:CreateAnimation("Alpha"); rise:SetFromAlpha(0); rise:SetToAlpha(0.55); rise:SetDuration(0.25); rise:SetSmoothing("OUT")
    local fade = g:CreateAnimation("Alpha"); fade:SetFromAlpha(0.55); fade:SetToAlpha(0); fade:SetDuration(1.15)
    fade:SetStartDelay(0.25); fade:SetSmoothing("IN")
    celebration[#celebration + 1] = g
    -- the motes: small soft lights drifting up and away, each its own path
    local paths = { { -14, 34, 0.05 }, { 6, 44, 0.2 }, { 18, 30, 0.35 }, { -4, 52, 0.5 }, { 12, 38, 0.7 } }
    for _, path in ipairs(paths) do
        local mote = Disc(float, "OVERLAY", 7, 5, 1, 0.88, 0.55, 0)
        mote:ClearAllPoints()
        mote:SetPoint("CENTER", medal, "CENTER", path[1] * 0.4, 4)
        mote:SetBlendMode("ADD")
        local m = mote:CreateAnimationGroup()
        local up = m:CreateAnimation("Translation"); up:SetOffset(path[1], path[2]); up:SetDuration(1.7)
        up:SetStartDelay(path[3]); up:SetSmoothing("OUT")
        local on = m:CreateAnimation("Alpha"); on:SetFromAlpha(0); on:SetToAlpha(0.9); on:SetDuration(0.3); on:SetStartDelay(path[3])
        local off = m:CreateAnimation("Alpha"); off:SetFromAlpha(0.9); off:SetToAlpha(0); off:SetDuration(1.4)
        off:SetStartDelay(path[3] + 0.3); off:SetSmoothing("IN")
        celebration[#celebration + 1] = m
    end
    -- the line: up into place
    local w = whisper:CreateAnimationGroup()
    local lift = w:CreateAnimation("Translation"); lift:SetOffset(0, 5); lift:SetDuration(0.01); lift:SetOrder(1)
    local settle = w:CreateAnimation("Translation"); settle:SetOffset(0, -5); settle:SetDuration(0.9); settle:SetOrder(2)
    settle:SetSmoothing("OUT")
    local show = w:CreateAnimation("Alpha"); show:SetFromAlpha(0); show:SetToAlpha(1); show:SetDuration(0.9); show:SetOrder(2)
    celebration[#celebration + 1] = w
end
local BRIGHT = { 1, 0.90, 0.58 }

function L.Celebrate()
    if not float:IsShown() then return end
    for _, g in ipairs(celebration) do g:Stop(); g:Play() end
end

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
-- point; pace: fish a point took lately; wary: fish keep getting away in
-- this water (L.Wary: one escape says little, an early or late press loses a
-- fish too)
local TRAIN = { 1, 0.82, 0.45 }
local WARY = { 0.85, 0.55, 0.40 }
function L.Whisper(now, wiserAt, rank, skill, max, since, pace, wary)
    if wiserAt and rank and now - wiserAt < 10 then return "Wiser  \194\183  Fishing " .. rank, now - wiserAt < 2.5 and BRIGHT or WISE end
    if L.AtCap(skill, max, since) then return "Train to learn more", TRAIN end
    if wary then return "Skill too low here", WARY end
    if skill then
        local text = "Fishing " .. skill
        if pace then text = text .. "  \194\183  " .. pace .. " fish a point" end
        return text, L.OddsColour(L.Odds(skill))
    end
end

local wiserAt, wiserRank
local wary = {}   -- water -> the times fish got away there (this session)

-- Fish keep getting away here: 3 within 10 minutes, the last within 10
L.WARY_COUNT, L.WARY_WINDOW = 3, 600
function L.Wary(times, now)
    if type(times) ~= "table" then return false end
    local recent = 0
    for _, t in ipairs(times) do if now - t <= L.WARY_WINDOW then recent = recent + 1 end end
    return recent >= L.WARY_COUNT
end
function L.WhisperNow(now)
    local s = L.Setting()
    local skill, max = L.SkillInfo()
    skill = skill or tonumber(s.skill)
    local text, color = L.Whisper(now, wiserAt, wiserRank, skill, max, s.since, L.Pace(s.pace), L.Wary(wary[L.Water()], now))
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

-- Blizzard's cast bar, unseen while you fish (its alpha only: never hidden or
-- moved; its own handler sets it back on the next cast). Setup > Fishing > Cast ring
local function CastBars()
    return { _G.PlayerCastingBarFrame, _G.CastingBarFrame }
end
local function Fishing()
    return cast ~= nil and L.Setting().castRing ~= false
end
local hooked = {}
local function HookBars()
    for _, bar in ipairs(CastBars()) do
        if bar and not hooked[bar] and bar.HookScript then
            hooked[bar] = true
            bar:HookScript("OnEvent", function(self) if Fishing() then self:SetAlpha(0) end end)
            bar:HookScript("OnShow", function(self) if Fishing() then self:SetAlpha(0) end end)
        end
    end
end

-- The line out (UNIT_SPELLCAST_CHANNEL_*), Fishing every rank
local FISHING = { [7620] = true, [7731] = true, [7732] = true, [18248] = true }
function L.Cast(on)
    if on then
        local _, _, _, startMs, endMs = Call(UnitChannelInfo, "player")
        cast = startMs and endMs and { startMs, endMs } or nil
    else
        cast = nil
    end
    ringWant = (cast and L.Setting().castRing ~= false) and 1 or 0
    HookBars()
    if Fishing() then for _, bar in ipairs(CastBars()) do if bar then bar:SetAlpha(0) end end end
end

local events = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "BAG_UPDATE_DELAYED",
    "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "LOOT_OPENED", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE", "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
    pcall(events.RegisterEvent, events, ev)
end
for _, ev in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    if not pcall(events.RegisterUnitEvent, events, ev, "player") then pcall(events.RegisterEvent, events, ev) end
end
events:SetScript("OnEvent", function(_, event, unit, message, spellID)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if unit == "player" and FISHING[spellID] then L.Cast(true) end
        return
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if unit == "player" and cast then L.Cast(false) end
        return
    end
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
        if shown then L.Refresh(); L.Celebrate() end
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
        local key, at = L.Water(), GetTime and GetTime() or 0
        local times = wary[key] or {}
        times[#times + 1] = at
        while #times > L.WARY_COUNT do table.remove(times, 1) end
        wary[key] = times
    end
    L.Show(PoleOn() or L.editing == true)
    if shown then L.Refresh() end
end)

-- the words once a second while shown (the tide runs by itself)
local tick = 0
float:SetScript("OnUpdate", function(_, elapsed)
    if ringWant > 0 or ringAlpha > 0 then DrawRing(GetTime and GetTime() or 0, elapsed) end
    tick = tick - elapsed
    if tick > 0 then return end
    tick = 1
    L.Refresh()
end)

-- Edit Mode: the float shows (pole or not) in a box of Edit Mode's blue, as
-- Companion's bar boxes (EditModeBars.lua): drag it anywhere, right-click puts
-- it home. Its spot is the character's. Edit Mode listened to, never hooked
function L.Spot(pos)
    if type(pos) == "table" and tonumber(pos[1]) and tonumber(pos[2]) then return pos[1], pos[2] end
    return L.HOME[1], L.HOME[2]
end
local function Place()
    local x, y = L.Spot(L.Setting().pos)
    float:ClearAllPoints()
    float:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end
L.Place = Place

local box = CreateFrame("Frame", nil, UIParent)
box:SetFrameStrata("HIGH")
box:SetAllPoints(float)
box:EnableMouse(true)
if box.RegisterForDrag then box:RegisterForDrag("LeftButton") end
box:Hide()
box.fill = box:CreateTexture(nil, "BACKGROUND")
box.fill:SetAllPoints()
box.fill:SetColorTexture(0.25, 0.6, 1, 0.18)
for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
    { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local e = box:CreateTexture(nil, "BORDER")
    e:SetPoint(pts[1]); e:SetPoint(pts[2])
    if i <= 2 then e:SetHeight(2) else e:SetWidth(2) end
    e:SetColorTexture(0.25, 0.6, 1, 0.95)
end
box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
box.label:SetPoint("BOTTOM", box, "TOP", 0, 3)
box.label:SetText("Fishing")
box:SetScript("OnDragStart", function() float:StartMoving() end)
box:SetScript("OnDragStop", function()
    float:StopMovingOrSizing()
    local x, y = float:GetLeft(), float:GetBottom()
    if tonumber(x) and tonumber(y) then L.Setting().pos = { math.floor(x + 0.5), math.floor(y + 0.5) } end
    Place()
end)
box:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then L.Setting().pos = nil; Place() end
end)

function L.EditMode(on)
    L.editing = on == true
    box:SetShown(L.editing)
    L.Show(PoleOn() or L.editing)
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", function() L.EditMode(true) end, L)
    EventRegistry:RegisterCallback("EditMode.Exit", function() L.EditMode(false) end, L)
end
-- (its spot once the character's settings are there)
local placer = CreateFrame("Frame")
pcall(placer.RegisterEvent, placer, "PLAYER_LOGIN")
placer:SetScript("OnEvent", function() Place() end)

L.frame = float
