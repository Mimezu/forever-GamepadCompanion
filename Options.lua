-- The Bars and Tools pages of the Gamepad Companion window (Window.lua).
--   Bars   My bar layout, Edit in Edit Mode (EditModeBars.lua places the bars),
--          the layout in use, its Copy and Reset (each with Undo)
--   Tools  Blizzard's spellbook, macros and gamepad options; spread view; the
--          window's skin, size, key and minimap icon
local _, ns = ...
local S, Shell = ns.OptionsSkin, ns.Shell
local API = GamepadCompanionAPI
local GOLD, GREY, DIM = S.GOLD, S.GREY, S.DIM
local Text, Button, Tooltip, SetSelected = S.Text, S.NewButton, S.Tooltip, S.SetSelected
local W = Shell.W

local mode
local ui = {}
local spellButtons = {}
local openingPanel, reopenAfterSettings
local Refresh

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

local function Notice(message) Shell.SetStatus(message, true) end

local function Result(ok, reason)
    Refresh()
    if reason then
        Notice((reason == "combat" or reason == "pending") and "Applies after combat" or tostring(reason))
    elseif ok == false then
        Notice("Not applied")
    end
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
    -- (the pad's focus ring never clicks it: a click from addon code runs it tainted)
    b.gpcFocusSkip = true
    return b
end

-- Bars page ----------------------------------------------------------------------
-- The bars are placed in Blizzard's Edit Mode (EditModeBars.lua): drag one,
-- click it for its scale, button prompt and Reset. Here only what Edit Mode
-- has no place for: the switch, the layout in use, and the whole layout's Copy
-- and Reset.

local function BuildBars(frame, header)
    ui.frame = frame
    ui.enable = S.NewCheck(header, "My bar layout", W - 150, -4, function(self)
        Result(API.SetEnabled(self:GetChecked() == true))
    end, 110)
    Tooltip(ui.enable, "My bar layout", "Off: Blizzard's, settings kept")

    local card = S.Card(frame, "Bars", 0, 0, W, 250)
    ui.editMode = SlashButton(card, "Edit in Edit Mode", 20, -52, 360, 56, "/editmode")
    ui.editMode.label:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
    ui.editMode:SetScript("PostClick", function() if InCombatLockdown() then Notice("Not in combat") end end)
    Tooltip(ui.editMode, "Edit Mode", "Drag a bar · click it: scale, prompt, reset")
    ui.off = Text(card, "", 400, -74, W - 420, 13, GREY)
    ui.layout = Text(card, "", 20, -132, W - 40, 13, GOLD)
    -- the whole layout at once: done, then Undo for a few seconds (as Default › Undo)
    local function Undoable(what, fn)
        local EB = ns.EditModeBars
        local snap = EB and EB.Snapshot(mode)
        local ok, reason = fn()
        Result(ok, reason)
        if ok and snap and Shell.Offer then
            local at = mode
            Shell.Offer(what, "Undo", function() EB.Restore(at, snap); Refresh() end)
        end
    end
    ui.copy = Button(card, "Copy from Standard", 20, -170, 200, function()
        local from = mode == "compact" and "standard" or "compact"
        Undoable("Copied from " .. (from == "compact" and "Compact" or "Standard"), function() return API.CopyLayout(from, mode) end)
    end, nil, 12, 30)
    ui.resetLayout = Button(card, "Reset layout", 230, -170, 150, function()
        Undoable("Layout reset", function() return API.ResetMode(mode) end)
    end, nil, 12, 30)
    Tooltip(ui.resetLayout, "Reset layout", "Every bar of this layout")
end

local function BarsStatus(settings, state, caps)
    if caps.suspended then return "Paused · settings kept" end
    if state.layoutError then return "Layout blocked" end
    if not state.available then return "Controller bars unavailable" end
    if InCombatLockdown() then return "Applies after combat" end
    if state.pendingLayout then return "Waiting for Blizzard's bars" end
    if not settings.enabled then return "Off · Blizzard's layout" end
    if not state.nativeEnabled then return "Ready · applies in gamepad UI" end
    return "Ready"
end

local function RefreshBars()
    if not ui.frame then return end
    local settings, state, caps = API.GetSettings(), API.GetState(), API.GetCapabilities()
    mode = state.mode or "standard"
    -- (off: Blizzard's bars, said in a few words)
    ui.off:SetText(settings.enabled == true and "" or "Off · Blizzard's bars")
    ui.layout:SetText((mode == "compact" and "Compact" or "Standard") .. "  ·  set in Edit Mode")
    ui.copy.label:SetText(mode == "compact" and "Copy from Standard" or "Copy from Compact")
    ui.editMode:SetEnabled(not InCombatLockdown())
    ui.enable:SetChecked(settings.enabled == true)
    ui.enable:SetEnabled(not caps.suspended)
    Shell.SetStatus(BarsStatus(settings, state, caps))
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
    spells.gpcFocusSkip = true
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
    local macros = SlashButton(blizz, "Macros", 24 + bw, -44, bw, 40, "/macro")
    macros:SetScript("PreClick", function() local w = Window(); openingPanel = w and w:IsShown() end)
    macros:SetScript("PostClick", function()
        ReturnToEditor()
        if InCombatLockdown() then Notice("Not in combat") end
    end)
    local gamepad = Button(blizz, "Gamepad options", 12, -118, bw, function()
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
