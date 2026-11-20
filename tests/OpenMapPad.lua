-- OpenMap on the gamepad map: OpenMap's own controller view turned on once,
-- a later "off" kept, and what a map opening showed.
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

-- Turned on once, when OpenMap's setting is off
local store, db = {}, { worldmap = { padView = false, enabled = true } }
eq(O.TurnOn(store, db, 100), true, "off: turned on")
eq(db.worldmap.padView, true, "OpenMap's switch on")
eq(store.openMap.padViewOn, 100, "remembered")

-- The user turns it off in OpenMap's menu: kept
db.worldmap.padView = false
eq(O.TurnOn(store, db, 200), false, "not again")
eq(db.worldmap.padView, false, "user's off kept")

-- Already on: nothing written, but done (a later off kept)
store, db = {}, { worldmap = { padView = true } }
eq(O.TurnOn(store, db, 5), false, "already on: nothing to do")
eq(store.openMap.padViewOn, 5, "already on: done")
db.worldmap.padView = false
eq(O.TurnOn(store, db, 6), false, "already on, then off: kept")
eq(db.worldmap.padView, false, "off stays")

-- OpenMap not loaded, or its settings not there yet: wait, not done
store = {}
eq(O.TurnOn(store, nil, 1), false, "no OpenMap")
eq(store.openMap.padViewOn, nil, "no OpenMap: not done")
eq(O.TurnOn(store, {}, 1), false, "no settings yet")
eq(store.openMap.padViewOn, nil, "no settings: not done")
db = { worldmap = { padView = false } }
eq(O.TurnOn(store, db, 2), true, "settings later: turned on")

-- Other OpenMap settings untouched
store, db = {}, { worldmap = { padView = false, padMap = false, zoom = 3 } }
O.TurnOn(store, db, 1)
eq(db.worldmap.padMap, false, "padMap untouched")
eq(db.worldmap.zoom, 3, "zoom untouched")

-- What a map opening showed
store = {}
eq(O.Seen(store, true, 0, true, 10), true, "pad, see-through canvas: OpenMap's view")
eq(store.openMap.seen.view, true, "seen: view")
eq(store.openMap.opens, 1, "one opening")
eq(O.Seen(store, true, 1, false, 11), false, "pad, canvas shown: Blizzard's map")
eq(store.openMap.seen.padView, false, "seen: switch off")
eq(O.Seen(store, false, 0, true, 12), false, "mouse mode: not the pad view")
eq(store.openMap.seen.padUI, false, "seen: no Gamepad UI")
eq(O.Seen(store, true, nil, true, 13), false, "no canvas: not the view")
eq(store.openMap.opens, 4, "four openings")
eq(store.openMap.seen.at, 13, "latest kept")

io.write(("OpenMapPad: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
