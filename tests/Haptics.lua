-- The Beta tab and its engine: feels, mixer, calibration, sharing, probes, events, Rumble routed.
-- lua5.1 tests/Haptics.lua <addon folder>
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

-- More of the game for the Beta engine ------------------------------------------------
function GetTime() return now end
date = os.date
local led = {}
C_GamePad.SetLedColor = function(c) led[#led + 1] = c end
C_GamePad.ClearLedColor = function() led[#led + 1] = "clear" end
C_GamePad.GetPowerLevel = function() return 3 end
C_GamePad.GetActiveDeviceID = function() return 1 end
local axes = { 0, 0, 0, 0, 0, 0 }
C_GamePad.GetDeviceMappedState = function() return { axes = axes, buttons = {}, labelStyle = "Shapes" } end
CreateColor = function(r, g, b) return { r = r, g = g, b = b } end
C_Timer.NewTicker = function(_, fn) local t = { fn = fn, Cancel = function() end }; return t end
UnitClass = function() return "Rogue", "ROGUE" end
RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 0.96, b = 0.41 } }
InCombatLockdown = function() return combat end
IsShiftKeyDown = function() return false end
function methods:HighlightText() end
function methods:SetMaxLetters() end

for _, file in ipairs({ "Model.lua", "Shared.lua", "TouchModel.lua", "Gestures.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "Haptics.lua", "Volume.lua",
    "HapticsLab.lua", "HelperLink.lua", "LightPresets.lua", "Lights.lua", "HelperCues.lua", "HapticsDebug.lua", "Battery.lua", "HapticsUI.lua", "LightPicker.lua", "RumblePage.lua", "BetaPage.lua", "SetupPage.lua", "GesturesPage.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local V, H, L = ns.Rumble, ns.Haptics, ns.HapticsLab
for _, f in ipairs(created) do
    if f.events and f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end
local function near(a, b, msg) assert(math.abs(a - b) < 1e-6, (msg or "") .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
local function frame(dt)
    now = now + (dt or 1 / 60)
    if H.driver.shown then H.driver.scripts.OnUpdate(H.driver, dt or 1 / 60) end
end
-- every shown OnUpdate but the mixer's, for a while
local function run(seconds, step)
    step = step or 0.01
    for _ = 1, math.floor(seconds / step) do
        now = now + step
        for _, f in ipairs(created) do
            if f ~= H.driver and f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, step) end
        end
    end
end

-- Feels --------------------------------------------------------------------------------
local env = { attack = 0.1, hold = 0.2, decay = 0.1, peak = 0.8 }
near(H.Length(env), 0.4, "length")
local l, r = H.Sample(env, 0.05)
near(l, 0.4, "attack half way"); near(r, 0.4, "both sides")
near((H.Sample(env, 0.2)), 0.8, "hold")
near((H.Sample(env, 0.35)), 0.4, "decay half way")
assert(H.Sample(env, 0.5) == nil, "done")
env.loop = true
near((H.Sample(env, 0.45)), 0.4, "looped")
l, r = H.Sample({ hold = 1, pan = -1 }, 0.5)
assert(l == 1 and r == 0, "pan left")
l, r = H.Sample({ hold = 1, pan = -1, panTo = 1 }, 0.999)
assert(l < 0.01 and r == 1, "pan swept right")
local grain = { hold = 1, grain = { rate = 10, depth = 1, wave = "square", duty = 0.5 } }
assert((H.Sample(grain, 0.02)) == 1 and (H.Sample(grain, 0.07)) == 0, "square grain on, off")
local keys = { keys = { left = { { 0, 0 }, { 1, 1 } }, right = { { 0, 1, "hold" }, { 0.5, 0 }, { 1, 0 } } } }
l, r = H.Sample(keys, 0.25)
near(l, 0.25, "keys left"); near(r, 1, "keys right held")
assert(H.Sample({ hold = 0.02, kick = 0.01, peak = 0.3 }, 0.005) == 1, "kick")
assert(H.Sample({ hold = 1, noise = 1 }, 0.3, 5) == H.Sample({ hold = 1, noise = 1 }, 0.3, 5), "noise stable per moment")
assert(#H.LIBRARY >= 50, "library: " .. #H.LIBRARY)
for _, f in ipairs(H.LIBRARY) do
    local len = H.Length(f)
    for t = 0, len, len / 20 do
        local x, y = H.Sample(f, t, 3)
        if x then assert(x >= 0 and x <= 1 and y >= 0 and y <= 1, f.key .. " in range at " .. t) end
    end
    local back = assert(H.Import(H.Export(f)), f.key .. " imports")
    near(H.Length(back), len, f.key .. " length after import")
    for t = 0.0037, len * 0.99, len / 7.3 do
        local x1, y1 = H.Sample(f, t, 3)
        local x2, y2 = H.Sample(back, t, 3)
        assert(math.abs((x1 or 0) - (x2 or 0)) < 0.01 and math.abs((y1 or 0) - (y2 or 0)) < 0.01,
            f.key .. " same feel at " .. t)
    end
end
assert(H.Import("hello") == nil and H.Import("GPCF1:{os.exit()}") == nil, "junk refused, no code run")
assert(#H.Simplify({ { 0, 0 }, { 0.5, 0.5 }, { 1, 1 } }) == 2, "straight line: two keys")
assert(#H.Simplify({ { 0, 0 }, { 0.5, 1 }, { 1, 0 } }) == 3, "a peak kept")
io.write("PASS: feels: envelope, keys, grain, pan, kick, noise, " .. #H.LIBRARY .. " library feels shared and back\n")

-- Mixer ---------------------------------------------------------------------------------
local db = H.DB()
assert(GamepadCompanionHapticsDB == db and db.engine == true, "own saved table, engine on")
db.engine = false
near(H.Calibrated(2, 0.5), 0.5, "no floor by default: both grips felt from 5% in game")
assert(db.minPulse == 0.05 and db.version == 8, "taps held to 50 ms by default")
GamepadCompanionHapticsDB = { minPulse = 0, floor = { 0, 0.5 } }
local old = H.DB()
assert(old.minPulse == 0.05 and old.floor[2] == 0, "settings from 0.13.2 moved to the probes' defaults")
GamepadCompanionHapticsDB = db
H.DB()
db.minPulse = 0
assert(H.Calibrated(1, 0) == 0, "zero stays zero")
db.gamma[1] = 0.5
near(H.Calibrated(1, 0.25), 0.5, "curve lifts soft levels")
db.gamma[1] = 1
assert(db.rate == 0, "every frame by default")
db.rate = 10
-- At 10/s a pulse shorter than a send's interval is still sent, held to it
vib = {}
H.Play({ hold = 0.03, peak = 1 }, { voice = "short" })
frame(0.01)
assert(vib[1] and vib[1][1] == "Low" and vib[1][2] == 1, "a short pulse goes out at once")
frame(0.03); frame(0.03)
assert(#vib == 2 and vib[#vib][1] ~= "stop", "held, not stopped before the next send")
frame(0.05)
assert(vib[#vib][1] == "stop", "stopped at the next send")
H.Stop()
db.rate = 0
vib = {}
H.Play({ hold = 0.1, peak = 1 }, { voice = "a" })
frame()
assert(#vib == 2 and vib[1][1] == "Low" and vib[1][2] == 1, "sent at once")
frame(); frame()
assert(#vib == 2, "unchanged: not sent again")
frame(0.11)
assert(vib[#vib][1] == "stop", "done: stopped")
H.Play({ hold = 1, peak = 0.5 }, { voice = "a" })
H.Play({ hold = 1, peak = 0.5 }, { voice = "b" })
db.mix = "max"; frame(); near(H.out.l, 0.5, "max")
db.mix = "screen"; frame(); near(H.out.l, 0.75, "screen")
db.mix = "sum"; frame(); near(H.out.l, 1, "sum")
db.mix = "screen"
H.Play({ hold = 0.5, peak = 0.1, duck = { amount = 1, time = 0.3 } }, { voice = "c" })
frame()
assert(H.out.l < 0.2, "ducked under the new one: " .. H.out.l)
H.Stop()
assert(vib[#vib][1] == "stop" and H.out.l == 0, "stop all")
db.kick = 0.03
H.Play({ hold = 0.5, peak = 0.2 }, { voice = "k" })
frame(); assert(H.out.l == 1, "overdrive at the start")
frame(0.05); assert(H.out.l < 1, "then the level")
db.kick = 0
H.Stop()
db.triggers = "mirror"
vib = {}
H.Play({ hold = 0.2, peak = 1 }, { voice = "t" })
frame()
local sawTrigger = false
for _, v in ipairs(vib) do if v[1] == "RTrigger" then sawTrigger = true end end
assert(sawTrigger, "mirrored on the triggers")
db.triggers = "off"
H.Stop()
io.write("PASS: mixer: frame sends on change, mix modes, ducking, calibration, overdrive, triggers\n")

-- Light bar -----------------------------------------------------------------------------
led = {}
H.Flash("x", 1, 0, 0, 0.5, 5)
frame(0.05)
assert(led[1] and led[1].r > 0.5 and led[1].g == 0, "flash sent")
frame(0.6); frame()
assert(led[#led] == "clear", "faded and cleared")
io.write("PASS: light bar: a flash sent and cleared\n")

-- Rumble through the mixer ---------------------------------------------------------------
L.SetEngine(true)
assert(H.Engine() and H.Routing(), "engine on, routed")
vib = {}
V.Play("impact")
assert(#vib == 0, "Rumble no longer writes the motors itself")
frame()
assert(#vib >= 2 and vib[1][1] == "Low", "the mixer does")
V.Stop()
frame()
assert(H.out.l == 0, "Rumble's stop clears its voice")
assert(V.Pattern("x_boom") and V.Pattern("x_boom").beta, "library feels registered")
V.SetEventPattern("levelUp", "x_boom")
V.Fire("levelUp")
assert(H.Playing("rumbleFeel"), "a beta feel on a Rumble event plays on the mixer")
V.Stop()
assert(not H.Playing("rumbleFeel"), "and stops with Rumble")
V.SetEventPattern("levelUp", "rise")
L.SetEngine(false)
assert(not H.Routing(), "off: not routed")
vib = {}
V.Play("impact"); RunTimers()
local direct = false
for _, v in ipairs(vib) do if v[1] == "Low" then direct = true end end
assert(direct, "off: Rumble writes the motors as before")
V.Stop()
io.write("PASS: Rumble routed through the mixer with the engine on, as before with it off; beta feels in Rumble\n")

-- Beta events ----------------------------------------------------------------------------
local labFrame
for _, f in ipairs(created) do if f.events and f.events.UI_ERROR_MESSAGE then labFrame = f end end
assert(labFrame, "lab listens")
L.SetEngine(true)
local fired = {}
L.onFire = function(key) fired[#fired + 1] = key end
local function ev(...) labFrame.scripts.OnEvent(labFrame, ...) end
UnitHealthMax = function() return 1000 end
ev("UNIT_COMBAT", "player", "WOUND", "", 300, 1)
ev("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
now = now + 1
ev("UI_ERROR_MESSAGE", 1, "Not enough mana")
LOOT_ITEM_SELF = "You receive loot: %s."
ev("CHAT_MSG_LOOT", "You receive loot: [Linen Cloth].")
ev("CHAT_MSG_LOOT", "Bob receives loot: [Linen Cloth].")
ev("QUEST_TURNED_IN", 1)
ev("CHAT_MSG_WHISPER", "hi", "Bob")
local seen = table.concat(fired, ",")
assert(seen == "hitTaken,dodge,uiError,loot,questDone,whisper", seen)
L.EventSettings("whisper").on = false
fired = {}
now = now + 1
ev("CHAT_MSG_WHISPER", "hi", "Bob")
assert(#fired == 0, "off: nothing")
local falling = true
IsFalling = function() return falling end
local air = L.airFrame
air.scripts.OnUpdate(air, 0.01); now = now + 1
falling = false
air.scripts.OnUpdate(air, 0.01)
assert(fired[1] == nil, "a landing waits a frame (the swim may start on the next)")
air.scripts.OnUpdate(air, 0.01)
assert(fired[1] == "landing", "landing: " .. tostring(fired[1]))
assert(H.DB().landings[1] == 1, "air time kept: " .. tostring(H.DB().landings[1]))
assert(H.Playing("ev_landing"), "a landing shaped by its fall")
local sentText
L.onLand = function(t, k, sent) if sent then sentText = sent end end
for _ = 1, 120 do frame(0.01); air.scripts.OnUpdate(air, 0.01) end
assert(sentText and sentText.peak > 0 and sentText.last > sentText.start, "what was sent, measured")
assert(L.lastLanding and L.lastLanding.t == 1, "last landing shown")
H.DB().landMin, H.DB().landMax = 0.4, 0.8
assert(math.abs(L.LandingWeight(0.6) - 0.5) < 1e-9 and L.LandingWeight(0.9) == 1, "landing range set by hand")
H.DB().landMin, H.DB().landMax = nil, nil
L.SetStepRate("walk", 1.5)
assert(L.StepRate("walk") == 1.5 and select(3, L.StepTiming(2.5)), "walk steps set by hand")
H.DB().stepSync = {}
-- Another feel on Landing: stretched with the landing's weight
L.EventSettings("landing").feel = "flick"
falling = true; air.scripts.OnUpdate(air, 0.01); now = now + 2
falling = false; air.scripts.OnUpdate(air, 0.01); air.scripts.OnUpdate(air, 0.01)
assert(L.lastLanding.feel == "Flick", "the feel played, named")
assert(math.abs(H.Peak(H.Feel("flick")) - 0.55) < 1e-9, "a feel's peak")
frame(0.01)
assert(H.out.l > 0.97 or H.out.r > 0.97, "a full landing: the feel's peak at full: " .. H.out.l .. " " .. H.out.r)
L.EventSettings("landing").feel = "thud"
local hop, fall = L.LandingFeel(L.LandingWeight(0.45)), L.LandingFeel(L.LandingWeight(2.5))
assert(#hop.pulses == 1 and hop.pulses[1][3] < 0.12, "a hop: one faint pulse")
assert(L.LandingLevel(0) < 0.05 and L.LandingLevel(0.29) < 0.09 and L.LandingLevel(1) == 1 and L.LandingLevel(0.5) < 0.3,
    "contrast: the lightest 30% barely there, then steep")
assert(#fall.pulses >= 4 and fall.pulses[1][3] > 0.9 and fall.pulses[1][2] >= 0.39, "a big fall: strong, long, echoes")
assert(hop.pulses[1][2] <= 0.07, "a hop: short")
H.DB().landLong = 0.8
assert(L.LandingFeel(1).pulses[1][2] >= 0.79, "longest landing set by hand")
H.DB().landLong = nil
-- Footsteps: the fit from squeezes (one step missed), and the timing it gives
local rate, offset = L.FitSteps({ 0.15, 0.55, 0.95, 1.75, 2.15, 2.55 })
assert(math.abs(rate - 2.5) < 1e-6 and math.abs(offset - 0.15) < 1e-6, "rate and offset: " .. tostring(rate) .. " " .. tostring(offset))
L.sync = { band = "run", taps = { 0.15, 0.55, 0.95, 1.35, 1.75 }, speeds = { 7, 7 }, start = now }
L.StepSyncEnd()
local r2, o2, synced = L.StepTiming(7)
assert(synced and math.abs(r2 - 2.5) < 1e-6 and math.abs(o2 - 0.15) < 1e-6, "synced timing")
local _, _, walkSynced = L.StepTiming(2.5)
assert(not walkSynced, "walking keeps its own (not synced yet)")
L.sync = { band = "walk", taps = { 0.2, 0.75, 1.3, 1.85, 2.4 }, speeds = { 7 }, start = now }
L.StepSyncEnd()
assert(not L.StepCal("walk"), "a walk sync done running is refused")
L.sync = { band = "walk", taps = { 0.2, 0.75, 1.3, 1.85, 2.4 }, speeds = { 2.5 }, start = now }
L.StepSyncEnd()
local rw, ow, ws = L.StepTiming(2.5)
assert(ws and math.abs(rw - 1 / 0.55) < 1e-6 and math.abs(ow - 0.2) < 1e-6, "walk synced on its own")
assert(math.abs(L.StepTiming(7) - 2.5) < 1e-6, "run unchanged")
assert(L.Report():find("Steps ", 1, true) and L.Report():find("Last landings", 1, true), "in the report")
L.EventSettings("heartbeat").on = true
UnitHealth = function() return 200 end
L.Poll()
assert(H.Playing("live_heartbeat"), "heartbeat under half health")
UnitHealth = function() return 900 end
L.Poll()
frame()
assert(not H.Playing("live_heartbeat"), "and gone above it")
L.SetEngine(false)
fired = {}
now = now + 1
ev("QUEST_TURNED_IN", 1)
assert(#fired == 0, "engine off: no beta events")
io.write("PASS: beta events: hits, avoid, errors, own loot only, quests, whispers, landing, heartbeat; off with the engine\n")

-- The Lab tab (once Beta) ------------------------------------------------------------------
ns.Shell.Open("beta")
local window, tabs = ns.ShellWindow()
assert(window:IsShown() and ns.Shell.Current() == "lab" and tabs.lab, "Lab, from the old key")
assert(not tabs.lab:IsShown() and not tabs.beta, "no tab until Tools › Lab")
API.SetLab(true)
assert(tabs.lab:IsShown(), "Tools › Lab: its tab")
assert(tabs.moments and tabs.gestures and tabs.setup, "Moments, Gestures, Setup tabs")
local ui = ns.BetaPage
for _, key in ipairs({ "feels", "editor", "tune", "timing", "link", "probes" }) do
    ui.Select(key)
    assert(ui.panels[key]:IsShown(), key .. " shown")
end
-- Gestures: twelve rows, an action shown by name, Clear
do
    local G = ns.Gestures
    G.Set(2, "text:/dance")
    ns.Shell.Open("gestures")
    local n, dance = 0, nil
    for _, f in ipairs(created) do
        if type(rawget(f, "label")) == "table" and f.label.text == "Clear" and f:IsVisible() then n = n + 1 end
        if type(rawget(f, "label")) == "table" and type(f.label.text) == "string" and f.label.text:find("/dance", 1, true) and f:IsVisible() then dance = f end
    end
    assert(n == 12 and dance, "twelve gesture rows, slot 2 /dance: " .. n)
    G.Set(2, nil)
    ns.Shell.Open("lab")
    io.write("PASS: gestures page: twelve slots, each an action" .. string.char(10))
end
local function button(label)
    for _, f in ipairs(created) do
        if type(rawget(f, "label")) == "table" and f.label.text == label and f:IsVisible() then return f end
    end
end
ui.Select("probes")
local play = assert(button("Play"), "Play")
vib = {}
play.scripts.OnClick(play)
run(3.5)
assert(vib[2] and vib[2][1] == "Low" and vib[2][2] == 1 and vib[#vib][1] == "stop", "probe step played raw and stopped")
local taps = 0
for _, v in ipairs(vib) do if v[1] == "Low" then taps = taps + 1 end end
assert(taps == 5, "five taps: " .. taps)
assert(L.Measured() == "10-20 ms", "real length on 10 ms frames: " .. tostring(L.Measured()))
local three = assert(button("3-4"), "3-4")
three.scripts.OnClick(three)
assert(L.Answers(L.PROBES[1])[1] == "3-4", "answer kept")
assert(L.Report():find("16 ms=3-4 (10-20 ms)", 1, true) and L.Report():find("Log:", 1, true), "in the report with its real length: " .. L.Report())
local cvars = { maxFPS = "100" }
C_CVar = { GetCVar = function(k) return cvars[k] end, SetCVar = function(k, v) cvars[k] = v end }
local cap = assert(button("Cap 60 fps"), "fps button")
cap.scripts.OnClick(cap)
assert(cvars.maxFPS == "60" and L.FpsCapped(), "capped")
cap.scripts.OnClick(cap)
assert(cvars.maxFPS == "100" and not L.FpsCapped(), "put back")
C_CVar = nil
ns.Shell.Open("setup")
local find = assert(button("Find left"), "Find left, on Setup")
find.scripts.OnClick(find)
assert(L.Ramping(), "ramping")
run(0.5)
L.ramp.level = 0.23
find.scripts.OnClick(find)
near(H.DB().floor[1], 0.23, "floor set")
ns.Shell.Open("lab")
ui.Select("editor")
local new = assert(button("New"), "New")
new.scripts.OnClick(new)
local own = {}
for k in pairs(H.DB().feels) do own[#own + 1] = k end
assert(#own == 1, "a feel of your own")
local feel = H.Feel(own[1])
assert(feel.pulses and #feel.pulses == 1 and not feel.keys, "a new feel is one pulse")
local keysB = assert(button("Keys"), "Keys")
keysB.scripts.OnClick(keysB)
assert(feel.keys and #feel.keys.left >= 2 and not feel.pulses, "to keyframes")
local shapeB = assert(button("Shape"), "Shape")
shapeB.scripts.OnClick(shapeB)
assert(feel.attack and not feel.keys, "to a shape")
local pulsesB = assert(button("Pulses"), "Pulses")
pulsesB.scripts.OnClick(pulsesB)
assert(feel.pulses and #feel.pulses >= 1 and not feel.attack, "back to pulses: " .. #feel.pulses)
keysB.scripts.OnClick(keysB)
assert(H.Import(H.Export(feel)).keys, "keyframes shared")
assert(V.Pattern("x_" .. own[1]), "in Rumble's grid too")
combat = true
local rec = assert(button("Record L2 R2"), "Record")
rec.scripts.OnClick(rec)
assert(not button("Stop recording"), "not in combat")
combat = false
rec.scripts.OnClick(rec)
axes[5], axes[6] = 0.6, 0.2
run(0.5, 0.05)
local stopRec = assert(button("Stop recording"), "recording")
stopRec.scripts.OnClick(stopRec)
local recorded
for _, f in pairs(H.DB().feels) do if (f.label or ""):find("Recorded") then recorded = f end end
assert(recorded and recorded.pulses and recorded.pulses[1][4] == -1 and recorded.pulses[1][3] > 0.5,
    "a squeeze of L2: a left pulse as deep as it was")
io.write("PASS: Lab tab: seven sections, probe played and answered, floor found, editor shape to keys, recorded, engine switch\n")

-- Review fixes ---------------------------------------------------------------------------
H.Stop()
H.Play("heart60", { voice = "once", loop = false })
for _ = 1, 80 do frame(1 / 60) end
assert(not H.Playing("once"), "a looping feel played once ends")
L.SetEngine(false)
V.SetEventPattern("levelUp", "x_boom")
vib = {}
V.Fire("levelUp")
assert(not H.Playing("rumbleFeel"), "engine off: a beta feel on Rumble plays Rumble's way")
local direct2 = false
for _, v in ipairs(vib) do if v[1] == "Low" then direct2 = true end end
assert(direct2, "as a tick")
V.Stop()
V.SetEventPattern("levelUp", "rise")
L.Run({ { 0, function() H.Send("Low", 1) end }, { 0.2, function() H.Silence() end } })
assert(H.hold, "a probe holds the motors")
H.Play("max", { voice = "intruder" })
vib = {}
frame()
for _, v in ipairs(vib) do assert(v[2] ~= 1 or v[1] ~= "High", "mixer quiet during a probe") end
L.Halt()
assert(not H.hold, "released")
H.Stop()
-- Shortest pulse: a feel shorter than it is held up to it
H.Stop()
db.minPulse = 0.05
H.Play({ hold = 0.01, peak = 1 }, { voice = "short" })
frame(0.01); assert(H.out.l == 1, "on")
frame(0.02); assert(H.out.l == 1, "held past its end")
frame(0.04); assert(H.out.l == 0, "then let go")
db.minPulse = 0
-- A feel shorter than a frame is still played
H.Play({ hold = 0.005, peak = 1 }, { voice = "tiny" })
frame(0.02)
assert(H.out.l == 1, "sampled at its start on its first frame")
H.Stop()
L.Run({ { 0, function() end } })
assert(L.Measured() == nil, "a probe without taps keeps no tap lengths")
L.Halt()
-- Trigger test: each squeeze plays the next variation on its side
ns.Shell.Open("lab"); ns.BetaPage.Select("probes")
local trigB
for _, f in ipairs(created) do
    if type(rawget(f, "label")) == "table" and f.label.text == "Trigger test" and f:IsVisible() then trigB = f end
end
assert(trigB, "Trigger test button")
trigB.scripts.OnClick(trigB)
local tw = GamepadCompanionTriggerTest
assert(tw and tw:IsShown() and L.trigger.on and H.hold, "window open, triggers listened to")
local function tick() now = now + 0.02; for _, f in ipairs(created) do if f ~= H.driver and f.shown and f.scripts.OnUpdate and f.parent == nil then f.scripts.OnUpdate(f, 0.02) end end end
vib = {}
axes[5] = 0.9; tick()
local lt = false
for _, v in ipairs(vib) do if v[1] == "LTrigger" and v[2] == 1 then lt = true end end
assert(lt and L.trigger.index[1] == 1, "L2 squeezed: first variation on LTrigger")
axes[5] = 0; tick()
axes[5] = 0.9; tick()
assert(L.trigger.index[1] == 2, "next squeeze: next variation")
axes[6] = 0.9; tick()
assert(L.trigger.index[2] == 1, "R2 counts on its own")
tw.rows[1].marks[1].scripts.OnClick(tw.rows[1].marks[1])
assert(L.TriggerAnswers("full").L2 == "Trigger", "marked")
assert(L.Report():find("Trigger, full, 0.5 s=L2 Trigger", 1, true), "in the report")
tw:Hide()
assert(not L.trigger.on and not H.hold, "closed: released")
axes[5], axes[6] = 0, 0
-- Overdrive taps: full first, then the level
local kicked
for _, p in ipairs(L.PROBES) do if p.key == "kick2" then kicked = p.steps[2][2]() end end
vib = {}
L.Run(kicked)
for _ = 1, 8 do now = now + 0.01; for _, f in ipairs(created) do if f ~= H.driver and f.shown and f.scripts.OnUpdate and f.parent == nil then f.scripts.OnUpdate(f, 0.01) end end end
local levels = {}
for _, v in ipairs(vib) do if v[1] == "Low" then levels[#levels + 1] = v[2] end end
assert(levels[1] == 1 and math.abs(levels[2] - 0.4) < 1e-9, "kick then level: " .. table.concat(levels, ","))
L.Halt()
-- Swings: each weapon its feel, on its own timer (main and off hand)
GetInventoryItemID = function(_, slot) return slot == 16 and 100 or slot == 17 and 200 or nil end
local oldItem = C_Item
C_Item = { GetItemInfoInstant = function(id)
    if id == 100 then return nil, nil, nil, nil, nil, 2, 5 end
    if id == 200 then return nil, nil, nil, nil, nil, 2, 15 end
end }
assert(V.SwingPattern(16) == "swMace2" and V.SwingPattern(17) == "swDagger", "two-handed mace, dagger")
assert(V.Pattern("swMace2").feel and V.Pattern("swDagger").feel, "swings as pulses")
UnitAttackSpeed = function() return 3.6, 1.5 end
V.SetEventPattern("autoAttack", "auto")
local swings = {}
local realFire = V.Fire
V.Fire = function(k) if k == "autoAttack" then swings[#swings + 1] = V.EventPattern("autoAttack") end end
local rumbleEvents
for _, f in ipairs(created) do if f.events and f.events.START_AUTOREPEAT_SPELL and f.events.PLAYER_LEVEL_UP then rumbleEvents = f end end
local function rev(...) rumbleEvents.scripts.OnEvent(rumbleEvents, ...) end
local canAttack, oldCan = true, UnitCanAttack
UnitCanAttack = function() return canAttack end
local function count()
    local m, o = 0, 0
    for _, k in ipairs(swings) do if k == "swMace2" then m = m + 1 elseif k == "swDagger" then o = o + 1 end end
    return m, o
end
-- auto attack on, out of range: no swing lands, nothing plays
rev("PLAYER_ENTER_COMBAT")
assert(V.Swinging(), "auto attack on")
run(8)
assert(#swings == 0, "out of range: no swings felt: " .. #swings)
-- real swings (UNIT_COMBAT on the target): one feel each, the hand the one due
rev("UNIT_COMBAT", "target", "WOUND", "", 120, 1)
now = now + 0.2
rev("UNIT_COMBAT", "target", "MISS", "", 0, 1)
local m, o = count()
assert(m == 1 and o == 1, "a main-hand hit, an off-hand miss: " .. m .. " " .. o)
now = now + 0.3
rev("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assert(#swings == 2, "too soon for either hand: someone else's blow")
now = now + 1.0
rev("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
m, o = count()
assert(m == 1 and o == 2, "the off hand again, by its speed: " .. m .. " " .. o)
now = now + 2.2
rev("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
m, o = count()
assert(m == 2 and o == 2, "the main hand, by its speed: " .. m .. " " .. o)
-- not swings: a spell's wound, a blow just after an ability, a heal, a friendly target, while shooting
now = now + 4
swings = {}
rev("UNIT_COMBAT", "target", "WOUND", "", 80, 4)
rev("UNIT_COMBAT", "target", "HEAL", "", 80, 1)
rev("UNIT_SPELLCAST_SUCCEEDED", "player", "g1", 1752)
rev("UNIT_COMBAT", "target", "WOUND", "", 80, 1)
canAttack = false
now = now + 1
rev("UNIT_COMBAT", "target", "WOUND", "", 80, 1)
canAttack = true
rev("START_AUTOREPEAT_SPELL")
rev("UNIT_COMBAT", "target", "WOUND", "", 80, 1)
rev("STOP_AUTOREPEAT_SPELL")
assert(#swings == 0, "only your melee swings: " .. #swings)
-- auto attack off, or dead: nothing
now = now + 3
rev("PLAYER_LEAVE_COMBAT")
rev("UNIT_COMBAT", "target", "WOUND", "", 80, 1)
assert(#swings == 0 and not V.Swinging(), "auto attack off: no swings")
rev("PLAYER_ENTER_COMBAT")
local oldDead = UnitIsDeadOrGhost
UnitIsDeadOrGhost = function() return true end
rev("UNIT_COMBAT", "target", "WOUND", "", 80, 1)
assert(#swings == 0, "dead: no swings")
UnitIsDeadOrGhost = oldDead
-- the combat log, where readable: your swings by hand, sure
local guid = "Player-1"
local oldGuid, oldLog = UnitGUID, CombatLogGetCurrentEventInfo
UnitGUID = function() return guid end
local entry
CombatLogGetCurrentEventInfo = function() return unpack(entry) end
entry = { 0, "SWING_DAMAGE", false, guid, "", 0, 0, "Creature-1", "", 0, 0, 100, 0, 1, 0, 0, 0, false, false, false, true }
rev("COMBAT_LOG_EVENT_UNFILTERED")
entry = { 0, "SWING_MISSED", false, "Player-2", "", 0, 0, "Creature-1", "", 0, 0, "MISS", false }
rev("COMBAT_LOG_EVENT_UNFILTERED")
m, o = count()
assert(m == 0 and o == 1, "the log: your off-hand swing, not another's: " .. m .. " " .. o)
UnitGUID, CombatLogGetCurrentEventInfo = oldGuid, oldLog
rev("PLAYER_LEAVE_COMBAT")
-- ranged: turning Auto Shot on fires nothing; each shot fired, one feel
local shots = 0
V.Fire = function(k) if k == "shot" then shots = shots + 1 end end
rev("START_AUTOREPEAT_SPELL")
run(5)
assert(shots == 0, "Auto Shot on, out of range: nothing")
rev("UNIT_SPELLCAST_SUCCEEDED", "player", "s1", 75)
assert(shots == 1, "a shot fired: one feel")
rev("STOP_AUTOREPEAT_SPELL")
UnitCanAttack = oldCan
UnitAttackSpeed = function() return 3.6, 1.5 end
V.Fire = realFire
C_Item = oldItem
GetInventoryItemID = nil
io.write("PASS: review fixes: loop feels once end, engine off keeps Rumble's way, probes hold the motors\n")

-- Lights: base, cues from Rumble and the Lab, casts, the pages ------------------------
do
    local LT = ns.Lights
    local db = H.DB()
    db.engine, db.light = true, true
    H.Stop()
    H.LightStop()
    led = {}
    LT.ApplyBase()
    frame(0.05)
    -- (perceptual brightness: 35 % -> 3/8 strength -> 0.375^2.2 of the light)
    assert(led[#led] and led[#led].r and led[#led].g > 0.05 and led[#led].r >= led[#led].g and led[#led].b < led[#led].g,
        "the class colour (rogue yellow) at the base")
    -- a crit: the base brighter (through Rumble's event, even with its vibration off)
    V.SetEventPattern("crit", "off")
    led = {}
    V.Fire("crit")
    frame(0.05)
    assert(led[#led] and led[#led].g > 0.8, "a crit: the base colour near full: " .. tostring(led[#led] and led[#led].g))
    for _ = 1, 40 do frame(0.05) end
    -- a cast glows, building, then flashes on release
    UnitCastingInfo = function() return "Fireball", nil, nil, now * 1000, (now + 2) * 1000 end
    local lf
    for _, f in ipairs(created) do if f.events and f.events.UNIT_SPELLCAST_SUCCEEDED and f.events.PLAYER_REGEN_DISABLED then lf = f end end
    assert(lf, "lights listen to casts")
    lf.scripts.OnEvent(lf, "UNIT_SPELLCAST_START", "player")
    frame(0.05)
    local early = led[#led] and (led[#led].r + led[#led].g + led[#led].b) or 0
    for _ = 1, 30 do frame(0.05) end
    local late = led[#led] and (led[#led].r + led[#led].g + led[#led].b) or 0
    assert(late > early, "the cast builds: " .. early .. " -> " .. late)
    lf.scripts.OnEvent(lf, "UNIT_SPELLCAST_SUCCEEDED", "player")
    frame(0.05)
    assert(led[#led] and (led[#led].r + led[#led].g + led[#led].b) > late + 0.3, "released: a bright flash")
    -- another spell's failed attempt mid-cast keeps the cast; STOP before SUCCEEDED still flashes
    for _ = 1, 30 do frame(0.05) end
    UnitCastingInfo = function() return "Fireball", nil, nil, now * 1000, (now + 2) * 1000 end
    lf.scripts.OnEvent(lf, "UNIT_SPELLCAST_START", "player", "cast-1")
    frame(0.05)
    lf.scripts.OnEvent(lf, "UNIT_SPELLCAST_FAILED", "player", "cast-2")
    assert(H.LightsBusy() and select(4, H.LedNow()), "still casting")
    for _ = 1, 5 do frame(0.05) end
    for _ = 1, 25 do frame(0.05) end
    late = led[#led] and (led[#led].r + led[#led].g + led[#led].b) or 0
    assert(late > 0.5, "the cast still builds after a failed attempt: " .. late)
    lf.scripts.OnEvent(lf, "UNIT_SPELLCAST_STOP", "player", "cast-1")
    lf.scripts.OnEvent(lf, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1")
    frame(0.05)
    assert(led[#led] and (led[#led].r + led[#led].g + led[#led].b) > late + 0.3, "STOP then SUCCEEDED: released")
    UnitCastingInfo = nil
    -- a whisper (a Lab event): purple double blink, even with its vibration off
    L.EventSettings("whisper").on = false
    led = {}
    now = now + 1
    L.Fire("whisper")
    frame(0.05)
    assert(led[#led] and led[#led].b > 0.1 and led[#led].b > led[#led].r and led[#led].r > led[#led].g, "whisper: purple")
    -- off: no event light
    LT.Settings("whisper").on = false
    for _ = 1, 30 do frame(0.05) end
    led = {}
    now = now + 1
    L.Fire("whisper")
    frame(0.05)
    local purple = false
    for _, c in ipairs(led) do if type(c) == "table" and c.b > 0.05 and c.b > c.r and c.r > c.g then purple = true end end
    assert(not purple, "whisper light off")
    LT.Settings("whisper").on = true
    -- a one-off moment with a lasting light glows a moment, then ends
    LT.Settings("kill").light = LT.LightByKey("glow").id
    LT.Fire("kill")
    assert(H.LightsBusy(), "glowing")
    for _ = 1, 40 do frame(0.05) end
    LT.Default("kill")
    io.write("PASS: lights: base, a crit brighter, a cast building then released, a whisper, off, a moment's glow\n")
end

-- The rebuilt pages: an event set Off from its grid, a light's effect picked
do
    ns.Shell.Open("rumble")
    ns.RumblePage.browser.Select("Defense")
    local ui = ns.BetaPage
    local function visible(label)
        for _, f in ipairs(created) do
            if type(rawget(f, "label")) == "table" and f.label.text == label and f:IsVisible() then return f end
        end
    end
    -- an event row (Hit taken): its plate opens the palette, Off on top
    local plate
    for _, f in ipairs(created) do
        if rawget(f, "pick") and rawget(f, "kind") == "l" and f.key == "hitTaken" then plate = f.pick end
    end
    assert(plate, "Hit taken row")
    plate.scripts.OnClick(plate)
    local pw = GamepadCompanionPalette
    assert(pw and pw:IsShown(), "the palette")
    local off = pw.pal.specialTiles[1]
    assert(off and off.key == "off", "Off first")
    off.scripts.OnClick(off, "LeftButton")
    assert(L.EventSettings("hitTaken").on == false, "set Off")
    plate.scripts.OnClick(plate)
    pw.pal:ShowGroup("Basics")
    local tick
    for _, t in ipairs(pw.pal.tiles) do if t:IsShown() and t.key == "r_tick" then tick = t end end
    assert(tick, "Rumble's Tick in the palette (Basics)")
    tick.scripts.OnClick(tick, "LeftButton")
    assert(L.EventSettings("hitTaken").on and L.EventSettings("hitTaken").feel == "r_tick", "a Rumble pattern on a Beta event")
    -- Default: back to the shipped feel
    for _, f in ipairs(created) do
        if rawget(f, "default") and rawget(f, "kind") == "l" and rawget(f, "key") == "hitTaken" then f.default.scripts.OnClick(f.default) end
    end
    assert(L.IsEventDefault("hitTaken"), "Default")
    -- Edit: a copy of the feel, assigned, open in the editor
    for _, f in ipairs(created) do
        if rawget(f, "edit") and rawget(f, "key") == "critted" then f.edit.scripts.OnClick(f.edit) end
    end
    local ownCrit = V.EventChoice("critted")
    assert(ownCrit:match("^x_own"), "Critical hit taken: your copy " .. ownCrit)
    assert(H.IsOwn(ownCrit:sub(3)) and ns.Shell.Current() == "lab", "in the editor")
    assert(ui.backButton:IsShown(), "Back to the moment")
    ui.backButton.scripts.OnClick(ui.backButton)
    assert(ns.Shell.Current() == "moments", "back on Moments")
    -- Moments › Light: the same groups, one picker (light, colour, strength), Default
    local M = ns.RumblePage
    local function row(kind, key)
        for _, r in ipairs(M.rows) do if r.kind == kind and r.key == key then return r end end
    end
    local critFeel = row("r", "crit")
    assert(critFeel and critFeel.marks[1]:IsShown(), "Critical hit: a light mark")
    critFeel.marks[1].scripts.OnClick(critFeel.marks[1])
    assert(M.kind == "light" and M.browser.current == "Attacks", "the mark: Light, Attacks")
    local critLight = row("light", "crit")
    assert(critLight:IsVisible() and not row("r", "crit"):IsVisible(), "the light row shown, the feel row not")
    critLight.pick.scripts.OnClick(critLight.pick)
    local lp = GamepadCompanionLightPicker
    assert(lp and lp:IsShown(), "the light picker")
    local function ltile(label)
        for _, t in ipairs(lp.tiles) do if t.label.text == label and t:IsShown() then return t end end
    end
    assert(ltile("Critical hit") and ltile("Flash") and not ltile("Casting"), "its own light first, once lights only")
    ltile("Double").scripts.OnClick(ltile("Double"))
    assert(ns.Lights.Settings("crit").light == ns.Lights.LightByKey("double").id and lp:IsShown(), "a light picked, the picker stays")
    local red
    for _, sw in ipairs(lp.swatches) do if sw.key == "red" and sw:IsShown() then red = sw end end
    red.scripts.OnClick(red)
    for _, sw in ipairs(lp.swatches) do assert(sw.key ~= "school" or not sw:IsShown(), "no School on a crit") end
    lp.dots[2].scripts.OnClick(lp.dots[2])
    local s = ns.Lights.Settings("crit")
    assert(s.color == "red" and s.strength == 2, "colour and strength picked")
    assert(critLight.default.enabled ~= false, "not its default")
    critLight.default.scripts.OnClick(critLight.default)
    assert(ns.Lights.Settings("crit").light == ns.Lights.LightByKey("crit").id and ns.Lights.IsDefault("crit"), "Default")
    lp:Hide()
    local function tile(label)
        for _, t in ipairs(GamepadCompanionBetaFeels.tiles) do if t.label.text == label and t:IsShown() then return t end end
    end
    assert(not critLight.level and not critLight.edit, "strength in the picker, no Edit on a light")
    -- Sound: every moment, loot's coin by default, None
    M.SetKind("sound")
    M.browser.Select("Progress")
    local loot = row("sound", "loot")
    assert(loot:IsVisible() and loot.pick.label.text == "Coin" and not loot.edit, "loot: Coin, no Edit")
    loot.pick.scripts.OnClick(loot.pick)
    tile("None").scripts.OnClick(tile("None"))
    assert(ns.HelperCues.MomentSound("loot") == nil, "None")
    loot.default.scripts.OnClick(loot.default)
    assert(ns.HelperCues.MomentSound("loot") ~= nil, "back to its coin")
    -- The last moment: its row found
    ns.HapticsDebug.Note("Defense · Hit taken: Thud", "hitTaken", "feel")
    M.why.scripts.OnClick(M.why)
    assert(M.kind == "feel" and M.browser.current == "Defense", "jumped to Hit taken")
    -- Edit with WoW Helper's data but the link off: Lab's editor all the same; reopening skips a hidden Lab
    WowHelperData = { at = "18:02" }
    ns.HelperLink.SetEnabled(false)
    API.SetLab(false)
    M.SetKind("feel")
    for _, f in ipairs(created) do
        if rawget(f, "edit") and rawget(f, "key") == "critted" then f.edit.scripts.OnClick(f.edit) end
    end
    assert(ns.Shell.Current() == "lab", "link off: Lab's editor")
    local win = ns.ShellWindow()
    win:Hide()
    ns.Shell.Open()
    assert(ns.Shell.Current() ~= "lab", "reopened: not on a hidden Lab")
    WowHelperData = nil
    ns.Shell.Open("setup")
    assert(visible("Find left") and visible("Sync run") and visible("True haptics"), "range, timing, true haptics on Setup")
    io.write("PASS: pages: an event Off from its grid, Edit and Back, light by mark (effect, colour, Default), sounds, jump, Setup\n")
end

-- Helper cues: casts tighten R2, low health shakes L2, loot and releases queue clips and sounds
do
    local K, C = ns.HelperLink, ns.HelperCues
    H.DB().engine = true
    K.SetEnabled(true)
    K.queue = K.queue or {}
    for i = #K.queue, 1, -1 do K.queue[i] = nil end
    local cf
    for _, f in ipairs(created) do if f.events and f.events.START_AUTOREPEAT_SPELL and f.events.PLAYER_DEAD then cf = f end end
    assert(cf, "cues listen")
    UnitCastingInfo = function() return "Fireball", nil, nil, now * 1000, (now + 2) * 1000 end
    cf.scripts.OnEvent(cf, "UNIT_SPELLCAST_START", "player")
    assert(K.state.right.mode == K.MODES.resist, "a cast: R2 resists")
    cf.scripts.OnEvent(cf, "UNIT_SPELLCAST_SUCCEEDED", "player")
    assert(K.state.right.mode == K.MODES.off, "released: R2 free")
    local queued = {}
    for _, q in ipairs(K.queue) do queued[#queued + 1] = q.touch end
    assert(queued[#queued] == K.CLIPS.release_hit, "the release's clip")
    UnitCastingInfo = nil
    cf.scripts.OnEvent(cf, "START_AUTOREPEAT_SPELL")
    assert(K.state.right.mode == K.MODES.weapon, "shooting: R2 clicks")
    cf.scripts.OnEvent(cf, "STOP_AUTOREPEAT_SPELL")
    V.Fire("lowHp")
    assert(K.state.left.mode == K.MODES.vibrate, "low health: L2 shakes")
    V.EndLoop("lowHp")
    assert(K.state.left.mode == K.MODES.off, "and stops")
    now = now + 1
    L.Fire("loot")
    local last = K.queue[#K.queue]
    assert(last and last.sound == K.SOUNDS.coin and last.moment == C.MOMENT_N.loot, "loot: the coin sound, its moment")
    C.Settings().sounds = false
    local n = #K.queue
    now = now + 1
    L.Fire("loot")
    assert(#K.queue == n or (K.queue[#K.queue].sound or 0) == 0, "sounds off: no sound")
    C.Settings().sounds = true
    -- Volumes: full by default, a moment's own and every sound's, sent as the cue's gain
    local Vol = ns.Volume
    assert(Vol.Gain(1) == 7 and Vol.Gain(0.5) == 3 and Vol.Gain(0) == nil and Vol.Intensity(1) == 4, "volume to gain")
    now = now + 1
    L.Fire("loot")
    last = K.queue[#K.queue]
    assert(last.sound == K.SOUNDS.coin and last.gain == 7, "full by default: " .. tostring(last.gain))
    Vol.SetSounds(0.5)
    Vol.SetSound("loot", 0.5)
    now = now + 1
    L.Fire("loot")
    last = K.queue[#K.queue]
    assert(last.sound == K.SOUNDS.coin and last.gain == 1, "a quarter: gain 1, " .. tostring(last.gain))
    Vol.SetSound("loot", 0)
    n = #K.queue
    now = now + 1
    L.Fire("loot")
    assert(#K.queue == n or (K.queue[#K.queue].sound or 0) == 0, "0%: no sound")
    Vol.SetSound("loot", 1)
    Vol.SetSounds(1)
    assert(Vol.DB().sound.loot == nil, "full is the default, not saved")
    Vol.SetFeel("levelUp", 0.5)
    assert(V.Scaled({ strength = 0.8 }, "levelUp").strength == 0.4 and V.Scaled(nil, "jump") == nil, "a feel at its volume")
    Vol.SetFeel("levelUp", 1)
    -- the rows: a volume beside each feel and sound
    ns.Shell.Open("moments")
    local M = ns.RumblePage
    M.SetKind("sound")
    M.browser.Select("Progress")
    local lootRow
    for _, r in ipairs(M.rows) do if r.kind == "sound" and r.key == "loot" then lootRow = r end end
    assert(lootRow.level and lootRow.level.value.text == "100%", "loot: 100%")
    lootRow.level.minus.scripts.OnClick(lootRow.level.minus)
    assert(math.abs(Vol.Sound("loot") - 0.9) < 1e-9 and lootRow.level.value.text == "90%", "loot: 90%")
    Vol.SetSound("loot", 1)
    M.SetKind("feel")
    K.SetEnabled(false)
    io.write("PASS: helper cues: casts tighten R2, shots click it, low health shakes L2, clips and sounds queued, off by group" .. string.char(10))
    io.write("PASS: volumes: full by default, per moment and for every sound, as the cue's gain; on the rows" .. string.char(10))
end

-- Setup flow: moments numbered (append only), a sound per moment, WoW Helper's data, Edit HD, the export
do
    local K, C = ns.HelperLink, ns.HelperCues
    -- the numbers are on the wire: pinned
    assert(#C.MOMENTS <= 127, "moments fit 7 bits")
    local PIN = { autoAttack = 1, crit = 3, hitTaken = 11, spell = 22, jump = 32, eat = 42, rain = 47, levelUp = 52,
        loot = 53, whisper = 60, haloClose = 68, critTaken = 69, halo = 75, haloUse = 67 }
    for key, n in pairs(PIN) do assert(C.MOMENT_N[key] == n, "moment number moved: " .. key) end
    local seen = {}
    for n, m in ipairs(C.MOMENTS) do assert(not seen[m[1]], "moment twice: " .. m[1]); seen[m[1]] = n end
    -- every moment on the Rumble tab has a number
    for _, g in ipairs(ns.RumblePage.GROUPS) do
        for _, item in ipairs(g.items) do assert(C.MOMENT_N[item[2]], "no number: " .. item[2]) end
    end
    -- sounds: defaults, chosen, none, back to default
    assert(C.MomentSound("loot") == K.SOUNDS.coin and C.IsSoundDefault("loot"), "loot: coin by default")
    assert(C.MomentSound("jump") == nil, "jump: none")
    C.SetMomentSound("jump", 900)
    assert(C.MomentSound("jump") == 900 and not C.IsSoundDefault("jump"), "a chosen sound")
    C.SetMomentSound("loot", false)
    assert(C.MomentSound("loot") == nil, "loot: none")
    C.SetMomentSound("loot", nil)
    assert(C.MomentSound("loot") == K.SOUNDS.coin, "loot: default again")
    -- no data: no helper sounds, Edit HD says so
    WowHelperData = nil
    K.SetEnabled(true)
    assert(C.Data() == nil and #C.SoundList() == 6, "built-in sounds only")
    local ok, why = C.EditHD("loot")
    assert(not ok and why == "Needs WoW Helper", "Edit HD needs data: " .. tostring(why))
    -- data: sounds, HD, its own feel, a proposal for loot
    local lootFeel = C.MomentFeel("loot")
    assert(lootFeel, "loot has a feel")
    WowHelperData = { at = "2026-11-16 18:02", sounds = { { id = 900, name = "Far bell", group = "Quests" } },
        hd = { [lootFeel] = true }, gestures = { [3] = "Flick up" },
        feels = { hx_2048 = { label = "Coin tap 2", hd = 2048, from = lootFeel } },
        use = { loot = { feel = "hx_2048", base = lootFeel, stamp = 3 },
            money = { feel = "hx_2048", base = "not_its_feel", stamp = 3 } } }
    local d = C.Data()
    assert(d.at == "2026-11-16 18:02" and d.sounds == 1 and d.hd == 1, "data counts")
    assert(#C.SoundList() == 7 and C.SoundName(900) == "Far bell", "helper sounds listed")
    assert(C.HasHD(lootFeel) and C.HasHD("hx_2048") and not C.HasHD("nope"), "HD known")
    assert(C.GestureName(3) == "Flick up" and C.GestureName(4) == nil, "gesture names")
    assert(C.HDMode() == "auto", "HD auto")
    C.SetHDMode("off")
    assert(C.HDMode() == "off" and not C.Settings().hdFeels, "HD off")
    C.SetHDMode("auto")
    local moneyWas = C.MomentFeel("money")
    local critLight = C.MomentLight("crit")
    assert(critLight, "crit has a light")
    local other
    for _, l in ipairs(ns.Lights.Lights()) do if l.id ~= critLight then other = l.id; break end end
    WowHelperData.use.crit = { light = other, lightBase = critLight, stamp = 3 }
    WowHelperData.use.kill = { light = other, lightBase = -1, stamp = 3 }
    local killWas = C.MomentLight("kill")
    assert(C.LoadHelperData() == 2, "a feel and a light applied")
    assert(C.MomentLight("crit") == other and C.MomentLight("kill") == killWas, "light: applied where its base held")
    assert(H.Feel("hx_2048") and H.Feel("hx_2048").label == "Coin tap 2" and ns.HapticsLab.HdId("hx_2048") == 2048,
        "its feel joins, with its id")
    assert(C.MomentFeel("loot") == "hx_2048", "loot uses it")
    assert(C.MomentFeel("money") == moneyWas, "money changed since: left alone")
    -- once per stamp: a choice made in game after it stays
    C.SetMomentFeel("loot", lootFeel)
    assert(C.LoadHelperData() == 0 and C.MomentFeel("loot") == lootFeel, "applied once")
    -- Edit HD: one cue, the moment, open
    for i = #K.queue, 1, -1 do K.queue[i] = nil end
    ok = C.EditHD("loot")
    local q = K.queue[#K.queue]
    assert(ok and q.open and q.moment == C.MOMENT_N.loot and q.sound == K.SOUNDS.coin
        and q.touch == ns.HapticsLab.HdId(lootFeel), "Edit HD: the moment's cue, open")
    -- the export: moments with number, group, feel, sound; the data's stamp
    local ex = ns.HapticsLab.Export()
    assert(ex.moments.loot.n == 53 and ex.moments.loot.group == "Progress" and ex.moments.loot.feel == lootFeel
        and ex.moments.loot.sound == K.SOUNDS.coin and ex.moments.loot.label == "Loot", "moments exported")
    assert(ex.moments.crit.light == other and ex.moments.jump.light == false, "lights exported")
    assert(ex.helperData == "2026-11-16 18:02", "data seen, exported")
    K.SetEnabled(false)
    WowHelperData = nil
    io.write("PASS: setup flow: moments pinned, sounds per moment, WoW Helper data, proposals once, Edit HD, export" .. string.char(10))
end

-- Debug: the reasons, logged and shown
do
    local D = ns.HapticsDebug
    H.DB().engine = true
    L.EventSettings("whisper").on = true
    now = now + 2
    L.Fire("whisper")
    local text = D.Latest()
    assert(text and text:find("Whisper", 1, true), "a cue logged: " .. tostring(text))
    assert(D.VoiceWhy("live_rain"):find("Rain", 1, true), "weather voice named")
    assert(D.VoiceWhy("ev_loot"):find("Loot", 1, true), "event voice named")
    assert(D.Show(true) and GamepadCompanionHapticsDebug:IsShown(), "the window")
    D.Update()
    D.Show(false)
    io.write("PASS: debug: cues logged, voices named, the window" .. string.char(10))
end

-- Review fixes (0.20.0): the palette's feels under its specials, a copy of a Rumble feel yours in Rumble,
-- live voices stop when turned off or Rumble is off, and restart on a new feel
do
    local pw = GamepadCompanionPalette
    pw.pal:SetSpecials({ { key = "off", label = "Off" } })
    pw.pal:ShowGroup("Basics")
    local first = pw.pal.tiles[1]
    assert(first.points[1][5] <= -70, "feels under the specials: " .. tostring(first.points[1][5]))
    pw.pal:SetSpecials({})
    pw.pal:ShowGroup("Basics")
    assert(pw.pal.tiles[1].points[1][5] == 0, "no specials: feels on top")
    local own = ns.BetaPage.EditCopy(H.Feel("r_tick"), "Tick (mine)")
    assert(H.Feel(own).rumble == nil, "a copy is yours, not Rumble's")
    H.DB().feels.ownImported = { label = "Imported", rumble = "tick", pulses = { { 0, 0.05, 0.5, 0 } } }
    L.RegisterInRumble()
    assert(V.Pattern("x_" .. own) and V.Pattern("x_ownImported"), "your copies in Rumble's grid")
    H.DB().feels.ownImported = nil
    H.DB().engine = true
    V.Settings().enabled = true
    local zone = GetRealZoneText
    GetRealZoneText = function() return "Duskwood" end
    L.EventSettings("rain").on, L.EventSettings("rain").feel = true, "raindrops"
    L.Poll()
    assert(H.Playing("live_rain"), "rain in Duskwood")
    L.EventSettings("rain").on = false
    L.Poll()
    assert(not H.Playing("live_rain"), "rain off: stops while it still rains")
    L.EventSettings("rain").on = true
    L.Poll()
    assert(H.Playing("live_rain"), "and back")
    V.Settings().enabled = false
    L.Poll()
    assert(not H.Playing("live_rain"), "Rumble off: quiet")
    V.Settings().enabled = true
    L.Poll()
    L.EventSettings("rain").feel = "whisper"
    L.Poll()
    assert(H.Playing("live_rain"), "another feel: still raining")
    L.EventDefault("rain")
    GetRealZoneText = zone
    L.Poll()
    assert(not H.Playing("live_rain"), "left the zone: gone")
    io.write("PASS: review fixes: palette under its specials, your copies in Rumble, live voices stop when off" .. string.char(10))
end

-- The game's weather (C_Weather): rain brings rain, heavy rain thunder; clear: nothing
do
    if type(Enum) ~= "table" then Enum = {} end
    Enum.WeatherType = { Clear = 0, Rain = 1, Snow = 2, Sandstorm = 3 }
    local w = { 1, 0.3 }
    C_Weather = { GetCurrentWeather = function() return w[1], w[2] end }
    L.ReadWeather()
    local brings = L.Sky()
    assert(brings.rain and not brings.thunder, "light rain")
    w = { 1, 0.9 }; L.ReadWeather()
    brings = L.Sky()
    assert(brings.rain and brings.thunder, "heavy rain: thunder too")
    w = { 0, 0 }; L.ReadWeather()
    brings = L.Sky()
    assert(not brings.rain and not brings.snow, "clear: nothing")
    w = { 3, 0.5 }; L.ReadWeather()
    assert(L.Sky().sand, "a sandstorm")
    C_Weather = nil
    io.write("PASS: weather: the game's own, rain, heavy rain with thunder, clear, sandstorm" .. string.char(10))
end

-- The library written out for the helper
do
    SOUNDKIT = { LOOT_WINDOW_COIN_SOUND = 120, IG_MAINMENU_OPEN = 850, odd = "x" }
    local ex = L.Export()
    assert(ex.soundkits.LOOT_WINDOW_COIN_SOUND == 120 and ex.soundkits.IG_MAINMENU_OPEN == 850 and ex.soundkits.odd == nil,
        "the game's sound kits by name")
    SOUNDKIT = nil
    assert(ex.version == 1 and ex.feels.r_tick and ex.feels.r_tick.pulses and ex.feels.thud.pulses, "feels exported")
    assert(ex.events.levelUp ~= nil and ex.events.hit ~= nil, "what each event plays")
    -- each feel a stable HD id, 128-4095, unique, the same next time
    local seen = {}
    for key, f in pairs(ex.feels) do
        assert(type(f.hd) == "number" and f.hd >= 128 and f.hd <= 4095 and not seen[f.hd], "hd id: " .. key)
        seen[f.hd] = key
    end
    local again = L.Export()
    for key, f in pairs(ex.feels) do assert(again.feels[key].hd == f.hd, "hd id kept: " .. key) end
    local nextId = H.DB().hdIds.next
    assert(L.HdId("own_test_x") == nextId and L.HdId("own_test_x") == nextId, "a new feel: the next id, kept")
    H.DB().hdIds.own_test_x = nil
    io.write("PASS: export: every feel with its stable HD id, and each event's choice, for the helper" .. string.char(10))
end

-- Ambient voices step aside: rain dips while a jump plays
do
    H.Stop()
    H.DB().mix = "max"
    H.DB().minPulse = 0
    H.Fn("live_rain", function() return 0.5, 0.5 end, { ambient = true })
    frame(0.01)
    local alone = H.out.l
    H.Play({ hold = 0.3, peak = 0.3 }, { voice = "ev_jump" })
    frame(0.01); frame(0.01)
    local with = nil
    for _, v in ipairs(H.ActiveVoices()) do if v.id == "live_rain" then with = v.l end end
    assert(alone > 0.3 and with and with < 0.06, "rain under the jump: " .. tostring(alone) .. " -> " .. tostring(with))
    H.Stop()
    io.write("PASS: ambient: weather steps aside for everything else" .. string.char(10))
end

-- Battery: in a button, four steps and wired; the button's art with no reading
do
    local B = ns.Battery
    local level = 2
    C_GamePad.GetPowerLevel = function() return level end
    local button = CreateFrame("Button")
    local art = button:CreateTexture()
    local g = B.Attach(button, art)
    assert(g:IsShown() and not art:IsShown() and B.Name() == "Medium", "the battery instead of the art")
    assert(B.Look(0) == 1 and B.Look(4) == 4, "levels")
    level = 9
    B.Update()
    assert(not g:IsShown() and art:IsShown(), "no reading: the art")
    io.write("PASS: battery: in the icon, steps, wired, the art when unknown" .. string.char(10))
end

-- Water: wading steps instead of footsteps, splashes instead of thuds
do
    H.DB().engine = true
    V.Settings().enabled = true
    L.SetEngine(true)
    assert(L.IsWading(true, false) and not L.IsWading(true, true) and not L.IsWading(false, false)
        and not L.IsWading(nil, false), "wading: in water, not swimming")
    -- a wet step: a faint slap, a fainter spray, then nothing; faint micro taps
    assert(L.WetStep(0) == L.WET_SLAP and L.WetStep(0.12) == L.WET_SPRAY and L.WetStep(0.07) == 0
        and L.WetStep(0.3) == 0, "slap, spray")
    assert(L.WET_SLAP <= 0.15 and L.WET_SPRAY < L.WET_SLAP, "faint, contrast")
    local sub, swim, speed, fall = false, false, 7, false
    IsSubmerged = function() return sub end
    IsSwimming = function() return swim end
    IsFalling = function() return fall end
    GetUnitSpeed = function() return speed end
    IsMounted = function() return false end
    L.EventSettings("footsteps").on = true
    L.EventSettings("wading").on = true
    L.Poll()
    assert(H.Playing("live_footsteps") and not H.Playing("live_wading"), "on land: footsteps")
    sub = true
    L.Poll()
    assert(H.Playing("live_wading") and not H.Playing("live_footsteps"), "in shallow water: wading")
    assert(L.water.wading and L.water.submerged and L.water.api, "the water state, for the debug window")
    assert(ns.HapticsDebug.WaterText() == "Water: wading · submerged yes · swimming no", ns.HapticsDebug.WaterText())
    L.EventSettings("footsteps").on = false
    L.Poll()
    assert(H.Playing("live_wading"), "wading alone, land footsteps off")
    sub = false
    L.Poll()
    assert(not H.Playing("live_wading") and not H.Playing("live_footsteps"), "out of water, footsteps off: quiet")
    -- the wading feel: faint slaps a step apart
    local wade = H.Feel("wade")
    assert(wade and H.Peak(wade) <= 0.15, "the Wading feel is faint")
    -- landing in shallow water: a splash, not the thud
    local air = L.airFrame
    local played = {}
    local play = H.Play
    H.Play = function(feel, opts) played[#played + 1] = { feel = feel, voice = opts and opts.voice }; return play(feel, opts) end
    local function jump(seconds, deep)
        played = {}
        fall = true; air.scripts.OnUpdate(air, 0.01)
        now = now + seconds
        fall = false; air.scripts.OnUpdate(air, 0.01)
        if deep then swim = true end
        air.scripts.OnUpdate(air, 0.01)
        L.Poll()
        now = now + 0.2
    end
    sub = true
    jump(0.6)
    assert(#played == 1 and played[1].voice == "ev_landing" and L.lastLanding.feel == "Splash, shallow",
        "shallow water: a splash on the landing: " .. tostring(L.lastLanding.feel))
    assert(played[1].feel.pulses[1][3] < L.LandingFeel(L.LandingWeight(0.6)).pulses[1][3] + 0.01, "no harder than a thud")
    -- a jump into deep water: the swim starts a frame after the fall ends: one splash, no thud
    sub = false
    jump(2, true)
    assert(#played == 1 and played[1].voice == "ev_splash", "deep water: one splash: " .. #played)
    local big = played[1].feel
    swim = false; L.Poll(); now = now + 2
    jump(0.4, true)
    local small = played[1] and played[1].feel
    assert(small and big.pulses[1][2] > small.pulses[1][2] and big.pulses[1][3] > small.pulses[1][3]
        and #big.pulses > #small.pulses, "scaled by the air time")
    -- walking into deep water still splashes once
    swim = false; L.Poll(); now = now + 2
    played = {}
    swim = true; L.Poll()
    assert(#played == 1 and played[1].voice == "ev_splash", "walked in: Into water")
    H.Play = play
    swim, sub = false, false
    L.Poll()
    L.EventDefault("footsteps"); L.EventDefault("wading")
    IsSubmerged, IsSwimming, IsFalling = nil, nil, nil
    io.write("PASS: water: wading steps, shallow landing splash, one scaled splash into deep water" .. string.char(10))
end

-- Mining: a knock and a ring on each swing, in time from the cast's start, a crack on success
do
    H.DB().engine = true
    V.Settings().enabled = true
    L.SetEngine(true)
    local K, R = V.STRIKE_KNOCK, V.STRIKE_RING
    assert(V.StrikeEnv(0) == K and V.StrikeEnv(0.12) == R and V.StrikeEnv(0.07) == 0 and V.StrikeEnv(0.3) == 0,
        "a strike: knock, gap, ring, then still")
    assert(K <= 0.5 and R < 0.1, "a firm knock, a faint ring")
    assert(V.StrikeAt(0.3, 1, 0.5) == 0 and V.StrikeAt(1.51, 1, 0.5) == K and V.StrikeAt(2.62, 1, 0.5) == R,
        "strikes from the first one, a period apart")
    local p, o, synced = V.StrikeTiming("mining")
    assert(p == 1 and o == 0.5 and not synced, "a guess until set")
    V.SetStrikeTiming("mining", 1.2, nil)
    p, o = V.StrikeTiming("mining")
    assert(p == 1.2 and o == 0.5, "the swing set by hand")
    V.SetStrikeTiming("mining", 99, -1)
    p, o = V.StrikeTiming("mining")
    assert(p == 3 and o == 0, "kept in range")
    -- the fit: two casts, a strike missed in the second
    local fp, fo = V.FitStrikes({ { 0.6, 1.8, 3.0 }, { 0.6, 1.8, 4.2 } })
    assert(fp and math.abs(fp - 1.2) < 1e-6 and math.abs(fo - 0.6) < 1e-6, "period and first strike: "
        .. tostring(fp) .. " " .. tostring(fo))
    assert(V.FitStrikes({ { 0.6, 1.8 } }) == nil, "too few")
    -- a real mining cast (Match the action): strikes in time, then the crack
    V.Settings().strikes = {}
    V.SetCastPreset("gather", "auto")
    CraftFrame, TradeSkillFrame, ProfessionsFrame = false, false, false
    local rf
    for _, f in ipairs(created) do if f.events and f.events.START_AUTOREPEAT_SPELL and f.events.PLAYER_LEVEL_UP then rf = f end end
    local start = now
    UnitCastingInfo = function() return "Mining", nil, nil, start * 1000, (start + 3) * 1000 end
    rf.scripts.OnEvent(rf, "UNIT_SPELLCAST_START", "player", "cast-m", 2575)
    assert(V.castKind == "gather" and V.castAction == "mining", "mining known: " .. tostring(V.castAction))
    local shape = V.looping and V.looping.shape
    assert(shape, "mining strikes in time (a shape, not the looped pattern)")
    assert(shape(start + 0.3) == 0 and shape(start + 0.52) == K and shape(start + 1.52) == K
        and shape(start + 0.62) == R and shape(start + 0.8) == 0, "a strike on each swing")
    -- sync: squeeze R2 on the strikes, over two casts
    V.StrikeSync("mining")
    local said
    V.onStrikeSync = function(text) said = text end
    rf.scripts.OnEvent(rf, "UNIT_SPELLCAST_START", "player", "cast-m2", 2575)
    local depth = 0
    local axesFn = L.TriggerAxes
    L.TriggerAxes = function() return 0, depth end
    local strikeFrameUpdate = V.strikeFrame
    assert(strikeFrameUpdate:IsShown(), "the sync listens")
    local function squeeze(t) now = start + t; depth = 1; strikeFrameUpdate.scripts.OnUpdate(strikeFrameUpdate, 0.01)
        depth = 0; strikeFrameUpdate.scripts.OnUpdate(strikeFrameUpdate, 0.01) end
    squeeze(0.7); squeeze(1.9); squeeze(3.1)
    rf.scripts.OnEvent(rf, "UNIT_SPELLCAST_STOP", "player", "cast-m2")
    assert(said == "3 strikes: mine again", tostring(said))
    start = now + 1
    rf.scripts.OnEvent(rf, "UNIT_SPELLCAST_START", "player", "cast-m3", 2575)
    squeeze(0.7); squeeze(1.9); squeeze(3.1)
    rf.scripts.OnEvent(rf, "UNIT_SPELLCAST_STOP", "player", "cast-m3")
    p, o, synced = V.StrikeTiming("mining")
    assert(synced and math.abs(p - 1.2) < 1e-6 and math.abs(o - 0.7) < 1e-6, "synced: " .. p .. " " .. o)
    assert(not V.strikeSync and said:find("Synced", 1, true), "sync done")
    -- success: the crack
    start = now + 1
    rf.scripts.OnEvent(rf, "UNIT_SPELLCAST_START", "player", "cast-m4", 2575)
    local crack, release = V.Crack, V.Release
    local cracked, released = false, false
    V.Crack = function() cracked = true end
    V.Release = function() released = true end
    rf.scripts.OnEvent(rf, "UNIT_SPELLCAST_STOP", "player", "cast-m4")
    rf.scripts.OnEvent(rf, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-m4", 2575)
    assert(cracked and not released, "the ore cracks loose")
    V.Crack, V.Release = crack, release
    local l1, r1 = V.CrackAt(0.05)
    assert(l1 > 0.8 and r1 > 0.8 and V.CrackAt(0.7) == nil, "a crack, then done")
    UnitCastingInfo = nil
    V.Settings().strikes = {}
    V.onStrikeSync = nil
    L.TriggerAxes = axesFn
    io.write("PASS: mining: a knock and ring per swing from the cast start, sync by R2, a crack on success" .. string.char(10))
end
