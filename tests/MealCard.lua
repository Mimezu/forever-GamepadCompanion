-- The meal card: what counts as a meal's buff (Well Fed after eating, a fire's after
-- sitting by one), its words (what it gives, for how long), and the reads: a food buff
-- shows once, a refresh and a stranger's blessing never, a campfire's shows, off is off.
-- lua5.1 tests/MealCard.lua <addon folder>
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
        if k == "SetWidth" then return function(self, v) self.width = v end end
        if k == "SetFont" then return function(self, _, size) self.size = size end end
        if k == "SetTexture" then return function(self, v) self.texture = v end end
        if k == "SetAlpha" then return function(self, v) self.alpha = v end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
        if k == "SetPoint" then return function(self, ...) self.point = { ... } end end
        if k == "ClearAllPoints" then return function(self) self.point = nil end end
        if k == "GetTop" then return function(self) return self.top end end
        if k == "GetEffectiveScale" then return function() return 1 end end
        if k == "SetScript" then return function(self, name, f) local sc = rawget(self, "scripts") or {}; rawset(self, "scripts", sc); sc[name] = f end end
        if k == "GetStringWidth" or k == "GetUnboundedStringWidth" then return function(self) return #(self.text or "") * 7 end end
        if k:match("^Create") then return function() return Obj() end end
        return function() end
    end })
end
local frames = {}
CreateFrame = function(_, name) local f = Obj(); frames[#frames + 1] = f; if name then f.name = name end; return f end
UIParent = Obj()
PlayerFrame = Obj()
PlayerFrame.top = 300
PlayerFrame.PlayerFrameContainer = { PlayerPortrait = Obj() }
PlayerFrame.PlayerFrameContainer.PlayerPortrait.top = 280
local clock = 100
GetTime = function() return clock end
local combat = false
InCombatLockdown = function() return combat end
local NAMES = { [433] = "Food", [430] = "Drink", [1312719] = "Refreshment" }
local DESCS = {}
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellDescription = function(id) return DESCS[id] or "" end }
-- the player's buffs, in order: { id, name, duration, source, mine, instance, desc }
local buffs = {}
C_UnitAuras = { GetBuffDataByIndex = function(unit, i)
    local b = buffs[i]
    if not b then return nil end
    return { name = b.name, spellId = b.id, icon = "icon" .. b.id, duration = b.duration, sourceUnit = b.source,
        isFromPlayerOrPlayerPet = b.mine, auraInstanceID = b.instance, expirationTime = b.expires, applications = b.count }
end }
C_TooltipInfo = { GetUnitBuffByAuraInstanceID = function(unit, instance)
    for _, b in ipairs(buffs) do
        if b.instance == instance then
            return { lines = { { leftText = b.name }, { leftText = b.desc }, { leftText = "14 minutes remaining" } } }
        end
    end
end }

local char = {}
local ns = { Shared = { CharDB = function() return char end }, FishingLure = { Setting = function() return {} end },
    Rumble = { REST_SPELLS = { eat = { 433 }, drink = { 430 }, both = { 1312719 } } } }
assert(loadfile(root .. "/FishingJournal.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/FishingToast.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/EditSpots.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Passage.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/MealFoods.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/MealCard.lua"))("GamepadCompanion", ns)
local P = ns.Passage
local M = ns.MealCard
local events
for _, f in ipairs(frames) do if f.scripts and f.scripts.OnEvent then events = f end end
assert(events, "the meal card listens")
local function Aura(unit) events.scripts.OnEvent(events, "UNIT_AURA", unit or "player") end

