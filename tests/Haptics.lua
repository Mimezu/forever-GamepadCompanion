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

for _, file in ipairs({ "Model.lua", "Shared.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "Haptics.lua",
    "HapticsLab.lua", "RumblePage.lua", "BetaPage.lua" }) do
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
assert(GamepadCompanionHapticsDB == db and db.engine == false, "own saved table, engine off")
near(H.Calibrated(2, 0.5), 0.5, "no floor by default: both grips felt from 5% in game")
assert(db.minPulse == 0.05 and db.version == 4, "taps held to 50 ms by default")
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
assert(seen == "hitTaken,avoid,uiError,loot,questDone,whisper", seen)
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
falling = false; air.scripts.OnUpdate(air, 0.01)
assert(L.lastLanding.feel == "Flick", "the feel played, named")
assert(math.abs(H.Peak(H.Feel("flick")) - 0.55) < 1e-9, "a feel's peak")
frame(0.01)
assert(H.out.l > 0.97 or H.out.r > 0.97, "a full landing: the feel's peak at full: " .. H.out.l .. " " .. H.out.r)
L.EventSettings("landing").feel = "thud"
local hop, fall = L.LandingFeel(L.LandingWeight(0.45)), L.LandingFeel(L.LandingWeight(2.5))
assert(#hop.pulses == 1 and hop.pulses[1][3] < 0.12, "a hop: one faint pulse")
assert(L.LandingLevel(0) < 0.1 and L.LandingLevel(1) == 1 and L.LandingLevel(0.5) < 0.4, "contrast: faint, then steep")
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

-- The Beta tab ----------------------------------------------------------------------------
ns.Shell.Open("beta")
local window, tabs = ns.ShellWindow()
assert(window:IsShown() and ns.Shell.Current() == "beta" and tabs.beta, "Beta tab")
local ui = ns.BetaPage
for _, key in ipairs({ "probes", "calibrate", "feels", "editor", "events", "light", "engine" }) do
    ui.Select(key)
    assert(ui.panels[key]:IsShown(), key .. " shown")
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
ui.Select("calibrate")
local find = assert(button("Find floor"), "Find floor")
find.scripts.OnClick(find)
assert(L.Ramping(), "ramping")
run(0.5)
L.ramp.level = 0.23
find.scripts.OnClick(find)
near(H.DB().floor[1], 0.23, "floor set")
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
ui.engine.checked = true
ui.engine.scripts.OnClick(ui.engine)
assert(H.Engine(), "engine on from the tab")
ui.engine.checked = false
ui.engine.scripts.OnClick(ui.engine)
assert(not H.Engine(), "and off")
io.write("PASS: Beta tab: seven sections, probe played and answered, floor found, editor shape to keys, recorded, engine switch\n")

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
ns.Shell.Open("beta"); ns.BetaPage.Select("probes")
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
io.write("PASS: review fixes: loop feels once end, engine off keeps Rumble's way, probes hold the motors\n")
