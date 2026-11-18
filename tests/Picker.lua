-- The action picker: one tile a spell (the spellbook lists every rank)
-- lua5.1 tests/Picker.lua .
local root = arg[1] or "."
local ns = { OptionsSkin = {}, TouchModel = {}, Shared = {} }
assert(loadfile(root .. "/Picker.lua"))("GamepadCompanion", ns)
local P = ns.Picker
local book = {
    { action = "spell:498", name = "Divine Protection" },
    { action = "spell:853", name = "Hammer of Justice" },
    { action = "spell:5573", name = "Divine Protection" },
    { action = "spell:5588", name = "Hammer of Justice" },
}
local one = P.OneRank(book)
assert(#one == 2, "one tile a spell")
assert(one[1].action == "spell:5573" and one[2].action == "spell:5588", "the highest rank, in the book's order")
io.write("PASS: action picker: one tile a spell, its highest rank" .. string.char(10))

-- Quick use, Mounts and Pets: run with the journals stubbed; every icon a path or a file id
do
    local tns = { Shared = {} }
    assert(loadfile(root .. "/TouchModel.lua"))("GamepadCompanion", tns)
    local T2 = { QUICK = tns.TouchModel and tns.TouchModel.QUICK or {} }
    local ns2 = { OptionsSkin = {}, TouchModel = T2, Shared = { HaloRings = function() return {} end },
        Touch = { ActionLook = function() return nil, nil end } }
    assert(#T2.QUICK >= 8, "quick use entries: " .. #T2.QUICK)
    assert(loadfile(root .. "/Picker.lua"))("GamepadCompanion", ns2)
    C_MountJournal = { GetMountIDs = function() return { 7, 8 } end, GetMountInfoByID = function(id)
        if id == 7 then return "Swift Horse", 23229, 132261, nil, nil, nil, nil, nil, nil, nil, true end
        return "Not Mine", 1, 1, nil, nil, nil, nil, nil, nil, nil, false
    end }
    C_PetJournal = { GetOwnedPetIDs = function() return { "BattlePet-0-1" } end,
        GetPetInfoByPetID = function() return nil, "Whiskers", nil, nil, nil, nil, nil, "Cat", 132599 end }
    local cats = ns2.Picker.Categories({ accepts = { quick = true, spell = true, pet = true } })
    local by = {}
    for _, c in ipairs(cats) do by[c.key] = c end
    assert(by.quick and #by.quick.list == #T2.QUICK, "Quick use listed")
    for _, e in ipairs(by.quick.list) do
        assert(type(e.icon) == "string" and e.icon:find("^Interface\\Icons\\[%w_]+$"), "quick icon path: " .. tostring(e.icon))
    end
    assert(by.mounts and #by.mounts.list == 1 and by.mounts.list[1].action == "spell:23229", "collected mounts only")
    assert(by.pets and by.pets.list[1].name == "Whiskers" and by.pets.list[1].action == "pet:BattlePet-0-1", "pets: their own name")
    C_MountJournal, C_PetJournal = nil, nil
    io.write("PASS: action picker: Quick use, Mounts and Pets listed, icon paths whole" .. string.char(10))
end
