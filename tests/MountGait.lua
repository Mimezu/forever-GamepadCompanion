-- Riding: each mount's own gait from its model (MountGaits.lua), the hooves on the animation's
-- clock: its cycle at speed / its own, from the move's start; a new speed keeps the place.
-- lua5.1 tests/MountGait.lua <addon folder>
local root = arg[1] or "."
local T = dofile(root .. "/tests/support/ClassHarness.lua")
local L, ns = T.L, T.ns
local check = T.check
assert(loadfile(root .. "/MountGaits.lua"))("GamepadCompanion", ns)

local function near(a, b, msg) check(math.abs(a - b) < 1e-6, msg .. ": " .. tostring(a) .. " ~ " .. tostring(b)) end

-- The data: the brown horse, the wolf
local horse = ns.MountGaits.spells[458]
check(horse and horse.run[1] == 800 and horse.run[2] > 9 and #horse.run[3] == 4, "the horse's run: 800 ms at 9.03, four hooves")
check(#horse.run[4] == #horse.run[3], "a side for each hoof")
check(ns.MountGaits.spells[459] and ns.MountGaits.spells[459].run[1] == 734, "the wolf's own run")

-- The gait: walk under 4.5 yd/s, else run; an unknown mount runs as the horse
check(L.RideGait(458, 14) == horse.run and L.RideGait(458, 2.5) == horse.walk, "walk and run")
check(L.RideGait(nil, 14)[1] == 800 and L.RideGait(999999, 14)[3][1] == 134, "unknown: the horse")

-- The cycle: 0.8 s at 9.03 yd/s, so at 14 (a fast mount) 0.516 s, at 11.2 0.645 s
near(L.RideCycle(horse.run, 9.03), 0.8, "at its own speed")
near(L.RideCycle(horse.run, 14), 0.8 * 9.03 / 14, "at 14 yd/s")
near(L.RideCycle({ 734, 0, { 67 }, "L" }, 14), 0.734, "move speed 0: not scaled")

-- The heavy hoof: after the longest flight (horse: 500 -> 934, the hoof at 134)
check(L.RideHeavy(horse.run) == 1, "the horse's heavy hoof: the first")
check(L.RideHeavy({ 1000, 7, { 200, 300, 900 }, "LRL" }) == 3, "the hoof after the 600 ms gap")

-- The clock: from the move's start, hoof by hoof (as heard at once: offset 0, the model's pace)
local sigH = "800@9.03:134,234,334,500"
check(L.RideSig(horse.run) == sigH, "the gait's name, as WoW Helper's: " .. L.RideSig(horse.run))
WowHelperData = { rideTiming = { [sigH] = { pace = 1, offset = 0, strides = 50 } } }
do
    local g, v, speed = horse.run, {}, 14
    local cycle = L.RideCycle(g, speed)
    local at = function(ms) return 10 + ms / 800 * cycle end
    local i, d = L.RideHoof(g, v, at(140), speed, 10)
    check(i == 1 and math.abs(d - 6 / 800 * cycle) < 1e-9, "the first hoof, 6 ms on: " .. tostring(i))
    i = L.RideHoof(g, v, at(240), speed, 10)
    check(i == 2, "the second")
    i = L.RideHoof(g, v, at(510), speed, 10)
    check(i == 4, "the fourth")
    i, d = L.RideHoof(g, v, at(800 + 100), speed, 10)
    check(i == 4 and d > 0, "before the next cycle's first: still the fourth")
    i = L.RideHoof(g, v, at(800 + 134), speed, 10)
    check(i == 1, "the next cycle's first")
    -- (a new speed: the same place, a new pace)
    local before = v.phase
    i = L.RideHoof(g, v, v.at, 7, 10)
    near(v.phase, before, "a new speed keeps the place")
    -- (walk: its cycle starts now, heard its offset later: the model's sound path, unlearned)
    i = L.RideHoof(horse.walk, v, v.at, 2.5, 10)
    near(v.phase, -L.RIDE_HEARD / L.RideCycle(horse.walk, 2.5), "to a walk: its cycle starts")
    check(v.gait == horse.walk and i == nil, "its first hoof still to come")
    -- (before the start: nothing)
    check(L.RideHoof(g, {}, 9.9, 14, 10) == nil, "before the move: no hoof")
end

-- What WoW Helper heard: the hooves 10 % slower and 200 ms after the model's
do
    WowHelperData.rideTiming[sigH] = { pace = 1.1, offset = 0.2, strides = 80 }
    local g, v = horse.run, {}
    local cycle = L.RideCycle(g, 14) * 1.1
    local i, d = L.RideHoof(g, v, 10 + 0.2 + 140 / 800 * cycle, 14, 10)
    check(i == 1 and math.abs(d - 6 / 800 * cycle) < 1e-9, "learned: the first hoof where it is heard")
    local p, o, learned = L.RideTiming(horse.walk)
    check(p == 1 and o == L.RIDE_HEARD and not learned, "an unlearned gait: the model's, after the sound path")
    WowHelperData.rideTiming[sigH] = { pace = 7, offset = 0 }
    check(L.RideTiming(g) == 1, "a pace out of reason is not taken")
    -- (learned at the speed ridden: that speed's own, others the gait's)
    WowHelperData.rideTiming[sigH] = { pace = 1.1, offset = 0.2 }
    WowHelperData.rideTiming[sigH .. "|12.5"] = { pace = 0.85, offset = 0.05 }
    check(L.RideTiming(g, 12.25) == 0.85, "12.25 yd/s: its own pace")
    check(L.RideTiming(g, 7) == 1.1, "another speed: the gait's")
    WowHelperData = nil
end

-- The ride markers: the gait's place, when the ride began, its speed; a stop
do
    local sent = {}
    local K = ns.HelperLink
    local saved = { K.Marker, K.Enabled, K.V2 }
    K.Marker = function(m) sent[#sent + 1] = m; return true end
    K.Enabled, K.V2 = function() return true end, function() return true end
    check(L.RidePlace(458) == 1 and L.RidePlace(459) == 2 and L.RidePlace(nil) == nil, "a mount's place")
    local auras = { { spellId = 459 } }
    C_UnitAuras = { GetAuraDataByIndex = function(_, i) return auras[i] end }
    T.Event("PLAYER_STARTED_MOVING")
    local t0 = T.Now()
    L.RideMarkers(t0 + 0.3, true, 14)
    local m = sent[1]
    check(m and m.moment == 96 and m.touch == 514 and m.sound == 1400 and m.seed == 30, "a run on the wolf, 300 ms in")
    L.RideMarkers(t0 + 0.4, true, 14)
    check(#sent == 1, "the same ride: nothing new")
    L.RideMarkers(t0 + 0.5, true, 11.2)
    check(#sent == 2 and sent[2].seed >= 128 and sent[2].sound == 1120, "a new speed: the same ride")
    L.RideMarkers(t0 + 0.5 + L.RIDE_KEEP, true, 11.2)
    check(#sent == 3 and sent[3].seed >= 128, "a keepalive")
    L.RideMarkers(t0 + 12, true, 2.5)
    check(#sent == 4 and sent[4].moment == 97 and sent[4].seed == 0, "to a walk: a new gait from now")
    L.RideMarkers(t0 + 13, false, 0)
    check(#sent == 5 and sent[5].moment == 98 and sent[5].touch == 512, "a stop")
    C_UnitAuras = nil
    K.Marker, K.Enabled, K.V2 = saved[1], saved[2], saved[3]
end

-- The mount: read from the player's auras
do
    local auras = { { spellId = 21562 }, { spellId = 458 } }
    C_UnitAuras = { GetAuraDataByIndex = function(_, i) return auras[i] end }
    check(L.MountSpell() == 458, "the horse among the buffs")
    auras = { { spellId = 21562 } }
    check(L.MountSpell() == nil, "no mount buff: none")
    C_UnitAuras = nil
end

if T.failures > 0 then
    io.write(T.failures .. " of " .. T.checks .. " checks failed" .. string.char(10))
    os.exit(1)
end
io.write("PASS: mount gait: " .. T.checks .. " checks (each mount's own cycle and hooves, the clock, the mount from its buff)" .. string.char(10))
