-- The catch card: a parchment slip that rises off the water above the lure
-- float (FishingLure.lua) each time fishing loot is taken. A journal's few
-- words: what you caught, the one fact worth saying about it (a first, a
-- milestone, a fine catch, a new water), this outing's count and, once these
-- waters have given enough, how often they give it. No sound, no mouse.
-- The catches themselves: FishingJournal.lua. Words pure: tests/FishingToast.lua
-- The slip's pieces (paper, kicker, layout, motion) are shared: the meal card
-- (MealCard.lua), the flight card and the flight list's quest note use them.
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
-- The slip's pieces, shared: the paper (T.Paper), a kicker (T.Kicker), the
-- card's layout (T.Slip: a round icon in an ink ring, a title, two lines) and
-- its motion (T.Motion). The catch card, the meal card (MealCard.lua), the
-- flight card and the flight list's quest note are made of them
---------------------------------------------------------------------------
local W, H, M = 280, 94, 14
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
T.TITLE_FONT, T.BODY_FONT = TITLE_FONT, BODY_FONT
local card, motion

local function Color(tex, c, a) tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1) end

-- A line of ink on parent, never wrapped
function T.Text(parent, font, size, ink, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetTextColor(ink[1], ink[2], ink[3])
    fs:SetShadowOffset(0, 0)
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end
local Text = T.Text

-- The slip's paper, on any frame f (also the flight list's quest note): two soft shadows under
-- it, the paper, a wash darker to the foot, the cut edge and its lit lip along the top and the left
function T.Paper(f)
    local skin = ns.OptionsSkin
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
end

-- The kicker on f, at x px in, y px down: a lapis lozenge, red capitals (f.kicker), a red rule
-- fading right (f.rule); T.SetKicker writes it
function T.Kicker(f, x, y)
    local skin = ns.OptionsSkin
    f.paraph = f:CreateTexture(nil, "ARTWORK")
    f.paraph:SetSize(5, 5)
    Color(f.paraph, T.LAPIS)
    f.paraph:SetPoint("CENTER", f, "TOPLEFT", x + 2, y)
    if f.paraph.SetRotation then pcall(f.paraph.SetRotation, f.paraph, math.pi / 4) end
    f.kicker = Text(f, BODY_FONT, 11, T.RUBRIC)
    f.kicker:SetPoint("LEFT", f, "TOPLEFT", x + 12, y)
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetHeight(1)
    if skin and skin.Gradient then
        skin.Gradient(f.rule, "HORIZONTAL", { T.RUBRIC[1], T.RUBRIC[2], T.RUBRIC[3], 0.40 }, { T.RUBRIC[1], T.RUBRIC[2], T.RUBRIC[3], 0 })
    else
        Color(f.rule, T.RUBRIC, 0.25)
    end
    f.kickerAt = { x, y }
end

local function Width(fs)
    local v = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return tonumber(v) or 0
end

-- The kicker's words; the rule fills the rest up to right (px from f's left)
function T.SetKicker(f, text, right)
    local x, y = f.kickerAt[1], f.kickerAt[2]
    f.kicker:SetWidth(0)
    f.kicker:SetText(text)
    local kw = Width(f.kicker)
    if kw > right - (x + 12) then f.kicker:SetWidth(right - (x + 12)); kw = right - (x + 12) end
    local room = right - (x + 12 + kw + 6)
    f.rule:ClearAllPoints()
    f.rule:SetPoint("LEFT", f, "TOPLEFT", x + 12 + kw + 6, y)
    f.rule:SetWidth(math.max(1, room))
    f.rule:SetShown(room >= 12)
end

-- A slip named name, w by h with margin m: the paper, a kicker, a round icon in a ring of
-- ink (f.icon, f.ring), a title (f.title) and two lines (f.line1, f.line2). Hidden, alpha 0;
-- the caller anchors it. T.FillSlip writes it
function T.Slip(name, w, h, m)
    local f = CreateFrame("Frame", name, UIParent)
    f.w, f.m = w, m
    f:SetSize(w, h)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    if f.EnableMouse then f:EnableMouse(false) end
    f:SetAlpha(0)
    f:Hide()
    T.Paper(f)
    T.Kicker(f, m, -17)

    -- the icon, round, in a ring of ink
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
    f.ring:SetPoint("CENTER", f, "TOPLEFT", m + 18, -(31 + 18))
    f.icon = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.icon:SetSize(36, 36)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", m, -31)
    Round(f.icon)

    f.title = Text(f, TITLE_FONT, 20, T.INK_STRONG)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", m + 46, -29)
    f.line1 = Text(f, BODY_FONT, 12, T.INK)
    f.line1:SetPoint("TOPLEFT", f, "TOPLEFT", m + 46, -53)
    f.line2 = Text(f, BODY_FONT, 11, T.INK_FADED)
    f.line2:SetPoint("TOPLEFT", f, "TOPLEFT", m + 46, -70)
    return f
