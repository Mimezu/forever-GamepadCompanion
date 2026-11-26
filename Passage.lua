-- The passage: a quiet line at the bottom left for a thing that takes time (a flight, a meal's
-- ten seconds, the fire's minute), in the lure float's manner (FishingLure.lua): no paper, no
-- box. A small medallion in a brass rim, the name as in an old book, the time in the same hand
-- at the line's end, a thin line filling as the time goes with a soft gold bead at its head
-- (stops on the way as small dots, passed ones filled and breathing gold once), a quiet line
-- under it. Fades in and out. One per owner ("flight", "meal": the meal's and the fire's),
-- each on a spot of its own: Edit Mode shows a sample of each in its own box to drag
-- (EditSpots.lua), apart from the lure float. Cards stay for short toasts.
-- Pure: P.Clock, P.Spot (tests/MealCard.lua)
local _, ns = ...
local Sh = ns.Shared
local P = {}
ns.Passage = P

-- "2:05", "~2:05" (a guess), "0:00"
function P.Clock(seconds, guess)
    local s = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    return (guess and "~" or "") .. ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

-- Each owner: its name in Edit Mode, its home (bottom-left, UIParent units; over the lure
-- float's home at 36, 210, one above the other) and its Edit Mode sample
P.OWNERS = {
    meal = { label = "Meal & fire", home = { 36, 284 },
        sample = { icon = "Interface\\Icons\\Spell_Misc_Food", title = "Well Fed", clock = "0:07", frac = 0.3,
            sub = "+12 Stamina and Spirit" } },
    flight = { label = "Flight", home = { 36, 358 },
        sample = { icon = "Interface\\Icons\\Ability_Mount_Gryphon_01", title = "Booty Bay", clock = "1:42", frac = 0.4,
            marks = { 0.55, 1 }, passed = 0, sub = "1 stop", bob = true } },
    -- (the pad stuck by another addon's taint: Cross held reloads, PadRescue.lua)
    pad = { label = "Pad stuck", home = { 36, 432 },
        sample = { icon = "Interface\\Icons\\Spell_Nature_TimeStop", title = "Pad stuck", clock = "", frac = 0.4,
            sub = "Hold to reload" } },
}

-- owner's spot from saved ({ owner = { x, y } }): x, y
function P.Spot(owner, saved)
    local s = type(saved) == "table" and saved[owner]
    if type(s) == "table" and tonumber(s[1]) and tonumber(s[2]) then return s[1], s[2] end
    local home = P.OWNERS[owner] and P.OWNERS[owner].home or { 36, 210 }
    return home[1], home[2]
end

if not CreateFrame then return end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function Now() return Call(GetTime) or 0 end
local function Saved()
    local db = Sh and Sh.CharDB and Sh.CharDB()
    if not db then return nil end
    db.passage = type(db.passage) == "table" and db.passage or {}
    return db.passage
end

local SIZE = 40                       -- the medallion
local LINE_W = 184                    -- the way
local GAP = 13                        -- medallion to words
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local PARCHMENT = { 0.93, 0.86, 0.68 }
local MIST = { 0.66, 0.74, 0.72 }
local WISE = { 0.96, 0.80, 0.42 }

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

local function Build(name)
    local f = CreateFrame("Frame", name, UIParent)
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

local function Stop(f, i)
    local s = f.stops[i]
    if s then return s end
    s = {}
    s.ring = Disc(f, "ARTWORK", 2, 6, MIST, 0.9)
    s.hole = Disc(f, "ARTWORK", 3, 3, { 0.04, 0.08, 0.11 }, 1)
    s.hole:SetPoint("CENTER", s.ring, "CENTER")
    s.pulse = Disc(f, "ARTWORK", 4, 16, WISE, 0)
    s.pulse:SetBlendMode("ADD")
    s.pulse:SetPoint("CENTER", s.ring, "CENTER")
    f.stops[i] = s
    return s
end

local editing = false     -- (Edit Mode open: the samples up)

-- spec: { icon, title, clock, frac (0-1), marks (stops, fractions; the last the end), passed,
-- sub, subLit (gold: a second press asked), bob }
local function Draw(w, elapsed)
    local f, spec = w.frame, w.live or (editing and w.sample)
    if not spec then return end
    f.icon:SetTexture(spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.title:SetText(spec.title or "")
    f.clock:SetText(spec.clock or "")
    local lit = spec.subLit and WISE or MIST
    f.sub:SetText(spec.sub or "")
    f.sub:SetTextColor(lit[1], lit[2], lit[3])
    local frac = math.max(0, math.min(1, tonumber(spec.frac) or 0))
    local x = f.x
    f.flown:SetWidth(math.max(1, LINE_W * frac))
    local t = Now()
    f.bead:ClearAllPoints()
    f.bead:SetPoint("CENTER", f, "LEFT", x + LINE_W * frac, -1.5 + math.sin(t * 2.1) * 0.6)
    local breath = 0.5 + 0.5 * math.sin(t * 2.6)
    f.glow:SetSize(12 + 5 * breath, 12 + 5 * breath)
    f.glow:SetAlpha(0.20 + 0.25 * breath)
    -- the stops (none for a single wait)
    local marks, passed = spec.marks or {}, tonumber(spec.passed) or 0
    if passed > w.shownPassed then
        for i = w.shownPassed + 1, passed do Stop(f, i).flash = 1 end
    end
    w.shownPassed = passed
    local n = #marks
    for i = 1, math.max(n, #f.stops) do
        local s = i <= n and Stop(f, i) or f.stops[i]
        if i <= n then
            s.ring:ClearAllPoints()
            s.ring:SetPoint("CENTER", f, "LEFT", x + LINE_W * marks[i], -1.5)
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
    if f.bob then
        if spec.bob and not f.bob:IsPlaying() then f.bob:Play()
        elseif not spec.bob and f.bob:IsPlaying() then f.bob:Stop() end
    end
end

-- The widgets, made the first time each is wanted
local widgets = {}
local function Place(w)
    local x, y = P.Spot(w.owner, Saved())
    w.frame:ClearAllPoints()
    w.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end
local function Widget(owner)
    local w = widgets[owner]
    if w then return w end
    local o = P.OWNERS[owner] or { label = owner }
    local name = "GamepadCompanionPassage" .. owner:sub(1, 1):upper() .. owner:sub(2)
    w = { owner = owner, frame = Build(name), alpha = 0, want = 0, shownPassed = 0, sample = o.sample }
    widgets[owner] = w
    Place(w)
    local ES = ns.EditSpots
    if ES and ES.Add then
        ES.Add({ name = "passage-" .. owner, label = o.label, frame = w.frame,
            get = function() return P.Spot(owner, Saved()) end,
            set = function(x, y)
                local saved = Saved()
                if saved then saved[owner] = (x and y) and { x, y } or nil end
            end })
    end
    return w
end
P.Widget = Widget

-- Up for owner, with spec (as Draw's); again: the words and the way changed
function P.Show(owner, s)
    local w = Widget(owner)
    if not w.live then w.shownPassed = tonumber(s and s.passed) or 0 end
    w.live, w.want = s, 1
    Place(w)
    w.frame:Show()
    Draw(w, 0)
end
-- owner's spec, changed (nothing while it isn't up)
function P.Update(owner, s)
    local w = widgets[owner]
    if w and w.live then w.live = s end
end
-- owner's down
function P.Hide(owner)
    local w = widgets[owner]
    if w and w.live then w.live = nil; w.want = (editing and 1 or 0) end
end
-- owner's widget frame (made when first wanted): where Edit Mode put it, shown or not
function P.Frame(owner) return Widget(owner).frame end
-- Is owner's up (its real thing, not an Edit Mode sample)
function P.Owner(owner)
    if owner then return widgets[owner] ~= nil and widgets[owner].live ~= nil end
    for o, w in pairs(widgets) do if w.live then return o end end
    return nil
end

local function Step(elapsed)
    for _, w in pairs(widgets) do
        local f = w.frame
        if w.want == 1 or w.alpha > 0 then
            w.alpha = w.alpha + (w.want - w.alpha) * math.min(1, (elapsed or 0) * 2.5)
            if w.want == 0 and w.alpha < 0.02 then
                w.alpha = 0
                f:SetAlpha(0)
                f:Hide()
                if f.bob and f.bob:IsPlaying() then f.bob:Stop() end
            else
                f:SetAlpha(w.alpha)
                Draw(w, elapsed)
            end
        end
    end
end
P.Step = Step
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed) Step(elapsed) end)

-- Edit Mode: each owner's sample up in its box (EditSpots), its real one if it's up
function P.EditMode(on)
    editing = on == true
    for owner in pairs(P.OWNERS) do
        local w = Widget(owner)
        if editing then
            w.want = 1
            Place(w)
            w.frame:Show()
            Draw(w, 0)
        elseif not w.live then
            w.want = 0
        end
    end
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", function() P.EditMode(true) end, P)
    EventRegistry:RegisterCallback("EditMode.Exit", function() P.EditMode(false) end, P)
end
