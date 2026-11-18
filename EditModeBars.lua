-- Blizzard Edit Mode, with what it lacks for the controller bars: each bar
-- Companion places (Base, L2, R2, L2 + R2, the compact stack, Stance, the
-- class buttons) gets Blizzard's own selection box in Edit Mode. Click one to
-- pick it (Blizzard's frames let go), drag it to move it (it snaps to Edit
-- Mode's grid when Snap is on), arrows nudge it; a small dialog has its Scale,
-- its button prompt and Reset. Blizzard still moves the controller bar block
-- itself, and Compact / Expand stay Blizzard's settings.
--
-- The LibEditMode pattern, in house: our own frames under Blizzard's selection
-- template, Edit Mode's Enter / Exit callbacks, nothing registered with the
-- manager and none of its tables written. Values are Companion's own (the
-- offsets from Blizzard's spot, per Compact / Standard), so Blizzard's saved
-- layouts are never touched.
local _, ns = ...
local M = ns.Model
local API = GamepadCompanionAPI
local EB = { proxies = {} }
ns.EditModeBars = EB

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local NUDGE = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 },
    PADDUP = { 0, 1 }, PADDDOWN = { 0, -1 }, PADDLEFT = { -1, 0 }, PADDRIGHT = { 1, 0 } }

local function Combat() return InCombatLockdown and InCombatLockdown() end
local function Readable(v) return type(v) == "number" and v == v and not (issecretvalue and issecretvalue(v)) end

