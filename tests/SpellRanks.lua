-- Spell ranks on the pad's slots: unpinned slots follow the highest rank,
-- pinned stay, a busy cursor or combat waits, login catches up, a lower rank
-- dropped by hand pins.
-- lua5.1 tests/SpellRanks.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game ------------------------------------------------------------------------------
-- Frost Armor ranks 1-5, Fireball (no ranks shown), Hearthstone an item
local SPELLS = {
    [168] = { "Frost Armor", 1 }, [7300] = { "Frost Armor", 2 }, [7301] = { "Frost Armor", 3 },
    [7302] = { "Frost Armor", 4 }, [7320] = { "Frost Armor", 5 },
    [133] = { "Fireball" },
}
local known = { [168] = true, [7300] = true, [7301] = true, [133] = true }
local combat, cursor = false, nil
local actions = {}          -- slot -> { kind, id }
local placed = 0

InCombatLockdown = function() return combat end
GetCursorInfo = function() if cursor then return cursor.kind, cursor.id end end
ClearCursor = function() cursor = nil end
IsSpellKnown = function(id) return known[id] == true end
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellSubtext = function(id) local s = SPELLS[id]; return s and s[2] and ("Rank " .. s[2]) or "" end,
    -- (by name: the highest rank known, as the client)
    GetSpellInfo = function(x)
        if type(x) == "number" then return SPELLS[x] and { name = SPELLS[x][1], spellID = x } end
        local best, rank
        for id, s in pairs(SPELLS) do
            if s[1] == x and known[id] and (s[2] or 0) >= (rank or -1) then best, rank = id, s[2] or 0 end
        end
        return best and { name = x, spellID = best }
    end,
    PickupSpell = function(id) cursor = { kind = "spell", id = id } end,
}
GetActionInfo = function(slot) local a = actions[slot]; if a then return a.kind, a.id end end
PlaceAction = function(slot)
    if not cursor then return end
    local old = actions[slot]
    actions[slot] = { kind = cursor.kind, id = cursor.id }
    placed = placed + 1
    cursor = old and { kind = old.kind, id = old.id } or nil   -- (the old action on the cursor, as the game)
end
C_GamepadUI = { GetFirstGamepadActionStorageSlotIndex = function() return 200 end,
    IsValidGamepadActionStorageSlotIndex = function(i) return i >= 200 and i < 216 end }
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
-- The spellbook lists every rank known, lowest first
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function()
        local n = 0
        for _ in pairs(known) do n = n + 1 end
        return { name = "Frost", itemIndexOffset = 0, numSpellBookItems = n }
    end,
    GetSpellBookItemInfo = function(slot)
        local ids = {}
        for id in pairs(known) do ids[#ids + 1] = id end
        table.sort(ids)
        local id = ids[slot]
        return id and { spellID = id, name = SPELLS[id][1], itemType = 1 }
    end,
}

local db = {}
local ns = { Shared = { CharDB = function() return db end } }
assert(loadfile(root .. "/SpellRanks.lua"))("GamepadCompanion", ns)
local R = ns.SpellRanks
local function Learn(id) known[id] = true; R.OnEvent("SPELLS_CHANGED") end

