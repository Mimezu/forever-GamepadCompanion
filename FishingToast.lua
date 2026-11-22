-- The catch card: a parchment slip that rises off the water above the lure
-- float (FishingLure.lua) each time fishing loot is taken. A journal's few
-- words: what you caught, the one fact worth saying about it (a first, a
-- milestone, a fine catch, a new water), this outing's count and, once these
-- waters have given enough, how often they give it. No sound, no mouse.
-- The catches themselves: FishingJournal.lua. Words pure: tests/FishingToast.lua
local _, ns = ...
local J = ns.FishingJournal
local T = {}
ns.FishingToast = T

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end
local Date = date
local Now = function() return Call(time) or 0 end

---------------------------------------------------------------------------
-- The words (pure)
---------------------------------------------------------------------------
-- Inks (social_diary's parchment palette)
T.PAPER = { 0.86, 0.77, 0.58 }
T.INK = { 0.24, 0.16, 0.07 }
T.INK_STRONG = { 0.13, 0.08, 0.03 }
T.INK_FADED = { 0.44, 0.35, 0.21 }
T.RUBRIC = { 0.50, 0.10, 0.05 }
T.LAPIS = { 0.17, 0.23, 0.47 }
T.ACCENT = "|cff6b240a"   -- 0.42, 0.14, 0.04
-- The icon's ring by quality: the parchment's inks, never the game's neon
T.RINGS = {
    [0] = { 0.31, 0.30, 0.28, 1 }, [1] = { 0.24, 0.16, 0.07, 0.8 }, [2] = { 0.03, 0.42, 0.00, 1 },
    [3] = { 0.00, 0.35, 0.69, 1 }, [4] = { 0.53, 0.05, 0.81, 1 },
}

function T.Ordinal(n)
    n = math.floor(tonumber(n) or 0)
    local tens, ones = n % 100, n % 10
    if tens >= 11 and tens <= 13 then return n .. "th" end
    return n .. (ones == 1 and "st" or ones == 2 and "nd" or ones == 3 and "rd" or "th")
end

-- A kind's milestones (10, 25, 50, 100, 250, 500, 1000, then every 1000) and
-- the journal's (100, 500, 1000, then every 1000)
local KIND_MARKS = { [10] = true, [25] = true, [50] = true, [100] = true, [250] = true, [500] = true }
function T.KindMark(n) n = tonumber(n) or 0; return KIND_MARKS[n] == true or (n >= 1000 and n % 1000 == 0) end
function T.TotalMark(n) n = tonumber(n) or 0; return n == 100 or n == 500 or (n >= 1000 and n % 1000 == 0) end

-- How often these waters give it: nil until they've given 20 catches
function T.Chance(here, hereTotal)
    local share = J.Share(here, hereTotal)
    if not share or share <= 0 then return nil end
    if share >= 0.6 then return "most here" end
    local n = math.floor(1 / share + 0.5)
    if n <= 40 then return "1 in " .. n .. " here" end
    return "rare here"
end

-- When a kind was first caught: "3 Nov", or "Nov 2025" another year
function T.Since(first, now)
    if not (Date and tonumber(first)) then return nil end
    local a, b = Date("*t", first), Date("*t", now or first)
    if a.year == b.year then return tonumber(Date("%d", first)) .. " " .. Date("%b", first) end
    return Date("%b %Y", first)
end

-- The journal names the fish, not its cooking state
function T.Title(name)
    name = tostring(name or "")
    return (name:gsub("^Raw ", ""))
end

local NUMBERS = { [5] = "FIVE", [10] = "TEN" }

-- The card's words for one catch (J.Record's): { kicker, title, line1,
-- line2, hold (s), grey }. The highest moment that applies gives the kicker
-- and line 1; line 2 is the outing's
function T.Words(c, now)
    local K, journal = c.ever or 1, nil
    local place = (c.place and c.place ~= "" and c.place ~= "?") and c.place or nil
    local w = { title = T.Title(c.name), grey = (c.q or 1) == 0 }
    local function Nth(n) return T.ACCENT .. T.Ordinal(n) .. "|r in the journal" end
    if w.grey then
        w.kicker, w.hold = place and place:upper() or "A CATCH", 3
    elseif K == 1 then
        w.kicker, w.line1, w.hold = "FIRST OF ITS KIND", "New to your journal", 7
    elseif (c.q or 1) >= 3 then
        w.kicker, w.line1, w.hold = "A RARE CATCH", Nth(K), 6
    elseif (c.q or 1) == 2 then
        w.kicker, w.line1, w.hold = "A FINE CATCH", Nth(K), 6
    elseif T.KindMark(K) then
        local since = T.Since(c.first, now)
        w.kicker, w.line1, w.hold = "THE " .. T.Ordinal(K):upper(), since and ("Since " .. since) or Nth(K), 6
    elseif T.TotalMark(c.total) then
        w.kicker, w.line1, w.hold = c.total .. " CATCHES", Nth(K), 6
    elseif c.firstHere and place then
        w.kicker, w.line1, w.hold, w.newHere = "NEW HERE", "First from " .. place, 5, true
    elseif NUMBERS[c.run] then
        w.kicker, w.line1, w.hold = NUMBERS[c.run] .. " IN A ROW", Nth(K), 5
    else
        w.kicker, w.line1, w.hold = place and place:upper() or "A CATCH", Nth(K), 4
    end
    w.line2 = T.Ordinal(c.outingTotal or 1) .. " this outing"
    local chance = not w.newHere and place and T.Chance(c.here, c.hereTotal)
    if chance then w.line2 = w.line2 .. "  \194\183  " .. chance end
    return w
