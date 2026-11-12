-- The Bars, Tools and Help pages of the Gamepad Companion window (Window.lua).
--   Bars   where Blizzard's controller bars and class buttons sit, and their size
--   Tools  Blizzard's spellbook, macros, Edit Mode and gamepad options; spread
--          view; Edit Mode layouts; the character's profile
--   Help   short topics and the commands
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

local function Arrow(button, direction)
    local atlas = direction == "left" and "common-icon-backarrow" or "common-icon-forwardarrow"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if info and button.CreateTexture then
        button.label:SetText("")
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetAtlas(atlas)
        icon:SetSize(22, 22)
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

-- [-] [ value ] [+], the value typed or stepped
local function ValueRow(parent, key, x, y, width)
    local spec = specs[key]
    local c = {}
    c.label = Text(parent, spec[6], x, y - 7, 60, 13, GOLD)
    local editX, editW = x + 60 + 40, width - 60 - 80
    c.minus = Button(parent, "-", x + 60, y, 36, function() Step(key, -1) end, nil, 16, 30)
    c.plus = Button(parent, "+", x + width - 36, y, 36, function() Step(key, 1) end, nil, 16, 30)
    Tooltip(c.minus, spec[6], string.format("Shift-click: -%g", spec[2]))
    Tooltip(c.plus, spec[6], string.format("Shift-click: +%g", spec[2]))
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

