-- The fishing lure: the pick (yours while it's in the bags, else the best the
-- skill allows), the bags read (counts, the tooltip over the table), the time
-- words and a lure's whole time, the float's text, and the skill's road (a
-- point's odds, the water's level learned, its word).
-- lua5.1 tests/FishingLure.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs: any frame method is a no-op, the font strings keep their text
local frames = {}
local function Obj()
    local o = {}
    return setmetatable(o, { __index = function(t, k)
        if k == "SetText" then return function(self, v) self.text = v end end
        if k == "SetScript" then return function(self, name, f) local sc = rawget(self, "scripts") or {}; rawset(self, "scripts", sc); sc[name] = f end end
        if k == "SetCooldown" then return function(self, s, d) self.cd = { s, d } end end
        if k == "Clear" then return function(self) self.cd = nil end end
        if k:match("^Create") then return function() return Obj() end end
        return function() end
    end })
end
CreateFrame = function() local f = Obj(); frames[#frames + 1] = f; return f end
UIParent = Obj()
local now = 100
GetTime = function() return now end
local bags, tooltips, enchant, skill, modifier = {}, {}, nil, 75, nil
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #bags or 0 end,
    GetContainerItemInfo = function(_, slot) local b = bags[slot]; return b and { itemID = b[1], stackCount = b[2], iconFileID = "icon" .. b[1] } end,
}
C_Item = {
    GetItemNameByID = function(id) return ({ [6530] = "Nightcrawlers", [6529] = "Shiny Bauble", [6532] = "Bright Baubles", [999] = "Odd Lure" })[id] end,
    GetItemIconByID = function(id) return "icon" .. id end,
}
C_TooltipInfo = { GetItemByID = function(id) local t = tooltips[id]; return t and { lines = t } or nil end }
local skillRead = true
GetNumSkillLines = function() return skillRead and 2 or 0 end
GetSkillLineInfo = function(i)
    if i == 1 then return "Secondary Skills", true end
    return "Fishing", false, nil, skill, 0, modifier
end
GetWeaponEnchantInfo = function() if enchant then return true, enchant * 1000 end return false end
local char = {}
local ns = { Shared = { CharDB = function() return char end } }
MimezuFishing = { PoleEquipped = function() return true end }
assert(loadfile(root .. "/FishingWaters.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/FishingLure.lua"))("GamepadCompanion", ns)
local L = ns.FishingLure

-- The pick ------------------------------------------------------------------------
local items = { { id = 6529, bonus = 25, skill = 0, count = 3 }, { id = 6530, bonus = 50, skill = 50, count = 9 },
    { id = 6532, bonus = 75, skill = 100, count = 2 } }
eq(L.Pick("auto", items, 75).id, 6530, "auto: the best the skill allows (Nightcrawlers at 75, not Bright Baubles)")
eq(L.Pick(nil, items, 120).id, 6532, "auto at 120: Bright Baubles")
eq(L.Pick("auto", items, 10).id, 6529, "low skill: Shiny Bauble")
eq(L.Pick("6529", items, 120).id, 6529, "chosen: that one, even with a better in the bags")
eq(L.Pick(6533, items, 120), nil, "chosen but not in the bags: none")
eq(L.Pick("auto", {}, 120), nil, "no lures: none")
eq(L.Pick("auto", items, nil).id, 6532, "skill unreadable: the best (the game's word decides)")
local red = { { id = 6532, bonus = 75, skill = 100, count = 2, usable = false }, { id = 6530, bonus = 50, skill = 50, count = 9 } }
eq(L.Pick("auto", red, nil).id, 6530, "skill unreadable: one the game says you can't use is passed over")
local tie = { { id = 6811, bonus = 50, skill = 50, count = 2 }, { id = 6530, bonus = 50, skill = 50, count = 9 } }
eq(L.Pick("auto", tie, 75).id, 6530, "same bonus: the bigger stack")