end

---------------------------------------------------------------------------
-- The card (made the first time it shows)
---------------------------------------------------------------------------
local W, H, M = 280, 94, 14
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local TITLE_ROOM = W - 60 - M
local card

local function Color(tex, c, a) tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1) end

local function Text(parent, font, size, ink)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetTextColor(ink[1], ink[2], ink[3])
    fs:SetShadowOffset(0, 0)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

local function Build()
    local f = CreateFrame("Frame", "GamepadCompanionCatchCard", UIParent)
    f:SetSize(W, H)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    if f.EnableMouse then f:EnableMouse(false) end
    f:SetAlpha(0)
    f:Hide()
    local skin = ns.OptionsSkin

    -- two soft shadows under the slip, the paper, a wash darker to the foot
    local function Shadow(sub, grow, x, y, a)
        local t = f:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetColorTexture(0, 0, 0, a)
        t:SetPoint("TOPLEFT", f, "TOPLEFT", x - grow / 2, y + grow / 2)
        t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", x + grow / 2, y - grow / 2)
    end
    Shadow(-2, 14, 3, -5, 0.10)
    Shadow(-1, 6, 2, -3, 0.22)
    local paper = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    paper:SetAllPoints()
    Color(paper, T.PAPER)
    local wash = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    wash:SetAllPoints()
    if skin and skin.Gradient then
        skin.Gradient(wash, "VERTICAL", { T.INK[1], T.INK[2], T.INK[3], 0.09 }, { T.INK[1], T.INK[2], T.INK[3], 0 })
    else
        Color(wash, T.INK, 0.04)
    end
    -- the cut edge, and its lit lip along the top and the left
    local function Line(p1, p2, horizontal, c, a, inset)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(c[1], c[2], c[3], a)
        t:SetPoint(p1, f, p1, inset[1], inset[2])
        t:SetPoint(p2, f, p2, inset[3], inset[4])
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
    end
    Line("TOPLEFT", "TOPRIGHT", true, T.INK, 0.30, { 0, 0, 0, 0 })
    Line("BOTTOMLEFT", "BOTTOMRIGHT", true, T.INK, 0.30, { 0, 0, 0, 0 })
    Line("TOPLEFT", "BOTTOMLEFT", false, T.INK, 0.30, { 0, 0, 0, 0 })
    Line("TOPRIGHT", "BOTTOMRIGHT", false, T.INK, 0.30, { 0, 0, 0, 0 })
    local LIP = { 0.95, 0.90, 0.74 }
    Line("TOPLEFT", "TOPRIGHT", true, LIP, 0.35, { 1, -1, -1, -1 })
    Line("TOPLEFT", "BOTTOMLEFT", false, LIP, 0.35, { 1, -1, 1, 1 })

    -- the kicker: a lapis lozenge, red capitals, a red rule fading right
    f.paraph = f:CreateTexture(nil, "ARTWORK")
    f.paraph:SetSize(5, 5)
    Color(f.paraph, T.LAPIS)
    f.paraph:SetPoint("CENTER", f, "TOPLEFT", M + 2, -17)
    if f.paraph.SetRotation then pcall(f.paraph.SetRotation, f.paraph, math.pi / 4) end
    f.kicker = Text(f, BODY_FONT, 11, T.RUBRIC)
    f.kicker:SetPoint("LEFT", f, "TOPLEFT", M + 12, -17)
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetHeight(1)
    if skin and skin.Gradient then
        skin.Gradient(f.rule, "HORIZONTAL", { T.RUBRIC[1], T.RUBRIC[2], T.RUBRIC[3], 0.40 }, { T.RUBRIC[1], T.RUBRIC[2], T.RUBRIC[3], 0 })
    else
        Color(f.rule, T.RUBRIC, 0.25)
    end

    -- the catch, round, in a ring of its quality's ink
    local function Round(t)
        if not f.CreateMaskTexture then return end
        local mask = f:CreateMaskTexture()
        mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(t)
        t:AddMaskTexture(mask)
    end
    f.ring = f:CreateTexture(nil, "ARTWORK", nil, 0)
    f.ring:SetTexture(MASK)
    f.ring:SetSize(40, 40)
    f.ring:SetPoint("CENTER", f, "TOPLEFT", M + 18, -(31 + 18))
    f.icon = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.icon:SetSize(36, 36)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", M, -31)
    Round(f.icon)

    f.title = Text(f, TITLE_FONT, 20, T.INK_STRONG)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -29)
    f.line1 = Text(f, BODY_FONT, 12, T.INK)
    f.line1:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -53)
    f.line2 = Text(f, BODY_FONT, 11, T.INK_FADED)
    f.line2:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -70)
    f:SetScript("OnUpdate", function(_, elapsed) T.Step(elapsed) end)
    return f