local function BuildBars(frame, header)
    ui.frame = frame
    ui.enable = S.NewCheck(header, "My bar layout", W - 150, -4, function(self)
        Result(API.SetEnabled(self:GetChecked() == true))
    end, 110)
    Tooltip(ui.enable, "My bar layout", "Off: Blizzard's, settings kept")

    -- Blizzard's layout in use
    local layout = S.Card(frame, "Blizzard layout", 0, 0, W, 86)
    for index, key in ipairs({ "compact", "standard" }) do
        local b = Button(layout, key, 14 + (index - 1) * 286, -42, 280, nil, "InsecureActionButtonTemplate", 13, 32)
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
    Tooltip(ui.modeButtons.compact, "Compact", "Set in Edit Mode")
    Tooltip(ui.modeButtons.standard, "Standard", "Set in Edit Mode")
    ui.modeHint = Text(layout, "", 604, -50, W - 620, 12, GREY)

    -- The bar list
    ui.list = S.Card(frame, "Bar", 0, -98, 250, H - 98)

    -- Position
    local pos = S.Card(frame, "Position", 262, -98, 470, H - 98)
    ui.posCard = pos
    local cx, cy = 235, -190      -- the readout's centre
    local pad = {
        up = { cx - 28, cy + 86, 0, 1, "Move up" }, down = { cx - 28, cy - 30, 0, -1, "Move down" },
        left = { cx - 120, cy + 28, -1, 0, "Move left" }, right = { cx + 64, cy + 28, 1, 0, "Move right" },
    }
    for direction, info in pairs(pad) do
        local b = Button(pos, "", info[1], info[2], 56, function()
            local size = nudgeSteps[step][2]
            if info[3] ~= 0 then Step("x", info[3], size) end
            if info[4] ~= 0 then Step("y", info[4], size) end
        end, nil, 14, 56)
        Arrow(b, direction)
        Tooltip(b, info[5], "Shift-click: 1")
        ui.arrows[direction] = b
    end
    local box = CreateFrame("Frame", nil, pos, "BackdropTemplate")
    box:SetPoint("TOPLEFT", cx - 56, cy + 22)
    box:SetSize(112, 44)
    S.Edit(box)
    ui.readout = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ui.readout:SetPoint("LEFT", 4, 0)
    ui.readout:SetPoint("RIGHT", -4, 0)
    ui.readout:SetJustifyH("CENTER")
    Text(pos, "Step", 20, -296, 60, 13, GOLD)
    for index, info in ipairs(nudgeSteps) do
        local b = Button(pos, info[1], 120 + (index - 1) * 82, -288, 76, function()
            step = index
            Refresh()
        end, nil, 13, 30)
        Tooltip(b, "Step " .. info[1], string.format("Scale %.2f", info[3]))
        ui.stepButtons[index] = b
    end
    ValueRow(pos, "x", 20, -346, 430)
    ValueRow(pos, "y", 20, -386, 430)

    -- Size, prompt and resets
    local size = S.Card(frame, "Size", 744, -98, W - 744, H - 98)
    local sw = W - 744 - 40
    ValueRow(size, "scale", 20, -50, sw)
    ui.scaleSteps = Text(size, "", 80, -88, sw - 60, 11, DIM)
    ui.promptsLabel = Text(size, "Button prompt", 20, -128, sw, 13, GOLD)
    ui.prompts = Button(size, "Shown", 20, -150, sw, function()
        Result(API.SetClassPrompts(API.GetSettings().classPrompts == false))
    end, nil, 13, 30)
    Tooltip(ui.prompts, "Button prompt", "Both class buttons")
    ui.resetBar = Button(size, "Reset", 20, -(H - 98) + 132, sw, function() Result(API.ResetBar(selected, mode)) end, nil, 13, 30)
    ui.resetLayout = Button(size, "Reset layout", 20, -(H - 98) + 94, sw, function() Result(API.ResetMode(mode)) end, nil, 13, 30)
    Tooltip(ui.resetLayout, "Reset layout", "Other layout unchanged")
    ui.copy = Button(size, "Copy from Standard", 20, -(H - 98) + 56, sw, function()
        Result(API.CopyLayout(mode == "compact" and "standard" or "compact", mode))
    end, nil, 13, 30)
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
            tab = Button(ui.list, entry[2], 12, 0, 226, function()
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
    ui.modeHint:SetText(mode == "compact" and "One bar at a time" or "Each bar in its own spot")

    local supported = not not (bar and state.available and caps.layout)
    ui.supported = supported
    for key, c in pairs(ui.controls) do
        if bar and not c.edit:HasFocus() then c.edit:SetText(string.format(specs[key][5], bar[key])) end
        c.edit:EnableMouse(supported)
        if not supported then c.edit:ClearFocus() end
        local shade = supported and 1 or 0.5
        c.edit:SetTextColor(shade, shade, shade)
        c.minus:SetEnabled(supported)
        c.plus:SetEnabled(supported)
        c.label:SetTextColor(GOLD[1] * shade, GOLD[2] * shade, GOLD[3] * shade)
    end
    for _, b in pairs(ui.arrows) do b:SetEnabled(supported) end
    ui.readout:SetText(bar and string.format("X  %d\nY  %d", bar.x, bar.y) or "")
    for index, b in ipairs(ui.stepButtons) do SetSelected(b, index == step) end
    ui.scaleSteps:SetText(string.format("Arrows: %d px · %.2f scale", nudgeSteps[step][2], nudgeSteps[step][3]))

    ui.prompts:SetShown(classTab)
    ui.promptsLabel:SetShown(classTab)
    ui.promptsLabel:SetText("Button prompt (" .. (entry and entry[3] or "L1 + L2") .. ")")
    ui.prompts.label:SetText(settings.classPrompts ~= false and "Shown" or "Hidden")
    ui.prompts:SetEnabled(state.available == true)

    local tabName = entry and entry[2] or selected
    ui.posCard.title:SetText("Position · " .. tabName)
    ui.resetBar.label:SetText("Reset " .. tabName)
    ui.copy.label:SetText(mode == "compact" and "Copy from Standard" or "Copy from Compact")
    ui.enable:SetChecked(settings.enabled == true)
    ui.enable:SetEnabled(not caps.suspended)
    Shell.SetStatus(BarsStatus(settings, state, caps, classTab))
    refreshing = false
end

-- Tools page ---------------------------------------------------------------------

local function ToolNote(parent, text, x, y, width)
    return Text(parent, text, x, y, width, 11, DIM)
end

local function BuildTools(frame)
    local half = (W - 12) / 2
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
    ToolNote(spread, "All 4 bars side by side, and the form bars · while this window is open", 14, -92, half - 28)

    -- Edit Mode layouts
    local em = S.Card(frame, "Edit Mode layouts", half + 12, 0, half, 210)
    ui.emStatus = Text(em, "", 14, -44, half - 28, 13, GOLD)
    ui.emStatus:SetHeight(60)
    ui.emStatus:SetJustifyV("TOP")
    local ew = (half - 36) / 2
    Button(em, "Convert again", 12, -118, ew, function()
        if API.EditMode then API.EditMode.Command("convert") end
        Refresh()
    end, nil, 13, 40)
    Button(em, "List in chat", 24 + ew, -118, ew, function()
        if API.EditMode then API.EditMode.Command("list") end
    end, nil, 13, 40)
    ToolNote(em, "Your old Companion layout, as a Blizzard gamepad layout", 14, -164, half - 28)

    -- Profile
    local profile = S.Card(frame, "Profile", half + 12, -222, half, 128)
    ui.profileName = Text(profile, "", 14, -44, half - 28, 14, GOLD)
    ToolNote(profile, "Controller and touchpad bindings: this character\nNew characters start from a copy · bar layout: all characters",
        14, -70, half - 28)

    -- Frame Gambit
    local fg = S.Card(frame, "Visibility", 0, -362, W, 90)
    ui.fgText = Text(fg, "", 14, -44, W - 28, 13, GOLD)
end

local function RefreshTools()
    if not ui.spread then return end
    local state = API.GetState()
    ui.spread.label:SetText(state.spread and "Spread view: On" or "Spread view: Off")
    SetSelected(ui.spread, state.spread == true)
    ui.spread:SetEnabled(state.enabled == true and (state.spread or not InCombatLockdown()))
    local ok, emStatus = pcall(function() return API.EditMode and API.EditMode.Status() end)
    ui.emStatus:SetText(ok and emStatus or "")
    local name = UnitName and UnitName("player")
    ui.profileName:SetText(type(name) == "string" and name or "")
    ui.fgText:SetText(_G.FrameGambitAPI and "Frame Gambit decides when bars show · Companion: place and size"
        or "Companion places and sizes the bars · Blizzard shows them")
    RefreshSpellbookButtons()
end

-- Help page ----------------------------------------------------------------------

local topics = {
    { "Controller", "Click a button on the drawing to edit it\nChoose: spells, items, macros, Halo rings, windows, typed macros\nOr drop a spell, item or macro on it\nHold L2 / R2: their layer\nBar slots: pages 1 to 3\nIn combat: applies after" },
    { "Touchpad", "Click the touchpad on the drawing\nZones, grid, swipes, tap time\nTouch + click: two actions per zone\nTaps work out of combat only\nL1 + touchpad: Blizzard's focus" },
    { "Bars", "Offsets from Blizzard's spot\nCompact or Standard: Edit Mode > controller bar\nBigger active bar: Expand in Edit Mode\nBase also moves page selector and shoulder icons\nFine steps: Shift-click or mouse wheel" },
    { "Class buttons", "Druid, paladin, warrior, hunter, warlock\nL1 + L2 and R1 + R2 menus\nIn combat: Blizzard's spot" },
    { "Edit Mode", "Frames: Blizzard Edit Mode\nOld Companion layout: converted once, kept as backup\n/gpc edit  status\n/gpc edit convert  make it again" },
    { "Rumble", "The motors on game events and casts\nEach event: a pattern, or Off\nCasts: a set for casting, interrupted, cancelled, pushed back\nMatch the action: each spell, profession or weapon its own feel\nTry: as the game would play it\nOff while Improved Forever: Vibration is on" },
    { "Profiles", "Bindings: per character\nNew characters start from a copy\nBar layout: all characters" },
    { "Commands", "/gpc  window\n/gpc pad  controller\n/gpc touch  touchpad\n/gpc bars  bar layout\n/gpc rumble  rumble\n/gpc rumble test  each motor\n/gpc on | off  my bar layout\n/gpc reset  both bar layouts\n/gpc gamepad  Blizzard options\n/gpc edit  Edit Mode layout\n/gpc help  commands in chat" },
}

local help = { buttons = {} }
local function ShowTopic(index)
    help.index = index
    help.title:SetText(topics[index][1])
    help.copy:SetText(topics[index][2])
    for i, b in ipairs(help.buttons) do SetSelected(b, i == index) end
end

local function BuildHelp(frame)
    local list = S.Card(frame, "Topics", 0, 0, 250, H)
    for index, topic in ipairs(topics) do
        help.buttons[index] = Button(list, topic[1], 12, -42 - (index - 1) * 40, 226, function() ShowTopic(index) end, nil, 13, 34)
    end
    local card = S.Card(frame, " ", 262, 0, W - 262, H)
    help.title = card.title
    help.copy = Text(card, "", 18, -50, W - 300, 14, GOLD)
    help.copy:SetJustifyV("TOP")
    help.copy:SetHeight(H - 70)
    if help.copy.SetSpacing then help.copy:SetSpacing(8) end
    if API.GetCapabilities().suspended then
        help.copy:SetText("Paused in this recovery build\nSettings kept")
    else
        ShowTopic(1)
    end
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
    key = "bars", name = "Bars", order = 3,
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
    key = "tools", name = "Tools", order = 4,
    icon = "Interface\\Icons\\Ability_Repair", build = BuildTools, refresh = RefreshTools,
})
Shell.AddPage({
    key = "help", name = "Help", order = 5, icon = "Interface\\Icons\\INV_Misc_Book_09", build = BuildHelp,
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
