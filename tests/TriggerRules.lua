-- lua5.1 tests/TriggerRules.lua .   (from the addon folder)
local root = arg and arg[1] or "."
local ns = {}
assert(loadfile(root .. "/TriggerRules.lua"))("GamepadCompanion", ns)
local T = ns.TriggerRules

local n, failed = 0, 0
local function check(ok, what)
    n = n + 1
    if not ok then failed = failed + 1; print("FAIL " .. what) end
end

-- Recommended: the three the addon always had, same bytes as before
local store = {}
local list = T.Ensure(store, {})
check(#list == 3 and store.v == 1, "three default rules")
check(T.Label(list[1]) == "Casting · R2 · Resist", "cast rule: " .. T.Label(list[1]))
check(T.Label(list[2]) == "Auto shot · R2 · Click", "shot rule")
check(T.Label(list[3]) == "Low health · L2 · Pulse", "low rule")

local out = T.Evaluate(list, { cast = true, progress = 0 })
check(out.R2[1] == "resist" and out.R2[2] == 3 and out.R2[4] == 2, "cast at its start: resist from 3, force 2")
out = T.Evaluate(list, { cast = true, progress = 1 })
check(out.R2[4] == 13, "cast at its end: force 13 (2 + p * 11, as before)")
out = T.Evaluate(list, { cast = true, progress = 0.5, autoShot = true })
check(out.R2[4] == 7, "half cast: 2 + floor(5.5)")
out = T.Evaluate(list, { autoShot = true })
check(out.R2[1] == "weapon" and out.R2[2] == 4 and out.R2[3] == 8 and out.R2[4] == 7, "auto shot: weapon 4, 8, 7")
check(out.L2 == nil, "L2 free")
out = T.Evaluate(list, { lowHp = true })
check(out.L2[1] == "vibrate" and out.L2[2] == 0 and out.L2[3] == 5 and out.L2[4] == 3, "low health: vibrate 0, 5, 3")
out = T.Evaluate(list, {})
check(out.R2 == nil and out.L2 == nil, "nothing holds: both free")

-- old switches carry over once
local old = {}
local l2 = T.Ensure(old, { castTrigger = false, lowTrigger = true })
check(l2[1].on == false and l2[2].on == true and l2[3].on == true, "old switches carried over")
l2[1].on = true
T.Ensure(old, { castTrigger = false })
check(old.list[1].on == true, "seeded once, never again")

-- seeded in place (a profile's table)
local profileTable = {}
local same = profileTable
T.Ensure(profileTable, nil)
check(same.list ~= nil and same == profileTable, "in place")

-- priority: the first rule that holds
local mine = { T.Clean({ when = "combat", side = "both", effect = "wall", from = 9 }), T.Clean({ when = "cast", side = "R2", effect = "resist", strength = 4 }) }
out = T.Evaluate(mine, { combat = true, cast = true, progress = 0.3 })
check(out.R2[1] == "resist" and out.R2[2] == 9 and out.R2[4] == 15 and out.L2[4] == 15, "wall wins both, full force")
mine[1].on = false
out = T.Evaluate(mine, { combat = true, cast = true })
check(out.R2[4] == 4 and out.L2 == nil, "a rule switched off is skipped")

-- always, and Try first
out = T.Evaluate({ T.Clean({ when = "always", side = "L2", effect = "section", from = 2, to = 10, strength = 5 }) }, {})
check(out.L2[1] == "section" and out.L2[2] == 2 and out.L2[3] == 10 and out.L2[4] == 5, "always: a zone")
out = T.Evaluate(list, { autoShot = true }, { when = "mounted", side = "R2", effect = "slope", from = 1, to = 12, strength = 9 })
check(out.R2[1] == "slope" and out.R2[3] == 12, "Try wins over the list")

-- clean: never trusted
local r = T.Clean({ when = "nope", side = 7, effect = "x", from = 99, to = -3, strength = 0, speed = 40, grow = "yes" })
check(r.when == "cast" and r.side == "R2" and r.effect == "resist" and r.from == 15 and r.to == 0 and r.strength == 1
    and r.speed == 15 and r.grow == false, "clean")
out = T.Evaluate({ T.Clean({ when = "always", effect = "weapon", from = 9, to = 3 }) }, {})
check(out.R2[3] == 9, "zone end never before its start")
local cap = { v = 1, list = {} }
for i = 1, 9 do cap.list[i] = { when = "always" } end
check(#T.Ensure(cap) == T.MAX, "six at most")
check(T.Hz(7) == "30 Hz" and T.Pct(15) == "100%" and T.Pct(0) == "0%", "formats")

print(string.format("TriggerRules: %s (%d checks)", failed == 0 and "ok" or (failed .. " failed"), n))
os.exit(failed == 0 and 0 or 1)
