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
        if k == "SetTexture" then return function(self, v) self.texture = v end end
        if k == "SetAlpha" then return function(self, v) self.alpha = v end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
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
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellDescription = function() return "" end }
-- the player's buffs, in order: { id, name, duration, source, mine, instance, desc }
local buffs = {}
C_UnitAuras = { GetBuffDataByIndex = function(unit, i)
    local b = buffs[i]
    if not b then return nil end
    return { name = b.name, spellId = b.id, icon = "icon" .. b.id, duration = b.duration, sourceUnit = b.source,
        isFromPlayerOrPlayerPet = b.mine, auraInstanceID = b.instance }
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
assert(loadfile(root .. "/MealCard.lua"))("GamepadCompanion", ns)
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
eq(card.point[1] .. "/" .. tostring(card.point[2] == PlayerFrame) .. "/" .. card.point[3], "BOTTOM/true/TOP", "above the player frame")
eq(card.point[5], 8 - 20 - 10, "its foot 8 px over the portrait (the frame's 20 px of air), 10 px low as it rises")
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
eq(card.point[5], 8 - 20, "resting 8 px over the portrait")
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

-- Edit Mode: a sample rests over the player frame
M.EditMode(true)
eq(M.shown.title, "Well Fed", "the sample")
M.Step(60)
eq(M.Phase() ~= "out" and M.Phase() ~= nil, true, "the sample stays while editing")
M.EditMode(false)
eq(M.Phase(), "out", "edit mode over: it goes")

io.write(("MealCard: %d checks, %d failures\n"):format(checks, failures))
if failures > 0 then os.exit(1) end
