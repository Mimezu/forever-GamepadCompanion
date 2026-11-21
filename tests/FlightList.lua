-- Flight list: the places you can fly to from a flight master, read from the
-- map's nodes, sorted, costed in coins; the row moves, pages, scrolls; the
-- last place flown to from here is where the list starts.
-- lua5.1 tests/FlightList.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

CreateFrame = nil   -- (the logic only: no game wiring)
local db = {}
local ns = { Shared = { CharDB = function() return db end } }
assert(loadfile(root .. "/FlightList.lua"))("GamepadCompanion", ns)
local FL = ns.FlightList

-- Names ------------------------------------------------------------------------
local place, zone = FL.SplitName("Ironforge, Dun Morogh")
eq(place, "Ironforge", "place")
eq(zone, "Dun Morogh", "zone")
place, zone = FL.SplitName("Booty Bay, Stranglethorn Vale")
eq(zone, "Stranglethorn Vale", "zone with spaces")
place, zone = FL.SplitName("Rut'theran Village")
eq(place, "Rut'theran Village", "no comma: the name")
eq(zone, nil, "no comma: no zone")
eq((FL.SplitName(nil)), "", "no name")

-- Reading the map ------------------------------------------------------------------
local nodes = {
    { "Ironforge, Dun Morogh", "CURRENT", 0, 0.50, 0.50, 0 },
    { "Thelsamar, Loch Modan", "REACHABLE", 120, 0.60, 0.50, 1 },
    { "Stormwind, Elwynn", "REACHABLE", 450, 0.40, 0.80, 1 },
    { "Booty Bay, Stranglethorn", "REACHABLE", 12345, 0.40, 0.10, 3 },
    { "Hidden, Nowhere", "NONE", 0, 0, 0, 0 },
    { "Far, Away", "DISTANT", 0, 0.9, 0.9, 0 },
    { "Sentinel Hill, Westfall", "REACHABLE", 300, 0.45, 0.50, 2 },
}
local api = {
    count = #nodes,
    name = function(i) return nodes[i][1] end,
    type = function(i) return nodes[i][2] end,
    cost = function(i) return nodes[i][3] end,
    pos = function(i) return nodes[i][4], nodes[i][5] end,
    hops = function(i) return nodes[i][6] end,
}
local here, list = FL.Read(api)
eq(here and here.place, "Ironforge", "here: the current node")
eq(here and here.index, 1, "here's index")
eq(#list, 4, "reachable only (not here, none, distant)")
eq(list[1].place, "Thelsamar", "map order before sorting")
eq(list[3].hops, 3, "hops kept")
eq(list[1].cost, 120, "cost")

-- nearest first
FL.Sort(list, "near")
eq(list[1].place, "Sentinel Hill", "nearest first")
eq(list[2].place, "Thelsamar", "then the next")
eq(list[3].place, "Stormwind", "0.3 away")
eq(list[4].place, "Booty Bay", "farthest last")
-- A-Z
FL.Sort(list, "name")
eq(list[1].place, "Booty Bay", "A-Z first")
eq(list[4].place, "Thelsamar", "A-Z last")
eq(FL.SORTS.near, "name", "Y: near to name")
eq(FL.SORTS.name, "near", "Y: name to near")

-- equal distance: by name
local eqList = {
    { index = 2, place = "b", dist = 1 }, { index = 1, place = "a", dist = 1 }, { index = 3, place = "c", dist = 0.5 } }
FL.Sort(eqList, "near")
eq(eqList[1].place .. eqList[2].place .. eqList[3].place, "cab", "ties by name")

-- no current node: still a list
nodes[1][2] = "REACHABLE"
here, list = FL.Read(api)
eq(here, nil, "no here")
eq(#list, 5, "all reachable")
eq(list[1].dist, 0, "no distance without here")
nodes[1][2] = "CURRENT"

-- empty map
here, list = FL.Read({ count = 0, name = api.name, type = api.type, cost = api.cost, pos = api.pos })
eq(#list, 0, "nothing")

-- Coins ------------------------------------------------------------------------------
local G = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local S = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local C = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
eq(FL.Coins(12345), "1" .. G .. "  23" .. S .. "  45" .. C, "gold silver copper")
eq(FL.Coins(120), "1" .. S .. "  20" .. C, "no gold")
eq(FL.Coins(10000), "1" .. G, "gold only")
eq(FL.Coins(5), "5" .. C, "copper only")
eq(FL.Coins(0), "", "free")
eq(FL.Coins(nil), "", "unknown")

-- Moving -------------------------------------------------------------------------------
eq(FL.Step(1, 5, 1, true), 2, "down")
eq(FL.Step(5, 5, 1, true), 1, "down wraps")
eq(FL.Step(1, 5, -1, true), 5, "up wraps")
eq(FL.Step(5, 5, 1, false), 5, "held: stops at the end")
eq(FL.Step(1, 5, -1, false), 1, "held: stops at the top")
eq(FL.Step(2, 20, 9, false), 11, "a page down")
eq(FL.Step(15, 20, 9, false), 20, "a page down: the end")
eq(FL.Step(3, 20, -9, false), 1, "a page up: the top")
eq(FL.Step(nil, 0, 1, true), nil, "nothing to move in")
eq(FL.Step(0, 4, 1, true), 1, "from none: the first")

-- Scrolling ------------------------------------------------------------------------------
eq(FL.Scroll(0, 3, 10, 5), 0, "all fit")
eq(FL.Scroll(0, 10, 10, 20), 0, "last visible row")
eq(FL.Scroll(0, 11, 10, 20), 1, "one past: one down")
eq(FL.Scroll(5, 3, 10, 20), 2, "above: up to it")
eq(FL.Scroll(0, 20, 10, 20), 10, "the end")
eq(FL.Scroll(15, 20, 10, 20), 10, "never past the end")
eq(FL.Scroll(4, nil, 10, 20), 0, "no row: the top")

local top, len = FL.Thumb(0, 10, 20, 400)
eq(top, 0, "thumb at the top")
eq(len, 200, "thumb half the track")
top = FL.Thumb(10, 10, 20, 400)
eq(top, 200, "thumb at the end")
eq(FL.Thumb(0, 10, 5, 400), nil, "no thumb when all fit")
local _, small = FL.Thumb(0, 2, 1000, 400)
eq(small, 16, "a thumb never too small to see")

-- Where it starts --------------------------------------------------------------------------
local rows = { { name = "A, x" }, { name = "B, y" } }
eq(FL.Start(rows, "B, y"), 2, "the last place flown to")
eq(FL.Start(rows, "Gone, z"), 1, "gone: the first")
eq(FL.Start(rows, nil), 1, "none yet: the first")
eq(FL.Start({}, nil), nil, "empty: none")

-- Settings ----------------------------------------------------------------------------------
eq(FL.Wanted(true, true, true), true, "shown: on, gamepad UI, map open")
eq(FL.Wanted(true, false, true), false, "not with mouse and keyboard")
eq(FL.Wanted(true, nil, true), false, "gamepad UI unknown: not shown")
eq(FL.Wanted(false, true, true), false, "off")
eq(FL.Wanted(true, true, false), false, "map closed")
eq(FL.Enabled(), true, "on by default")
db.flightList = false
eq(FL.Enabled(), false, "off")
eq(FL.Sorting(), "near", "nearest by default")
db.flightSort = "name"
eq(FL.Sorting(), "name", "A-Z kept")
eq(FL.LastFrom("Ironforge, Dun Morogh"), nil, "nothing flown yet")
FL.Remember("Ironforge, Dun Morogh", "Stormwind, Elwynn")
FL.Remember("Stormwind, Elwynn", "Sentinel Hill, Westfall")
eq(FL.LastFrom("Ironforge, Dun Morogh"), "Stormwind, Elwynn", "per place")
eq(FL.LastFrom("Stormwind, Elwynn"), "Sentinel Hill, Westfall", "the other place")
eq(FL.LastFrom(nil), nil, "no here")

-- The map ------------------------------------------------------------------------------------
local x, y = FL.NodePoint(0.25, 0.75, 580, 580)
eq(x, 145, "x from the left")
eq(y, 145, "y from the bottom (the game's own placing)")
eq(FL.Ease(0), 0, "ease from")
eq(FL.Ease(1), 1, "ease to")
eq(FL.Ease(0.5), 0.5, "ease midway")
eq(FL.Ease(2), 1, "ease clamped")

io.write(("FlightList: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
