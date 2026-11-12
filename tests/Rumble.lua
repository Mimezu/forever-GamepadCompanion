-- The Rumble page and the ported engine: settings, events, the pattern grid.
-- lua5.1 tests/Rumble.lua <addon folder>
local root = arg[1] or "."
local ns = {}
local combat, now = false, 100
local created, registered, calls = {}, {}, {}
local methods = {}
local function new(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, shown = true, points = {},
        attributes = {}, enabled = true }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") and not key:match("^C_") and not key:match("^[A-Z_]+$") then return function() end end
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
NineSliceUtil = { ApplyLayoutByName = function(frame, layout) frame.nineslice = layout end }
C_Texture = { GetAtlasInfo = function() return { file = 1, width = 64, height = 64, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 } end }

-- Game ----------------------------------------------------------------------------
local vib, otherLoaded = {}, false
function methods:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
function methods:RegisterUnitEvent(e) self.events = self.events or {}; self.events[e] = true end
function methods:SetDesaturated(v) self.desaturated = v end
function methods:SetTexture(t) self.texture = t end
function methods:SetAlpha(a) self.alpha = a end
local timers = {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTimer = function(_, fn) local t = { fn = fn, Cancel = function(self) self.cancelled = true end }; timers[#timers + 1] = t; return t end,
}
local function RunTimers()
    local list = timers; timers = {}
    for _, t in ipairs(list) do
        if type(t) == "function" then t() elseif not t.cancelled then t.fn() end
    end
end
C_GamePad = {
    SetVibration = function(motor, v) vib[#vib + 1] = { motor, v } end,
    StopVibration = function() vib[#vib + 1] = { "stop" } end,
}
C_AddOns = { IsAddOnLoaded = function(name) return name == "ImprovedForever_Vibration" and otherLoaded end }
function hooksecurefunc() end
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
format = string.format
function print() end
UnitRace = function() return "Human", "Human", 1 end
UnitSex = function() return 2 end
GetSpellInfo = function(id) return "Spell " .. tostring(id) end
LowHealthFrame, FrameGambitAPI, SettingsPanel, SOUNDKIT, GAMEPAD_MOD_LEFT = false, false, false, false, "SHIFT"
-- (any other game function: a no-op)
setmetatable(_G, { __index = function(_, key)
    if type(key) == "string" and key:match("^%u") and not key:match("^C_") and not key:match("^[A-Z_]+$") then return function() end end
end })

local settings = { optionsStyle = "A" }
GamepadCompanionAPI = { GetSettings = function() return settings end, GetCapabilities = function() return {} end }
local API = GamepadCompanionAPI
GamepadCompanionCharDB = nil
for _, file in ipairs({ "Model.lua", "Shared.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "RumblePage.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local V = ns.Rumble
for _, f in ipairs(created) do
    if f.events and f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end

-- Engine -----------------------------------------------------------------------------
local s = V.Settings()
assert(s.enabled == true and math.abs(s.intensity - 0.8) < 1e-9, "on, 80%")
assert(GamepadCompanionCharDB.vibration == s, "settings in the character's profile")
assert(V.EventChoice("levelUp") == "rise" and V.EventChoice("jump") == "off", "the original's defaults")
assert(V.CastPreset("spell") == "auto", "casts match the action")
assert(#V.PATTERNS >= 48 and #V.RAIL == 15, "every pattern and event: " .. #V.PATTERNS .. ", " .. #V.RAIL)
assert(V.Active(), "active")
V.Fire("levelUp")
RunTimers()
assert(#vib > 0, "level up rumbles")
vib = {}
otherLoaded = true
assert(not V.Active(), "Improved Forever: Vibration loaded: Companion stays off")
V.Fire("levelUp")
RunTimers()
assert(#vib == 0, "no double rumble")
otherLoaded = false
print_ = nil
io.write("PASS: engine ported: profile settings, defaults, events, off beside the original\n")

-- Page -------------------------------------------------------------------------------
ns.Shell.Open("rumble")
local window, tabs = ns.ShellWindow()
assert(window:IsShown() and ns.Shell.Current() == "rumble" and tabs.rumble, "Rumble tab")
local strength
for _, f in ipairs(created) do if f.kind == "FontString" and f.text == "80%" and f:IsVisible() then strength = f end end
assert(strength, "strength shown")
local function button(label)
    for _, f in ipairs(created) do
        if type(rawget(f, "label")) == "table" and f.label.text == label and f:IsVisible() then return f end
    end
end
button("+").scripts.OnClick(button("+"))
assert(math.abs(V.Settings().intensity - 0.9) < 1e-9 and strength.text == "90%", "stronger")
-- Each row: its choice; the grid chooses
local rowFor = {}
for _, f in ipairs(created) do if rawget(f, "rail") then rowFor[f.rail.key] = f end end
local level = rowFor.levelUp
assert(level and level.pick.label.text == "Crescendo", tostring(level and level.pick.label.text))
level.pick.scripts.OnClick(level.pick)
local grid = GamepadCompanionRumbleChoices
assert(grid and grid:IsShown(), "pattern grid")
local off
for _, t in ipairs(grid.tiles) do if t.entry and t.entry.action == "off" then off = t end end
off.scripts.OnClick(off)
assert(not grid:IsShown() and V.EventChoice("levelUp") == "off" and level.pick.label.text == "Off", "set off")
local gather = rowFor.cast_gather
gather.pick.scripts.OnClick(gather.pick)
local pulse
for _, t in ipairs(grid.tiles) do if t.entry and t.entry.action == "pulse" and t:IsShown() then pulse = t end end
pulse.scripts.OnClick(pulse)
assert(V.CastPreset("gather") == "pulse" and gather.pick.label.text == "Pulse", "gathering: the Pulse set")
assert(gather.choice.text:find("Casting: Pulse", 1, true), "its moments shown")
-- Off, and the other addon
local enable
for _, f in ipairs(created) do if f.kind == "CheckButton" and f:IsVisible() then enable = f end end
enable.checked = false
enable.scripts.OnClick(enable)
assert(V.Settings().enabled == false and not V.Active(), "switched off")
enable.checked = true
enable.scripts.OnClick(enable)
otherLoaded = true
ns.Shell.Refresh()
assert(not enable.enabled and not enable.checked, "the other addon has the motors")
otherLoaded = false
io.write("PASS: Rumble page: strength, pattern grid, cast sets, on / off, beside the original\n")
