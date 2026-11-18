-- The Bars, Tools and Help pages of the Gamepad Companion window (Window.lua).
--   Bars   where Blizzard's controller bars and class buttons sit, and their size
--   Tools  Blizzard's spellbook, macros, Edit Mode and gamepad options; spread
--          view; Edit Mode layouts; the character's profile
--   Help   HelpPage.lua
local ADDON, ns = ...
local S, Shell = ns.OptionsSkin, ns.Shell
local API = GamepadCompanionAPI
local GOLD, GREY, DIM, YELLOW = S.GOLD, S.GREY, S.DIM, S.YELLOW
local Text, Note, Button, Tooltip, SetSelected = S.Text, S.Note, S.NewButton, S.Tooltip, S.SetSelected
local W, H = Shell.W, Shell.H

-- Targets per layout. Compact mode stacks the four trigger bars in one spot and
-- shows only the active one, so they share a single "Action bars" entry there.
local targetsByMode = {
    compact = { { "bars", "Action bars" }, { "stance", "Stance" } },
    standard = { { "base", "Base" }, { "lt", "L2" }, { "rt", "R2" }, { "both", "L2 + R2" }, { "stance", "Stance" } },
}
local classTargets = { { "classLeft", "L1 + L2" }, { "classRight", "R1 + R2" } }
local classMenuNames = {
    Forms = "Form menu", Auras = "Aura menu", Stances = "Stance menu", Pet = "Pet menu", ["Pet spells"] = "Pet spells",
}
local tips = {
    bars = "All 4 trigger bars",
    base = "Also moves page selector and shoulder icons",
    stance = "Edit its actions in Spread view",
}
-- step, fine step, minimum, maximum, display format, name
local specs = {
    x = { 10, 1, -2000, 2000, "%.0f", "X" },
    y = { 10, 1, -2000, 2000, "%.0f", "Y" },
    scale = { 0.05, 0.01, 0.5, 2, "%.2f", "Scale" },
}
-- Arrow steps: pixels for offsets, and the matching scale step
local nudgeSteps = { { "1", 1, 0.01 }, { "10", 10, 0.05 }, { "50", 50, 0.10 } }

local mode, selected, refreshing = nil, "base", false
local ui = { tabs = {}, modeButtons = {}, controls = {}, arrows = {}, stepButtons = {} }
local step = 2
local spellButtons = {}
local openingPanel, reopenAfterSettings
local Refresh

local function PlayerClassButtons()
    local _, class = UnitClass("player")
    if issecretvalue and issecretvalue(class) then return {} end
    return ns.Model and ns.Model.classButtonUse[class] or {}
end

