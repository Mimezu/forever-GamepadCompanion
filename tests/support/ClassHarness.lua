-- The game stood in for a class test (tests/Warrior.lua, tests/Rogue.lua): the stubs tests/Hunter.lua
-- uses, then the addon loaded with its class files. dofile it; it returns T (see the end).
-- (in tests/support: not a test of its own)
local root = arg[1] or "."
local ns = {}
local now = 100
local created = {}
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
GamepadCompanionCharDB = nil
Halo = { On = function() end }

local T = { failures = 0, checks = 0 }
function T.check(ok, label)
    T.checks = T.checks + 1
    if not ok then T.failures = T.failures + 1; io.write("FAIL: " .. label .. "\n") end
end
function T.eq(a, b, label) T.check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- The class's spells (tests/fixtures/<class>-spells.txt): every rank, its name, cast and what it plays
local SPELLS, NAME, CAST = {}, {}, {}
T.SPELLS, T.NAME, T.CAST = SPELLS, NAME, CAST
function T.LoadSpells(file)
    for line in io.lines(root .. "/tests/fixtures/" .. file) do
        if not line:match("^#") then
            local f = {}
            for v in (line:gsub("\r$", "") .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
            local s = { id = tonumber(f[1]), name = f[2], line = f[3], school = tonumber(f[4]), ms = tonumber(f[5]),
                channel = f[6] == "1", helpful = f[7] == "1", letters = f[8], tick = tonumber(f[9]), want = f[10] }
            SPELLS[#SPELLS + 1] = s
            NAME[s.id], CAST[s.id] = s.name, s.ms
        end
    end
end
-- (other spells the addon names: theirs, so name lookups never collide)
local OTHER = { [6603] = "Attack", [5019] = "Shoot", [3018] = "Shoot", [2480] = "Shoot Bow", [7918] = "Shoot Gun",
    [7919] = "Shoot Crossbow", [2764] = "Throw", [7922] = "Charge Stun", [20253] = "Intercept Stun",
    [20614] = "Intercept Stun", [20615] = "Intercept Stun", [2842] = "Poisons", [7411] = "Enchanting",
    [3365] = "Opening", [2575] = "Mining", [2366] = "Herb Gathering", [8613] = "Skinning" }
GetSpellInfo = function(id) return NAME[id] or OTHER[id] or ("Spell " .. tostring(id)), nil, nil, CAST[id] or 0 end
IsSpellHelpful = function(id)
    for _, s in ipairs(SPELLS) do if s.id == id then return s.helpful end end
    return false
end

-- The player, the target, the auras, the combo points, Stealth, a trade window
local game = { class = "WARRIOR", auras = {}, combo = 0, stealthed = false, trade = nil }
T.game = game
UnitClass = function() return game.class, game.class end
UnitExists = function(u) return u == "player" or u == "target" end
UnitGUID = function() return "Player-1" end
UnitIsDead = function() return false end
UnitIsDeadOrGhost = function() return false end
UnitHealthMax = function() return 3000 end
UnitIsUnit = function(a, b) return a == b end
UnitAffectingCombat = function() return true end
UnitCanAttack = function() return true end
GetComboPoints = function() return game.combo end
UnitPower = function(_, kind) if kind == 4 then return game.combo end return 50 end
UnitPowerMax = function(_, kind) if kind == 4 then return 5 end return 100 end
IsStealthed = function() return game.stealthed end
C_UnitAuras = { GetAuraDataByIndex = function(unit, i)
    local a = (game.auras[unit] or {})[i]
    if a then return { name = NAME[a.id] or OTHER[a.id], spellId = a.id, sourceUnit = a.source } end
end }
GetTime = function() return now end
function T.Now() return now end
function T.Advance(s) now = now + s end
TradeSkillFrame = { IsShown = function() return game.trade ~= nil end }
GetTradeSkillLine = function() return game.trade end
CraftFrame, ProfessionsFrame = false, false
-- (WoW Forever: no combat log, UNIT_COMBAT instead)
CombatLogGetCurrentEventInfo = false

-- The addon, the class files with it (before Rumble.lua, as the TOC loads them)
for _, file in ipairs({ "Model.lua", "Shared.lua", "When.lua", "OptionsSkin.lua", "Window.lua", "ClassFeels.lua",
    "Warrior.lua", "Rogue.lua", "Rumble.lua", "Haptics.lua", "Timing.lua", "Volume.lua", "SpellOverrides.lua",
    "HapticsLab.lua", "HelperLink.lua", "Stack.lua", "Hush.lua", "LightPresets.lua", "Lights.lua", "HelperCues.lua",
    "Hunter.lua", "FullFeel.lua", "Profiles.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
for _, f in ipairs(created) do
    if f.events and f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end
T.ns, T.V, T.L, T.H, T.CF = ns, ns.Rumble, ns.HapticsLab, ns.Haptics, ns.ClassFeels

-- What a rule plays, in the fixture's words
function T.Plays(r)
    if not r then return "nothing (no rule)" end
    if r.moment == "shot" then return "shot" end
    if r.moment == "spell" then return "cast " .. tostring(r.set) end
    if r.moment == "quiet" then return "quiet" end
    if r.moment == "craft" or r.moment == "gather" then return r.moment end
    if r.moment == "instant" and r.next then return "next " .. tostring(r.pattern) end
    if r.moment == "instant" then
        return "instant " .. tostring(r.pattern) .. " " .. tostring(r.when) .. (r.how and r.how.ranged and " ranged" or "")
    end
    return tostring(r.moment)
end

-- Every event to every frame that listens (the class files' own frames too)
function T.Event(event, ...)
    for _, f in ipairs(created) do
        if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
-- C_Timer's queue, run
T.Run = RunTimers

-- Coverage: every spell of the fixture plays what it says, twice (without, then with WoW
-- Helper's spell kinds); none a guess, the fallback set or the generic Blow; every pattern
-- with its pulses and its library feel, every set a real one. A spell new to the fixture
-- with no expectation fails.
local function RuleAsCast(s)
    return T.V.SpellRule(s.id, (s.ms > 0 or s.channel) and math.max(s.ms, 1000) / 1000 or 0)
end
function T.Coverage(class, report)
    local V, H = T.V, T.H
    game.class = class
    for pass = 1, 2 do
        if pass == 2 then
            local kinds = {}
            for _, s in ipairs(SPELLS) do if s.letters ~= "" then kinds[s.id] = { s.letters, s.school, s.tick } end end
            WowHelperData = { at = "test", spellKinds = kinds }
        end
        for _, s in ipairs(SPELLS) do
            local craft, gather = s.want:match("^craft (%a+)"), s.want:match("^gather (%a+)")
            game.trade = craft and "Poisons" or nil
            local r = RuleAsCast(s)
            local got = T.Plays(r)
            local want = (craft and "craft") or (gather and "gather") or s.want
            T.check(want ~= nil and want ~= "", s.name .. " (" .. s.id .. ") has an expectation")
            T.eq(got, want, class .. " pass " .. pass .. ": " .. s.name .. " (" .. s.id .. ")")
            T.check(not (r and r.guessed), s.name .. ": not a guess")
            T.check(not (r and r.moment == "spell" and r.set == "sweep"), s.name .. ": not the fallback set")
            T.check(not (r and r.moment == "instant" and r.pattern == "blow"), s.name .. ": not the generic Blow")
            local pat = r and r.pattern
            if pat then
                T.check(V.PULSES[pat] ~= nil, s.name .. ": " .. pat .. " has pulses")
                T.check(H.Feel("r_" .. pat) ~= nil, s.name .. ": r_" .. pat .. " is in the library")
            end
            if r and r.moment == "spell" then
                local found = false
                for _, p in ipairs(V.CAST_PRESETS) do if p.key == r.set then found = true end end
                T.check(found, s.name .. ": its set " .. tostring(r.set) .. " exists")
            end
            if pass == 1 and report then io.write(string.format("%-8d %-28s %s\n", s.id, s.name, got)) end
        end
        game.trade = nil
    end
    WowHelperData = nil
end

-- What fires: Rumble's moments and V.Play, the Lab's
T.fired, T.gains = {}, {}
function T.Capture()
    local V, L = T.V, T.L
    V.Settings().enabled = true
    V.Fire = function(key)
        T.fired[#T.fired + 1] = key .. (key == "instant" and (":" .. tostring(V.instantMove)) or "")
        T.gains[#T.fired] = V.fireGain or 1
    end
    V.Play = function(key) T.fired[#T.fired + 1] = "play:" .. tostring(key) end
    L.Fire = function(key) T.fired[#T.fired + 1] = "lab:" .. key end
end
function T.Has(what) for _, f in ipairs(T.fired) do if f == what then return true end end return false end
function T.Clear() T.fired, T.gains = {}, {} end
-- The gain the last time this fired with (1: full; nil: it didn't)
function T.GainOf(what)
    for i = #T.fired, 1, -1 do if T.fired[i] == what then return T.gains[i] end end
end

function T.Done(name)
    io.write(string.format("%s: %d checks, %d failures" .. string.char(10), name, T.checks, T.failures))
    os.exit(T.failures == 0 and 0 or 1)
end
return T
