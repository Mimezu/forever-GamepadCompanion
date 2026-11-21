-- Paladin coverage: every paladin spell in WoW Forever and what it plays (the paladin pass,
-- 2026-11-20). The spells are the client's own (tests/fixtures/paladin-spells.txt, from WoW Helper's
-- --spells and --spell-kinds, the runes and the class mounts); each must play its own feel, none
-- generic. The feels a paladin had before stay as they were. Then the new ones played out:
-- Consecration's ground each second, Avenger's Shield and Exorcism at the wound, Redemption's
-- release, the steed's hooves.
-- lua5.1 tests/PaladinCoverage.lua <addon folder> [list]
-- (the game's stubs: as tests/MageCoverage.lua has them)
local root = arg[1] or "."
SPELLS = {}
local byId, kinds = {}, {}
for line in io.lines(root .. "/tests/fixtures/paladin-spells.txt") do
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
-- (the gatherings and a craft: Rumble reads their names)
for id, n in pairs({ [8613] = { "Skinning", 2000 }, [2575] = { "Mining", 3000 }, [3908] = { "Tailoring", 0 },
    [2963] = { "Bolt of Linen Cloth", 3000 }, [3915] = { "Brown Linen Shirt", 5125 }, [2366] = { "Herb Gathering", 1500 } }) do
    byId[id] = { id = id, name = n[1], cast = n[2] }
end
function PaladinSpellInfo(id)
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
GetSpellInfo = PaladinSpellInfo
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
for _, file in ipairs({ "Profiles.lua", "Model.lua", "Shared.lua", "TouchModel.lua", "Gestures.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "Paladin.lua", "Haptics.lua", "Timing.lua", "Volume.lua",
    "HapticsLab.lua", "HelperLink.lua", "TriggerRules.lua", "Stack.lua", "Hush.lua", "LightPresets.lua", "Lights.lua", "HelperCues.lua", "Hunter.lua", "FullFeel.lua", "TriggerStack.lua", "HapticsDebug.lua", "Battery.lua", "Staircase.lua", "HapticsUI.lua", "ProfileMenu.lua", "LightPicker.lua", "SpellOverrides.lua", "RumblePage.lua", "LearnedPage.lua", "BetaPage.lua", "SetupPage.lua", "GesturesPage.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local V, H, L = ns.Rumble, ns.Haptics, ns.HapticsLab
-- (timings tested exact: the motor and link leads tested on their own)
ns.Timing.MOTOR_LEAD, ns.Timing.LINK_DEFAULT = 0, 0
for _, f in ipairs(created) do
    if f.events and f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end
local function near(a, b, eps, msg) assert(math.abs(a - b) < (eps or 1e-6), (msg or "") .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
local function run(seconds, step)
    step = step or 0.01
    for _ = 1, math.floor(seconds / step + 0.5) do
        now = now + step
        for _, f in ipairs(created) do
            if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, step) end
        end
    end
end
local V, H, L, C, K = ns.Rumble, ns.Haptics, ns.HapticsLab, ns.HelperCues, ns.HelperLink
local PD = ns.Paladin
V.Settings().enabled = true
UnitRace = function() return "Human", "Human", 1 end
UnitSex = function() return 2 end
UnitClass = function() return "Paladin", "PALADIN" end
CraftFrame, TradeSkillFrame, ProfessionsFrame = false, false, false

---------------------------------------------------------------------------
-- 1. Coverage: every paladin spell the client has, and what it plays
---------------------------------------------------------------------------
-- (never cast by the player: the debuffs a Judgement lays, a talent's proc)
local TRIGGERED = { ["Judgement of Justice"] = true, ["Judgement of Light"] = true, ["Judgement of Wisdom"] = true,
    ["Judgement of the Crusader"] = true, ["Vindication"] = true }
-- (by ID: Flash of Light's heal over time (the instant ranks the book lists), Divine Storm's heal)
local function Triggered(s)
    return TRIGGERED[s.name] or (s.name == "Flash of Light" and s.cast == 0) or s.id == 407784
end
-- (the feels a paladin had before this pass: kept as they were)
local BEFORE = {
    ["Blessing of Freedom"] = "cast:seal", ["Blessing of Kings"] = "cast:seal", ["Blessing of Might"] = "cast:seal",
    ["Blessing of Wisdom"] = "cast:seal", ["Blessing of Protection"] = "cast:ward", ["Cleanse"] = "cast:mend",
    ["Purify"] = "cast:mend", ["Consecration"] = "cast:surge", ["Divine Protection"] = "cast:ward",
    ["Divine Shield"] = "cast:ward", ["Holy Shield"] = "cast:ward", ["Hammer of Justice"] = "cast:bash",
    ["Rebuke"] = "cast:bash", ["Repentance"] = "cast:judge", ["Lay on Hands"] = "cast:rise",
    ["Holy Shock"] = "hit:shock", ["Judgement"] = "hit:judge", ["Holy Strike"] = "hit:judge",
    ["Crusader Strike"] = "hit:judge", ["Divine Storm"] = "hit:judge", ["Eye for an Eye"] = "hit:judge",
    ["Hammer of the Righteous"] = "hit:judge", ["Judgement of Command"] = "hit:judge",
    ["Judgement of Fury"] = "hit:judge", ["Judgement of Martyrdom"] = "hit:judge",
    ["Judgement of Righteousness"] = "hit:judge", ["Righteous Judgement"] = "hit:judge",
    ["Shield of Righteousness"] = "hit:judge", ["Swift Judgement"] = "hit:judge",
    ["Seal of Command"] = "cast:seal", ["Seal of Justice"] = "cast:seal", ["Seal of Light"] = "cast:seal",
    ["Seal of Martyrdom"] = "cast:seal", ["Seal of Righteousness"] = "cast:seal", ["Seal of Wisdom"] = "cast:seal",
    ["Seal of the Crusader"] = "cast:seal",
    ["Divine Light"] = "set:healing", ["Flash of Light"] = "set:healing", ["Holy Light"] = "set:healing",
    ["Light's Vigil"] = "set:healing", ["Hammer of Wrath"] = "set:holy", ["Holy Wrath"] = "set:holy",
}
-- (the gaps this pass filled)
local ADDED = {
    ["Devotion Aura"] = "cast:aura", ["Retribution Aura"] = "cast:aura", ["Concentration Aura"] = "cast:aura",
    ["Fire Resistance Aura"] = "cast:aura", ["Frost Resistance Aura"] = "cast:aura",
    ["Shadow Resistance Aura"] = "cast:aura", ["Divine Sacrifice"] = "cast:aura", ["Horn of Lordaeron"] = "cast:aura",
    ["Voice of Truth"] = "cast:aura", ["Aura Mastery"] = "cast:empower", ["Righteous Fury"] = "cast:empower",
    ["Inspiration Exemplar"] = "cast:empower", ["Avenging Wrath"] = "cast:wings",
    ["Greater Blessing of Kings"] = "cast:seal", ["Greater Blessing of Might"] = "cast:seal",
    ["Greater Blessing of Wisdom"] = "cast:seal", ["Blessing of Sacrifice"] = "cast:seal",
    ["Hand of Sacrifice"] = "cast:seal", ["Seal of Fury"] = "cast:seal", ["Oath of Light"] = "cast:seal",
    ["Divine Favor"] = "cast:glow", ["Beacon of Light"] = "cast:glow", ["Divine Intervention"] = "cast:ward",
    ["Sacred Shield"] = "cast:ward", ["Templar's Bulwark"] = "cast:ward", ["Sense Undead"] = "cast:micro",
    ["Hand of Reckoning"] = "cast:micro", ["Avenger's Shield"] = "hit:avenger", ["Exorcism"] = "hit:exorcism",
    ["Redemption"] = "burst:raise", ["Turn Undead"] = "burst:turn", ["Summon Warhorse"] = "burst:hooves",
    ["Summon Charger"] = "burst:hooves",
}
local EXPECT = {}
for k, v in pairs(BEFORE) do EXPECT[k] = v end
for k, v in pairs(ADDED) do assert(not EXPECT[k], k .. ": before and added"); EXPECT[k] = v end

local function Plays(s)
    local r = V.SpellRule(s.id, s.channel and 1 or s.cast / 1000)
    if not r then return "none" end
    if r.moment == "spell" then
        local m = r.mage
        if m and m.burst then return "burst:" .. m.burst, r end
        if m and m.impact then return "impact:" .. m.impact, r end
        return "set:" .. tostring(r.set), r
    end
    if r.moment == "quiet" then return "quiet", r end
    return (r.when == "hit" and "hit:" or "cast:") .. tostring(r.move), r
end

local lines, wrong, seen, ids = {}, {}, {}, 0
for _, s in ipairs(SPELLS) do
    local got, r = Plays(s)
    ids = ids + 1
    lines[#lines + 1] = ("%7d  %-30s %s"):format(s.id, s.name, Triggered(s) and "never cast (triggered)" or got)
    if not Triggered(s) then
        if EXPECT[s.name] ~= got then wrong[#wrong + 1] = s.id .. " " .. s.name .. ": " .. got .. " (expected " .. tostring(EXPECT[s.name]) .. ")" end
        if got == "set:sweep" or got == "cast:blow" or got == "hit:blow" or got == "quiet" or (r and r.guessed) then
            wrong[#wrong + 1] = s.id .. " " .. s.name .. ": " .. got .. " is generic"
        end
        local pattern = got:match(":(.+)$")
        if pattern and got:sub(1, 4) ~= "set:" then
            assert(V.PULSES[pattern], s.name .. ": no pulses for " .. pattern)
            assert(H.Feel("r_" .. pattern), s.name .. ": no library feel r_" .. pattern)
        end
        seen[s.name] = true
    end
end
assert(#wrong == 0, "paladin spells that play something else:\n  " .. table.concat(wrong, "\n  "))
for key in pairs(EXPECT) do assert(seen[key], "expected but not in the client's list: " .. key) end
if arg[2] == "list" then io.write(table.concat(lines, "\n"), "\n") end
-- (the loops: the steed's own; Turn Undead's Holy, not Nature by its school; Redemption's Holy)
local function SetOf(id) return V.SpellRule(id, byId[id].cast / 1000).set end
assert(SetOf(13819) == "feel:steed" and SetOf(23214) == "feel:steed", "the steed called")
assert(SetOf(2878) == "holy" and SetOf(7328) == "holy", "Turn Undead and Redemption: Holy")
-- (every new feel exists, rumble and HD; every step 0.1 s or more)
for _, p in ipairs(PD.PATTERNS) do
    assert(V.PULSES[p.key] and H.Feel("r_" .. p.key), p.key .. ": pulses and its HD library feel")
    for _, st in ipairs(p.steps) do assert(st[3] >= 0.1, p.key .. ": every step 0.1 s or more") end
end
io.write("PASS: " .. ids .. " paladin spell IDs (every rank, runes, mounts): each its own feel, none generic; the old ones kept\n")

---------------------------------------------------------------------------
-- 2. Play: the new ones as they happen (events in, rumble and HD out)
---------------------------------------------------------------------------
local rf
for _, fr in ipairs(created) do if fr.events and fr.events.START_AUTOREPEAT_SPELL and fr.events.PLAYER_LEVEL_UP then rf = fr end end
local function rev(...)
    rf.scripts.OnEvent(rf, ...)
    PD.frame.scripts.OnEvent(PD.frame, ...)
end
local hd, moments, played = {}, {}, {}
local cFeel, cMoment, vplay = C.Feel, C.Moment, V.Play
C.Feel = function(key, gain, side) hd[#hd + 1] = { t = now, key = key, gain = gain, side = side } end
C.Moment = function(key, feel, opts) moments[#moments + 1] = { t = now, key = key, feel = feel }; return cMoment(key, feel, opts) end
V.Play = function(key, loop, shape) played[#played + 1] = { t = now, key = key, loop = loop, shape = shape }; return vplay(key, loop, shape) end
UnitCanAttack = function() return true end
local casting
UnitCastingInfo = function() if casting then return "x", nil, nil, casting[1] * 1000, casting[2] * 1000 end end
local fired = {}
local vfire = V.Fire
V.Fire = function(key, ...) if key == "instant" then fired[#fired + 1] = { t = now, move = V.instantMove } end; return vfire(key, ...) end
local function instant(id, woundAfter, school, result)
    fired, moments, hd, played = {}, {}, {}, {}
    now = now + 10
    rev("UNIT_SPELLCAST_SUCCEEDED", "player", "i" .. id, id)
    if woundAfter then run(woundAfter); rev("UNIT_COMBAT", "target", "WOUND", result or "", 100, school) end
    run(0.3)
    RunTimers()
    return fired
end
local function HdOf()
    for _, e in ipairs(moments) do if e.feel then return e.feel end end
end

-- At the cast: each its own, its HD with it
for id, move in pairs({ [465] = "aura", [7294] = "aura", [407788] = "wings", [25780] = "empower", [25898] = "seal",
    [20163] = "seal", [20216] = "glow", [19752] = "ward", [5502] = "micro" }) do
    local f = instant(id)
    assert(#f == 1 and f[1].move == move, byId[id].name .. ": " .. move .. " at the cast, got " .. tostring(f[1] and f[1].move))
    assert(HdOf() == "r_" .. move, byId[id].name .. ": its HD r_" .. move .. " " .. tostring(HdOf()))
end
-- (a higher rank, by its name: Devotion Aura's top rank)
local f = instant(10293)
assert(#f == 1 and f[1].move == "aura", "Devotion Aura, its top rank")
-- The old ones as they were: a seal, Hammer of Justice, Divine Shield, Lay on Hands, Consecration laid down
for id, move in pairs({ [20154] = "seal", [853] = "bash", [642] = "ward", [633] = "rise", [26573] = "surge" }) do
    f = instant(id)
    assert(#f == 1 and f[1].move == move, byId[id].name .. ": still " .. move)
end
f = instant(20271, 0.3, 2)
assert(#f == 1 and f[1].move == "judge", "Judgement: at its blow")
-- (a seal, then its Judgement right after: both, the gap per ability)
fired = {}
now = now + 10
rev("UNIT_SPELLCAST_SUCCEEDED", "player", "s", 20154)
now = now + 0.05
rev("UNIT_SPELLCAST_SUCCEEDED", "player", "j", 20271)
run(0.2); rev("UNIT_COMBAT", "target", "WOUND", "", 100, 2); run(0.3); RunTimers()
assert(#fired == 2 and fired[1].move == "seal" and fired[2].move == "judge", "a seal, then Judgement: both")
-- As they land: Avenger's Shield and Exorcism, at the wound; a crit its own impact
f = instant(470264, 0.6, 2)
assert(#f == 1 and f[1].move == "avenger", "Avenger's Shield at its hit: " .. tostring(f[1] and f[1].move))
f = instant(470264, 0.6, 1)
assert(#f == 0, "a physical wound isn't the shield's (a swing)")
f = instant(10314, 0.2, 2)
assert(#f == 1 and f[1].move == "exorcism", "Exorcism, any rank, at its hit")
f = instant(415068, 0.2, 2, "CRITICAL")
assert(#f >= 1 and f[1].move == "exorcism", "Exorcism's crit: its own impact")

-- Casts: the loop, then the release's own (no wait for a wound)
local function cast(id, seconds)
    played, hd = {}, {}
    now = now + 10
    casting = { now, now + seconds }
    rev("UNIT_SPELLCAST_START", "player", "k" .. id, id)
    local loop = V.looping and V.looping.pattern
    run(seconds)
    casting = nil
    rev("UNIT_SPELLCAST_SUCCEEDED", "player", "k" .. id, id)
    rev("UNIT_SPELLCAST_STOP", "player", "k" .. id, id)
    run(0.3)
    RunTimers()
    return loop, played[#played] and played[#played].key
end
local loop, last = cast(13819, 3)
assert(loop == "steed" and last == "hooves", "Summon Warhorse: hoofbeats, then the steed there: " .. tostring(loop) .. " " .. tostring(last))
loop, last = cast(23214, 3)
assert(loop == "steed" and last == "hooves", "Summon Charger")
loop, last = cast(7328, 10)
assert(loop == "radiance" and last == "raise", "Redemption: Holy's radiance, a soul drawn back: " .. tostring(loop) .. " " .. tostring(last))
loop, last = cast(2878, 1.5)
assert(loop == "radiance" and last == "turn", "Turn Undead: Holy, the flash")
io.write("PASS: auras, wings, the blessings and seals at the cast (HD each its own); the old ones kept; Avenger's Shield and Exorcism at the wound; Redemption, Turn Undead, the steeds at the release\n")

---------------------------------------------------------------------------
-- 3. Consecration: laid down (Surge), then its ground each second you stand in it
---------------------------------------------------------------------------
local px, py
UnitPosition = function() if px then return py, px, 0, 0 end end
local mounted = false
IsMounted = function() return mounted end
local function consecrate(walk)
    fired, hd, played = {}, {}, {}
    now = now + 20
    local t0 = now
    rev("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 20924)
    for _ = 1, 950 do
        now = now + 0.01
        if walk then walk(now - t0) end
        for _, fr in ipairs(created) do if fr.shown and fr.scripts.OnUpdate then fr.scripts.OnUpdate(fr, 0.01) end end
    end
    local ticks = {}
    for _, e in ipairs(hd) do if e.key == "r_hallow" then ticks[#ticks + 1] = { e.t - t0, e.gain, e.side } end end
    local rumbles = 0
    for _, p in ipairs(played) do if p.key == "hallow" then rumbles = rumbles + 1 end end
    return ticks, rumbles
end
-- (where the client hides your position: every tick)
px = nil
local ticks, rumbles = consecrate()
assert(fired[1] and fired[1].move == "surge", "laid down: Surge, as before")
assert(#ticks == 8 and rumbles == 8, "eight ticks, rumble and HD: " .. #ticks .. " " .. rumbles)
for i, e in ipairs(ticks) do near(e[1], i, 0.02, "tick " .. i .. " on its second") end
assert(ticks[1][3] < 0 and ticks[2][3] > 0 and ticks[3][3] < 0, "by turns from either hand")
for _, e in ipairs(ticks) do assert(math.abs(e[3]) <= 0.45, "near the middle: the ground under you") end
-- (standing in it: full; walked out after 3 s: no more)
px, py = 0, 0
ticks = consecrate(function(t) if t > 3.5 then px = 20 end end)
assert(#ticks == 3, "walked out after three: " .. #ticks)
near(ticks[1][2], 1, 1e-6, "at its middle: full")
-- (towards its edge: fainter)
px, py = 0, 0
ticks = consecrate(function(t) if t > 0.5 then px = 6 end end)
assert(#ticks == 8 and ticks[1][2] < 0.7 and ticks[1][2] > 0.5, "near the edge: fainter: " .. tostring(ticks[1] and ticks[1][2]))
-- (mounted: it stops)
px, py = 0, 0
ticks = consecrate(function(t) mounted = t > 2.5 end)
mounted = false
assert(#ticks == 2, "mounted at 2.5 s: two ticks: " .. #ticks)
-- (Your abilities off: nothing)
local ev = V.Settings().events
local wasOn = ev.instant and ev.instant.on
ev.instant = ev.instant or {}
ev.instant.on = false
px = nil
ticks = consecrate()
assert(#ticks == 0, "Your abilities off: no ticks")
ev.instant.on = wasOn
-- (each tick small: a faint ground, never a blow)
for _, p in ipairs(V.PULSES.hallow) do assert(p[3] <= 0.15, "faint") end
io.write("PASS: Consecration: Surge as laid down, then its ground each second for 8 s, by turns, fainter at its edge, none once out, mounted or off\n")

---------------------------------------------------------------------------
-- 4. Another class: none of the paladin's rules
---------------------------------------------------------------------------
UnitClass = function() return "Mage", "MAGE" end
assert(PD.Of(10293) == nil, "a mage: no paladin rule by name")
assert(PD.Of(465) == nil, "nor by its ID")
UnitClass = function() return "Paladin", "PALADIN" end
assert(PD.Of(10293) ~= nil, "a paladin: by name, every rank")
C.Feel, C.Moment, V.Play, V.Fire = cFeel, cMoment, vplay, vfire
io.write("PASS: the paladin's names only for a paladin\n")
