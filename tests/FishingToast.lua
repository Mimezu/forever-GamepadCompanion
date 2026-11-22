-- The catch card: its words for each moment, the outing line and the chance
-- here, a catch read from the loot window, kept and shown, and its motion.
-- lua5.1 tests/FishingToast.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs: any frame method is a no-op, the font strings keep their text
local function Obj()
    local o = {}
    return setmetatable(o, { __index = function(t, k)
        if k == "SetText" then return function(self, v) self.text = v end end
        if k == "SetAlpha" then return function(self, v) self.alpha = v end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetPoint" then return function(self, ...) self.point = { ... } end end
        if k == "SetScript" then return function(self, name, f) local sc = rawget(self, "scripts") or {}; rawset(self, "scripts", sc); sc[name] = f end end
        if k == "GetStringWidth" or k == "GetUnboundedStringWidth" then return function(self) return #(self.text or "") * 7 end end
        if k:match("^Create") then return function() return Obj() end end
        return function() end
    end })
end
local events
CreateFrame = function() local f = Obj(); if not events then events = f end; return f end
UIParent = Obj()
local clock, epoch = 50, 1795000000   -- GetTime, time()
GetTime = function() return clock end
time = function() return epoch end
date = os.date
local zone, sub = "Elwynn Forest", "Crystal Lake"
GetZoneText = function() return zone end
GetSubZoneText = function() return sub end
local loot, fishing, pole = {}, true, true
GetNumLootItems = function() return #loot end
GetLootSlotInfo = function(i) local l = loot[i]; return "icon" .. l[1], l[2], l[4] or 1, nil, l[3] end
GetLootSlotLink = function(i) return "|Hitem:" .. loot[i][1] .. "::::|h[" .. loot[i][2] .. "]|h" end
IsFishingLoot = function() return fishing end
MimezuFishing = { PoleEquipped = function() return pole end }

local char = {}
local ns = { Shared = { CharDB = function() return char end }, FishingLure = { Setting = function()
    char.fishing = char.fishing or {}; return char.fishing end } }
assert(loadfile(root .. "/FishingJournal.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/FishingToast.lua"))("GamepadCompanion", ns)
local T, J = ns.FishingToast, ns.FishingJournal
local A = T.ACCENT

-- Small words --------------------------------------------------------------------------
eq(T.Ordinal(1) .. T.Ordinal(2) .. T.Ordinal(3) .. T.Ordinal(4), "1st2nd3rd4th", "ordinals")
eq(T.Ordinal(11) .. T.Ordinal(12) .. T.Ordinal(13) .. T.Ordinal(21) .. T.Ordinal(112), "11th12th13th21st112th", "teens")
eq(T.Title("Raw Brilliant Smallfish"), "Brilliant Smallfish", "\"Raw\" dropped")
eq(T.Title("Raw"), "Raw", "only a leading \"Raw \"")
eq(T.KindMark(10) and T.KindMark(250) and T.KindMark(3000), true, "a kind's milestones")
eq(T.KindMark(11) or T.KindMark(1500), false, "not milestones")
eq(T.TotalMark(100) and T.TotalMark(2000), true, "the journal's milestones")
eq(T.TotalMark(250), false, "250 catches: not one")
eq(T.Chance(5, 19), nil, "under 20 catches here: no chance")
eq(T.Chance(5, 25), "1 in 5 here", "a fifth: 1 in 5")
eq(T.Chance(15, 20), "most here", "three quarters: most")
eq(T.Chance(1, 50), "rare here", "1 in 50: rare")
eq(T.Since(1793000000, 1795000000), "26 Oct", "first this year: day and month")
eq(T.Since(1760000000, 1795000000), "Oct 2025", "another year: month and year")

-- The moments ---------------------------------------------------------------------------
local function W(c) return T.Words(c, 1795000000) end
local base = { name = "Raw Brilliant Smallfish", q = 1, ever = 7, total = 40, outingTotal = 12, here = 5, hereTotal = 25,
    place = "Crystal Lake", first = 1793000000, run = 1 }
