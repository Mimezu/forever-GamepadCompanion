-- The Controller page: the whole DualSense as line art, every gamepad bar
-- slot on its button for the layer and page shown, the other buttons with
-- what they run, and the touchpad's zones. One editor in the side card sets
-- any of them: Choose (the picker), drop, clear. Holding L2 / R2 shows that
-- layer; pressed buttons light up. Opened by /gpc pad and the options
-- window's Controller button.
local _, ns = ...
local C, S, T, Sh = ns.ControllerModel, ns.OptionsSkin, ns.TouchModel, ns.Shared
local API = GamepadCompanionAPI

local K = 0.78                                  -- art scale
local ART_W, ART_H = C.ART_W * K, C.ART_H * K   -- 799 x 530
local TOP = 0                                   -- (the layer and page tabs sit in the page header)
local CARD_X, CARD_W = math.floor(ART_W) + 16, 286
local BODY_W, BODY_H = ns.Shell.W, ns.Shell.H
local W = CARD_W - 24                           -- the card's content width

local window, body      -- the page frame (Window.lua's Controller page)
local ui = { layers = {}, pages = {}, slots = {}, buttons = {}, zones = {}, rows = {} }
local selectedLayer, selectedPage, heldLayer = "base", 1, nil
local selected = { kind = "slot", slot = 1 }    -- or { kind = "button", id = ... }
local tpZone, tpSlot = "r1c1", "click"          -- the touchpad zone (or swipe) and slot edited
local Refresh

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function Layer() return heldLayer or selectedLayer end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function TouchSettings() return ns.Touch and ns.Touch.Settings and ns.Touch.Settings() end
local function Look(action) if ns.Touch then return ns.Touch.ActionLook(action) end end

-- Game state ---------------------------------------------------------------------

local function ActivePage()
    local root = _G.GamepadMainActionBarFrame
    local unit = root and root.PageUnit
    local page = unit and Call(unit.GetCurrentPage, unit)
    if type(page) == "number" and page >= 1 and page <= C.PAGES then return page end
    return nil
end

local function Storage(layer, slot)
    local util = _G.GamepadActionBarBindingUtil
    local id = C.PageUnitSlot(layer, slot)
    if util and id and type(util.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID) == "function" then
        return Call(util.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID, selectedPage, id)
    end
    return C.StorageSlot(selectedPage, layer, slot, C.Constants())
end

local KINDS = { spell = "Spell", item = "Item", macro = "Macro", flyout = "Flyout", companion = "Mount",
    summonmount = "Mount", summonpet = "Pet", equipmentset = "Equipment set" }

-- name, texture, kind label for a storage slot (nil when empty)
local function ActionOf(storage)
    if not storage then return nil end
    local kind, id = Call(GetActionInfo, storage)
    if not kind then return nil end
    local texture = Call(C_ActionBar and C_ActionBar.GetActionTexture or GetActionTexture, storage)
    local name
    if kind == "spell" then
        name = Call(C_Spell and C_Spell.GetSpellName, id) or Call(GetSpellInfo, id)
    elseif kind == "item" then
        name = Call(C_Item and C_Item.GetItemNameByID, id) or Call(GetItemInfo, id)
    elseif kind == "macro" then
        name = Call(GetActionText, storage) or Call(GetMacroInfo, id)
    end
    name = name or Call(GetActionText, storage) or KINDS[kind] or kind
    return name, texture, KINDS[kind] or kind
end

-- What the game binds to a key on a layer (not Companion's), as a name
local commandKeys
local function GameBinding(key, layer)
    local bindKey = Sh.LayerPrefix(layer) .. key
    local action = Call(GetBindingAction, bindKey, true)
    if type(action) == "string" and action ~= "" and not action:find(ns.Keys.BUTTON, 1, true) then
        return C.CommandName(action)
    end
    if layer ~= "base" then return nil end
    if not commandKeys then
        commandKeys = {}
        for _, command in ipairs(C.LOOKUP_COMMANDS) do
            local k1, k2 = Call(GetBindingKey, command)
            if k1 then commandKeys[k1] = commandKeys[k1] or command end
            if k2 then commandKeys[k2] = commandKeys[k2] or command end
        end
    end
    if commandKeys[key] then return C.CommandName(commandKeys[key]) end
    -- (Blizzard's core set: cleared while a window has the gamepad's focus)
    return C.BLIZZARD[key]
end

local function PadState()
    local id = C_GamePad and Call(C_GamePad.GetActiveDeviceID)
    if not id then return nil end
    local state = Call(C_GamePad.GetDeviceMappedState, id)
    return state and state.buttons
end

local function Down(buttons, key)
    local index = buttons and C_GamePad and Call(C_GamePad.ButtonBindingToIndex, key)
    return index and buttons[index] and true or false
end

-- Targets ------------------------------------------------------------------------
-- What the card edits: a bar slot, a button, or a touchpad zone. Each gives,
-- per layer, { name, icon, atlas, kind, own } and sets / clears an action.

local ALL = { spell = true, item = true, macro = true, halo = true, window = true, text = true }
local BAR = { spell = true, item = true, macro = true }

local function PlaceOnSlot(storage, action)
    if not storage or not (ns.GamepadSlotEditable and ns.GamepadSlotEditable(storage)) then return end
    local kind, value = action:match("^(%a+):(.+)$")
    Call(ClearCursor)
    if kind == "spell" then Call(C_Spell and C_Spell.PickupSpell or PickupSpell, tonumber(value))
    elseif kind == "item" then Call(C_Item and C_Item.PickupItem or PickupItem, tonumber(value))
    elseif kind == "macro" then Call(PickupMacro, value) end
    if not (GetCursorInfo and GetCursorInfo()) then return end
    ns.GamepadSlotDrop({ slot = storage })
    Call(ClearCursor)   -- (the action it replaced)
end

local function TpSlot(zone)
    local s = TouchSettings()
    local dual = s and s.mode == "chord" and s.input == "dual"
    return (dual and not T.GESTURE_LABELS[zone]) and tpSlot or "click"
end

-- A touchpad zone's action on a layer: own, or Base's (inherited)
local function ZoneAction(zone, layer, slot)
    local s = TouchSettings()
    local set = slot == "touch" and s.touchActions or s.actions[s.mode]
    local own = set[layer] and set[layer][zone]
    if own == "none" then own = nil end
    local action = own
    if not action and layer ~= "base" and set.base then action = set.base[zone] end
    if action == "none" then action = nil end
    return action, own ~= nil
end

local function FromAction(action, own, inherited)
    if not action then return nil end
    local name, icon, atlas = Look(action)
    local kind = action:match("^(%a+):")
    local kinds = { spell = "Spell", item = "Item", macro = "Macro", window = "Window", halo = "Halo ring", text = "Typed macro" }
    return { name = name, icon = icon, atlas = atlas, kind = (kinds[kind] or kind) .. (inherited and " · Base" or ""),
        own = own, inherited = inherited, action = action }
end

local function Target()
    local layer = Layer()
    if selected.kind == "slot" then
        local info = C.SLOTS[selected.slot]
        return {
            kind = "slot", glyph = info.glyph, accepts = BAR,
            title = C.Combo(layer, info.glyph, 18) .. "   " .. (layer == "base" and "" or (C.LAYER_LABELS[layer] .. " + ")) .. info.name,
            entry = function(l)
                local fixed = C.Fixed(l, selected.slot)
                if fixed then return { name = fixed.name, icon = fixed.atlas or fixed.icon, atlas = fixed.atlas ~= nil, kind = "Blizzard", fixed = true } end
                local name, texture, kind = ActionOf(Storage(l, selected.slot))
                if not name then return nil end
                return { name = name, icon = texture, kind = kind, own = true }
            end,
            set = function(l, action) PlaceOnSlot(Storage(l, selected.slot), action) end,
            clear = function(l)
                local storage = Storage(l, selected.slot)
                if storage and ns.GamepadSlotEditable(storage) and not (GetCursorInfo and GetCursorInfo()) then
                    Call(PickupAction, storage)
                    Call(ClearCursor)
                end
            end,
            drop = function(l) local storage = Storage(l, selected.slot); if storage then ns.GamepadSlotDrop({ slot = storage }) end end,
            editable = function(l) return not InCombat() and Storage(l, selected.slot) ~= nil end,
        }
    end
    local info = C.BUTTON_BY_ID[selected.id]
    if info.role == "touchpad" then
        local zone = tpZone
        return {
            kind = "zone", accepts = ALL,
            entry = function(l)
                local action, own = ZoneAction(zone, l, TpSlot(zone))
                return FromAction(action, own, action ~= nil and not own)
            end,
            set = function(l, action) ns.Touch.SetZone(l, zone, action, TpSlot(zone)) end,
            clear = function(l) ns.Touch.SetZone(l, zone, "none", TpSlot(zone)) end,
            drop = function(l)
                local action = ns.Touch.TakeCursor()
                if action then ns.Touch.SetZone(l, zone, action, TpSlot(zone)) end
            end,
            editable = function() return true end,
        }
    end
    if info.role == "binding" then
        local key = info.key
        return {
            kind = "key", glyph = info.glyph, accepts = ALL,
            title = C.Combo(layer, info.glyph, 18) .. "   " .. (layer == "base" and "" or (C.LAYER_LABELS[layer] .. " + ")) .. info.name,
            entry = function(l)
                local action = ns.Keys.Get(key, l)
                if action then return FromAction(action, true) end
                local game = GameBinding(key, l)
                if not game then return nil end
                return { name = game, icon = "Gamepad_" .. info.glyph .. "_64", atlas = true, kind = "Blizzard" }
            end,
            set = function(l, action) ns.Keys.Set(key, l, action) end,
            clear = function(l) ns.Keys.Set(key, l, nil) end,
            drop = function(l)
                local action = ns.Touch.TakeCursor()
                if action then ns.Keys.Set(key, l, action) end
            end,
            editable = function() return true end,
        }
    end
    return nil
end

-- Widgets ------------------------------------------------------------------------

local function Glow(frame, round)
    local t = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    t:SetPoint("TOPLEFT", -3, 3)
    t:SetPoint("BOTTOMRIGHT", 3, -3)
    t:SetColorTexture(1, 0.78, 0.3, 0.35)
    if t.SetBlendMode then t:SetBlendMode("ADD") end
    if round and frame.CreateMaskTexture then
        local mask = frame:CreateMaskTexture()
        mask:SetAllPoints(t)
        mask:SetAtlas("CircleMask")
        t:AddMaskTexture(mask)
    end
    t:Hide()
    return t
end

local function SetIcon(texture, icon, atlas)
    if not icon then texture:Hide(); return end
    if atlas then texture:SetAtlas(icon) else texture:SetTexture(icon) end
    texture:Show()
end

local function Select(kind, value)
    if kind == "slot" then selected = { kind = "slot", slot = value } else selected = { kind = "button", id = value } end
    Refresh()
end

local function HasCursor() return GetCursorInfo and GetCursorInfo() ~= nil end

-- Drop what the cursor holds on the selected target, on the layer shown
local function DropOnTarget()
    local target = Target()
    if not (target and HasCursor() and target.editable(Layer())) then return false end
    target.drop(Layer())
    Refresh()
    return true
end

local function SlotButton(info)
    local square = info.shape == "square"
    local size = (square and C.SQUARE or C.CIRCLE) * K
    local b = CreateFrame("Button", nil, ui.art)
    b:SetSize(size, size)
    b:SetPoint("CENTER", ui.art, "TOPLEFT", C.ToFrame(info.x, info.y, K))
    b:SetFrameLevel((ui.art:GetFrameLevel() or 0) + 4)
    local shape = square and "square" or "circle"
    b.shadow = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    b.shadow:SetPoint("TOPLEFT", -4, 4)
    b.shadow:SetPoint("BOTTOMRIGHT", 4, -4)
    b.shadow:SetAtlas("gamepad-actionbar-" .. shape .. "slot-dropshadow")
    b.background = b:CreateTexture(nil, "BACKGROUND")
    b.background:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    if b.CreateMaskTexture then
        b.mask = b:CreateMaskTexture()
        b.mask:SetAllPoints(b.icon)
        b.mask:SetAtlas(square and "SquareMask" or "CircleMask")
        b.icon:AddMaskTexture(b.mask)
    end
    b.rim = b:CreateTexture(nil, "OVERLAY")
    b.rim:SetAllPoints()
    b.rim:SetAtlas("gamepad-actionbar-" .. shape .. "slot-border-normal")
    b.selection = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.selection:SetPoint("TOPLEFT", -2, 2)
    b.selection:SetPoint("BOTTOMRIGHT", 2, -2)
    b.selection:SetAtlas("gamepad-actionbar-" .. shape .. "slot-border-hover")
    b.selection:SetVertexColor(1, 0.82, 0.2)
    b.selection:Hide()
    b.pressed = Glow(b, not square)
    -- (the button's glyph, small, on the slot's outer corner)
    b.glyph = b:CreateTexture(nil, "OVERLAY", nil, 3)
    b.glyph:SetSize(18, 18)
    b.glyph:SetAtlas("Gamepad_" .. info.glyph .. "_32")
    b.glyph:SetPoint("CENTER", b, "BOTTOMRIGHT", -5, 5)
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetAtlas("gamepad-actionbar-" .. shape .. "slot-border-hover")
    b.info = info
    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("LeftButtonUp")
    local function PickAndDrop()
        selected = { kind = "slot", slot = info.slot }
        if not DropOnTarget() then Refresh() end
    end
    b:SetScript("OnClick", PickAndDrop)
    b:SetScript("OnReceiveDrag", PickAndDrop)
    b:SetScript("OnDragStart", function(self)
        if self.storage and ns.GamepadSlotEditable and ns.GamepadSlotEditable(self.storage) and not HasCursor() then
            Call(PickupAction, self.storage)
            Refresh()
        end
    end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.fixed then
            GameTooltip:SetText(self.fixed.name, 1, 0.82, 0)
        elseif self.storage and Call(GetActionInfo, self.storage) then
            GameTooltip:SetAction(self.storage)
        else
            GameTooltip:SetText(C.LAYER_LABELS[Layer()] .. " · " .. info.name, 1, 0.82, 0)
            GameTooltip:AddLine("Empty", 0.62, 0.62, 0.62)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

local ROUND = { l3 = true, r3 = true, ps = true }
-- Where a button's label sits on the art: x, y, width, anchor
local LABELS = {
    l2 = { 212, 46, 120 }, r2 = { 812, 46, 120 }, l1 = { 212, 75, 150 }, r1 = { 812, 75, 150 },
    create = { 290, 124, 150, "RIGHT" }, options = { 734, 124, 150, "LEFT" },
    l3 = { 382, 392, 100 }, r3 = { 642, 392, 100 }, ps = { 512, 350, 130, "BOTTOM" },
}

local function HotSpot(info)
    local b = CreateFrame("Button", nil, ui.art)
    b:SetSize(info.w * K, info.h * K)
    b:SetPoint("CENTER", ui.art, "TOPLEFT", C.ToFrame(info.x, info.y, K))
    b:SetFrameLevel((ui.art:GetFrameLevel() or 0) + (info.role == "touchpad" and 1 or 3))
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.78, 0.3, 0.12)
    if ROUND[info.id] and b.CreateMaskTexture then
        local mask = b:CreateMaskTexture()
        mask:SetAllPoints(hover)
        mask:SetAtlas("CircleMask")
        hover:AddMaskTexture(mask)
    end
    b.selection = Glow(b, ROUND[info.id])
    b.selection:SetColorTexture(1, 0.82, 0.2, 0.18)
    b.pressed = Glow(b, ROUND[info.id])
    local spot = LABELS[info.id]
    if spot then
        b.text = ui.art:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local anchor = spot[4] or "CENTER"
        b.text:SetPoint(anchor, ui.art, "TOPLEFT", C.ToFrame(spot[1], spot[2], K))
        b.text:SetWidth(spot[3] * K)
        b.text:SetJustifyH(anchor == "RIGHT" and "RIGHT" or anchor == "LEFT" and "LEFT" or "CENTER")
        -- (shoulders and the side buttons: glyph and binding on one line)
        b.oneLine = info.id == "l1" or info.id == "r1" or anchor == "RIGHT" or anchor == "LEFT"
        if b.oneLine then b.text:SetWordWrap(false) end
        b.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    end
    b.info = info
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function()
        if info.role == "layer" then
            selectedLayer = selectedLayer == info.layer and "base" or info.layer
        end
        selected = { kind = "button", id = info.id }
        if info.role ~= "binding" or not DropOnTarget() then Refresh() end
    end)
    if info.role == "binding" then
        b:SetScript("OnReceiveDrag", function()
            selected = { kind = "button", id = info.id }
            if not DropOnTarget() then Refresh() end
        end)
    end
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(C.Glyph(info.glyph, 18) .. " " .. info.name, 1, 0.82, 0)
        if self.runs then GameTooltip:AddLine(self.runs, 1, 1, 1) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

-- The touchpad's zones, drawn on the pad -----------------------------------------

local function PickZone(zone)
    tpZone = zone
    selected = { kind = "button", id = "touchpad" }
    if not DropOnTarget() then Refresh() end
end

local function ZoneCell(zone)
    local c = CreateFrame("Button", nil, ui.art)
    c:RegisterForClicks("LeftButtonUp")
    c:SetScript("OnClick", function() PickZone(zone) end)
    c:SetScript("OnReceiveDrag", function() PickZone(zone) end)
    local hover = c:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.78, 0.3, 0.14)
    c:SetFrameLevel((ui.art:GetFrameLevel() or 0) + 2)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.bg:SetColorTexture(1, 0.85, 0.55, 0.06)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(22, 22)
    c.icon:SetPoint("CENTER", 0, 5)
    c.touch = c:CreateTexture(nil, "OVERLAY")
    c.touch:SetSize(12, 12)
    c.touch:SetPoint("CENTER", c.icon, "TOPRIGHT", 1, -1)
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.label:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    c.label:SetPoint("BOTTOMLEFT", 2, 2)
    c.label:SetPoint("BOTTOMRIGHT", -2, 2)
    c.label:SetJustifyH("CENTER")
    c.label:SetWordWrap(false)
    return c
