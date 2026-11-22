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

-- (the real Sh.Settler: the triggers' grace, shared with fishing)
local realSettler
do
    local shared = {}
    hooksecurefunc = function() end
    assert(loadfile(root .. "/Shared.lua"))("GamepadCompanion", shared)
    hooksecurefunc = nil
    realSettler = shared.Shared.Settler
end
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
eq(FL.VIEWS.zones, "near", "Y: zones to nearest")
eq(FL.VIEWS.near, "zones", "Y: nearest to zones")

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

-- Scrolling (rows of 40 px, zones of 24) ---------------------------------------------------
local function H(r) return r.kind == "header" and 24 or 40 end
local flat = {}
for i = 1, 20 do flat[i] = { kind = "flight" } end
eq(FL.Scroll(0, 3, { flat[1], flat[2], flat[3] }, 400, H), 0, "all fit")
eq(FL.Scroll(0, 10, flat, 400, H), 0, "last visible row")
eq(FL.Scroll(0, 11, flat, 400, H), 1, "one past: one down")
eq(FL.Scroll(5, 3, flat, 400, H), 2, "above: up to it")
eq(FL.Scroll(0, 20, flat, 400, H), 10, "the end")
eq(FL.Scroll(15, 20, flat, 400, H), 10, "never past the end")
eq(FL.Scroll(4, nil, flat, 400, H), 0, "no row: the top")
local grouped = { { kind = "flight" }, { kind = "header" }, { kind = "flight" }, { kind = "flight" } }
eq(FL.Scroll(2, 3, grouped, 80, H), 1, "a zone's first: its header comes along")
eq(FL.Scroll(0, 4, grouped, 80, H), 2, "the end, by height")

local top, len = FL.Thumb(0, 10, 20, 400)
eq(top, 0, "thumb at the top")
eq(len, 200, "thumb half the track")
top = FL.Thumb(10, 10, 20, 400)
eq(top, 200, "thumb at the end")
eq(FL.Thumb(0, 10, 5, 400), nil, "no thumb when all fit")
local _, small = FL.Thumb(0, 2, 1000, 400)
eq(small, 16, "a thumb never too small to see")

-- Zones, levels, quests ----------------------------------------------------------------
eq(FL.ZoneName("Elwynn"), "Elwynn Forest", "the map's short name")
eq(FL.ZoneName("Thunder Bluff"), "Mulgore", "a city: its zone")
eq(FL.ZoneName("Ashenvale"), "Ashenvale", "a full name kept")
eq(FL.ZoneName(nil), nil, "no zone")
eq(FL.Tier(30, { 30, 40 }), "yellow", "in range")
eq(FL.Tier(27, { 30, 40 }), "orange", "a little low")
eq(FL.Tier(26, { 30, 40 }), "red", "too low")
eq(FL.Tier(45, { 30, 40 }), "green", "a little high")
eq(FL.Tier(46, { 30, 40 }), "grey", "too high")
eq(FL.Tier(30, nil), nil, "no range")
eq(FL.Tier(30, false), nil, "a hub")
eq(FL.Fit(30, { 30, 40 }), 25, "fit: in range")
eq(FL.Fit(30, nil), 8, "fit: unknown")
eq(FL.Fit(60, { 1, 10 }, true), 8, "fit: a city never nothing")

-- Arranging (Thunder Bluff, level 30) ------------------------------------------------------
local function N(i, name, dist, cost)
    local p, z = FL.SplitName(name)
    return { index = i, name = name, place = p, zone = z, dist = dist, cost = cost or 100, hops = 1 }
end
local tb = {
    N(1, "Camp Taurajo, The Barrens", 0.10), N(2, "Sun Rock Retreat, Stonetalon Mountains", 0.15),
    N(3, "Crossroads, The Barrens", 0.20), N(4, "Freewind Post, Thousand Needles", 0.18),
    N(5, "Orgrimmar, Durotar", 0.50), N(6, "Gadgetzan, Tanaris", 0.60, 5000),
    N(7, "Bloodhoof Village, Mulgore", 0.05), N(8, "Splintertree Post, Ashenvale", 0.40),
}
local ctx = { zone = "Mulgore", level = 30, money = 1000,
    places = { ["Splintertree Post, Ashenvale"] = { open = 1, ready = 2 }, ["Crossroads, The Barrens"] = { open = 4, ready = 0 } } }
local rows, start = FL.Arrange(tb, ctx)
eq(rows[1].kind, "header", "zones: a header first")
eq(rows[1].g.zone, "Mulgore", "your own zone first")
eq(start, 2, "start: the first flight")
eq(rows[start].node.place, "Bloodhoof Village", "the nearest in your zone")
eq(rows[3].g.zone, "Ashenvale", "then turn-ins")
eq(rows[5].g.zone, "The Barrens", "then open quests")
eq(rows[6].node.place, "Camp Taurajo", "in a zone: nearest first")
eq(rows[3].g.ready, 2, "a zone's turn-ins: its paths'")
eq(rows[5].g.open, 4, "a zone's quests: its paths'")
eq(rows[#rows].node.place, "Gadgetzan", "a zone you can't pay for: last")
eq(rows[#rows - 1].g.zone, "Tanaris", "its header")
eq(rows[#rows].g.tier, "red", "Tanaris red at 30")
-- no flight in your zone: the best zone first
rows, start = FL.Arrange(tb, { zone = "Moonglade", level = 30, money = 1000, places = ctx.places })
eq(rows[1].g.zone, "Ashenvale", "no flight here: the best zone first")
eq(rows[start].node.place, "Splintertree Post", "and its nearest")
-- level only: a grey zone dimmed, a city not
rows = FL.Arrange(tb, { zone = "x", level = 60 })
local dims = {}
for _, r in ipairs(rows) do if r.kind == "header" then dims[r.g.zone] = r.g.dim end end
eq(dims["Thousand Needles"], true, "grey: dimmed")
eq(dims["Durotar"], false, "a city: never dimmed")
-- the last place flown to lifts its zone
local a1 = FL.Arrange({ N(1, "A, Desolace", 0.3), N(2, "B, Feralas", 0.3) }, { level = 45 })
local a2 = FL.Arrange({ N(1, "A, Desolace", 0.3), N(2, "B, Feralas", 0.3) }, { level = 40, last = "A, Desolace" })
eq(a1[1].g.zone, "Feralas", "the zone your level fits")
eq(a2[1].g.zone, "Desolace", "equal fit: the last place's zone")
-- nearest view: no headers
rows, start = FL.Arrange(tb, { view = "near", zone = "Mulgore", level = 30, places = ctx.places })
eq(#rows, #tb, "nearest: flights only")
eq(rows[1].node.place, "Bloodhoof Village", "nearest first")
eq(start, 1, "nearest: the first")
eq(rows[1].g.zone, "Mulgore", "rows still know their zone")
-- an empty map
rows, start = FL.Arrange({}, ctx)
eq(#rows, 0, "no rows")
eq(start, nil, "no start")
-- no zone in the name: the place is its group
rows = FL.Arrange({ N(1, "Moonglade", 0.2) }, {})
eq(rows[1].g.zone, "Moonglade", "named after the place")
eq(rows[1].g.range, nil, "a hub: no range")

-- Moving in zones ---------------------------------------------------------------------------
rows = FL.Arrange(tb, ctx)
eq(FL.Next(rows, 2, 1, true), 4, "down: past the next header")
eq(FL.Next(rows, 4, -1, true), 2, "up: past it again")
eq(FL.Next(rows, 2, -1, true), #rows, "up from the top: wraps to the last")
eq(FL.Next(rows, #rows, 1, true), 2, "down from the last: wraps")
eq(FL.Next(rows, #rows, 1, false), #rows, "held: stops")
eq(FL.Next(rows, nil, 1, false), 2, "none yet: the first")
eq(FL.Next(rows, nil, -1, false), #rows, "none yet, up: the last")
eq(FL.Next({}, nil, 1, true), nil, "nothing to move in")
eq(rows[FL.Zone(rows, 2, 1)].g.zone, "Ashenvale", "right: the next zone")
eq(FL.Zone(rows, 2, -1), #rows, "left from the first: the last zone")
eq(FL.Zone(rows, #rows, 1), 2, "right from the last: the first")
-- the triggers' jumps
local j = FL.Jump(rows, 2, "ready")
eq(rows[j].g.zone, "Ashenvale", "L2: the zone with turn-ins")
eq(FL.Jump(rows, j, "ready"), j, "only one: stays")
j = FL.Jump(rows, 2, "open")
eq(rows[j].g.zone, "The Barrens", "R2: the most open quests")
eq(rows[FL.Jump(rows, j, "open")].g.zone, "Ashenvale", "again: the next")
eq(FL.Jump(rows, 2, "none"), nil, "no zone: nothing")
eq(FL.Total(rows, "open"), 5, "all open quests")
eq(FL.Total(rows, "ready"), 2, "all turn-ins")
eq(rows[FL.Find(rows, "Crossroads, The Barrens")].node.place, "Crossroads", "X: the last place")
eq(FL.Find(rows, "Gone, z"), nil, "gone: none")
eq(FL.Find(rows, nil), nil, "none yet")
-- nearest view: the jumps land on the zone's nearest
rows = FL.Arrange(tb, { view = "near", zone = "Mulgore", level = 30, places = ctx.places })
eq(rows[FL.Jump(rows, 1, "open")].node.place, "Crossroads", "nearest view: the path itself")

-- Quests to flight paths (world yards, by continent) -----------------------------------------
local P = function(name, zone, cont, x, y) return { name = name, zone = zone, at = cont and { cont = cont, x = x, y = y } } end
local paths = {
    P("Crossroads, The Barrens", "The Barrens", 1, 0, 0), P("Ratchet, The Barrens", "The Barrens", 1, 500, 100),
    P("Camp Taurajo, The Barrens", "The Barrens", 1, 100, 900), P("Orgrimmar, Durotar", "Durotar", 1, 900, -900),
    P("Booty Bay, Stranglethorn Vale", "Stranglethorn Vale", 0, 0, 0), P("Gone, Nowhere", "Nowhere"),
}
local centres = { ["The Barrens"] = { cont = 1, x = 120, y = 800 } }
local W = function(cont, x, y) return { cont = cont, x = x, y = y } end
local pq = FL.Tally({
    { ready = true, zone = "The Barrens", at = W(1, 20, 10) },        -- by Crossroads
    { ready = false, zone = "The Barrens", at = W(1, 480, 90) },      -- by Ratchet
    { ready = false, zone = "Durotar", at = W(1, 480, 120) },         -- a Durotar quest by Ratchet: the point wins
    { ready = true, zone = "The Barrens", at = W(0, 10, 10) },        -- on the other continent: Booty Bay
    { ready = false, zone = "The Barrens" },                          -- no point: the path by the zone's centre
    { ready = false, zone = "Durotar" },                              -- no point, no centre: the zone's first
    { ready = false, zone = "Warrior" },                              -- no point, no zone of paths: no dot
    { ready = true, zone = nil },                                     -- nothing known: no dot
}, paths, centres)
eq(pq["Crossroads, The Barrens"].ready, 1, "a turn-in: the nearest path")
eq(pq["Ratchet, The Barrens"].open, 2, "quests to do: the nearest path, whatever their zone")
eq(pq["Booty Bay, Stranglethorn Vale"].ready, 1, "only paths on the quest's continent")
eq(pq["Camp Taurajo, The Barrens"].open, 1, "no point: the zone's path by its centre")
eq(pq["Orgrimmar, Durotar"].open, 1, "no point, no centre: the zone's first path")
local total = 0
for _, c in pairs(pq) do total = total + c.open + c.ready end
eq(total, 6, "the two with nothing known: no dot")
eq(pq["Gone, Nowhere"], nil, "a path with no point: no quest by distance")
eq(next(FL.Tally({}, paths, centres)), nil, "no quests")
eq(next(FL.Tally({ { ready = true, at = W(1, 0, 0) } }, {}, {})), nil, "no paths")

-- The quest note --------------------------------------------------------------------------------
local qs = {
    { title = "Kolkar Leaders", level = 16, ready = false }, { title = "Wharfmaster Dizzywig", level = 15, ready = true },
    { title = "Raptor Thieves", level = 12, ready = false }, { title = "The Angry Scytheclaws", ready = true },
}
local lines, more = FL.NoteLines(qs)
eq(#lines, 4, "every quest a line")
eq(lines[1].title, "Wharfmaster Dizzywig", "turn-ins first")
eq(lines[1].ready, true, "a gold mark")
eq(lines[2].title, "The Angry Scytheclaws", "then the next turn-in")
eq(lines[2].level, nil, "no level known: none")
eq(lines[3].title, "Kolkar Leaders", "then the quests to do, in the log's order")
eq(lines[3].level, 16, "its level")
eq(lines[4].ready, false, "a brown mark")
eq(more, 0, "nothing more")
lines, more = FL.NoteLines(qs, 3)
eq(#lines, 3, "at most max lines")
eq(more, 1, "and how many more")
lines, more = FL.NoteLines({})
eq(#lines, 0, "no quests: no lines")
eq(more, 0, "none more")
local tallied = FL.Tally({ { ready = true, zone = "The Barrens", title = "Wharfmaster Dizzywig", level = 15 } },
    { { name = "Ratchet, The Barrens", zone = "The Barrens" } }, {})
eq(tallied["Ratchet, The Barrens"].quests[1].title, "Wharfmaster Dizzywig", "a path keeps its quests")
local noted = FL.Arrange({ N(1, "Ratchet, The Barrens", 0.2) }, { places = tallied })
eq(noted[2].quests[1].title, "Wharfmaster Dizzywig", "a row carries them: the note's quests")
eq(#FL.Arrange({ N(1, "Ratchet, The Barrens", 0.2) }, {})[2].quests, 0, "none: no note")

-- Rows carry their path's quests; L2 / R2 go to the paths with the most -----------------------
local rq = FL.Arrange(tb, { zone = "Mulgore", level = 30,
    places = { ["Crossroads, The Barrens"] = { open = 1, ready = 1 }, ["Camp Taurajo, The Barrens"] = { open = 2, ready = 0 },
        ["Splintertree Post, Ashenvale"] = { open = 1, ready = 0 } } })
local at = {}
for i, r in ipairs(rq) do if r.node then at[r.node.place] = i end end
eq(rq[at["Crossroads"]].ready, 1, "a row's turn-ins")
eq(rq[at["Camp Taurajo"]].open, 2, "a row's quests to do")
eq(rq[at["Orgrimmar"]].open, 0, "none: zero")
eq(FL.Jump(rq, 2, "ready"), at["Crossroads"], "L2: the path with turn-ins")
eq(FL.Jump(rq, at["Crossroads"], "ready"), at["Crossroads"], "the only one: stays")
eq(FL.Jump(rq, 2, "open"), at["Camp Taurajo"], "R2: the path with the most to do")
local nx = FL.Jump(rq, at["Camp Taurajo"], "open")
check(nx == at["Crossroads"] or nx == at["Splintertree Post"], "R2 again: the next path with quests")
check(FL.Jump(rq, nx, "open") ~= nx, "and on, round")

-- Settings ----------------------------------------------------------------------------------
eq(FL.Wanted(true, true, true), true, "shown: on, gamepad UI, map open")
eq(FL.Wanted(true, false, true), false, "not with mouse and keyboard")
eq(FL.Wanted(true, nil, true), false, "gamepad UI unknown: not shown")
eq(FL.Wanted(false, true, true), false, "off")
eq(FL.Wanted(true, true, false), false, "map closed")
eq(FL.Enabled(), true, "on by default")
db.flightList = false
eq(FL.Enabled(), false, "off")
eq(FL.View(), "zones", "zones by default")
db.flightSort = "near"
eq(FL.View(), "near", "nearest kept")
db.flightSort = "name"
eq(FL.View(), "near", "an older A-Z: nearest")
eq(FL.LastFrom("Ironforge, Dun Morogh"), nil, "nothing flown yet")
FL.Remember("Ironforge, Dun Morogh", "Stormwind, Elwynn")
FL.Remember("Stormwind, Elwynn", "Sentinel Hill, Westfall")
eq(FL.LastFrom("Ironforge, Dun Morogh"), "Stormwind, Elwynn", "per place")
eq(FL.LastFrom("Stormwind, Elwynn"), "Sentinel Hill, Westfall", "the other place")
eq(FL.LastFrom(nil), nil, "no here")
eq(FL.NoteOn(), true, "the quest note on by default")
db.flightNote = false
eq(FL.NoteOn(), false, "off")
db.flightNote = nil

-- The map ------------------------------------------------------------------------------------
local x, y = FL.NodePoint(0.25, 0.75, 580, 580)
eq(x, 145, "x from the left")
eq(y, 145, "y from the bottom (the game's own placing)")
eq(FL.Ease(0), 0, "ease from")
eq(FL.Ease(1), 1, "ease to")
eq(FL.Ease(0.5), 0.5, "ease midway")
eq(FL.Ease(2), 1, "ease clamped")

-- L2 / R2's bindings ------------------------------------------------------------------------
local on = FL.Binds(true)
eq(on.PADLTRIGGER, "CLICK GamepadCompanionFlightTurnIns:LeftButton", "L2: turn-ins")
eq(on.PADRTRIGGER, "CLICK GamepadCompanionFlightQuests:LeftButton", "R2: quests to do")
eq(next(FL.Binds(false)), nil, "off: none")
eq(FL.TRIGGER_JUMPS.PADLTRIGGER, "ready", "L2 jumps to turn-ins")
eq(FL.TRIGGER_JUMPS.PADRTRIGGER, "open", "R2 jumps to quests")

-- The game wiring: L2 / R2 bound while the list shows, changed only when both have been up
-- a quarter second (as the fishing pole's), dropped in a fight -----------------------------------
do
    local clock, lt, rt, combat = 100, false, false, false
    local overrides, frames, drivers = {}, {}, {}
    local function Frame(name)
        local f = { scripts = {}, attrs = {}, shown = false, points = {}, name = name }
        return setmetatable(f, { __index = function(t, k)
            if k == "TitleText" or k == "CloseButton" or k == "InsetBg" then return nil end
            if k == "SetScript" then return function(_, a, b) t.scripts[a] = b end end
            if k == "HookScript" then return function(_, a, b) t.scripts[a] = b end end
            if k == "SetAttribute" then return function(_, a, b) t.attrs[a] = b end end
            if k == "Show" then return function() t.shown = true end end
            if k == "Hide" then return function() t.shown = false end end
            if k == "IsShown" then return function() return t.shown end end
            if k == "SetShown" then return function(_, v) t.shown = v and true or false end end
            if k == "GetHeight" or k == "GetWidth" then return function() return 500 end end
            if k == "GetFrameLevel" then return function() return 3 end end
            if k == "GetParent" then return function() return rawget(t, "parent") end end
            if k == "SetParent" then return function(_, v) t.parent = v end end
            if k == "GetStringWidth" then return function() return 30 end end
            if k:match("^Create") then return function() return Frame() end end
            return function() end
        end })
    end
    _G.CreateFrame = function(_, name, parent)
        local f = Frame(name)
        f.parent = parent
        if name then _G[name] = f; frames[name] = f end
        return f
    end
    UIParent = Frame("UIParent")
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    C_Timer = { After = function(_, fn) fn() end }
    InCombatLockdown = function() return combat end
    GetTime = function() return clock end
    GetMoney = function() return 1000 end
    hooksecurefunc = function() end
    SetOverrideBindingClick = function(owner, _, key, name) overrides[key] = { owner = owner, action = "CLICK " .. name .. ":LeftButton" } end
    ClearOverrideBindings = function(owner) for k, v in pairs(overrides) do if v.owner == owner then overrides[k] = nil end end end
    RegisterStateDriver = function(f, st, cond) drivers[#drivers + 1] = { f = f, st = st, cond = cond } end
    TaxiFrame = Frame("TaxiFrame")
    TaxiRouteMap = Frame("TaxiRouteMap")
    local map = { { "Orgrimmar, Durotar", "CURRENT" }, { "Crossroads, The Barrens", "REACHABLE" } }
    NumTaxiNodes = function() return #map end
    TaxiNodeName = function(i) return map[i][1] end
    TaxiNodeGetType = function(i) return map[i][2] end
    TaxiNodeCost = function() return 100 end
    TaxiNodePosition = function(i) return 0.1 * i, 0.5 end
    GetNumRoutes = function() return 1 end
    TaxiGetNodeSlot = function() return 1 end
    local wdb = {}
    local wns = { Shared = {
        CharDB = function() return wdb end,
        Held = function() return lt, rt end,
        PadButtons = function() return {} end,
        PadDown = function() return false end,
        Settler = realSettler,
    } }
    local kicked
    wns.FishingToast = { Paper = function() end, Kicker = function() end, SetKicker = function(_, text) kicked = text end }
    C_QuestLog = {
        GetNumQuestLogEntries = function() return 2 end,
        GetInfo = function(i) return ({ { title = "The Barrens", isHeader = true }, { title = "Wharfmaster Dizzywig", level = 15, questID = 7 } })[i] end,
        ReadyForTurnIn = function() return true end,
    }
    assert(loadfile(root .. "/FlightList.lua"))("GamepadCompanion", wns)
    local W = wns.FlightList
    local function L2() return overrides.PADLTRIGGER and overrides.PADLTRIGGER.action end
    eq(drivers[1] and drivers[1].cond, "[combat] on; off", "a fight drops them (state driver)")
    TaxiFrame.shown = true
    W.Open()
    eq(kicked, "CROSSROADS", "the note: the chosen path's quests, named after it")
    kicked = nil
    W.SetNote(false)
    eq(kicked, nil, "the note off: not drawn")
    W.SetNote(true)
    eq(L2(), nil, "map just open: L2 the bars' till both have been up a quarter second")
    clock = clock + 0.3
    eq(W.Bind(), true, "then")
    eq(L2(), "CLICK GamepadCompanionFlightTurnIns:LeftButton", "map open: L2 ours")
    eq(overrides.PADRTRIGGER and overrides.PADRTRIGGER.action, "CLICK GamepadCompanionFlightQuests:LeftButton", "and R2")
    -- the map closes with L2 held: L2 stays till both are up a quarter second
    lt = true
    TaxiFrame.shown = false
    W.Close()
    eq(L2(), "CLICK GamepadCompanionFlightTurnIns:LeftButton", "L2 held: no change mid-press")
    clock = clock + 1
    eq(W.Bind(), false, "still held: still waiting")
    lt = false
    eq(W.Bind(), false, "just released: not yet")
    clock = clock + 0.1
    eq(W.Bind(), false, "0.1 s up: not yet")
    clock = clock + 0.2
    eq(W.Bind(), true, "a quarter second up: done")
    eq(L2(), nil, "map closed: L2 back to the bars")
    eq(overrides.PADRTRIGGER, nil, "R2 too")
    -- opened in a fight's wake: waits till it's over
    combat = true
    TaxiFrame.shown = true
    W.Open()
    eq(L2(), nil, "in combat: nothing changed")
    combat = false
    W.Bind()
    clock = clock + 0.3
    W.Bind()
    eq(L2(), "CLICK GamepadCompanionFlightTurnIns:LeftButton", "after it: ours")
    -- a fight starts: the driver clears them (the bars' again at once); after it, ours again
    combat = true
    ClearOverrideBindings(drivers[1].f)
    drivers[1].f.Fight(drivers[1].f, "on")
    eq(L2(), nil, "a fight: L2 the bars'")
    combat = false
    W.Bind()
    clock = clock + 0.3
    W.Bind()
    eq(L2(), "CLICK GamepadCompanionFlightTurnIns:LeftButton", "after it: ours again")
end

io.write(("FlightList: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