local function With(t) local c = {}; for k, v in pairs(base) do c[k] = v end; for k, v in pairs(t) do c[k] = v end; return c end
local w = W(base)
eq(w.kicker, "CRYSTAL LAKE", "plain: the water")
eq(w.title, "Brilliant Smallfish", "plain: the fish")
eq(w.line1, A .. "7th|r in the journal", "plain: the kind's count")
eq(w.line2, "12th this outing  \194\183  1 in 5 here", "outing and chance")
eq(w.hold, 4, "plain: 4 s")
w = W(With({ ever = 1, firstHere = true }))
eq(w.kicker .. " / " .. w.line1 .. " / " .. w.hold, "FIRST OF ITS KIND / New to your journal / 7", "first ever")
w = W(With({ q = 3 }))
eq(w.kicker .. " / " .. w.hold, "A RARE CATCH / 6", "a rare one")
w = W(With({ q = 2, ever = 10 }))
eq(w.kicker, "A FINE CATCH", "a fine one, over a milestone")
w = W(With({ ever = 25 }))
eq(w.kicker .. " / " .. w.line1, "THE 25TH / Since 26 Oct", "a milestone of the kind")
w = W(With({ total = 500 }))
eq(w.kicker, "500 CATCHES", "a milestone of the journal")
w = W(With({ firstHere = true }))
eq(w.kicker .. " / " .. w.line1, "NEW HERE / First from Crystal Lake", "first in this water")
eq(w.line2, "12th this outing", "new here: no chance said")
w = W(With({ run = 5 }))
eq(w.kicker, "FIVE IN A ROW", "five in a row")
eq(W(With({ run = 6 })).kicker, "CRYSTAL LAKE", "six in a row: plain")
w = W(With({ q = 0, ever = 1, name = "Ruined Leather Scraps" }))
eq(w.kicker .. " / " .. tostring(w.line1) .. " / " .. w.hold, "CRYSTAL LAKE / nil / 3", "grey junk: quiet, even the first")
eq(w.grey, true, "grey")
w = W(With({ place = "?", hereTotal = 50 }))
eq(w.kicker .. " / " .. w.line2, "A CATCH / 12th this outing", "no water known: no place, no chance")
eq(W(With({ hereTotal = 10 })).line2, "12th this outing", "too few here: no chance")

-- A catch read, kept, shown --------------------------------------------------------------
local OnEvent = events.scripts.OnEvent
loot = { { 6291, "Raw Brilliant Smallfish", 1 } }
OnEvent(events, "LOOT_READY")
local db = char.fishJournal
eq(db.total, 1, "kept")
eq(db.kinds[6291].name, "Raw Brilliant Smallfish", "its name kept")
eq(db.log[1].w, "Elwynn Forest/Crystal Lake", "its water kept")
eq(db.log[1].t, epoch, "its time kept")
eq(T.shown.kicker, "FIRST OF ITS KIND", "shown: a first")
eq(T.Phase(), "in", "rising")
OnEvent(events, "LOOT_OPENED")
eq(db.total, 1, "the same window read twice: one catch")
-- the motion
T.Step(0.2)
eq(T.Phase(), "in", "still rising")
T.Step(0.2)
eq(T.Phase(), "hold", "in place")
T.Step(6.9)
eq(T.Phase(), "hold", "first of its kind holds 7 s")
T.Step(0.2)
eq(T.Phase(), "out", "then fades")
T.Step(0.7)
eq(T.Phase(), nil, "gone")

-- the next catch, the junk beside it named the fish
clock = clock + 20; epoch = epoch + 20
loot = { { 2934, "Ruined Leather Scraps", 0 }, { 6291, "Raw Brilliant Smallfish", 1 } }
OnEvent(events, "LOOT_OPENED")
eq(T.shown.title, "Brilliant Smallfish", "the fish over the junk")
eq(T.shown.line2, "2nd this outing", "the outing's second")
eq(db.total, 2, "two catches")
-- another while shown: no queue, the words change in place
T.Step(0.4)
clock = clock + 2
loot = { { 6303, "Raw Slitherskin Mackerel", 1 } }
OnEvent(events, "LOOT_OPENED")
eq(T.shown.title, "Slitherskin Mackerel", "replaced in place")
eq(T.Phase(), "hold", "still held")
T.Step(7.1)
eq(T.Phase(), "out", "fading")
clock = clock + 2
loot = { { 6291, "Raw Brilliant Smallfish", 1 } }
OnEvent(events, "LOOT_OPENED")
eq(T.Phase(), "hold", "a catch as it fades: back, held again")
T.Step(5)
T.Step(1)

-- not ours: no pole, not fishing loot
pole = false
loot = { { 6303, "Raw Slitherskin Mackerel", 1 } }
clock = clock + 5
OnEvent(events, "LOOT_OPENED")
eq(db.total, 4, "no pole: not a catch")
pole, fishing = true, false
OnEvent(events, "LOOT_OPENED")
eq(db.total, 4, "not fishing loot: not a catch")
fishing = true

-- the card off: still kept
char.fishing.toast = false
clock = clock + 5
eq(T.Catch({ { id = 6291, name = "Raw Brilliant Smallfish", q = 1, n = 1 } }, clock), nil, "card off: none shown")
eq(db.total, 5, "card off: still kept")
char.fishing.toast = nil
-- a name not known yet: kept, not shown
clock = clock + 5
eq(T.Catch({ { id = 7777, q = 1, n = 1 } }, clock), nil, "no name: none shown")
eq(db.kinds[7777].n, 1, "no name: still kept")

-- Edit Mode: a sample rests on the float
T.EditMode(true)
eq(T.shown.title, "Brilliant Smallfish", "the sample")
T.Step(60)
eq(T.Phase() ~= "out" and T.Phase() ~= nil, true, "the sample stays while editing")
T.EditMode(false)
eq(T.Phase(), "out", "edit mode over: it goes")

io.write(("FishingToast: %d checks, %d failures\n"):format(checks, failures))
if failures > 0 then os.exit(1) end