end

local function LayoutZones(layer)
    for _, c in pairs(ui.zones) do c:Hide() end
    local s = TouchSettings()
    if not (s and T) then ui.padText:SetText(""); return end
    if not s.enabled then
        ui.padText:SetText("Touchpad")
        return
    end
    ui.padText:SetText("")
    local mode, grid = s.mode, T.Grid(s, s.mode)
    local r = C.TOUCHPAD_RECT
    local x0, w = r.x0, r.x1 - r.x0
    if mode == "split" then x0, w = r.x0 + w / 2, w / 2 end
    local cw, ch = w / grid.cols, (r.y1 - r.y0) / grid.rows
    local dual = mode == "chord" and s.input == "dual"
    for _, zone in ipairs(T.Zones(s)) do
        local row, col = zone:match("^r(%d)c(%d)$")
        row, col = tonumber(row), tonumber(col)
        local c = ui.zones[zone] or ZoneCell(zone)
        ui.zones[zone] = c
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", ui.art, "TOPLEFT", C.ToFrame(x0 + (col - 1) * cw + 2, r.y0 + (row - 1) * ch + 2, K))
        c:SetSize((cw - 4) * K, (ch - 4) * K)
        local action = ZoneAction(zone, layer, "click")
        local label, icon, atlas = Look(action)
        SetIcon(c.icon, icon, atlas)
        c.label:SetText(label or "")
        if dual then
            local _, tIcon, tAtlas = Look((ZoneAction(zone, layer, "touch")))
            SetIcon(c.touch, tIcon, tAtlas)
        else
            c.touch:Hide()
        end
        local picked = selected.kind == "button" and selected.id == "touchpad" and tpZone == zone
        if picked then c.bg:SetColorTexture(1, 0.82, 0.2, 0.3) else c.bg:SetColorTexture(1, 0.85, 0.55, 0.06) end
        c:Show()
    end
