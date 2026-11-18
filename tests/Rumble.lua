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
for _, file in ipairs({ "Model.lua", "Shared.lua", "When.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "Haptics.lua", "Timing.lua", "Volume.lua",
    "HapticsLab.lua", "HelperLink.lua", "Stack.lua", "Hush.lua", "LightPresets.lua", "Lights.lua", "HelperCues.lua", "HapticsDebug.lua", "HapticsUI.lua", "LightPicker.lua", "SpellOverrides.lua", "RumblePage.lua", "LearnedPage.lua", "SetupPage.lua" }) do
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
    local name = ({ [133] = "Fireball", [143] = "Fireball", [122] = "Frost Nova", [139] = "Renew", [6603] = "Attack" })[id]
    local o = ns.SpellOverrides.Get(name)
    local plan = {}
    for k, v in pairs(p) do plan[k] = v end
    plan.ruleSet, plan.ruleFeel = p.set, p.feel
    -- (its light and sound: a moment of its own under Spell released or Instant ability)
    plan.base = p.moment == "spell" and "release" or (p.moment == "instant" or p.moment == "quiet") and "instant" or nil
    plan.key = plan.base and ns.SpellOverrides.Key(plan.base, name) or nil
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
-- the cast sets: the Feel picker every moment opens, its sets on top, any feel below
-- (a tile of the palette by its label, in whichever group it is: the special row first)
function PaletteTile(label)
    local p = GamepadCompanionPalette.pal
    for _, t in ipairs(p.specialTiles) do if t:IsShown() and t.label.text == label then return t end end
    for _, g in ipairs(p.groups) do
        p:ShowGroup(g)
        for _, t in ipairs(p.tiles) do if t:IsShown() and t.label.text == label then return t end end
    end
