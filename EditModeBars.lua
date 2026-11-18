-- Blizzard Edit Mode, with what it lacks for the controller bars: each bar
-- Companion places (Base, L2, R2, L2 + R2, the compact stack, Stance, the
-- class buttons) gets Blizzard's own selection box in Edit Mode. Click one to
-- pick it (Blizzard's frames let go), drag it to move it (it snaps to Edit
-- Mode's grid when Snap is on), arrows nudge it; a small dialog has its Scale,
-- its button prompt and Reset. Blizzard still moves the controller bar block
-- itself, and Compact / Expand stay Blizzard's settings.
--
-- The suite's Edit Mode pattern (as social_diary's toast and Plumber's
-- SharedEditMode on this client): Edit Mode is listened to (EventRegistry's
-- EditMode.Enter / EditMode.Exit), never hooked; our own boxes and dialog, no
-- Blizzard template, nothing registered with the manager, none of its tables
-- written. Picking one of ours clears Blizzard's pick (ClearSelectedSystem, its
-- own secure delegate); a click anywhere else lets ours go. A fight ends it.
-- Values are Companion's own (offsets from Blizzard's spot, per Compact /
-- Standard): Blizzard's saved layouts are never touched.
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

-- A box in Edit Mode's colours: blue while waiting, gold once picked, the name on it
local BLUE, GOLD = { 0.25, 0.6, 1 }, { 1, 0.82, 0.2 }
local function Paint(sel, c, fill)
    sel.fill:SetColorTexture(c[1], c[2], c[3], fill)
    for _, e in ipairs(sel.edges) do e:SetColorTexture(c[1], c[2], c[3], 0.95) end
end

local function Selection(proxy)
    local sel = CreateFrame("Frame", nil, proxy)
    sel:SetAllPoints(proxy)
    sel:SetFrameLevel(999)
    sel:EnableMouse(true)
    if sel.RegisterForDrag then sel:RegisterForDrag("LeftButton") end
    sel.fill = sel:CreateTexture(nil, "BACKGROUND")
    sel.fill:SetAllPoints()
    sel.edges = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
        { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local e = sel:CreateTexture(nil, "BORDER")
        e:SetPoint(p[1]); e:SetPoint(p[2])
        if i <= 2 then e:SetHeight(2) else e:SetWidth(2) end
        sel.edges[i] = e
    end
    sel.label = sel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    sel.label:SetPoint("CENTER")
    function sel:ShowSelected() Paint(self, GOLD, 0.3); self.label:SetText(proxy:GetSystemName()); self.isSelected = true; self:Show() end
    function sel:ShowHighlighted() Paint(self, BLUE, 0.18); self.label:SetText(""); self.isSelected = false; self:Show() end
    sel:SetScript("OnEnter", function(self) if not self.isSelected then self.label:SetText(proxy:GetSystemName()) end end)
    sel:SetScript("OnLeave", function(self) if not self.isSelected then self.label:SetText("") end end)
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
    if not layer then return Place() end
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
-- Where the dialog goes (its bottom-left, UIParent units) for a picked bar's
-- box: above it when there is room, else below, else beside it, else the top
-- right corner; never over the bar, always on the screen. Dragged by the user:
-- that spot, for the session (as Blizzard's own dialog keeps its place).
local GAP = 10
function EB.DialogSpot(r, dw, dh, sw, sh)
    local function Clamp(x, lo, hi) return max(lo, min(hi, x)) end
    local cx = Clamp(r.left + r.width / 2 - dw / 2, 0, sw - dw)
    local top = r.bottom + r.height
    if top + GAP + dh <= sh then return cx, top + GAP end                     -- above
    if r.bottom - GAP - dh >= 0 then return cx, r.bottom - GAP - dh end      -- below
    local cy = Clamp(r.bottom + r.height / 2 - dh / 2, 0, sh - dh)
    if r.left + r.width + GAP + dw <= sw then return r.left + r.width + GAP, cy end   -- right
    if r.left - GAP - dw >= 0 then return r.left - GAP - dw, cy end         -- left
    return sw - dw, sh - dh                                                  -- a corner
end

local dialog
local function Dialog()
    if dialog then return dialog end
    local ok, d = pcall(CreateFrame, "Frame", "GamepadCompanionEditModeDialog", UIParent, "DialogBorderTranslucentTemplate")
    if not ok or type(d) ~= "table" then d = CreateFrame("Frame", "GamepadCompanionEditModeDialog", UIParent) end
    d:SetSize(250, 150)
    d:SetFrameStrata("DIALOG")
    d:SetClampedToScreen(true)
    d:EnableMouse(true)
    -- the user's own spot: dragged anywhere, kept for the session
    d:SetMovable(true)
    if d.RegisterForDrag then d:RegisterForDrag("LeftButton") end
    d:SetScript("OnDragStart", function(self) self:StartMoving() end)
    d:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local l, b = self:GetLeft(), self:GetBottom()
        if Readable(l) and Readable(b) then
            EB.dialogSpot = { l, b }
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
        end
    end)
    local okX, close = pcall(CreateFrame, "Button", nil, d, "UIPanelCloseButton")
    if okX and type(close) == "table" then
        close:SetPoint("TOPRIGHT", -2, -2)
        close:SetScript("OnClick", function() Select(nil) end)
        d.close = close
    end
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
    -- beside the bar, never over it (or where the user dragged it)
    local x, y
    if EB.dialogSpot then
        x, y = EB.dialogSpot[1], EB.dialogSpot[2]
    else
        local r = EB.Rect(selected)
            or { left = p:GetLeft() or 0, bottom = p:GetBottom() or 0, width = p:GetWidth() or 0, height = p:GetHeight() or 0 }
        x, y = EB.DialogSpot(r, d:GetWidth(), d:GetHeight(), UIParent:GetWidth(), UIParent:GetHeight())
    end
    d:ClearAllPoints()
    d:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
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
-- A click anywhere but our boxes and dialog lets ours go (Blizzard's frames
-- included); a fight ends it all
local function Over(frame) return frame and frame.IsShown and frame:IsShown() and frame.IsMouseOver and frame:IsMouseOver() end
function EB.MouseDown()
    if not (EB.active and selected) then return end
    for _, p in pairs(EB.proxies) do if Over(p) then return end end
    if dialog and Over(dialog) then return end
    selected = nil
    Place()
end
local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "GLOBAL_MOUSE_DOWN")
pcall(events.RegisterEvent, events, "PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "GLOBAL_MOUSE_DOWN" then EB.MouseDown() else EB.Exit() end
end)
EB.events = events