end

-- Card: the editor ---------------------------------------------------------------

local function OpenPicker()
    local target = Target()
    if not target or not target.editable(Layer()) or not ns.Picker then return end
    local layer = Layer()
    local entry = target.entry(layer)
    ns.Picker.Open({
        title = "Choose · " .. (target.kind == "zone"
            and ((T.GESTURE_LABELS[tpZone] or T.ZoneLabel(tpZone, T.Grid(TouchSettings(), TouchSettings().mode))) .. " · " .. C.LAYER_LABELS[layer])
            or (C.LAYER_LABELS[layer] .. " + " .. (selected.kind == "slot" and C.SLOTS[selected.slot].name or C.BUTTON_BY_ID[selected.id].name))),
        accepts = target.accepts,
        current = entry and entry.own and entry.action or nil,
        onPick = function(action)
            target.set(layer, action)
            Refresh()
        end,
    })
end

local function BuildEditor(card)
    local ed = CreateFrame("Frame", nil, card)
    ed:SetSize(W, 66)
    ed.icon = CreateFrame("Button", nil, ed)
    ed.icon:SetSize(50, 50)
    ed.icon:SetPoint("TOPLEFT", 0, 0)
    ed.icon.texture = ed.icon:CreateTexture(nil, "ARTWORK")
    ed.icon.texture:SetAllPoints()
    ed.icon.empty = ed.icon:CreateTexture(nil, "BACKGROUND")
    ed.icon.empty:SetAllPoints()
    ed.icon.empty:SetColorTexture(1, 0.85, 0.55, 0.08)
    local hover = ed.icon:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.78, 0.3, 0.2)
    ed.icon:RegisterForClicks("LeftButtonUp")
    ed.icon:SetScript("OnClick", function() if not DropOnTarget() then OpenPicker() end end)
    ed.icon:SetScript("OnReceiveDrag", DropOnTarget)
    S.Tooltip(ed.icon, "Choose", "Or drop a spell, item or macro")
    ed.icon:SetScript("OnEnter", S.ShowTooltip)
    ed.icon:SetScript("OnLeave", S.HideTooltip)
    ed.name = S.Text(ed, "", 60, -2, W - 60, 14, S.GOLD)
    ed.name:SetWordWrap(false)
    ed.kind = S.Text(ed, "", 60, -22, W - 60, 11, S.GREY)
    ed.kind:SetWordWrap(false)
    ed.choose = S.NewButton(ed, "Choose", 60, -40, 84, OpenPicker, nil, 11, 24)
    ed.clear = S.NewButton(ed, "Clear", 148, -40, 54, function()
        local target = Target()
        if target and target.editable(Layer()) then target.clear(Layer()); Refresh() end
    end, nil, 11, 24)
    ed.pickup = S.NewButton(ed, "Pick up", 206, -40, W - 206, function()
        local storage = selected.kind == "slot" and Storage(Layer(), selected.slot)
        if storage and ns.GamepadSlotEditable(storage) and not HasCursor() then
            Call(PickupAction, storage)
            Refresh()
        end
    end, nil, 11, 24)
    return ed
