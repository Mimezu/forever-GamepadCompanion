-- The flight's passage: on a taxi, no card, a quiet line at the bottom left (Passage.lua, in the
-- lure float's manner): where you're going, the time left, and the way there as a line, a dot
-- per stop (passed ones filled), a gold bead gliding along it. The game gives no time left: each route's
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

-- The passage (Passage.lua): no card, a quiet line at the bottom left -----------------
local armedUntil = 0

local function Icon()
    local faction = Call(UnitFactionGroup, "player")
    return faction == "Horde" and "Interface\\Icons\\Ability_Mount_Wyvern_01" or "Interface\\Icons\\Ability_Mount_Gryphon_01"
end

-- What the passage shows now: the place, the time left, the way and its stops, B's word
function C.Spec()
    if not flight then return nil end
    local plan = flight.plan
    -- (the time left as seen in flight: the plan, corrected by how fast the way shrinks)
    local elapsed = Now() - flight.start
    local live, span = C.LiveLeft(flight.samples)
    local left, guess = C.Left(plan, elapsed, live, span)
    local frac, _, passed = C.Progress(plan, elapsed, left)
    local FL = ns.FlightList
    local s = { icon = Icon(), title = (FL.SplitName(flight.to)), clock = C.Clock(left, guess), frac = frac,
        marks = #plan.marks > 1 and plan.marks or nil, passed = passed, bob = true }
    -- B: the next stop, or ask again
    local stop = not flight.landing and C.NextStop(plan, passed)
    local glyph = ns.ControllerModel and ns.ControllerModel.Glyph and ns.ControllerModel.Glyph("Shp_Circle", 12) or "B"
    if stop and type(TaxiRequestEarlyLanding) == "function" then
        local place = FL.SplitName(plan.hops[stop].to)
        if Now() < armedUntil then s.sub, s.subLit = glyph .. "  again: land at " .. place, true
        else s.sub = glyph .. "  Land at " .. place end
    elseif flight.landing then
        s.sub = "Landing at " .. FL.SplitName(flight.landing)
    else
        s.sub = #plan.marks > 1 and (#plan.marks - 1 .. (#plan.marks == 2 and " stop" or " stops")) or "Direct"
    end
    return s
end

local function Draw()
    local P = ns.Passage
    if not (P and flight) then return end
    if C.Enabled() then
        if P.Owner() == "flight" then P.Update("flight", C.Spec()) else P.Show("flight", C.Spec()) end
    else
        P.Hide("flight")
    end
end
local function Fill() Draw() end

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
    Draw()
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
    armedUntil = 0
    Save()
    Fill()
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
    if ns.Passage then ns.Passage.Hide("flight") end
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
end

local driver = CreateFrame("Frame")
local tick = 0
-- (each frame: takeoff and landing every fifth of a second, the passage's words and way)
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
    if flight then Sample(elapsed); Draw() end
end
driver:SetScript("OnUpdate", function(_, elapsed) C.Tick(elapsed) end)

local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function() if not flight then Resume() end end)

function C.SetEnabled(on)
    Sh.CharDB().flightCard = on and true or false
end
