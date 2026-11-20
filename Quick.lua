-- Quick use: food, drink, potions, trinkets, a random mount or pet, the
-- fishing pole swap, for any binder (zones, gestures, pad buttons) as
-- quick:<key>. The bags are read out
-- of combat (bags change, combat ends, level up) and the best items picked
-- (TouchModel's QuickOrder); a changed pick re-applies the binders. In combat
-- the last pick stays.
local _, ns = ...
local T, Sh = ns.TouchModel, ns.Shared
local Q = {}
ns.Quick = Q

local picks, scanned, pending = {}, false, false
local missing = {}           -- items whose info hadn't come yet at the last scan

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g end
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- Well Fed food, from its tooltip
local function BuffFood(id)
    local info = C_TooltipInfo and Call(C_TooltipInfo.GetItemByID, id)
    for _, line in ipairs(info and info.lines or {}) do
        local text = type(line.leftText) == "string" and line.leftText:lower() or ""
        if text:find("well fed", 1, true) then return true end
    end
    return false
end

-- The bags' items, as QuickOrder wants them (one entry per item)
function Q.Scan()
    local items, seen = {}, {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return items end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, tonumber((Call(C_Container.GetContainerNumSlots, bag))) or 0 do
            local info = Call(C_Container.GetContainerItemInfo, bag, slot)
            local id = info and tonumber(info.itemID)
            if id and not seen[id] then
                seen[id] = true
                local _, _, _, _, _, classID, subclass = Call(C_Item.GetItemInfoInstant, id)
                local name, _, quality, ilvl, reqLevel = Call(C_Item.GetItemInfo or GetItemInfo, id)
                -- (not known yet: its info will come; only that one calls for a new scan)
                if not name then missing[id] = true end
                local item = { id = id, name = name, classID = classID, subclass = subclass,
                    spell = Call(C_Item.GetItemSpell or GetItemSpell, id), quality = quality, ilvl = ilvl,
                    reqLevel = reqLevel, usable = Call(C_Item.IsUsableItem, id) and true or false }
                local kinds = T.QuickKinds(item)
                if kinds then
                    if kinds.food then item.buff = BuffFood(id) end
                    items[#items + 1] = item
                end
            end
        end
    end
    return items
end

local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

-- Picks the best items again; re-applies the binders when a pick changed
function Q.Refresh()
    if InCombat() then pending = true; return false end
    pending = false
    local items, level = Q.Scan(), tonumber((Call(UnitLevel, "player")))
    local changed = not scanned
    for _, key in ipairs({ "food", "drink", "health", "mana" }) do
        local ids = T.QuickOrder(key, items, level)
        if not (picks[key] and Same(picks[key], ids)) then changed = true end
        picks[key] = ids
    end
    scanned = true
    -- (the pole swap: its macro follows the bags and the hands)
    local fish = Q.FishMacro()
    if fish ~= picks.fish then changed = true end
    picks.fish = fish
    if changed then
        for _, m in ipairs({ ns.Keys, ns.Touch, ns.Gestures, ns.SlotMacros }) do
            if m and m.Apply then pcall(m.Apply) end
        end
        if ns.Touch and ns.Touch.RefreshPreview then pcall(ns.Touch.RefreshPreview) end
    end
    return changed
end

function Q.Picks(key) return picks[key] end

-- The pole swap's macro (MimezuFishing.lua, shared with Halo); in combat the last one
function Q.FishMacro()
    local lib = _G.MimezuFishing
    if InCombat() or not (lib and lib.Macro) then return picks.fish end
    local ok, text = pcall(lib.Macro)
    return ok and text or nil
end

-- The macro a key runs now (the binders' lookup.quick)
function Q.Macro(key)
    if key == "fish" then
        if not InCombat() then picks.fish = Q.FishMacro() end
        return picks.fish
    end
    if not scanned and not InCombat() then
        scanned = true   -- (the first scan: no re-apply, the binder asking is applying)
        local items, level = Q.Scan(), tonumber((Call(UnitLevel, "player")))
        for _, k in ipairs({ "food", "drink", "health", "mana" }) do picks[k] = T.QuickOrder(k, items, level) end
    end
    return T.QuickMacro(key, picks[key])
end
Sh.lookup.quick = Q.Macro

-- name, icon for a key: the item picked (or the slot's trinket), else the
-- key's label and icon; empty: its "none" word
function Q.Look(key)
    local q = T.QUICK_BY_KEY[key]
    if not q then return key end
    if q.slot then
        local id = Call(GetInventoryItemID, "player", q.slot)
        if not id then return q.none, q.icon end
        local name = Call(C_Item.GetItemNameByID, id) or Call(GetItemInfo, id)
        return name or q.label, Call(GetInventoryItemTexture, "player", q.slot) or q.icon
    end
    if q.run then return q.label, q.icon end
    if q.swap then
        local lib = _G.MimezuFishing
        if lib and lib.Look then
            local ok, name, icon = pcall(lib.Look)
            if ok then return name, icon or q.icon end
        end
        return q.label, q.icon
    end
    local id = picks[key] and picks[key][1]
    if not id then return q.none, q.icon end
    local name = Call(C_Item.GetItemNameByID, id) or Call(GetItemInfo, id)
    local icon = Call(C_Item.GetItemIconByID, id) or Call(GetItemIcon, id)
    return name or q.label, icon or q.icon
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP",
    "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end
local wait = 0
events:SetScript("OnEvent", function(_, event, itemID)
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    -- (the hands changed in combat: the pole swap's macro after it)
    if event == "PLAYER_EQUIPMENT_CHANGED" and InCombat() then pending = true; return end
    -- (item info arrives in bursts, mostly for others' items: only ours that
    -- were missing, once, a moment later)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not missing[tonumber(itemID) or 0] then return end
        missing[tonumber(itemID)] = nil
        if wait > 0 then return end
        wait = 1
        C_Timer.After(1, function() wait = 0; Q.Refresh() end)
        return
    end
    Q.Refresh()
end)
