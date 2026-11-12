-- The Controller page: the whole DualSense as line art, every gamepad bar
-- slot on its button for the layer and page shown, the other buttons with
-- what they run, and the touchpad's zones. Drop, pick up and clear actions
-- out of combat. Holding L2 / R2 shows that layer; pressed buttons light up.
-- Opened by /gpc pad and the options window's Controller button.
local _, ns = ...
local C, S, T = ns.ControllerModel, ns.OptionsSkin, ns.TouchModel
local API = GamepadCompanionAPI

local K = 0.78                                  -- art scale
local ART_W, ART_H = C.ART_W * K, C.ART_H * K   -- 799 x 530
local TOP = 40                                  -- tabs above the art
local CARD_X, CARD_W = math.floor(ART_W) + 16, 286
local BODY_W, BODY_H = CARD_X + CARD_W, TOP + math.floor(ART_H) + 34

local window, body
local ui = { layers = {}, pages = {}, slots = {}, buttons = {}, zones = {}, rows = {} }
local selectedLayer, selectedPage, heldLayer = "base", 1, nil
local selected = { kind = "slot", slot = 1 }    -- or { kind = "button", id = ... }
local Refresh

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function Layer() return heldLayer or selectedLayer end
local function InCombat() return InCombatLockdown and InCombatLockdown() end

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

-- The command a key runs, as a name
local commandKeys
local function BindingOf(key)
    local action = Call(GetBindingAction, key, true)
    if type(action) == "string" and action ~= "" then return C.CommandName(action) end
    if not commandKeys then
        commandKeys = {}
        for _, command in ipairs(C.LOOKUP_COMMANDS) do
            local k1, k2 = Call(GetBindingKey, command)
            if k1 then commandKeys[k1] = commandKeys[k1] or command end
            if k2 then commandKeys[k2] = commandKeys[k2] or command end
        end
    end
    return commandKeys[key] and C.CommandName(commandKeys[key]) or nil
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

local function Select(kind, value)
    if kind == "slot" then selected = { kind = "slot", slot = value } else selected = { kind = "button", id = value } end
    Refresh()
end