-- What it gives, for how long ----------------------------------------------------------------
eq(M.Gives("Increases Stamina and Spirit by 4 for 15 min."), "+4 Stamina and Spirit", "Well Fed's line")
eq(M.Gives("Increases your Strength by 10 for 1 hr."), "+10 Strength", "your Strength")
eq(M.Gives("Increases Spirit by 4."), "+4 Spirit", "no duration said")
eq(M.Gives("Restores 8 mana per 5 sec for 10 min."), "+8 mana per 5 sec", "mana regen")
eq(M.Gives("|cffffffffIncreases Agility by 10 for 15 min.|r Second sentence."), "+10 Agility", "colours and a second sentence dropped")
eq(M.Gives("Warm and cozy. Nothing else"), "Warm and cozy", "an odd line: its first sentence")
-- Forever's camp: a heading, then each gain on its line (2026-11-22, the card said nothing)
eq(M.Gives("Gained the following camp benefits:\n\nFaction Banner: Spirit increased by 14."), "+14 Spirit", "the camp's gain under its heading")
eq(M.Gives("Gained the following camp benefits:\nFaction Banner: Spirit increased by 14.\nCampfire: Stamina increased by 5."), "+14 Spirit · +5 Stamina", "two gains")
eq(M.Gives("Gained the following camp benefits:\nA: Spirit increased by 1.\nB: Stamina increased by 2.\nC: Agility increased by 3."), "+1 Spirit · +2 Stamina", "two at most")
eq(M.Gives("Spirit increased by 14."), "+14 Spirit", "no source named")
eq(M.Gives("Attack Power is increased by 20."), "+20 Attack Power", "'is increased by': no 'is' left (2026-11-23)")
eq(M.Fresh({ duration = 900, expirationTime = 1000 }, 102), true, "landed 2 s ago: new")
eq(M.Fresh({ duration = 900, expirationTime = 1000 }, 400), false, "running 5 min: not new")
eq(M.Fresh({ duration = 0 }, 400), true, "no time to read: may be new")
eq(M.Gives("Gained the following camp benefits:"), nil, "a heading alone: nothing")
eq(M.Kind({ name = "Camp Benefits", duration = 3600 }, { now = 0 }), "fire", "Camp Benefits: the fire's, by name")
eq(M.Gives(""), nil, "nothing: nil")
eq(M.Gives(nil), nil, "no line: nil")
eq(M.Lasts(900), "For 15 minutes", "15 min")
eq(M.Lasts(1800), "For half an hour", "half an hour")
eq(M.Lasts(3600), "For an hour", "an hour")
eq(M.Lasts(7200), "For 2 hours", "two hours")
eq(M.Lasts(60), "For 1 minute", "one minute")
eq(M.Lasts(0), nil, "no duration: nil")
local w = M.Words("meal", "Well Fed", "+4 Stamina and Spirit", 900)
eq(w.kicker .. " / " .. w.title .. " / " .. w.line1 .. " / " .. w.line2 .. " / " .. w.hold, "A GOOD MEAL / Well Fed / +4 Stamina and Spirit / For 15 minutes / 5", "a meal's words")
w = M.Words("fire", "Cozy Fire", nil, 3600)
eq(w.kicker .. " / " .. w.line1 .. " / " .. tostring(w.line2), "BY THE FIRE / For an hour / nil", "a fire's words, nothing known of it: the time on line 1")

-- What counts ---------------------------------------------------------------------------------
local quiet = { eating = {}, fire = {}, now = 0 }
local eating = { eating = { now = true }, fire = {}, now = 0 }
local fireOn = { eating = {}, fire = { before = true }, now = 0 }
eq(M.Kind({ name = "Well Fed", spellId = 19705, duration = 900 }, quiet), "meal", "Well Fed by name: a meal, eating or not")
eq(M.Kind({ name = "Bien nourri", spellId = 19706, duration = 900 }, quiet), "meal", "a known id in another tongue: a meal")
eq(M.Kind({ name = "Cozy Fire", spellId = 7353, duration = 3600 }, quiet), "fire", "Cozy Fire: the fire's")
eq(M.Kind({ name = "Food", spellId = 433, duration = 30 }, eating), nil, "Food itself: not a meal")
eq(M.Kind({ name = "Welcoming Campfire", spellId = 1229739, duration = 75 }, fireOn), nil, "the fire's timer: not a meal")
eq(M.Kind({ name = "Hearty Stew", spellId = 999001, duration = 900, sourceUnit = "player", isFromPlayerOrPlayerPet = true }, eating), "meal", "an unknown buff of your own while eating: a meal")
eq(M.Kind({ name = "Hearty Stew", spellId = 999001, duration = 900, sourceUnit = "player", isFromPlayerOrPlayerPet = true }, quiet), nil, "the same, not eating: not a meal")
eq(M.Kind({ name = "Power Word: Fortitude", spellId = 1243, duration = 1800, sourceUnit = "party1", isFromPlayerOrPlayerPet = false }, eating), nil, "a priest's blessing while eating: not a meal")
eq(M.Kind({ name = "Power Word: Fortitude", spellId = 1243, duration = 1800, isFromPlayerOrPlayerPet = false }, eating), nil, "a stranger's blessing while eating: not a meal")
eq(M.Kind({ name = "Quick Bite", spellId = 999002, duration = 20, sourceUnit = "player", isFromPlayerOrPlayerPet = true }, eating), nil, "a short one while eating: not a meal")
eq(M.Kind({ name = "Warmth", spellId = 999003, duration = 3600 }, fireOn), "fire", "an unknown buff as the fire's timer ends: the fire's")
eq(M.Kind({ name = "Warmth", spellId = 999003, duration = 3600, sourceUnit = "party2" }, fireOn), nil, "a party member's while by the fire: not the fire's")
eq(M.Kind({ name = "Warmth", spellId = 999003, duration = 3600 }, { eating = {}, fire = { at = 8 }, now = 10 }), "fire", "the timer seen 2 s ago: the fire's")
eq(M.Kind({ name = "Warmth", spellId = 999003, duration = 3600 }, { eating = {}, fire = { at = 0 }, now = 10 }), nil, "seen 10 s ago: not")

