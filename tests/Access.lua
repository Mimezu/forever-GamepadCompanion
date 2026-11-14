-- lua5.1 tests/Access.lua <addon folder>
-- Window key (setter), Blizzard Settings page, minimap icon, and the Tools card.
local root = arg[1] or "."
local ns = {}
local combat, now = false, 100
local created = {}
local methods = {}
local function new(kind, name, parent, template)
    local f = setmetatable({ kind = kind, name = name, parent = parent, template = template, scripts = {}, shown = true,
        points = {}, attributes = {}, enabled = true }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
    created[#created + 1] = f
    if name then _G[name] = f end
    return f
end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:GetScript(key) return self.scripts[key] end
function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:CreateFontString() return new("FontString", nil, self) end
function methods:CreateTexture() return new("Texture", nil, self) end
function methods:SetPoint(point, a, b, c, d)
    if type(a) == "number" then self.points[#self.points + 1] = { point, self.parent, point, a, b }
    else self.points[#self.points + 1] = { point, a, b, c, d } end
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:IsShown() return self.shown end
function methods:Show()
    local was = self.shown; self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local was = self.shown; self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsVisible()
    local f = self
    while f do if not f.shown then return false end; f = f.parent end
    return true
end
function methods:IsEnabled() return self.enabled end
function methods:SetEnabled(v) self.enabled = v and true or false end
function methods:SetChecked(v) self.checked = v and true or false end
function methods:GetChecked() return self.checked end
function methods:EnableKeyboard(v) self.keyboard = v end
function methods:SetPropagateKeyboardInput(v) self.propagate = v end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function CreateFrame(kind, name, parent, template) return new(kind, name, parent, template) end
UIParent = new("Frame", "UIParent")
function UIParent:GetWidth() return 1920 end
function UIParent:GetHeight() return 1080 end
UISpecialFrames = {}
GameTooltip = new("Frame", "GameTooltip")
Minimap = new("Frame", "Minimap")
Minimap.width = 140
function Minimap:GetCenter() return 1800, 900 end
function Minimap:GetEffectiveScale() return 1 end
local cursor = { 1800, 1000 }
function GetCursorPosition() return cursor[1], cursor[2] end
InCombatLockdown = function() return combat end
GetTime = function() return now end
local mods = {}
IsShiftKeyDown = function() return mods.shift == true end
IsControlKeyDown = function() return mods.ctrl == true end
IsAltKeyDown = function() return false end
UnitClass = function() return "Hunter", "HUNTER" end
UnitName = function() return "Alberich" end
C_Texture = { GetAtlasInfo = function() return nil end }
SlashCmdList = {}
local printed = {}
print = function(text) printed[#printed + 1] = text end

-- Key bindings
local bindings, saved = { F5 = "TOGGLEWORLDMAP" }, 0
BINDING_NAME_TOGGLEWORLDMAP = "Toggle World Map"
function GetBindingKey(action)
    local keys = {}
    for key, a in pairs(bindings) do if a == action then keys[#keys + 1] = key end end
    table.sort(keys)
    return unpack(keys)
end
function GetBindingAction(key) return bindings[key] or "" end
function GetBindingText(key) return key end
function SetBinding(key, action)
    if combat then error("SetBinding in combat") end
    bindings[key] = action
    return true
end
function SaveBindings() saved = saved + 1 end
function GetCurrentBindingSet() return 2 end
ReloadUI = function() error("ReloadUI is protected; Companion must not call it") end

-- Blizzard Settings
local registered = {}
local settingsShown = true
SettingsPanel = new("Frame", "SettingsPanel")
function SettingsPanel:IsShown() return settingsShown end
function HideUIPanel(frame) if frame == SettingsPanel then settingsShown = false end end
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
    RegisterAddOnCategory = function(category) registered[#registered + 1] = category end,
}

-- Provider with real normalization and the real SetMinimap shape
assert(loadfile(root .. "/Model.lua"))("GamepadCompanion", ns)
local M = ns.Model
local settings = M.Normalize({})
GamepadCompanionAPI = {
    GetSettings = function() return M.Copy(settings) end,
    GetState = function() return { available = true, enabled = true, mode = "standard" } end,
    GetCapabilities = function() return { layout = true } end,
    Subscribe = function() end, Unsubscribe = function() end, SetEditing = function() end,
    SetMinimap = function(shown, angle)
        local current = settings.minimap
        if shown == nil then shown = current.shown end
        settings.minimap = M.Normalize({ minimap = { shown = shown ~= false, angle = angle or current.angle } }).minimap
        return true
    end,
}
local api = GamepadCompanionAPI
for _, file in ipairs({ "OptionsSkin.lua", "Window.lua", "Access.lua", "Options.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local A = ns.Access

local function login()
    for _, f in ipairs(created) do
        if f.events and f.events.PLAYER_LOGIN and f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
    end
end

-- Saved shape: icon shown by default; angle kept, clamped
local fresh = M.Normalize({})
assert(fresh.minimap.shown == true and fresh.minimap.angle == 200, "icon on by default")
assert(M.Normalize({ minimap = { shown = false, angle = 999 } }).minimap.angle == 360)
assert(M.Normalize({ minimap = { shown = false } }).minimap.shown == false)
io.stdout:write("PASS: minimap setting normalizes\n")

-- Binding names and the toggle
assert(BINDING_NAME_GAMEPADCOMPANION_TOGGLE and BINDING_HEADER_GAMEPADCOMPANION == "Gamepad Companion")
GamepadCompanion_Toggle()
assert(GamepadCompanionOptions:IsShown(), "key opens the window")
GamepadCompanion_Toggle()
assert(not GamepadCompanionOptions:IsShown(), "and closes it")
local xml = assert(io.open(root .. "/Bindings.xml")):read("*a")
assert(xml:find('name="GAMEPADCOMPANION_TOGGLE"', 1, true) and xml:find("GamepadCompanion_Toggle()", 1, true))
io.stdout:write("PASS: window key binding toggles the window\n")

-- Login: Settings page and minimap icon
login()
assert(#registered == 1 and registered[1].name == "Gamepad Companion", "AddOns category with the title")
local panel = A.panel
assert(panel.open.text == "Open" and panel.slash.text == "/gpc", "Open button and slash hint")
local icon = assert(GamepadCompanionMinimapButton, "minimap icon built")
assert(icon:IsShown() and icon.points[1][2] == Minimap, "shown, on the minimap")
assert(panel.icon.checked == true, "checkbox mirrors the icon")
io.stdout:write("PASS: Settings page registered; icon shown by default\n")

-- Open from Settings closes Settings first
panel.open.scripts.OnClick(panel.open)
assert(not settingsShown and GamepadCompanionOptions:IsShown(), "Settings closed, window open")
GamepadCompanionOptions:Hide()
io.stdout:write("PASS: Open closes Settings and opens the window\n")

-- Icon: tooltip, click toggles, drag saves the angle
icon.scripts.OnEnter(icon)
assert(GameTooltip.text == "Gamepad Companion")
icon.scripts.OnClick(icon)
assert(GamepadCompanionOptions:IsShown())
icon.scripts.OnClick(icon)
assert(not GamepadCompanionOptions:IsShown())
icon.scripts.OnDragStart(icon)
cursor = { 1800, 1000 }          -- straight above the centre
icon.scripts.OnUpdate(icon)
icon.scripts.OnDragStop(icon)
assert(math.abs(settings.minimap.angle - 90) < 1e-6, "angle saved: " .. settings.minimap.angle)
local p = icon.points[1]
assert(math.abs(p[4]) < 1e-6 and math.abs(p[5] - 80) < 1e-6, "placed above the minimap edge")
io.stdout:write("PASS: icon tooltip, click, drag round the edge\n")

-- Checkbox hides the icon and saves it
panel.icon.checked = false
panel.icon.scripts.OnClick(panel.icon)
assert(settings.minimap.shown == false and not icon:IsShown())
assert(settings.minimap.angle == 90, "angle kept")
panel.icon.checked = true
panel.icon.scripts.OnClick(panel.icon)
assert(settings.minimap.shown == true and icon:IsShown())
io.stdout:write("PASS: minimap checkbox\n")

-- Key setter in Settings: listen, modifiers combine, replaces, warns, saves
local key = panel.key
assert(key.text == "Not set")
key.scripts.OnClick(key, "LeftButton")
assert(key.text == "Press a key" and key.keyboard == true and key.propagate == false, "listening")
key.scripts.OnKeyDown(key, "LSHIFT")
assert(A.Listening() == key, "a modifier alone keeps listening")
mods.shift = true
key.scripts.OnKeyDown(key, "G")
mods.shift = false
assert(bindings["SHIFT-G"] == "GAMEPADCOMPANION_TOGGLE" and saved == 1 and key.text == "SHIFT-G")
assert(not A.Listening() and key.keyboard == false)
key.scripts.OnClick(key, "LeftButton")
key.scripts.OnKeyDown(key, "F5")
assert(bindings.F5 == "GAMEPADCOMPANION_TOGGLE" and bindings["SHIFT-G"] == nil, "moved to the new key")
assert(printed[#printed]:find("Toggle World Map", 1, true), "names what the key did before")
key.scripts.OnClick(key, "LeftButton")
key.scripts.OnKeyDown(key, "ESCAPE")
assert(bindings.F5 == "GAMEPADCOMPANION_TOGGLE" and key.text == "F5", "Esc cancels")
key.scripts.OnClick(key, "RightButton")
assert(GetBindingKey("GAMEPADCOMPANION_TOGGLE") == nil and key.text == "Not set", "right-click clears")
combat = true
key.scripts.OnClick(key, "LeftButton")
assert(not A.Listening() and printed[#printed]:find("Not in combat"), "refused in combat")
combat = false
io.stdout:write("PASS: key setter listens, combines, replaces, cancels, clears, refuses in combat\n")

-- Tools card: same key and icon toggle, both stay in step
api.ToggleOptions("tools")
local card = assert(ns.Access and GamepadCompanionOptions and (function()
    for _, f in ipairs(created) do if f.label and f.label.text == "Not set" and f.tipTitle == "Window key" then return f end end
end)(), "Tools card keycap")
card.scripts.OnClick(card, "LeftButton")
assert(card.label.text == "Press a key" and card.selected, "listening, lit")
card.scripts.OnKeyDown(card, "F9")
assert(bindings.F9 == "GAMEPADCOMPANION_TOGGLE" and card.label.text == "F9" and key.text == "F9", "both keycaps updated")
card.scripts.OnClick(card, "LeftButton")
card:Hide()  -- the client hides children with the window
GamepadCompanionOptions:Hide()
assert(not A.Listening(), "closing the window stops listening")
local check
for _, f in ipairs(created) do if f.kind == "CheckButton" and f.label and f.label.text == "Minimap icon" then check = f end end
assert(check and check.checked == true)
check.checked = false
check.scripts.OnClick(check)
assert(not icon:IsShown() and panel.icon.checked == false, "Tools checkbox and Settings checkbox in step")
io.stdout:write("PASS: Tools card key and minimap icon\n")

-- No ReloadUI anywhere in the addon's code
for _, file in ipairs({ "Access.lua", "Options.lua", "Window.lua", "Core.lua" }) do
    local source = assert(io.open(root .. "/" .. file)):read("*a")
    assert(not source:find("ReloadUI%s*%("), file .. " calls ReloadUI")
end
io.stdout:write("PASS: no ReloadUI\n")
