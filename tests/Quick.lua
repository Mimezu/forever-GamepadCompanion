-- Quick use: what a bag item is for, the best pick (conjured first, the best
-- next, buff food last), the macros, and combat keeping the last pick.
-- lua5.1 tests/Quick.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs ---------------------------------------------------------------------
local bags, info, combat, level, applied = {}, {}, false, 30, 0
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(self, _, f) self.handler = f end }
end
InCombatLockdown = function() return combat end
UnitLevel = function() return level end
C_Timer = { After = function(_, f) f() end }
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #bags or 0 end,
    GetContainerItemInfo = function(_, slot) return bags[slot] and { itemID = bags[slot] } or nil end,
}
C_Item = {
    GetItemInfoInstant = function(id) local i = info[id]; return id, nil, nil, nil, nil, i.classID, i.subclass end,
    GetItemInfo = function(id) local i = info[id]; return i.name, nil, i.quality or 1, i.ilvl or 1, i.reqLevel or 1 end,
    GetItemSpell = function(id) return info[id].spell end,
    IsUsableItem = function(id) return info[id].usable ~= false end,
    GetItemNameByID = function(id) return info[id] and info[id].name end,
    GetItemIconByID = function(id) return "icon" .. id end,
}
C_TooltipInfo = { GetItemByID = function(id)
    return { lines = { { leftText = info[id].buff and "Use: ... you will become well fed" or "Use: Restores health" } } }
end }

local ns = { Shared = { lookup = {} }, Keys = { Apply = function() applied = applied + 1 end } }
assert(loadfile(root .. "/TouchModel.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Quick.lua"))("GamepadCompanion", ns)
local T, Q = ns.TouchModel, ns.Quick

-- Items: food, water, potions ------------------------------------------------------
local function Food(id, name, reqLevel, extra)
    info[id] = { name = name, classID = 0, subclass = 5, spell = "Food", reqLevel = reqLevel }
    for k, v in pairs(extra or {}) do info[id][k] = v end
end
Food(4599, "Cured Ham Steak", 35)                 -- above level 30
Food(3771, "Wild Hog Shank", 25)
Food(4594, "Rockscale Cod", 15)
Food(1114, "Conjured Rye", 15)                      -- conjured, lower level
Food(12210, "Roast Raptor", 25, { buff = true })     -- Well Fed
Food(1645, "Moonberry Juice", 25, { spell = "Drink" })
Food(8077, "Conjured Mineral Water", 15, { spell = "Drink" })
Food(13724, "Enriched Manna Biscuit", 45, { spell = "Refreshment" })
info[929] = { name = "Healing Potion", classID = 0, subclass = 1, spell = "Healing Potion", reqLevel = 12 }
info[1710] = { name = "Greater Healing Potion", classID = 0, subclass = 1, spell = "Healing Potion", reqLevel = 21 }
info[3827] = { name = "Mana Potion", classID = 0, subclass = 1, spell = "Restore Mana", reqLevel = 22 }
info[5509] = { name = "Healthstone", classID = 0, subclass = 8, spell = "Healthstone" }
info[2459] = { name = "Swiftness Potion", classID = 0, subclass = 1, spell = "Speed" }
info[6948] = { name = "Hearthstone", classID = 15, subclass = 0, spell = "Hearthstone" }