---------------------------------------------------------------------------
-- What is placed, and where it is
---------------------------------------------------------------------------
-- The bars of the layout in use, then this class's menu buttons
function EB.Layers(mode)
    local list = {}
    for _, layer in ipairs(mode == "compact" and M.compactLayers or M.layoutLayers) do
        if M.classKeys[layer] then
            local _, class = UnitClass("player")
            local use = class and M.Readable(class) and M.classButtonUse[class]
            if use and use[layer] then list[#list + 1] = layer end
        else
            list[#list + 1] = layer
        end
    end
    return list
end

function EB.Name(layer)
    if M.classKeys[layer] then
        local _, class = UnitClass("player")
        local use = class and M.classButtonUse[class] and M.classButtonUse[class][layer]
        return use and (M.classMenuNames[use] or use) or M.layerNames[layer]
    end
    return M.layerNames[layer] or layer
end

-- The bar's frame (the compact stack: its Base bar)
local function FrameOf(layer)
    if not API.GetBarFrame then return nil end
    local ok, frame = pcall(API.GetBarFrame, layer == "bars" and "base" or layer)
    return ok and type(frame) == "table" and frame or nil
end

-- The bar's box in UIParent units, and how many of its offset units one UIParent unit is
function EB.Rect(layer)
    local frame = FrameOf(layer)
    if not frame then return nil end
    local ok, l, b, w, h, fs = pcall(function()
        return frame:GetLeft(), frame:GetBottom(), frame:GetWidth(), frame:GetHeight(), frame:GetEffectiveScale()
    end)
    local us = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not ok then return nil end
    for _, v in ipairs({ l, b, w, h, fs, us }) do if not Readable(v) then return nil end end
    if fs <= 0 or us <= 0 or w <= 0 or h <= 0 then return nil end
    local r = fs / us
    return { left = l * r, bottom = b * r, width = w * r, height = h * r, units = us / fs }
end

local function Value(layer, key)
    local layout = M.Layout(API.GetSettings(), API.GetMode())
    return layout[layer] and layout[layer][key] or (key == "scale" and 1 or 0)
end

-- Move a bar by (dx, dy) of its offset units, inside Model's bounds
local function MoveBy(layer, dx, dy)
    local mode = API.GetMode()
    local bx, by = M.bounds.x, M.bounds.y
    local x = max(bx[1], min(bx[2], floor(Value(layer, "x") + dx + 0.5)))
    local y = max(by[1], min(by[2], floor(Value(layer, "y") + dy + 0.5)))
    API.SetBarOption(layer, "x", x, mode)
    return API.SetBarOption(layer, "y", y, mode)
end
EB.MoveBy = MoveBy

-- Edit Mode's grid: snap a point to its lines (centred on the screen) when Snap is on
function EB.Snap(px, py)
    local manager = EditModeManagerFrame
    local on = manager and manager.IsSnapEnabled and select(2, pcall(manager.IsSnapEnabled, manager))
    local spacing = manager and manager.Grid and manager.Grid.gridSpacing
    if on ~= true or not Readable(spacing) or spacing <= 0 then return px, py end
    local cx, cy = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    return cx + floor((px - cx) / spacing + 0.5) * spacing, cy + floor((py - cy) / spacing + 0.5) * spacing
end

---------------------------------------------------------------------------
-- The boxes
---------------------------------------------------------------------------
local selected
local Place, Select, ShowDialog

local function Selection(proxy)
    -- Blizzard's own box when the client has it; a plain one otherwise
    local ok, sel = pcall(CreateFrame, "Frame", nil, proxy, "EditModeSystemSelectionTemplate")
    if not ok or type(sel) ~= "table" or not sel.ShowSelected then
        sel = CreateFrame("Frame", nil, proxy)
        sel.fill = sel:CreateTexture(nil, "OVERLAY")
        sel.fill:SetAllPoints()
        function sel:ShowSelected() self.fill:SetColorTexture(1, 0.82, 0.2, 0.35); self.isSelected = true; self:Show() end
        function sel:ShowHighlighted() self.fill:SetColorTexture(0.3, 0.6, 1, 0.25); self.isSelected = false; self:Show() end
        sel:EnableMouse(true)
        if sel.RegisterForDrag then sel:RegisterForDrag("LeftButton") end
    end
    sel:SetAllPoints(proxy)
    sel.parent, sel.system = proxy, proxy
    if sel.SetSystem then pcall(sel.SetSystem, sel, proxy) end
    sel:SetScript("OnMouseDown", function() Select(proxy.layer) end)
    sel:SetScript("OnDragStart", function() proxy:OnDragStart() end)
    sel:SetScript("OnDragStop", function() proxy:OnDragStop() end)
    return sel
end

local function Proxy(layer)
    local p = EB.proxies[layer]
    if p then return p end
    p = CreateFrame("Frame", nil, UIParent)
    p.layer = layer
    p:SetFrameStrata("MEDIUM")
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    function p:GetSystemName() return EB.Name(self.layer) end
    function p:OnDragStart()
        if Combat() then return end
        Select(self.layer)
        self.from = { self:GetLeft(), self:GetBottom() }
        EB.dragging = true
        self:StartMoving()
    end
    function p:OnDragStop()
        self:StopMovingOrSizing()
        EB.dragging = false
        local from, rect = self.from, EB.Rect(self.layer)
        self.from = nil
        if not (from and rect) then return Place() end
        local l, b = EB.Snap(self:GetLeft(), self:GetBottom())
        local dx, dy = (l - from[1]) * rect.units, (b - from[2]) * rect.units
        if abs(dx) >= 0.5 or abs(dy) >= 0.5 then MoveBy(self.layer, dx, dy) end
        Place()
    end
    p.selection = Selection(p)
    EB.proxies[layer] = p
    return p
end

-- Every box over its bar; the picked one selected
Place = function()
    for _, p in pairs(EB.proxies) do p:Hide() end
    if not EB.active then return end
    for _, layer in ipairs(EB.Layers(API.GetMode())) do
        local rect = EB.Rect(layer)
        if rect then
            local p = Proxy(layer)
            p:ClearAllPoints()
            p:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect.left, rect.bottom)
            p:SetSize(rect.width, rect.height)
            if layer == selected then p.selection:ShowSelected() else p.selection:ShowHighlighted() end
            p:Show()
        end
    end
    if selected and not (EB.proxies[selected] and EB.proxies[selected]:IsShown()) then selected = nil end
    ShowDialog()
end
EB.Place = Place

Select = function(layer)
    if selected == layer then return end
    selected = layer
    -- Blizzard's frames let go (its own secure delegate) and its dialog closes
    local manager = EditModeManagerFrame
    if layer and manager and manager.ClearSelectedSystem then pcall(manager.ClearSelectedSystem, manager) end
    Place()
end
EB.Select = Select
function EB.Selected() return selected end

---------------------------------------------------------------------------
-- The dialog: Scale, the button prompt, Reset
---------------------------------------------------------------------------
local dialog
local function Dialog()
    if dialog then return dialog end
    local ok, d = pcall(CreateFrame, "Frame", "GamepadCompanionEditModeDialog", UIParent, "DialogBorderTranslucentTemplate")
    if not ok or type(d) ~= "table" then d = CreateFrame("Frame", "GamepadCompanionEditModeDialog", UIParent) end
    d:SetSize(250, 150)
    d:SetFrameStrata("DIALOG")
    d:SetClampedToScreen(true)
    d:EnableMouse(true)
    d.title = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    d.title:SetPoint("TOP", 0, -16)
    local function Btn(text, w, x, y, onClick)
        local b = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
        b:SetSize(w, 24)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(text)
        b.text = text
        b:SetScript("OnClick", onClick)
        return b
    end
    d.scaleLabel = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.scaleLabel:SetPoint("TOPLEFT", 18, -52)
    d.scaleLabel:SetText("Scale")
    local function Scale(dir)
        if not selected or Combat() then return end
        local step = (IsShiftKeyDown and IsShiftKeyDown()) and 0.01 or 0.05
        local v = floor((Value(selected, "scale") + dir * step) * 100 + 0.5) / 100
        API.SetBarOption(selected, "scale", max(M.bounds.scale[1], min(M.bounds.scale[2], v)), API.GetMode())
        Place()
    end
    d.minus = Btn("-", 28, 96, -46, function() Scale(-1) end)
    d.scaleValue = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.scaleValue:SetPoint("TOPLEFT", 128, -52)
    d.scaleValue:SetWidth(60)
    d.plus = Btn("+", 28, 192, -46, function() Scale(1) end)
    local okC, check = pcall(CreateFrame, "CheckButton", nil, d, "UICheckButtonTemplate")
    if not okC or type(check) ~= "table" then check = CreateFrame("CheckButton", nil, d) end
    check:SetPoint("TOPLEFT", 14, -78)
    check:SetSize(26, 26)
    check.label = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.label:SetText("Button prompt")
    check:SetScript("OnClick", function(self)
        if Combat() then return end
        API.SetClassPrompts(self:GetChecked() == true)
    end)
    d.prompt = check
    d.reset = Btn("Reset", 100, 75, -112, function()
        if not selected or Combat() then return end
        API.ResetBar(selected, API.GetMode())
        Place()
    end)
    -- arrows and the d-pad nudge the picked bar (Shift: 1, else 10)
    local function Press(self, key)
        local n = NUDGE[key]
        if self.SetPropagateKeyboardInput and not Combat() then pcall(self.SetPropagateKeyboardInput, self, not n) end
        if not (n and selected) or Combat() then return end
        local step = (IsShiftKeyDown and IsShiftKeyDown()) and 1 or 10
        MoveBy(selected, n[1] * step, n[2] * step)
        Place()
    end
    d:SetScript("OnKeyDown", Press)
    d:SetScript("OnGamePadButtonDown", Press)
    d:Hide()
    dialog = d
    return d
end

ShowDialog = function()
    local p = selected and EB.proxies[selected]
    if not (EB.active and p and p:IsShown()) then
        if dialog then dialog:Hide() end
        return
    end
    local d = Dialog()
    d.title:SetText(EB.Name(selected))
    d.scaleValue:SetText(string.format("%.2f", Value(selected, "scale")))
    local class = M.classKeys[selected] ~= nil
    d.prompt:SetShown(class)
    d.prompt.label:SetShown(class)
    d.prompt:SetChecked(API.GetSettings().classPrompts ~= false)
    d:ClearAllPoints()
    d:SetPoint("TOP", p, "BOTTOM", 0, -8)
    d:Show()
    if not Combat() then
        pcall(d.EnableKeyboard, d, true)
        if d.EnableGamePadButton then pcall(d.EnableGamePadButton, d, true) end
    end
end

---------------------------------------------------------------------------
-- Edit Mode's Enter / Exit
---------------------------------------------------------------------------
local function Usable()
    local settings, state = API.GetSettings(), API.GetState()
    return settings.enabled == true and state.available == true and not Combat()
end

function EB.Enter()
    if EB.active or not Usable() then return end
    EB.active = true
    API.SetEditing(true)                      -- every bar shown while editing
    if API.Subscribe then API.Subscribe(EB, function() if not EB.dragging then Place() end end) end
    Place()
end

function EB.Exit()
    if not EB.active then return end
    EB.active, selected = false, nil
    if API.Unsubscribe then API.Unsubscribe(EB) end
    Place()
    -- (still shown while Companion's window is open)
    local window = ns.Shell and ns.Shell.Window and ns.Shell.Window()
    if not (window and window:IsShown()) then API.SetEditing(false) end
end

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", EB.Enter, EB)
    EventRegistry:RegisterCallback("EditMode.Exit", EB.Exit, EB)
end
-- A Blizzard frame picked: ours lets go
if hooksecurefunc and EditModeManagerFrame and EditModeManagerFrame.SelectSystem then
    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(_, frame)
        if selected and not (frame and frame.layer) then selected = nil; Place() end
    end)
end