-- Targets for the mode being edited: its bars, then this class's L1 + L2 /
-- R1 + R2 menu buttons. Classes without one don't see those.
local function Targets()
    local list = {}
    for _, entry in ipairs(targetsByMode[mode]) do list[#list + 1] = entry end
    local uses = PlayerClassButtons()
    for _, entry in ipairs(classTargets) do
        local use = uses[entry[1]]
        if use then list[#list + 1] = { entry[1], classMenuNames[use] or use, entry[2], use } end
    end
    return list
end

local function IsClassTarget(key) return key == "classLeft" or key == "classRight" end
local function Window() return Shell.Window() end

-- Blizzard's gamepad options -----------------------------------------------------
-- In the gamepad interface Blizzard's Settings panel is not opened from addon code: the
-- gamepad window manager would then run under addon taint (the "A and B dead until
-- /reload" bug). The note says where to find the options instead.
local GAMEPAD_UI_NOTE = "Game menu > Options > Gamepad"
local function GamepadUI()
    local ok, on = pcall(function() return InputUtil.IsGamepadUIEnabled() end)
    return ok and ns.Model.Readable(on) and on == true
end

local function OpenGamepadSettings()
    if InCombatLockdown() then return false, "Not in combat" end
    if GamepadUI() then return false, GAMEPAD_UI_NOTE end
    local id
    local category = Settings and Settings.GetCategory and GAMEPAD_LABEL and select(2, pcall(Settings.GetCategory, GAMEPAD_LABEL))
    if type(category) == "table" and category.GetID then id = category:GetID() end
    if not id and SettingsPanel and SettingsPanel.GetAllCategories then
        local ok, all = pcall(SettingsPanel.GetAllCategories, SettingsPanel)
        for _, entry in ipairs(ok and all or {}) do
            if entry.GetName and entry:GetName() == GAMEPAD_LABEL then id = entry:GetID(); break end
        end
    end
    -- The client opens the panel itself (C_SettingsUtil). Since build 70338 the
    -- compact action bar checkbox lives in Edit Mode, so there is no anchor.
    local opened
    if C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
        opened = pcall(C_SettingsUtil.OpenSettingsPanel, id)
    elseif Settings and Settings.OpenToCategory then
        opened = pcall(Settings.OpenToCategory, id)
    end
    if not opened then return false, GAMEPAD_UI_NOTE end
    return true
end
API.OpenGamepadSettings = OpenGamepadSettings

-- Values -----------------------------------------------------------------------

local function Current(key)
    local settings = API.GetSettings()
    local layout = mode == "compact" and settings.compact or settings.bars
    return layout[selected] and layout[selected][key] or 0
end

local function Notice(message) Shell.SetStatus(message, true) end

local function Result(ok, reason)
    Refresh()
    if reason then
        Notice((reason == "combat" or reason == "pending") and "Applies after combat" or tostring(reason))
    elseif ok == false then
        Notice("Not applied")
    end
end

local function Submit(key, value)
    if refreshing or not ui.supported then return end
    local spec = specs[key]
    if not value or value ~= value or value < spec[3] or value > spec[4] then
        Refresh()
        Notice(string.format("%g to %g only", spec[3], spec[4]))
        return
    end
    -- Round away float drift from repeated fine steps.
    value = math.floor(value / spec[2] + 0.5) * spec[2]
    Result(API.SetBarOption(selected, key, value, mode))
end

local function Step(key, direction, size)
    local spec = specs[key]
    if IsShiftKeyDown and IsShiftKeyDown() then size = spec[2] end
    size = size or spec[1]
    Submit(key, math.max(spec[3], math.min(spec[4], Current(key) + direction * size)))
end

-- Accept "0,9" as well as "0.9".
local function ParseNumber(text)
    return tonumber((tostring(text or ""):gsub(",", ".")))
end

-- Blizzard's panels, from the hardware click -------------------------------------

local function ReturnToEditor()
    local reopen = openingPanel
    openingPanel = nil
    local window = Window()
    if reopen and window and not window:IsShown() and not InCombatLockdown() then window:Show() end
end

local function RefreshSpellbookButtons()
    if InCombatLockdown() then return end
    local delegate = SpellbookMicroButton
    local aspect = Enum and Enum.ForbiddenAspect and Enum.ForbiddenAspect.ScriptedInput
    local usable = false
    if delegate and aspect and type(delegate.HasAccessConstraints) == "function"
        and type(delegate.HasAnyForbiddenAspects) == "function" then
        local okAccess, constrained = pcall(delegate.HasAccessConstraints, delegate)
        local okScript, forbidden = pcall(delegate.HasAnyForbiddenAspects, delegate, aspect)
        usable = okAccess and okScript
            and not (issecretvalue and (issecretvalue(constrained) or issecretvalue(forbidden)))
            and constrained == false and forbidden == false
    end
    for _, button in ipairs(spellButtons) do
        button:SetAttribute("type", usable and "click" or nil)
        button:SetAttribute("clickbutton", usable and delegate or nil)
        button.ready = usable
    end
end

-- A secure button that runs a slash command from the click (Blizzard's panels
-- must not be opened from addon code)
local function SlashButton(parent, label, x, y, width, height, slash)
    local b = Button(parent, label, x, y, width, nil, "InsecureActionButtonTemplate", 13, height)
    b:RegisterForClicks("LeftButtonUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", slash)
    return b
end

-- Bars page ----------------------------------------------------------------------
-- One strip for the layout (Blizzard's Compact / Standard, read from Edit Mode;
-- Copy and Reset for the whole layout), then three columns: the bars, a live
-- preview of the screen (click a bar to pick it, drag to move it; arrows and the
-- pad's d-pad nudge it while the pointer is over it), and the picked bar's values
-- (X, Y, Scale, its prompt) with one Reset.

local function Arrow(button, direction)
    local atlas = direction == "left" and "common-icon-backarrow" or "common-icon-forwardarrow"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if info and button.CreateTexture then
        button.label:SetText("")
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetAtlas(atlas)
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER")
        if icon.SetRotation then
            icon:SetRotation(direction == "up" and math.pi / 2 or direction == "down" and -math.pi / 2 or 0)
        end
        button:HookScript("OnEnable", function() icon:SetDesaturated(false); icon:SetAlpha(1) end)
        button:HookScript("OnDisable", function() icon:SetDesaturated(true); icon:SetAlpha(0.5) end)
    else
        button.label:SetText(({ up = "Up", down = "Down", left = "<", right = ">" })[direction])
    end
end

-- A label and a typed value; [-] [+] only where nothing else steps it (Scale)
local function ValueRow(parent, key, x, y, width, steppers)
    local spec = specs[key]
    local c = {}
    c.label = Text(parent, spec[6], x, y - 8, 60, 13, GOLD)
    local editX, editW = x + 60, width - 60
    if steppers then
        editX, editW = x + 60 + 40, width - 60 - 80
        c.minus = Button(parent, "-", x + 60, y, 36, function() Step(key, -1) end, nil, 16, 30)
        c.plus = Button(parent, "+", x + width - 36, y, 36, function() Step(key, 1) end, nil, 16, 30)
        Tooltip(c.minus, spec[6], string.format("Shift-click: -%g", spec[2]))
        Tooltip(c.plus, spec[6], string.format("Shift-click: +%g", spec[2]))
    end
    local edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    edit:SetPoint("TOPLEFT", editX, y)
    edit:SetSize(editW, 30)
    edit:SetFontObject("GameFontHighlight")
    edit:SetJustifyH("CENTER")
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(12)
    S.Edit(edit)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    -- Leaving the box without Enter puts the saved value back.
    edit:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetText(string.format(spec[5], Current(key)))
    end)
    edit:SetScript("OnEnterPressed", function(self) Submit(key, ParseNumber(self:GetText())); self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Tab applies and moves to the next value
    edit:SetScript("OnTabPressed", function(self)
        Submit(key, ParseNumber(self:GetText()))
        local nextKey = ({ x = "y", y = "scale", scale = "x" })[key]
        local nextControl = ui.controls[nextKey]
        if nextControl and nextControl.edit:IsVisible() then nextControl.edit:SetFocus() else self:ClearFocus() end
    end)
    edit:EnableMouseWheel(true)
    edit:SetScript("OnMouseWheel", function(_, delta)
        if ui.supported and not edit:HasFocus() then Step(key, delta > 0 and 1 or -1) end
    end)
    c.edit = edit
    ui.controls[key] = c
    return c
end

-- Nudge the picked bar by the chosen step (Shift: 1)
local function Nudge(dx, dy)
    if not ui.supported then return end
    local size = nudgeSteps[step][2]
    if dx ~= 0 then Step("x", dx, size) end
    if dy ~= 0 then Step("y", dy, size) end
end
local NUDGE_KEYS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 },
    PADDUP = { 0, 1 }, PADDDOWN = { 0, -1 }, PADDLEFT = { -1, 0 }, PADDRIGHT = { 1, 0 } }

-- The preview: UIParent as a small screen, each bar of the layout a box
local preview = { boxes = {} }

-- A bar's box in UIParent units, or nil when it can't be read
local function BarRect(key)
    if not API.GetBarFrame then return nil end
    local ok, frame = pcall(API.GetBarFrame, key)
    if not ok or type(frame) ~= "table" then return nil end
    local okR, left, bottom, width, height = pcall(function()
        local l, b = frame:GetLeft(), frame:GetBottom()
        return l, b, frame:GetWidth(), frame:GetHeight()
    end)
    local okS, fs = pcall(frame.GetEffectiveScale, frame)
    local us = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not (okR and okS) then return nil end
    for _, v in ipairs({ left, bottom, width, height, fs, us }) do
        if type(v) ~= "number" or v ~= v or (issecretvalue and issecretvalue(v)) then return nil end
    end
    if fs <= 0 or us <= 0 or width <= 0 or height <= 0 then return nil end
    local r = fs / us
    return { left * r, bottom * r, width * r, height * r, units = us / fs }
end

local function PreviewScale()
    local uw = UIParent.GetWidth and UIParent:GetWidth() or 1920
    return preview.w / ((uw and uw > 0) and uw or 1920)
end

-- Drop a dragged box: the cursor's travel, as the bar's own offset units
local function DragStop(box)
    box:SetScript("OnUpdate", nil)
    local d = preview.drag
    preview.drag = nil
    if not d then return end
    local k = PreviewScale()
    local dx, dy = (d.cx - d.x0) / k * d.units, (d.cy - d.y0) / k * d.units
    if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return Refresh() end
    local x, y = Current("x") + dx, Current("y") + dy
    local sx, sy = specs.x, specs.y
    x = math.max(sx[3], math.min(sx[4], math.floor(x + 0.5)))
    y = math.max(sy[3], math.min(sy[4], math.floor(y + 0.5)))
    API.SetBarOption(selected, "x", x, mode)
    Result(API.SetBarOption(selected, "y", y, mode))
end

local function Cursor()
    local x, y = GetCursorPosition()
    local s = preview.frame:GetEffectiveScale() or 1
    return x / s, y / s
end

local function PreviewBox(key)
    local box = preview.boxes[key]
    if box then return box end
    box = CreateFrame("Button", nil, preview.frame)
    box.fill = box:CreateTexture(nil, "ARTWORK")
    box.fill:SetAllPoints()
    box.edge = {}
    for i = 1, 4 do box.edge[i] = box:CreateTexture(nil, "OVERLAY") end
    box.edge[1]:SetPoint("TOPLEFT"); box.edge[1]:SetPoint("TOPRIGHT"); box.edge[1]:SetHeight(1)
    box.edge[2]:SetPoint("BOTTOMLEFT"); box.edge[2]:SetPoint("BOTTOMRIGHT"); box.edge[2]:SetHeight(1)
    box.edge[3]:SetPoint("TOPLEFT"); box.edge[3]:SetPoint("BOTTOMLEFT"); box.edge[3]:SetWidth(1)
    box.edge[4]:SetPoint("TOPRIGHT"); box.edge[4]:SetPoint("BOTTOMRIGHT"); box.edge[4]:SetWidth(1)
    box.name = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.name:SetPoint("BOTTOM", box, "TOP", 0, 3)
    box.name:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnClick", function()
        if selected ~= key then selected = key; Refresh() end
    end)
    box:SetScript("OnDragStart", function(self)
        if not ui.supported or InCombatLockdown() then return end
        if selected ~= key then selected = key; Refresh() end
        local rect = BarRect(key)
        if not rect then return end
        local x0, y0 = Cursor()
        local _, _, _, px, py = self:GetPoint(1)
        px, py = tonumber(px) or 0, tonumber(py) or 0
        preview.drag = { x0 = x0, y0 = y0, cx = x0, cy = y0, px = px, py = py, units = rect.units }
        self:SetScript("OnUpdate", function(b)
            local d = preview.drag
            if not d then return b:SetScript("OnUpdate", nil) end
            d.cx, d.cy = Cursor()
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", preview.frame, "BOTTOMLEFT", d.px + d.cx - d.x0, d.py + d.cy - d.y0)
            ui.drag:SetText(string.format("X %+d  Y %+d", (d.cx - d.x0) / PreviewScale() * d.units,
                (d.cy - d.y0) / PreviewScale() * d.units))
        end)
    end)
    box:SetScript("OnDragStop", DragStop)
    preview.boxes[key] = box
    return box
end

local function DrawPreview(list)
    if not preview.frame then return end
    for _, box in pairs(preview.boxes) do box:Hide() end
    if preview.drag then return end
    local k = PreviewScale()
    local shown = 0
    for _, entry in ipairs(list) do
        local rect = BarRect(entry[1])
        if rect then
            local box = PreviewBox(entry[1])
            local on = entry[1] == selected
            box:ClearAllPoints()
            box:SetPoint("BOTTOMLEFT", preview.frame, "BOTTOMLEFT", rect[1] * k, rect[2] * k)
            box:SetSize(math.max(6, rect[3] * k), math.max(4, rect[4] * k))
            box.fill:SetColorTexture(1, 0.72, 0.2, on and 0.32 or 0.07)
            for _, e in ipairs(box.edge) do
                if on then e:SetColorTexture(1, 0.82, 0.35, 0.95) else e:SetColorTexture(0.85, 0.85, 0.85, 0.35) end
            end
            box.name:SetText(on and entry[2] or "")
            box:SetFrameLevel((preview.frame:GetFrameLevel() or 1) + (on and 3 or 1))
            box:Show()
            shown = shown + 1
        end
    end
    ui.drag:SetText(shown == 0 and "No bars to show" or "")
end

local function BuildPreview(card, x, y, w, h)
    local pv = CreateFrame("Frame", nil, card)
    pv:SetPoint("TOPLEFT", x, y)
    pv:SetSize(w, h)
    local bg = pv:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.03, 0.75)
    -- a screen: its rim and a faint centre cross
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
        local t = pv:CreateTexture(nil, "BORDER")
        t:SetPoint(p[1]); t:SetPoint(p[2])
        if p[3] then t:SetWidth(1) else t:SetHeight(1) end
        t:SetColorTexture(0.68, 0.5, 0.26, i == 1 and 0.6 or 0.4)
    end
    local v = pv:CreateTexture(nil, "BORDER")
    v:SetPoint("TOP"); v:SetPoint("BOTTOM"); v:SetWidth(1); v:SetColorTexture(1, 1, 1, 0.05)
    local hz = pv:CreateTexture(nil, "BORDER")
    hz:SetPoint("LEFT"); hz:SetPoint("RIGHT"); hz:SetHeight(1); hz:SetColorTexture(1, 1, 1, 0.05)
    -- arrows and the pad's d-pad nudge while the pointer is over the screen
    pv:EnableMouse(true)
    local function Keys(on)
        if InCombatLockdown() then return end
        pcall(pv.EnableKeyboard, pv, on)
        if pv.EnableGamePadButton then pcall(pv.EnableGamePadButton, pv, on) end
    end
    pv:SetScript("OnEnter", function() Keys(true) end)
    pv:SetScript("OnLeave", function() Keys(false) end)
    local function Press(self, key)
        local n = NUDGE_KEYS[key]
        if not InCombatLockdown() and self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, not n) end
        if n then Nudge(n[1], n[2]) end
    end
    pv:SetScript("OnKeyDown", Press)
    pv:SetScript("OnGamePadButtonDown", Press)
    preview.frame, preview.w, preview.h = pv, w, h
    return pv