end

-- Rests on the float, wherever Edit Mode put it (the float's spot even while
-- it's hidden); y: the rise
local function Anchor(y)
    local float = _G.GamepadCompanionLure
    card:ClearAllPoints()
    if float then
        card:SetPoint("BOTTOMLEFT", float, "TOPLEFT", 2, 14 + (y or 0))
    else
        card:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 38, 284 + (y or 0))
    end
    if float and float.GetFrameLevel then card:SetFrameLevel((float:GetFrameLevel() or 0) + 10) end
end

local function Width(fs)
    local v = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return tonumber(v) or 0
end

local function Fill(w, icon, q)
    card.kicker:SetWidth(0)
    card.kicker:SetText(w.kicker)
    local kw = Width(card.kicker)
    if kw > W - M - (M + 12) then card.kicker:SetWidth(W - M - (M + 12)); kw = W - M - (M + 12) end
    local room = W - M - (M + 12 + kw + 6)
    card.rule:ClearAllPoints()
    card.rule:SetPoint("LEFT", card, "TOPLEFT", M + 12 + kw + 6, -17)
    card.rule:SetWidth(math.max(1, room))
    card.rule:SetShown(room >= 12)

    card.title:SetWidth(0)
    card.title:SetFont(TITLE_FONT, 20, "")
    card.title:SetText(w.title)
    if Width(card.title) > TITLE_ROOM then card.title:SetFont(TITLE_FONT, 18, "") end
    if Width(card.title) > TITLE_ROOM then card.title:SetWidth(TITLE_ROOM) end
    local ink = w.grey and T.INK or T.INK_STRONG
    card.title:SetTextColor(ink[1], ink[2], ink[3])
    card.line1:SetText(w.line1 or "")
    card.line2:SetText(w.line2 or "")

    card.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Fish_02")
    local ring = T.RINGS[q or 1] or T.RINGS[1]
    card.ring:SetVertexColor(ring[1], ring[2], ring[3], ring[4])
end

---------------------------------------------------------------------------
-- Motion: rises 10 px into place as it shows (0.35 s), holds, drifts up 6
-- more as it fades (0.6 s). Another catch while it shows: the words change in
-- place with a small lift, and the hold starts again. No queue.
---------------------------------------------------------------------------
local IN, OUT, LIFT = 0.35, 0.6, 0.25
local phase, t, hold, lift = nil, 0, 4, nil   -- phase: "in", "hold", "out"
local held = false                             -- Edit Mode's sample: stays