end

local function RefreshEditor(target)
    local ed, layer = ui.ed, Layer()
    local entry = target.entry(layer)
    local editable = target.editable(layer) and not (entry and entry.fixed)
    if entry and entry.icon then
        SetIcon(ed.icon.texture, entry.icon, entry.atlas)
        ed.icon.texture:SetAlpha(entry.inherited and 0.45 or 1)
    else
        ed.icon.texture:Hide()
    end
    ed.icon.empty:SetShown(not (entry and entry.icon))
    ed.name:SetText(entry and entry.name or "Empty")
    if entry then ed.name:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3]) else ed.name:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3]) end
    ed.kind:SetText(entry and entry.kind or "")
    ed.choose:SetEnabled(editable)
    ed.clear:SetEnabled(editable and entry ~= nil and entry.own == true)
    ed.pickup:SetShown(target.kind == "slot")
    ed.pickup:SetEnabled(editable and entry ~= nil)
    ed.icon:EnableMouse(editable)
end

local function Row(index)
    if ui.rows[index] then return ui.rows[index] end
    local r = CreateFrame("Button", nil, ui.card)
    r:SetSize(W + 4, 38)
    local hover = r:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.7, 0.2, 0.1)
    r.selection = r:CreateTexture(nil, "BACKGROUND")
    r.selection:SetAllPoints()
    r.selection:SetColorTexture(1, 0.72, 0.2, 0.16)
    r.combo = S.Text(r, "", 4, -13, 64, 12, S.GOLD)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("LEFT", 72, 0)
    r.name = S.Text(r, "", 110, -13, W - 108, 12, S.GOLD)
    r.name:SetWordWrap(false)
    r:RegisterForClicks("LeftButtonUp")
    ui.rows[index] = r
    return r