local function Drop(button)
    if not button.storage or not ns.GamepadSlotDrop then return false end
    -- (SpreadOverview's drop: swaps, keeps the old action on the cursor)
    ns.GamepadSlotDrop({ slot = button.storage })
    return true
end

local function SlotButton(info)
    local square = info.shape == "square"
    local size = square and 36 or 46
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
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetAtlas("gamepad-actionbar-" .. shape .. "slot-border-hover")
    b.info = info
    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(self)
        if GetCursorInfo and GetCursorInfo() and Drop(self) then
            Select("slot", info.slot)
            return
        end
        Select("slot", info.slot)
    end)
    b:SetScript("OnReceiveDrag", function(self)
        Drop(self)
        Select("slot", info.slot)
    end)
    b:SetScript("OnDragStart", function(self)
        if self.storage and ns.GamepadSlotEditable and ns.GamepadSlotEditable(self.storage)
            and not (GetCursorInfo and GetCursorInfo()) then
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
local LABELS = {   -- where a button's label sits (art), and its width
    l2 = { 212, 50, 120 }, r2 = { 812, 50, 120 }, l1 = { 212, 83, 160 }, r1 = { 812, 83, 160 },
    create = { 308, 170, 120 }, options = { 716, 170, 120 }, l3 = { 382, 392, 96 }, r3 = { 642, 392, 96 },
    ps = { 512, 344, 110 },
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
        b.text:SetPoint("CENTER", ui.art, "TOPLEFT", C.ToFrame(spot[1], spot[2], K))
        b.text:SetWidth(spot[3] * K)
        b.text:SetJustifyH("CENTER")
        b.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    end
    b.info = info
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function()
        if info.role == "layer" then
            selectedLayer = selectedLayer == info.layer and "base" or info.layer
        end
        Select("button", info.id)
    end)
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

-- The touchpad's zones, drawn on the pad
local function ZoneCell()
    local c = CreateFrame("Frame", nil, ui.art)
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

local function SetLook(texture, action)
    local Touch = ns.Touch
    local _, icon, isAtlas
    if Touch and Touch.ActionLook then _, icon, isAtlas = Touch.ActionLook(action) end
    if icon then
        if isAtlas then texture:SetAtlas(icon) else texture:SetTexture(icon) end
        texture:Show()
    else
        texture:Hide()
    end
    return icon ~= nil
end

local function TouchAction(set, layer, zone)
    local action = set[layer] and set[layer][zone]
    if (action == nil or action == "none") and layer ~= "base" and set.base then action = set.base[zone] end
    if action == "none" then return nil end
    return action
end

local function LayoutZones(layer)
    for _, c in pairs(ui.zones) do c:Hide() end
    local Touch = ns.Touch
    local s = Touch and Touch.Settings and Touch.Settings()
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
        local c = ui.zones[zone] or ZoneCell()
        ui.zones[zone] = c
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", ui.art, "TOPLEFT", C.ToFrame(x0 + (col - 1) * cw + 2, r.y0 + (row - 1) * ch + 2, K))
        c:SetSize((cw - 4) * K, (ch - 4) * K)
        local action = TouchAction(s.actions[mode], layer, zone)
        local label = Touch.ActionLook(action)
        SetLook(c.icon, action)
        c.label:SetText(label or "")
        if dual then SetLook(c.touch, TouchAction(s.touchActions, layer, zone)) else c.touch:Hide() end
        c:Show()
    end
end

-- Card ---------------------------------------------------------------------------

local function Row(index)
    if ui.rows[index] then return ui.rows[index] end
    local card = ui.card
    local r = CreateFrame("Button", nil, card)
    r:SetPoint("TOPLEFT", 10, -238 - (index - 1) * 44)
    r:SetSize(CARD_W - 20, 40)
    local hover = r:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.7, 0.2, 0.1)
    r.selection = r:CreateTexture(nil, "BACKGROUND")
    r.selection:SetAllPoints()
    r.selection:SetColorTexture(1, 0.72, 0.2, 0.16)
    r.combo = S.Text(r, "", 4, -12, 64, 12, S.GOLD)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("LEFT", 72, 0)
    r.name = S.Text(r, "", 110, -13, CARD_W - 130, 12, S.GOLD)
    r.name:SetWordWrap(false)
    r:RegisterForClicks("LeftButtonUp")
    ui.rows[index] = r
    return r
end