end

local function BuildBars(frame, header)
    ui.frame = frame
    ui.enable = S.NewCheck(header, "My bar layout", W - 150, -4, function(self)
        Result(API.SetEnabled(self:GetChecked() == true))
    end, 110)
    Tooltip(ui.enable, "My bar layout", "Off: Blizzard's, settings kept")
    ui.editMode = SlashButton(header, "Edit Mode", W - 280, -2, 110, 28, "/editmode")
    ui.editMode:SetScript("PostClick", function() if InCombatLockdown() then Notice("Not in combat") end end)
    Tooltip(ui.editMode, "Edit Mode", "Drag the bars there, click one for its scale")

    -- The layout: Blizzard's (set in Edit Mode), and what applies to all of it
    local strip = S.Card(frame, nil, 0, 0, W, 52)
    Text(strip, "Layout", 16, -19, 70, 13, GOLD)
    for index, key in ipairs({ "compact", "standard" }) do
        local b = Button(strip, key, 90 + (index - 1) * 172, -11, 172, nil, "InsecureActionButtonTemplate", 13, 30)
        b:RegisterForClicks("LeftButtonUp")
        b:SetAttribute("useOnKeyDown", false)
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "/editmode")
        b:SetScript("PostClick", function()
            if (API.GetState().mode or "standard") == key then return end
            Notice(InCombatLockdown() and "Not in combat"
                or (key == "compact" and "Tick" or "Untick") .. " Compact Action Bar in Edit Mode")
        end)
        ui.modeButtons[key] = b
    end
    Tooltip(ui.modeButtons.compact, "Compact", "One bar at a time · set in Edit Mode")
    Tooltip(ui.modeButtons.standard, "Standard", "Each bar its own spot · set in Edit Mode")
    ui.resetLayout = Button(strip, "Reset layout", W - 134, -13, 120, function() Result(API.ResetMode(mode)) end, nil, 11, 26)
    Tooltip(ui.resetLayout, "Reset layout", "Every bar of this layout")
    ui.copy = Button(strip, "Copy from Standard", W - 300, -13, 160, function()
        Result(API.CopyLayout(mode == "compact" and "standard" or "compact", mode))
    end, nil, 11, 26)

    local top, height = -64, H - 64
    -- The bars
    ui.list = S.Card(frame, "Bar", 0, top, 210, height)

    -- The preview, with the arrows and their step under it
    local pw = 560
    local card = S.Card(frame, "Position", 222, top, pw + 32, height)
    ui.posCard = card
    local sw, sh = pw, math.floor(pw * 9 / 16)
    BuildPreview(card, 16, -44, sw, sh)
    local ay = -44 - sh - 16
    local x = 16
    for _, info in ipairs({ { "left", -1, 0, "Move left" }, { "up", 0, 1, "Move up" }, { "down", 0, -1, "Move down" },
        { "right", 1, 0, "Move right" } }) do
        local b = Button(card, "", x, ay, 44, function() Nudge(info[2], info[3]) end, nil, 14, 34)
        Arrow(b, info[1])
        Tooltip(b, info[4], "Shift-click: 1")
        ui.arrows[info[1]] = b
        x = x + 48
    end
    Text(card, "Step", 228, ay - 10, 50, 13, GOLD)
    for index, info in ipairs(nudgeSteps) do
        local b = Button(card, info[1], 278 + (index - 1) * 56, ay + 2, 52, function()
            step = index
            Refresh()
        end, nil, 13, 30)
        Tooltip(b, info[1] .. " px")
        ui.stepButtons[index] = b
    end
    ui.drag = Text(card, "", 16, ay - 52, sw, 11, DIM)
    Text(card, "Drag · arrow keys · d-pad", 16, -(height - 26), sw, 11, DIM)

    -- The picked bar's values
    local vx = 222 + pw + 32 + 12
    local vw = W - vx
    local vals = S.Card(frame, " ", vx, top, vw, height)
    ui.valCard = vals
    ValueRow(vals, "x", 16, -48, vw - 32)
    ValueRow(vals, "y", 16, -88, vw - 32)
    ValueRow(vals, "scale", 16, -140, vw - 32, true)
    ui.promptsLabel = Text(vals, "Button prompt", 16, -192, vw - 32, 13, GOLD)
    ui.prompts = Button(vals, "Shown", 16, -214, vw - 32, function()
        Result(API.SetClassPrompts(API.GetSettings().classPrompts == false))
    end, nil, 13, 30)
    Tooltip(ui.prompts, "Button prompt", "Both class buttons")
    ui.resetBar = Button(vals, "Reset", 16, -(height - 50), vw - 32, function() Result(API.ResetBar(selected, mode)) end, nil, 13, 30)