-- What an item is for
local function Kinds(id)
    local i = info[id]
    local k = T.QuickKinds({ id = id, name = i.name, spell = i.spell, classID = i.classID, subclass = i.subclass })
    if not k then return "-" end
    local out = {}
    for _, key in ipairs({ "food", "drink", "health", "mana" }) do if k[key] then out[#out + 1] = key end end
    return table.concat(out, "+")
end
eq(Kinds(3771), "food", "food")
eq(Kinds(1645), "drink", "drink")
eq(Kinds(13724), "food+drink", "refreshment: both")
eq(Kinds(929), "health", "healing potion")
eq(Kinds(3827), "mana", "mana potion")
eq(Kinds(5509), "health", "healthstone")
eq(Kinds(2459), "-", "swiftness potion: none")
eq(Kinds(6948), "-", "hearthstone: none")

-- The order
local function Items(ids)
    local out = {}
    for _, id in ipairs(ids) do
        local i = info[id]
        out[#out + 1] = { id = id, name = i.name, spell = i.spell, classID = i.classID, subclass = i.subclass,
            reqLevel = i.reqLevel, buff = i.buff, usable = i.usable }
    end
    return out
end
local all = { 4599, 3771, 4594, 1114, 12210, 1645, 8077, 13724, 929, 1710, 3827, 5509 }
local food = T.QuickOrder("food", Items(all), 30)
eq(food[1], 1114, "food: conjured first")
eq(food[2], 3771, "food: then the highest level")
eq(food[#food], 12210, "food: buff food last")
check(not (food[1] == 4599 or food[2] == 4599 or food[3] == 4599 or food[4] == 4599), "food: above my level passed over")
eq(T.QuickOrder("food", Items({ 12210 }), 30)[1], 12210, "food: buff food when it's the only one")
local drink = T.QuickOrder("drink", Items(all), 30)
eq(drink[1], 8077, "drink: conjured water first")
eq(T.QuickOrder("health", Items(all), 30)[1], 5509, "health: healthstone first")
eq(T.QuickOrder("health", Items({ 929, 1710 }), 30)[1], 1710, "health: the best potion")
eq(#T.QuickOrder("mana", Items({ 929, 1645 }), 30), 0, "mana: none")
eq(#T.QuickOrder("drink", {}, 30), 0, "empty bags: no pick")

-- Macros
eq(T.QuickMacro("food", { 1114, 3771 }), "/use item:1114", "food: the best one only")
eq(T.QuickMacro("health", { 1710, 929 }), "/use item:1710\n/use item:929", "potions: a chain (one cooldown)")
eq(T.QuickMacro("health", { 5509, 1710 }), "/use item:5509", "a healthstone: no potion after it")
eq(T.QuickMacro("mana", {}), nil, "nothing: no macro")
eq(T.QuickMacro("trinket1"), "/use 13", "trinket 1")
eq(T.QuickMacro("trinket2"), "/use 14", "trinket 2")
eq(T.QuickMacro("mount"), "/run C_MountJournal.SummonByID(0)", "random favourite mount")
check(T.QuickMacro("pet"):find("SummonRandomPet", 1, true) ~= nil, "random favourite pet")
eq(T.MacroText("pet:BattlePet-0-000001", ns.Shared.lookup), '/run C_PetJournal.SummonPetByGUID("BattlePet-0-000001")', "a chosen pet")
eq(T.MacroText('pet:x")', ns.Shared.lookup), nil, "a bad pet id: nothing")
check(T.ValidAction("quick:food") and T.ACCEPTS.quick and T.ACCEPTS.pet, "quick and pet: every binder")

-- Runtime: picks from the bags, kept in combat -----------------------------------
bags = { 3771, 1645, 1710 }
eq(T.MacroText("quick:food", ns.Shared.lookup), "/use item:3771", "first ask: scanned")
eq(select(1, Q.Look("food")), "Wild Hog Shank", "icon and name: the pick")
eq(select(1, Q.Look("mana")), "No potion", "empty: quiet")
applied = 0
bags = { 1114, 3771, 1645, 1710 }
check(Q.Refresh(), "bags changed: new pick")
eq(applied, 1, "binders applied again")
eq(T.MacroText("quick:food", ns.Shared.lookup), "/use item:1114", "conjured picked")
combat = true
bags = { 3771 }
check(not Q.Refresh(), "in combat: no change")
eq(T.MacroText("quick:food", ns.Shared.lookup), "/use item:1114", "in combat: the last pick")
eq(applied, 1, "in combat: nothing applied")
combat = false
check(Q.Refresh(), "combat ends: picked again")
eq(T.MacroText("quick:food", ns.Shared.lookup), "/use item:3771", "after combat: what's left")
check(not Q.Refresh(), "same bags: nothing to apply")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
