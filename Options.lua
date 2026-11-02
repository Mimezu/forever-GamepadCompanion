local ADDON, ns = ...
local S = ns.OptionsSkin
local API = GamepadCompanionAPI
local GOLD, GREY, DIM = S.GOLD, S.GREY, S.DIM
local Text, Note, Button, Tooltip, SetSelected = S.Text, S.Note, S.NewButton, S.Tooltip, S.SetSelected

-- Targets per layout. Compact mode stacks the four trigger bars in one spot and
-- shows only the active one, so they share a single "Action bars" entry there.
local targetsByMode = {
    compact = { { "bars", "Action bars" }, { "stance", "Stance" } },
    standard = { { "base", "Base" }, { "lt", "LT" }, { "rt", "RT" }, { "both", "LT + RT" }, { "stance", "Stance" } },
}
local classTargets = { { "classLeft", "LB + LT" }, { "classRight", "RB + RT" } }
local classMenuNames = {
    Forms = "Form menu", Auras = "Aura menu", Stances = "Stance menu", Pet = "Pet menu", ["Pet spells"] = "Pet spells",
}
local tips = {
    bars = "All four trigger bars. In compact mode Blizzard shows one at a time in the same place, so they share one position.",
    base = "The bar shown with no trigger held. Also moves the 1-2-3 page selector, the shoulder icons and the targeting/shortcut bars.",
    lt = "The bar shown while LT is held.",
    rt = "The bar shown while RT is held.",
    both = "The bar shown while LT and RT are both held.",
    stance = "Blizzard's shared stance/form bar. Its actions are edited in Spread view.",
}
-- step, fine step, minimum, maximum, display format
local specs = {
    x = { 10, 1, -2000, 2000, "%.0f", "Horizontal offset" },
    y = { 10, 1, -2000, 2000, "%.0f", "Vertical offset" },
    scale = { 0.05, 0.01, 0.5, 2, "%.2f", "Scale" },
}
local valueKeys = { "x", "y", "scale" }
local styleNames = { A = "Controller", B = "Legacy window", C = "Classic" }
local styleTips = {
    A = "Big buttons for the gamepad cursor. Move with arrows and pick a step size; no typing.",
    B = "The window of Forever Names, Petal and Halo, with each section in a card.",
    C = "Gamepad Companion's original look, with typed values.",
}
-- Style A step sizes: pixels for offsets, and the matching scale step.
local nudgeSteps = { { "1", 1, 0.01 }, { "10", 10, 0.05 }, { "50", 50, 0.10 } }

local mode, selected, window, help, refreshing = nil, "base", nil, nil, false
local views, view, style = {}, nil, "A"
local spellButtons = {}
local openingPanel, reopenAfterSettings
local Refresh, SetStatus

local function PlayerClassButtons()
    local _, class = UnitClass("player")
    if issecretvalue and issecretvalue(class) then return {} end
    return ns.Model and ns.Model.classButtonUse[class] or {}
end

-- Targets for the mode being edited: its bars, then this class's LB+LT / RB+RT
-- menu buttons. Classes without one don't see those tabs.
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

local function OpenGamepadSettings()
    if InCombatLockdown() then return false, "Blizzard settings open after combat." end
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
    if not opened then return false, "Open Blizzard's Options > Gamepad from the game menu." end
    return true
end
API.OpenGamepadSettings = OpenGamepadSettings

-- Values -------------------------------------------------------------------

local function Current(key)
    local settings = API.GetSettings()
    local layout = mode == "compact" and settings.compact or settings.bars
    return layout[selected] and layout[selected][key] or 0
end

-- A message about the user's last action stays up for a few seconds, even
-- when a live state change repaints the window underneath it.
local sticky, stickyUntil
local function Notice(message)
    sticky, stickyUntil = message, (GetTime and GetTime() or 0) + 5
    SetStatus(message)
end

local function Result(ok, reason)
    sticky = nil
    Refresh()
    if reason then
        Notice((reason == "combat" or reason == "pending") and "Layout changes apply after combat." or tostring(reason))
    elseif ok == false then
        Notice("This change could not be applied.")
    end
end

local function Submit(key, value)
    if refreshing or not (view and view.supported[key]) then return end
    local spec = specs[key]
    if not value or value ~= value or value < spec[3] or value > spec[4] then
        Refresh()
        Notice(string.format("Enter a value from %g to %g.", spec[3], spec[4]))
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

-- Shared pieces ------------------------------------------------------------

local function NewView(key, width, height)
    local v = { style = key, width = width, height = height, controls = {}, tabs = {}, modeButtons = {},
        styleButtons = {}, supported = {} }
    v.frame = CreateFrame("Frame", nil, window)
    v.frame:SetSize(width, height)
    v.frame:Hide()
    return v
end