end
page.browser.Select("Abilities")
local gather = rowFor.gather
gather.pick.scripts.OnClick(gather.pick)
assert(GamepadCompanionPalette:IsShown() and PaletteTile("Match the action") and PaletteTile("Alerts only"), "the palette, the sets on top")
local pulse = PaletteTile("Pulse")
pulse.scripts.OnClick(pulse, "LeftButton")
assert(V.CastPreset("gather") == "feel:pulse" and gather.pick.label.text == "Pulse", "gathering: Pulse while casting: " .. tostring(V.CastPreset("gather")))
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
    assert(renew.pick.label.text == "Off" and renew.default.enabled == false, "quiet: Off, as the picker says, nothing to undo")
    assert(not renew.level:IsShown() and not renew.try:IsShown(), "nothing plays: no volume, no Try")
    renew.pick.scripts.OnClick(renew.pick)
    assert(GamepadCompanionPalette.current == "off", "its picker opens on Off")
    PaletteTile("Off").scripts.OnClick(PaletteTile("Off"), "LeftButton")
    assert(O.Get("Renew") == nil and renew.default.enabled == false, "Off again: still as it ships")
    -- a cast set of its own (any feel, in the same picker), then Off, then Default
    fire.pick.scripts.OnClick(fire.pick)
    assert(GamepadCompanionPalette:IsShown() and GamepadCompanionPalette.current == "subtle", "the Feel picker, its set selected")
    PaletteTile("Pulse").scripts.OnClick(PaletteTile("Pulse"), "LeftButton")
    assert(O.Get("Fireball").set == "feel:pulse" and fire.pick.label.text == "Pulse" and fire.default.enabled ~= false, "its own feel while casting")
    -- (the volume chip opens its slider)
    fire.level.scripts.OnClick(fire.level)
    local pop = ns.HapticsUI.LevelPop()
    pop.stepper.minus.scripts.OnClick(pop.stepper.minus)
    pop:Hide()
    assert(math.abs(O.Volume("Fireball") - 0.9) < 1e-9, "its volume")
    fire.pick.scripts.OnClick(fire.pick)
    PaletteTile("Off").scripts.OnClick(PaletteTile("Off"), "LeftButton")
    assert(O.Get("Fireball").on == false and fire.pick.label.text == "Off" and not fire.level:IsShown(), "Off: no volume")
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
-- Your spells follow Feel / Light / Sound like every group: the spell's own light and sound
-- (the same picker and popup as any moment's), in its overrides, Default per kind, the count
do
    local O, sp, K = ns.SpellOverrides, page.spells, ns.HelperLink
    local count = page.browser.buttons.spells.count
    page.SetKind("feel")
    page.browser.Select("spells")
    sp.tabs[1].scripts.OnClick(sp.tabs[1])
    local function rows()
        local t = {}
        for _, r in ipairs(sp.rows) do if r:IsShown() then t[#t + 1] = r end end
        return t
    end
    local fire, nova, renew = rows()[1], rows()[2], rows()[3]
    local novaFeel = nova.pick.label.text
    assert(novaFeel ~= "Off" and nova.level:IsShown(), "Feel: Frost Nova's feel, its volume")
    assert(count.text == "3/4", "Feel: on of all, as every group: " .. tostring(count.text))
    -- Light: each row the spell's own light, its parent's until it has one
    page.SetKind("light")
    assert(fire.pick.label.text == "Spell released" and fire.sub.text == "When released", "Fireball: Spell released's light: " .. tostring(fire.pick.label.text))
    assert(nova.pick.label.text == "Off" and nova.default.enabled == false, "Frost Nova: Instant ability's light (off), nothing to undo")
    assert(not nova.level:IsShown(), "a light's strength is in its picker")
    assert(count.text == "1/4", "Light: the count follows the kind: " .. tostring(count.text))
    nova.pick.scripts.OnClick(nova.pick)
    local lp = GamepadCompanionLightPicker
    assert(lp and lp:IsShown() and lp.title.text == "Frost Nova", "the light picker, for the spell")
    local flash
    for _, t in ipairs(lp.tiles) do if t:IsShown() and t.label.text == "Flash" then flash = t end end
    flash.scripts.OnClick(flash)
    local red
    for _, sw in ipairs(lp.swatches) do if sw.key == "red" and sw:IsShown() then red = sw end end
    red.scripts.OnClick(red)
    lp:Hide()
    local own = O.Get("Frost Nova").light
    assert(own and own.on == true and own.color == "red" and own.light == ns.Lights.LightByKey("flash").id, "its own light, in its overrides")
    assert(ns.Lights.IsDefault("instant") and ns.Lights.Settings("instant").on == false, "Instant ability's own light untouched")
    page.Refresh()
    assert(nova.pick.label.text == "Flash" and nova.default.enabled ~= false and count.text == "2/4", "shown, Default to undo, counted")
    -- Feel again: the feel rows, the feel's Default untouched by the light
    page.SetKind("feel")
    assert(nova.pick.label.text == novaFeel and nova.default.enabled == false, "Feel: its feel again; the light is not the feel's")
    -- Sound: a sound for the spell on the pad's speaker, its volume
    page.SetKind("sound")
    assert(nova.pick.label.text == "Off" and not nova.level:IsShown() and not nova.try:IsShown() and count.text == "0/4",
        "Sound: none yet; nothing plays: no volume, no Try")
    nova.pick.scripts.OnClick(nova.pick)
    local chime
    for _, t in ipairs(GamepadCompanionBetaFeels.tiles) do if t:IsShown() and t.label.text == "Chime" then chime = t end end
    chime.scripts.OnClick(chime)
    assert(O.Field("Frost Nova", "sound") == K.SOUNDS.chime and nova.pick.label.text == "Chime" and nova.level:IsShown(), "its own sound, its volume")
    assert(ns.HelperCues.MomentSound("instant") == nil, "Instant ability's sound untouched")
    -- (the volume chip opens its slider)
    nova.level.scripts.OnClick(nova.level)
    local pop = ns.HapticsUI.LevelPop()
    pop.stepper.minus.scripts.OnClick(pop.stepper.minus)
    pop:Hide()
    assert(math.abs(O.Field("Frost Nova", "soundVolume") - 0.9) < 1e-9 and O.Volume("Frost Nova") == 1, "its sound's volume, not the feel's")
    assert(count.text == "1/4", "counted: " .. tostring(count.text))
    -- Default, by kind: the sound (and its volume) only, then the light
    nova.default.scripts.OnClick(nova.default)
    assert(O.Field("Frost Nova", "sound") == nil and O.Field("Frost Nova", "soundVolume") == nil and O.Get("Frost Nova").light, "Default: its sound only")
    page.SetKind("light")
    nova.default.scripts.OnClick(nova.default)
    assert(O.Get("Frost Nova") == nil and nova.pick.label.text == "Off", "Default: its light, nothing left")
    -- a linked spell: its moment's light or sound, a link
    page.SetKind("sound")
    sp.tabs[2].scripts.OnClick(sp.tabs[2])
    local attack = sp.rows[1]
    assert(attack.pick.label.text == "Off ›" and attack.sub.text == "With Auto attack" and not attack.level:IsShown(), "Attack: Auto attack's sound, a link")
    attack.pick.scripts.OnClick(attack.pick)
    assert(page.kind == "sound" and page.browser.current == "Attacks", "jumped to Auto attack's sound")
    page.SetKind("feel")
    io.write("PASS: Your spells follow Feel / Light / Sound: own light and sound (same picker), in its overrides, Default per kind, the count\n")
end
-- Every row opens its kind's one picker: Feel the palette, Light the light picker, Sound the
-- sound list; every moment's group and Your spells (every tab), cast sets and heals alike
do
    local FRAME = { feel = "GamepadCompanionPalette", light = "GamepadCompanionLightPicker", sound = "GamepadCompanionBetaFeels" }
    local function hideAll() for _, n in pairs(FRAME) do if _G[n] then _G[n]:Hide() end end end
    local opened = 0
    for _, kind in ipairs({ "feel", "light", "sound" }) do
        page.SetKind(kind)
        for _, g in ipairs(page.GROUPS) do
            page.browser.Select(g.key)
            for _, r in ipairs(page.rows) do
                if r:IsVisible() then
                    hideAll()
                    r.pick.scripts.OnClick(r.pick)
                    for k, n in pairs(FRAME) do
                        assert((_G[n] and _G[n]:IsShown() or false) == (k == kind), kind .. " " .. r.key .. ": the " .. kind .. " picker, only it")
                    end
                    opened = opened + 1
                end
            end
        end
        page.browser.Select("spells")
        for i = 1, #page.spells.lines do
            page.spells.tabs[i].scripts.OnClick(page.spells.tabs[i])
            for _, r in ipairs(page.spells.rows) do
                if r:IsShown() and r.plan and not r.linked and (r.plan.moment == "spell" or r.plan.moment == "instant" or r.plan.moment == "quiet") then
                    hideAll()
                    r.pick.scripts.OnClick(r.pick)
                    for k, n in pairs(FRAME) do
                        assert((_G[n] and _G[n]:IsShown() or false) == (k == kind), kind .. " " .. r.plan.name .. ": the " .. kind .. " picker, only it")
                    end
                    opened = opened + 1
                end
            end
        end
    end
    hideAll()
    page.SetKind("feel")
    assert(opened > 60, "every row tried: " .. opened)
    io.write("PASS: every row opens its kind's one picker (" .. opened .. " rows)\n")
end
-- Every feel the picker offers has an icon, and the addon's own icon files exist
do
    local missing = {}
    for _, feel in ipairs(ns.Haptics.AllFeels()) do
        local icon = feel.icon
        if type(icon) ~= "string" or icon == "" then
            missing[#missing + 1] = feel.key .. " (none)"
        else
            local rel = icon:match("^Interface\\AddOns\\GamepadCompanion\\(.+)$")
            if rel then
                rel = rel:gsub("\\", "/")
                local found = false
                for _, ext in ipairs({ "", ".tga", ".blp", ".png" }) do
                    local fh = io.open(root .. "/" .. rel .. ext, "rb")
                    if fh then fh:close(); found = true; break end
                end
                if not found then missing[#missing + 1] = feel.key .. " (" .. rel .. ")" end
            end
        end
    end
    assert(#missing == 0, "feels with no icon: " .. table.concat(missing, ", "))
    io.write("PASS: every feel in the picker has its icon (" .. #ns.Haptics.AllFeels() .. " feels)\n")
end
-- One meaning of Default (design audit phase 1): a row's Default is Recommended for the class,
-- the same as the profile's Reset (hit, miss, dodges, parries, hitTaken, combo, oom... agreed)
do
    assert(loadfile(root .. "/Profiles.lua"))("GamepadCompanion", ns)
    local P, L = ns.Profiles, ns.HapticsLab
    local n = 0
    for _, class in ipairs({ "PALADIN", "ROGUE", "HUNTER" }) do
        P.state.class = class
        local rec = P.Recommended(class)
        for key, r in pairs(rec.events) do
            local s = L.EventSettings(key)
            s.on = not r.on
            assert(not L.IsEventDefault(key), class .. " " .. key .. ": not Recommended, Default lit")
            L.EventDefault(key)
            assert(L.EventSettings(key).on == r.on and L.IsEventDefault(key), class .. " " .. key .. ": Default = the profile's Reset")
            n = n + 1
        end
        for key, r in pairs(rec.vibration.events) do
            V.Settings().events[key].on = not r.on
            assert(not V.IsEventDefault(key), class .. " " .. key .. ": not Recommended")
            V.EventDefault(key)
            assert(V.Settings().events[key].on == r.on and V.IsEventDefault(key), class .. " " .. key .. ": Default = Reset")
            n = n + 1
        end
    end
    -- the row says so: Hit after Default is off and its Default greyed
    P.state.class = "PALADIN"
    page.SetKind("feel")
    page.browser.Select("Attacks")
    local hit
    for _, r in ipairs(page.rows) do if r.key == "hit" and r:IsVisible() then hit = r end end
    L.EventSettings("hit").on = true
    page.Refresh()
    assert(hit.default.enabled ~= false, "Hit on: not Recommended")
    hit.default.scripts.OnClick(hit.default)
    assert(L.EventSettings("hit").on == false and hit.default.enabled == false and hit.pick.label.text == "Off", "Hit's Default: Off, as Recommended")
    local offer = ns.ShellWindow().offer
    assert(offer.label.text == "Undo", "Undo for a while")
    offer.scripts.OnClick(offer)
    assert(L.EventSettings("hit").on == true, "Undo: on again")
    for key in pairs(P.RECOMMENDED.events) do L.EventDefault(key) end
    P.state.class = nil
    for key in pairs(P.RECOMMENDED.events) do L.EventDefault(key) end
    io.write("PASS: one Default: a row's Default is Recommended, as the profile's Reset (" .. n .. " checks)\n")
end
-- A cast's cue goes as its kind's moment (Spell casting 22, Gathering 23, Crafting 24), not as
-- "cast" (72); cancelled and pushback have numbers (76, 77); light-only moments have no sound row
do
    local C, K = ns.HelperCues, ns.HelperLink
    assert(C.MOMENT_N.cancelled == 76 and C.MOMENT_N.pushback == 77 and C.MOMENT_N.cast == 72 and C.MOMENT_N.halo == 75, "appended, none moved")
    local enabled, v2, cue = K.Enabled, K.V2, K.Cue
    local sent = {}
    K.Enabled, K.V2 = function() return true end, function() return true end
    K.Cue = function(item) sent[#sent + 1] = item.moment; return true end
    local Ksounds = C.Settings().sounds
    C.Settings().sounds = true
    C.SetMomentSound("spell", K.SOUNDS.chime)
    for _, kind in ipairs({ "spell", "gather", "craft" }) do
        V.castKind = kind
        sent = {}
        V.Fire("cast")
        assert(sent[1] == C.MOMENT_N[kind], kind .. ": its own number, not 72: " .. tostring(sent[1]))
    end
    V.castKind = "spell"
    for _, k in ipairs({ "cancelled", "pushback" }) do
        sent = {}
        C.SetMomentSound(k, K.SOUNDS.chime)
        V.Fire(k)
        assert(sent[1] == C.MOMENT_N[k], k .. ": its number: " .. tostring(sent[1]))
        C.SetMomentSound(k, nil)
    end
    C.SetMomentSound("spell", nil)
    -- a sound picked for "Casting" (72) once: Spell casting's now
    ns.Haptics.DB().link.sounds.cast = K.SOUNDS.coin
    assert(C.MomentSound("spell") == K.SOUNDS.coin and C.MomentSound("cast") == nil, "Casting's sound moved to Spell casting")
    C.SetMomentSound("spell", nil)
    C.Settings().sounds = Ksounds
    K.Enabled, K.V2, K.Cue = enabled, v2, cue
    -- the Sound view: no row for a light-only moment (Critical hit taken once, not twice)
    page.SetKind("sound")
    for _, g in ipairs(page.GROUPS) do
        page.browser.Select(g.key)
        local seen = {}
        for _, r in ipairs(page.rows) do
            if r:IsVisible() and r.kind == "sound" then
                assert(not C.LIGHT_ONLY[r.key], "a light-only moment's sound row: " .. r.key)
                local label = r.label:GetText()
                assert(not seen[label], g.key .. ": two sound rows named " .. tostring(label))
                seen[label] = true
            end
        end
    end
    page.SetKind("feel")
    io.write("PASS: casts as Spell casting / Gathering / Crafting; cancelled 76, pushback 77; no light-only sound rows\n")
end
-- N3: a gold dot on a changed row's name, a ring by its group's count, Reset group (Undo 5 s)
do
    local L = ns.HapticsLab
    page.SetKind("feel")
    page.browser.Select("Moving")
    local btn = page.browser.buttons.Moving
    local card = page.cards.Moving.feel
    local function row(key) for _, r in ipairs(page.rows) do if r.key == key and r:IsVisible() then return r end end end
    for _, item in ipairs(page.GROUPS[4].items) do if not page.IsRecommended(item[1], item[2]) then page.ResetGroup("Moving", "feel") break end end
    page.Refresh()
    local jump, land = row("jump"), row("landing")
    assert(not (jump.changed and jump.changed:IsShown()) and not (btn.ring and btn.ring:IsShown()), "as Recommended: no dot, no ring")
    assert(card.reset and card.reset.enabled == false, "Reset group greyed with nothing changed")
    V.SetEventPattern("jump", "pulse")
    L.EventSettings("landing").on = not L.DefaultOn("landing")
    page.Refresh()
    assert(jump.changed:IsShown() and land.changed:IsShown(), "changed: a gold dot on each")
    assert(btn.ring:IsShown() and btn.changed == 2 and card.reset.enabled ~= false, "the group's ring, Reset group lit")
    card.reset.scripts.OnClick(card.reset)
    assert(V.IsEventDefault("jump") and L.IsEventDefault("landing"), "Reset group: both Recommended")
    assert(not jump.changed:IsShown() and not btn.ring:IsShown(), "no dot, no ring")
    local offer = ns.ShellWindow().offer
    assert(offer.label.text == "Undo", "Undo for a while")
    offer.scripts.OnClick(offer)
    assert(V.EventChoice("jump") == "pulse" and not L.IsEventDefault("landing"), "Undo: both as they were")
    page.ResetGroup("Moving", "feel")
    io.write("PASS: N3: changed dot, the group's ring, Reset group with Undo\n")
end
-- N2: one Search above the groups: moments in every kind, spells, states; a result opens it
do
    local box, card = page.searchBox, page.searchCard
    local function Type(text) box:SetText(text); box.scripts.OnTextChanged(box) end
    local function Found(label, where)
        for _, b in ipairs(card.rows) do
            if b:IsShown() and b.label.text == label and (not where or b.where.text:find(where, 1, true)) then return b end
        end
    end
    page.SetKind("feel")
    Type("crit")
    assert(card:IsShown(), "results where the group goes")
    assert(Found("Critical hit: melee", "Attacks · Feel") and Found("Critical hit taken", "Defense · Feel"), "feel moments, their group in grey")
    assert(Found("Critical hit", "Attacks · Light") and Found("Critical hit: ranged", "Sound"), "and the other kinds")
    -- a click: its kind, its group, the results step aside
    local land = (Type("landing") or true) and Found("Landing", "Moving · Sound")
    assert(land, "Landing's sound")
    land.scripts.OnClick(land)
    assert(not card:IsShown() and page.kind == "sound" and page.browser.current == "Moving", "opened where it lives")
    -- a spell of yours, a state
    Type("fireball")
    local fb = Found("Fireball")
    assert(fb and fb.where.text:find("Your spells", 1, true), "your spells")
    fb.scripts.OnClick(fb)
    assert(page.browser.current == "spells", "Your spells, at its tab")
    local shown = false
    for _, r in ipairs(page.spells.rows) do if r:IsShown() and r.plan and r.plan.name == "Fireball" then shown = true end end
    assert(shown, "Fireball's row on the page shown")
    Type("zzzz no such")
    assert(card.none:IsShown(), "Nothing found")
    -- Enter opens the first; Escape clears
    Type("whisper")
    box.scripts.OnEnterPressed(box)
    assert(not card:IsShown() and page.browser.current == "Social", "Enter: the first result")
    box.scripts.OnEscapePressed(box)
    box.scripts.OnTextChanged(box)
    assert(box:GetText() == "" and not card:IsShown(), "Escape: cleared")
    -- states are found too
    local any = false
    for _, e in ipairs(page.SearchIndex()) do if e.where:find("States", 1, true) then any = true end end
    assert(any, "the States lists are searched")
    -- Ctrl+F: the field
    local ctrl = IsControlKeyDown
    IsControlKeyDown = function() return true end
    box:ClearFocus()
    assert(page.SearchKey("F"), "Ctrl+F handled")
    assert(box:HasFocus(), "Ctrl+F: in the search field")
    box:ClearFocus()
    IsControlKeyDown = ctrl
    page.SetKind("feel")
    io.write("PASS: N2: search over moments, kinds, spells, states; open, Enter, Escape, Ctrl+F\n")
end
-- N11: When chips: Low health, Heartbeat, Out of mana, Landing wait for levels kept as data
-- (When.lua), shown on the row, changed in a stepper with Default; Landing's range left Setup
do
    local Wh, L = ns.When, ns.HapticsLab
    assert(Wh.Get("lowHp", "below") == 0.35 and Wh.Get("heartbeat", "below") == 0.5 and Wh.Get("oom", "below") == 0.15
        and Wh.Get("landing", "soft") == L.LAND_MIN and Wh.Get("landing", "full") == L.LAND_MAX, "as they ship, from the data")
    page.SetKind("feel")
    page.browser.Select("Defense")
    local function row(key) for _, r in ipairs(page.rows) do if r.key == key and r:IsVisible() then return r end end end
    local low = row("lowHp")
    page.Refresh()
    assert(low.when and low.when.label.text == "When: below 35 %", "the chip: " .. tostring(low.when and low.when.label.text))
    -- the stepper: one step down, Default back
    low.when.scripts.OnClick(low.when)
    local pop = ns.HapticsUI.LevelPop()
    assert(pop:IsShown() and pop.title.text == "Low health · Below", "its stepper: " .. tostring(pop.title.text))
    assert(pop.note and pop.note.text ~= "", "U2-11: the hidden-health limit shown")
    pop.lv.set(0.25)
    assert(Wh.Get("lowHp", "below") == 0.25 and low.when.label.text == "When: below 25 %", "set: the chip says so")
    assert(low.changed and low.changed:IsShown() and low.default.enabled ~= false, "a changed When: the dot, Default lit")
    assert(ns.Haptics.DB().when.lowHp.below == 0.25, "saved in the Feel profile's when")
    -- the row's Default puts it back too (and Undo returns it)
    low.default.scripts.OnClick(low.default)
    assert(Wh.Get("lowHp", "below") == 0.35 and ns.Haptics.DB().when.lowHp == nil, "Default: as it ships, nothing saved")
    ns.ShellWindow().offer.scripts.OnClick(ns.ShellWindow().offer)
    assert(Wh.Get("lowHp", "below") == 0.25, "Undo: 25 % again")
    pop.default.scripts.OnClick(pop.default)
    assert(Wh.Get("lowHp", "below") == 0.35, "the stepper's Default")
    pop:Hide()
    -- low health plays below the level set, when health can be read
    local fired, ended = 0, 0
    local fire, endLoop = V.Fire, V.EndLoop
    V.Fire = function(k, ...) if k == "lowHp" then fired = fired + 1 end return fire(k, ...) end
    V.EndLoop = function(k, ...) if k == "lowHp" then ended = ended + 1 end return endLoop(k, ...) end
    local uh, um, ud = UnitHealth, UnitHealthMax, UnitIsDeadOrGhost
    local hp = 100
    UnitHealth, UnitHealthMax, UnitIsDeadOrGhost = function() return hp end, function() return 100 end, function() return false end
    -- (night 2 U2-1: Secret is Rumble's own local; a global "Secret" here is the catch-all's no-op, so
    -- calling it means the local wasn't in scope: in the game, an error on every health tick)
    rawset(_G, "Secret", function() error("U2-1: HealthNow called the global Secret") end)
    Wh.Set("lowHp", "below", 0.25)
    hp = 30; V.CheckLowHealth("UNIT_HEALTH")
    assert(fired == 0, "30 % with 25 % set: not yet")
    hp = 24; V.CheckLowHealth("UNIT_HEALTH")
    assert(fired == 1, "24 %: low health")
    local e0 = ended
    hp = 60; V.CheckLowHealth("UNIT_HEALTH")
    assert(ended == e0 + 1, "60 %: over")
    Wh.Set("lowHp", "below", nil)
    UnitHealth, UnitHealthMax, UnitIsDeadOrGhost = uh, um, ud
    rawset(_G, "Secret", nil)
    -- Landing: two knobs, which first, then its stepper; Soft stays under Full
    page.browser.Select("Moving")
    local land = row("landing")
    page.Refresh()
    assert(land.when.label.text == "When: soft 0.50 s · full 1.20 s", "two knobs: " .. land.when.label.text)
    Wh.Set("landing", "soft", 1.3)
    assert(ns.Haptics.DB().landMin == 1.3 and Wh.Get("landing", "full") >= 1.35 - 1e-9, "Soft over Full: Full moves up")
    Wh.Default("landing")
    assert(ns.Haptics.DB().landMin == nil and ns.Haptics.DB().landMax == nil, "Default: the old keys cleared")
    V.Fire, V.EndLoop = fire, endLoop
    -- the sound row of the same moment shows it too; a moment without a When has no chip
    page.SetKind("sound")
    page.browser.Select("Abilities")
    local oom = row("oom")
    page.Refresh()
    assert(oom and not oom.when, "U2-11: Out of mana's sound row: no second When (one setting, one place)")
    page.SetKind("feel")
    page.browser.Select("Attacks")
    assert(not row("hit").when, "Hit: no When")
    io.write("PASS: N11: When chips (low health, heartbeat, out of mana, landing), stepper, Default, Undo, profile\n")
end
-- Night review 2, U2-2 / U2-3: the palette's hover preview plays once, faint, only as Try would
-- (Feel on, no Improved Forever, not in a fight), and stops on leave, on hide and when a fight starts
do
    local H = ns.Haptics
    page.SetKind("feel")
    page.browser.Select("Attacks")
    local hit
    for _, r in ipairs(page.rows) do if r.key == "hit" and r:IsVisible() then hit = r end end
    hit.pick.scripts.OnClick(hit.pick)
    local pal = GamepadCompanionPalette
    assert(pal:IsShown(), "the palette")
    local rain = PaletteTile("Rain")
    assert(rain and H.Feel(rain.key).loop, "a looping feel's tile")
    local function hover(t) t.scripts.OnEnter(t); RunTimers() end
    hover(rain)
    assert(H.Playing("preview"), "hovered: it plays")
    rain.scripts.OnLeave(rain)
    assert(not H.Playing("preview"), "U2-2: left, the loop stops (it hummed until /reload)")
    hover(rain)
    pal:Hide()
    assert(not H.Playing("preview"), "U2-2: the palette closed, it stops")
    hit.pick.scripts.OnClick(hit.pick)
    rain = PaletteTile("Rain")
    V.Settings().enabled = false
    hover(rain)
    assert(not H.Playing("preview"), "U2-3: Feel off, no preview")
    V.Settings().enabled = true
    rain.scripts.OnLeave(rain)
    local icl = InCombatLockdown
    InCombatLockdown = function() return true end
    hover(rain)
    assert(not H.Playing("preview"), "U2-3: in a fight, no preview")
    InCombatLockdown = icl
    rain.scripts.OnLeave(rain)
    GamepadCompanionPalette:Hide()
    io.write("PASS: U2-2/U2-3: hover preview once, gated, stopped on leave and hide\n")
end
-- Night review 2, U2-4: an Undo belongs to its own change: a newer pick takes it away, and an old
-- snapshot never goes back over it
do
    local L = ns.HapticsLab
    page.SetKind("feel")
    page.browser.Select("Progress")
    local loot
    for _, r in ipairs(page.rows) do if r.key == "loot" and r:IsVisible() then loot = r end end
    L.EventSettings("loot").on, L.EventSettings("loot").feel = true, "chime"
    page.Refresh()
    loot.default.scripts.OnClick(loot.default)
    local offer = ns.ShellWindow().offer
    assert(offer:IsShown(), "Default: Undo offered")
    -- a new pick on the same row, within the 5 s
    loot.pick.scripts.OnClick(loot.pick)
    local pulse = PaletteTile("Pulse")
    pulse.scripts.OnClick(pulse, "LeftButton")
    local picked = L.EventSettings("loot").feel
    assert(picked ~= "chime", "the new pick: " .. tostring(picked))
    if offer:IsShown() then offer.scripts.OnClick(offer) end
    assert(L.EventSettings("loot").feel == picked, "U2-4: the old Undo didn't put chime back over the new pick")
    assert(not offer:IsShown(), "U2-4: that Undo is gone")
    -- a newer message takes it away too
    loot.default.scripts.OnClick(loot.default)
    assert(offer:IsShown(), "Undo again")
    ns.Shell.SetStatus("Something else", true)
    assert(not offer:IsShown(), "U2-4: a newer message, no Undo beside it")
    L.EventDefault("loot")
    io.write("PASS: U2-4: Undo goes with its own change and its message\n")
end
-- Night review 2, U2-8: the Feel tour stops: a fight, the window closing, the same button again;
-- it doesn't start with Feel off
do
    local tries = 0
    local try = page.TryMoment
    page.TryMoment = function(...) tries = tries + 1 end
    RunTimers()
    -- a fight starts mid-tour: nothing more plays
    page.PlayTour()
    assert(tries == 1, "the first step at once")
    local icl = InCombatLockdown
    InCombatLockdown = function() return true end
    RunTimers()
    InCombatLockdown = icl
    assert(tries == 1, "U2-8: a fight started: the other five didn't play (" .. tries .. ")")
    -- the window closes mid-tour
    tries = 0
    page.PlayTour()
    ns.ShellWindow():Hide()
    RunTimers()
    assert(tries == 1, "U2-8: the window closed: the tour stopped (" .. tries .. ")")
    ns.ShellWindow():Show()
    -- the same button again: Stop
    tries = 0
    page.PlayTour()
    page.PlayTour()
    RunTimers()
    assert(tries == 1, "U2-8: played again = Stop (" .. tries .. ")")
    -- Feel off: no tour
    tries = 0
    V.Settings().enabled = false
    page.PlayTour()
    RunTimers()
    V.Settings().enabled = true
    assert(tries == 0, "U2-8: Feel off, no tour")
    page.TryMoment = try
    io.write("PASS: U2-8: the tour stops on a fight, on close, on Stop; not with Feel off\n")
end
-- Night review 2, U2-16 / U2-9: the popover's Default has Undo; a proposal hides the When chip
do
    local Wh = ns.When
    page.SetKind("feel")
    page.browser.Select("Defense")
    local low
    for _, r in ipairs(page.rows) do if r.key == "lowHp" and r:IsVisible() then low = r end end
    Wh.Set("lowHp", "below", 0.25)
    page.Refresh()
    low.when.scripts.OnClick(low.when)
    local pop = ns.HapticsUI.LevelPop()
    pop.default.scripts.OnClick(pop.default)
    assert(Wh.Get("lowHp", "below") == 0.35, "the popover's Default")
    local offer = ns.ShellWindow().offer
    assert(offer:IsShown(), "U2-16: Undo offered")
    offer.scripts.OnClick(offer)
    assert(Wh.Get("lowHp", "below") == 0.25, "U2-16: Undo: 25 % again")
    pop:Hide()
    Wh.Set("lowHp", "below", nil)
    -- a proposal on the row: its line, no chip over it
    local C = ns.HelperCues
    local prop = C.Proposal
    C.Proposal = function(kind, key) if key == "lowHp" and kind == "feel" then return { id = "pulse", name = "Pulse" } end end
    page.Refresh()
    assert(not low.when:IsShown(), "U2-9: the proposal's line, no When chip over it")
    C.Proposal = prop
    page.Refresh()
    assert(low.when:IsShown(), "the chip back")
    io.write("PASS: U2-16/U2-9/U2-11: popover Undo, chip under a proposal, one When" .. string.char(10))
end