end

local function LayoutList(list)
    for _, tab in pairs(ui.tabs) do tab:Hide() end
    local found = false
    for _, entry in ipairs(list) do if entry[1] == selected then found = true end end
    if not found then selected = list[1][1] end
    for index, entry in ipairs(list) do
        local key = entry[1]
        local tab = ui.tabs[key]
        if not tab then
            tab = Button(ui.list, entry[2], 12, 0, 186, function()
                selected = key
                Refresh()
            end, nil, 13, 34)
            ui.tabs[key] = tab
        end
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", 12, -42 - (index - 1) * 40)
        tab.label:SetText(entry[2])
        if IsClassTarget(key) then
            Tooltip(tab, entry[2] .. " (" .. entry[3] .. ")", "Blizzard's spot during combat")
        else
            Tooltip(tab, entry[2], tips[key])
        end
        SetSelected(tab, key == selected)
        tab:Show()
    end
end

local function BarsStatus(settings, state, caps, classTab)
    if caps.suspended then return "Paused · settings kept" end
    if state.layoutError then return "Layout blocked · turn My bar layout off and on" end
    if not state.available then return "Controller bars unavailable" end
    if InCombatLockdown() then return "Applies after combat" end
    if state.pendingLayout then return "Waiting for Blizzard's bars" end
    if not settings.enabled then return "Off · Blizzard's layout" end
    if not state.nativeEnabled then return "Ready · applies in gamepad UI" end
    if classTab then return "Offsets from Blizzard's spot" end
    if mode == "compact" and state.spread then return "Spread: all 4 bars" end
    return "Bars shown while open"
