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

-- The clock: from the move's start, hoof by hoof
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
    -- (walk: its cycle starts now)
    i = L.RideHoof(horse.walk, v, v.at, 2.5, 10)
    check(v.phase == 0 and v.gait == horse.walk, "to a walk: its cycle starts")
    -- (before the start: nothing)
    check(L.RideHoof(g, {}, 9.9, 14, 10) == nil, "before the move: no hoof")
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
