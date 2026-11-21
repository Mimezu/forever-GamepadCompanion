-- Spell ranks on the pad's bar slots: a slot holding a spell's top rank
-- follows it to the next rank you train ("Highest"); a slot holding a lower
-- rank keeps it ("Rank 2": chosen, whoever put it there).
--
-- The gamepad bars are the game's own action slots in the gamepad storage
-- range (C_GamepadUI.GetFirstGamepadActionStorageSlotIndex). Classic upgrades
-- ranks on its normal bars when you train; slots in this range keep the old
-- rank (seen in play, not proven in Blizzard's code).
--
-- How a slot is told to follow: per character, the top rank known of each
-- spell at the last pass (GamepadCompanionRanksDB.top["name#icon"], a per-character
-- saved variable of its own, so Controls profiles never share or copy it).
-- On a pass, a slot moves up only if it holds that previous top rank and a
-- higher rank of the same spell is now known. The first pass on a character
-- only records the top ranks: nothing moves.
--
-- Passes: after a spell is learned, and once after login when the bars have
-- loaded. Out of combat only (deferred to its end), never with something on
-- the cursor (retried when it is free); the replaced rank never stays on the
-- cursor. A placement the game refuses is not retried until the spellbook
-- changes, and its spell's top rank is not moved on (so it is retried then).
local _, ns = ...
local R = {}
ns.SpellRanks = R

local SPAN = 256          -- slots looked at from the first gamepad slot (each checked with the client)
local BAR_TRIES = 30      -- login: seconds to wait for the bars to hold anything

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function InCombat() return InCombatLockdown and InCombatLockdown() and true or false end
local function Cursor() return GetCursorInfo and GetCursorInfo() ~= nil end

-- Per character, never in a Controls profile
local function DB()
    if type(GamepadCompanionRanksDB) ~= "table" then GamepadCompanionRanksDB = { version = 1 } end
    local db = GamepadCompanionRanksDB
    if type(db.top) ~= "table" then db.top = {} end
    return db
end
R.DB = DB

-- Spells ---------------------------------------------------------------------------

local function SpellName(id)
    local name = Call(C_Spell and C_Spell.GetSpellName, id)
    if not name then
        local info = Call(C_Spell and C_Spell.GetSpellInfo, id)
        name = type(info) == "table" and info.name or Call(GetSpellInfo, id)
    end
    return name
end

local function Icon(id)
    return Call(C_Spell and C_Spell.GetSpellTexture, id) or Call(GetSpellTexture, id)
end

-- One spell's ranks share a name and an icon: its family's key
local function Family(id, name)
    name = name or SpellName(id)
    return name and (name .. "#" .. tostring(Icon(id) or "")) or nil
end

-- "Rank 3" -> 3 (nil for a spell without ranks); an ID's rank never changes
local rankMemo = {}
function R.RankOf(id)
    if id == nil then return nil end
    if rankMemo[id] then return rankMemo[id] end
    local text = Call(C_Spell and C_Spell.GetSpellSubtext, id) or Call(GetSpellSubtext, id)
    local n = type(text) == "string" and tonumber(text:match("(%d+)")) or nil
    if n then rankMemo[id] = n end   -- (nil not kept: the spell's data may not be in yet)
    return n
end
local RankOf = R.RankOf

local function Known(id)
    if IsSpellKnown then return Call(IsSpellKnown, id) and true or false end
    return true
end

-- family -> { known ranked spell IDs, lowest rank first }, and the book's
-- signature (it changes only when the spells known change)
local book, signature
local function Book()
    if book then return book end
    book = {}
    local count, sum = 0, 0
    local function Add(id, name)
        if not id or not name or not RankOf(id) or not Known(id) then return end
        local key = Family(id, name)
        local list = book[key]
        if not list then list = {}; book[key] = list end
        for _, have in ipairs(list) do if have == id then return end end
        list[#list + 1] = id
        count, sum = count + 1, sum + id
    end
    local sb = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    if sb and sb.GetNumSpellBookSkillLines then
        for i = 1, Call(sb.GetNumSpellBookSkillLines) or 0 do
            local info = Call(sb.GetSpellBookSkillLineInfo, i)
            if info then
                for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = Call(sb.GetSpellBookItemInfo, slot, bank)
                    if item and item.itemType == spellType and not item.isPassive then
                        Add(item.spellID or item.actionID, item.name)
                    end
                end
            end
        end
    else
        for i = 1, Call(GetNumSpellTabs) or 0 do
            local _, _, first, n = Call(GetSpellTabInfo, i)
            for slot = (first or 0) + 1, (first or 0) + (n or 0) do
                local kind, id = Call(GetSpellBookItemInfo, slot, "spell")
                if kind == "SPELL" then Add(id, Call(GetSpellBookItemName, slot, "spell")) end
            end
        end
    end
    for _, list in pairs(book) do
        table.sort(list, function(a, b) return rankMemo[a] < rankMemo[b] end)   -- (Add ranked them all)
    end
    signature = count .. ":" .. sum
    return book
end
function R.Forget() book = nil end
function R.Signature() Book(); return signature end

-- The known ranks of the same spell as id, lowest first: same name, ranked,
-- same icon. Empty for a spell without ranks.
function R.Ranks(id)
    local own = RankOf(id)
    local name = own and SpellName(id)
    if not name then return {} end
    local key = Family(id, name)
    local out, has = {}, {}
    local function Take(x)
        if not x or has[x] or not RankOf(x) or Family(x) ~= key then return end   -- (same name, another spell)
        has[x] = true
        out[#out + 1] = x
    end
    for _, x in ipairs(Book()[key] or {}) do Take(x) end
    -- (the name lookup gives the top rank known, when the book hides lower ones)
    local info = Call(C_Spell and C_Spell.GetSpellInfo, name)
    local top = type(info) == "table" and tonumber(info.spellID) or nil
    if top and Known(top) then Take(top) end
    table.sort(out, function(a, b) return rankMemo[a] < rankMemo[b] end)
    return out
end

-- The top known rank of the same spell when it is higher than id; else nil
function R.Higher(id)
    local have = RankOf(id)
    if not have then return nil end
    local ranks = R.Ranks(id)
    local top = ranks[#ranks]
    if top and top ~= id and RankOf(top) > have then return top end
end

-- Slots ----------------------------------------------------------------------------

local slots
local function Slots()
    if slots then return slots end
    local first = Call(C_GamepadUI and C_GamepadUI.GetFirstGamepadActionStorageSlotIndex)
    local out = {}
    if type(first) ~= "number" then return out end
    for slot = first, first + SPAN - 1 do
        if Call(C_GamepadUI.IsValidGamepadActionStorageSlotIndex, slot) == true then out[#out + 1] = slot end
    end
    if #out > 0 then slots = out end
    return out
end

local function SpellAt(slot)
    local kind, id = Call(GetActionInfo, slot)
    if kind == "spell" and type(id) == "number" then return id end
end

-- Puts a spell on a slot; the replaced action never stays on the cursor.
-- True when the slot holds it.
local function Put(slot, id)
    if InCombat() or Cursor() then return false end
    Call(C_Spell and C_Spell.PickupSpell or PickupSpell, id)
    if Cursor() then Call(PlaceAction, slot) end
    Call(ClearCursor)
    return SpellAt(slot) == id
end

-- The rank control's choices for a slot, lowest first: the lower ranks, then
-- Highest (the top rank, which follows). The index of what the slot holds.
function R.Choices(slot)
    local id = SpellAt(slot)
    if not id or not RankOf(id) then return nil end
    local ranks = R.Ranks(id)
    local list, at = {}, nil
    for i, r in ipairs(ranks) do
        list[#list + 1] = { id = r, label = i == #ranks and "Highest" or ("Rank " .. RankOf(r)) }
        if r == id then at = #list end
    end
    if not at then
        -- (a rank no longer known: shown where it falls)
        local entry, pos = { id = id, label = "Rank " .. RankOf(id) }, #list + 1
        for i, c in ipairs(list) do if RankOf(c.id) > RankOf(id) then pos = i; break end end
        table.insert(list, pos, entry)
        at = pos
    end
    return list, at
end

-- Puts another known rank of the slot's spell there (never another spell)
function R.Set(slot, id)
    local current = SpellAt(slot)
    if not current or not id or InCombat() or Cursor() then return false end
    if id == current then return true end
    local ok = false
    for _, r in ipairs(R.Ranks(current)) do if r == id then ok = true end end
    if not ok then return false end
    return Put(slot, id)
end

-- Pass -----------------------------------------------------------------------------

local pending = false
local failed = {}         -- slot -> { id = the rank refused, sig = the book then }
local lastSig             -- the book at the last whole pass
R.ready = false

-- Moves up every slot that held its spell's previous top rank. Returns the
-- slots changed, or nil when it had to wait (combat, or the cursor busy).
function R.Upgrade()
    if InCombat() or Cursor() then pending = true; return nil end
    pending = false
    local spells = Book()
    local sig = signature
    if sig == lastSig then return {} end    -- (the spells known didn't change)
    local db = DB()
    local top, changed, held = db.top, {}, {}
    if db.seeded then
        for _, slot in ipairs(Slots()) do
            local id = SpellAt(slot)
            local name = id and RankOf(id) and Family(id)
            if name and top[name] == id then
                local higher = R.Higher(id)
                local refused = failed[slot]
                if higher and refused and refused.id == higher and refused.sig == sig then
                    held[name] = true     -- (refused already: wait for the book to change)
                elseif higher then
                    if Put(slot, higher) then
                        changed[#changed + 1] = slot
                        failed[slot] = nil
                    else
                        failed[slot] = { id = higher, sig = sig }
                        held[name] = true
                    end
                    if Cursor() then pending = true; return changed end
                end
            end
        end
    end
    -- the top ranks now known (a spell whose slot was refused keeps its old one)
    for key, list in pairs(spells) do
        if not held[key] then top[key] = list[#list] end
    end
    db.seeded = true
    lastSig = sig
    if #changed > 0 and ns.Refresh then pcall(ns.Refresh) end
    return changed
end
function R.Pending() return pending end

-- Events ---------------------------------------------------------------------------

local function Later(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

local queued = false
local function Soon()
    if queued then return end
    queued = true
    Later(0.5, function() queued = false; R.Upgrade() end)
end

-- Login: wait until a gamepad slot holds something (or the wait runs out)
local function BarsLoaded()
    for _, slot in ipairs(Slots()) do
        if Call(GetActionInfo, slot) then return true end
    end
    return false
end

local started = false
local function CatchUp(tries)
    if not BarsLoaded() and tries < BAR_TRIES then
        Later(1, function() CatchUp(tries + 1) end)
        return
    end
    R.Forget()
    R.ready = true
    R.Upgrade()
end

function R.OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" then
        if started then return end
        started = true
        CatchUp(0)
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
        R.Forget()
        if R.ready then Soon() end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "CURSOR_CHANGED" then
        if pending and R.ready and not Cursor() then Soon() end
    end
end

if CreateFrame then
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE",
        "PLAYER_REGEN_ENABLED", "CURSOR_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event) R.OnEvent(event) end)
end