end

-- The target on every layer, from y down
local function RefreshRows(target, y, glyph)
    ui.layersTitle:ClearAllPoints()
    ui.layersTitle:SetPoint("TOPLEFT", ui.card, "TOPLEFT", 12, y)
    ui.layersTitle:Show()
    local layer = Layer()
    for index, l in ipairs(C.LAYERS) do
        local r = Row(index)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", ui.card, "TOPLEFT", 10, y - 18 - (index - 1) * 40)
        r.combo:SetText(C.Combo(l, glyph, 16))
        local entry = target.entry(l)
        if entry and entry.icon then
            SetIcon(r.icon, entry.icon, entry.atlas)
            r.icon:SetAlpha(entry.inherited and 0.45 or 1)
        else
            r.icon:Hide()
        end
        r.name:SetText(entry and entry.name or "Empty")
        if entry and not entry.inherited then r.name:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
        else r.name:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3]) end
        r.selection:SetShown(l == layer)
        r:SetScript("OnClick", function() selectedLayer = l; Refresh() end)
        r:Show()
    end
end

-- Card: the touchpad's settings --------------------------------------------------

local function BuildTouchPanel(card)
    local Touch = ns.Touch
    local p = CreateFrame("Frame", nil, card)
    p:SetPoint("TOPLEFT", 12, -40)
    p:SetSize(W, 220)
    ui.tp = p
    local tp = { inputs = {}, modes = {}, slots = {}, swipes = {} }
    ui.tpw = tp
    local function Settings() return Touch.Settings() end

    tp.enable = S.NewCheck(p, "Zones", -2, 0, function(self) Touch.SetEnabled(self:GetChecked() == true) end, 60)
    tp.preview = S.NewCheck(p, "Preview", 132, 0, function(self) Touch.SetPreview(self:GetChecked() == true) end, 70)
    local x = 0
    for _, e in ipairs({ { "click", "Click", 74 }, { "tap", "Tap or click", 90 }, { "dual", "Touch + click", 90 } }) do
        tp.inputs[e[1]] = S.NewButton(p, e[2], x, -32, e[3], function() Touch.SetInput(e[1]) end, nil, 11, 24)
        x = x + e[3] + 4
    end
    S.Tooltip(tp.inputs.click, "Press", "A full click")
    S.Tooltip(tp.inputs.tap, "Press", "Taps out of combat only")
    S.Tooltip(tp.inputs.dual, "Touch + click", "Whole pad only")
    local half = (W - 4) / 2
    tp.modes.chord = S.NewButton(p, "Whole pad", 0, -62, half, function() Touch.SetMode("chord") end, nil, 11, 24)
    tp.modes.split = S.NewButton(p, "Right half", half + 4, -62, half, function() Touch.SetMode("split") end, nil, 11, 24)
    S.Tooltip(tp.modes.chord, "Whole pad", "L1 + touchpad: Blizzard's focus")
    S.Tooltip(tp.modes.split, "Right half", "Left half: Blizzard's focus")

    local function Step(sx, tip, dc, dr)
        local b = S.NewButton(p, dc + dr < 0 and "-" or "+", sx, -92, 24, function()
            local s = Settings()
            local g = T.Grid(s, s.mode)
            Touch.SetGrid(g.cols + dc, g.rows + dr)
        end, nil, 13, 24)
        S.Tooltip(b, tip)
        return b
    end
    tp.colsMinus = Step(0, "Fewer columns", -1, 0)
    tp.cols = S.Text(p, "", 26, -98, 66, 11, S.YELLOW)
    tp.cols:SetJustifyH("CENTER")
    tp.colsPlus = Step(94, "More columns", 1, 0)
    tp.rowsMinus = Step(W - 118, "Fewer rows", 0, -1)
    tp.rows = S.Text(p, "", W - 92, -98, 66, 11, S.YELLOW)
    tp.rows:SetJustifyH("CENTER")
    tp.rowsPlus = Step(W - 24, "More rows", 0, 1)

    tp.tapLabel = S.Text(p, "Tap", 0, -128, 30, 11, S.GOLD)
    tp.tapMinus = S.NewButton(p, "-", 30, -122, 24, function() Touch.SetTapTime(Settings().tapMs - T.TAP_MS.step) end, nil, 13, 24)
    tp.tapTime = S.Text(p, "", 56, -128, 60, 11, S.YELLOW)
    tp.tapTime:SetJustifyH("CENTER")
    tp.tapPlus = S.NewButton(p, "+", 118, -122, 24, function() Touch.SetTapTime(Settings().tapMs + T.TAP_MS.step) end, nil, 13, 24)
    S.Tooltip(tp.tapMinus, "Shorter tap")
    S.Tooltip(tp.tapPlus, "Longer tap")
    tp.over = S.NewCheck(p, "Over windows", 150, -121, function(self) Touch.SetOverWindows(self:GetChecked() == true) end, 90)
    S.Tooltip(tp.over, "Over windows", "Off: an open window takes the pad")

    -- The picked zone's heading and slot, then swipes
    local rule = p:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(1, 0.82, 0, 0.18)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -154)
    rule:SetWidth(W)
    tp.zoneTitle = S.Text(p, "", 0, -166, W - 122, 12, S.YELLOW)
    tp.zoneTitle:SetWordWrap(false)
    for i, e in ipairs({ { "touch", "Touch" }, { "click", "Click" } }) do
        tp.slots[e[1]] = S.NewButton(p, e[2], W - 116 + (i - 1) * 60, -161, 56, function()
            tpSlot = e[1]
            Refresh()
        end, nil, 11, 22)
    end
    tp.swipeRow = CreateFrame("Frame", nil, card)
    tp.swipeRow:SetSize(W, 24)
    local sw = (W - 12) / 4
    for i, gesture in ipairs(T.GESTURES) do
        local label = T.GESTURE_LABELS[gesture]:gsub("^Swipe ", "")
        label = label:sub(1, 1):upper() .. label:sub(2)
        local b = S.NewButton(tp.swipeRow, label, (i - 1) * (sw + 4), 0, sw, function() PickZone(gesture) end, nil, 11, 24)
        b:SetScript("OnReceiveDrag", function() PickZone(gesture) end)
        S.Tooltip(b, T.GESTURE_LABELS[gesture])
        tp.swipes[gesture] = b
    end
