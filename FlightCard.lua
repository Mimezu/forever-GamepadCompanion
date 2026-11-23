-- The flight card: on a taxi, a small slip of the catch card's paper (FishingToast.lua) in the
-- lower left: where you're going, the time left, and the way there as a line, a dot per stop
-- (passed ones filled), a marker gliding along it. The game gives no time left: each route's
-- time is learned from the flights you take (per character), else guessed from its length ("~").
-- B lands at the next stop (TaxiRequestEarlyLanding, as Blizzard's leave button does): a first
-- press names the stop, a second within 3 s lands. B is ours only while on a taxi with a stop
-- ahead, rebound only once it has been up a moment (Sh.Settler, the triggers' rule).
-- docs/FLIGHT-LIST.md. Pure: tests/FlightCard.lua
local _, ns = ...
local Sh = ns.Shared
local C = {}
ns.FlightCard = C

---------------------------------------------------------------------------
-- The timing (pure)
---------------------------------------------------------------------------
C.SPEED = 30      -- yd/s on a taxi (OpenMap's own estimate)
C.BEND = 1.2      -- the way curves: the straight line times this
C.TAKEOFF = 10    -- s: rising and setting down, once a flight
C.UNKNOWN = 90    -- s: a hop with no length known
C.MIN, C.MAX = 5, 3600   -- a learned time outside these: not a flight

function C.Key(from, to) return tostring(from) .. " > " .. tostring(to) end

-- The way: hops = { { from, to, len (yards, straight; nil unknown) } }, times = learned
-- { [key] = s }. -> plan { total, guess (true: some of it estimated), marks (each hop's end, a
-- fraction of the way), hops }
-- pace: s per straight yard, learned from your flights (C.LearnPace), else BEND / SPEED.
function C.Plan(hops, times, pace)
    times = times or {}
    pace = pace or C.BEND / C.SPEED
    local parts, sum, guess = {}, 0, false
    for i, h in ipairs(hops) do
        local t = times[C.Key(h.from, h.to)]
        if not t then
            guess = true
            t = h.len and h.len * pace or C.UNKNOWN
            if #hops == 1 then t = t + C.TAKEOFF end
        end
        parts[i] = t
        sum = sum + t
    end
    local route = #hops > 0 and times[C.Key(hops[1].from, hops[#hops].to)]
    local total = route or (sum + ((#hops > 1 and guess) and C.TAKEOFF or 0))
    if route then guess = false end
    local marks, acc = {}, 0
    for i, t in ipairs(parts) do
        acc = acc + t
        marks[i] = sum > 0 and acc / sum or i / #parts
    end
    return { total = total, guess = guess, marks = marks, hops = hops }
end

-- elapsed s into the plan: -> fraction of the way (0..1), s left, stops passed. left: the time
-- left as seen in flight (C.Left), else the plan's
function C.Progress(plan, elapsed, left)
    local total = math.max(1, left and (elapsed or 0) + left or plan.total or 1)
    local frac = math.max(0, math.min(1, (elapsed or 0) / total))
    local passed = 0
    for i = 1, #plan.marks - 1 do if plan.marks[i] <= frac then passed = i end end
    return frac, math.max(0, total - (elapsed or 0)), passed
end

-- The next stop before the destination (its hop index), or nil: none left
function C.NextStop(plan, passed)
    local i = (passed or 0) + 1
    if i <= #plan.marks - 1 then return i end
    return nil
end

-- A flight's time into times[key]: the first as it is, then the mean with the last
function C.Learn(times, key, seconds)
    if type(seconds) ~= "number" or seconds < C.MIN or seconds > C.MAX then return false end
    local old = times[key]
    times[key] = math.floor((old and (old + seconds) / 2 or seconds) + 0.5)
    return true
end

-- Seen in flight: the way winds far more than the straight line (a guess ran out with Tarren
-- Mill still ahead, "~0:00", 2026-11-22). Once a second the straight distance to the
-- destination is sampled; how fast it shrinks says the time left.
C.SAMPLE = 1        -- s between samples
C.WINDOW = 20       -- s of samples the rate is read over
C.SPAN_MIN = 6      -- s of samples before the rate is trusted at all
C.TRUST = 30        -- s of samples for the guess to give way to it fully
C.KEEP = 60         -- samples kept

-- samples { { t, d } } (oldest first) -> s left, and the span read (nil: not yet)
function C.LiveLeft(samples)
    local n = samples and #samples or 0
    if n < 2 then return nil end
    local last = samples[n]
    local first
    for i = n - 1, 1, -1 do
        first = samples[i]
        if last.t - first.t >= C.WINDOW then break end
    end
    local span = last.t - first.t
    if span < C.SPAN_MIN then return nil end
    local rate = (first.d - last.d) / span
    if rate < 3 then return nil end          -- (turning, or away for now: no say)
    return last.d / rate, span
end

-- The time left to show: the plan's; a guessed plan gives way to what's seen as it builds;
-- a learned one holds unless it ran out with the destination still ahead. -> s, guessed
function C.Left(plan, elapsed, live, span)
    local planned = math.max(0, (plan.total or 0) - (elapsed or 0))
    if not live then return planned, plan.guess end
    if planned <= 0 then return live, true end
    if not plan.guess then return planned, false end
    local w = math.min(1, (span or 0) / C.TRUST)
    return w * live + (1 - w) * planned, true
end

-- A whole flight teaches the pace (s per straight yard, after rising and setting down): the
-- first as it is, then the mean with the last. -> kept
function C.LearnPace(db, seconds, len)
    if type(seconds) ~= "number" or type(len) ~= "number" or len < 200 then return false end
    if seconds < C.MIN or seconds > C.MAX then return false end
    local p = (seconds - C.TAKEOFF) / len
    if p < 0.02 or p > 0.2 then return false end     -- (30 to 2 yd/s straight: else not a flight)
    db.flightPace = db.flightPace and (db.flightPace + p) / 2 or p
    return true
end

-- "2:05", "~2:05" (a guess), "0:00"
function C.Clock(seconds, guess)
    seconds = math.max(0, math.floor((seconds or 0) + 0.5))
    return ("%s%d:%02d"):format(guess and "~" or "", math.floor(seconds / 60), seconds % 60)
end

-- The flight times learned (per character)
function C.Times()
    local db = Sh.CharDB()
    if type(db.flightTimes) ~= "table" then db.flightTimes = {} end
    return db.flightTimes
end
function C.Enabled() return Sh.CharDB().flightCard ~= false end

---------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------
if not CreateFrame then return end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Now() return GetTime and GetTime() or 0 end
local function Wall() return Call(time) or 0 end
local function OnTaxi() return Call(UnitOnTaxi, "player") and true or false end

local W, H, M = 268, 96, 14
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local GOLD = { 1.00, 0.78, 0.18 }
local LAND_BUTTON = "GamepadCompanionFlightLand"
local LAND_KEY = "PAD2"

local flight      -- { from, to, hops, plan, start (GetTime), wall (time()), landing }
local pending     -- the route picked, before the taxi rises: { from, to, hops, at }

-- The route from the flight map, as it is picked (TakeTaxiNode): each hop's names and length
local function Route(index)
    local n = tonumber(Call(GetNumRoutes, index)) or 0
    local names, hops = {}, {}
    for r = 1, n do
        local a, b = Call(TaxiGetNodeSlot, index, r, true), Call(TaxiGetNodeSlot, index, r, false)
        local an, bn = a and Call(TaxiNodeName, a), b and Call(TaxiNodeName, b)
        if not (an and bn) then return nil end
        hops[r] = { from = an, to = bn }
        names[an], names[bn] = true, true
    end
    if #hops == 0 then
        local here, there
        for i = 1, tonumber(Call(NumTaxiNodes)) or 0 do
            if Call(TaxiNodeGetType, i) == "CURRENT" then here = Call(TaxiNodeName, i) end
        end
        there = Call(TaxiNodeName, index)
        if not (here and there) then return nil end
        hops[1] = { from = here, to = there }
        names[here], names[there] = true, true
    end
    -- lengths: the paths' world points (FlightList.lua reads them as it does for the quests)
    local FL = ns.FlightList
    local nodes = {}
    for name in pairs(names) do
        local place, zone = FL.SplitName(name)
        nodes[#nodes + 1] = { name = name, place = place, zone = zone }
    end
    local at = {}
    if FL.PathsOf then
        for _, p in ipairs(FL.PathsOf(nodes) or {}) do at[p.name] = p.at end
    end
    for _, h in ipairs(hops) do
        local a, b = at[h.from], at[h.to]
        if a and b and FL.SameContinent(a, b) then
            local dx, dy = a.x - b.x, a.y - b.y
            h.len = math.sqrt(dx * dx + dy * dy)
        end
    end
    -- (and where it ends: the time left is read against it in flight)
    local dest = at[hops[#hops].to]
    return hops, dest and { cont = dest.cont, map = dest.map, x = dest.x, y = dest.y } or nil
end

-- Where you are now (world yards, as the paths' points), or nil
local function Here()
    local FL = ns.FlightList
    if not (FL and FL.WorldOf and C_Map) then return nil end
    local map = Call(C_Map.GetBestMapForUnit, "player")
    local pos = map and Call(C_Map.GetPlayerMapPosition, map, "player")
    if not pos then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return FL.WorldOf(map, x, y)
end

-- The straight length of the way (nil: a hop unknown)
local function Length(hops)
    local sum = 0
    for _, h in ipairs(hops or {}) do
        if not h.len then return nil end
        sum = sum + h.len
    end
    return sum
end

-- The card ------------------------------------------------------------------------
local card

local function Disc(parent, size, color, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 1)
    t:SetTexture(DISC)
    t:SetSize(size, size)
    t:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    return t
end

local LINE_X, LINE_Y, LINE_W = M + 6, -78, W - 2 * M - 12

local function Build()
    local T = ns.FishingToast
    if not (T and T.Paper and T.Kicker and T.Text) then return nil end
    local Text = T.Text
    local f = CreateFrame("Frame", "GamepadCompanionFlightCard", UIParent)
    f:SetSize(W, H)
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 24, 230)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    f:SetAlpha(0)
    f:Hide()
    T.Paper(f)
    T.Kicker(f, M, -15)
    f.title = Text(f, TITLE_FONT, 19, T.INK_STRONG)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", M, -27)
    f.clock = Text(f, TITLE_FONT, 19, T.INK_STRONG, "RIGHT")
    f.clock:SetPoint("TOPRIGHT", f, "TOPRIGHT", -M, -27)
    f.title:SetPoint("RIGHT", f.clock, "LEFT", -8, 0)
    f.land = Text(f, BODY_FONT, 10, T.INK_FADED)
    f.land:SetPoint("TOPLEFT", f, "TOPLEFT", M, -52)
    -- the way: a faded ink line, the part flown in ink
    f.way = f:CreateTexture(nil, "ARTWORK", nil, 0)
    f.way:SetHeight(1)
    f.way:SetColorTexture(T.INK[1], T.INK[2], T.INK[3], 0.30)
    f.way:SetPoint("LEFT", f, "TOPLEFT", LINE_X, LINE_Y)
    f.way:SetWidth(LINE_W)
    f.flown = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.flown:SetHeight(2)
    f.flown:SetColorTexture(T.INK[1], T.INK[2], T.INK[3], 0.85)
    f.flown:SetPoint("LEFT", f, "TOPLEFT", LINE_X, LINE_Y)
    -- the stops: an ink ring, filled once passed (a ring of paper inside while to come)
    f.stops = {}
    -- the marker: a gold bead with a soft glow, breathing
    f.glow = Disc(f, 16, { GOLD[1], GOLD[2], GOLD[3], 0.35 }, "ARTWORK", 5)
    f.glow:SetBlendMode("ADD")
    f.bead = Disc(f, 8, GOLD, "ARTWORK", 7)
    f.beadRing = Disc(f, 10, { 0.16, 0.09, 0.02, 1 }, "ARTWORK", 6)
    f.bead:SetPoint("CENTER", f.beadRing, "CENTER")
    f.glow:SetPoint("CENTER", f.beadRing, "CENTER")
    return f
end

local function Stop(i)
    local s = card.stops[i]
    if s then return s end
    local T = ns.FishingToast
    s = {}
    s.ring = Disc(card, 9, { 0.16, 0.09, 0.02, 1 }, "ARTWORK", 2)
    s.hole = Disc(card, 5, { T.PAPER[1], T.PAPER[2], T.PAPER[3], 1 }, "ARTWORK", 3)
    s.hole:SetPoint("CENTER", s.ring, "CENTER")
    s.pulse = Disc(card, 18, { GOLD[1], GOLD[2], GOLD[3], 0 }, "ARTWORK", 4)
    s.pulse:SetBlendMode("ADD")
    s.pulse:SetPoint("CENTER", s.ring, "CENTER")
    card.stops[i] = s
    return s
end

local fade = { alpha = 0, want = 0 }
local armedUntil = 0
local shownPassed = 0

local function Draw(elapsed)
    if not (card and flight) then return end
    local T = ns.FishingToast
    local plan = flight.plan
    -- (the time left as seen in flight: the plan, corrected by how fast the way shrinks)
    local elapsed = Now() - flight.start
    local live, span = C.LiveLeft(flight.samples)
    local left, guess = C.Left(plan, elapsed, live, span)
    local frac, _, passed = C.Progress(plan, elapsed, left)
    -- (a stop passed: its dot fills, a soft gold breath on it)
    if passed > shownPassed then
        for i = shownPassed + 1, passed do local s = Stop(i); s.flash = 1 end
        shownPassed = passed
    end
    local n = #plan.marks
    for i = 1, math.max(n, #card.stops) do
        local s = i <= n and Stop(i) or card.stops[i]
        if i <= n then
            local x = LINE_X + LINE_W * plan.marks[i]
            s.ring:ClearAllPoints()
            s.ring:SetPoint("CENTER", card, "TOPLEFT", x, LINE_Y)
            s.ring:Show()
            s.hole:SetShown(i > passed and i < n)
            s.ring:SetSize(i == n and 11 or 9, i == n and 11 or 9)
            s.flash = math.max(0, (s.flash or 0) - (elapsed or 0) * 1.2)
            s.pulse:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.6 * s.flash)
            s.pulse:Show()
        elseif s then
            s.ring:Hide(); s.hole:Hide(); s.pulse:Hide()
        end
    end
    -- the bead: along the line, a slow breath and a faint drift up and down
    local t = Now()
    local x = LINE_X + LINE_W * frac
    card.flown:SetWidth(math.max(1, LINE_W * frac))
    card.beadRing:ClearAllPoints()
    card.beadRing:SetPoint("CENTER", card, "TOPLEFT", x, LINE_Y + math.sin(t * 2.1) * 0.8)
    local breath = 0.5 + 0.5 * math.sin(t * 2.6)
    card.glow:SetSize(14 + 6 * breath, 14 + 6 * breath)
    card.glow:SetAlpha(0.25 + 0.25 * breath)
    card.clock:SetText(C.Clock(left, guess))
    -- B: the next stop, or ask again
    local stop = not flight.landing and C.NextStop(plan, passed)
    local glyph = ns.ControllerModel and ns.ControllerModel.Glyph and ns.ControllerModel.Glyph("Shp_Circle", 13) or "B"
    if stop and type(TaxiRequestEarlyLanding) == "function" then
        local place = ns.FlightList.SplitName(plan.hops[stop].to)
        if Now() < armedUntil then
            card.land:SetText(glyph .. "  again: land at " .. place)
            card.land:SetTextColor(T.RUBRIC[1], T.RUBRIC[2], T.RUBRIC[3])
        else
            card.land:SetText(glyph .. "  Land at " .. place)
            card.land:SetTextColor(T.INK_FADED[1], T.INK_FADED[2], T.INK_FADED[3])
        end
    elseif flight.landing then
        card.land:SetText("Landing at " .. ns.FlightList.SplitName(flight.landing))
        card.land:SetTextColor(T.INK_FADED[1], T.INK_FADED[2], T.INK_FADED[3])
    else
        card.land:SetText(#plan.marks > 1 and (#plan.marks - 1 .. (#plan.marks == 2 and " stop" or " stops")) or "Direct")
        card.land:SetTextColor(T.INK_FADED[1], T.INK_FADED[2], T.INK_FADED[3])
    end
end

local function Fill()
    if not card then card = Build() end
    if not (card and flight) then return end
    local FL = ns.FlightList
    local place, zone = FL.SplitName(flight.to)
    ns.FishingToast.SetKicker(card, (FL.ZoneName(zone) or "In flight"):upper(), W - M)
    card.title:SetText(place)
    shownPassed = select(3, C.Progress(flight.plan, Now() - flight.start))
    Draw(0)
end

-- B: lands at the next stop (two presses) ---------------------------------------------
local landButton = CreateFrame("Button", LAND_BUTTON, UIParent)
landButton:RegisterForClicks("AnyDown")
landButton:SetScript("OnClick", function()
    if not (flight and OnTaxi()) then return end
    local _, _, passed = C.Progress(flight.plan, Now() - flight.start)
    local stop = C.NextStop(flight.plan, passed)
    if not stop then return end
    if Now() < armedUntil then
        armedUntil = 0
        flight.landing = flight.plan.hops[stop].to
        Call(TaxiRequestEarlyLanding)
    else
        armedUntil = Now() + 3
    end
    Draw(0)
end)

local binds = CreateFrame("Frame", "GamepadCompanionFlightCardBinds", UIParent, "SecureHandlerStateTemplate")
binds:SetAttribute("_onstate-fight", [[ if newstate == "on" then self:ClearBindings() end self:CallMethod("Fight", newstate) ]])
local bound, landOn = {}, false
local function BHeld() return Sh.PadDown(Sh.PadButtons(), LAND_KEY) end
local settle = Sh.Settler(BHeld, function() return C.GRACE end, Now)
C.GRACE = 0.25

-- B ours while on a taxi with a stop ahead, out of combat; true when done
function C.Bind()
    if InCombat() then return false end
    local want = false
    if flight and OnTaxi() and C.Enabled() and type(TaxiRequestEarlyLanding) == "function" then
        local _, _, passed = C.Progress(flight.plan, Now() - flight.start)
        want = C.NextStop(flight.plan, passed) ~= nil and not flight.landing
    end
    if want == landOn then return true end
    if not settle.Settled() then return false end
    settle.Reset()
    ClearOverrideBindings(binds)
    for k in pairs(bound) do bound[k] = nil end
    if want then
        SetOverrideBindingClick(binds, true, LAND_KEY, LAND_BUTTON, "LeftButton")
        bound[LAND_KEY] = "CLICK " .. LAND_BUTTON .. ":LeftButton"
    end
    landOn = want
    return true
end
function binds:Fight(newstate) if newstate == "on" then landOn = false; for k in pairs(bound) do bound[k] = nil end end end
if RegisterStateDriver then RegisterStateDriver(binds, "fight", "[combat] on; off") end
if Sh.Claim then Sh.Claim(bound, function() if not InCombat() then landOn = false; C.Bind() end end) end

-- Taking off, flying, landing -------------------------------------------------------------
local function Save()
    Sh.CharDB().flightNow = flight and { from = flight.from, to = flight.to, hops = flight.plan.hops, wall = flight.wall, dest = flight.dest } or nil
end

local function Pace() return tonumber(Sh.CharDB().flightPace) end

-- (once a second in flight: the straight distance left)
local sampleIn = 0
local function Sample(elapsed)
    sampleIn = sampleIn - elapsed
    if sampleIn > 0 or not (flight and flight.dest) then return end
    sampleIn = C.SAMPLE
    local here = Here()
    local FL = ns.FlightList
    if not (here and FL.SameContinent(here, flight.dest)) then return end
    local dx, dy = here.x - flight.dest.x, here.y - flight.dest.y
    local s = flight.samples
    s[#s + 1] = { t = Now(), d = math.sqrt(dx * dx + dy * dy) }
    if #s > C.KEEP then table.remove(s, 1) end
end

local function TakeOff()
    local p = pending
    pending = nil
    flight = { from = p.from, to = p.to, start = Now(), wall = Wall(), plan = C.Plan(p.hops, C.Times(), Pace()),
        dest = p.dest, samples = {} }
    sampleIn = 0
    armedUntil, shownPassed = 0, 0
    Save()
    Fill()
    fade.want = 1
end

local function Land()
    if not flight then return end
    local took = Now() - flight.start
    local times = C.Times()
    -- (a time worth keeping: a whole flight, or to the stop it set down at)
    if flight.landing then C.Learn(times, C.Key(flight.from, flight.landing), took)
    elseif not flight.resumed then
        C.Learn(times, C.Key(flight.from, flight.to), took)
        -- (and the pace, for the routes not flown yet)
        C.LearnPace(Sh.CharDB(), took, Length(flight.plan.hops))
    end
    flight = nil
    Save()
    fade.want = 0
end

if type(hooksecurefunc) == "function" and type(TakeTaxiNode) == "function" then
    hooksecurefunc("TakeTaxiNode", function(index)
        local hops, dest = Route(index)
        if not hops then return end
        pending = { from = hops[1].from, to = hops[#hops].to, hops = hops, dest = dest, at = Now() }
    end)
end

-- (a /reload in the air: the flight goes on from what was saved)
local function Resume()
    local saved = Sh.CharDB().flightNow
    if not (type(saved) == "table" and type(saved.hops) == "table" and #saved.hops > 0) then return end
    if not OnTaxi() then Sh.CharDB().flightNow = nil; return end
    local since = math.max(0, Wall() - (saved.wall or Wall()))
    flight = { from = saved.from, to = saved.to, wall = saved.wall, start = Now() - since,
        plan = C.Plan(saved.hops, C.Times(), Pace()), resumed = true, dest = saved.dest, samples = {} }
    sampleIn = 0
    Fill()
    fade.want = 1
end

local driver = CreateFrame("Frame")
local tick = 0
-- (each frame: takeoff and landing every fifth of a second, the card's fade and motion)
function C.Tick(elapsed)
    tick = tick + elapsed
    if tick >= 0.2 then
        tick = 0
        local on = OnTaxi()
        if pending and on and not flight then TakeOff()
        elseif pending and Now() - pending.at > 15 then pending = nil end
        if flight and not on then Land() end
        C.Bind()
    end
    if flight then Sample(elapsed) end
    -- the fade, and the card's motion while shown
    if card then
        local target = (fade.want == 1 and C.Enabled()) and 1 or 0
        fade.alpha = fade.alpha + (target - fade.alpha) * math.min(1, elapsed * 3)
        if target == 0 and fade.alpha < 0.02 then fade.alpha = 0; card:Hide()
        else card:Show() end
        card:SetAlpha(fade.alpha)
        if flight and card:IsShown() then Draw(elapsed) end
    end
end
driver:SetScript("OnUpdate", function(_, elapsed) C.Tick(elapsed) end)

local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function() if not flight then Resume() end end)

function C.SetEnabled(on)
    Sh.CharDB().flightCard = on and true or false
end