local function RefreshCard()
    local layer = Layer()
    local card = ui.card
    for _, w in ipairs({ ui.pickup, ui.clear, ui.drop, ui.openTouch, ui.showLayer, ui.layersTitle }) do w:Hide() end
    for _, r in ipairs(ui.rows) do r:Hide() end
    ui.bigIcon:SetTexCoord(0, 1, 0, 1)
    if selected.kind == "slot" then
        local info = C.SLOTS[selected.slot]
        local button = ui.slots[selected.slot]
        card.title:SetText(C.Combo(layer, info.glyph, 18) .. "   " .. (layer == "base" and "" or (C.LAYER_LABELS[layer] .. " + ")) .. info.name)
        ui.sub:SetText("Page " .. selectedPage .. " · " .. (layer == "base" and "Base bar" or (C.LAYER_LABELS[layer] .. " bar")))
        if button.fixed then
            if button.fixed.atlas then ui.bigIcon:SetAtlas(button.fixed.atlas) else ui.bigIcon:SetTexture(button.fixed.icon) end
            ui.bigIcon:Show()
            ui.name:SetText(button.fixed.name)
            ui.kind:SetText("Blizzard")
        else
            local name, texture, kind = ActionOf(button.storage)
            if texture then ui.bigIcon:SetTexture(texture); ui.bigIcon:Show()
            else ui.bigIcon:SetAtlas(ns.GamepadEmptyAtlas and ns.GamepadEmptyAtlas(selected.slot) or ""); ui.bigIcon:Show() end
            ui.name:SetText(name or "Empty")
            ui.kind:SetText(kind or "")
            ui.pickup:Show(); ui.clear:Show(); ui.drop:Show()
            local editable = button.storage ~= nil and not InCombat()
            ui.pickup:SetEnabled(editable and name ~= nil)
            ui.clear:SetEnabled(editable and name ~= nil)
            ui.drop:SetEnabled(editable)
        end
        -- The same button on every layer
        ui.layersTitle:Show()
        for index, l in ipairs(C.LAYERS) do
            local r = Row(index)
            r.combo:SetText(C.Combo(l, info.glyph, 16))
            local fixed = C.Fixed(l, selected.slot)
            local name, texture
            if fixed then
                name = fixed.name
                if fixed.atlas then r.icon:SetAtlas(fixed.atlas) else r.icon:SetTexture(fixed.icon) end
                r.icon:Show()
            else
                name, texture = ActionOf(Storage(l, selected.slot))
                if texture then r.icon:SetTexture(texture); r.icon:Show() else r.icon:Hide() end
            end
            r.name:SetText(name or "Empty")
            if name then r.name:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
            else r.name:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3]) end
            r.selection:SetShown(l == layer)
            r:SetScript("OnClick", function() selectedLayer = l; Refresh() end)
            r:Show()
        end
        return
    end
    local info = C.BUTTON_BY_ID[selected.id]
    card.title:SetText(C.Glyph(info.glyph, 18) .. "   " .. info.name)
    ui.bigIcon:SetAtlas("Gamepad_" .. info.glyph .. "_64")
    ui.bigIcon:Show()
    ui.kind:SetText("")
    if info.role == "layer" then
        ui.name:SetText(info.name .. " bar")
        ui.sub:SetText("Hold for the " .. info.name .. " bar")
        ui.showLayer.label:SetText(selectedLayer == info.layer and "Show Base" or ("Show " .. info.name))
        ui.showLayer:Show()
    elseif info.role == "touchpad" then
        local s = ns.Touch and ns.Touch.Settings and ns.Touch.Settings()
        local on = s and s.enabled
        ui.name:SetText(on and "Touchpad zones" or "Blizzard")
        if on and T then
            local grid = T.Grid(s, s.mode)
            ui.sub:SetText(grid.cols .. " × " .. grid.rows .. (s.mode == "split" and " · right half" or ""))
        else
            ui.sub:SetText("Zones off")
        end
        ui.openTouch:Show()
    else
        local runs = BindingOf(info.key)
        ui.name:SetText(runs or "Not bound")
        ui.sub:SetText("")
    end
end

-- Refresh ------------------------------------------------------------------------

Refresh = function()
    if not window or not window:IsShown() then return end
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
            if b.fixed.atlas then b.icon:SetAtlas(b.fixed.atlas) else b.icon:SetTexture(b.fixed.icon) end
            b.icon:Show()
            b.icon:SetDesaturated(false)
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
        elseif info.role == "touchpad" then runs = nil
        else runs = BindingOf(info.key) end
        b.runs = runs
        if b.text then
            local glyph = C.Glyph(info.glyph, 14)
            if info.role == "layer" then
                b.text:SetText(glyph .. " " .. info.name)
                if layer == info.layer or layer == "both" then b.text:SetTextColor(S.YELLOW[1], S.YELLOW[2], S.YELLOW[3])
                else b.text:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3]) end
            else
                b.text:SetText(glyph .. (runs and ("\n" .. runs) or ""))
                b.text:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
            end
        end
    end
    LayoutZones(layer)
    RefreshCard()
    local note = InCombat() and "Not in combat" or "Drag: pick up · Click: drop"
    ui.status:SetText(note)
end

-- Build --------------------------------------------------------------------------