end

local function RefreshTouchPanel()
    local s, tp, layer = TouchSettings(), ui.tpw, Layer()
    local grid, limit = T.Grid(s, s.mode), T.GRID_LIMITS[s.mode]
    if not T.IsZone(s, s.mode, tpZone) then tpZone = "r1c1" end
    tp.enable:SetChecked(s.enabled)
    tp.preview:SetChecked(s.preview)
    for input, b in pairs(tp.inputs) do
        S.SetSelected(b, input == s.input)
        b:SetEnabled(input ~= "dual" or s.mode == "chord")
    end
    for mode, b in pairs(tp.modes) do S.SetSelected(b, mode == s.mode) end
    tp.cols:SetText(grid.cols .. (grid.cols == 1 and " column" or " columns"))
    tp.rows:SetText(grid.rows .. (grid.rows == 1 and " row" or " rows"))
    tp.colsMinus:SetEnabled(grid.cols > 1); tp.colsPlus:SetEnabled(grid.cols < limit.cols)
    tp.rowsMinus:SetEnabled(grid.rows > 1); tp.rowsPlus:SetEnabled(grid.rows < limit.rows)
    local taps = s.input ~= "click"
    for _, w in ipairs({ tp.tapLabel, tp.tapMinus, tp.tapTime, tp.tapPlus }) do w:SetShown(taps) end
    tp.tapTime:SetText(s.tapMs .. " ms")
    tp.tapMinus:SetEnabled(s.tapMs > T.TAP_MS.min)
    tp.tapPlus:SetEnabled(s.tapMs < T.TAP_MS.max)
    tp.over:SetChecked(s.overWindows)
    tp.over:SetShown(s.mode == "chord")
    local dual = s.mode == "chord" and s.input == "dual"
    local swipe = T.GESTURE_LABELS[tpZone] ~= nil
    tp.zoneTitle:SetText((swipe and T.GESTURE_LABELS[tpZone] or T.ZoneLabel(tpZone, grid)) .. " · " .. T.LAYER_LABELS[layer])
    local slot = TpSlot(tpZone)
    for key, b in pairs(tp.slots) do
        b:SetShown(dual)
        S.SetSelected(b, key == slot)
        b:SetEnabled(key == "click" or not swipe)
    end
    for gesture, b in pairs(tp.swipes) do S.SetSelected(b, gesture == tpZone) end