end

local function RefreshBars()
    if not ui.frame then return end
    refreshing = true
    local settings, state, caps = API.GetSettings(), API.GetState(), API.GetCapabilities()
    local live = state.mode or "standard"
    mode = live
    local list = Targets()
    LayoutList(list)
    local layout = mode == "compact" and settings.compact or settings.bars
    local bar = layout[selected]
    local classTab = IsClassTarget(selected)
    local entry
    for _, item in ipairs(list) do if item[1] == selected then entry = item end end

    for key, button in pairs(ui.modeButtons) do
        SetSelected(button, key == mode)
        button.label:SetText((key == "compact" and "Compact" or "Standard") .. (key == live and "  ·  in use" or ""))
        button:SetAttribute("type", key == live and "" or "macro")
        button:SetEnabled(not InCombatLockdown())
    end

    local supported = not not (bar and state.available and caps.layout)
    ui.supported = supported
    for key, c in pairs(ui.controls) do
        if bar and not c.edit:HasFocus() then c.edit:SetText(string.format(specs[key][5], bar[key])) end
        c.edit:EnableMouse(supported)
        if not supported then c.edit:ClearFocus() end
        local shade = supported and 1 or 0.5
        c.edit:SetTextColor(shade, shade, shade)
        if c.minus then c.minus:SetEnabled(supported); c.plus:SetEnabled(supported) end
        c.label:SetTextColor(GOLD[1] * shade, GOLD[2] * shade, GOLD[3] * shade)
    end
    for _, b in pairs(ui.arrows) do b:SetEnabled(supported) end
    for index, b in ipairs(ui.stepButtons) do SetSelected(b, index == step) end

    ui.prompts:SetShown(classTab)
    ui.promptsLabel:SetShown(classTab)
    ui.promptsLabel:SetText("Button prompt (" .. (entry and entry[3] or "L1 + L2") .. ")")
    ui.prompts.label:SetText(settings.classPrompts ~= false and "Shown" or "Hidden")
    ui.prompts:SetEnabled(state.available == true)

    local tabName = entry and entry[2] or selected
    ui.valCard.title:SetText(tabName)
    ui.resetBar.label:SetText("Reset " .. tabName)
    ui.copy.label:SetText(mode == "compact" and "Copy from Standard" or "Copy from Compact")
    ui.enable:SetChecked(settings.enabled == true)
    ui.enable:SetEnabled(not caps.suspended)
    DrawPreview(list)
    Shell.SetStatus(BarsStatus(settings, state, caps, classTab))
    refreshing = false