local function Build()
    window = CreateFrame("Frame", "GamepadCompanionController", UIParent)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window.chrome = S.Chrome(window, "Gamepad Companion · Controller")
    body = CreateFrame("Frame", nil, window)
    body:SetSize(BODY_W, BODY_H)

    -- Layers and pages
    local x = 0
    for _, layer in ipairs(C.LAYERS) do
        local glyphs = C.Combo(layer, nil, 14)
        local label = layer == "base" and "Base" or glyphs
        local width = layer == "both" and 84 or 64
        ui.layers[layer] = S.NewButton(body, label, x, 0, width, function()
            selectedLayer = layer
            Refresh()
        end, nil, 12, 28)
        S.Tooltip(ui.layers[layer], C.LAYER_LABELS[layer])
        x = x + width + 6
    end
    local pageX = ART_W - C.PAGES * 40 - 50
    ui.pageLabel = S.Text(body, "Page", pageX, -8, 46, 12, S.GOLD)
    for p = 1, C.PAGES do
        ui.pages[p] = S.NewButton(body, tostring(p), pageX + 46 + (p - 1) * 40, 0, 36, function()
            selectedPage = p
            Refresh()
        end, nil, 12, 28)
        S.Tooltip(ui.pages[p], "Page " .. p, p == ActivePage() and "Active" or nil)
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

    -- Card: the selected button
    ui.card = S.Card(body, " ", CARD_X, 0, CARD_W, BODY_H - 36)
    local card = ui.card
    ui.bigIcon = card:CreateTexture(nil, "ARTWORK")
    ui.bigIcon:SetSize(52, 52)
    ui.bigIcon:SetPoint("TOPLEFT", 12, -42)
    ui.name = S.Text(card, "", 74, -48, CARD_W - 86, 14, S.GOLD)
    ui.name:SetWordWrap(false)
    ui.kind = S.Text(card, "", 74, -70, CARD_W - 86, 11, S.GREY)
    ui.sub = S.Note(card, 12, -104, CARD_W - 24, 1, 11, S.GREY)
    ui.pickup = S.NewButton(card, "Pick up", 12, -126, 100, function()
        local b = ui.slots[selected.slot]
        if b and b.storage and ns.GamepadSlotEditable and ns.GamepadSlotEditable(b.storage) then
            Call(PickupAction, b.storage)
            Refresh()
        end
    end)
    ui.clear = S.NewButton(card, "Clear", 118, -126, 80, function()
        local b = ui.slots[selected.slot]
        if b and b.storage and ns.GamepadSlotEditable and ns.GamepadSlotEditable(b.storage)
            and not (GetCursorInfo and GetCursorInfo()) then
            Call(PickupAction, b.storage)
            Call(ClearCursor)
            Refresh()
        end
    end)
    ui.drop = S.NewButton(card, "Drop spell, item or macro", 12, -160, CARD_W - 24, nil, nil, 11, 36)
    ui.drop.label:SetTextColor(S.GREY[1], S.GREY[2], S.GREY[3])
    local function DropHere()
        local b = ui.slots[selected.slot]
        if b and Drop(b) then Refresh() end
    end
    ui.drop:SetScript("OnClick", DropHere)
    ui.drop:SetScript("OnReceiveDrag", DropHere)
    ui.openTouch = S.NewButton(card, "Touchpad window", 12, -126, CARD_W - 24, function()
        if API.ToggleTouchpad then API.ToggleTouchpad() end
    end)
    ui.showLayer = S.NewButton(card, "", 12, -126, CARD_W - 24, function()
        local info = C.BUTTON_BY_ID[selected.id]
        selectedLayer = selectedLayer == info.layer and "base" or info.layer
        Refresh()
    end)
    ui.layersTitle = S.Text(card, "Every layer", 12, -214, nil, 11, S.YELLOW)

    S.NewButton(body, "Close", BODY_W - 100, -(BODY_H - 28), 100, function() window:Hide() end)

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
    window:SetScript("OnShow", function()
        selectedPage = ActivePage() or selectedPage
        Refresh()
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
    UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionController"
    S.RegisterWindow(window)
    window:Hide()
end

local function ApplyStyle()
    window.chrome:SetKind(S.ChromeKind(S.CurrentStyle()))
    local inset = window.chrome:Insets()
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", inset.left, -inset.top)
    window:SetSize(BODY_W + inset.left + inset.right, BODY_H + inset.top + inset.bottom)
    S.Fit(window)
end

function API.ToggleController()
    if not window then Build() end
    if window:IsShown() then window:Hide(); return end
    ApplyStyle()
    window:Show()
    window:Raise()
end

-- Harness access
ns.ControllerWindow = function() return window, ui end
