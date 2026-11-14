-- Ways into the window: a keyboard key (Bindings.xml), a page in Blizzard's
-- Settings (Esc > Options > AddOns) and a minimap icon. The key is set from the
-- Tools page and the Settings page: click the keycap, press a key (Esc cancels,
-- right-click clears). Pad buttons stay on the Controller page.
local ADDON, ns = ...
local S, Shell = ns.OptionsSkin, ns.Shell
local API = GamepadCompanionAPI
local Access = {}
ns.Access = Access

local TITLE = "Gamepad Companion"
Access.ACTION = "GAMEPADCOMPANION_TOGGLE"
BINDING_HEADER_GAMEPADCOMPANION = TITLE
BINDING_CATEGORY_GAMEPADCOMPANION = TITLE
BINDING_NAME_GAMEPADCOMPANION_TOGGLE = "Open or close window"

function GamepadCompanion_Toggle() Shell.Toggle() end

local function Say(message) print("|cff80c0ffGamepad Companion:|r " .. message) end
local function Notice(message)
    if Shell.IsShown() then Shell.SetStatus(message, true) end
    Say(message)
end

-- Every widget showing the key, refreshed together
local setters = {}
local function RefreshAll() for _, refresh in ipairs(setters) do pcall(refresh) end end
Access.Refresh = RefreshAll

-- Key -----------------------------------------------------------------------------

function Access.KeyText()
    local key = GetBindingKey and GetBindingKey(Access.ACTION)
    if not key then return "Not set" end
    return GetBindingText and GetBindingText(key) or key
end

-- key nil clears. Out of combat only. Returns ok, and what the key did before.
function Access.Bind(key)
    if InCombatLockdown() or not SetBinding then return false end
    local previous = key and GetBindingAction and GetBindingAction(key)
    for _, old in ipairs({ GetBindingKey(Access.ACTION) }) do SetBinding(old) end
    if key then SetBinding(key, Access.ACTION) end
    if SaveBindings then SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end
    if previous == "" or previous == Access.ACTION then previous = nil end
    return true, previous and (_G["BINDING_NAME_" .. previous] or previous) or nil
end

local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true }

function Access.Combo(key)
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. (IsMetaKeyDown and IsMetaKeyDown() and "META-" or "") .. key
end

local listening
local function Stop()
    local button = listening
    listening = nil
    if button then
        button:SetScript("OnKeyDown", nil)
        button:EnableKeyboard(false)
    end
    RefreshAll()
end
Access.Stop = Stop
function Access.Listening() return listening end

-- The next key pressed: Esc cancels, modifiers combine, a key already in use
-- is taken over (named in chat).
function Access.Listen(button)
    if InCombatLockdown() then Notice("Not in combat"); return false end
    if listening then Stop() end
    listening = button
    button:EnableKeyboard(true)
    if button.SetPropagateKeyboardInput then button:SetPropagateKeyboardInput(false) end
    button:SetScript("OnKeyDown", function(_, key)
        if MODIFIERS[key] then return end
        if key ~= "ESCAPE" then
            local combo = Access.Combo(key)
            local ok, previous = Access.Bind(combo)
            if not ok then Notice("Not in combat")
            elseif previous then Notice((GetBindingText and GetBindingText(combo) or combo) .. " was: " .. previous) end
        end
        Stop()
    end)
    RefreshAll()
    return true
end