-- Compact / Standard show which of Blizzard's layouts is in use. Since build
-- 70338 "Compact Action Bar" is a setting of the controller action bar in Edit
-- Mode, saved with the Edit Mode layout; the old GamepadUseCompactActionBar CVar
-- is no longer read. The mode that is not in use runs Blizzard's /editmode from
-- the hardware click, like the Macros button: opening Edit Mode from addon code
-- would taint the gamepad window manager. Refresh clears the macro on the mode
-- in use.
local function ModeButtons(v, x, y, width, height)
    local first = math.floor((width - 6) / 2)
    local second = width - 6 - first
    for index, key in ipairs({ "compact", "standard" }) do
        local button = Button(v.frame, key, index == 1 and x or x + first + 6, y,
            index == 1 and first or second, nil, "InsecureActionButtonTemplate", nil, height)
        button:RegisterForClicks("LeftButtonUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/editmode")
        button:SetScript("PostClick", function()
            sticky = nil
            if (API.GetState().mode or "standard") == key then return end
            Notice(InCombatLockdown() and "Switch layouts after combat."
                or "In Edit Mode, select the controller action bar and "
                    .. (key == "compact" and "tick" or "untick") .. " Compact Action Bar.")
        end)
        v.modeButtons[key] = button
    end
    Tooltip(v.modeButtons.compact, "Compact", "One bar at a time, stacked at the bottom. To switch, click here: Edit Mode opens; select the controller action bar and tick Compact Action Bar. Blizzard saves it with the Edit Mode layout.")
    Tooltip(v.modeButtons.standard, "Standard", "Each trigger bar has its own spot. To switch, click here: Edit Mode opens; select the controller action bar and untick Compact Action Bar. Blizzard saves it with the Edit Mode layout.")
end

local function GamepadButton(v, x, y, width, height, size)
    v.gamepad = Button(v.frame, "Gamepad options", x, y, width, function()
        local ok, reason = OpenGamepadSettings()
        if not ok then Result(nil, reason); return end
        reopenAfterSettings = true
        window:Hide()
        -- If Blizzard's panel never opened, don't pop this window up later.
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function()
                if reopenAfterSettings and SettingsPanel and SettingsPanel.IsShown and not SettingsPanel:IsShown() then
                    reopenAfterSettings = nil
                    if not window:IsShown() and not InCombatLockdown() then API.ToggleOptions() end
                end
            end)
        end
    end, nil, size, height)
    Tooltip(v.gamepad, "Blizzard gamepad options", "Opens Blizzard's Options > Gamepad. This window comes back when you close it.")
end

local function EnableCheck(v, x, y)
    v.enable = S.NewCheck(v.frame, "Enabled", x, y, function(self)
        Result(API.SetEnabled(self:GetChecked() == true))
    end, 60)
    Tooltip(v.enable, "Apply my layout", "Off releases every bar back to Blizzard's layout. Your settings are kept.")
end

local function ResetRow(v, x, y, widths, height)
    local left = x
    v.resetBar = Button(v.frame, "Reset", left, y, widths[1], function() Result(API.ResetBar(selected, mode)) end, nil, nil, height)
    left = left + widths[1] + 6
    v.resetLayout = Button(v.frame, "Reset layout", left, y, widths[2], function() Result(API.ResetMode(mode)) end, nil, nil, height)
    Tooltip(v.resetLayout, "Reset layout", "Puts every bar and button of this layout back in Blizzard's spot. The other layout is not changed.")
    left = left + widths[2] + 6
    v.copy = Button(v.frame, "Copy from Standard", left, y, widths[3], function()
        Result(API.CopyLayout(mode == "compact" and "standard" or "compact", mode))
    end, nil, nil, height)
end

local function ReturnToEditor()
    local reopen = openingPanel
    openingPanel = nil
    if reopen and not window:IsShown() and not InCombatLockdown() then window:Show() end
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

