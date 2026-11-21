-- Priest and warlock coverage: every priest and warlock spell in WoW Forever and what it plays (the
-- priest and warlock pass, 2026-11-20). The spells are the client's own (tests/fixtures/priest-spells.txt,
-- warlock-spells.txt, from WoW Helper's --spells and --spell-kinds); each plays its own feel, none
-- generic. Then the iconic ones played out: Mind Flay's and Drain Life's ticks, Penance's bolts, the
-- bolts after their flight, heals as they land, each demon's arrival, a Soul Shard, the DoTs' ticks.
-- lua5.1 tests/PriestWarlock.lua <addon folder> [list]
-- (the game's stubs: as tests/MageCoverage.lua has them)
local root = arg[1] or "."
SPELLS = { PRIEST = {}, WARLOCK = {} }
local byId, kinds = {}, {}
for class, file in pairs({ PRIEST = "priest-spells.txt", WARLOCK = "warlock-spells.txt" }) do
    for line in io.lines(root .. "/tests/fixtures/" .. file) do
        if not line:match("^#") then
            local f = {}
            for v in (line .. "	"):gmatch("([^	]*)	") do f[#f + 1] = v end
            local s = { id = tonumber(f[1]), name = f[2], line = f[3], school = tonumber(f[4]), cast = tonumber(f[5]),
                channel = f[6] == "1", helpful = f[7] == "1" }
            table.insert(SPELLS[class], s)
            byId[s.id] = s
            if f[8] ~= "" then kinds[s.id] = { f[8], s.school, tonumber(f[9]) } end
        end
    end
end
function ClassSpellInfo(id)
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
GetSpellInfo = ClassSpellInfo
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
for _, file in ipairs({ "Profiles.lua", "Model.lua", "Shared.lua", "TouchModel.lua", "Gestures.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua",
    "ClassSpells.lua", "Priest.lua", "Warlock.lua", "Haptics.lua", "Timing.lua", "Volume.lua",
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
V.Settings().enabled = true
UnitRace = function() return "Undead", "Scourge", 5 end
CraftFrame, TradeSkillFrame, ProfessionsFrame = false, false, false
UnitSex = function() return 3 end
local CS, PR, WL, HN, P = ns.ClassSpells, ns.Priest, ns.Warlock, ns.Hunter, ns.Profiles
local class = "PRIEST"
UnitClass = function() return class, class end

---------------------------------------------------------------------------
-- 1. Coverage: every priest and warlock spell the client has, and what it plays
---------------------------------------------------------------------------
-- (never cast by the player: a talent's proc, a rune slot's or a racial's script, a spell another
-- one sets off; each lands as its own wound or aura, no cast to feel)
local TRIGGERED = { ["Blessed Recovery"] = true, ["Focused Casting"] = true, ["Priest Racial Ability"] = true,
    ["Priest Racial Ability RAQ"] = true, ["Soul Engraving"] = true, ["Bane of Doom Effect"] = true,
    ["Hellfire Effect"] = true, ["Ritual of Doom Effect"] = true, ["Pyroclasm"] = true, ["Grimoire of Synergy"] = true,
    ["Master Demonologist"] = true, ["Metamorphosis : Demon Charge"] = true, ["Metamorphosis : Demonic Howl"] = true }
for _, slot in ipairs({ "Bracer", "Chest", "Cloak", "Feet", "Hands", "Helm", "Legs", "Shoulder", "Waist" }) do
    TRIGGERED[slot .. " Rune Ability"] = true
end
local TRIGGERED_ID = { [426325] = true }   -- Shadowflame's burn (the cast is 426320)
local EXPECT = {
    PRIEST = {
        ["Abolish Disease"] = "cast:cleanse", ["Binding Heal"] = "burst:bindingHeal", ["Chastise"] = "hit:chastise",
        ["Circle of Healing"] = "cast:circle", ["Confounding Flash"] = "burst:flash", ["Contingency Plan"] = "cast:glow",
        ["Cure Disease"] = "cast:cleanse", ["Dark Sacrifice"] = "cast:lifeTap", ["Desperate Prayer"] = "cast:desperate",
        ["Devouring Plague"] = "cast:plague", ["Dispel Magic"] = "cast:cleanse", ["Dispersion"] = "cast:dispersion",
        ["Divine Grace"] = "cast:flashHeal", ["Divine Spirit"] = "cast:glow", ["Elune's Grace"] = "cast:glow",
        ["Eye of the Void"] = "cast:fiend", ["Fade"] = "cast:fadeOut", ["Fear Ward"] = "cast:ward", ["Feedback"] = "cast:glow",
        ["Flash Heal"] = "burst:flashHeal", ["Greater Heal"] = "burst:greaterHeal", ["Heal"] = "burst:heal",
        ["Hex of Weakness"] = "cast:hex", ["Holy Fire"] = "burst:holyFire", ["Holy Nova"] = "cast:holyNova",
        ["Homunculi"] = "cast:fiend", ["Inner Fire"] = "cast:innerFire", ["Inner Focus"] = "cast:focus",
        ["Lesser Heal"] = "burst:lesserHeal", ["Levitate"] = "cast:updraft", ["Lightwell"] = "burst:lightwell",
        ["Lightwell Renew"] = "cast:renew", ["Mana Burn"] = "burst:manaBurn", ["Mind Blast"] = "burst:mindBlast",
        ["Mind Control"] = "set:feel:dominate", ["Mind Flay"] = "tick:flay", ["Mind Sear"] = "tick:sear",
        ["Mind Soothe"] = "cast:glow", ["Mind Spike"] = "burst:mindSpike", ["Mind Vision"] = "set:farsight",
        ["Pain Suppression"] = "cast:ward", ["Penance"] = "tick:penance", ["Power Infusion"] = "cast:empower",
        ["Power Word: Barrier"] = "cast:barrier", ["Power Word: Fortitude"] = "cast:glow",
        ["Power Word: Shield"] = "cast:pwShield", ["Prayer of Fortitude"] = "cast:glow",
        ["Prayer of Healing"] = "burst:prayerHeal", ["Prayer of Mending"] = "cast:mending",
        ["Prayer of Shadow Protection"] = "cast:glow", ["Prayer of Spirit"] = "cast:glow",
        ["Psychic Scream"] = "cast:scream", ["Renew"] = "cast:renew", ["Resurrection"] = "burst:resurrect",
        ["Shackle Undead"] = "burst:shackle", ["Shadow Protection"] = "cast:glow", ["Shadow Word: Death"] = "hit:swDeath",
        ["Shadow Word: Pain"] = "cast:pain", ["Shadowfiend"] = "cast:fiend", ["Shadowform"] = "cast:shadowform",
        ["Shadowguard"] = "cast:mantle", ["Silence"] = "cast:counterspell", ["Smite"] = "burst:smite",
        ["Starshards"] = "tick:starshard", ["Touch of Weakness"] = "cast:mantle", ["Vampiric Embrace"] = "cast:embrace",
        ["Vampiric Touch"] = "burst:vampTouch", ["Void Plague"] = "cast:plague", ["Void Zone"] = "burst:voidZone",
        ["Engrave"] = "set:enchanting",
    },
    WARLOCK = {
        ["Amplify Curse"] = "cast:empower", ["Bane of Agony"] = "cast:curse", ["Bane of Doom"] = "cast:curse",
        ["Bane of Havoc"] = "cast:curse", ["Banish"] = "burst:banish", ["Chaos Bolt"] = "impact:chaosBolt",
        ["Conflagrate"] = "hit:conflagrate", ["Corruption"] = "burst:corruption", ["Create Firestone"] = "burst:stone",
        ["Create Healthstone"] = "burst:stone", ["Create Soulstone"] = "burst:stone", ["Create Spellstone"] = "burst:stone",
        ["Curse of Exhaustion"] = "cast:curse", ["Curse of Idiocy"] = "cast:curse", ["Curse of Recklessness"] = "cast:curse",
        ["Curse of Tongues"] = "cast:curse", ["Curse of Weakness"] = "cast:curse", ["Curse of the Elements"] = "cast:curse",
        ["Death Coil"] = "hit:deathCoil", ["Demon Armor"] = "cast:felArmor", ["Demon Charge"] = "cast:charge",
        ["Demon Skin"] = "cast:felArmor", ["Demonic Grace"] = "cast:empower", ["Demonic Howl"] = "cast:howl",
        ["Demonic Sacrifice"] = "cast:sacrifice", ["Detect Invisibility"] = "cast:glow", ["Drain Life"] = "tick:drainLife",
        ["Drain Mana"] = "tick:drainMana", ["Drain Soul"] = "tick:drainSoul", ["Explorer Imp"] = "burst:imp",
        ["Eye of Kilrogg"] = "set:farsight", ["Fear"] = "burst:fear", ["Fel Armor"] = "cast:felArmor",
        ["Fel Domination"] = "cast:empower", ["Haunt"] = "impact:haunt", ["Health Funnel"] = "tick:funnel",
        ["Hellfire"] = "tick:hellfire", ["Howl of Terror"] = "burst:howl", ["Immolate"] = "burst:immolate",
        ["Immolation Aura"] = "cast:immolationAura", ["Incinerate"] = "impact:incinerate", ["Inferno"] = "burst:infernal",
        ["Infernal Armor"] = "cast:felArmor", ["Invocation"] = "hit:shadowburn", ["Life Tap"] = "cast:lifeTap",
        ["Menace"] = "cast:roar", ["Metamorphosis"] = "cast:metamorphosis",
        ["Portal of Summoning"] = "set:feel:summonCircle", ["Rain of Fire"] = "tick:rainOfFire",
        ["Ritual of Doom"] = "set:feel:summonCircle", ["Ritual of Summoning"] = "set:feel:summonCircle",
        ["Searing Pain"] = "burst:searingPain", ["Sense Demons"] = "cast:glow", ["Shadow Bolt"] = "impact:shadowBolt",
        ["Shadow Cleave"] = "hit:shadowCleave", ["Shadow Ward"] = "cast:ward", ["Shadowburn"] = "hit:shadowburn",
        ["Shadowflame"] = "burst:shadowflame", ["Siphon Life"] = "cast:affliction", ["Soul Fire"] = "impact:soulFire",
        ["Soul Link"] = "cast:glow", ["Subjugate Demon"] = "burst:subjugate", ["Summon Felguard"] = "burst:felguard",
        ["Summon Felhunter"] = "burst:felhunter", ["Summon Imp"] = "burst:imp", ["Summon Incubus"] = "burst:succubus",
        ["Summon Succubus"] = "burst:succubus", ["Summon Voidwalker"] = "burst:voidwalker",
        ["Unending Breath"] = "cast:glow", ["Unstable Affliction"] = "burst:affliction", ["Vengeance"] = "cast:empower",
        ["Wrack"] = "tick:wrack", ["Minor Healthstone"] = "cast:healthstone", ["Lesser Healthstone"] = "cast:healthstone",
        ["Healthstone"] = "cast:healthstone", ["Greater Healthstone"] = "cast:healthstone",
        ["Major Healthstone"] = "cast:healthstone", ["Soulstone Resurrection"] = "burst:stone", ["Spellstone"] = "cast:ward",
        ["Engrave"] = "set:enchanting",
    },
}

local function Plays(s)
    local r = V.SpellRule(s.id, s.channel and 1 or s.cast / 1000)
    if not r then return "none" end
    if r.moment == "shot" then return "shot", r end
    if r.moment == "spell" then
        local m = r.mage
        if m then
            if m.impact then return "impact:" .. m.impact, r end
            if m.burst then return "burst:" .. m.burst, r end
            if m.tick then return "tick:" .. m.tick, r end
        end
        return "set:" .. tostring(r.set), r
    end
    if r.moment == "quiet" then return "quiet", r end
    return (r.when == "hit" and "hit:" or "cast:") .. tostring(r.move), r
end

local lines, ids = {}, 0
for _, c in ipairs({ "PRIEST", "WARLOCK" }) do
    class = c
    local wrong, seen = {}, {}
    for _, s in ipairs(SPELLS[c]) do
        local key = s.name
        if s.line == "Engraving" then key = "Engrave" end
        local got, r = Plays(s)
        ids = ids + 1
        local never = TRIGGERED[s.name] or TRIGGERED_ID[s.id]
        lines[#lines + 1] = ("%-8s %7d  %-34s %s"):format(c, s.id, s.name, never and "never cast (triggered)" or got)
        if not never then
            if EXPECT[c][key] ~= got then wrong[#wrong + 1] = s.id .. " " .. s.name .. ": " .. got .. " (expected " .. tostring(EXPECT[c][key]) .. ")" end
            -- (nothing generic: not the fallback set, not a guessed Blow, never a quiet one)
            if got == "set:sweep" or got == "cast:blow" or got == "hit:blow" or got == "quiet" or (r and r.guessed) then
                wrong[#wrong + 1] = s.id .. " " .. s.name .. ": " .. got .. " is generic"
            end
            -- (each feel exists, rumble and its HD library entry)
            local pattern = got:match("^[a-z]+:(.+)$")
            if pattern and got:sub(1, 4) ~= "set:" then
                assert(V.PULSES[pattern], s.name .. ": no pulses for " .. pattern)
                assert(H.Feel("r_" .. pattern), s.name .. ": no library feel r_" .. pattern)
            end
            seen[key] = true
        end
    end
    assert(#wrong == 0, c .. " spells that play something else:\n  " .. table.concat(wrong, "\n  "))
    for key in pairs(EXPECT[c]) do assert(seen[key], "expected but not in the client's list: " .. key) end
end
if arg[2] == "list" then io.write(table.concat(lines, "\n"), "\n") end
-- (a class's own for its class only: a priest's Smite is no warlock's; a Healthstone is anyone's)
class = "WARLOCK"
assert(V.MageOf(585) == nil and V.MageOf(589) == nil, "Smite, Shadow Word: Pain: a priest's only")
class = "MAGE"
assert(V.MageOf(686) == nil, "Shadow Bolt: a warlock's only")
assert(V.MageOf(5720) and V.MageOf(5720).move == "healthstone", "a Healthstone: anyone's")
assert(V.MageOf(133) and V.MageOf(133).impact == "fireball", "a mage's own still its own")
class = "PRIEST"
io.write("PASS: " .. ids .. " priest and warlock spell IDs (every rank, runes, the warlock's stones): each its own feel, none generic\n")

---------------------------------------------------------------------------
-- 2. Play: the iconic spells as they happen (events in, rumble and HD out)
---------------------------------------------------------------------------
-- (every frame that listens, as the game does; Rumble's own frame takes UNIT_COMBAT too: the stubs
-- name a combat log, which WoW Forever has not)
local rf
for _, f in ipairs(created) do if f.events and f.events.START_AUTOREPEAT_SPELL and f.events.PLAYER_LEVEL_UP then rf = f end end
local function ev(event, ...)
    for _, f in ipairs(created) do
        if f.events and (f.events[event] or (f == rf and event == "UNIT_COMBAT")) and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
local hd, moments, labFired = {}, {}, {}
local cFeel, cMoment, lFire = C.Feel, C.Moment, L.Fire
C.Feel = function(key, gain, side) hd[#hd + 1] = { t = now, key = key, side = side } end
C.Moment = function(key, feel, opts) moments[#moments + 1] = { t = now, key = key, feel = feel }; return cMoment(key, feel, opts) end
L.Fire = function(key, ...) labFired[#labFired + 1] = key; return lFire(key, ...) end
UnitCanAttack = function() return true end
local chan, casting
UnitChannelInfo = function() if chan then return "x", nil, nil, chan[1] * 1000, chan[2] * 1000 end end
UnitCastingInfo = function() if casting then return "x", nil, nil, casting[1] * 1000, casting[2] * 1000 end end
local function channel(id, seconds, after)
    hd = {}
    now = now + 5
    chan = { now, now + seconds }
    local t0 = now
    ev("UNIT_SPELLCAST_CHANNEL_START", "player", "c" .. id, id)
    run(seconds - 0.02)
    ev("UNIT_SPELLCAST_CHANNEL_STOP", "player", "c" .. id, id)
    chan = nil
    run(after or 0.5)
    local out = {}
    for _, e in ipairs(hd) do out[#out + 1] = { e.t - t0, e.key, e.side } end
    return out
end
local function ticks(id, seconds, n, key, period, first)
    local m = channel(id, seconds)
    assert(#m == n, key .. ": " .. n .. " ticks: " .. #m)
    for i, e in ipairs(m) do
        near(e[1], (first and (i - 1) or i) * period, 0.03, key .. " tick " .. i)
        assert(e[2] == "r_" .. key, key .. ": its own tick, " .. tostring(e[2]))
    end
    return m
end
-- Mind Flay: three ticks over 3 s, hand by turns; Mind Sear and Starshards six over 6 s
local m = ticks(15407, 3, 3, "flay", 1)
assert(m[1][3] == -0.4 and m[2][3] == 0.4, "Mind Flay: left, then right")
ticks(413259, 6, 6, "sear", 1)
ticks(10797, 6, 6, "starshard", 1)
-- Penance: its first bolt as it starts, then one each second
ticks(402174, 2, 3, "penance", 1, true)
-- Mind Flay hasted 20 %: still three ticks, each 0.8 s
ticks(15407, 2.4, 3, "flay", 0.8)
class = "WARLOCK"
-- Drain Life, Drain Mana: five ticks over 5 s; Drain Soul five over 15 s; Health Funnel ten; Hellfire
-- fifteen; Rain of Fire four over 8 s; Wrack six
ticks(689, 5, 5, "drainLife", 1)
ticks(5138, 5, 5, "drainMana", 1)
ticks(1120, 15, 5, "drainSoul", 3)
ticks(755, 10, 10, "funnel", 1)
ticks(1949, 15, 15, "hellfire", 1)
ticks(5740, 8, 4, "rainOfFire", 2)
ticks(1316697, 6, 6, "wrack", 1)
-- the top rank by name: Drain Life rank 6
ticks(11700, 5, 5, "drainLife", 1)
io.write("PASS: channels on their ticks (haste too): Mind Flay by turns, Penance's first bolt at its start, the drains, Hellfire, Rain of Fire\n")

-- Bolts: the cast builds, released, felt as it lands (their school only); casts with no flight at the release
local fired, played = {}, {}
local vfire, vplay = V.Fire, V.Play
V.Fire = function(key, ...) if key == "instant" then fired[#fired + 1] = { t = now, move = V.instantMove } end; return vfire(key, ...) end
V.Play = function(key, ...) played[#played + 1] = key; return vplay(key, ...) end
local loops = {}
local function cast(id, seconds, woundAfter, school)
    fired, moments, played, labFired = {}, {}, {}, {}
    now = now + 5
    casting = { now, now + seconds }
    ev("UNIT_SPELLCAST_START", "player", "k" .. id, id)
    loops[id] = V.castAction
    run(seconds)
    casting = nil
    ev("UNIT_SPELLCAST_SUCCEEDED", "player", "k" .. id, id)
    ev("UNIT_SPELLCAST_STOP", "player", "k" .. id, id)
    local t0 = now
    if woundAfter then
        run(woundAfter)
        ev("UNIT_COMBAT", "target", "WOUND", "", 300, school)
    end
    run(0.5)
    RunTimers()
    return fired, t0
end
local f, t0 = cast(686, 3, 0.6, 32)
assert(#f == 1 and f[1].move == "shadowBolt", "Shadow Bolt lands as its own: " .. tostring(f[1] and f[1].move))
near(f[1].t - t0, 0.6, 0.02, "at the wound, after its flight")
f = cast(686, 3, 0.6, 4)
assert(#f == 0, "a fire wound isn't the Shadow Bolt's")
f = cast(6353, 6, 0.9, 4)
assert(#f == 1 and f[1].move == "soulFire", "Soul Fire: its own impact")
f = cast(403629, 2.5, 0.7, 124)
assert(#f == 1 and f[1].move == "chaosBolt", "Chaos Bolt (every school): its own impact")
f = cast(348, 2)
assert(#f == 0 and played[#played] == "immolate", "Immolate at the release: " .. tostring(played[#played]))
f = cast(5782, 1.5)
assert(played[#played] == "fear", "Fear at the release")
-- each demon its own arrival, out of a summoning circle (not the strong family loop)
for id, demon in pairs({ [688] = "imp", [697] = "voidwalker", [712] = "succubus", [713] = "succubus", [691] = "felhunter",
    [427733] = "felguard" }) do
    cast(id, 10)
    assert(played[#played] == demon, "summoned: " .. demon .. " " .. tostring(played[#played]))
    assert(loops[id] == "feel:summonCircle", demon .. ": the circle while it's drawn: " .. tostring(loops[id]))
end
cast(6201, 3)
assert(played[#played] == "stone" and loops[6201] == "feel:stoneForm", "a Healthstone made: it forms, then the stone")
cast(1122, 2)
assert(played[#played] == "infernal", "Inferno: the infernal's crash")
class = "PRIEST"
cast(585, 1.5)
assert(played[#played] == "smite", "Smite at the release")
cast(8092, 1.5)
assert(played[#played] == "mindBlast", "Mind Blast at the release")
for id, heal in pairs({ [2050] = "lesserHeal", [2054] = "heal", [2060] = "greaterHeal", [2061] = "flashHeal",
    [596] = "prayerHeal", [401937] = "bindingHeal" }) do
    cast(id, 2)
    assert(played[#played] == heal, "a heal lands at the release: " .. heal .. " " .. tostring(played[#played]))
end
cast(2006, 10)
assert(played[#played] == "resurrect" and loops[2006] == "healing", "Resurrection: healing's loop, then the breath")
-- Instants: at the cast, or as they land
local function instant(id, woundAfter, school)
    fired, moments, labFired = {}, {}, {}
    now = now + 5
    ev("UNIT_SPELLCAST_SUCCEEDED", "player", "i" .. id, id)
    if woundAfter then run(woundAfter); ev("UNIT_COMBAT", "target", "WOUND", "", 100, school) end
    run(0.3)
    RunTimers()
    return fired
end
local AT_CAST = { PRIEST = { [17] = "pwShield", [8122] = "scream", [586] = "fadeOut", [139] = "renew", [589] = "pain",
        [15237] = "holyNova", [10901] = "pwShield", [15473] = "shadowform", [401977] = "fiend" },
    WARLOCK = { [1454] = "lifeTap", [702] = "curse", [980] = "curse", [706] = "felArmor", [18788] = "sacrifice",
        [403789] = "metamorphosis", [5720] = "healthstone" } }
for _, c in ipairs({ "PRIEST", "WARLOCK" }) do
    class = c
    for id, move in pairs(AT_CAST[c]) do
        f = instant(id)
        assert(#f == 1 and f[1].move == move, "at the cast: " .. move .. " " .. tostring(f[1] and f[1].move))
        local hdKey
        for _, e in ipairs(moments) do if e.feel then hdKey = e.feel end end
        assert(hdKey == "r_" .. move, move .. ": its HD feel " .. tostring(hdKey))
    end
end
class = "WARLOCK"
f = instant(6789, 0.1, 32)
assert(#f == 1 and f[1].move == "deathCoil", "Death Coil as it lands")
f = instant(1293817, 0.1, 4)
assert(#f == 1 and f[1].move == "conflagrate", "Conflagrate as it lands")
class = "PRIEST"
f = instant(401955, 0.1, 32)
assert(#f == 1 and f[1].move == "swDeath", "Shadow Word: Death as it lands")
-- (a crit: its own at full, as a mage's)
fired = {}
now = now + 5
ev("UNIT_SPELLCAST_SUCCEEDED", "player", "crit", 401955)
run(0.1)
ev("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 300, 32)
run(0.3); RunTimers()
assert(#fired >= 1 and fired[1].move == "swDeath", "its crit: its own feel")
V.Fire, V.Play = vfire, vplay
io.write("PASS: bolts land as themselves after their flight (school-checked); casts, heals and demons at the release; instants at the cast or as they land\n")

---------------------------------------------------------------------------
-- 3. The feels' shape: area spells in both hands, DoTs faint, heals by their size
---------------------------------------------------------------------------
local function hands(k, upTo)
    local l0, r0 = 0, 0
    for _, p in ipairs(V.PULSES[k]) do
        if p[1] < (upTo or 0.45) then
            l0 = math.max(l0, p[3] * math.min(1, 1 - p[4]))
            r0 = math.max(r0, p[3] * math.min(1, 1 + p[4]))
        end
    end
    return l0, r0
end
for _, k in ipairs({ "holyNova", "scream", "prayerHeal", "howl", "hellfire", "immolationAura", "infernal" }) do
    local l0, r0 = hands(k, k == "infernal" and 1.2 or nil)
    assert(l0 > 0.15 and r0 > 0.15, k .. ": both hands")
end
-- Rain of Fire: meteors scattered over both hands, uneven
local left, right = 0, 0
for _, p in ipairs(V.PULSES.rainOfFire) do if p[4] < 0 then left = left + 1 elseif p[4] > 0 then right = right + 1 end end
assert(left >= 2 and right >= 2, "Rain of Fire: spread")
local function peak(k) local s = 0; for _, p in ipairs(V.PULSES[k]) do s = math.max(s, p[3]) end; return s end
local function mass(k) local s = 0; for _, p in ipairs(V.PULSES[k]) do s = s + p[3] * p[2] end; return s end
for _, k in ipairs({ "pain", "plague", "vampTouch", "embrace", "curse", "corruption", "affliction", "dotTick" }) do
    assert(peak(k) <= 0.15, k .. ": a DoT's word is faint (" .. peak(k) .. ")")
end
assert(mass("lesserHeal") < mass("heal") and mass("heal") < mass("greaterHeal"), "heals by their size")
assert(mass("shadowBolt") < mass("soulFire") and mass("soulFire") <= mass("chaosBolt") + 0.05, "bolts by their weight")
assert(mass("voidwalker") > mass("imp") and mass("felguard") > mass("imp"), "a voidwalker heavier than an imp")
for _, list in ipairs({ PR.PATTERNS, WL.PATTERNS }) do
    for _, p in ipairs(list) do
        assert(V.Pattern(p.key) == p and H.Feel("r_" .. p.key), p.key .. ": in Rumble and the library")
        for _, pu in ipairs(p.pulses) do
            assert(pu[2] >= 0.05 and pu[3] > 0 and pu[3] <= 1 and pu[4] >= -1 and pu[4] <= 1, p.key .. ": a pulse the pad feels")
        end
        assert(#p.steps >= 1, p.key .. ": steps for the engine off")
    end
end
io.write("PASS: area spells in both hands, Rain of Fire spread; DoTs faint; heals, bolts and demons by their weight\n")

---------------------------------------------------------------------------
-- 4. The warlock's demon: its arrival is the summon's; its blows and the blows on it off
---------------------------------------------------------------------------
class = "WARLOCK"
local pet = nil
UnitExists = function(u) return u == "pet" and pet ~= nil end
UnitGUID = function(u) return u == "pet" and pet and pet.guid or nil end
UnitIsDead = function(u) return u == "pet" and pet and pet.dead or false end
UnitIsUnit = function(a, b) return a == "pettarget" and b == "target" and pet ~= nil end
UnitOnTaxi = function() return false end
local function labHas(k) for _, x in ipairs(labFired) do if x == k then return true end end; return false end
-- a summon: the old demon leaves and the new comes while you summon, and just after: no Pet moments
now = now + 10
pet = { guid = "Pet-1" }
HN.PetChanged()
labFired = {}
casting = { now, now + 10 }
ev("UNIT_SPELLCAST_START", "player", "sum", 697)
pet = nil
ev("UNIT_PET", "player")
run(10)
casting = nil
pet = { guid = "Pet-2" }
ev("UNIT_PET", "player")
ev("UNIT_SPELLCAST_SUCCEEDED", "player", "sum", 697)
pet = { guid = "Pet-3" }
ev("UNIT_PET", "player")
assert(not labHas("petArrive") and not labHas("petDismiss"), "summoning: the demon's own arrival only: " .. table.concat(labFired, ","))
-- later, it dies in a fight: Pet dies
run(5)
pet.dead = true
ev("UNIT_HEALTH", "pet")
assert(labHas("petDeath"), "the demon dies: Pet dies")
-- Demonic Sacrifice: no Pet dies on top of the sacrifice
pet = { guid = "Pet-4" }
HN.PetChanged()
labFired = {}
ev("UNIT_SPELLCAST_SUCCEEDED", "player", "sac", 18788)
pet.dead = true
ev("UNIT_HEALTH", "pet")
pet = nil
ev("UNIT_PET", "player")
assert(not labHas("petDeath") and not labHas("petDismiss"), "sacrificed: its own feel, no Pet dies")
-- the demon's melee on your target: its own (Pet crit), off by default; never your Crit or Miss
run(5)
pet = { guid = "Pet-5" }
HN.PetChanged()
labFired = {}
local yourCrits = 0
V.Fire = function(key, ...) if key == "crit" or key == "critRanged" then yourCrits = yourCrits + 1 end; return vfire(key, ...) end
ev("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 80, 1)
ev("UNIT_COMBAT", "target", "MISS", "", 0, 1)
V.Fire = vfire
assert(yourCrits == 0 and not labHas("miss"), "the demon's blows aren't yours: " .. table.concat(labFired, ","))
assert(L.EVENT.petCrit.on == false and L.EVENT.petHurt.on == false, "Pet crit, Pet hurt: off by default")
pet = nil
HN.PetChanged()
io.write("PASS: a demon's arrival is its summon's (no Pet arrives or leaves on top), Demonic Sacrifice quiet, Pet dies in a fight; its blows its own, off\n")

---------------------------------------------------------------------------
-- 5. Soul Shards and the DoTs' ticks
---------------------------------------------------------------------------
local shardCount = 2
C_Item = C_Item or {}
local getCount = C_Item.GetItemCount
C_Item.GetItemCount = function(id) return id == 6265 and shardCount or 0 end
labFired = {}
ev("PLAYER_ENTERING_WORLD")
ev("BAG_UPDATE_DELAYED")
assert(not labHas("soulShard"), "the shards you have: counted, not felt")
shardCount = 3
ev("BAG_UPDATE_DELAYED")
assert(labHas("soulShard"), "a Soul Shard gained")
labFired = {}
shardCount = 2
ev("BAG_UPDATE_DELAYED")
assert(not labHas("soulShard"), "one used: nothing")
assert(L.EVENT.soulShard.on == true, "Soul Shard: on by default")
class = "PRIEST"
shardCount = 5
ev("BAG_UPDATE_DELAYED")
assert(not labHas("soulShard"), "a priest's bags: nothing")
C_Item.GetItemCount = getCount
-- DoT ticks: off by default; your DoT's school on your target, unclaimed, not while channelling
assert(L.EVENT.dotTick.on == false, "DoT ticks: off by default")
local auras = {}
C_UnitAuras = C_UnitAuras or {}
local getAura = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
    if unit == "target" and filter == "HARMFUL|PLAYER" then return auras[i] end
end
class = "WARLOCK"
auras = { { name = "Corruption", spellId = 172 } }
ev("UNIT_AURA", "target")
local function tick(school, after)
    labFired = {}
    now = now + (after or 3)
    ev("UNIT_COMBAT", "target", "WOUND", "", 40, school)
    return labHas("dotTick")
end
assert(tick(32), "Corruption ticks: DoT ticks")
assert(not tick(4), "a fire wound: not Corruption's")
assert(not tick(1), "a physical blow: not a tick")
assert(tick(32) and not tick(32, 0.1), "two at once: one tick")
chan = { now, now + 5 }
assert(not tick(32), "Drain Life's own ticks while you channel")
chan = nil
auras = {}
ev("UNIT_AURA", "target")
assert(not tick(32), "no DoT of yours on it: nothing")
class = "PRIEST"
auras = { { name = "Shadow Word: Pain", spellId = 589 } }
ev("PLAYER_TARGET_CHANGED")
assert(tick(32), "Shadow Word: Pain ticks")
auras = {}
ev("PLAYER_TARGET_CHANGED")
C_UnitAuras.GetAuraDataByIndex = getAura
io.write("PASS: a Soul Shard gained (a warlock's, felt once); DoT ticks off by default, only your DoT's school, one per tick, not under a channel\n")

---------------------------------------------------------------------------
-- 6. Shipped for the class: cloth, as a mage
---------------------------------------------------------------------------
for _, c in ipairs({ "PRIEST", "WARLOCK" }) do
    local r = P.CLASS[c]
    assert(r and r.events.oom and r.vibration.shot and r.vibration.autoAttack == false, c .. ": low mana, the wand on, swings off")
    assert(not (r.events.petCrit or r.events.petHurt or r.events.dotTick), c .. ": the pet's blows and DoT ticks stay off")
end
---------------------------------------------------------------------------
-- 7. Review: windows of several schools only for the class spells that ask; Penance's first bolt
-- as you set it; names not loaded retried at most every 10 s
---------------------------------------------------------------------------
UnitCanAttack = function() return true end
-- (a mage's fire window and a paladin's holy window: as on main, a wound of another mix is not theirs)
local function window(action, multi, school)
    now = now + 5
    V.CastImpactWindow(action, 1, "fireball", multi)
    now = now + 0.4
    local claimed = V.ClaimsResult("WOUND", school)
    now = now + 5
    return claimed
end
assert(not window("fire", nil, 20), "Frostfire's fire window: a school-20 wound is not its own")
assert(not window("fire", nil, 124), "a fire window: someone's chaos wound is not its own")
assert(not window("holy", nil, 3), "a paladin's holy window: a school-3 wound is not its own")
assert(window("fire", nil, 4) and window("holy", nil, 2), "its own school: its own")
assert(window("fire", true, 124), "Chaos Bolt's window (a class spell of every school): its wound")
assert(V.MageOf(401502) and not V.MageOf(401502).multiSchool, "Frostfire Bolt: one school's window")
class = "WARLOCK"
assert(V.MageOf(403629).multiSchool, "Chaos Bolt asks for it")
-- Penance: its first bolt off when you turned it off, at your volume when you set one
class = "PRIEST"
local O = ns.SpellOverrides
local get = O.Get
local hdSent, playOpts = {}, {}
local cFeel2, vplay2 = C.Feel, V.Play
C.Feel = function(key) hdSent[#hdSent + 1] = key end
V.Play = function(key, loop, opts) playOpts[#playOpts + 1] = { key = key, opts = opts }; return vplay2(key, loop, opts) end
O.Get = function(name) if name == "Penance" then return { on = false } end end
PR.ChannelStarted(402174)
assert(#hdSent == 0 and #playOpts == 0, "Penance off: no first bolt")
O.Get = function(name) if name == "Penance" then return { volume = 0.5 } end end
PR.ChannelStarted(402174)
assert(#playOpts == 1 and playOpts[1].opts and playOpts[1].opts.strength == 0.5, "Penance at half: its first bolt at half")
O.Get = get
C.Feel, V.Play = cFeel2, vplay2
-- DoT names: one never loaded is read again at most every 10 s, not on every aura change
local asked = 0
local spellName = C_Spell and C_Spell.GetSpellName
local gsi = GetSpellInfo
GetSpellInfo = function(id) asked = asked + 1; if id == 589 then return nil end; return gsi(id) end
if C_Spell then C_Spell.GetSpellName = nil end
class = "PRIEST"
now = now + 20
CS.ForgetDots()
ev("PLAYER_TARGET_CHANGED")
local first = asked
for _ = 1, 20 do ev("UNIT_AURA", "target") end
assert(asked == first, "a missing name: not read again on every aura (" .. (asked - first) .. ")")
now = now + 11
ev("UNIT_AURA", "target")
assert(asked > first, "read again after 10 s")
GetSpellInfo = gsi
if C_Spell then C_Spell.GetSpellName = spellName end
now = now + 11
ev("UNIT_AURA", "target")
io.write("PASS: review: a mage's and a paladin's windows as before, Chaos Bolt's its own; Penance off or at your volume; missing names retried every 10 s\n")
C.Feel, C.Moment, L.Fire = cFeel, cMoment, lFire
io.write("PASS: P.CLASS.PRIEST and WARLOCK: cloth, the wand on, swings, pet blows and DoT ticks off\n")

-- WoW Helper's plans (SpellPlans.lua): Penance, its first bolt on the rumble, two more on its ticks
do
    class = "PRIEST"
    assert(loadfile(root .. "/SpellPlans.lua"))("GamepadCompanion", ns)
    local p = ns.SpellPlans.Plan(402174)
    assert(p and p.tick == "r_penance" and p.n == 2 and p.first and p.rumble and p.rumble[1] == "penance", "Penance's plan")
    io.write("PASS: Penance's plan for WoW Helper: a first bolt (rumble), then its ticks\n")
end
