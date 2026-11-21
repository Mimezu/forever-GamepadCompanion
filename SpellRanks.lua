-- Spell ranks on the pad's bar slots: a spell follows every rank you train
-- ("Highest", the default), unless its slot is pinned to a rank on purpose.
--
-- The gamepad bars are the game's own action slots in the gamepad storage
-- range (C_GamepadUI.GetFirstGamepadActionStorageSlotIndex). Classic upgrades
-- ranks on its normal bars when you train; slots in this range keep the old
-- rank (seen in play, not proven in Blizzard's code). So after a spell is
-- learned, and once after login, unpinned spell slots get the highest known
-- rank. Out of combat only (deferred to its end), never with something on
-- the cursor (retried when the cursor is free).
--
-- Pins: GamepadCompanionCharDB.spellPins[storage slot] = the pinned spell ID.
-- A pin holds only while the slot has that spell; anything else there drops it.
-- A spell dropped on a slot by hand: its highest rank follows (no pin), a
-- lower rank is pinned (you dragged that rank on purpose).
local _, ns = ...
local R = {}
ns.SpellRanks = R

local SPAN = 256    -- slots looked at from the first gamepad slot (each checked with the client)

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function InCombat() return InCombatLockdown and InCombatLockdown() and true or false end
local function Cursor() return GetCursorInfo and GetCursorInfo() ~= nil end

local function Pins()
    local db = ns.Shared.CharDB()
    if type(db.spellPins) ~= "table" then db.spellPins = {} end
    return db.spellPins
end
R.Pins = Pins

-- Spellbook ------------------------------------------------------------------------

local function SpellName(id)
    local name = Call(C_Spell and C_Spell.GetSpellName, id)
    if not name then
        local info = Call(C_Spell and C_Spell.GetSpellInfo, id)
        name = type(info) == "table" and info.name or Call(GetSpellInfo, id)
    end
    return name
end

-- "Rank 3" -> 3 (nil for a spell without ranks)
function R.RankOf(id)
    local text = Call(C_Spell and C_Spell.GetSpellSubtext, id) or Call(GetSpellSubtext, id)
    local n = type(text) == "string" and text:match("(%d+)")
    return n and tonumber(n) or nil
end

local function Known(id)
    if IsSpellKnown then return Call(IsSpellKnown, id) and true or false end
    return true
end

-- name -> { spell IDs known, lowest rank first }; rebuilt on SPELLS_CHANGED
local book
local function Book()
    if book then return book end
    book = {}
    local function Add(id, name)
        if not id or not name then return end
        local list = book[name]
        if not list then list = {}; book[name] = list end
        for _, have in ipairs(list) do if have == id then return end end
        list[#list + 1] = id
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
            local _, _, first, count = Call(GetSpellTabInfo, i)
            for slot = (first or 0) + 1, (first or 0) + (count or 0) do
                local kind, id = Call(GetSpellBookItemInfo, slot, "spell")
                if kind == "SPELL" then Add(id, Call(GetSpellBookItemName, slot, "spell")) end
            end
        end
    end
    for _, list in pairs(book) do
        local order = {}
        for i, id in ipairs(list) do order[id] = i end
        table.sort(list, function(a, b)
            local ra, rb = R.RankOf(a) or 0, R.RankOf(b) or 0
            if ra ~= rb then return ra < rb end
            return order[a] < order[b]
        end)
    end
    return book
end
function R.Forget() book = nil end

-- The ranks of a spell you know, lowest first (one entry for a spell without ranks)
function R.Ranks(id)
    local name = id and SpellName(id)
    local out = {}
    for _, other in ipairs(name and Book()[name] or {}) do
        if Known(other) then out[#out + 1] = other end
    end
    -- (the name lookup gives the highest rank known, when the book hides lower ones)
    local info = name and Call(C_Spell and C_Spell.GetSpellInfo, name)
    local top = type(info) == "table" and tonumber(info.spellID) or nil
    local function Has(x) for _, v in ipairs(out) do if v == x then return true end end end
    if top and Known(top) and not Has(top) then out[#out + 1] = top end
    if id and Known(id) and not Has(id) then out[#out + 1] = id end
    if #out > 1 then
        table.sort(out, function(a, b) return (R.RankOf(a) or 0) < (R.RankOf(b) or 0) end)
    end
    return out
end

-- The highest rank you know of this spell (nil: none known)
function R.Highest(id)
    local ranks = R.Ranks(id)
    return ranks[#ranks]
end

-- Slots ----------------------------------------------------------------------------

local function Slots()
    local first = Call(C_GamepadUI and C_GamepadUI.GetFirstGamepadActionStorageSlotIndex)
    local out = {}
    if type(first) ~= "number" then return out end
    for slot = first, first + SPAN - 1 do
        if Call(C_GamepadUI.IsValidGamepadActionStorageSlotIndex, slot) == true then out[#out + 1] = slot end
    end
    return out
end
R.Slots = Slots

local function SpellAt(slot)
    local kind, id = Call(GetActionInfo, slot)
    if kind == "spell" and type(id) == "number" then return id end
end

local seen = {}      -- slot -> spell ID last seen there (to tell a hand-made change)
local placing = 0    -- (our own placements: not by hand)

-- Puts a spell on a slot; the replaced action never stays on the cursor
local function Put(slot, id)
    if InCombat() or Cursor() then return false end
    placing = placing + 1
    Call(C_Spell and C_Spell.PickupSpell or PickupSpell, id)
    local ok = Cursor()
    if ok then Call(PlaceAction, slot) end
    Call(ClearCursor)
    placing = placing - 1
    local now = SpellAt(slot)
    seen[slot] = now
    return ok and now == id
end

-- The pinned spell of a slot, or nil (a stale pin is dropped)
function R.Pinned(slot)
    local pins = Pins()
    local pin = pins[slot]
    if pin == nil then return nil end
    if SpellAt(slot) ~= pin then pins[slot] = nil; return nil end
    return pin
end

-- "Highest" or "Rank 2", for a spell slot; nil for anything else
function R.Label(slot)
    local id = SpellAt(slot)
    if not id then return nil end
    local pin = R.Pinned(slot)
    if not pin then return "Highest rank" end
    local n = R.RankOf(pin)
    return n and ("Rank " .. n) or "Pinned"
end

-- The rank choice of a slot: nil = Highest (follows), or a known spell ID to pin.
-- Returns true when the slot holds it.
function R.Set(slot, id)
    local current = SpellAt(slot)
    if not current or InCombat() or Cursor() then return false end
    local pins = Pins()
    if id == nil then
        pins[slot] = nil
        local top = R.Highest(current)
        if top and top ~= current then return Put(slot, top) end
        return true
    end
    if id ~= current and not Put(slot, id) then return false end
    pins[slot] = id
    return true
end

-- The choices for a slot's rank control, lowest first, Highest last:
-- { { id = <spell>|nil, label = "Rank 1" | "Highest" }, ... } and the chosen index
function R.Choices(slot)
    local id = SpellAt(slot)
    if not id then return nil end
    local ranks = R.Ranks(id)
    local list = {}
    for _, r in ipairs(ranks) do
        local n = R.RankOf(r)
        if n then list[#list + 1] = { id = r, label = "Rank " .. n } end
    end
    list[#list + 1] = { id = nil, label = "Highest" }
    local pin, at = R.Pinned(slot), #list
    for i, c in ipairs(list) do if pin and c.id == pin then at = i end end
    return list, at
end

-- Upgrade --------------------------------------------------------------------------

local pending = false
-- Every unpinned spell slot to its highest rank. Returns the slots changed,
-- or nil when it had to wait (combat, or the cursor busy).
function R.Upgrade()
    if InCombat() or Cursor() then pending = true; return nil end
    pending = false
    local changed = {}
    for _, slot in ipairs(Slots()) do
        local id = SpellAt(slot)
        if id and not R.Pinned(slot) then
            local top = R.Highest(id)
            local have, want = R.RankOf(id), top and R.RankOf(top)
            if top and top ~= id and have and want and want > have then
                if Put(slot, top) then changed[#changed + 1] = slot end
                if Cursor() then pending = true; break end   -- (never leave it: stop)
            end
        end
        seen[slot] = SpellAt(slot)
    end
    if #changed > 0 and ns.Refresh then pcall(ns.Refresh) end
    return changed
end
function R.Pending() return pending end

-- A slot changed by hand: a lower rank dropped there is pinned; the highest
-- (or anything else) follows
function R.SlotChanged(slot)
    if placing > 0 or type(slot) ~= "number" then return end
    if Call(C_GamepadUI and C_GamepadUI.IsValidGamepadActionStorageSlotIndex, slot) ~= true then return end
    local id = SpellAt(slot)
    if seen[slot] == id then return end
    seen[slot] = id
    local pins = Pins()
    if not id then pins[slot] = nil; return end
    if pins[slot] == id then return end
    local top = R.Highest(id)
    local have, want = R.RankOf(id), top and R.RankOf(top)
    if have and want and have < want then pins[slot] = id else pins[slot] = nil end
end

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
R.Soon = Soon

R.ready = false
function R.OnEvent(event, arg)
    if event == "PLAYER_ENTERING_WORLD" then
        if R.ready then return end
        -- (the bars load a moment into the world: then catch up on ranks trained before)
        Later(3, function()
            R.Forget()
            -- (what each slot holds now: a later change is told from it)
            for _, slot in ipairs(Slots()) do seen[slot] = SpellAt(slot) end
            R.Upgrade()
            R.ready = true
        end)
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
        R.Forget()
        if R.ready then Soon() end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "CURSOR_CHANGED" or event == "CURSOR_UPDATE" then
        if pending and R.ready and not Cursor() then Soon() end
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        if R.ready then R.SlotChanged(arg) end
    end
end

if CreateFrame then
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE",
        "PLAYER_REGEN_ENABLED", "CURSOR_CHANGED", "CURSOR_UPDATE", "ACTIONBAR_SLOT_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, arg) R.OnEvent(event, arg) end)
end