-- Makes `button` (the caller's style) a keycap: shows the key, click to
-- listen, right-click to clear.
function Access.Setter(button)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouse)
        if listening == self then Stop(); return end
        if mouse == "RightButton" then
            if not Access.Bind(nil) then Notice("Not in combat") end
            RefreshAll()
            return
        end
        Access.Listen(self)
    end)
    button:HookScript("OnHide", function(self) if listening == self then Stop() end end)
    local function Refresh()
        local text = listening == button and "Press a key" or Access.KeyText()
        if button.label then button.label:SetText(text) else button:SetText(text) end
        if S.SetSelected and button.selection then S.SetSelected(button, listening == button) end
    end
    setters[#setters + 1] = Refresh
    Refresh()
    return button
end

-- Minimap icon --------------------------------------------------------------------

local ICON_ATLAS, ICON_FILE = "gamepad-radial-icon-gamemenu", "Interface\\Icons\\INV_Misc_Gear_01"
local icon

local function MinimapSettings() return API.GetSettings().minimap or { shown = true, angle = 200 } end

-- Where the icon sits for an angle in degrees: just outside the minimap's edge
function Access.IconOffset(angle, radius)
    local r = math.rad(angle)
    return math.cos(r) * radius, math.sin(r) * radius
end

local function Place(angle)
    if not icon or not Minimap then return end
    local radius = (Minimap:GetWidth() or 140) / 2 + 10
    local x, y = Access.IconOffset(angle, radius)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CursorAngle()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    return angle < 0 and angle + 360 or angle
end

local function BuildIcon()
    if icon or not Minimap then return icon end
    icon = CreateFrame("Button", "GamepadCompanionMinimapButton", Minimap)
    icon:SetSize(31, 31)
    icon:SetFrameStrata("MEDIUM")
    icon:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    icon:RegisterForClicks("LeftButtonUp")
    icon:RegisterForDrag("LeftButton")
    local art = icon:CreateTexture(nil, "BACKGROUND")
    art:SetSize(20, 20)
    art:SetPoint("CENTER", 0, 1)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ICON_ATLAS)
    if info then art:SetAtlas(ICON_ATLAS) else art:SetTexture(ICON_FILE) end
    icon.art = art
    local border = icon:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    icon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    icon:SetScript("OnClick", function() Shell.Toggle() end)
    icon:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function() Place(CursorAngle()) end)
    end)
    icon:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        API.SetMinimap(nil, CursorAngle())
        Place(MinimapSettings().angle)
    end)
    icon:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(TITLE, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return icon
end

function Access.UpdateIcon()
    local saved = MinimapSettings()
    if saved.shown then
        if not BuildIcon() then return end
        Place(saved.angle)
        icon:Show()
    elseif icon then
        icon:Hide()
    end
    RefreshAll()
end

function Access.SetIconShown(shown)
    API.SetMinimap(shown == true)
    Access.UpdateIcon()
end
function Access.IconShown() return MinimapSettings().shown == true end
Access.Icon = function() return icon end

-- Blizzard Settings page ----------------------------------------------------------

local function OpenFromSettings()
    if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
        if HideUIPanel then pcall(HideUIPanel, SettingsPanel) else SettingsPanel:Hide() end
    end
    Shell.Open()
end

function Access.BuildSettingsPanel()
    local panel = CreateFrame("Frame")
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText(TITLE)
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(140, 26)
    open:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
    open:SetText("Open")
    open:SetScript("OnClick", OpenFromSettings)
    panel.open = open
    local slash = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    slash:SetPoint("LEFT", open, "RIGHT", 12, 0)
    slash:SetText("/gpc")
    panel.slash = slash

    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -2, -14)
    local label = type(check.Text) == "table" and check.Text or check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:ClearAllPoints()
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText("Minimap icon")
    check:SetScript("OnClick", function(self) Access.SetIconShown(self:GetChecked() == true) end)
    panel.icon = check

    local keyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keyLabel:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 2, -16)
    keyLabel:SetText("Window key")
    local key = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    key:SetSize(140, 26)
    key:SetPoint("LEFT", keyLabel, "RIGHT", 12, 0)
    Access.Setter(key)
    key:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Window key", 1, 0.82, 0)
        GameTooltip:AddLine("Right-click: clear", 1, 1, 1)
        GameTooltip:Show()
    end)
    key:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.key = key

    setters[#setters + 1] = function() check:SetChecked(Access.IconShown()) end
    panel:SetScript("OnShow", RefreshAll)
    return panel
end

function Access.RegisterSettings()
    if Access.category or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return Access.category
    end
    local panel = Access.BuildSettingsPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
    Access.panel, Access.category = panel, category
    return category
end

-- Tools page card -----------------------------------------------------------------

function Access.BuildCard(parent, x, y, width, height)
    local card = S.Card(parent, "Window", x, y, width, height)
    S.Text(card, "Key", 14, -52, 60, 13, S.GOLD)
    local key = S.NewButton(card, "", 70, -44, 200, nil, nil, 13, 30)
    S.Tooltip(key, "Window key", "Right-click: clear")
    Access.Setter(key)
    local check = S.NewCheck(card, "Minimap icon", 310, -46, function(self)
        Access.SetIconShown(self:GetChecked() == true)
    end, 110)
    setters[#setters + 1] = function() check:SetChecked(Access.IconShown()) end
    RefreshAll()
    card.key, card.icon = key, check
    return card
end

-- Start --------------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "UPDATE_BINDINGS", "PLAYER_REGEN_DISABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        pcall(Access.RegisterSettings)
        Access.UpdateIcon()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if listening then Stop() end
    else
        RefreshAll()
    end
end)