end

-- Card ---------------------------------------------------------------------------

local function Place(frame, y)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", ui.card, "TOPLEFT", 12, y)
    frame:Show()
end

local function RefreshCard()
    local layer = Layer()
    local card = ui.card
    for _, w in ipairs({ ui.ed, ui.tp, ui.tpw and ui.tpw.swipeRow, ui.sub, ui.layersTitle, ui.info, ui.showLayer }) do
        if w then w:Hide() end
    end
    for _, r in ipairs(ui.rows) do r:Hide() end
    local info = selected.kind == "button" and C.BUTTON_BY_ID[selected.id] or nil
    local target = Target()
    if info and info.role == "layer" then
        card.title:SetText(C.Glyph(info.glyph, 18) .. "   " .. info.name)
        ui.info:Show()
        ui.infoIcon:SetAtlas("Gamepad_" .. info.glyph .. "_64")
        ui.infoName:SetText(info.name .. " bar")
        ui.showLayer.label:SetText(selectedLayer == info.layer and "Show Base" or ("Show " .. info.name))
        ui.showLayer:Show()
        return
    end
    if target.kind == "zone" then
        card.title:SetText(C.Glyph("Shp_TouchpadL", 18) .. "   Touchpad")
        if ui.tp then ui.tp:Show(); RefreshTouchPanel() end
        Place(ui.ed, -228)
        RefreshEditor(target)
        Place(ui.tpw.swipeRow, -300)
        RefreshRows(target, -336, nil)
        return
    end
    card.title:SetText(target.title)
    Place(ui.ed, -40)
    RefreshEditor(target)
    if target.kind == "slot" then
        Place(ui.sub, -112)
        ui.sub:SetText("Page " .. selectedPage .. " · " .. (layer == "base" and "Base bar" or (C.LAYER_LABELS[layer] .. " bar")))
    end
    RefreshRows(target, -140, target.glyph)
end

-- Refresh ------------------------------------------------------------------------

Refresh = function()
    if not window or not window:IsVisible() then return end
    local layer = Layer()
    local active = ActivePage()
    for l, button in pairs(ui.layers) do S.SetSelected(button, l == layer) end
    for p, button in ipairs(ui.pages) do
        S.SetSelected(button, p == selectedPage)
        button.label:SetText(p == active and (p .. " •") or tostring(p))
    end
    for index, b in ipairs(ui.slots) do
        b.fixed = C.Fixed(layer, index)
        b.storage = not b.fixed and Storage(layer, index) or nil
        b.background:SetAtlas(ns.GamepadEmptyAtlas and ns.GamepadEmptyAtlas(index) or "")
        if b.fixed then
            SetIcon(b.icon, b.fixed.atlas or b.fixed.icon, b.fixed.atlas ~= nil)
            b.background:Hide()
        else
            local _, texture = ActionOf(b.storage)
            b.icon:SetTexture(texture)
            b.icon:SetShown(texture ~= nil)
            b.background:SetShown(texture == nil)
        end
        b.selection:SetShown(selected.kind == "slot" and selected.slot == index)
    end
    for id, b in pairs(ui.buttons) do
        local info = b.info
        b.selection:SetShown(selected.kind == "button" and selected.id == id)
        local runs
        if info.role == "layer" then runs = info.name .. " bar"
        elseif info.role == "binding" then
            local own = ns.Keys.Get(info.key, layer)
            runs = own and (Look(own)) or GameBinding(info.key, layer)
        end
        b.runs = runs
        if b.text then
            if info.role == "layer" then
                b.text:SetText(C.Glyph(info.glyph, 18))
                if layer == info.layer or layer == "both" then b.text:SetTextColor(S.YELLOW[1], S.YELLOW[2], S.YELLOW[3])
                else b.text:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3]) end
            else
                b.text:SetText(C.Glyph(info.glyph, 14) .. (runs and ((b.oneLine and " " or "\n") .. runs) or ""))
                if info.role == "binding" and ns.Keys.Get(info.key, layer) then b.text:SetTextColor(S.YELLOW[1], S.YELLOW[2], S.YELLOW[3])
                else b.text:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3]) end
            end
        end
    end
    LayoutZones(layer)
    RefreshCard()
    local note = InCombat() and "Not in combat" or ((ns.Keys.IsPending() and "Applies after combat · " or "")
        .. "Drag: pick up · Drop: bind")
    ui.status:SetText(note)
end

-- Build --------------------------------------------------------------------------