-- The reads: eating, then Well Fed ----------------------------------------------------------------
local shows = 0
local show = M.Show
M.Show = function(...) shows = shows + 1; return show(...) end
buffs = { { id = 1126, name = "Mark of the Wild", duration = 1800, source = "player", mine = true, instance = 1 } }
events.scripts.OnEvent(events, "PLAYER_ENTERING_WORLD")
eq(shows, 0, "login: the buffs on are not new")
buffs[#buffs + 1] = { id = 433, name = "Food", duration = 30, source = "player", mine = true, instance = 2 }
Aura()
eq(shows, 0, "sitting down to eat: nothing")
clock = clock + 10
buffs[#buffs + 1] = { id = 19705, name = "Well Fed", duration = 900, source = "player", mine = true, instance = 3,
    desc = "Increases Stamina and Spirit by 4 for 15 min." }
Aura()
eq(shows, 1, "Well Fed lands: the card")
eq(M.shown.kicker .. " / " .. M.shown.title, "A GOOD MEAL / Well Fed", "its words")
eq(M.shown.line1 .. " / " .. M.shown.line2, "+4 Stamina and Spirit / For 15 minutes", "what it gives, for how long")
eq(M.Phase(), "in", "rising")
local card
for _, f in ipairs(frames) do if f.name == "GamepadCompanionMealCard" then card = f end end
assert(card, "the card is a named frame")
eq(card.point[1] .. "/" .. tostring(card.point[2] == ns.Passage.Frame("meal")) .. "/" .. card.point[3], "BOTTOMLEFT/true/TOPLEFT",
    "above the meal's line, where Edit Mode put it")
eq(card.point[5], 8 - 10, "its foot 8 px over the line, 10 px low as it rises")
eq(card.icon.texture, "icon19705", "the buff's icon")
-- the same auras again (a refresh): no card
Aura()
Aura()
eq(shows, 1, "the same buffs read again: no new card")
buffs[3].duration = 900
Aura()
eq(shows, 1, "Well Fed refreshed: no new card")
-- the motion
M.Step(0.4)
eq(M.Phase(), "hold", "in place")
eq(card.point[5], 8, "resting 8 px over the line")
M.Step(5.1)
eq(M.Phase(), "out", "then fades")
M.Step(0.7)
eq(M.Phase(), nil, "gone")
-- standing up: Food goes, Well Fed stays
table.remove(buffs, 2)
Aura()
eq(shows, 1, "standing up: nothing")

-- not a meal: a buff from elsewhere
buffs[#buffs + 1] = { id = 1243, name = "Power Word: Fortitude", duration = 1800, source = nil, mine = false, instance = 4 }
Aura()
eq(shows, 1, "a stranger's blessing: no card")
buffs[#buffs + 1] = { id = 2457, name = "Battle Stance", duration = 0, source = "player", mine = true, instance = 5 }
Aura()
eq(shows, 1, "a stance of your own: no card")
-- a blessing while eating, from a party member
buffs[#buffs + 1] = { id = 430, name = "Drink", duration = 30, source = "player", mine = true, instance = 6 }
Aura()
buffs[#buffs + 1] = { id = 1244, name = "Power Word: Fortitude", duration = 1800, source = "party1", mine = false, instance = 7 }
Aura()
eq(shows, 1, "a party member's blessing while drinking: no card")
table.remove(buffs); table.remove(buffs)
Aura()

-- the fire: the timer, then its buff as the timer ends
buffs[#buffs + 1] = { id = 1229739, name = "Welcoming Campfire", duration = 75, source = nil, mine = false, instance = 8 }
Aura()
eq(shows, 1, "sitting by the fire: nothing")
clock = clock + 60
table.remove(buffs)
buffs[#buffs + 1] = { id = 999003, name = "Warmth of the Fire", duration = 3600, source = nil, mine = false, instance = 9,
    desc = "Increases Spirit by 4 for 1 hr." }
Aura()
eq(shows, 2, "the fire's buff lands as the timer ends: the card")
eq(M.shown.kicker .. " / " .. M.shown.title .. " / " .. M.shown.line1 .. " / " .. M.shown.line2, "BY THE FIRE / Warmth of the Fire / +4 Spirit / For an hour", "its words")
M.Step(10)
-- a buff a while after the fire: not the fire's
clock = clock + 30
buffs[#buffs + 1] = { id = 1126, name = "Mark of the Wild", duration = 1800, source = nil, mine = false, instance = 10 }
Aura()
eq(shows, 2, "a druid's blessing later: no card")

-- other units, combat, the card off
buffs[#buffs + 1] = { id = 19706, name = "Well Fed", duration = 900, source = "player", mine = true, instance = 11 }
Aura("target")
eq(shows, 2, "another unit's auras: nothing")
combat = true
Aura()
eq(shows, 2, "in combat: not read")
combat = false
Aura()
eq(shows, 3, "out of combat: read, the meal shows")
char.mealCard = false
buffs[#buffs + 1] = { id = 19708, name = "Well Fed", duration = 900, source = "player", mine = true, instance = 12 }
Aura()
eq(shows, 4, "off: asked") -- (Show is asked, says no)
eq(M.shown.title, "Well Fed", "off: the last card's words stay")
eq(select(2, pcall(function() return show("meal", { name = "Well Fed", duration = 900 }) end)), nil, "off: nothing shown")
char.mealCard = nil
eq(M.Enabled(), true, "on by default")

-- a loading screen: what's on is not new
buffs[#buffs + 1] = { id = 19709, name = "Well Fed", duration = 900, source = "player", mine = true, instance = 13 }
events.scripts.OnEvent(events, "PLAYER_ENTERING_WORLD")
eq(shows, 4, "after a loading screen: the buffs on are not new")

-- a hearthstone, no loading screen: the buffs sent again under new instance ids, a read
-- with none between (2026-11-23: Well Fed's card after a hearth)
for _, b in ipairs(buffs) do b.expires = clock + b.duration - 300 end
Aura()
local kept = buffs
buffs = {}
Aura()
buffs = kept
for i, b in ipairs(buffs) do b.instance = 100 + i end
Aura()
eq(shows, 4, "after a hearthstone: Well Fed running 5 min is not new")
-- eaten again later: a fresh Well Fed still shows
table.remove(buffs)
Aura()
buffs[#buffs + 1] = { id = 19709, name = "Well Fed", duration = 900, source = "player", mine = true, instance = 200,
    expires = clock + 899, desc = "Attack Power is increased by 20. Spirit is increased by 10. A long third line of nothing." }
Aura()
eq(shows, 5, "a fresh Well Fed: the card")
eq(M.shown.line1, "+20 Attack Power · +10 Spirit", "its gains")
buffs[#buffs].desc = nil
local T = ns.FishingToast
T.FillSlip(card, { kicker = "A GOOD MEAL", title = "Well Fed", line1 = "+4 Spirit" }, "icon")
eq(card.line1.width .. "/" .. card.line1.size, "0/12", "a line that fits: as it was")
-- a line too long for the paper: a point smaller, then cut at the paper's edge
T.FillSlip(card, { kicker = "A GOOD MEAL", title = "Well Fed", line1 = string.rep("x", 60) }, "icon")
eq(card.line1.size, 11, "a long line: a point smaller")
eq(card.line1.width, 280 - (14 + 46) - 14, "and cut at the paper's edge")

-- Edit Mode: a sample rests over the player frame
M.EditMode(true)
eq(M.shown.title, "Well Fed", "the sample")
M.Step(60)
eq(M.Phase() ~= "out" and M.Phase() ~= nil, true, "the sample stays while editing")
M.EditMode(false)
eq(M.Phase(), "out", "edit mode over: it goes")

-- The wait: a buff food's ten seconds, the fire's minute, on the passage (no card) ------------
local FED = "Restores 1392 health over 27 sec. Must remain seated while eating. If you spend at least 10 seconds eating you will become well fed and gain 12 Stamina and Spirit for 15 min."
local f = M.FoodBuff(FED)
eq(f and (f.wait .. " / " .. f.title .. " / " .. f.gives), "10 / Well Fed / +12 Stamina and Spirit", "a buff food's text: the wait, the buff, its gain")
eq(M.FoodBuff("Restores 61 health over 18 sec. Must remain seated while eating."), nil, "plain food: no wait")
eq(M.FoodBuff("Restores 151 mana over 18 sec. Must remain seated while drinking."), nil, "water: no wait")
f = M.FoodBuff("Restores 1933 health over 27 sec. Must remain seated while eating. If you spend at least 10 seconds eating you will gain 10 Strength for 10 min.")
eq(f and (f.wait .. " / " .. tostring(f.title) .. " / " .. f.gives), "10 / nil / +10 Strength", "a food naming its own buff")
eq(M.FoodBuff(""), nil, "no text yet: nil")
eq(M.Clock(9.98) .. " / " .. M.Clock(0.02) .. " / " .. M.Clock(-1) .. " / " .. M.Clock(60), "0:10 / 0:00 / 0:00 / 1:00", "the time to go")
local ws = M.WaitSpec("meal", "Well Fed", "+12 Stamina and Spirit", "icon", 100, 110, 104)
eq(ws.title .. " / " .. ws.clock .. " / " .. ws.sub .. " / " .. ws.frac, "Well Fed / 0:06 / +12 Stamina and Spirit / 0.4", "a meal's wait: 4 s of 10")
ws = M.WaitSpec("fire", nil, nil, nil, 0, 60, 18)
eq(ws.title .. " / " .. ws.clock .. " / " .. ws.sub, "Camp Benefits / 0:42 / By the fire", "the fire's minute")
eq(P.Clock(125) .. " / " .. P.Clock(125, true) .. " / " .. P.Clock(-3), "2:05 / ~2:05 / 0:00", "the passage's clock")

M.EditMode(false); M.Step(10)
buffs = {}
events.scripts.OnEvent(events, "PLAYER_ENTERING_WORLD")
Aura()
local n0 = shows
-- plain food: nothing
DESCS[433] = "Restores 61 health over 18 sec. Must remain seated while eating."
buffs = { { id = 433, name = "Food", duration = 18, expires = clock + 18, source = "player", mine = true, instance = 300 } }
Aura()
eq(M.Waiting(), nil, "plain food: no wait")
eq(shows, n0, "and no card")
buffs = {}; Aura()
-- a buff food: the passage at once (no card), the way filling, the seconds counting
local passage
for _, fr in ipairs(frames) do if fr.name == "GamepadCompanionPassageMeal" then passage = fr end end
DESCS[24869] = FED
NAMES[24869] = "Food"
M.Reset(); Aura()
local phase0 = M.Phase()
buffs = { { id = 24869, name = "Food", duration = 27, expires = clock + 27, source = "player", mine = true, instance = 301 } }
Aura()
check(M.Waiting() ~= nil, "a buff food: the wait")
eq(P.Owner(), "meal", "on the passage")
eq(M.Phase(), phase0, "no card while waiting")
for _, fr in ipairs(frames) do if fr.name == "GamepadCompanionPassageMeal" then passage = fr end end
assert(passage, "the passage is a named frame")
P.Step(0.1)
eq(passage.title.text .. " / " .. passage.clock.text .. " / " .. passage.sub.text, "Well Fed / 0:10 / +12 Stamina and Spirit", "its words")
eq(passage.point[1] .. "/" .. passage.point[3] .. "/" .. passage.point[4] .. "/" .. passage.point[5], "BOTTOMLEFT/BOTTOMLEFT/36/284", "at the bottom left, its own spot over the lure float's")
clock = clock + 4; M.Tick(); P.Step(0.1)
eq(passage.clock.text, "0:06", "4 s on: 6 to go")
eq(math.floor(passage.flown.width + 0.5), math.floor(184 * 0.4 + 0.5), "the way 40% gone")
clock = clock + 6
buffs[#buffs + 1] = { id = 19705, name = "Well Fed", duration = 900, expires = clock + 900, source = "player", mine = true, instance = 302,
    desc = "Increases Stamina and Spirit by 12 for 15 min." }
Aura()
eq(shows, n0 + 1, "Well Fed lands: its card, a short toast")
eq(M.Waiting(), nil, "the wait over")
eq(P.Owner(), nil, "the passage goes")
eq(M.shown.line2, "For 15 minutes", "the buff's own words")
M.Step(0.4); M.Step(6)
eq(M.Phase(), "out", "then it fades as before")
M.Step(1); P.Step(10)
eq(passage.shown, false, "the passage faded away")
-- stood up early: the passage goes
buffs = {}; Aura()
buffs = { { id = 24869, name = "Food", duration = 27, expires = clock + 27, source = "player", mine = true, instance = 303 } }
Aura()
check(M.Waiting() ~= nil, "eating again (Well Fed gone): the wait")
clock = clock + 5
buffs = {}; Aura()
eq(M.Waiting(), nil, "stood up at 5 s: no wait")
eq(P.Owner(), nil, "the passage goes")
P.Step(10)
-- the buff never comes: the passage goes a moment after the wait
buffs = { { id = 24869, name = "Food", duration = 27, expires = clock + 27, source = "player", mine = true, instance = 304 } }
Aura()
clock = clock + 10 + M.LATE + 0.5; M.Tick()
eq(M.Waiting(), nil, "no buff by the end: no wait")
eq(P.Owner(), nil, "the passage goes")
P.Step(10)
eq(shows, n0 + 1, "and no buff card")
Aura()
eq(M.Waiting(), nil, "the same eating read again: not waited on twice")
-- Well Fed still on, eaten again: the wait, and its refresh lands it
buffs = { { id = 19705, name = "Well Fed", duration = 900, expires = clock + 300, source = "player", mine = true, instance = 305 } }
Aura()
buffs[2] = { id = 24869, name = "Food", duration = 27, expires = clock + 27, source = "player", mine = true, instance = 306 }
Aura()
check(M.Waiting() ~= nil, "eating with Well Fed on: the wait")
clock = clock + 10
buffs[1].expires = clock + 900
Aura()
eq(shows, n0 + 2, "Well Fed renewed: its card")
M.Step(10)
-- a fight: the wait goes
buffs = {}; Aura()
buffs = { { id = 24869, name = "Food", duration = 27, expires = clock + 27, source = "player", mine = true, instance = 307 } }
Aura()
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
eq(M.Waiting(), nil, "a fight: no wait")
M.Step(1)
-- the fire's minute: up with the fire's words, its benefits on or not
buffs = { { id = 1229739, name = "Welcoming Campfire", duration = 60, expires = clock + 60, instance = 308, icon = "fire" } }
Aura()
local fw = M.Waiting()
eq(fw and fw.kind, "fire", "the fire's minute: the wait")
P.Step(0.1)
eq(passage.title.text .. " / " .. passage.clock.text .. " / " .. passage.sub.text, "Camp Benefits / 1:00 / By the fire", "its words")
eq(passage.icon.texture, "icon1229739", "the timer's icon")
clock = clock + 60
buffs = { { id = 1300001, name = "Camp Benefits", duration = 3600, expires = clock + 3600, instance = 309,
    desc = "Gained the following camp benefits:\nFaction Banner: Spirit increased by 14." } }
Aura()
eq(shows, n0 + 3, "the benefits land: their card")
eq(M.shown.line1, "+14 Spirit", "what they give")
M.Step(10)
buffs[2] = { id = 1229739, name = "Welcoming Campfire", duration = 60, expires = clock + 64, instance = 310 }
Aura()
-- the next minute, the benefits on: the wait again (2026-11-25: Camp Benefits stays on an hour
-- and is renewed each minute sat, so a wait only without it never showed)
local fw2 = M.Waiting()
eq(fw2 and fw2.kind, "fire", "the next minute, the benefits on: the wait")
P.Step(0.1)
eq(passage.clock.text, "1:04", "its time")
clock = clock + 64
buffs[1].expires = clock + 3600
table.remove(buffs, 2)
Aura()
eq(shows, n0 + 3, "the benefits renewed: no card each minute")
eq(M.Waiting(), nil, "the minute's done")
local function traced(s)
    local t = GamepadCompanionTraceDB and GamepadCompanionTraceDB.meal or {}
    for i = #t, 1, -1 do if t[i]:find(s, 1, true) then return true end end
    return false
end
check(traced("fire: 1229739 Welcoming Campfire, 1:04 left -> wait"), "written down: the fire's minute")
check(traced("fire: Camp Benefits renewed"), "written down: the benefits renewed")
P.Step(10)

-- the fire's timer the buff list leaves out: asked for by its id
do
    M.Reset(); buffs = {}; Aura()
    local hidden = { name = "Welcoming Campfire", spellId = 1229739, icon = "fire", duration = 60, expirationTime = clock + 60, auraInstanceID = 320 }
    C_UnitAuras.GetPlayerAuraBySpellID = function(id) if id == 1229739 then return hidden end end
    Aura()
    eq(M.Waiting() and M.Waiting().kind, "fire", "the timer by its id: the wait")
    hidden = nil
    Aura()
    eq(M.Waiting(), nil, "stood up: no wait")
    C_UnitAuras.GetPlayerAuraBySpellID = nil
    P.Step(10)
end

-- Forever's buff foods: the eating aura is bread's (Food 1127: "Restores 841 health over 27
-- sec."); the item used or its "Nutritious Food" cast says it (MealFoods.lua, 2026-11-25)
local FOREVER = "Restores 2065 health over 30 sec. Must remain seated while eating. If you spend at least 10 sec eating, you will become well fed and gain 20 Strength for 15 min. Additionally, experience gained from kills is increased by 5%."
f = M.FoodBuff(FOREVER)
eq(f and (f.wait .. " / " .. f.title .. " / " .. f.gives), "10 / Well Fed / +20 Strength", "Forever's text: '10 sec eating,'")
eq(M.ItemFood(250071) and M.ItemFood(250071).gives, "+20 Strength", "Steaming Stag Steak: on the list")
eq(select(2, M.ItemFood(250071)), "list", "known by the list")
eq(M.ItemFood(4599, "Cured Ham Steak\nUse: Restores 1392 health over 27 sec. Must remain seated while eating."), nil, "a plain food item: no buff")
eq(M.ItemFood(9999, "Odd Pie\nUse: " .. FOREVER).gives, "+20 Strength", "an unlisted buff food: its tooltip")
eq(M.SpellFood(1248401) and M.SpellFood(1248401).gives, "+20 Strength", "Nutritious Food's spell: on the list")
eq(M.SpellFood(1127, "Restores 841 health over 27 sec.  Must remain seated while eating."), nil, "bread's Food spell: no buff")
local n = 0
for _ in pairs(M.BUFF_FOODS) do n = n + 1 end
check(n >= 100, "the list holds Forever's buff foods (" .. n .. ")")
for item, e in pairs(M.BUFF_FOODS) do
    check(type(e[1]) == "number" and e[1] > 0 and type(e[2]) == "string" and e[2]:sub(1, 1) == "+", "list entry " .. item)
end
do
    M.Reset(); buffs = {}; Aura(); P.Step(10)
    DESCS[1127] = "Restores 841 health over 27 sec.  Must remain seated while eating."
    NAMES[1127] = "Food"
    -- plain food: bread's aura, nothing used that says a buff
    buffs = { { id = 1127, name = "Food", duration = 27, expires = clock + 27, source = "player", mine = true, instance = 500 } }
    Aura()
    eq(M.Waiting(), nil, "bread: no wait")
    clock = clock + 30; buffs = {}; Aura()
    -- a buff food from an action button: the item first, then the aura
    M.ItemUsed(250071)
    eq(M.Waiting(), nil, "used, not eating yet: no wait")
    buffs = { { id = 1131, name = "Food", duration = 30, expires = clock + 30, source = "player", mine = true, instance = 501 } }
    DESCS[1131] = "Restores 2065 health over 30 sec.  Must remain seated while eating."
    Aura()
    eq(M.Waiting() and M.Waiting().kind, "meal", "a buff food on bread's aura: the wait")
    P.Step(0.1)
    eq(passage.title.text .. " / " .. passage.clock.text .. " / " .. passage.sub.text, "Well Fed / 0:10 / +20 Strength", "its words")
    check(traced("eat: item 250071 (list) -> buff, wait 10"), "written down: the item")
    check(traced("eat: 1131 Food -> wait 0:10"), "written down: the wait")
    clock = clock + 10
    buffs[2] = { id = 1243969, name = "Well Fed", duration = 900, expires = clock + 900, source = "player", mine = true, instance = 502 }
    local before = shows
    Aura()
    eq(shows, before + 1, "Well Fed lands: the toast")
    eq(M.Waiting(), nil, "the wait over")
    M.Step(10); P.Step(10)
    -- the aura first, then the cast (the spell's own text)
    buffs = {}; Aura()
    buffs = { { id = 1131, name = "Food", duration = 30, expires = clock + 30, source = "player", mine = true, instance = 503 } }
    Aura()
    eq(M.Waiting(), nil, "bread's aura alone: no wait")
    events.scripts.OnEvent(events, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1248401)
    eq(M.Waiting() and M.Waiting().kind, "meal", "then Nutritious Food's cast: the wait")
    -- a cast long after the eating began: not this eating's
    buffs = {}; Aura(); P.Step(10)
    buffs = { { id = 1131, name = "Food", duration = 30, expires = clock + 30, source = "player", mine = true, instance = 504 } }
    Aura()
    clock = clock + 8
    events.scripts.OnEvent(events, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1248401)
    eq(M.Waiting(), nil, "a cast 8 s into bread: not this eating's")
    buffs = {}; Aura(); P.Step(10)
    -- a plain spell cast: nothing
    events.scripts.OnEvent(events, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1127)
    buffs = { { id = 1127, name = "Food", duration = 27, expires = clock + 27, source = "player", mine = true, instance = 505 } }
    Aura()
    eq(M.Waiting(), nil, "bread eaten, bread cast: no wait")
    buffs = {}; Aura(); P.Step(10)
end

-- The sleeping bag: laid out, a minute to each Well-Rested stack, three at most
do
    M.Reset(); buffs = {}; Aura(); P.Step(10)
    local resting = false
    IsResting = function() return resting end
    local before = shows
    events.scripts.OnEvent(events, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 429961)
    local bw = M.Waiting()
    eq(bw and bw.kind, "bag", "the bag laid out: the wait")
    P.Step(0.1)
    eq(passage.title.text .. " / " .. passage.clock.text .. " / " .. passage.sub.text, "Well-Rested / 1:00 / +1% XP", "its words")
    check(traced("bag: Unroll Bag -> wait 1:00"), "written down: the bag")
    resting = true
    events.scripts.OnEvent(events, "PLAYER_UPDATE_RESTING")
    clock = clock + 60
    buffs = { { id = 429959, name = "Well-Rested", duration = 7200, expires = clock + 7200, source = "player", mine = true, instance = 600, count = 1 } }
    Aura()
    eq(shows, before, "Well-Rested: no card")
    check(traced("bag: Well-Rested 1/3"), "written down: the stack")
    bw = M.Waiting()
    eq(bw and bw.kind, "bag", "resting on: the next minute")
    P.Step(0.1)
    eq(passage.sub.text, "+2% XP", "the next stack's words")
    clock = clock + 60
    buffs[1].count = 2; buffs[1].expires = clock + 7200
    Aura()
    clock = clock + 60
    buffs[1].count = 3; buffs[1].expires = clock + 7200
    Aura()
    eq(M.Waiting(), nil, "three stacks: no more wait")
    -- up from the bag mid-minute: the wait goes
    buffs = {}; Aura()
    events.scripts.OnEvent(events, "PLAYER_UPDATE_RESTING")
    check(M.Waiting() ~= nil, "back in the bag (resting): the wait")
    resting = false
    events.scripts.OnEvent(events, "PLAYER_UPDATE_RESTING")
    eq(M.Waiting(), nil, "up from the bag: no wait")
    -- long after the bag: resting at an inn is not the bag's
    clock = clock + 30 * 60
    resting = true
    events.scripts.OnEvent(events, "PLAYER_UPDATE_RESTING")
    eq(M.Waiting(), nil, "an inn later: no wait")
    IsResting = nil
    P.Step(10)
end

io.write(("MealCard: %d checks, %d failures\n"):format(checks, failures))
if failures > 0 then os.exit(1) end