-- Ranks -----------------------------------------------------------------------------
eq(R.Highest(168), 7301, "highest known rank")
eq(#R.Ranks(7300), 3, "three ranks known")
eq(R.Highest(133), 133, "a spell without ranks: itself")

-- Login: ranks trained before are caught ----------------------------------------
actions[200] = { kind = "spell", id = 168 }      -- Frost Armor 1, never upgraded
actions[201] = { kind = "spell", id = 7300 }     -- rank 2, pinned on purpose
actions[202] = { kind = "item", id = 6948 }
actions[203] = { kind = "spell", id = 133 }
actions[50] = { kind = "spell", id = 168 }       -- a normal bar: not ours
db.spellPins = { [201] = 7300 }
R.OnEvent("PLAYER_ENTERING_WORLD")               -- (no C_Timer: at once)
check(R.ready, "ready after login")
eq(actions[200].id, 7301, "login: rank 1 -> rank 3")
eq(actions[201].id, 7300, "login: pinned rank 2 stays")
eq(actions[202].id, 6948, "an item untouched")
eq(actions[203].id, 133, "a spell without ranks untouched")
eq(actions[50].id, 168, "outside the gamepad range: untouched")
eq(cursor, nil, "nothing left on the cursor")

-- A new rank trained ------------------------------------------------------------
Learn(7302)
eq(actions[200].id, 7302, "trained: rank 3 -> rank 4")
eq(actions[201].id, 7300, "trained: pinned stays")
eq(cursor, nil, "cursor clear after the upgrade")
eq(R.Label(200), "Highest rank", "label: Highest")
eq(R.Label(201), "Rank 2", "label: Rank 2")
eq(R.Label(202), nil, "label: none for an item")

-- Cursor busy: nothing done, done once it is free --------------------------------
cursor = { kind = "item", id = 2589 }
local before = placed
Learn(7320)
eq(placed, before, "cursor busy: no placement")
eq(actions[200].id, 7302, "cursor busy: slot unchanged")
check(cursor and cursor.id == 2589, "cursor busy: what you hold stays")
check(R.Pending(), "cursor busy: pending")
cursor = nil
R.OnEvent("CURSOR_CHANGED")
eq(actions[200].id, 7320, "cursor free: upgraded")
check(not R.Pending(), "nothing pending")

-- Combat: waits for its end -------------------------------------------------------
known[7320] = nil
actions[200] = { kind = "spell", id = 7302 }
R.OnEvent("ACTIONBAR_SLOT_CHANGED", 200)     -- (rank 4 now the highest: follows)
check(db.spellPins[200] == nil, "the highest dropped by hand: not pinned")
combat = true
Learn(7320)
eq(actions[200].id, 7302, "in combat: unchanged")
check(R.Pending(), "in combat: pending")
combat = false
R.OnEvent("PLAYER_REGEN_ENABLED")
eq(actions[200].id, 7320, "after combat: upgraded")

-- By hand: a lower rank pins, the highest follows -------------------------------
actions[204] = { kind = "spell", id = 168 }
R.OnEvent("ACTIONBAR_SLOT_CHANGED", 204)
eq(db.spellPins[204], 168, "rank 1 dropped by hand: pinned")
Learn(7320)
eq(actions[204].id, 168, "pinned by hand: stays")
actions[204] = { kind = "spell", id = 7320 }
R.OnEvent("ACTIONBAR_SLOT_CHANGED", 204)
eq(db.spellPins[204], nil, "the highest dropped: follows")
actions[201] = { kind = "item", id = 6948 }
R.OnEvent("ACTIONBAR_SLOT_CHANGED", 201)
eq(db.spellPins[201], nil, "something else there: the pin drops")
actions[51] = { kind = "spell", id = 168 }
R.OnEvent("ACTIONBAR_SLOT_CHANGED", 51)
eq(db.spellPins[51], nil, "a normal bar slot: never pinned")

-- The rank control's choices, and setting them --------------------------------------
actions[205] = { kind = "spell", id = 7320 }
local list, at = R.Choices(205)
eq(#list, 6, "five ranks and Highest")
eq(list[1].label, "Rank 1", "lowest first")
eq(list[#list].label, "Highest", "Highest last")
eq(at, #list, "unpinned: Highest chosen")
check(R.Set(205, 7300), "pin rank 2")
eq(actions[205].id, 7300, "pinned: rank 2 placed")
eq(db.spellPins[205], 7300, "pinned: saved")
eq(cursor, nil, "pin: cursor clear")
list, at = R.Choices(205)
eq(list[at].label, "Rank 2", "control shows Rank 2")
Learn(7320)
eq(actions[205].id, 7300, "pinned: kept on a scan")
check(R.Set(205, nil), "back to Highest")
eq(actions[205].id, 7320, "Highest: top rank placed")
eq(db.spellPins[205], nil, "Highest: no pin")
cursor = { kind = "item", id = 1 }
check(not R.Set(205, 168), "cursor busy: no pin")
eq(actions[205].id, 7320, "cursor busy: unchanged")
cursor = nil
combat = true
check(not R.Set(205, 168), "combat: no pin")
combat = false

io.write(("SpellRanks: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