local function Build(frame, header)
    window, body = frame, frame

    -- Layers and pages, in the page header
    local x = 150
    for _, layer in ipairs(C.LAYERS) do
        local glyphs = C.Combo(layer, nil, 14)
        local label = layer == "base" and "Base" or glyphs
        local width = layer == "both" and 84 or 64
        ui.layers[layer] = S.NewButton(header, label, x, -3, width, function()
            selectedLayer = layer
            Refresh()
        end, nil, 12, 28)
        S.Tooltip(ui.layers[layer], C.LAYER_LABELS[layer])
        x = x + width + 6
    end
    local pageX = ART_W - C.PAGES * 40 - 50
    ui.pageLabel = S.Text(header, "Page", pageX, -11, 46, 12, S.GOLD)
    for p = 1, C.PAGES do
        ui.pages[p] = S.NewButton(header, tostring(p), pageX + 46 + (p - 1) * 40, -3, 36, function()
            selectedPage = p
            Refresh()
        end, nil, 12, 28)
        S.Tooltip(ui.pages[p], "Page " .. p, "Bar slots only")
    end

    -- The controller
    ui.art = CreateFrame("Frame", nil, body)
    ui.art:SetPoint("TOPLEFT", 0, -TOP)
    ui.art:SetSize(ART_W, ART_H)
    local art = ui.art:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetAllPoints()
    art:SetTexture(C.TEXTURE)
    art:SetTexCoord(0, 1, 0, C.ART_H / C.TEX_SIZE)
    ui.artTexture = art
    ui.padText = ui.art:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ui.padText:SetPoint("CENTER", ui.art, "TOPLEFT", C.ToFrame(512, 192, K))
    for _, info in ipairs(C.BUTTONS) do ui.buttons[info.id] = HotSpot(info) end
    for index, info in ipairs(C.SLOTS) do ui.slots[index] = SlotButton(info) end
    ui.status = S.Note(body, 2, -(TOP + ART_H + 10), ART_W - 4, 1, 11, S.GREY)

    -- Card
    ui.card = S.Card(body, " ", CARD_X, 0, CARD_W, BODY_H)
    local card = ui.card
    ui.ed = BuildEditor(card)
    ui.name, ui.kind, ui.clear, ui.pickup, ui.choose = ui.ed.name, ui.ed.kind, ui.ed.clear, ui.ed.pickup, ui.ed.choose
    ui.sub = S.Note(card, 12, -112, W, 1, 11, S.GREY)
    ui.layersTitle = S.Text(card, "Every layer", 12, -140, nil, 11, S.YELLOW)
    -- (L2 / R2: what they are, and a button to show their bar)
    ui.info = CreateFrame("Frame", nil, card)
    ui.info:SetPoint("TOPLEFT", 12, -40)
    ui.info:SetSize(W, 60)
    ui.infoIcon = ui.info:CreateTexture(nil, "ARTWORK")
    ui.infoIcon:SetSize(50, 50)
    ui.infoIcon:SetPoint("TOPLEFT")
    ui.infoName = S.Text(ui.info, "", 60, -14, W - 60, 14, S.GOLD)
    ui.showLayer = S.NewButton(card, "", 12, -110, W, function()
        local info = C.BUTTON_BY_ID[selected.id]
        selectedLayer = selectedLayer == info.layer and "base" or info.layer
        Refresh()
    end)
    if ns.Touch and T then BuildTouchPanel(card) end

    -- Live: held triggers show their layer, pressed buttons light up
    local wait, pageWait, lastActive = 0, 0, nil
    window:SetScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.05
        local buttons = PadState()
        local held = buttons and C.LayerOf(Down(buttons, "PADLTRIGGER"), Down(buttons, "PADRTRIGGER")) or "base"
        held = held ~= "base" and held or nil
        if held ~= heldLayer then heldLayer = held; Refresh() end
        for _, b in ipairs(ui.slots) do b.pressed:SetShown(Down(buttons, b.info.key)) end
        for _, b in pairs(ui.buttons) do
            local down = Down(buttons, b.info.key) or (b.info.role == "touchpad" and Down(buttons, "PAD6"))
            b.pressed:SetShown(down)
        end
        pageWait = pageWait - math.max(elapsed, 0.05)
        if pageWait <= 0 then
            pageWait = 0.5
            local active = ActivePage()
            if active ~= lastActive then lastActive = active; Refresh() end
        end
    end)
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "SPELLS_CHANGED", "UPDATE_BINDINGS",
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "CURSOR_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_BINDINGS" then commandKeys = nil end
        Refresh()
    end)
    if ns.Touch and ns.Touch.OnChange then ns.Touch.OnChange(Refresh) end
    if ns.Keys then ns.Keys.OnChange(Refresh) end
end

-- The main page of the Gamepad Companion window
ns.Shell.AddPage({
    key = "controller", name = "Controller", order = 1, icon = "Interface\\Icons\\Trade_Engineering",
    build = Build, refresh = function() Refresh() end,
    show = function() selectedPage = ActivePage() or selectedPage end,
    hide = function() if ns.Picker then ns.Picker.Close() end end,
})

function API.ToggleController() ns.Shell.Toggle("controller") end

-- /gpc touch: this page, on the touchpad
function API.ToggleTouchpad()
    local open = ns.Shell.IsShown("controller")
    if open and selected.kind == "button" and selected.id == "touchpad" then
        ns.Shell.Window():Hide()
        return
    end
    selected = { kind = "button", id = "touchpad" }
    if open then Refresh() else ns.Shell.Open("controller") end
end

-- Harness access
ns.ControllerWindow = function() return window, ui end
