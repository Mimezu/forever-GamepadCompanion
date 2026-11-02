-- Run from GamepadCompanion: luajit tests/OptionsStyles.lua .
-- Options window styles A/B/C, shared controls and the Edit Mode panel skin.
local root = arg[1] or "."
local ns = {}
local combat, now = false, 100
local created, registered, calls = {}, {}, {}
local methods = {}
local function new(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, shown = true, points = {},
        attributes = {}, enabled = true }, { __index = function(_, key)
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
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:GetSize() return self:GetWidth(), self:GetHeight() end
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
function methods:SetEnabled(v)
    local was = self.enabled; self.enabled = v and true or false
    if was ~= self.enabled and self.scripts[self.enabled and "OnEnable" or "OnDisable"] then
        self.scripts[self.enabled and "OnEnable" or "OnDisable"](self)
    end
end
function methods:SetChecked(v) self.checked = v and true or false end
function methods:GetChecked() return self.checked end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:HasFocus() return self.focus == true end
local focused
function methods:SetFocus()
    -- Like the client: focusing one box takes focus from the other.
    if focused and focused ~= self then focused:ClearFocus() end
    focused = self
    self.focus = true
    if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function methods:ClearFocus()
    local was = self.focus; self.focus = false
    if was and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function methods:SetScale(s) self.scale = s end
function methods:SetTextColor(r, g, b) self.color = { r, g, b } end
function CreateFrame(kind, name, parent) return new(kind, name, parent) end
UIParent = new("Frame", "UIParent")
function UIParent:GetWidth() return 1920 end
function UIParent:GetHeight() return 1080 end
UISpecialFrames = {}
GameTooltip = new("Frame", "GameTooltip")
InCombatLockdown = function() return combat end
GetTime = function() return now end
IsShiftKeyDown = function() return false end
UnitClass = function() return "Hunter", "HUNTER" end
C_Texture = { GetAtlasInfo = function(atlas)
    if atlas:find("arrow") then return nil end
    return { file = 1, width = 300, height = 50, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
end }
NineSliceUtil = { ApplyLayoutByName = function(frame, layout) frame.nineslice = layout end }
FrameGambitAPI = { RegisterCinematicWindow = function(frame) registered[frame] = true; return true end }
SlashCmdList = {}

-- Provider stub with real settings normalization.
assert(loadfile(root .. "/Model.lua"))("GamepadCompanion", ns)
local M = ns.Model
local settings = M.Normalize({ compact = { bars = { y = -50, scale = 0.9 } } })
local state = { available = true, enabled = true, nativeEnabled = true, gameplay = true, mode = "compact", compact = true }
local editing = false
GamepadCompanionAPI = {
    GetSettings = function() return M.Copy(settings) end,
    GetState = function() return M.Copy(state) end,
    GetCapabilities = function() return { layout = true, activeZoom = true } end,
    Subscribe = function() end, Unsubscribe = function() end,
    SetEditing = function(v) editing = v end,
    SetSpread = function(v) state.spread = v; return true end,
    SetBarOption = function(layer, key, value, mode)
        calls[#calls + 1] = { layer, key, value, mode }
        M.Layout(settings, mode)[layer][key] = value
        return true
    end,
    SetEnabled = function(v) settings.enabled = v; return true end,
    SetClassPrompts = function(v) settings.classPrompts = v; return true end,
    ResetBar = function() return true end, ResetMode = function() return true end, CopyLayout = function() return true end,
    SetOptionsStyle = function(v) settings.optionsStyle = v; return true end,
}
local api = GamepadCompanionAPI
assert(loadfile(root .. "/OptionsSkin.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Options.lua"))("GamepadCompanion", ns)

local function find(label, kind)
    for _, f in ipairs(created) do
        local text = type(rawget(f, "label")) == "table" and f.label.text
        if text == label and (not kind or f.kind == kind) and f:IsVisible() then return f end
    end
end
local function click(label)
    local button = assert(find(label), "Missing visible button: " .. label)
    assert(button.enabled, "button disabled: " .. label)
    if button.scripts.PreClick then button.scripts.PreClick(button) end
    button.scripts.OnClick(button)
    if button.scripts.PostClick then button.scripts.PostClick(button) end
end
local function visibleEdits()
    local list = {}
    for _, f in ipairs(created) do if f.kind == "EditBox" and f:IsVisible() then list[#list + 1] = f end end
    return list
end

-- Style A (controller) is the default and registers with Frame Gambit's Cinematic windows.
api.ToggleOptions()
local window = GamepadCompanionOptions
assert(window:IsShown() and editing)
assert(registered[window], "options window opts into Cinematic suite windows")
assert(settings.optionsStyle == "A" and window.width == 588 and window.height == 628, "controller layout is the default")
assert(#visibleEdits() == 0, "the default has no text entry")
-- Style C is the classic look.
click("C")
assert(settings.optionsStyle == "C" and editing)
assert(window.width == 560 and window.height == 560, "classic window keeps its 560x560 size")
assert(find("Compact  ·  in use") and find("Action bars") and find("Pet menu") and find("Pet spells"))
-- Tabs fill the row exactly: the last one ends on the right edge.
local tab = find("Pet spells")
assert(tab.points[1][4] + tab.width == 520, "last tab ends at the content edge, got " .. tab.points[1][4] + tab.width)
print("PASS: style A (controller) default, C classic at 560x560, Cinematic registration, tabs fill the row")

-- Enabled is a check box that reflects the saved setting.
local enable
for _, f in ipairs(created) do if f.kind == "CheckButton" and f:IsVisible() then enable = f end end
assert(enable and enable.checked == true)
enable.checked = false
enable.scripts.OnClick(enable)
assert(settings.enabled == false and enable.checked == false)
enable.checked = true
enable.scripts.OnClick(enable)
assert(settings.enabled == true)
print("PASS: Enabled check box toggles and mirrors the setting")

-- Typed values: comma decimals, Enter applies, leaving without Enter reverts.
local edits = visibleEdits()
assert(#edits == 3, "x, y and scale; active zoom was removed in 0.4.0")
local scaleEdit = edits[3]
assert(scaleEdit.text == "0.90")
scaleEdit:SetFocus()
scaleEdit.text = "0,85"
scaleEdit.scripts.OnEnterPressed(scaleEdit)
assert(math.abs(settings.compact.bars.scale - 0.85) < 1e-9, "comma decimal accepted")
assert(scaleEdit.text == "0.85" and not scaleEdit.focus)
scaleEdit:SetFocus()
scaleEdit.text = "1.7"
scaleEdit:ClearFocus()
assert(scaleEdit.text == "0.85" and math.abs(settings.compact.bars.scale - 0.85) < 1e-9, "focus loss reverts, no save")
scaleEdit:SetFocus()
scaleEdit.text = "9"
scaleEdit.scripts.OnEnterPressed(scaleEdit)
local status
for _, f in ipairs(created) do
    if f.kind == "FontString" and f.text and f.text:find("Enter a value from 0.5 to 2", 1, true) and f:IsVisible() then status = f end
end
assert(status, "out-of-range value explains the range")
-- A live state repaint keeps the message for a few seconds.
api.RefreshOptions()
assert(status.text:find("Enter a value", 1, true), "message survives a repaint")
now = now + 6
api.RefreshOptions()
assert(not status.text:find("Enter a value", 1, true), "message expires")
-- Tab moves to the next field after applying.
local yEdit = edits[2]
yEdit:SetFocus()
yEdit.text = "-40"
yEdit.scripts.OnTabPressed(yEdit)
assert(settings.compact.bars.y == -40 and scaleEdit.focus and not yEdit.focus)
scaleEdit:ClearFocus()
print("PASS: comma decimals, Enter/Tab apply, focus loss reverts, range message stays briefly")

-- Class tabs: the prompt row names the tab's own button combination.
click("Pet spells")
local label
for _, f in ipairs(created) do
    if f.kind == "FontString" and f.text and f.text:find("^Button prompt") and f:IsVisible() then label = f end
end
assert(label and label.text == "Button prompt (RB + RT)", tostring(label and label.text))
click("Pet menu")
assert(label.text == "Button prompt (LB + LT)")
print("PASS: prompt row follows the selected class button")

-- The edited layout always follows Blizzard's setting; no "not in use" state.
state.mode, state.compact = "standard", false
api.RefreshOptions()
assert(find("Standard  ·  in use") and find("LT") and not find("Action bars"))
for _, f in ipairs(created) do
    assert(not (f.kind == "FontString" and f.text and f.text:find("Not in use", 1, true)), "no orange not-in-use hint")
end
local standardButton = find("Standard  ·  in use")
assert(standardButton.attributes.macrotext == "/editmode" and standardButton.attributes.type == "")
assert(find("Compact").attributes.type == "macro", "the mode not in use opens Edit Mode")
state.mode, state.compact = "compact", true
api.RefreshOptions()
click("Pet menu")
print("PASS: Compact/Standard follow Blizzard's setting and carry its /console command")

-- Style B: Legacy chrome, same settings, editing stays on while switching.
click("B")
assert(settings.optionsStyle == "B" and window:IsShown() and editing, "switching keeps the window open")
assert(window.width == 588 and window.height == 582)
assert(find("Pet menu") and find("Reset Pet menu"), "selection carries over")
assert(#visibleEdits() == 3, "class tab shows x, y and scale in style B too")
print("PASS: style B switches in place with the Legacy window size")

-- Style A: arrows and step sizes, no typing.
click("A")
assert(settings.optionsStyle == "A" and window.width == 588 and window.height == 628)
assert(#visibleEdits() == 0, "style A has no text entry")
click("Action bars")
local arrows = {}
for _, f in ipairs(created) do
    if f.kind == "Button" and f:IsVisible() and f.tipTitle and f.tipTitle:find("^Move ") then arrows[f.tipTitle] = f end
end
assert(arrows["Move up"] and arrows["Move down"] and arrows["Move left"] and arrows["Move right"])
local y = settings.compact.bars.y
arrows["Move up"].scripts.OnClick(arrows["Move up"])
assert(settings.compact.bars.y == y + 10, "default step is 10")
click("1")
arrows["Move left"].scripts.OnClick(arrows["Move left"])
assert(settings.compact.bars.x == -1)
click("50")
local scale = settings.compact.bars.scale
local plus
for _, f in ipairs(created) do
    if f.kind == "Button" and f:IsVisible() and f.tipTitle == "Scale" and f.label.text == "+" then plus = f end
end
plus.scripts.OnClick(plus)
assert(math.abs(settings.compact.bars.scale - (scale + 0.10)) < 1e-9, "large step changes scale by 0.10")
-- Arrows are disabled when the bars are unavailable.
state.available = false
api.RefreshOptions()
assert(not arrows["Move up"].enabled)
state.available = true
api.RefreshOptions()
assert(arrows["Move up"].enabled)
print("PASS: style A nudges by the chosen step, scales by the matching step and disables when unavailable")

-- Back to A through the slash command path; the choice survives normalization.
api.SelectOptionsStyle("C")
assert(window.width == 560 and settings.optionsStyle == "C")
-- Saves from before the A/C swap keep the look they had: old C (controller) is now A.
assert(M.Normalize({ optionsStyle = "C" }).optionsStyle == "A")
assert(M.Normalize({ optionsStyle = "B" }).optionsStyle == "B")
assert(M.Normalize({ optionsStyle = "C", optionsStyleVersion = 2 }).optionsStyle == "C")
assert(M.Normalize({ optionsStyle = "Z" }).optionsStyle == "A" and M.Normalize().optionsStyle == "A")
assert(M.Normalize(M.Normalize({ optionsStyle = "C", optionsStyleVersion = 2 })).optionsStyle == "C", "stable after saving")
print("PASS: style selection by API, A/C swap migration and saved-value validation")

-- Help follows the style and registers too.
api.ToggleHelp()
assert(GamepadCompanionHelp:IsShown() and registered[GamepadCompanionHelp])
assert(find("Window styles") and find("Commands"))
api.ToggleHelp()
window:Hide()
assert(not editing)
print("PASS: help window style, registration and close lifecycle")