end

-- Tools page ---------------------------------------------------------------------

local function ToolNote(parent, text, x, y, width)
    return Text(parent, text, x, y, width, 11, DIM)
end

local function BuildTools(frame, header)
    local half = (W - 12) / 2
    -- Skin: v2 (calm textures) or Blizzard (flat fills); applies at once
    if header and S.Segments then
        local label = Text(header, "Skin", W - 370, -11, 40, 12, GOLD)
        label:SetJustifyH("RIGHT")
        local widths = { 50, 66, 72 }
        S.Segments(header, W - 325, -2, widths, 26)
        ui.skin = {}
        local sx = W - 324
        for i, e in ipairs({ { "v2", "v2" }, { "gilded", "Gilded" }, { "blizzard", "Blizzard" } }) do
            local x = sx
            sx = sx + widths[i]
            ui.skin[e[1]] = S.Segment(header, e[2], x, -3, widths[i], function()
                S.SetSkin(e[1])
                for k, b in pairs(ui.skin) do S.SetSelected(b, k == S.Skin()) end
            end, 12, 26)
        end
        for k, b in pairs(ui.skin) do S.SetSelected(b, k == S.Skin()) end
        S.OnSkin(function(skin) for k, b in pairs(ui.skin) do S.SetSelected(b, k == skin) end end)
        -- Size: 90% or 100%
        local sizeLabel = Text(header, "Size", W - 525, -11, 40, 12, GOLD)
        sizeLabel:SetJustifyH("RIGHT")
        S.Segments(header, W - 480, -2, { 56, 56 }, 26)
        ui.size = {}
        local function Mark() for v, b in pairs(ui.size) do S.SetSelected(b, math.abs(v - S.UIScale()) < 0.01) end end
        for i, v in ipairs(S.SIZES) do
            ui.size[v] = S.Segment(header, math.floor(v * 100 + 0.5) .. "%", W - 479 + (i - 1) * 56, -3, 56, function()
                S.SetUIScale(v)
                Mark()
            end, 12, 26)
        end
        Mark()
    end
    -- Lab: the tuning and probes tab, for the curious
    if header and API.SetLab then
        ui.lab = S.NewCheck(header, "Lab", W - 90, -4, function(self)
            API.SetLab(self:GetChecked() == true)
        end, 50)
        S.Tooltip(ui.lab, "Lab", "Advanced")
    end
    -- Blizzard's windows
    local blizz = S.Card(frame, "Blizzard", 0, 0, half, 210)
    local bw = (half - 36) / 2
    local spells = Button(blizz, "Spells", 12, -44, bw, nil, "InsecureActionButtonTemplate", 13, 40)
    spells:RegisterForClicks("LeftButtonUp")
    spells:SetAttribute("useOnKeyDown", false)
    spells:HookScript("OnShow", RefreshSpellbookButtons)
    spells:HookScript("OnEnter", RefreshSpellbookButtons)
    spells:SetScript("PreClick", function() local w = Window(); openingPanel = w and w:IsShown() end)
    spells:SetScript("PostClick", function()
        ReturnToEditor()
        if InCombatLockdown() or not spells.ready then Notice("Use Blizzard's spellbook button") end
    end)
    spellButtons[#spellButtons + 1] = spells
    ToolNote(blizz, "Spellbook", 14, -90, bw)
    local macros = SlashButton(blizz, "Macros", 24 + bw, -44, bw, 40, "/macro")
    macros:SetScript("PreClick", function() local w = Window(); openingPanel = w and w:IsShown() end)
    macros:SetScript("PostClick", function()
        ReturnToEditor()
        if InCombatLockdown() then Notice("Not in combat") end
    end)
    ToolNote(blizz, "Macro window", 26 + bw, -90, bw)
    local editMode = SlashButton(blizz, "Edit Mode", 12, -118, bw, 40, "/editmode")
    editMode:SetScript("PostClick", function() if InCombatLockdown() then Notice("Not in combat") end end)
    ToolNote(blizz, "Frames and the controller bar", 14, -164, bw)
    local gamepad = Button(blizz, "Gamepad options", 24 + bw, -118, bw, function()
        local ok, reason = OpenGamepadSettings()
        if not ok then Result(nil, reason); return end
        reopenAfterSettings = true
        local window = Window()
        window:Hide()
        -- If Blizzard's panel never opened, don't pop this window up later.
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function()
                if reopenAfterSettings and SettingsPanel and SettingsPanel.IsShown and not SettingsPanel:IsShown() then
                    reopenAfterSettings = nil
                    if not window:IsShown() and not InCombatLockdown() then Shell.Open() end
                end
            end)
        end
    end, nil, 13, 40)
    Tooltip(gamepad, "Blizzard gamepad options", "Mouse and keyboard UI only")
    ToolNote(blizz, "Mouse and keyboard UI", 26 + bw, -164, bw)
    RefreshSpellbookButtons()

    -- Spread view
    local spread = S.Card(frame, "Spread view", 0, -222, half, 128)
    ui.spread = Button(spread, "Spread view: Off", 12, -44, half - 24, function()
        Result(API.SetSpread(not API.GetState().spread))
    end, nil, 13, 40)
    Tooltip(ui.spread, "Spread view", "Not in combat")
    ToolNote(spread, "While this window is open", 14, -92, half - 28)

    -- Window key and minimap icon (Access.lua)
    if ns.Access then ui.access = ns.Access.BuildCard(frame, half + 12, 0, half, 210) end
