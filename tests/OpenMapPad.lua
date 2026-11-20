-- OpenMap on the gamepad map, undone: OpenMap's controller view turned back off
-- once where Companion turned it on, then OpenMap's own choice kept.
-- lua5.1 tests/OpenMapPad.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

CreateFrame = nil   -- (the logic only: no game wiring)
local ns = {}
assert(loadfile(root .. "/OpenMapPad.lua"))("GamepadCompanion", ns)
local O = ns.OpenMapPad

-- Companion turned it on: turned off once
local store = { openMap = { padViewOn = 100, seen = { at = 1 }, opens = 3 } }
local db = { worldmap = { padView = true, zoom = 3 } }
eq(O.GiveBack(store, db), true, "turned off")
eq(db.worldmap.padView, false, "OpenMap's switch off")
eq(db.worldmap.zoom, 3, "other settings untouched")
eq(store.openMap.seen, nil, "old notes dropped")

-- Turned on again in OpenMap's menu: kept
db.worldmap.padView = true
eq(O.GiveBack(store, db), false, "not again")
eq(db.worldmap.padView, true, "user's on kept")

-- Never turned on by Companion: untouched
store, db = {}, { worldmap = { padView = true } }
eq(O.GiveBack(store, db), false, "not ours")
eq(db.worldmap.padView, true, "not ours: kept")

-- OpenMap's settings not there yet: wait
store = { openMap = { padViewOn = 1 } }
eq(O.GiveBack(store, nil), false, "no OpenMap")
eq(store.openMap.padViewBack, nil, "no OpenMap: not done")
db = { worldmap = { padView = true } }
eq(O.GiveBack(store, db), true, "settings later: turned off")

io.write(("OpenMapPad: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