end

-- The slip's words: w = { kicker, title, line1, line2, grey (a quiet one) }, the icon and
-- its ring's ink { r, g, b, a }. A long title shrinks, then is cut
function T.FillSlip(f, w, icon, ring)
    T.SetKicker(f, w.kicker or "", f.w - f.m)
    local room = f.w - (f.m + 46) - f.m
    f.title:SetWidth(0)
    f.title:SetFont(TITLE_FONT, 20, "")
    f.title:SetText(w.title or "")
    if Width(f.title) > room then f.title:SetFont(TITLE_FONT, 18, "") end
    if Width(f.title) > room then f.title:SetWidth(room) end
    local ink = w.grey and T.INK or T.INK_STRONG
    f.title:SetTextColor(ink[1], ink[2], ink[3])
    -- (a line kept on the paper: a point smaller, then cut. A meal's long line ran past the
    -- slip's edge, 2026-11-23)
    local function Line(fs, text, size)
        fs:SetWidth(0)
        fs:SetFont(BODY_FONT, size, "")
        fs:SetText(text or "")
        if Width(fs) > room then fs:SetFont(BODY_FONT, size - 1, "") end
        if Width(fs) > room then fs:SetWidth(room) end
    end
    Line(f.line1, w.line1, 12)
    Line(f.line2, w.line2, 11)
    f.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    ring = ring or T.RINGS[1]
    f.ring:SetVertexColor(ring[1], ring[2], ring[3], ring[4])
end

---------------------------------------------------------------------------
-- Motion: a slip rises 10 px into place as it shows (0.35 s), holds, drifts
-- up 6 more as it fades (0.6 s). Shown again while it shows: the words change
-- in place with a small lift, and the hold starts again. No queue.
-- T.Motion(slip, anchor): anchor(y) places the slip, y the rise. The slip's
-- OnUpdate calls Step
---------------------------------------------------------------------------
local IN, OUT, LIFT = 0.35, 0.6, 0.25

local function Out(x) return 1 - (1 - x) * (1 - x) end
local function Ease(x) return x * x end

function T.Motion(slip, anchor)
    local phase, t, hold, lift = nil, 0, 4, nil   -- phase: "in", "hold", "out"
    local held = false                             -- Edit Mode's sample: stays
    local m = {}
    function m.Step(elapsed)
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
            if x >= 1 then phase = nil; slip:SetAlpha(0); slip:Hide(); return end
        end
        if lift then
            lift = lift + (elapsed or 0)
            if lift >= LIFT then lift = nil else y = y + 4 * math.sin(math.pi * lift / LIFT) end
        end
        anchor(y)
        slip:SetAlpha(a)
        return phase
    end
    -- Shows the slip (filled already) for seconds
    function m.Show(seconds)
        hold = seconds or 4
        if phase then
            -- (already up, or going: stays, a small lift, the hold again)
            lift = 0
            if phase ~= "in" then phase, t = "hold", 0 end
        else
            phase, t, lift = "in", 0, nil
            slip:SetAlpha(0)
        end
        anchor(phase == "in" and -10 or 0)
        slip:Show()
    end
    function m.Hide() if phase and phase ~= "out" then phase, t = "out", 0 end end
    function m.Phase() return phase end
    -- Held: stays up until let go (Edit Mode's sample)
    function m.Hold(on) held = on == true end
    return m
end

---------------------------------------------------------------------------
-- The catch card (made the first time it shows)
---------------------------------------------------------------------------
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

local function Build()
    local f = T.Slip("GamepadCompanionCatchCard", W, H, M)
    motion = T.Motion(f, Anchor)
    f:SetScript("OnUpdate", function(_, elapsed) motion.Step(elapsed) end)
    return f
end

function T.Step(elapsed) return motion and motion.Step(elapsed) end
function T.Phase() return motion and motion.Phase() end

-- Shows one catch's words
function T.Show(w, icon, q)
    if not card then card = Build() end
    T.FillSlip(card, w, icon or "Interface\\Icons\\INV_Misc_Fish_02", T.RINGS[q or 1] or T.RINGS[1])
    motion.Show(w.hold or 4)
    T.shown = w
    return w
end

function T.Hide()
    if motion then motion.Hide() end
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
    if on then
        if not card then card = Build() end
        motion.Hold(true)
        local icon = C_Item and Call(C_Item.GetItemIconByID, 6291)
        T.Show(T.Words({ name = "Raw Brilliant Smallfish", q = 1, ever = 12, outingTotal = 3, place = "Crystal Lake" }),
            icon, 1)
    elseif motion then
        motion.Hold(false)
        T.Hide()
    end
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", function() T.EditMode(true) end, T)
    EventRegistry:RegisterCallback("EditMode.Exit", function() T.EditMode(false) end, T)
end
