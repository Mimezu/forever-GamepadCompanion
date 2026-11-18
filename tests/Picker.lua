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
