-- Spell ranks on the pad's slots: a slot at its spell's top rank follows the
-- next rank trained; a lower rank stays (chosen). First login only records;
-- late bars wait; a refused placement waits for the spellbook to change;
-- per character, never in a Controls profile; never another spell.
-- lua5.1 tests/SpellRanks.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game ------------------------------------------------------------------------------
-- Frost Armor 1-5 (icon 1); another "Frost Armor" with a rank of its own (icon 99,
-- say a pet's); Fireball without ranks; Flash Heal 1-3 (icon 3)
local SPELLS = {
    [168] = { "Frost Armor", 1, 1 }, [7300] = { "Frost Armor", 2, 1 }, [7301] = { "Frost Armor", 3, 1 },
    [7302] = { "Frost Armor", 4, 1 }, [7320] = { "Frost Armor", 5, 1 },
    [8888] = { "Frost Armor", 9, 99 },
    [133] = { "Fireball", nil, 2 },
    [2061] = { "Flash Heal", 1, 3 }, [9472] = { "Flash Heal", 2, 3 }, [9473] = { "Flash Heal", 3, 3 },
}
local known = { [168] = true, [7300] = true, [7301] = true, [8888] = true, [133] = true,
    [2061] = true, [9472] = true }
local combat, cursor = false, nil
local actions = {}          -- slot -> { kind, id }
local refuse = {}           -- slot -> true: PlaceAction does nothing there
local placed, subtexts = 0, 0
local barsLoaded = true

InCombatLockdown = function() return combat end
GetCursorInfo = function() if cursor then return cursor.kind, cursor.id end end
ClearCursor = function() cursor = nil end
IsSpellKnown = function(id) return known[id] == true end
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellTexture = function(id) return SPELLS[id] and SPELLS[id][3] end,
    GetSpellSubtext = function(id)
        subtexts = subtexts + 1
        local s = SPELLS[id]; return s and s[2] and ("Rank " .. s[2]) or ""
    end,
    -- (by name: the highest rank known of any spell of that name, as the client may)
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
GetActionInfo = function(slot)
    if not barsLoaded then return nil end
    local a = actions[slot]; if a then return a.kind, a.id end
end
PlaceAction = function(slot)
    if not cursor or refuse[slot] then return end
    local old = actions[slot]
    actions[slot] = { kind = cursor.kind, id = cursor.id }
    placed = placed + 1
    cursor = old and { kind = old.kind, id = old.id } or nil   -- (the old action on the cursor, as the game)
end
C_GamepadUI = { GetFirstGamepadActionStorageSlotIndex = function() return 200 end,
    IsValidGamepadActionStorageSlotIndex = function(i) return i >= 200 and i < 216 end }
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function()
        local n = 0
        for _ in pairs(known) do n = n + 1 end
        return { name = "All", itemIndexOffset = 0, numSpellBookItems = n }
    end,
    GetSpellBookItemInfo = function(slot)
        local ids = {}
        for id in pairs(known) do ids[#ids + 1] = id end
        table.sort(ids)
        local id = ids[slot]
        return id and { spellID = id, name = SPELLS[id][1], itemType = 1 }
    end,
}
-- Timers run when the test says
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end

-- (the Controls profile's table: SpellRanks must never use it)
local ns = { Shared = { CharDB = function() error("SpellRanks read the Controls profile") end } }
local function Load()
    assert(loadfile(root .. "/SpellRanks.lua"))("GamepadCompanion", ns)
    return ns.SpellRanks
end
local R = Load()
local function Learn(id) known[id] = true; R.OnEvent("SPELLS_CHANGED"); RunTimers() end

-- Ranks -----------------------------------------------------------------------------
eq(R.Higher(168), 7301, "rank 1: rank 3 is higher")
eq(R.Higher(7301), nil, "the top rank: nothing higher")
eq(R.Higher(133), nil, "a spell without ranks: nothing")
eq(R.Higher(8888), nil, "another spell of the same name: not Frost Armor's ranks")
eq(#R.Ranks(7300), 3, "three Frost Armor ranks (not the other spell's)")
local before = subtexts
R.Forget(); R.Ranks(7300); R.Ranks(7300)
check(subtexts - before <= 12, "ranks read once per ID, not in the sort (" .. (subtexts - before) .. " reads)")

-- First login: late bars, then only the top ranks recorded -----------------------
GamepadCompanionRanksDB = nil
actions[200] = { kind = "spell", id = 168 }      -- Frost Armor 1: chosen (cheap)
actions[201] = { kind = "spell", id = 7301 }     -- Frost Armor 3: the top
actions[202] = { kind = "spell", id = 2061 }     -- Flash Heal 1: a downranked heal
actions[203] = { kind = "spell", id = 133 }
actions[204] = { kind = "item", id = 6948 }
actions[50] = { kind = "spell", id = 7301 }      -- a normal bar: not ours
barsLoaded = false
R.OnEvent("PLAYER_ENTERING_WORLD")
check(not R.ready, "late bars: not ready while the bars are empty")
RunTimers(); RunTimers()
check(not R.ready, "late bars: still waiting")
barsLoaded = true
RunTimers()
check(R.ready, "late bars: ready once a slot holds something")
local top = GamepadCompanionRanksDB.top
eq(top["Frost Armor#1"], 7301, "first login: Frost Armor's top recorded")
eq(top["Flash Heal#3"], 9472, "first login: Flash Heal's top recorded")
eq(top["Frost Armor#99"], 8888, "the other Frost Armor: its own family")
eq(actions[200].id, 168, "first login: rank 1 kept")
eq(actions[202].id, 2061, "first login: the downranked heal kept")
eq(placed, 0, "first login: nothing placed")

-- A new rank trained -----------------------------------------------------------
Learn(7302)
eq(actions[201].id, 7302, "trained: the top slot follows (3 -> 4)")
eq(actions[200].id, 168, "trained: rank 1 stays")
eq(actions[50].id, 7301, "trained: a normal bar untouched")
eq(actions[203].id, 133, "trained: a spell without ranks untouched")
eq(cursor, nil, "trained: nothing left on the cursor")
eq(top["Frost Armor#1"], 7302, "trained: the new top recorded")
Learn(9473)
eq(actions[202].id, 2061, "Flash Heal 3 trained: the downranked heal stays")

-- Rank chosen by hand earlier and the next rank: still only the top slot moves
actions[205] = { kind = "spell", id = 7302 }
actions[206] = { kind = "spell", id = 7300 }

-- Cursor busy: nothing done, done once it is free --------------------------------
cursor = { kind = "item", id = 2589 }
local p0 = placed
Learn(7320)
eq(placed, p0, "cursor busy: no placement")
eq(actions[201].id, 7302, "cursor busy: slot unchanged")
check(cursor and cursor.id == 2589, "cursor busy: what you hold stays")
check(R.Pending(), "cursor busy: pending")
cursor = nil
R.OnEvent("CURSOR_CHANGED"); RunTimers()
eq(actions[201].id, 7320, "cursor free: the top slot follows")
eq(actions[205].id, 7320, "cursor free: another top slot follows")
eq(actions[206].id, 7300, "cursor free: rank 2 stays")
check(not R.Pending(), "nothing pending")

-- Combat: waits for its end ---------------------------------------------------------
actions[207] = { kind = "spell", id = 9473 }
known[9474] = true; SPELLS[9474] = { "Flash Heal", 4, 3 }
combat = true
R.OnEvent("SPELLS_CHANGED"); RunTimers()
eq(actions[207].id, 9473, "in combat: unchanged")
check(R.Pending(), "in combat: pending")
combat = false
R.OnEvent("PLAYER_REGEN_ENABLED"); RunTimers()
eq(actions[207].id, 9474, "after combat: upgraded")

-- A placement the game refuses: not retried until the spellbook changes ---------
known[9475] = true; SPELLS[9475] = { "Flash Heal", 5, 3 }
refuse[207] = true
R.OnEvent("SPELLS_CHANGED"); RunTimers()
eq(actions[207].id, 9474, "refused: slot unchanged")
eq(cursor, nil, "refused: nothing on the cursor")
eq(top["Flash Heal#3"], 9474, "refused: the old top kept (so it is retried)")
local p1 = placed
local tries = 0
local place = PlaceAction
PlaceAction = function(slot) tries = tries + 1; return place(slot) end
R.OnEvent("SPELLS_CHANGED"); RunTimers()
R.OnEvent("SPELLS_CHANGED"); RunTimers()
eq(tries, 0, "refused: no retry while the spellbook is the same")
refuse[207] = nil
SPELLS[1459] = { "Arcane Intellect", 1, 4 }
Learn(1459)    -- (any other spell learned: the book changed)
check(tries >= 1, "book changed: retried")
eq(actions[207].id, 9475, "book changed: upgraded")
PlaceAction = place
check(placed > p1, "placed after the retry")

-- Per character, never in a Controls profile ------------------------------------
-- (ns.Shared.CharDB errors when read: getting here means it never was)
check(type(GamepadCompanionRanksDB) == "table", "kept in GamepadCompanionRanksDB (per character)")

-- The rank control's choices, and setting them --------------------------------------
actions[208] = { kind = "spell", id = 7320 }
local list, at = R.Choices(208)
eq(#list, 5, "four lower ranks and Highest")
eq(list[1].label, "Rank 1", "lowest first")
eq(list[#list].label, "Highest", "Highest last")
eq(at, #list, "the top: Highest")
eq(list[at - 1].label, "Rank 4", "'<' from Highest: the next rank down")
check(R.Set(208, list[at - 1].id), "set rank 4")
eq(actions[208].id, 7302, "rank 4 placed")
eq(cursor, nil, "set: cursor clear")
list, at = R.Choices(208)
eq(list[at].label, "Rank 4", "a lower rank: shown as its rank")
-- A slot behind (not following): never shown as Highest
actions[209] = { kind = "spell", id = 7300 }
list, at = R.Choices(209)
eq(list[at].label, "Rank 2", "a slot behind: its rank, not Highest")
check(R.Set(208, 7320), "back to Highest")
eq(actions[208].id, 7320, "Highest placed")
check(not R.Set(208, 8888), "never another spell of the same name")
check(not R.Set(208, 133), "never another spell")
eq(actions[208].id, 7320, "unchanged")
eq(R.Choices(203), nil, "no choices for a spell without ranks")
eq(R.Choices(204), nil, "no choices for an item")
cursor = { kind = "item", id = 1 }
check(not R.Set(208, 168), "cursor busy: nothing set")
eq(actions[208].id, 7320, "cursor busy: unchanged")
cursor = nil
combat = true
check(not R.Set(208, 168), "combat: nothing set")
combat = false

-- Next login: a rank trained while the addon was off is caught --------------------
local saved = GamepadCompanionRanksDB
actions = { [200] = { kind = "spell", id = 7320 }, [201] = { kind = "spell", id = 168 } }
known[7321] = true; SPELLS[7321] = { "Frost Armor", 6, 1 }
GamepadCompanionRanksDB = saved
timers = {}
R = Load()
R.OnEvent("PLAYER_ENTERING_WORLD"); RunTimers()
eq(actions[200].id, 7321, "next login: the top slot catches up")
eq(actions[201].id, 168, "next login: rank 1 stays")
-- Another character: its own table, starts by recording only
GamepadCompanionRanksDB = nil
actions = { [200] = { kind = "spell", id = 7300 } }
R = Load()
R.OnEvent("PLAYER_ENTERING_WORLD"); RunTimers()
eq(actions[200].id, 7300, "another character's first login: nothing moves")
check(GamepadCompanionRanksDB ~= saved, "another character: its own table")

io.write(("SpellRanks: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
