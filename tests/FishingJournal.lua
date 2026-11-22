-- The fishing journal: catches kept, outings, the toast's facts and its words.
-- lua5.1 tests/FishingJournal.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

local char = {}
local ns = { Shared = { CharDB = function() return char end } }
assert(loadfile(root .. "/FishingJournal.lua"))("GamepadCompanion", ns)
local J = ns.FishingJournal

-- The record -------------------------------------------------------------------------
local db = J.DB()
eq(char.fishJournal, db, "kept in the character's settings")
eq(J.Water("Elwynn Forest", "Crystal Lake"), "Elwynn Forest/Crystal Lake", "water: zone and place")
eq(J.Water("Elwynn Forest", ""), "Elwynn Forest", "no place: the zone")
eq(J.Water("Stormwind", "Stormwind"), "Stormwind", "place named as the zone: the zone")

local LAKE = "Elwynn Forest/Crystal Lake"
local function Fish(id, name, q, n) return { id = id, name = name, icon = "icon" .. id, q = q or 1, n = n or 1 } end
local r = J.Record(db, { Fish(6291, "Raw Brilliant Smallfish") }, LAKE, 1000)
eq(#r, 1, "one item")
eq(r[1].firstEver, true, "first ever")
eq(r[1].firstHere, true, "first here")
eq(r[1].ever, 1, "one of it")
eq(r[1].newOuting, true, "an outing begins")
eq(db.total, 1, "one catch")
r = J.Record(db, { Fish(6291, "Raw Brilliant Smallfish") }, LAKE, 1060)
eq(r[1].firstEver, false, "second: not first")
eq(r[1].ever .. "/" .. r[1].outing .. "/" .. r[1].outingTotal, "2/2/2", "counts: ever, outing, outing total")
eq(r[1].newOuting, false, "same outing")
r = J.Record(db, { Fish(6303, "Raw Slitherskin Mackerel"), Fish(2934, "Ruined Leather Scraps", 0) }, LAKE, 1100)
eq(#r, 2, "two items in one catch")
eq(J.Best(r).id, 6303, "the toast's item: the fish over the junk")
eq(db.total, 3, "a loot window is one catch")
eq(db.waters[LAKE].n, 3, "three catches in the lake")
eq(#db.log, 4, "each item logged")
eq(db.log[4].w, LAKE, "with its water")
local box = J.Record(db, { Fish(6291, "Raw Brilliant Smallfish"), Fish(6352, "Waterlogged Crate", 2) }, LAKE, 1200)
eq(J.Best(box).id, 6352, "a green crate over a fish")
eq(J.Record(db, {}, LAKE, 1300)[1], nil, "an empty loot: nothing")
eq(db.total, 4, "an empty loot: not a catch")

-- A new outing after the gap
r = J.Record(db, { Fish(6291, "Raw Brilliant Smallfish") }, "Westfall", 1200 + J.OUTING_GAP + 1)
eq(r[1].newOuting, true, "after the gap: a new outing")
eq(r[1].outing, 1, "outing counts start again")
eq(#db.outings, 1, "the old outing kept")
eq(db.outings[1].n, 4, "with its catches")
eq(r[1].firstHere, true, "first in Westfall")
eq(r[1].ever, 4, "the kind's count goes on")

-- The log is capped
J.LOG_MAX = 3
J.Record(db, { Fish(6291, "Raw Brilliant Smallfish") }, "Westfall", 5000)
eq(#db.log, 3, "the log capped")
eq(db.kinds[6291].n, 5, "the counts are not")

-- Share of a water
eq(J.Share(5, 19), nil, "too few catches: no share")
eq(J.Share(5, 20), 0.25, "enough: a quarter")
eq(J.ItemID("|cff9d9d9d|Hitem:2934::::::::|h[Ruined Leather Scraps]|h|r"), 2934, "item id from a link")

io.write(("FishingJournal: %d checks, %d failures\n"):format(checks, failures))
if failures > 0 then os.exit(1) end
