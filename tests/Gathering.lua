-- Gathering, end to end (2026-11-20, after "the crack no longer plays"): every gathering action
-- cast from its start to succeeded and stopped, its markers as WoW Helper expects them (the
-- shared scenarios: tests/fixtures/helperlink-gather-vectors.txt, written by WoW Helper), mining
-- timed by WoW Helper, fishing and mining apart, a silent fallback said in the log.
-- lua5.1 tests/Gathering.lua <addon folder>
-- (the game's stubs: as tests/Haptics.lua has them; the spells: as tests/MageCoverage.lua)
local root = arg[1] or "."
SPELLS = {}
local byId, kinds = {}, {}
for line in io.lines(root .. "/tests/fixtures/mage-spells.txt") do
    if not line:match("^#") then
        local f = {}
        for v in (line .. "	"):gmatch("([^	]*)	") do f[#f + 1] = v end
        local s = { id = tonumber(f[1]), name = f[2], line = f[3], school = tonumber(f[4]), cast = tonumber(f[5]),
            channel = f[6] == "1", helpful = f[7] == "1" }
        SPELLS[#SPELLS + 1] = s
        byId[s.id] = s
        if f[8] ~= "" then kinds[s.id] = { f[8], s.school, tonumber(f[9]) } end
    end
end
-- (the ranks no skill line lists, cast all the same: Arcane Missiles' top rank)
byId[25345] = byId[25345] or { id = 25345, name = "Arcane Missiles", cast = 0, channel = true }
-- (her professions)
for id, n in pairs({ [8613] = { "Skinning", 2000 }, [2575] = { "Mining", 3000 }, [3908] = { "Tailoring", 0 },
    [7620] = { "Fishing", 0 }, [2963] = { "Bolt of Linen Cloth", 3000 }, [3915] = { "Brown Linen Shirt", 5125 }, [2366] = { "Herb Gathering", 1500 } }) do
    byId[id] = { id = id, name = n[1], cast = n[2] }
end
function MageSpellInfo(id)
    local s = byId[id]
    if s then return s.name, nil, nil, s.cast end
    return "Spell " .. tostring(id)
end
WowHelperData = { spellKinds = kinds }
IsSpellHelpful = function(id) local s = byId[id]; return s and s.helpful or false end
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
GetSpellInfo = MageSpellInfo
LowHealthFrame, FrameGambitAPI, SettingsPanel, SOUNDKIT, GAMEPAD_MOD_LEFT = false, false, false, false, "SHIFT"
-- (any other game function the addon reads: a no-op. Only those listed in
-- tests/fixtures/game-globals.txt: any other capitalised global is an error, never
-- a silent no-op (night review 2 V-1: a local used before its declaration hid here))
local GAME_GLOBALS = {}
for line in io.lines(root .. "/tests/fixtures/game-globals.txt") do
    local name = line:match("^([%w_]+)")
    if name then GAME_GLOBALS[name] = true end
end
-- (the addon's SavedVariables: nil until the game loads them, as in the game)
local SAVED_VARS = {}
for line in io.lines(root .. "/GamepadCompanion.toc") do
    local list = line:match("^## SavedVariables[%w]*:%s*(.+)")
    if list then for name in list:gmatch("[%w_]+") do SAVED_VARS[name] = true end end
end
setmetatable(_G, { __index = function(_, key)
    if type(key) == "string" and key:match("^%u") and not key:match("^C_") and not key:match("^[A-Z_]+$") then
        if GAME_GLOBALS[key] then return function() end end
        if SAVED_VARS[key] then return nil end
        error("unknown global " .. key .. " (not the addon's, not in tests/fixtures/game-globals.txt)", 2)
    end
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

UnitName = function() return "Tester" end
GetRealmName = function() return "Noir" end
GamepadCompanionCharDB = { version = 1 }   -- (an existing character: the code's defaults, not Recommended)
for _, file in ipairs({ "Profiles.lua", "Model.lua", "Shared.lua", "TouchModel.lua", "Gestures.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "Haptics.lua", "Timing.lua", "Volume.lua",
    "HapticsLab.lua", "HelperLink.lua", "TriggerRules.lua", "Stack.lua", "Hush.lua", "LightPresets.lua", "Lights.lua", "HelperCues.lua", "FullFeel.lua", "TriggerStack.lua", "HapticsDebug.lua", "Battery.lua", "Staircase.lua", "HapticsUI.lua", "ProfileMenu.lua", "LightPicker.lua", "SpellOverrides.lua", "RumblePage.lua", "LearnedPage.lua", "BetaPage.lua", "SetupPage.lua", "GesturesPage.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local V, H, L = ns.Rumble, ns.Haptics, ns.HapticsLab
-- (timings tested exact: the motor and link leads tested on their own)
ns.Timing.MOTOR_LEAD, ns.Timing.LINK_DEFAULT = 0, 0
for _, f in ipairs(created) do
    if f.events and f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end
local V, H, L, C, K, T = ns.Rumble, ns.Haptics, ns.HapticsLab, ns.HelperCues, ns.HelperLink, ns.Timing
local function run(seconds, step)
    step = step or 0.01
    for _ = 1, math.floor(seconds / step + 0.5) do
        now = now + step
        for _, f in ipairs(created) do if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, step) end end
    end
end
V.Settings().enabled = true
CraftFrame, TradeSkillFrame, ProfessionsFrame = false, false, false
UnitClass = function() return "Mage", "MAGE" end
K.Enabled = function() return true end
C.Settings().hdFeels = true
V.SetCastPreset("gather", "auto")
-- (Alberich's mining sound, the user's: Pickaxe strike)
C.SetMomentSound("gather:mining", 1001)
local rf
for _, f in ipairs(created) do if f.events and f.events.START_AUTOREPEAT_SPELL and f.events.PLAYER_LEVEL_UP then rf = f end end
local function rev(...) rf.scripts.OnEvent(rf, ...) end
local marks, cues = {}, {}
local kmarker, cmoment = K.Marker, C.Moment
K.Marker = function(item) marks[#marks + 1] = item; return kmarker(item) end
C.Moment = function(key, feel, opts)
    -- (a cue sent; a marker's own item is built, not sent)
    if not (opts and opts.build) then cues[#cues + 1] = { key = key, feel = feel } end
    return cmoment(key, feel, opts)
end
local casting, chan
UnitCastingInfo = function() if casting then return "x", nil, nil, casting[1] * 1000, casting[2] * 1000 end end
UnitChannelInfo = function() if chan then return "x", nil, nil, chan[1] * 1000, chan[2] * 1000 end end
local SPELL = { mining = 2575, herbalism = 2366, skinning = 8613, fishing = 7620 }
local FEEL = { mining = "r_pickaxe", herbalism = "r_pluck", skinning = "r_skin" }
local function who(race, sex)
    UnitRace = function() return "R", "R", race end
    UnitSex = function() return sex end
end
-- WoW Helper's learned timing for this action, as its data addon has it (read by the real loader)
local function learned(key, first, period)
    WowHelperData = { spellKinds = WowHelperData and WowHelperData.spellKinds,
        strikeTiming = key and { [key] = { first = first, period = period, strikes = 30 } } or {} }
    T.LoadHelper()
end
-- a cast, start to end ("succeeded" or "stopped")
local function cast(action, ends)
    marks, cues = {}, {}
    now = now + 5
    casting = { now, now + 3.2 }
    rev("UNIT_SPELLCAST_START", "player", "g" .. action, SPELL[action])
    run(ends == "stopped" and 1 or 3.2)
    casting = nil
    if ends == "succeeded" then rev("UNIT_SPELLCAST_SUCCEEDED", "player", "g" .. action, SPELL[action])
    else rev("UNIT_SPELLCAST_INTERRUPTED", "player", "g" .. action, SPELL[action]) end
    rev("UNIT_SPELLCAST_STOP", "player", "g" .. action, SPELL[action])
    run(0.4)
    RunTimers()
end

---------------------------------------------------------------------------
-- 1. The shared scenarios (tests/fixtures/helperlink-gather-vectors.txt, WoW Helper's): each
-- replayed through a real cast; its marker as the file has it
---------------------------------------------------------------------------
local FIELDS = { "seq", "lmode", "lstart", "lfinish", "lforce", "rmode", "rstart", "rfinish", "rforce",
    "touch", "sound", "gain", "level", "side", "intensity", "seed", "mic", "moment", "open" }
local PHASE = { start = 0, succeeded = 1, stopped = 2 }
local n = 0
for row in io.lines(root .. "/tests/fixtures/helperlink-gather-vectors.txt") do
    if row:sub(1, 1) ~= "#" and row:find(":") then
        local action, phase, race, sex, carries, first, head, digits =
            row:match("^(%a+) (%a+) (%d+) (%d+) (%a+) (%d+) : (.-)%s*:%s*(%d+)%s*$")
        race, sex, first = tonumber(race), tonumber(sex), tonumber(first)
        local f, i = {}, 0
        for num in head:gmatch("%d+") do i = i + 1; f[FIELDS[i]] = tonumber(num) end
        assert(action and i == 19, "gather vector line: " .. row)
        -- (the cells: this addon's encoder, as WoW Helper's)
        local s = { seq = f.seq, left = {}, right = {}, touch = f.touch, sound = f.sound, gain = f.gain, level = f.level,
            side = f.side, intensity = f.intensity, seed = f.seed, mic = 0, moment = f.moment }
        local cells, out = K.EncodeV2(s), {}
        for c = 1, #cells do out[c] = tostring(cells[c][1] * 4 + cells[c][2] * 2 + cells[c][3]) end
        assert(table.concat(out) == digits, "gather vector cells: " .. row)
        -- the scenario: this race and sex (a Skyborne woman: race 95), the learned first strike
        -- (the new format, period 0: mining timed by its crack; the old, a period)
        who(race == 15 and 95 or race, sex)
        local key = T.HelperModel() .. "|" .. action
        if first == 127 then learned(nil) elseif action == "mining" then learned(key, first / 100, 0) else learned(key, first / 100, 1.4) end
        cast(action, phase == "stopped" and "stopped" or "succeeded")
        local m
        for _, q in ipairs(marks) do if q.moment == f.moment then m = q end end
        assert(m, row .. ": its marker " .. f.moment)
        assert(m.moment == V.GATHER_MARKERS[action] + PHASE[phase] and m.side == f.side and m.seed == f.seed and (m.level or 0) == 0,
            row .. ": side " .. tostring(m.side) .. " seed " .. tostring(m.seed))
        local touch, sound = m.touch or 0, m.sound or 0
        if carries == "strike" then
            assert(touch == L.HdId(FEEL[action]), row .. ": the start carries the strike's HD: " .. touch)
            assert((sound > 0) == (f.sound > 0), row .. ": and its sound: " .. sound)
            assert(sound == 0 or sound == f.sound, row .. ": the action's own sound")
        elseif carries == "finish" then
            assert(touch == L.HdId("r_peel") and sound == 0, row .. ": the finish")
        else
            assert(touch == 0 and sound == 0, row .. ": carries nothing: " .. touch .. " " .. sound)
        end
        n = n + 1
    end
end
assert(n == 11, "11 gather vectors: " .. n)
io.write("PASS: " .. n .. " shared gathering scenarios replayed: each marker as WoW Helper expects (Undead, Skyborne, learned old and new)\n")

---------------------------------------------------------------------------
-- 2. Mining, end to end: WoW Helper times it (the addon sends no strike, no crack); without the
-- link the addon plays both; a stop has no crack
---------------------------------------------------------------------------
who(5, 2)
learned(nil)
cast("mining", "succeeded")
for _, c in ipairs(cues) do assert(c.key ~= "gather:mining", "WoW Helper times mining: no strike cue from here") end
local enabled = K.Enabled
K.Enabled = function() return false end
cast("mining", "succeeded")
local strikes = 0
for _, c in ipairs(cues) do if c.key == "gather:mining" then strikes = strikes + 1 end end
assert(strikes == 2, "without the link: the strike and the crack from here: " .. strikes)
K.Enabled = enabled
cast("mining", "stopped")
assert(#marks == 2 and marks[2].moment == 102, "stopped: its marker, no succeeded")
io.write("PASS: mining: WoW Helper's strike and crack with the link, the addon's without; a stop is a stop\n")

---------------------------------------------------------------------------
-- 3. Fishing and mining never touch each other
---------------------------------------------------------------------------
marks, cues = {}, {}
now = now + 5
chan = { now, now + 20 }
rev("UNIT_SPELLCAST_CHANNEL_START", "player", "fish", 7620)
run(2)
chan = nil
rev("UNIT_SPELLCAST_CHANNEL_STOP", "player", "fish", 7620)
run(0.4)
for _, q in ipairs(marks) do assert(q.moment < 100 or q.moment > 109, "fishing: no gathering marker (" .. q.moment .. ")") end
for _, c in ipairs(cues) do
    assert(c.key ~= "gather:mining" and c.feel ~= "r_pickaxe", "fishing: nothing of mining's")
end
assert(C.MomentSound("gather:fishing") ~= 1001, "fishing's sound is never the pickaxe")
cast("mining", "succeeded")
for _, c in ipairs(cues) do assert(c.key ~= "gather:fishing" and c.feel ~= "r_flick", "mining: nothing of fishing's") end
io.write("PASS: fishing and mining: no marker, cue, feel or sound of the other\n")

---------------------------------------------------------------------------
-- 4. A silent fallback is said once, in the timing log
---------------------------------------------------------------------------
V.gatherFallbacks = {}
C.Settings().hdFeels = false
C.SetMomentSound("gather:mining", false)
cast("mining", "succeeded")
cast("mining", "succeeded")
local said = 0
for _, line in ipairs(T.Store().log) do if line:find("^mining: the addon plays the strikes") then said = said + 1 end end
assert(V.gatherFallbacks.mining and said == 1, "a start with nothing to carry: said once: " .. said)
C.Settings().hdFeels = true
C.SetMomentSound("gather:mining", 1001)
K.Marker, C.Moment = kmarker, cmoment
io.write("PASS: a gathering start with nothing to carry is said once in the timing log\n")
