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
GetNumSkillLines = function() return 2 end
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

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