-- Time ------------------------------------------------------------------------------
eq(L.TimeText(600), "10 min", "10 min")
eq(L.TimeText(541), "10 min", "9 min 1 s: 10 min (rounded up)")
eq(L.TimeText(60), "1 min", "60 s: 1 min")
eq(L.TimeText(42.4), "42 s", "under a minute: seconds")
eq(L.TimeText(-3), "0 s", "never negative")
eq(L.Total(nil, nil, 598), 600, "fresh lure: its whole time to the minute")
eq(L.Total(600, 598, 590), 600, "running: the known whole time stays")
eq(L.Total(600, 30, 299), 300, "a new 5 min lure over the end of the old: 5 min")
eq(L.Total(600, 100, nil), nil, "none")

-- The bags: stacks counted, the tooltip read over the table ------------------------------
bags = { { 6530, 5 }, { 1234, 1 }, { 6530, 4 }, { 999, 1 } }
tooltips[999] = { { leftText = "Odd Lure" }, { leftText = "Use: When applied to your fishing pole, increases Fishing by 60 for 10 min." },
    { leftText = "Requires Fishing (60)" } }
tooltips[6530] = { { leftText = "Nightcrawlers" }, { leftText = "Use: When applied to your fishing pole, increases Fishing by 50 for 10 min." },
    { leftText = "Requires Fishing (50)" } }
