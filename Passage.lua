-- The passage: a quiet line at the bottom left for a thing that takes time (a flight, a meal's
-- ten seconds, the fire's minute), in the lure float's manner (FishingLure.lua): no paper, no
-- box. A small medallion in a brass rim, the name as in an old book, the time in the same hand
-- at the line's end, a thin line filling as the time goes with a soft gold bead at its head
-- (stops on the way as small dots, passed ones filled and breathing gold once), a quiet line
-- under it. Fades in and out. It sits where the lure float sits (Edit Mode moves both), just
-- above the float when that shows. One owner at a time ("flight", "meal"); cards stay for
-- short toasts. Pure: P.Clock (tests/Passage.lua)
local _, ns = ...
local P = {}
ns.Passage = P

-- "2:05", "~2:05" (a guess), "0:00"
function P.Clock(seconds, guess)
    local s = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    return (guess and "~" or "") .. ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

if not CreateFrame then return end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function Now() return Call(GetTime) or 0 end

local SIZE = 40                       -- the medallion
local LINE_W = 184                    -- the way
local GAP = 13                        -- medallion to words
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local PARCHMENT = { 0.93, 0.86, 0.68 }
local MIST = { 0.66, 0.74, 0.72 }
local WISE = { 0.96, 0.80, 0.42 }
P.ABOVE_LURE = 74                     -- px up when the lure float shows

local frame, current, spec
local alpha, want = 0, 0
local shownPassed = 0

local function Disc(parent, layer, sub, size, c, a)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(MASK)
    t:SetSize(size, size)
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
    return t
end
local function Ink(fs, font, size, c)
    fs:SetFont(font, size, "")
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
end

local function Build()
    local f = CreateFrame("Frame", "GamepadCompanionPassage", UIParent)
    f:SetSize(SIZE + GAP + LINE_W + 8, SIZE + 16)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    if f.EnableMouse then f:EnableMouse(false) end
    f:SetAlpha(0)
    f:Hide()
    -- the medallion: a soft shadow, a thin brass rim, dark inside, the icon
    local medal = CreateFrame("Frame", nil, f)
    medal:SetSize(SIZE, SIZE)
    medal:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.medal = medal
    local shadow = Disc(medal, "BACKGROUND", 0, SIZE + 18, { 0, 0, 0 }, 0.42)
    shadow:SetPoint("CENTER")
    local rim = Disc(medal, "BACKGROUND", 1, SIZE + 3, { 0.62, 0.50, 0.30 }, 0.95)
    rim:SetPoint("CENTER")
    local inner = Disc(medal, "BACKGROUND", 2, SIZE, { 0.04, 0.08, 0.11 }, 0.96)
    inner:SetPoint("CENTER")
    f.icon = medal:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(SIZE - 8, SIZE - 8)
    f.icon:SetPoint("CENTER")
    if medal.CreateMaskTexture then
        local mask = medal:CreateMaskTexture()
        mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(f.icon)
        f.icon:AddMaskTexture(mask)
    end
    -- (a slow drift up and down while flying: the medallion only)
    if medal.CreateAnimationGroup then
        f.bob = medal:CreateAnimationGroup()
        f.bob:SetLooping("BOUNCE")
        local d = f.bob:CreateAnimation("Translation")
        d:SetOffset(0, -2); d:SetDuration(2.4); d:SetSmoothing("IN_OUT")
    end
    -- the words: the name, the time at the line's end; the way; a quiet line under it
    local x = 4 + SIZE + GAP
    f.x = x
    f.title = f:CreateFontString(nil, "OVERLAY")
    Ink(f.title, TITLE_FONT, 15, PARCHMENT)
    f.title:SetPoint("BOTTOMLEFT", f, "LEFT", x, 4)
    f.clock = f:CreateFontString(nil, "OVERLAY")
    Ink(f.clock, TITLE_FONT, 15, PARCHMENT)
    f.clock:SetJustifyH("RIGHT")
    f.clock:SetPoint("BOTTOMRIGHT", f, "LEFT", x + LINE_W, 4)
    f.title:SetPoint("RIGHT", f.clock, "LEFT", -8, 0)
    f.way = f:CreateTexture(nil, "ARTWORK", nil, 0)
    f.way:SetColorTexture(MIST[1], MIST[2], MIST[3], 0.30)
    f.way:SetSize(LINE_W, 1)
    f.way:SetPoint("LEFT", f, "LEFT", x, -2)
    f.flown = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.flown:SetColorTexture(WISE[1], WISE[2], WISE[3], 0.80)
    f.flown:SetSize(1, 2)
    f.flown:SetPoint("LEFT", f, "LEFT", x, -2)
    f.glow = Disc(f, "ARTWORK", 5, 14, WISE, 0.35)
    f.glow:SetBlendMode("ADD")
    f.bead = Disc(f, "ARTWORK", 7, 5, WISE, 1)
    f.glow:SetPoint("CENTER", f.bead, "CENTER")
    f.sub = f:CreateFontString(nil, "OVERLAY")
    Ink(f.sub, BODY_FONT, 10, MIST)
    f.sub:SetPoint("TOPLEFT", f, "LEFT", x, -9)
    f.sub:SetWidth(LINE_W)
    f.stops = {}
    return f
end

local function Stop(i)
    local s = frame.stops[i]
    if s then return s end
    s = {}
    s.ring = Disc(frame, "ARTWORK", 2, 6, MIST, 0.9)
    s.hole = Disc(frame, "ARTWORK", 3, 3, { 0.04, 0.08, 0.11 }, 1)
    s.hole:SetPoint("CENTER", s.ring, "CENTER")
    s.pulse = Disc(frame, "ARTWORK", 4, 16, WISE, 0)
    s.pulse:SetBlendMode("ADD")
    s.pulse:SetPoint("CENTER", s.ring, "CENTER")
    frame.stops[i] = s
    return s
end

-- Where it sits: the lure float's spot, above the float while that shows
local function Place()
    local L = ns.FishingLure
    local x, y = 36, 210
    if L and L.Spot and L.Setting then x, y = L.Spot(L.Setting().pos) end
    if L and L.frame and L.frame.IsShown and L.frame:IsShown() then y = y + P.ABOVE_LURE end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

-- spec: { icon, title, clock, frac (0-1), marks (stops, fractions; the last the end), passed,
-- sub, subLit (gold: a second press asked), bob }
local function Draw(elapsed)
    if not (frame and spec) then return end
    frame.icon:SetTexture(spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    frame.title:SetText(spec.title or "")
    frame.clock:SetText(spec.clock or "")
    local lit = spec.subLit and WISE or MIST
    frame.sub:SetText(spec.sub or "")
    frame.sub:SetTextColor(lit[1], lit[2], lit[3])
    local frac = math.max(0, math.min(1, tonumber(spec.frac) or 0))
    local x = frame.x
    frame.flown:SetWidth(math.max(1, LINE_W * frac))
    local t = Now()
    frame.bead:ClearAllPoints()
    frame.bead:SetPoint("CENTER", frame, "LEFT", x + LINE_W * frac, -1.5 + math.sin(t * 2.1) * 0.6)
    local breath = 0.5 + 0.5 * math.sin(t * 2.6)
    frame.glow:SetSize(12 + 5 * breath, 12 + 5 * breath)
    frame.glow:SetAlpha(0.20 + 0.25 * breath)
    -- the stops (none for a single wait)
    local marks, passed = spec.marks or {}, tonumber(spec.passed) or 0
    if passed > shownPassed then
        for i = shownPassed + 1, passed do Stop(i).flash = 1 end
    end
    shownPassed = passed
    local n = #marks
    for i = 1, math.max(n, #frame.stops) do
        local s = i <= n and Stop(i) or frame.stops[i]
        if i <= n then
            s.ring:ClearAllPoints()
            s.ring:SetPoint("CENTER", frame, "LEFT", x + LINE_W * marks[i], -1.5)
            local last = i == n
            s.ring:SetSize(last and 8 or 6, last and 8 or 6)
            local done = i <= passed
            local c = done and WISE or MIST
            s.ring:SetVertexColor(c[1], c[2], c[3], 0.9)
            s.ring:Show()
            s.hole:SetShown(not done)
            s.flash = math.max(0, (s.flash or 0) - (elapsed or 0) * 1.2)
            s.pulse:SetVertexColor(WISE[1], WISE[2], WISE[3], 0.55 * s.flash)
            s.pulse:Show()
        elseif s then
            s.ring:Hide(); s.hole:Hide(); s.pulse:Hide()
        end
    end
    if frame.bob then
        if spec.bob and not frame.bob:IsPlaying() then frame.bob:Play()
        elseif not spec.bob and frame.bob:IsPlaying() then frame.bob:Stop() end
    end
end

-- Up for owner, with spec (as Draw's); again: the words and the way changed
function P.Show(owner, s)
    if not frame then frame = Build() end
    if current ~= owner then shownPassed = tonumber(s and s.passed) or 0 end
    current, spec, want = owner, s, 1
    Place()
    frame:Show()
    Draw(0)
end
-- The same owner's spec, changed (nothing when another owns it)
function P.Update(owner, s)
    if current ~= owner then return end
    spec = s
end
-- Down, if owner still has it
function P.Hide(owner)
    if current == owner then want = 0 end
end
function P.Owner() return want == 1 and current or nil end
function P.Shown() return P.Owner() end
P.frame = function() return frame end

local function Step(elapsed)
    if not (frame and current) then return end
    alpha = alpha + (want - alpha) * math.min(1, (elapsed or 0) * 2.5)
    if want == 0 and alpha < 0.02 then
        alpha = 0
        frame:SetAlpha(0)
        frame:Hide()
        if frame.bob and frame.bob:IsPlaying() then frame.bob:Stop() end
        current, spec = nil, nil
        return
    end
    frame:SetAlpha(alpha)
    Place()
    Draw(elapsed)
end
P.Step = Step
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed) Step(elapsed) end)
