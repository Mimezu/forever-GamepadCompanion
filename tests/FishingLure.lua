-- The fishing lure: the pick (yours while it's in the bags, else the best the
-- skill allows), the bags read (counts, the tooltip over the table), the time
-- words and a lure's whole time, and the float's text.
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
local bags, tooltips, enchant, skill = {}, {}, nil, 75
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
    return "Fishing", false, nil, skill
end
GetWeaponEnchantInfo = function() if enchant then return true, enchant * 1000 end return false end
local char = {}
local ns = { Shared = { CharDB = function() return char end } }
MimezuFishing = { PoleEquipped = function() return true end }
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
eq(L.AtCap(75, nil, 2), false, "no cap to read, 75, 2 fish: too soon to say")
eq(L.AtCap(75, nil, 3), true, "no cap to read, 75, 3 fish with no point (every catch counts at 75): train")
eq(L.AtCap(150, nil, 11), false, "no cap to read, 150: a point is one in four, 11 isn't enough")
eq(L.AtCap(150, nil, 12), true, "150, 12 fish: train")
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
w = L.Whisper(120, nil, nil, 120, 150, 1, nil, true)
eq(w, "Skill too low here", "fish keep getting away here")
eq(L.Wary({ 10 }, 20), false, "one escape: nothing said (an early press loses a fish too)")
eq(L.Wary({ 10, 50 }, 60), false, "two: still nothing")
eq(L.Wary({ 10, 50, 90 }, 100), true, "three within 10 minutes: skill too low")
eq(L.Wary({ 10, 50, 90 }, 700), false, "ten minutes after the first: two left, nothing said")
eq(L.Wary(nil, 100), false, "none")
w, c = L.Whisper(120, nil, nil, 120, 150, 1, 2, false)
eq(w, "Fishing 120  " .. dot .. "  2 fish a point", "otherwise: the skill and the pace")
eq(c[1] .. "," .. c[2], "1,1", "coloured by its odds (yellow at 120)")
eq(L.Whisper(120, nil, nil, nil, nil, 3, nil, false), nil, "nothing known: nothing said")

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
for _, f in ipairs(frames) do local sc = rawget(f, "scripts"); if sc and sc.OnEvent then ev = sc.OnEvent end end
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
eq(L.WhisperNow(now), "Skill too low here", "three lost here: skill too low")
GetSubZoneText = function() return "The Sepulcher" end
eq(L.WhisperNow(now), "Fishing 121  " .. dot .. "  2 fish a point", "another water: the skill and the pace")

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

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