local found = L.Bags()
eq(#found, 2, "two lures (a plain item left out)")
eq(found[1].id == 6530 and found[1].count, 9, "Nightcrawlers: both stacks counted")
eq(found[2].bonus .. "/" .. found[2].skill, "60/60", "a lure the table doesn't know: read from its tooltip")
eq(L.Skill(), 75, "the Fishing skill read")
eq(L.Current().id, 999, "auto in game: the odd lure (60) over Nightcrawlers (50) at 75")
skill = 55
eq(L.Current().id, 6530, "skill 55: Nightcrawlers")
char.fishing = { lure = 6530 }
skill = 75
eq(L.Current().id, 6530, "chosen Nightcrawlers")
-- Forever's skill list empty (the case in game): the lure still found
char.fishing = {}
skillRead = false
eq(L.Skill(), nil, "no skill list: unknown, not 0")
eq(L.Current() and L.Current().id, 999, "no skill list: the best lure in the bags, not none")
skillRead = true
char.fishing = { lure = 6530 }

-- The float's words ------------------------------------------------------------------
local glyph = "|A:Gamepad_Shp_LTrigger_64:14:14|a"
local t, line, lit = L.Words(541, false, "Nightcrawlers", nil)
eq(t .. " / " .. line .. " / " .. tostring(lit), "Nightcrawlers / 10 min / true", "on the pole: its name and time, lit")
t, line, lit = L.Words(nil, true, "Nightcrawlers", { name = "Nightcrawlers" })
eq(t .. " / " .. line .. " / " .. tostring(lit), "Nightcrawlers / Spent / false", "just run out: spent, dim")
t, line = L.Words(nil, false, "Nightcrawlers", { name = "Nightcrawlers" })
eq(t .. " / " .. line, "No lure / " .. glyph .. "  Nightcrawlers", "none on: L2 and the lure it puts on")
t, line = L.Words(nil, false, nil, nil)
eq(t .. " / " .. line, "No lure / None in bags", "none in the bags")

-- Driven: the float follows the pole's enchant
L.Show(true)
enchant = 598
char.fishing.lastLure = 6530
t, line, lit = L.Refresh()
eq(t .. " / " .. line .. " / " .. tostring(lit), "Nightcrawlers / 10 min / true", "a lure on: shown")
enchant = 30
t, line = L.Refresh()
eq(line, "30 s", "its last seconds")
enchant = nil
t, line = L.Refresh()
eq(line, "Spent", "run out: spent")
now = now + 7
t, line = L.Refresh()
eq(t, "No lure", "a moment later: no lure")
check(line:find("Nightcrawlers", 1, true) ~= nil, "and L2's lure named")

-- The skill's road -------------------------------------------------------------------
eq(L.SkillUp("Your skill in Fishing has increased to 76."), 76, "a Fishing skill-up read")
eq(L.SkillUp("Your skill in Mining has increased to 76."), nil, "another skill: not ours")
eq(L.SkillUp("Tu habilidad en Pesca ha aumentado a 12.", "Tu habilidad en %s ha aumentado a %d.", "Pesca"), 12, "another language, from its own format")
eq(L.SkillUp(nil), nil, "no message")
eq(L.Odds(40), 1, "below 75: every catch")
eq(L.Odds(100), 0.5, "100: one in two")
eq(L.Odds(300), 0.1, "300: one in ten")
eq(L.OddsColour(1)[2], 0.50, "every catch: orange")
eq(L.OddsColour(0.5)[2], 1, "one in two: yellow")
eq(L.OddsColour(0.2)[1], 0.25, "one in five: green")
eq(L.OddsColour(0.1)[1], 0.55, "one in ten: grey")
eq(L.AtCap(75, 75, 0), true, "75 of 75: train")
eq(L.AtCap(300, 300, 0), false, "300 of 300: nothing more to train")
eq(L.AtCap(74, 75, 9), false, "74 of 75: not yet")
eq(L.AtCap(75, nil, 5), false, "no cap to read, 75, 5 fish: too soon to say")
eq(L.AtCap(75, nil, 6), true, "no cap to read, 75, 6 fish with no point (every catch counts at 75): train")
eq(L.AtCap(150, nil, 23), false, "no cap to read, 150: a point is one in four, 23 isn't enough")
eq(L.AtCap(150, nil, 24), true, "150, 24 fish (6 points' worth): train")
eq(L.AtCap(150, nil, 29, "vanilla"), false, "the other formula (one in five at 150): 29 isn't enough")
eq(L.AtCap(150, nil, 30, "vanilla"), true, "and 30 is")
eq(L.AtCap(nil, nil, 50), false, "no skill known: nothing said")
eq(L.Pace({ 1, 2, 2 }), 2, "the fish a point took lately")
eq(L.Pace({}), nil, "no points yet")
local dot = "\194\183"
local w, c = L.Whisper(100, 95, 76, 76, 150, 0, nil, false)
eq(w, "Wiser  " .. dot .. "  Fishing 76", "a skill-up: said a moment, first")
local _, warm = L.Whisper(96, 95, 76, 76, 150, 0, nil, false)
check(warm[1] == 1 and c[1] < 1, "the first moments in bright gold, then the usual warm gold")
check(type(L.Celebrate) == "function" and pcall(L.Celebrate), "a point: the celebration plays (quietly, no error)")
w = L.Whisper(120, 95, 75, 75, 75, 0, nil, false)
eq(w, "Train to learn more", "at the cap: train")
w = L.Whisper(120, nil, nil, 120, 150, 1, nil, "low")
eq(w, "Skill too low here", "the water beyond the skill: too low")
w, c = L.Whisper(120, nil, nil, 120, 150, 1, 2, "some")
eq(w, "Fishing 120  " .. dot .. "  some get away", "some get away: said on the skill's line")
eq(c[1] .. "," .. c[2], "1,1", "still coloured by the point's odds (the water never changes them)")
w, c = L.Whisper(120, nil, nil, 120, 150, 1, 2, false)
eq(w, "Fishing 120  " .. dot .. "  2 fish a point", "otherwise: the skill and the pace")
eq(c[1] .. "," .. c[2], "1,1", "coloured by its odds (yellow at 120)")
eq(L.Whisper(120, nil, nil, nil, nil, 3, nil, false), nil, "nothing known: nothing said")

-- The water's level and its word (pure) -----------------------------------------------
eq(L.Effective(120, 50), 170, "the skill the water counts: rank and modifier")
eq(L.Effective(120, nil), 120, "no modifier read: the rank")
eq(L.Effective(nil, 50), nil, "no rank: unknown")
eq(L.EstimateB(170, 9, 11), 130, "9 of 20 land at 170: the water is 130")
eq(L.EstimateB(170, 6, 5), nil, "11 outcomes: too few to say")
local b, bound = L.EstimateB(170, 20, 0)
eq(tostring(b) .. "/" .. tostring(bound), "nil/75", "none lost: only that the water is 75 or lower")
eq(L.EstimateB(150, 0, 6), 155, "6 lost, none landed: beyond reach (above 150)")
eq(L.EstimateB(150, 0, 2), nil, "2 lost: too few to say anything")
eq(L.EstimateB(260, 5, 15), 230, "far from any known level: kept as it is (a tenth of the bites allowed as late presses)")
eq(L.Judge(170, 130), "some", "40 over the water: some get away")
eq(L.Judge(230, 130), nil, "95 over it: none get away, nothing said")
eq(L.Judge(100, 130), "low", "under it: too low")
eq(L.Judge(145, 130), "low", "20 in 100 land: too low still")
eq(L.Judge(150, 130), "some", "one in four: some get away")
eq(L.Judge(170, nil), nil, "the water unknown: nothing said")
eq(L.Judge(200, 205), "low", "the game's 205 at 200: too low")
local stv = L.Keys("Stranglethorn Vale", "Grom'gol Base Camp")
eq(table.concat(stv, "|"), "Stranglethorn Vale/Grom'gol Base Camp|Stranglethorn Vale", "the place first, then the zone")
eq(#L.Keys("Durotar", ""), 1, "no place: the zone alone")
eq(#L.Keys("", "x"), 0, "no zone: no key")
eq(L.Reach({ ["Stranglethorn Vale"] = { landed = 9, escaped = 11, sumE = 3400 } }, stv), 130, "the place unknown: the zone's level")
eq(L.Reach({ ["Tanaris"] = { landed = 2, escaped = 18, sumE = 4000, need = 205 } }, L.Keys("Tanaris")), 205, "the game's word beats the outcomes (190)")
eq(L.Reach({ ["Tanaris"] = { above = 180 } }, L.Keys("Tanaris")), 181, "refused at 180 with no number: above it")
eq(L.Reach({}, stv), nil, "never fished: unknown")
local ws = {}
L.Outcome(ws, stv, 170, true); L.Outcome(ws, stv, 170, false)
eq(ws["Stranglethorn Vale"].landed .. "/" .. ws["Stranglethorn Vale"].escaped .. "/" .. ws["Stranglethorn Vale"].sumE, "1/1/340", "counted for the zone")
eq(ws[stv[1]].landed, 1, "and for the place")
eq(L.TooLow("Requires Fishing 205", "Requires Fishing %d"), 205, "the game's refusal: its level")
eq(L.TooLow("Requires Mining 205", "Requires Fishing %d"), nil, "another refusal: not ours")
eq(L.TooLow("Fishing skill too low", "Fishing skill too low"), true, "a refusal naming no level")
eq(L.TooLow("Your fish got away!", "Fishing skill too low"), nil, "a lost fish isn't a refusal")
-- False positives: none from a few lost fish -------------------------------------------
-- (bites fed as the game sends them: a fish landed, or got away)
local function Fed(waters, keys, E, list) for _, landed in ipairs(list) do L.Outcome(waters, keys, E, landed) end end
local function Says(waters, keys, E, prior, sure) return L.Judge(E, (L.Reach(waters, keys, prior, sure))) end
local durotar = L.Keys("Durotar", "")
-- timing misses on easy water: Durotar (-70) at 150, 3 lost to late presses among 30
ws = {}
Fed(ws, durotar, 150, { false, false, false })
eq(Says(ws, durotar, 150, -70, true), nil, "Durotar at 150, the first 3 lost (late presses): nothing said (the known level)")
Fed(ws, durotar, 150, { true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true })
eq(Says(ws, durotar, 150, -70, true), nil, "and 3 lost of 30: still nothing")
eq(L.EstimateB(150, 27, 3), nil, "3 lost in 30 on its own: within the late presses allowed")
-- a new water with 2 casts: nothing, whatever they did
local nowhere = L.Keys("Nowhere", "")
ws = {}
Fed(ws, nowhere, 150, { false, false })
eq(Says(ws, nowhere, 150), nil, "an unknown water, 2 lost: nothing said")
ws = {}
Fed(ws, nowhere, 150, { true, true })
eq(Says(ws, nowhere, 150), nil, "2 landed: nothing said")
ws = {}
Fed(ws, stv, 120, { false, false })
eq(Says(ws, stv, 170, 130, true), "some", "Stranglethorn, 2 lost at 170: its known level only (some get away), never too low")
-- plainly hard, said fast: 3 lost in the first 4 bites, at any pace
ws = {}
Fed(ws, nowhere, 150, { false, false, true })
eq(Says(ws, nowhere, 150), nil, "an unknown water, 2 lost and one landed: not yet")
Fed(ws, nowhere, 150, { false })
eq(Says(ws, nowhere, 150), "low", "3 lost in the first 4 bites: too low")
ws = {}
Fed(ws, nowhere, 150, { false, false, false })
eq(Says(ws, nowhere, 150), "low", "3 lost, none landed: too low")
-- a pool harder than its zone: Stranglethorn (130) at 230 says nothing, until the water
-- shows it over 20 bites (and then "some get away", never too low)
local pool = L.Keys("Stranglethorn Vale", "The Savage Coast")
ws = {}
Fed(ws, pool, 230, { false, false, false, true, false, true })
eq(Says(ws, pool, 230, 130, true), nil, "a harder pool, 4 lost of 6 at 230: the known level holds (nothing)")
Fed(ws, pool, 230, { true, true, false, true, true, false, true, true, false, true, true, true, false, true })
eq(Says(ws, pool, 230, 130, true), "some", "10 lost of 20: the water's own level, some get away")
eq(L.Reach(ws, pool, 130, true) > 130, true, "learned above the zone's")
-- a known level a fish proves wrong: one landed at 120 in a water known as 205 (sure)
ws = {}
Fed(ws, stv, 120, { true })
check(L.Reach(ws, stv, 205, true) <= 124, "a fish landed at 120: the water can't be over 124")

-- The zones' known levels: by map, else by name (the client's own, else English)
local b1, sure1 = L.Known(1434)
eq(tostring(b1) .. "/" .. tostring(sure1), "130/true", "Stranglethorn by its map: 130")
eq(L.Known(nil, "Tanaris"), 205, "no map: by its English name")
eq(L.Known(nil, "Tuercespina", function(id) return id == 1434 and "Tuercespina" or nil end), 130, "by the map's name in the client's language")
eq(L.Known(9999, "Nowhere"), nil, "unknown: nothing")
eq(select(2, L.Known(1423)), false, "Eastern Plaguelands: a guess")
local tiers = {}
for _, t in ipairs(L.TIERS) do tiers[t] = true end
local count, names = 0, {}
for id, z in pairs(L.ZONES) do
    count = count + 1
    check(tiers[z[1]] and type(z[2]) == "string" and id >= 1411 and id <= 1458 and (z.sure == nil or z.sure == false),
        "zone " .. id .. " well formed")
    check(not names[z[2]], "zone name " .. tostring(z[2]) .. " once")
    names[z[2]] = true
end
eq(count, 44, "44 fishable zones and cities")
for name, w in pairs(L.WATERS) do
    check(tiers[w[1]] and type(name) == "string" and name ~= "" and (w.sure == nil or w.sure == false), "water " .. name .. " well formed")
end
eq(L.Known(nil, "Stratholme"), 330, "a dungeon by its name")
L.WATERS["Stranglethorn Vale/Test Pool"] = { 205 }
eq(L.Known(1434, "Stranglethorn Vale", nil, "Test Pool"), 205, "a place with its own level: over its zone's")
eq(L.Known(1434, "Stranglethorn Vale", nil, "Grom'gol Base Camp"), 130, "another place: the zone's")
L.WATERS["Stranglethorn Vale/Test Pool"] = nil
local r1, how1 = L.Reach({}, stv, 130)
eq(tostring(r1) .. "/" .. tostring(how1), "130/known", "never fished: the zone's known level")
eq(select(2, L.Reach({}, stv, 205, false)), "guess", "a guess said so")
eq(L.Reach({ ["Stranglethorn Vale"] = { landed = 1, escaped = 0, sumE = 100, caughtAt = 100 } }, stv, 130), 104,
    "a fish landed at 100 proves the water under 105: the known level gives way")
eq(L.Reach({ ["Tanaris"] = { above = 260 } }, L.Keys("Tanaris"), 205), 261, "a refused cast at 260: above it")
eq(L.Reach({ ["Stranglethorn Vale"] = { landed = 4, escaped = 16, sumE = 4000 } }, stv, 130), 175, "what the water did beats the known level")
ws = {}
L.Outcome(ws, { "X" }, 150, true); L.Outcome(ws, { "X" }, 120, true); L.Outcome(ws, { "X" }, 180, false)
eq(ws.X.caughtAt, 120, "the lowest skill a fish landed at, kept")

-- A point's odds, and the formula the fish your points took pick
eq(L.Odds(74), 1, "74: every catch")
eq(L.Odds(75, "vanilla"), 0.5, "the other formula at 75: one in two")
eq(L.Odds(150, "vanilla"), 0.2, "and one in five at 150")
check(math.abs(L.Odds(300, "vanilla") - 1 / 11) < 1e-9, "and one in eleven at 300")
local fished = { mangos = {}, vanilla = {} }
for r = 80, 109 do
    for name in pairs(fished) do table.insert(fished[name], { r, math.floor(1 / L.Odds(r, name) + 0.5) }) end
end
eq(L.Fit(fished.vanilla), "vanilla", "points that took the other formula's fish (80-109, where the two differ most): that formula")
eq(L.Fit(fished.mangos), "mangos", "points that took MaNGOS's: MaNGOS")
eq(L.Fit({ { 150, 6 }, { 151, 6 } }), "mangos", "two points: too few, the default")
eq(L.Fit(nil), "mangos", "none: the default")

-- Driven: the skill read from C_SkillInfo (Forever's list), skill-ups, catches, a lost fish
C_SkillInfo = {
    GetNumSkillLines = function() return 2 end,
    GetSkillLineInfo = function(i)
        if i == 1 then return { name = "Professions", isHeader = true } end
        return { name = "Fishing", rank = 75, maxRank = 75 }
    end,
}
local r, m = L.SkillInfo()
eq(tostring(r) .. "/" .. tostring(m), "75/75", "Forever's list read: 75 of 75")
GetZoneText = function() return "Silverpine Forest" end
GetSubZoneText = function() return "North Tide's Run" end
IsFishingLoot = function() return true end
SKILL_RANK_UP = "Your skill in %s has increased to %d."
local ev
for _, f in ipairs(frames) do local sc = rawget(f, "scripts"); if sc and sc.OnEvent and not ev then ev = sc.OnEvent end end   -- (the first: the float's own)
check(ev ~= nil, "the float listens")
eq(L.WhisperNow(now), "Train to learn more", "75 of 75 read: train")
C_SkillInfo, skillRead = nil, false   -- (no list to read: the skill-up messages tell it)
ev(nil, "CHAT_MSG_SKILL", "Your skill in Fishing has increased to 120.")
for _ = 1, 2 do ev(nil, "LOOT_OPENED") end
ev(nil, "CHAT_MSG_SKILL", "Your skill in Fishing has increased to 121.")
eq(char.fishing.skill, 121, "the skill kept from the message")
eq(char.fishing.since, 0, "the count starts again")
eq(char.fishing.pace[#char.fishing.pace], 2, "that point took 2 fish")
ERR_FISH_ESCAPED = "Your fish got away!"
ev(nil, "UI_ERROR_MESSAGE", 1, "Your fish got away!")
now = now + 30
eq(L.WhisperNow(now), "Fishing 121  " .. dot .. "  2 fish a point", "one fish lost: nothing about it")
ev(nil, "UI_ERROR_MESSAGE", 1, "Your fish got away!")
ev(nil, "UI_ERROR_MESSAGE", 1, "Your fish got away!")
eq(L.WhisperNow(now), "Fishing 121  " .. dot .. "  2 fish a point", "three lost here: still nothing (it used to say too low)")
eq(char.fishing.waters["Silverpine Forest"].escaped, 3, "the lost fish kept for the water")
-- Before a cast, from the known levels: Durotar at 121 says nothing; Stranglethorn at 120 with no
-- lure (under its 130) too low at once; Eastern Plaguelands (a guess) at 121 never too low
GetZoneText = function() return "Durotar" end
GetSubZoneText = function() return "" end
eq(L.WhisperNow(now), "Fishing 121  " .. dot .. "  2 fish a point", "Durotar at 121: nothing about the water")
GetZoneText = function() return "Stranglethorn Vale" end
eq(L.WhisperNow(now), "Skill too low here", "Stranglethorn at 121, no lure: too low before a cast")
C_Map = { GetBestMapForUnit = function() return 1423 end }
eq(L.WhisperNow(now), "Fishing 121  " .. dot .. "  2 fish a point", "Eastern Plaguelands (its map read) at 121: a guess, never too low")
skillRead, skill, modifier = true, 250, 0
eq(L.WhisperNow(now), "Fishing 250  " .. dot .. "  some get away", "and at 250: some get away")
C_Map = nil
skillRead, skill, modifier = false, 75, nil
-- Stranglethorn at 120 with Nightcrawlers (+50): about 45 in 100 land. Fishing 120 + 50
-- is 40 over the water, never "too low"
skillRead, skill, modifier = true, 120, 50
GetZoneText = function() return "Stranglethorn Vale" end
GetSubZoneText = function() return "Grom'gol Base Camp" end
local outcomes = { true, false, false, true, false, false, false, true, false, true, false, true, false, true, false, true, false, true, false, true }
for i = 1, 3 do ev(nil, "UI_ERROR_MESSAGE", 1, "Your fish got away!") end
eq(L.WhisperNow(now), "Fishing 120  " .. dot .. "  some get away", "Stranglethorn, 3 lost in a row at 170: not too low (its known 130: some get away)")
char.fishing.waters = {}
for _, landed in ipairs(outcomes) do
    if landed then ev(nil, "LOOT_OPENED") else ev(nil, "UI_ERROR_MESSAGE", 1, "Your fish got away!") end
end
eq(L.WhisperNow(now), "Fishing 120  " .. dot .. "  some get away", "9 of 20 landed at 170: some get away")
modifier = 0
eq(L.WhisperNow(now), "Skill too low here", "the lure off (120 under the water's 130): too low")
modifier = 75
eq(L.WhisperNow(now), "Fishing 120  " .. dot .. "  some get away", "Bright Baubles on (195): some still get away")
skill, modifier = 225, 50
eq(L.WhisperNow(now), "Fishing 225  " .. dot .. "  2 fish a point", "275, 145 over the water: nothing about it")
skill, modifier = 120, 50
GetSubZoneText = function() return "Nek'mani Wellspring" end
eq(L.WhisperNow(now), "Fishing 120  " .. dot .. "  some get away", "another place in the zone: the zone's level")
-- the lure's bonus when the modifier can't be read: the one on the pole
skillRead = false
char.fishing.skill = 120
enchant, char.fishing.lastLure = 500, 6530
eq(select(1, L.EffectiveNow()), 170, "no modifier read: Nightcrawlers on the pole count")
enchant = nil
eq(select(1, L.EffectiveNow()), 120, "and nothing when the pole has no lure")
skillRead = true
-- The game refuses the cast and says the level: too low at once, a lure counted against it
SPELL_FAILED_FISHING_TOO_LOW = "Requires Fishing %d"
GetZoneText = function() return "Tanaris" end
GetSubZoneText = function() return "" end
ev(nil, "UI_ERROR_MESSAGE", 1, "Requires Fishing 205")
eq(char.fishing.waters["Tanaris"].need, 205, "the game's level kept")
eq(L.WhisperNow(now), "Skill too low here", "170 under Tanaris' 205: too low, at once")
modifier = 100
eq(L.WhisperNow(now), "Skill too low here", "with +100 (220): under one in four land, still too low")
modifier = 110
eq(L.WhisperNow(now), "Fishing 120  " .. dot .. "  some get away", "with +110 (230): some get away")
ev(nil, "CHAT_MSG_SKILL", "Your skill in Fishing has increased to 122.")
eq(char.fishing.waters["Tanaris"] and char.fishing.waters["Tanaris"].need, 205, "a point keeps what the waters taught")
eq(char.fishing.points[#char.fishing.points][1], 121, "the point's fish kept with the rank they were caught at")
modifier = nil
GetZoneText = function() return "Silverpine Forest" end
GetSubZoneText = function() return "North Tide's Run" end

-- The same bites, fishing non-stop (5 s apart) or now and then (10 min apart): the same word
local verdicts = {}
now = now + 60   -- (the last point's "Wiser" long gone)
for _, gap in ipairs({ 5, 600 }) do
    char.fishing.waters = {}
    skillRead, skill, modifier = true, 150, 0
    GetZoneText = function() return "Nowhere" end
    GetSubZoneText = function() return "" end
    local said = {}
    for _, landed in ipairs({ false, true, false, false, true, false, false, false }) do
        now = now + gap
        if landed then ev(nil, "LOOT_OPENED") else ev(nil, "UI_ERROR_MESSAGE", 1, "Your fish got away!") end
        said[#said + 1] = L.WhisperNow(now)
    end
    verdicts[gap] = table.concat(said, "|")
end
eq(verdicts[5], verdicts[600], "non-stop or relaxed: the same words, bite by bite")
check(verdicts[5]:find("Skill too low here", 1, true) ~= nil, "and too low once 3 of 4 got away")
skillRead, skill, modifier = false, 75, nil

-- The cast ring ------------------------------------------------------------------------
eq(L.CastLeft(100000, 130000, 100), 1, "the cast begins: all of it left")
eq(L.CastLeft(100000, 130000, 115), 0.5, "halfway")
eq(L.CastLeft(100000, 130000, 140), 0, "over: none, never below")
eq(L.CastLeft(nil, 130000, 115), nil, "no channel: nothing")
local beads = L.Beads(0.5, 8)
eq(table.concat(beads, ","), "1,1,1,1,0,0,0,0", "half left: the first half of the beads lit")
beads = L.Beads(0.3, 10)
eq(beads[3], 1, "the beads up to the share lit")
check(math.abs(beads[4]) < 1e-9, "the next one dark (exact share)")
beads = L.Beads(0.35, 10)
check(math.abs(beads[4] - 0.5) < 1e-9, "the tip glides: the last bead half lit")
-- Driven: a cast hides Blizzard's bar (its alpha only), the line in lets it be
local bar = { alpha = 1, hooks = {} }
function bar:SetAlpha(a) self.alpha = a end
function bar:HookScript(name, f) self.hooks[name] = f end
PlayerCastingBarFrame = bar
UnitChannelInfo = function() return "Fishing", nil, nil, now * 1000, (now + 30) * 1000 end
ev(nil, "UNIT_SPELLCAST_CHANNEL_START", "player", nil, 7620)
eq(bar.alpha, 0, "fishing: Blizzard's cast bar unseen")
bar.alpha = 1; bar.hooks.OnEvent(bar)
eq(bar.alpha, 0, "its own handler shows it again mid-cast: unseen again")
ev(nil, "UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 7620)
bar.alpha = 1; bar.hooks.OnEvent(bar)
eq(bar.alpha, 1, "the line in: the next cast's bar shows as the game draws it")
ev(nil, "UNIT_SPELLCAST_CHANNEL_START", "player", nil, 133)
eq(bar.alpha, 1, "another channel: the bar untouched")
char.fishing.castRing = false
ev(nil, "UNIT_SPELLCAST_CHANNEL_START", "player", nil, 7620)
eq(bar.alpha, 1, "Cast ring off: Blizzard's bar as it is")
char.fishing.castRing = nil
ev(nil, "UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 7620)

-- Edit Mode: the float moved, put home ------------------------------------------------
eq(select(1, L.Spot(nil)) .. "," .. select(2, L.Spot(nil)), "36,210", "never moved: its home spot")
eq(select(1, L.Spot({ 400, 300 })) .. "," .. select(2, L.Spot({ 400, 300 })), "400,300", "moved: its own spot")
eq(select(1, L.Spot({ "x" })), 36, "a broken spot: home")
check(pcall(L.EditMode, true) and L.editing == true, "Edit Mode opens: the float editable")
check(pcall(L.EditMode, false) and L.editing == false, "Edit Mode closes")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