local function Out(x) return 1 - (1 - x) * (1 - x) end
local function Ease(x) return x * x end

function T.Step(elapsed)
    if not phase then return end
    t = t + (elapsed or 0)
    local y, a = 0, 1
    if phase == "in" then
        local x = math.min(1, t / IN)
        y, a = -10 * (1 - Out(x)), Out(x)
        if x >= 1 then phase, t = "hold", 0 end
    elseif phase == "hold" then
        if not held and t >= hold then phase, t = "out", 0 end
    elseif phase == "out" then
        local x = math.min(1, t / OUT)
        y, a = 6 * Ease(x), 1 - Ease(x)
        if x >= 1 then phase = nil; card:SetAlpha(0); card:Hide(); return end
    end
    if lift then
        lift = lift + (elapsed or 0)
        if lift >= LIFT then lift = nil else y = y + 4 * math.sin(math.pi * lift / LIFT) end
    end
    Anchor(y)
    card:SetAlpha(a)
    return phase
end

function T.Phase() return phase end

-- Shows one catch's words
function T.Show(w, icon, q)
    if not card then card = Build() end
    Fill(w, icon, q)
    hold = w.hold or 4
    if phase then
        -- (already up, or going: stays, a small lift, the hold again)
        lift = 0
        if phase ~= "in" then phase, t = "hold", 0 end
    else
        phase, t, lift = "in", 0, nil
        card:SetAlpha(0)
    end
    Anchor(phase == "in" and -10 or 0)
    card:Show()
    T.shown = w
    return w
end

function T.Hide()
    if card and phase and phase ~= "out" then phase, t = "out", 0 end
end

local function On()
    local lure = ns.FishingLure
    return not (lure and lure.Setting and lure.Setting().toast == false)
end

---------------------------------------------------------------------------
-- The catch: read the fishing loot as it's ready (before anything takes it),
-- kept in the journal, then shown
---------------------------------------------------------------------------
local lastAt, lastKey = -1, nil

local function Where()
    local zone = Call(GetZoneText) or ""
    if zone == "" then zone = Call(GetRealZoneText) or "" end
    local sub = Call(GetSubZoneText) or ""
    if zone == "" then return "?", "?" end
    return J.Water(zone, sub), (sub ~= "" and sub) or zone
end

-- items: the loot window's (J.Loot); clock: GetTime for the double read
function T.Catch(items, clock, now)
    if type(items) ~= "table" or #items == 0 then return nil end
    -- (LOOT_READY then LOOT_OPENED: the same window read twice)
    local key = {}
    for i, item in ipairs(items) do key[i] = item.id .. "x" .. (item.n or 1) end
    key = table.concat(key, ",")
    if clock and lastKey == key and clock - lastAt < 1 then return nil end
    lastAt, lastKey = clock or -1, key
    now = now or Now()
    local water, place = Where()
    local best = J.Best(J.Record(J.DB(), items, water, now, place))
    if not (best and best.name) or not On() then return nil end
    return T.Show(T.Words(best, now), best.icon, best.q)
end

local function PoleOn()
    local lib = _G.MimezuFishing
    return lib and lib.PoleEquipped and Call(lib.PoleEquipped) == true or false
end

local events = CreateFrame("Frame")
for _, ev in ipairs({ "LOOT_READY", "LOOT_OPENED" }) do pcall(events.RegisterEvent, events, ev) end
events:SetScript("OnEvent", function()
    if not (PoleOn() and Call(IsFishingLoot)) then return end
    T.Catch(J.Loot(), Call(GetTime) or 0)
end)

-- Edit Mode: a sample card rests on the float while it's moved
function T.EditMode(on)
    held = on == true
    if held then
        local icon = C_Item and Call(C_Item.GetItemIconByID, 6291)
        T.Show(T.Words({ name = "Raw Brilliant Smallfish", q = 1, ever = 12, outingTotal = 3, place = "Crystal Lake" }),
            icon, 1)
    else
        T.Hide()
    end
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", function() T.EditMode(true) end, T)
    EventRegistry:RegisterCallback("EditMode.Exit", function() T.EditMode(false) end, T)
end