end

local function RefreshTools()
    if not ui.spread then return end
    if ui.lab and ns.Haptics then ui.lab:SetChecked(ns.Haptics.DB().lab == true) end
    local state = API.GetState()
    ui.spread.label:SetText(state.spread and "Spread view: On" or "Spread view: Off")
    SetSelected(ui.spread, state.spread == true)
    ui.spread:SetEnabled(state.enabled == true and (state.spread or not InCombatLockdown()))
    RefreshSpellbookButtons()
end

-- Pages ----------------------------------------------------------------------------

local function StateChanged()
    local window = Window()
    if not window or not window:IsShown() then return end
    for _, c in pairs(ui.controls) do if c.edit:HasFocus() then return end end
    Refresh()
end

Refresh = function()
    RefreshSpellbookButtons()
    local current = Shell.Current()
    if current == "bars" then RefreshBars() elseif current == "tools" then RefreshTools() end
end
API.RefreshOptions = function() Refresh() end
ns.RefreshOptions = Refresh

Shell.AddPage({
    key = "bars", name = "Bars", order = 5,
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    build = BuildBars, refresh = RefreshBars,
    -- Bars stay shown, and live state updates, while the window is open
    windowShow = function()
        mode = API.GetState().mode or "standard"
        API.SetEditing(true)
        API.Subscribe(Window(), StateChanged)
    end,
    windowHide = function()
        API.Unsubscribe(Window())
        if openingPanel then return end
        API.SetEditing(false)
    end,
})
Shell.AddPage({
    key = "tools", name = "Tools", order = 6,
    icon = "Interface\\Icons\\Ability_Repair", build = BuildTools, refresh = RefreshTools,
})

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function()
    local window = Window()
    if window and window:IsShown() then Refresh() end
end)
if SettingsPanel and SettingsPanel.HookScript then
    SettingsPanel:HookScript("OnHide", function()
        if not reopenAfterSettings then return end
        reopenAfterSettings = nil
        local window = Window()
        if window and not window:IsShown() and not InCombatLockdown() then Shell.Open() end
    end)
end

-- /gpc: the window on its last page (Controller first)
function API.ToggleOptions(page) Shell.Toggle(page) end
function API.OpenBars() Shell.Open("bars") end
function API.ToggleHelp() Shell.Toggle("help") end
