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
local haloListeners = {}
Halo = { On = function(kind, fn) haloListeners[kind] = haloListeners[kind] or {}; table.insert(haloListeners[kind], fn) end }
local function HaloFire(kind, ...) for _, fn in ipairs(haloListeners[kind] or {}) do fn(...) end end
for _, file in ipairs({ "Model.lua", "Shared.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "Haptics.lua", "Timing.lua", "Volume.lua",
    "HapticsLab.lua", "HelperLink.lua", "LightPresets.lua", "Lights.lua", "HelperCues.lua", "HapticsDebug.lua", "HapticsUI.lua", "LightPicker.lua", "SpellOverrides.lua", "RumblePage.lua", "SetupPage.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local V = ns.Rumble
-- Your spells: the rules' answer and the spellbook, stood in for (the rules land in Rumble.lua)
local PLANS = {
    [133] = { moment = "spell", when = "cast", set = "subtle" },
    [143] = { moment = "spell", when = "cast", set = "subtle" },
    [122] = { moment = "instant", when = "cast", feel = "strike", guess = true },
    [139] = { moment = "quiet", when = "none" },
    [6603] = { moment = "autoAttack", when = "hit" },
}
V.SpellPlan = function(id)
    local p = PLANS[id]
    if not p then return nil end
    local o = ns.SpellOverrides.Get(({ [133] = "Fireball", [143] = "Fireball", [122] = "Frost Nova", [139] = "Renew", [6603] = "Attack" })[id])
    local plan = {}
    for k, v in pairs(p) do plan[k] = v end
    if o and o.set then plan.set = o.set end
    if o and o.feel then plan.feel = o.feel end
    return plan
end
ns.Picker = { SpellLines = function()
    return { { name = "Fire", list = { { spell = 133, name = "Fireball" }, { spell = 143, name = "Fireball" },
        { spell = 122, name = "Frost Nova" }, { spell = 139, name = "Renew" } } },
        { name = "General", list = { { spell = 6603, name = "Attack" } } } }
end }
for _, f in ipairs(created) do
    if f.events and f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end

-- (the original engine's path: the Beta engine off)
ns.Haptics.DB().engine = false

-- Engine -----------------------------------------------------------------------------
local s = V.Settings()
assert(s.enabled == true and math.abs(s.intensity - 0.8) < 1e-9, "on, 80%")
assert(GamepadCompanionCharDB.vibration == s, "settings in the character's profile")
assert(V.EventChoice("levelUp") == "rise" and V.EventChoice("jump") == "off", "the original's defaults")
assert(V.CastPreset("spell") == "auto", "casts match the action")
assert(#V.PATTERNS >= 48 and #V.RAIL == 18, "every pattern and event: " .. #V.PATTERNS .. ", " .. #V.RAIL)
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
-- Halo's rings: open, slot change, fire, close
for _, f in ipairs(created) do
    if f.events and f.events.PLAYER_LOGIN and f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
end
assert(haloListeners.open and haloListeners.pick and haloListeners.close, "listens to Halo")
local played = {}
local realPlay = V.Play
V.Play = function(key, ...) played[#played + 1] = key; return realPlay(key, ...) end
now = now + 1; HaloFire("open", 1)
now = now + 1; HaloFire("pick", 2)
now = now + 1; HaloFire("close", 1, 2)
now = now + 1; HaloFire("close", 1, nil)
assert(table.concat(played, ",") == "tick,micro,pulse", "open, slot, fire; close off by default: " .. table.concat(played, ","))
V.SetEventPattern("haloClose", "fade")
now = now + 1; HaloFire("close", 1, nil)
assert(played[4] == "fade", "close the ring")
V.Play = realPlay
io.write("PASS: engine ported: profile settings, defaults, events, off beside the original, Halo rings\n")

-- Page -------------------------------------------------------------------------------
ns.Shell.Open("rumble")
local window, tabs = ns.ShellWindow()
assert(window:IsShown() and ns.Shell.Current() == "moments" and tabs.moments, "Moments tab (from its old key)")
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
-- Rows by key, groups down the left
local page = ns.RumblePage
local rowFor = {}
local FEEL = { r = true, c = true, l = true }
for _, f in ipairs(created) do if FEEL[rawget(f, "kind")] and rawget(f, "pick") then rowFor[f.key] = f end end
assert(rowFor.levelUp and rowFor.hit and rowFor.gather and rowFor.rain, "Rumble's, the Beta engine's and the cast sets' rows")
assert(rowFor.wading and rowFor.footsteps, "Wading has its own row and switch beside Footsteps")
page.browser.Select("Progress")
local level = rowFor.levelUp
assert(level:IsVisible() and level.pick.label.text == "Crescendo", tostring(level.pick.label.text))
-- the palette: Off first
level.pick.scripts.OnClick(level.pick)
local pal = GamepadCompanionPalette
assert(pal and pal:IsShown(), "the palette")
local off = pal.pal.specialTiles[1]
off.scripts.OnClick(off, "LeftButton")
assert(not pal:IsShown() and V.EventChoice("levelUp") == "off" and level.pick.label.text == "Off", "set off")
-- Default: back to Crescendo
level.default.scripts.OnClick(level.default)
assert(V.EventChoice("levelUp") == "rise" and level.pick.label.text == "Crescendo", "default")
-- a Beta feel on a Rumble event (any feel of the palette)
level.pick.scripts.OnClick(level.pick)
pal.pal:ShowGroup("Impacts")
local boom
for _, t in ipairs(pal.pal.tiles) do if t:IsShown() and t.key == "boom" then boom = t end end
boom.scripts.OnClick(boom, "LeftButton")
assert(V.EventChoice("levelUp") == "x_boom", "Boom on level up: " .. tostring(V.EventChoice("levelUp")))
level.default.scripts.OnClick(level.default)
-- the cast sets: their own grid
page.browser.Select("Abilities")
local gather = rowFor.gather
gather.pick.scripts.OnClick(gather.pick)
local grid = GamepadCompanionBetaFeels
local pulse
for _, t in ipairs(grid.tiles) do if t.label.text == "Pulse" and t:IsShown() then pulse = t end end
pulse.scripts.OnClick(pulse)
assert(V.CastPreset("gather") == "pulse" and gather.pick.label.text == "Pulse", "gathering: the Pulse set")
assert(gather.sub.text:find("Pulse", 1, true), "its moments shown")
-- Off, and the other addon
local enable
for _, f in ipairs(created) do if f.kind == "CheckButton" and f:IsVisible() and f.label and f.label.text == "On" then enable = f end end
enable.checked = false
enable.scripts.OnClick(enable)
assert(V.Settings().enabled == false and not V.Active(), "switched off")
enable.checked = true
enable.scripts.OnClick(enable)
otherLoaded = true
ns.Shell.Refresh()
assert(not enable.enabled and not enable.checked, "the other addon has the motors")
otherLoaded = false
io.write("PASS: Rumble page: strength, groups, the palette (Off, Default, a Beta feel), cast sets, on / off, beside the original\n")
-- Your spells: after Abilities, one row a name, the plate by the spell's moment, Off, Default, volume
do
    local O, sp = ns.SpellOverrides, page.spells
    assert(page.browser.buttons.spells, "Your spells group")
    page.browser.Select("spells")
    ns.Shell.Refresh()
    local shown = {}
    for _, r in ipairs(sp.rows) do if r:IsShown() then shown[#shown + 1] = r end end
    assert(#shown == 3, "Fireball once (ranks share a name), Frost Nova, Renew: " .. #shown)
    local fire, nova, renew = shown[1], shown[2], shown[3]
    assert(fire.label.text == "Fireball" and fire.pick.label.text == "Subtle" and fire.sub.text == "At the cast", "a cast set")
    assert(nova.sub.text == "At the cast", "when only: " .. tostring(nova.sub.text))
    assert(renew.pick.label.text == "None" and renew.default.enabled == false, "quiet: None, nothing to undo")
    -- a cast set of its own, then Off, then Default
    fire.pick.scripts.OnClick(fire.pick)
    local pop = GamepadCompanionBetaFeels
    local function tile(label) for _, t in ipairs(pop.tiles) do if t:IsShown() and t.label.text == label then return t end end end
    tile("Pulse").scripts.OnClick(tile("Pulse"))
    assert(O.Get("Fireball").set == "pulse" and fire.pick.label.text == "Pulse" and fire.default.enabled ~= false, "its own set")
    fire.pick.scripts.OnClick(fire.pick)
    tile("Off").scripts.OnClick(tile("Off"))
    assert(O.Get("Fireball").on == false and fire.pick.label.text == "Off", "Off")
    fire.level.minus.scripts.OnClick(fire.level.minus)
    assert(math.abs(O.Volume("Fireball") - 0.9) < 1e-9, "its volume")
    fire.default.scripts.OnClick(fire.default)
    assert(O.Get("Fireball") == nil and fire.pick.label.text == "Subtle" and fire.default.enabled == false, "Default: the rules")
    -- the General tab: Attack belongs to Auto attack, a link
    sp.tabs[2].scripts.OnClick(sp.tabs[2])
    local attack = sp.rows[1]
    assert(attack.pick.label.text == "Auto attack ›" and not attack.level:IsShown(), "a link to its moment")
    attack.pick.scripts.OnClick(attack.pick)
    assert(page.browser.current == "Attacks", "jumped to Auto attack")
    io.write("PASS: Your spells: a row a name, cast set / feel / link by moment, Off, volume, Default\n")
end
