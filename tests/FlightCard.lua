-- The flight card's timing: a route's time learned or guessed from its length, the way's
-- stops as fractions, progress, the next stop to land at, the clock.
-- lua5.1 tests/FlightCard.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end
local function near(a, b, label) check(math.abs((a or 0) - b) < 0.001, label .. " (got " .. tostring(a) .. ", want " .. b .. ")") end

local realSettler
do
    local shared = {}
    hooksecurefunc = function() end
    assert(loadfile(root .. "/Shared.lua"))("GamepadCompanion", shared)
    hooksecurefunc = nil
    realSettler = shared.Shared.Settler
end
CreateFrame = nil
local db = {}
local ns = { Shared = { CharDB = function() return db end } }
assert(loadfile(root .. "/FlightCard.lua"))("GamepadCompanion", ns)
local C = ns.FlightCard

local A, B, X = "Splintertree Post, Ashenvale", "Crossroads, The Barrens", "Camp Taurajo, The Barrens"
eq(C.Key(A, B), A .. " > " .. B, "a route's key")

-- a first flight: guessed from the length
local direct = { { from = A, to = B, len = 1500 } }
local plan = C.Plan(direct, {})
eq(plan.guess, true, "never flown: a guess")
near(plan.total, 1500 * C.BEND / C.SPEED + C.TAKEOFF, "length at taxi speed, plus rising and setting down")
eq(#plan.marks, 1, "direct: one mark, the end")
near(plan.marks[1], 1, "the end at the end")
-- learned
local times = {}
eq(C.Learn(times, C.Key(A, B), 70.4), true, "a flight's time kept")
eq(times[C.Key(A, B)], 70, "rounded")
C.Learn(times, C.Key(A, B), 80)
eq(times[C.Key(A, B)], 75, "then the mean with the last")
eq(C.Learn(times, C.Key(A, B), 2), false, "a blink: not a flight")
eq(C.Learn(times, C.Key(A, B), 7200), false, "hours: not a flight")
plan = C.Plan(direct, times)
eq(plan.guess, false, "flown before: no guess")
eq(plan.total, 75, "its learned time")

-- stops on the way
local two = { { from = A, to = B, len = 1500 }, { from = B, to = X, len = 900 } }
plan = C.Plan(two, {})
eq(plan.guess, true, "unknown hops: a guess")
eq(#plan.marks, 2, "a mark per hop's end")
near(plan.marks[1], 1500 / 2400, "the stop where its share of the way ends")
near(plan.total, 2400 * C.BEND / C.SPEED + C.TAKEOFF, "the hops added, one takeoff")
plan = C.Plan(two, { [C.Key(A, B)] = 60 })
eq(plan.guess, true, "one hop known, one not: still a guess")
plan = C.Plan(two, { [C.Key(A, X)] = 200, [C.Key(A, B)] = 75 })
eq(plan.guess, false, "the whole route flown: its time")
eq(plan.total, 200, "the route's own time wins over the hops'")
plan = C.Plan({ { from = A, to = B }, { from = B, to = X } }, {})
near(plan.marks[1], 0.5, "no lengths: even shares")

-- progress
plan = C.Plan(two, { [C.Key(A, B)] = 60, [C.Key(B, X)] = 40 })
eq(plan.total, 100, "hops known: their sum")
local frac, left, passed = C.Progress(plan, 30)
near(frac, 0.3, "30 s of 100")
eq(left, 70, "70 s left")
eq(passed, 0, "the stop still ahead")
eq(C.NextStop(plan, passed), 1, "B lands at the first stop")
frac, left, passed = C.Progress(plan, 65)
eq(passed, 1, "past the stop at 60 s")
eq(C.NextStop(plan, passed), nil, "no stop left before the end")
frac, left = C.Progress(plan, 130)
eq(frac, 1, "late: at the end, no further")
eq(left, 0, "nothing left, never below")
eq(C.NextStop(C.Plan(direct, {}), 0), nil, "direct: nowhere to land on the way")

-- seen in flight (a guess ran out with Tarren Mill ahead, "~0:00", 2026-11-22)
do
    eq(C.LiveLeft({}), nil, "no samples: nothing seen")
    local s = {}
    for t = 0, 4 do s[#s + 1] = { t = t, d = 3000 - 20 * t } end
    eq(C.LiveLeft(s), nil, "4 s seen: too soon to say")
    s = {}
    for t = 0, 40 do s[#s + 1] = { t = t, d = 3000 - 20 * t } end
    local live, span = C.LiveLeft(s)
    near(live, 2200 / 20, "20 yd/s closing in, 2200 yd left: 110 s")
    eq(span, C.WINDOW, "read over the last 20 s")
    s = {}
    for t = 0, 20 do s[#s + 1] = { t = t, d = 3000 + t } end
    eq(C.LiveLeft(s), nil, "the way turns away for now: no say")
    -- a guess runs out in the air: what's seen takes over
    local g = C.Plan(direct, {})
    local left, guess = C.Left(g, g.total + 30, 95, 20)
    eq(left, 95, "the guess ran out: the time seen")
    eq(guess, true, "still a guess (~)")
    -- a guess gives way as the samples build
    left = C.Left({ total = 100, guess = true }, 40, 120, 15)
    near(left, 0.5 * 120 + 0.5 * 60, "half trusted at 15 s")
    left = C.Left({ total = 100, guess = true }, 40, 120, 45)
    eq(left, 120, "fully trusted from 30 s")
    -- a learned route holds, unless it ran out
    left, guess = C.Left({ total = 100, guess = false }, 40, 120, 45)
    eq(left, 60, "learned: its time")
    eq(guess, false, "no ~")
    left = C.Left({ total = 100, guess = false }, 110, 25, 20)
    eq(left, 25, "learned but slower today: the time seen")
    eq((C.Left({ total = 100, guess = true }, 40)), 60, "nothing seen: the plan")
    -- progress against the time seen
    local frac = C.Progress({ total = 100, marks = { 1 } }, 60, 60)
    near(frac, 0.5, "60 s flown, 60 left: halfway")
    -- the pace, learned from whole flights, guesses the next routes
    local d = {}
    eq(C.LearnPace(d, 452, 9000), true, "a whole flight teaches the pace")
    near(d.flightPace, (452 - C.TAKEOFF) / 9000, "s per straight yard, after rising and setting down")
    eq(C.LearnPace(d, 452, nil), false, "a hop of unknown length: nothing")
    eq(C.LearnPace(d, 452, 100), false, "too short to say")
    eq(C.LearnPace(d, 30, 9000), false, "300 yd/s: not a flight")
    local p = C.Plan(direct, {}, 0.06)
    near(p.total, 1500 * 0.06 + C.TAKEOFF, "a new route at the learned pace")
end

-- the clock
eq(C.Clock(125), "2:05", "minutes and seconds")
eq(C.Clock(125, true), "~2:05", "a guess")
eq(C.Clock(-3), "0:00", "never negative")
eq(C.Clock(59.6), "1:00", "rounded")

-- settings, times per character
eq(C.Enabled(), true, "on by default")
db.flightCard = false
eq(C.Enabled(), false, "off")
eq(type(C.Times()), "table", "times kept per character")
eq(db.flightTimes, C.Times(), "in flightTimes")

-- The game wiring: a flight picked, the taxi rising, a stop passed, B twice lands there ------------
do
    local clock, onTaxi, landed = 1000, false, 0
    local overrides, hooks, frames = {}, {}, {}
    local function Frame(name)
        local f = { scripts = {}, shown = false, name = name }
        return setmetatable(f, { __index = function(t, k)
            if k == "SetScript" then return function(_, a, b) t.scripts[a] = b end end
            if k == "Show" then return function() t.shown = true end end
            if k == "Hide" then return function() t.shown = false end end
            if k == "IsShown" then return function() return t.shown end end
            if k == "SetText" then return function(_, v) t.text = v end end
            if k:match("^Create") then return function() return Frame() end end
            return function() end
        end })
    end
    _G.CreateFrame = function(_, name) local f = Frame(name); if name then _G[name] = f; frames[name] = f end; return f end
    UIParent = Frame("UIParent")
    GetTime = function() return clock end
    time = function() return math.floor(clock) end
    InCombatLockdown = function() return false end
    UnitOnTaxi = function() return onTaxi end
    hooksecurefunc = function(name, fn) hooks[name] = fn end
    TakeTaxiNode = function() end
    TaxiRequestEarlyLanding = function() landed = landed + 1 end
    SetOverrideBindingClick = function(_, _, key, name) overrides[key] = name end
    ClearOverrideBindings = function() for k in pairs(overrides) do overrides[k] = nil end end
    RegisterStateDriver = function() end
    local names = { A, B, X }
    NumTaxiNodes = function() return 3 end
    TaxiNodeName = function(i) return names[i] end
    TaxiNodeGetType = function(i) return i == 1 and "CURRENT" or "REACHABLE" end
    GetNumRoutes = function() return 2 end
    TaxiGetNodeSlot = function(_, r, src) if src then return r end return r + 1 end
    local wdb = { flightTimes = { [C.Key(A, B)] = 60, [C.Key(B, X)] = 40 } }
    local padB = false
    local ns2 = { Shared = { CharDB = function() return wdb end, PadButtons = function() return {} end,
        PadDown = function() return padB end, Settler = realSettler, Claim = function() end },
        FlightList = { SplitName = function(n) return n:match("^(.-),%s*(.+)$") end, ZoneName = function(z) return z end,
            SameContinent = function() return true end },
        FishingToast = { Paper = function() end, Kicker = function() end, SetKicker = function() end,
            INK = { 0, 0, 0 }, INK_STRONG = { 0, 0, 0 }, INK_FADED = { 0, 0, 0 }, RUBRIC = { 1, 0, 0 }, PAPER = { 1, 1, 1 } } }
    assert(loadfile(root .. "/FlightCard.lua"))("GamepadCompanion", ns2)
    local W = ns2.FlightCard
    W.GRACE = 0
    check(hooks.TakeTaxiNode ~= nil, "takeoff read from TakeTaxiNode")
    hooks.TakeTaxiNode(3)
    onTaxi = true
    W.Tick(0.25)
    eq(wdb.flightNow and wdb.flightNow.to, X, "in the air: the flight kept (for a /reload)")
    eq(overrides.PAD2, "GamepadCompanionFlightLand", "B: land at the next stop")
    _G.GamepadCompanionFlightLand.scripts.OnClick()
    eq(landed, 0, "a first press only names the stop")
    clock = clock + 1
    _G.GamepadCompanionFlightLand.scripts.OnClick()
    eq(landed, 1, "a second within 3 s lands")
    W.Tick(0.25)
    eq(overrides.PAD2, nil, "landing asked: B the bars' again")
    clock = clock + 55
    onTaxi = false
    W.Tick(0.25)
    eq(wdb.flightNow, nil, "landed: no flight kept")
    eq(wdb.flightTimes[C.Key(A, B)], 58, "the time to the stop it set down at, learned (60 and 56)")
end

io.write(("FlightCard: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
