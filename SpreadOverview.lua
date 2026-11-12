local _, ns = ...
local API = GamepadCompanionAPI
local overview, rows, captions = nil, {}, {}
local sceneProvider
local layerNames = { "Base (no trigger)", "Left trigger (LT)", "Right trigger (RT)", "Both triggers (LT + RT)" }
local positions = { {-92, 0}, {-58, 22}, {-24, 0}, {-58, -22},
    {25, 0}, {59, 22}, {93, 0}, {59, -22} }
local directions = { "left", "up", "right", "down" }
local faces = { Shapes = { "ps-square", "ps-triangle", "ps-circle", "ps-cross" },
    Letters = { "xbox-x", "xbox-y", "xbox-b", "xbox-a" },
    Reverse = { "xbox-y", "xbox-x", "xbox-a", "xbox-b" } }

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and ns.Model.Readable(value) then return value end
end

local function Integer(value)
    return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function RegisterSceneProvider()
    local provider = _G.FrameGambitAPI
    if not overview or not provider or provider == sceneProvider or type(provider.RegisterSceneProvider) ~= "function" then return end
    local ok, registered = pcall(provider.RegisterSceneProvider, {
        id = "gamepad_companion_spread", role = "action_bar_editor", cinematicKeep = true,
        resolve = function()
            -- GPC hides these frames when editing ends. Keep their hidden roots
            -- exempt too, so reopening never inherits a dormant blackout lease.
            local frames = { overview }
            for _, caption in ipairs(captions) do frames[#frames + 1] = caption end
            return frames
        end,
    })
    if ok and registered then sceneProvider = provider end
end

local function EmptyAtlas(index)
    if index <= 4 then return "gamepad-actionbar-squareslot-generic-dpad" .. directions[index] .. "-normal" end
    local manager = InputDeviceIconSetManager
    local set = manager and Call(manager.GetActiveInputDeviceIconSet, manager)
    local names = faces[set] or faces.Letters
    return "gamepad-actionbar-circleslot-" .. names[index - 4] .. "-normal"
end

local function Error(message)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(message, 1, 0.35, 0.2) end
end

local function Pickup(kind, id)
    if kind == "spell" then return (C_Spell and C_Spell.PickupSpell) or PickupSpell, id end
    if kind == "item" then return (C_Item and C_Item.PickupItem) or PickupItem, id end
    if kind == "macro" then return PickupMacro, id end
end

local function Editable(slot)
    if InCombatLockdown and InCombatLockdown() then Error("Not in combat"); return false end
    if not slot or not C_GamepadUI or Call(C_GamepadUI.IsValidGamepadActionStorageSlotIndex, slot) ~= true then return false end
    return true
end

local function Receive(button)
    if not Editable(button.slot) or not GetCursorInfo then return end
    local kind, id, _, spellID = GetCursorInfo()
    if not kind then return end
    local pick, incoming = Pickup(kind, kind == "spell" and spellID or id)
    if not pick or not incoming then Error("Spell, item or macro only"); return end
    local oldKind, oldID = GetActionInfo(button.slot)
    local oldPick, oldArg = Pickup(oldKind, oldID)
    if oldKind and not oldPick then Error("Move this action in Blizzard's editor"); return end
    local changed = false
    local ok, message = pcall(function()
        if oldKind then
            ClearCursor()
            PickupAction(button.slot)
            if GetActionInfo(button.slot) then error("Action not moved") end
            changed = true
            ClearCursor()
            pick(incoming)
            if not GetCursorInfo() then error("Action not picked up") end
        end
        PlaceAction(button.slot)
        -- Successful placement clears the cursor because we emptied the slot.
        if GetCursorInfo() or not GetActionInfo(button.slot) then error("Drop refused") end
    end)
    if not ok then
        if changed then
            ClearCursor()
            local restored = pcall(function() oldPick(oldArg); PlaceAction(button.slot) end)
            local restoredKind, restoredID = GetActionInfo(button.slot)
            if not restored or restoredKind ~= oldKind or restoredID ~= oldID then
                Error("Drop failed · old action on cursor")
                return
            end
        end
        if not GetCursorInfo() then pcall(pick, incoming) end
        Error(tostring(message))
        return
    end
    -- Keep the replaced action on the cursor, like a normal action-bar swap.
    if oldPick then pcall(oldPick, oldArg) end
    if ns.Refresh then ns.Refresh() end
end

-- The normal pages precede the fixed-size stance groups. Validate every slot
-- against the client rather than using absolute indices from another build.
local function Discover()
    local c = Constants and Constants.GamepadActionBarConstants
    local api = C_GamepadUI
    if not c or not api then return {} end
    local first = Call(api.GetFirstGamepadActionStorageSlotIndex)
    local pages, perPage, reserved = c.NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT,
        c.NUM_PAGEABLE_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT_STANDARD_PAGE,
        c.NUM_RESERVED_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT
    local count, size = c.NUM_GAMEPAD_STANCE_ACTION_BARS, c.NUM_SLOTS_PER_GAMEPAD_ACTION_BAR
    if not Integer(first) or not Integer(pages) or not Integer(perPage) or not Integer(reserved)
        or not Integer(count) or count > 12 or size ~= 8 or reserved >= perPage then return {} end
    local start = first + pages * (perPage - reserved)
    local result = {}
    for index = 1, count do
        local slot = start + (index - 1) * size
        local valid = true
        for offset = 0, size - 1 do
            if Call(api.IsValidGamepadActionStorageSlotIndex, slot + offset) ~= true then valid = false end
        end
        if valid then result[#result + 1] = { index = index, first = slot } end
    end
    return result
end

local function ActiveName()
    local count = Call(GetNumShapeshiftForms) or 0
    for index = 1, math.min(count, 20) do
        local ok, _, active, _, spell = pcall(GetShapeshiftFormInfo, index)
        if ok and ns.Model.Readable(active) and active and ns.Model.Readable(spell) then
            local info = C_Spell and Call(C_Spell.GetSpellInfo, spell)
            return info and info.name or Call(GetSpellInfo, spell)
        end
    end
end

local function Names()
    local guid = Call(UnitGUID, "player")
    if not guid then return {} end
    GamepadCompanionFormNames = GamepadCompanionFormNames or {}
    GamepadCompanionFormNames[guid] = GamepadCompanionFormNames[guid] or {}
    return GamepadCompanionFormNames[guid]
end

local function Text(parent, size)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetFontObject(size == "small" and "GameFontHighlightSmall" or "GameFontNormal")
    label:SetJustifyH("CENTER")
    return label
end

local function Ensure()
    if overview then return end
    overview = CreateFrame("Frame", nil, UIParent)
    overview:SetFrameStrata("LOW")
    overview:SetSize(240, 1)
    overview.title = Text(overview)
    overview.title:SetPoint("BOTTOM", overview, "TOP", 0, 12)
    overview.title:SetText("Form bars")
    overview.note = Text(overview, "small")
    overview.note:SetWidth(255)
    overview.note:SetText("Shift forms to name bars")
    for index = 1, 4 do
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetFrameStrata("LOW")
        holder:SetSize(300, 22)
        holder.text = Text(holder)
        holder.text:SetAllPoints()
        captions[index] = holder
    end
end

local function Row(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("Frame", nil, overview)
    row:SetSize(240, 116)
    row.label = Text(row)
    row.label:SetPoint("TOP", 0, 0)
    row.label:SetWidth(260)
    row.buttons = {}
    for buttonIndex, position in ipairs(positions) do
        -- Addon-owned editor widgets write storage only on an explicit drop.
        local button = CreateFrame("Button", nil, row)
        button:SetSize(buttonIndex <= 4 and 30 or 32, buttonIndex <= 4 and 30 or 32)
        button:SetPoint("CENTER", row, "TOP", position[1], position[2] - 64)
        local shape = buttonIndex <= 4 and "square" or "circle"
        button.shadow = button:CreateTexture(nil, "BACKGROUND", nil, -2)
        button.shadow:SetPoint("TOPLEFT", -4, 4)
        button.shadow:SetPoint("BOTTOMRIGHT", 4, -4)
        button.shadow:SetAtlas("gamepad-actionbar-" .. shape .. "slot-dropshadow")
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetAllPoints()
        button.background:SetAtlas(EmptyAtlas(buttonIndex))
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.mask = button:CreateMaskTexture()
        button.mask:SetAllPoints(button.icon)
        button.mask:SetAtlas(buttonIndex <= 4 and "SquareMask" or "CircleMask")
        button.icon:AddMaskTexture(button.mask)
        button.rim = button:CreateTexture(nil, "OVERLAY")
        button.rim:SetAllPoints()
        button.rim:SetAtlas("gamepad-actionbar-" .. shape .. "slot-border-normal")
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetAtlas("gamepad-actionbar-" .. shape .. "slot-border-hover")
        button:RegisterForDrag("LeftButton")
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnReceiveDrag", Receive)
        button:SetScript("OnClick", Receive)
        button:SetScript("OnDragStart", function(self)
            if Editable(self.slot) and not GetCursorInfo() then
                local ok = pcall(PickupAction, self.slot)
                if not ok then Error("Action not moved") end
                if ns.Refresh then ns.Refresh() end
            end
        end)
        button:SetScript("OnEnter", function(self)
            if not self.slot or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GetActionInfo and Call(GetActionInfo, self.slot) then GameTooltip:SetAction(self.slot)
            else GameTooltip:SetText("Empty form slot") end
                    GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        row.buttons[buttonIndex] = button
    end
    rows[index] = row
    return row
end

function ns.UpdateSpreadOverview(state)
    -- LOW strata keeps the spellbook above these surfaces. Register their
    -- editing role so Cinematic's root audit does not mistake them for HUD.
    RegisterSceneProvider()
    -- Observe the active form even when the editor is closed, so names remain
    -- available next time spread is opened. Do not assume form-list order maps
    -- to storage order (Cat stealth and Bear are separate bonus groups).
    local groups = Discover()
    local active = C_GamepadUI and Call(C_GamepadUI.GetFirstGamepadActionBarStorageSlotIndexForActiveStance)
    if C_ActionBar and Call(C_ActionBar.HasBonusActionBar) == false then active = nil end
    local names = Names()
    for _, group in ipairs(groups) do
        if active == group.first then
            local name = ActiveName()
            if type(name) == "string" then
                if Call(IsStealthed) then name = name .. " (stealth)" end
                names[group.first] = name
            end
        end
    end
    if not state.spread or not state.enabled then
        if overview then overview:Hide() end
        for _, caption in ipairs(captions) do caption:Hide() end
        return
    end
    Ensure()
    RegisterSceneProvider()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local fit = math.min(1, height / math.max(720, #groups * 125 + 120), width / 1100)
    overview:SetScale(fit)
    overview:ClearAllPoints()
    overview:SetPoint("TOP", UIParent, "CENTER", -width * 0.34 / fit, (#groups * 125) / 2)
    overview:SetShown(#groups > 0)
    for index, group in ipairs(groups) do
        local row = Row(index)
        row:ClearAllPoints()
        row:SetPoint("TOP", overview, "TOP", 0, -(index - 1) * 125)
        local name = names[group.first] or ("Form bar " .. group.index .. " — not identified")
        row.label:SetText(name .. (active == group.first and "  (active)" or ""))
        row.label:SetTextColor(active == group.first and 0.4 or 1, active == group.first and 1 or 0.82, 0.35)
        for offset, button in ipairs(row.buttons) do
            button.slot = group.first + offset - 1
            local texture = Call(C_ActionBar and C_ActionBar.GetActionTexture or GetActionTexture, button.slot)
            button.icon:SetTexture(texture)
            button.background:SetAtlas(EmptyAtlas(offset))
            button.background:SetShown(not texture)
        end
        row:Show()
    end
    for index = #groups + 1, #rows do rows[index]:Hide() end
    overview.note:ClearAllPoints()
    overview.note:SetPoint("TOP", overview, "TOP", 0, -#groups * 125 - 4)
    for index, layer in ipairs(ns.Model.layers) do
        local caption, bar = captions[index], API.GetBarFrame(layer)
        caption:SetScale(math.min(1, height / 720, width / 1100))
        caption:ClearAllPoints()
        if bar then caption:SetPoint("BOTTOM", bar, "TOP", 0, 18) end
        caption.text:SetText("Bar " .. tostring(state.page or "?") .. " — " .. layerNames[index])
        caption:SetShown(bar ~= nil)
    end
end

ns.DiscoverFormStorage = Discover
-- Shared with the Controller page
ns.GamepadSlotDrop, ns.GamepadSlotEditable, ns.GamepadEmptyAtlas = Receive, Editable, EmptyAtlas