local function Tools(v, x, y, widths, height)
    local left = x
    v.spread = Button(v.frame, "Spread view: Off", left, y, widths[1], function()
        Result(API.SetSpread(not API.GetState().spread))
    end, nil, nil, height)
    Tooltip(v.spread, "Spread view", "Lays the four bars out side by side, with your form action sets on the left. Drag spells, items or macros onto them outside combat.")
    left = left + widths[1] + 6
    local spells = Button(v.frame, "Spells", left, y, widths[2], nil, "InsecureActionButtonTemplate", nil, height)
    spells:RegisterForClicks("LeftButtonUp")
    spells:SetAttribute("useOnKeyDown", false)
    spells:HookScript("OnShow", RefreshSpellbookButtons)
    spells:HookScript("OnEnter", RefreshSpellbookButtons)
    spells:SetScript("PreClick", function() openingPanel = window:IsShown() end)
    spells:SetScript("PostClick", function()
        ReturnToEditor()
        if InCombatLockdown() or not spells.ready then
            Notice("Open Spells with Blizzard's spellbook button or controller menu.")
        end
    end)
    Tooltip(spells, "Spells", "Opens your spellbook next to this window, to drag spells onto the bars.")
    spellButtons[#spellButtons + 1] = spells
    v.spells = spells
    RefreshSpellbookButtons()
    left = left + widths[2] + 6
    local macros = Button(v.frame, "Macros", left, y, widths[3], nil, "InsecureActionButtonTemplate", nil, height)
    macros:RegisterForClicks("LeftButtonUp")
    macros:SetAttribute("useOnKeyDown", false)
    -- Let the engine-owned hardware-click action run Blizzard's slash command.
    -- Never call its panel opener from an addon OnClick or retry it directly.
    macros:SetAttribute("type", "macro")
    macros:SetAttribute("macrotext", "/macro")
    macros:SetScript("PreClick", function() openingPanel = window:IsShown() end)
    macros:SetScript("PostClick", function()
        ReturnToEditor()
        if InCombatLockdown() then Notice("Open the macro editor after combat.") end
    end)
    Tooltip(macros, "Macros", "Opens Blizzard's macro window next to this one.")
    v.macros = macros
    left = left + widths[3] + 6
    -- Blizzard Edit Mode, run from the hardware click like the Macros button.
    local layouts = Button(v.frame, "Edit Mode", left, y, widths[4], nil, "InsecureActionButtonTemplate", nil, height)
    layouts:RegisterForClicks("LeftButtonUp")
    layouts:SetAttribute("useOnKeyDown", false)
    layouts:SetAttribute("type", "macro")
    layouts:SetAttribute("macrotext", "/editmode")
    layouts:SetScript("PostClick", function()
        if InCombatLockdown() then Notice("Open Edit Mode after combat.") end
    end)
    Tooltip(layouts, "Edit Mode", "Opens Blizzard Edit Mode. In the gamepad UI it edits your gamepad layout: frames, and the controller action bar block with its Compact and Expand settings.")
    v.layouts = layouts
end

local SelectStyle
local function StyleSwitch(v, x, y, height)
    local label = Text(v.frame, "Style", x, 0, nil, 11, DIM)
    label:ClearAllPoints()
    label:SetPoint("LEFT", v.frame, "TOPLEFT", x, y - (height or 26) / 2)
    for index, key in ipairs({ "A", "B", "C" }) do
        local button = Button(v.frame, key, x + 36 + (index - 1) * 34, y, 30, function() SelectStyle(key) end, nil, 12, height)
        Tooltip(button, "Style " .. key .. ": " .. styleNames[key], styleTips[key] .. " Your settings are the same in every style.")
        v.styleButtons[key] = button
    end
end

-- Offset / scale rows with a typed value between - and + (styles B, C).
local function ValueRows(v, x, y, width, spacing, labelX)
    local right = x + width
    local minusX, editX = right - 28 - 6 - 106 - 6 - 28, right - 28 - 6 - 106
    for index, key in ipairs(valueKeys) do
        local spec = specs[key]
        local rowY = y - (index - 1) * spacing
        local control = {}
        control.label = Text(v.frame, spec[6], 0, 0, minusX - labelX - 8)
        control.label:ClearAllPoints()
        control.label:SetPoint("LEFT", v.frame, "TOPLEFT", labelX, rowY - 13)
        control.minus = Button(v.frame, "-", minusX, rowY, 28, function() Step(key, -1) end, nil, 15)
        control.plus = Button(v.frame, "+", right - 28, rowY, 28, function() Step(key, 1) end, nil, 15)
        Tooltip(control.minus, spec[6], string.format("Click: -%g. Shift-click: -%g.", spec[1], spec[2]))
        Tooltip(control.plus, spec[6], string.format("Click: +%g. Shift-click: +%g.", spec[1], spec[2]))
        local edit = CreateFrame("EditBox", nil, v.frame, "BackdropTemplate")
        edit:SetPoint("TOPLEFT", editX, rowY)
        edit:SetSize(106, 26)
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
        edit:SetScript("OnTabPressed", function(self)
            Submit(key, ParseNumber(self:GetText()))
            local nextKey = valueKeys[index % #valueKeys + 1]
            local nextControl = v.controls[nextKey]
            if nextControl and nextControl.edit:IsShown() then nextControl.edit:SetFocus() else self:ClearFocus() end
        end)
        edit:EnableMouseWheel(true)
        edit:SetScript("OnMouseWheel", function(_, delta)
            if v.supported[key] and not edit:HasFocus() then Step(key, delta > 0 and 1 or -1) end
        end)
        control.edit = edit
        v.controls[key] = control
    end
    -- Class buttons get a prompt toggle in the row below scale.
    local promptY = y - 3 * spacing
    v.promptsLabel = Text(v.frame, "Button prompt", 0, 0, minusX - labelX - 8)
    v.promptsLabel:ClearAllPoints()
    v.promptsLabel:SetPoint("LEFT", v.frame, "TOPLEFT", labelX, promptY - 13)
    v.prompts = Button(v.frame, "Shown", minusX, promptY, right - minusX, function()
        Result(API.SetClassPrompts(API.GetSettings().classPrompts == false))
    end)
    Tooltip(v.prompts, "Button prompt", "The two-icon hint under each class button. Applies to both class buttons.")

    function v.UpdateValues(bar, classTab, available, caps)
        for key, control in pairs(v.controls) do
            local supported = not not (bar and available and caps.layout)
            v.supported[key] = supported
            if bar and not control.edit:HasFocus() then
                control.edit:SetText(string.format(specs[key][5], bar[key]))
            end
            control.edit:EnableMouse(supported)
            if not supported then control.edit:ClearFocus() end
            control.edit:SetTextColor(supported and 1 or 0.5, supported and 1 or 0.5, supported and 1 or 0.5)
            control.minus:SetEnabled(supported)
            control.plus:SetEnabled(supported)
            local shade = supported and 1 or 0.5
            control.label:SetTextColor(GOLD[1] * shade, GOLD[2] * shade, GOLD[3] * shade)
        end
    end
    function v.HasFocus()
        for _, control in pairs(v.controls) do if control.edit:HasFocus() then return true end end
        return false
    end
end

-- Arrow icon for style C, with a plain-text fallback.
local function Arrow(button, direction)
    local atlas = direction == "left" and "common-icon-backarrow" or "common-icon-forwardarrow"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if info then
        button.label:SetText("")
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetAtlas(atlas)
        icon:SetSize(20, 20)
        icon:SetPoint("CENTER")
        if icon.SetRotation then
            icon:SetRotation(direction == "up" and math.pi / 2 or direction == "down" and -math.pi / 2 or 0)
        end
        button.icon = icon
        button:HookScript("OnEnable", function() icon:SetDesaturated(false); icon:SetAlpha(1) end)
        button:HookScript("OnDisable", function() icon:SetDesaturated(true); icon:SetAlpha(0.5) end)
    else
        button.label:SetText(({ up = "Up", down = "Down", left = "<", right = ">" })[direction])
    end
end

-- Controller-friendly editor (style A): arrows move by the chosen step, big
-- -/+ buttons for scale, no text entry.
local function NudgePad(v, cardX, cardY)
    v.step = 2
    local function Nudge(dx, dy)
        local size = nudgeSteps[v.step][2]
        if dx ~= 0 then Step("x", dx, size) end
        if dy ~= 0 then Step("y", dy, size) end
    end
    local pad = {
        up = { cardX + 120, cardY - 80, 0, 1, "Move up" }, down = { cardX + 120, cardY - 168, 0, -1, "Move down" },
        left = { cardX + 40, cardY - 124, -1, 0, "Move left" }, right = { cardX + 200, cardY - 124, 1, 0, "Move right" },
    }
    v.arrows = {}
    for direction, info in pairs(pad) do
        local button = Button(v.frame, "", info[1], info[2], 40, function() Nudge(info[3], info[4]) end, nil, 14, 40)
        Arrow(button, direction)
        Tooltip(button, info[5], "Moves by the step size below. Shift-click moves 1.")
        v.arrows[direction] = button
    end
    local box = CreateFrame("Frame", nil, v.frame, "BackdropTemplate")
    box:SetPoint("TOPLEFT", cardX + 86, cardY - 126)
    box:SetSize(108, 36)
    S.Edit(box)
    v.readout = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    v.readout:SetPoint("LEFT", 4, 0)
    v.readout:SetPoint("RIGHT", -4, 0)
    v.readout:SetJustifyH("CENTER")
    local stepLabel = Text(v.frame, "Step", 0, 0, nil, 12)
    stepLabel:ClearAllPoints()
    stepLabel:SetPoint("LEFT", v.frame, "TOPLEFT", cardX + 14, cardY - 234)
    v.stepButtons = {}
    for index, info in ipairs(nudgeSteps) do
        local button = Button(v.frame, info[1], cardX + 62 + (index - 1) * 62, cardY - 220, 56, function()
            v.step = index
            Refresh()
        end, nil, 13, 28)
        Tooltip(button, "Step " .. info[1], string.format("Arrows move %g. Scale changes by %.2f.", info[2], info[3]))
        v.stepButtons[index] = button
    end
    -- Scale: - value +
    v.rows = {}
    local function Row(key, labelY)
        local row = {}
        row.label = Text(v.frame, specs[key][6], cardX + 282, cardY - labelY, 244)
        row.minus = Button(v.frame, "-", cardX + 280, cardY - labelY - 18, 40, function()
            Step(key, -1, nudgeSteps[v.step][3])
        end, nil, 16, 32)
        row.plus = Button(v.frame, "+", cardX + 488, cardY - labelY - 18, 40, function()
            Step(key, 1, nudgeSteps[v.step][3])
        end, nil, 16, 32)
        row.value = v.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.value:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
        row.value:SetPoint("LEFT", row.minus, "RIGHT", 4, 0)
        row.value:SetPoint("RIGHT", row.plus, "LEFT", -4, 0)
        row.value:SetJustifyH("CENTER")
        Tooltip(row.minus, specs[key][6], "Smaller by the step size. Shift-click: 0.01.")
        Tooltip(row.plus, specs[key][6], "Larger by the step size. Shift-click: 0.01.")
        v.rows[key] = row
        return row
    end
    Row("scale", 80)
    v.promptsLabel = Text(v.frame, "Button prompt", cardX + 282, cardY - 146, 244)
    v.prompts = Button(v.frame, "Shown", cardX + 280, cardY - 164, 248, function()
        Result(API.SetClassPrompts(API.GetSettings().classPrompts == false))
    end, nil, nil, 32)
    Tooltip(v.prompts, "Button prompt", "The two-icon hint under each class button. Applies to both class buttons.")

    function v.UpdateValues(bar, classTab, available, caps)
        local layout = not not (bar and available and caps.layout)
        v.supported.x, v.supported.y, v.supported.scale = layout, layout, layout
        for _, button in pairs(v.arrows) do button:SetEnabled(layout) end
        v.readout:SetText(bar and string.format("X  %d\nY  %d", bar.x, bar.y) or "")
        v.readout:SetTextColor(layout and 1 or 0.5, layout and 1 or 0.5, layout and 1 or 0.5)
        for index, button in ipairs(v.stepButtons) do SetSelected(button, index == v.step) end
        for key, row in pairs(v.rows) do
            local supported = v.supported[key]
            row.value:SetText(bar and string.format(specs[key][5], bar[key]) or "")
            row.minus:SetEnabled(supported); row.plus:SetEnabled(supported)
            local shade = supported and 1 or 0.5
            row.label:SetTextColor(GOLD[1] * shade, GOLD[2] * shade, GOLD[3] * shade)
            row.value:SetTextColor(shade, shade, shade)
        end
    end
    function v.HasFocus() return false end
end

-- Builders -----------------------------------------------------------------
-- Each style builds its own body; Refresh fills whichever one is shown.

local function BuildClassic()
    local v = NewView("C", 520, 482)
    EnableCheck(v, -2, 0)
    GamepadButton(v, 270, 0, 142)
    v.help = Button(v.frame, "?  Help", 418, 0, 102, function() API.ToggleHelp() end)
    S.Heading(v.frame, "LAYOUT", 0, -38, 520)
    ModeButtons(v, 0, -62, 520)
    v.modeHint = Note(v.frame, 4, -94, 512, 2)
    v.tabArea = { x = 0, y = -128, width = 520, height = 26, size = 11 }
    ValueRows(v, 0, -166, 520, 36, 4)
    ResetRow(v, 0, -316, { 169, 169, 170 })
    v.status = Note(v.frame, 4, -350, 512, 2)
    S.Heading(v.frame, "TOOLS", 0, -388, 520)
    Tools(v, 0, -412, { 142, 110, 110, 140 })
    StyleSwitch(v, 4, -456)
    Button(v.frame, "Close", 418, -456, 102, function() window:Hide() end)
    return v
end

local function Footer(v, y, height)
    EnableCheck(v, -2, y - ((height or 26) - 26) / 2)
    StyleSwitch(v, 150, y, height)
    v.help = Button(v.frame, "?  Help", 334, y, 100, function() API.ToggleHelp() end, nil, nil, height)
    Button(v.frame, "Close", 440, y, 100, function() window:Hide() end, nil, nil, height)
end

local function BuildLegacy()
    local v = NewView("B", 540, 524)
    S.Card(v.frame, "Layout", 0, 0, 540, 104)
    GamepadButton(v, 392, -4, 136, 22, 11)
    ModeButtons(v, 12, -40, 516)
    v.modeHint = Note(v.frame, 14, -72, 512, 2)
    local position = S.Card(v.frame, "Position and size", 0, -112, 540, 262)
    v.cardTitle = position.title
    v.tabArea = { x = 12, y = -152, width = 516, height = 26, size = 11 }
    ValueRows(v, 12, -190, 516, 34, 14)
    ResetRow(v, 12, -332, { 168, 168, 168 })
    v.status = Note(v.frame, 4, -380, 532, 2)
    S.Card(v.frame, "Tools", 0, -414, 540, 74)
    Tools(v, 12, -452, { 138, 111, 111, 138 })
    Footer(v, -498)
    return v
end

local function BuildController()
    local v = NewView("A", 540, 570)
    v.controller = true
    S.Card(v.frame, "Layout", 0, 0, 540, 104)
    GamepadButton(v, 392, -4, 136, 22, 11)
    ModeButtons(v, 12, -38, 516, 28)
    v.modeHint = Note(v.frame, 14, -72, 512, 2)
    local position = S.Card(v.frame, "Position and size", 0, -112, 540, 304)
    v.cardTitle = position.title
    v.tabArea = { x = 12, y = -150, width = 516, height = 28, size = 12 }
    NudgePad(v, 0, -112)
    ResetRow(v, 12, -374, { 168, 168, 168 }, 28)
    v.status = Note(v.frame, 4, -422, 532, 2)
    S.Card(v.frame, "Tools", 0, -456, 540, 76)
    Tools(v, 12, -494, { 138, 111, 111, 138 }, 28)
    Footer(v, -542, 28)
    return v
end

local builders = { A = BuildController, B = BuildLegacy, C = BuildClassic }

-- Refresh ------------------------------------------------------------------

SetStatus = function(message)
    if view and view.status then view.status:SetText(message or "") end
end

local function LayoutTabs(v, list)
    for _, tab in pairs(v.tabs) do tab:Hide() end
    local found = false
    for _, entry in ipairs(list) do if entry[1] == selected then found = true end end
    if not found then selected = list[1][1] end
    local area, gap, count = v.tabArea, 6, #list
    local total = area.width - gap * (count - 1)
    for index, entry in ipairs(list) do
        local key = entry[1]
        -- Spread the rounding so the last tab ends exactly on the right edge.
        local left = math.floor(total * (index - 1) / count)
        local width = math.floor(total * index / count) - left
        local tab = v.tabs[key]
        if not tab then
            tab = Button(v.frame, entry[2], 0, 0, width, function()
                selected = key
                Refresh()
            end, nil, area.size, area.height)
            v.tabs[key] = tab
        end
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", area.x + left + (index - 1) * gap, area.y)
        tab:SetWidth(width)
        tab.label:SetText(entry[2])
        if IsClassTarget(key) then
            Tooltip(tab, entry[2] .. " (" .. entry[3] .. ")", "Blizzard's round " .. entry[4]:lower()
                .. " button. Hold " .. entry[3] .. " to open it. Blizzard moves it back while you press it in combat; your placement returns after combat.")
        else
            Tooltip(tab, entry[2], tips[key])
        end
        SetSelected(tab, key == selected)
        tab:Show()
    end
end

Refresh = function()
    if not window or not view then return end
    RefreshSpellbookButtons()
    refreshing = true
    local v = view
    local settings, state, caps = API.GetSettings(), API.GetState(), API.GetCapabilities()
    local live = state.mode or "standard"
    -- The layout being edited is always the one Blizzard is using.
    mode = live
    local list = Targets()
    LayoutTabs(v, list)
    local layout = mode == "compact" and settings.compact or settings.bars
    local bar = layout[selected]
    local classTab = IsClassTarget(selected)
    local entry
    for _, item in ipairs(list) do if item[1] == selected then entry = item end end

    for key, button in pairs(v.modeButtons) do
        SetSelected(button, key == mode)
        button.label:SetText((key == "compact" and "Compact" or "Standard") .. (key == live and "  ·  in use" or ""))
        button:SetAttribute("type", key == live and "" or "macro")
    end
    v.modeHint:SetText(mode == "compact"
        and "One bar at a time, stacked at the bottom. Hold LT or RT to see that bar."
        or "Each trigger bar keeps its own position, measured from Blizzard's spot.")
    v.modeHint:SetTextColor(DIM[1], DIM[2], DIM[3])
    for _, button in pairs(v.modeButtons) do button:SetEnabled(not InCombatLockdown()) end

    v.UpdateValues(bar, classTab, state.available, caps)
    v.prompts:SetShown(classTab)
    v.promptsLabel:SetShown(classTab)
    v.promptsLabel:SetText("Button prompt (" .. (entry and entry[3] or "LB + LT") .. ")")
    v.prompts.label:SetText(settings.classPrompts ~= false and "Shown" or "Hidden")
    v.prompts:SetEnabled(state.available == true)

    local tabName = entry and entry[2] or selected
    if v.cardTitle then v.cardTitle:SetText(tabName .. ": position and size") end
    v.resetBar.label:SetText("Reset " .. tabName)
    Tooltip(v.resetBar, "Reset " .. tabName, "Puts it back in Blizzard's spot, at Blizzard's size.")
    v.copy.label:SetText(mode == "compact" and "Copy from Standard" or "Copy from Compact")
    Tooltip(v.copy, v.copy.label:GetText(), mode == "compact"
        and "Base becomes the compact bar position. Stance and class buttons are copied as they are."
        or "The compact bar becomes Base. Stance and class buttons are copied as they are.")

    v.enable:SetChecked(settings.enabled == true)
    v.enable:SetEnabled(not caps.suspended)
    v.spread.label:SetText(state.spread and "Spread view: On" or "Spread view: Off")
    SetSelected(v.spread, state.spread == true)
    v.spread:SetEnabled(state.enabled == true and (state.spread or not InCombatLockdown()))
    for key, button in pairs(v.styleButtons) do SetSelected(button, key == style) end

    if sticky and GetTime and GetTime() < stickyUntil then
        SetStatus(sticky)
    elseif caps.suspended then
        SetStatus("Controller enhancements paused. Your saved settings are preserved.")
    elseif state.layoutError then
        SetStatus("A layout change was blocked, so automatic retries stopped. Reset the bar or turn Enabled off and on to try again.")
    elseif not state.available then
        SetStatus("Blizzard's controller bars are not available right now.")
    elseif InCombatLockdown() then
        SetStatus("Layout changes apply after combat.")
    elseif state.pendingLayout then
        SetStatus("Layout changes are waiting for Blizzard's bars.")
    elseif not settings.enabled then
        SetStatus("Enabled is off: Blizzard's layout is shown.")
    elseif not state.nativeEnabled then
        SetStatus("Ready. Switch to Blizzard's gamepad UI to use your layout.")
    elseif classTab then
        SetStatus("Offsets move the button from Blizzard's spot. Scale keeps it in place.")
    elseif mode == "compact" and state.spread then
        SetStatus("Spread view shows all four bars; compact play shows one at a time.")
    elseif v.controller then
        SetStatus("Bars stay visible while this window is open. Pick a step size, then use the arrows.")
    else
        SetStatus("Bars stay visible while this window is open. Shift-click - or +, or scroll over a value, for fine steps.")
    end
    refreshing = false
end

-- Style --------------------------------------------------------------------

local function ApplyStyle(key)
    style = builders[key] and key or "A"
    local v = views[style]
    if not v then
        v = builders[style]()
        views[style] = v
    end
    if view and view ~= v then view.frame:Hide() end
    view = v
    window.chrome:SetKind(S.ChromeKind(style))
    local inset = window.chrome:Insets()
    v.frame:ClearAllPoints()
    v.frame:SetPoint("TOPLEFT", inset.left, -inset.top)
    window:SetSize(v.width + inset.left + inset.right, v.height + inset.top + inset.bottom)
    v.frame:Show()
    S.Fit(window)
end

local function ApplyHelpStyle()
    if not help then return end
    help.chrome:SetKind(S.ChromeKind(style))
    local inset = help.chrome:Insets()
    help.body:ClearAllPoints()
    help.body:SetPoint("TOPLEFT", inset.left, -inset.top)
    help:SetSize(720 + inset.left + inset.right, 300 + inset.top + inset.bottom)
    S.Fit(help)
end

SelectStyle = function(key)
    if not builders[key] then return end
    if API.SetOptionsStyle then API.SetOptionsStyle(key) end
    if not window then style = key; return end
    ApplyStyle(key)
    ApplyHelpStyle()
    if window:IsShown() then Refresh() end
end
API.SelectOptionsStyle = SelectStyle

-- Help ---------------------------------------------------------------------

local topics = {
    { "Compact mode", "Blizzard's Compact Action Bar setting is in Edit Mode: select the controller action bar there. It is saved with the Edit Mode layout. With it on, the four trigger bars sit in one spot at the bottom and only the active bar is shown.\n\nCompanion keeps two layouts: Compact and Standard. It uses the one that matches Blizzard's setting, so switching modes never scrambles the other layout. Click the mode that is not in use to open Edit Mode and change it there (not during combat).\n\nTo move the whole bar block, use Edit Mode too. Companion's offsets are added on top of Blizzard's position.\n\nIn Compact, Action bars moves all four bars together. Copy from Standard / Compact carries Base, Stance and the class buttons across." },
    { "Bar layout", "Choose a bar tab, then adjust its offsets and scale. Offsets move the bar from Blizzard's position; scale changes its size. To enlarge the bar you are holding, tick Expand on the controller action bar in Edit Mode.\n\nBase also moves the 1-2-3 page selector, the shoulder icons and their targeting/shortcut bars.\n\nStance controls the shared bar Blizzard fills with your form actions. Edit those actions in Spread view.\n\nShift-click - or + for fine steps, or scroll the mouse wheel over a value. Type a value and press Enter or Tab to apply it. During combat, geometry waits until combat ends." },
    { "Class buttons", "Druids, paladins, warriors, hunters and warlocks get round class buttons below the bars (LB + LT, RB + RT). They open a radial menu of forms, auras, stances or pet commands.\n\nTheir tab moves and scales that button. The two-icon prompt under it follows, or can be hidden.\n\nBlizzard puts the button back in its own spot every time it's pressed. Outside combat Companion restores your placement at once; in combat it stays in Blizzard's spot until combat ends." },
    { "Edit Mode", "Blizzard Edit Mode now has its own gamepad layouts. Open it in the gamepad UI (Edit Mode button) to move frames and the controller action bar block. Blizzard keeps one layout for the keyboard and one for the gamepad, and switches between them by itself.\n\nGamepad Companion no longer moves frames. A Companion layout you used is converted once, the first time you use the gamepad UI: it becomes a Blizzard layout named after your character (Name Gamepad) and is selected. Your old Companion layouts stay saved as a backup.\n\n/gpc edit shows what happened. /gpc edit convert makes the Blizzard layout again, for example after you deleted it." },
    { "Visibility", "Use Frame Gambit to control when bars fade or appear. Add a visibility rule for the controller bar you want to manage.\n\nGamepad Companion controls bar placement and size. Keep one addon responsible for visibility." },
    { "Window styles", "A (default) is made for the gamepad cursor: bigger buttons, arrows to move a bar, and a step size (1, 10 or 50) instead of typing or Shift-click.\n\nB uses the window of Forever Names, Petal and Halo, with each section in a card and typed values.\n\nC is Gamepad Companion's original look.\n\nPick one with the Style buttons at the bottom of the options window, or /gpc style A, B or C. Your settings are the same in every style." },
    { "Commands", "/gpc  open or close this window\n/gpc on | off  apply or release your layout\n/gpc reset  reset both layouts\n/gpc style A | B | C  window style\n/gpc gamepad  open Blizzard's gamepad options\n/gpc edit  your Blizzard gamepad layout (convert, list)\n/gpc help  list these commands in chat" },
}

function API.ToggleHelp()
    if not help then
        help = CreateFrame("Frame", "GamepadCompanionHelp", UIParent)
        help:SetPoint("CENTER")
        help:SetFrameStrata("FULLSCREEN_DIALOG")
        help:SetToplevel(true)
        help.chrome = S.Chrome(help, "Gamepad Companion · Help")
        help.body = CreateFrame("Frame", nil, help)
        help.body:SetSize(720, 300)
        local copy = Text(help.body, "", 172, -4, 548, 13)
        copy:SetJustifyV("TOP")
        copy:SetHeight(260)
        local buttons = {}
        local function Show(index)
            copy:SetText(topics[index][2])
            for i, button in ipairs(buttons) do SetSelected(button, i == index) end
        end
        for index, topic in ipairs(topics) do
            buttons[index] = Button(help.body, topic[1], 0, -(index - 1) * 32, 150, function() Show(index) end)
        end
        if API.GetCapabilities().suspended then
            copy:SetText("Controller enhancements are paused in this recovery build. Blizzard's controller UI remains in control.\n\nYour saved layout settings are preserved.")
        else
            Show(1)
        end
        Button(help.body, "Close", 620, -274, 100, function() help:Hide() end)
        UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionHelp"
        S.RegisterWindow(help)
        help:Hide()
    end
    ApplyHelpStyle()
    help:SetShown(not help:IsShown())
    if help:IsShown() then help:Raise() end
end

-- Window -------------------------------------------------------------------

local function CreateOptions()
    window = CreateFrame("Frame", "GamepadCompanionOptions", UIParent)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    local title = "Gamepad Companion"
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    if type(version) == "string" then title = title .. "  |cff9d9d9d" .. version .. "|r" end
    window.chrome = S.Chrome(window, title)
    UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionOptions"
    S.RegisterWindow(window)
    window:Hide()
    local function StateChanged()
        if not window:IsShown() or (view and view.HasFocus and view.HasFocus()) then return end
        Refresh()
    end
    window:SetScript("OnShow", function()
        API.SetEditing(true)
        API.Subscribe(window, StateChanged)
    end)
    window:SetScript("OnHide", function()
        API.Unsubscribe(window)
        if openingPanel then return end
        API.SetEditing(false)
        if help then help:Hide() end
    end)
    window:RegisterEvent("PLAYER_REGEN_ENABLED")
    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:RegisterEvent("PLAYER_ENTERING_WORLD")
    window:SetScript("OnEvent", function() if window:IsShown() then Refresh() end end)
    if SettingsPanel and SettingsPanel.HookScript then
        SettingsPanel:HookScript("OnHide", function()
            if not reopenAfterSettings then return end
            reopenAfterSettings = nil
            if not window:IsShown() and not InCombatLockdown() then API.ToggleOptions() end
        end)
    end
    ApplyStyle(S.CurrentStyle())
end

function API.ToggleOptions()
    if not window then CreateOptions() end
    if window:IsShown() then window:Hide(); return end
    -- Open on the layout Blizzard is using now.
    mode = API.GetState().mode or "standard"
    S.Fit(window)
    Refresh()
    window:Show()
    window:Raise()
end

function API.RefreshOptions()
    if window and window:IsShown() then Refresh() end
end
