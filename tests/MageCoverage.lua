-- Mage coverage: every mage spell in WoW Forever and what it plays (the mage pass, 2026-11-20).
-- The spells are the client's own (tests/fixtures/mage-spells.txt, from WoW Helper's --spells and
-- --spell-kinds); each must play its own feel, none generic. Then the iconic ones played out:
-- Arcane Missiles on its ticks, Blizzard's shards, the bolts' impacts after their flight.
-- lua5.1 tests/MageCoverage.lua <addon folder>
-- (the game's stubs: as tests/Haptics.lua has them)
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
    [2963] = { "Bolt of Linen Cloth", 3000 }, [3915] = { "Brown Linen Shirt", 5125 }, [2366] = { "Herb Gathering", 1500 } }) do
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
UnitClass = function() return "Mage", "MAGE" end

---------------------------------------------------------------------------
-- 1. Coverage: every mage spell the client has, and what it plays
---------------------------------------------------------------------------
-- (never cast by the player: a talent's or a rune's proc, a spell another
-- one triggers; each lands as its own wound or aura, no cast to feel)
local TRIGGERED = { ["Chilled"] = true, ["Frostbite"] = true, ["Impact"] = true, ["Fire Vulnerability"] = true,
    ["Clearcasting"] = true, ["Master of Elements"] = true, ["Magic Absorption"] = true, ["Comprehend Scroll"] = true }
-- (quiet by design: none)
local EXPECT = {
    ["Amplify Magic"] = "cast:glow", ["Arcane Barrage"] = "hit:barrage", ["Arcane Blast"] = "impact:arcaneBlast",
    ["Arcane Brilliance"] = "cast:glow", ["Arcane Explosion"] = "cast:arcaneExplosion", ["Arcane Intellect"] = "cast:glow",
    ["Arcane Missiles"] = "tick:missile", ["Arcane Power"] = "cast:empower", ["Arcane Surge"] = "hit:arcaneBlast",
    ["Arcane Wrath"] = "impact:arcaneBlast", ["Balefire Bolt"] = "impact:fireball", ["Blast Wave"] = "cast:blastWave",
    ["Blink"] = "cast:blink", ["Blizzard"] = "tick:blizzard", ["Cold Snap"] = "cast:empower", ["Combustion"] = "cast:empower",
    ["Cone of Cold"] = "cast:coneOfCold", ["Conjure Food"] = "set:feel:conjure", ["Conjure Mana Agate"] = "set:feel:conjure",
    ["Conjure Mana Citrine"] = "set:feel:conjure", ["Conjure Mana Jade"] = "set:feel:conjure",
    ["Conjure Mana Ruby"] = "set:feel:conjure", ["Conjure Water"] = "set:feel:conjure", ["Counterspell"] = "cast:counterspell",
    ["Dampen Magic"] = "cast:glow", ["Evocation"] = "tick:evocation", ["Felfire"] = "hit:fireBlast",
    ["Fire Blast"] = "hit:fireBlast", ["Fire Ward"] = "cast:ward", ["Fireball"] = "impact:fireball",
    ["Flamestrike"] = "burst:flamestrike", ["Frost Armor"] = "cast:mantle", ["Frost Nova"] = "cast:frostNova",
    ["Frost Ward"] = "cast:ward", ["Frostbolt"] = "impact:frostbolt", ["Frostfire Bolt"] = "impact:frostfire",
    ["Frozen Orb"] = "cast:frozenOrb", ["Ice Armor"] = "cast:mantle", ["Ice Barrier"] = "cast:iceBarrier",
    ["Ice Block"] = "cast:iceBlock", ["Ice Lance"] = "hit:iceLance", ["Icy Veins"] = "cast:empower",
    ["Living Bomb"] = "cast:bomb", ["Living Flame"] = "cast:bomb", ["Mage Armor"] = "cast:mantle",
    ["Mana Shield"] = "cast:manaShield", ["Mass Regeneration"] = "set:healing", ["Polymorph"] = "burst:polymorph",
    ["Polymorph: Cow"] = "burst:polymorph", ["Portal: Darnassus"] = "set:travel", ["Portal: Ironforge"] = "set:travel",
    ["Portal: Orgrimmar"] = "set:travel", ["Portal: Stormwind"] = "set:travel", ["Portal: Thunder Bluff"] = "set:travel",
    ["Portal: Undercity"] = "set:travel", ["Presence of Mind"] = "cast:empower", ["Pyroblast"] = "impact:pyroblast",
    ["Regeneration"] = "set:healing", ["Remove Lesser Curse"] = "cast:glow", ["Rewind Time"] = "cast:blink",
    ["Scorch"] = "impact:scorch", ["Slow Fall"] = "cast:glow", ["Spellfrost Bolt"] = "impact:frostbolt",
    ["Study"] = "set:arcaneSpells", ["Teleport: Dalaran"] = "set:travel", ["Teleport: Darnassus"] = "set:travel",
    ["Teleport: Ironforge"] = "set:travel", ["Teleport: Orgrimmar"] = "set:travel", ["Teleport: Stormwind"] = "set:travel",
    ["Teleport: Thunder Bluff"] = "set:travel", ["Teleport: Undercity"] = "set:travel",
    ["Deep Freeze"] = "cast:deepFreeze", ["Molten Armor"] = "cast:mantle", ["Displacement"] = "cast:blink",
    ["Temporal Anomaly"] = "cast:glow", ["Dragon's Breath"] = "cast:dragonsBreath",
    ["Will of the Forsaken"] = "cast:shock", ["Cannibalize"] = "cast:chew", ["Cannibalize (channel)"] = "tick:chew",
    ["Shoot"] = "shot", ["Engrave"] = "set:enchanting",
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

local lines, wrong, seen, ids = {}, {}, {}, 0
for _, s in ipairs(SPELLS) do
    local key = s.name
    if s.line == "Engraving" then key = "Engrave" end
    if s.id == 20578 then key = "Cannibalize (channel)" end
    local got, r = Plays(s)
    ids = ids + 1
    lines[#lines + 1] = ("%7d  %-34s %s"):format(s.id, s.name, TRIGGERED[s.name] and "never cast (triggered)" or got)
    if not TRIGGERED[s.name] then
        if EXPECT[key] ~= got then wrong[#wrong + 1] = s.id .. " " .. s.name .. ": " .. got .. " (expected " .. tostring(EXPECT[key]) .. ")" end
        -- (nothing generic: not the fallback set, not a guessed Blow, never a quiet one)
        if got == "set:sweep" or got == "cast:blow" or got == "hit:blow" or got == "quiet" or (r and r.guessed) then
            wrong[#wrong + 1] = s.id .. " " .. s.name .. ": " .. got .. " is generic"
        end
        -- (each feel exists, rumble and its HD library entry)
        local pattern = got:match(":(.+)$")
        if pattern and not pattern:find("^feel:") and got:sub(1, 4) ~= "set:" then
            assert(V.PULSES[pattern], s.name .. ": no pulses for " .. pattern)
            assert(H.Feel("r_" .. pattern), s.name .. ": no library feel r_" .. pattern)
        end
        seen[key] = true
    end
end
assert(#wrong == 0, "mage spells that play something else:\n  " .. table.concat(wrong, "\n  "))
for key in pairs(EXPECT) do assert(seen[key], "expected but not in the client's list: " .. key) end
if arg[2] == "list" then io.write(table.concat(lines, "\n"), "\n") end
io.write("PASS: " .. ids .. " mage spell IDs (every rank, runes, racials, the wand): each its own feel, none generic\n")

---------------------------------------------------------------------------
-- 2. Play: the iconic spells as they happen (events in, rumble and HD out)
---------------------------------------------------------------------------
local rf
for _, f in ipairs(created) do if f.events and f.events.START_AUTOREPEAT_SPELL and f.events.PLAYER_LEVEL_UP then rf = f end end
local function rev(...) rf.scripts.OnEvent(rf, ...) end
local hd, moments = {}, {}
local cFeel, cMoment = C.Feel, C.Moment
C.Feel = function(key, gain, side) hd[#hd + 1] = { t = now, key = key, side = side } end
C.Moment = function(key, feel, opts) moments[#moments + 1] = { t = now, key = key, feel = feel }; return cMoment(key, feel, opts) end
UnitCanAttack = function() return true end
local chan, casting
UnitChannelInfo = function() if chan then return "x", nil, nil, chan[1] * 1000, chan[2] * 1000 end end
UnitCastingInfo = function() if casting then return "x", nil, nil, casting[1] * 1000, casting[2] * 1000 end end
local function channel(id, seconds, after)
    hd = {}
    now = now + 5
    chan = { now, now + seconds }
    local t0 = now
    rev("UNIT_SPELLCAST_CHANNEL_START", "player", "c" .. id, id)
    run(seconds - 0.02)
    rev("UNIT_SPELLCAST_CHANNEL_STOP", "player", "c" .. id, id)
    chan = nil
    run(after or 0.5)
    local out = {}
    for _, e in ipairs(hd) do out[#out + 1] = { e.t - t0, e.key, e.side } end
    return out
end

-- Arcane Missiles, rank 1: 3 missiles, at 1, 2 and 3 s; by turns from either hand; the last firmer
local m = channel(5143, 3)
assert(#m == 3, "three missiles: " .. #m)
for i, e in ipairs(m) do near(e[1], i, 0.03, "missile " .. i .. " on its tick") end
assert(m[1][2] == "r_missile" and m[2][2] == "r_missile" and m[3][2] == "r_missileLast", "the last a touch firmer")
assert(m[1][3] == -0.4 and m[2][3] == 0.4, "left hand, then right")
-- the top rank, hasted 20 %: 5 missiles over 4 s (each 0.8 s), not 4
m = channel(25345, 4)
assert(#m == 5, "hasted: still five missiles: " .. #m)
for i, e in ipairs(m) do near(e[1], i * 0.8, 0.03, "hasted missile " .. i) end
-- cut short (moved): no last missile played for the ones it never fired
hd = {}
now = now + 5
chan = { now, now + 5 }
rev("UNIT_SPELLCAST_CHANNEL_START", "player", "cut", 10211)
run(2.5)
chan = nil
rev("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cut", 10211)
run(0.5)
assert(#hd == 2 and hd[2].key == "r_missile", "stopped at 2.5 s: two missiles, no last: " .. #hd)
-- Blizzard: eight seconds of shards, one burst of uneven impacts each second
m = channel(10, 8)
assert(#m == 8, "Blizzard: eight ticks: " .. #m)
for i, e in ipairs(m) do near(e[1], i, 0.03, "tick " .. i); assert(e[2] == "r_blizzard", "shards") end
-- (the shards: several, uneven, both hands)
local shards = V.PULSES.blizzard
assert(#shards >= 7, "many small impacts")
local gaps, left, right = {}, 0, 0
for i, p in ipairs(shards) do
    assert(p[3] <= 0.25, "each shard small")
    if p[4] < 0 then left = left + 1 else right = right + 1 end
    if i > 1 then gaps[#gaps + 1] = p[1] - shards[i - 1][1] end
end
table.sort(gaps)
assert(gaps[#gaps] - gaps[1] > 0.04 and left >= 3 and right >= 3, "uneven, over both hands: not a buzz")
-- Evocation: a breath each second
m = channel(12051, 8)
assert(#m == 4 and m[1][2] == "r_evocation", "Evocation: four breaths, one per 2 s regen tick: " .. #m)
near(m[1][1], 2, 0.03, "the first at 2 s")
-- Cannibalize: a bite every 2 s
m = channel(20578, 10)
assert(#m == 5 and m[1][2] == "r_chew", "Cannibalize: five bites, 2 s apart")
near(m[2][1], 4, 0.03, "the second bite at 4 s")
io.write("PASS: channels: Arcane Missiles on its ticks (haste too), the last firmer; Blizzard's shards; Evocation; Cannibalize\n")

-- Fireball: the cast builds, released silent, felt as it lands (travel time), its own impact
local fired = {}
local vfire = V.Fire
V.Fire = function(key, ...) if key == "instant" then fired[#fired + 1] = { t = now, move = V.instantMove } end; return vfire(key, ...) end
local function cast(id, seconds, woundAfter, school)
    fired, moments = {}, {}
    now = now + 5
    casting = { now, now + seconds }
    rev("UNIT_SPELLCAST_START", "player", "k" .. id, id)
    run(seconds)
    casting = nil
    rev("UNIT_SPELLCAST_SUCCEEDED", "player", "k" .. id, id)
    rev("UNIT_SPELLCAST_STOP", "player", "k" .. id, id)
    local t0 = now
    if woundAfter then
        run(woundAfter)
        rev("UNIT_COMBAT", "target", "WOUND", "", 300, school)
    end
    run(0.5)
    RunTimers()
    return fired, t0
end
local f, t0 = cast(133, 3.5, 0.7, 4)
assert(#f == 1 and f[1].move == "fireball", "Fireball lands as its own: " .. tostring(f[1] and f[1].move))
near(f[1].t - t0, 0.7, 0.02, "at the wound, after its flight")
f = cast(133, 3.5, 0.05, 4)
assert(#f == 0, "a wound in the first 0.15 s isn't the bolt's")
f = cast(116, 3, 0.9, 16)
assert(#f == 1 and f[1].move == "frostbolt", "Frostbolt: its own impact")
f = cast(116, 3, 0.9, 4)
assert(#f == 0, "a fire wound isn't the Frostbolt's")
f = cast(11366, 6, 1.1, 4)
assert(#f == 1 and f[1].move == "pyroblast", "Pyroblast: its own impact")
f = cast(2948, 1.5, 0.2, 4)
assert(#f == 1 and f[1].move == "scorch", "Scorch: its own impact")
-- Flamestrike: no waiting for a wound (on the ground): the eruption at the release
local played = {}
local vplay = V.Play
V.Play = function(key, ...) played[#played + 1] = key; return vplay(key, ...) end
f = cast(2120, 3)
assert(#f == 0 and played[#played] == "flamestrike", "Flamestrike at the release: " .. tostring(played[#played]))
f = cast(118, 1.5)
assert(played[#played] == "polymorph", "Polymorph: its pop at the release")
V.Play = vplay
-- Instants: at the cast (around you) or as they land
local function instant(id, woundAfter, school)
    fired, moments = {}, {}
    now = now + 5
    rev("UNIT_SPELLCAST_SUCCEEDED", "player", "i" .. id, id)
    if woundAfter then run(woundAfter); rev("UNIT_COMBAT", "target", "WOUND", "", 100, school) end
    run(0.3)
    RunTimers()
    return fired
end
for id, move in pairs({ [122] = "frostNova", [120] = "coneOfCold", [1449] = "arcaneExplosion", [11113] = "blastWave",
    [1953] = "blink", [2139] = "counterspell", [11958] = "iceBlock", [11426] = "iceBarrier", [1463] = "manaShield",
    [1459] = "glow", [168] = "mantle", [12042] = "empower" }) do
    f = instant(id)
    assert(#f == 1 and f[1].move == move, "at the cast: " .. move .. " " .. tostring(f[1] and f[1].move))
    local hdKey
    for _, e in ipairs(moments) do if e.feel then hdKey = e.feel end end
    assert(hdKey == "r_" .. move, move .. ": its HD feel " .. tostring(hdKey))
end
f = instant(2136, 0.1, 4)
assert(#f == 1 and f[1].move == "fireBlast", "Fire Blast as it lands")
f = instant(10230, nil)
assert(#f == 1 and f[1].move == "frostNova", "Frost Nova, its top rank (by name)")
V.Fire = vfire
-- Frost Nova and Arcane Explosion: around you, both hands from the first moment
for _, k in ipairs({ "frostNova", "arcaneExplosion", "blastWave" }) do
    local l0, r0 = 0, 0
    for _, p in ipairs(V.PULSES[k]) do
        if p[1] < 0.3 then
            if p[4] <= 0 then l0 = math.max(l0, p[3] * math.min(1, 1 - p[4])) end
            if p[4] >= 0 then r0 = math.max(r0, p[3] * math.min(1, 1 + p[4])) end
        end
    end
    assert(l0 > 0.2 and r0 > 0.2, k .. ": both hands")
end
C.Feel, C.Moment = cFeel, cMoment
io.write("PASS: casts land as themselves after their flight (school-checked); Flamestrike and Polymorph at the release; instants at the cast, both hands for area spells\n")

---------------------------------------------------------------------------
-- 3. Her professions: Skinning (a knife, then the hide pulled free; nothing of mining's) and
-- Tailoring (stitches, a snip; a bolt of cloth wound and patted down)
---------------------------------------------------------------------------
do
    V.SetCastPreset("gather", "auto")
    V.SetCastPreset("craft", "auto")
    local enabled = K.Enabled
    K.Enabled = function() return true end
    C.Settings().hdFeels = true
    wipe(K.queue)
    local loops, playedNow, marks = {}, {}, {}
    -- (the markers as they're made: the link sends them from the queue while the frames run)
    local kmarker = K.Marker
    K.Marker = function(item) marks[#marks + 1] = item; return kmarker(item) end
    local vplay2 = V.Play
    V.Play = function(key, loop, ...) playedNow[#playedNow + 1] = key; return vplay2(key, loop, ...) end
    local function castOf(id, seconds)
        playedNow, marks = {}, {}
        wipe(K.queue)
        now = now + 5
        casting = { now, now + seconds }
        rev("UNIT_SPELLCAST_START", "player", "p" .. id, id)
        loops[#loops + 1] = V.looping and V.looping.pattern
        run(seconds)
        casting = nil
        rev("UNIT_SPELLCAST_SUCCEEDED", "player", "p" .. id, id)
        rev("UNIT_SPELLCAST_STOP", "player", "p" .. id, id)
        run(0.3)
        RunTimers()
    end
    -- Skinning: the knife's loop, the hide's peel at the end, its marker carrying it for WoW Helper
    castOf(8613, 2)
    assert(loops[#loops] == "skin", "skinning: the knife, not the pickaxe: " .. tostring(loops[#loops]))
    assert(playedNow[#playedNow] == "peel", "skinning succeeds: the hide pulled free: " .. tostring(playedNow[#playedNow]))
    local start, done
    for _, q in ipairs(marks) do
        if q.moment == 106 then start = q elseif q.moment == 107 then done = q end
    end
    assert(start and done, "its markers: 106 start, 107 succeeded")
    assert(done.touch == L.HdId("r_peel"), "the succeeded marker carries the peel's HD")
    assert(start.side == 5 and start.seed >= 128, "an Undead female's markers")
    for _, q in ipairs(marks) do
        assert((q.touch or 0) ~= L.HdId("r_pickaxe") and q.moment ~= 100 and q.moment ~= 101, "nothing of mining's")
    end
    assert(C.MomentSound("gather:skinning") == C.MomentSound("gather"), "its sound: Gathering's, never Mining's own")
    -- Tailoring: stitches, a snip; a bolt of cloth wound onto the bolt, then patted down
    TradeSkillFrame = { IsShown = function() return true end }
    GetTradeSkillLine = function() return "Tailoring" end
    castOf(3915, 2)
    assert(loops[#loops] == "sew" and playedNow[#playedNow] == "snip", "a shirt: stitches, a snip")
    castOf(2963, 3)
    assert(loops[#loops] == "roll" and playedNow[#playedNow] == "bolt", "a bolt of cloth: wound and patted: "
        .. tostring(loops[#loops]) .. " " .. tostring(playedNow[#playedNow]))
    TradeSkillFrame, GetTradeSkillLine = false, nil
    V.Play, K.Enabled, K.Marker = vplay2, enabled, kmarker
    io.write("PASS: Skinning: the knife, the hide pulled free (its marker carries it), nothing of mining's; Tailoring: stitches, a snip; bolts wound and patted down\n")
end

---------------------------------------------------------------------------
-- 4. Her model and her class: the Undead female's steps; a mage's defaults; a spell's crit
---------------------------------------------------------------------------
do
    local saved = WowHelperData
    WowHelperData = nil
    local rate = L.StepTiming(7)
    near(rate, 2.906, 1e-6, "her run: her own stride (666 ms), not the default 2.4")
    near((L.StepTiming(2.5)), 1.919, 1e-6, "her walk")
    WowHelperData = { timingDefaults = { run = { rate = 2.4, offset = 0.1, speed = 7 }, models = { ["5-3"] = { run = 2.95, walk = 1.9 } } } }
    near((L.StepTiming(7)), 2.95, 1e-6, "WoW Helper's published table first")
    UnitRace = function() return "Undead", "Scourge", 5 end
    UnitSex = function() return 2 end
    near((L.StepTiming(7)), 3.23, 1e-6, "the Undead male: his own stride, as heard (a table without him: the addon's)")
    UnitSex = function() return 3 end
    -- (her swings: her one-hand and staff animations are the Undead male's lengths: the kinds' defaults)
    local T = ns.Timing
    for _, k in ipairs({ "staff", "dagger", "oneHand" }) do
        local d, src = T.Offset(k, "main")
        assert(src == "guess" and d == T.KIND[k].delay, k .. ": the measured default")
    end
    WowHelperData = saved
    -- a mage's Recommended: low mana, an enemy's cast, aggro; the wand's shots; no melee swings
    local P = ns.Profiles
    local feel = P.Recommended("MAGE")
    assert(feel.events.oom.on and feel.events.targetCast.on and feel.events.aggro.on, "a mage's warnings on")
    assert(feel.events.gcd.on == false and feel.events.combo.on == false, "and the rest as Recommended")
    assert(feel.vibration.events.shot.on == true and feel.vibration.events.autoAttack.on == false, "the wand, no swings")
    -- a Fireball's crit: its own impact at full (Critical hit: ranged is off by default)
    fired = {}
    V.Fire = function(key, ...) if key == "instant" or key == "critRanged" then fired[#fired + 1] = key .. ":" .. tostring(V.instantMove) end; return vfire(key, ...) end
    now = now + 5
    casting = { now, now + 3.5 }
    rev("UNIT_SPELLCAST_START", "player", "crit", 133)
    run(3.5)
    casting = nil
    rev("UNIT_SPELLCAST_SUCCEEDED", "player", "crit", 133)
    rev("UNIT_SPELLCAST_STOP", "player", "crit", 133)
    run(0.6)
    rev("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 900, 4)
    run(0.3)
    RunTimers()
    assert(fired[1] == "instant:fireball", "a crit: its own impact: " .. tostring(fired[1]))
    V.Fire = vfire
    -- (the name rules and Study are a mage's only: a rogue's runes keep their own)
    UnitClass = function() return "Rogue", "ROGUE" end
    assert(V.MageOf(401762) == nil and V.MageOf(1302508) == nil, "another class: no Engrave or Study rule")
    assert(V.MageOf(133) ~= nil, "the mage's own IDs stay")
    UnitClass = function() return "Mage", "MAGE" end
    for _, p in ipairs(V.MAGE_PATTERNS) do
        if p.key == "peel" or p.key == "roll" or p.key == "bolt" then assert(p.group == "Crafts", p.key .. ": Crafts") end
    end
    io.write("PASS: the Undead female's steps (her stride), her swings (the measured defaults); a mage's Recommended; a spell's crit lands as itself\n")
end

---------------------------------------------------------------------------
-- 5. Mining's crack (2026-11-20, the user: "the crack no longer plays"): a cast the server ends
-- a touch before its time still cracks, and the crack is the strike firmer, not one more strike.
-- (The addon's own crack: without the link; with it WoW Helper times mining, tests/Gathering.lua)
---------------------------------------------------------------------------
do
    V.SetCastPreset("gather", "auto")
    local enabled = K.Enabled
    K.Enabled = function() return false end
    C.Settings().hdFeels = true
    local cues = {}
    local cm = C.Moment
    C.Moment = function(key, feel, opts)
        if key == "gather:mining" then cues[#cues + 1] = { t = now, intensity = opts and opts.intensity } end
        return cm(key, feel, opts)
    end
    local function mine(ends)
        cues = {}
        now = now + 5
        local t0 = now
        casting = { now, now + 3.2 }
        rev("UNIT_SPELLCAST_START", "player", "mine", 2575)
        run(ends)
        casting = nil
        rev("UNIT_SPELLCAST_SUCCEEDED", "player", "mine", 2575)
        rev("UNIT_SPELLCAST_STOP", "player", "mine", 2575)
        run(0.3)
        RunTimers()
        return cues, t0
    end
    local c = mine(3.2)
    assert(#c == 2 and c[1].intensity == nil and c[2].intensity == 6, "a strike, then the crack firmer: " .. #c)
    c = mine(3.1)
    assert(#c == 2 and c[2].intensity == 6, "ended 0.1 s early: the crack all the same, at the end: " .. #c)
    c = mine(2.0)
    assert(#c == 2, "even a short one: its strike and its crack")
    C.Moment, K.Enabled = cm, enabled
    io.write("PASS: mining: the crack plays firmer than a strike, even when the cast ends before its time\n")
end

---------------------------------------------------------------------------
-- 6. The plans WoW Helper reads (SpellPlans.lua): the rule written down, so its Try plays each
-- spell as the game does, even one never cast
---------------------------------------------------------------------------
do
    local book = { 25345, 5143, 133, 116, 2120, 10, 2136, 122 }
    ns.SpellRanks = ns.SpellRanks or {}
    ns.SpellRanks.EachBookSpell = function(fn) for _, id in ipairs(book) do fn(id, (MageSpellInfo(id))) end end
    assert(loadfile(root .. "/SpellPlans.lua"))("GamepadCompanion", ns)
    local P = ns.SpellPlans
    local p = P.Plan(25345)
    assert(p.m == "spell" and p.w == "channel" and p.tick == "r_missile" and p.last == "r_missileLast" and p.n == 5 and p.alt,
        "Arcane Missiles: five missiles, the last its own, by turns")
    assert(P.Plan(5143).n == 3, "rank 1: three")
    p = P.Plan(133)
    assert(p.m == "spell" and p.w == "cast" and p.imp == "r_fireball" and not p.tick and not p.rumble, "Fireball: its impact")
    assert(P.Plan(116).imp == "r_frostbolt", "Frostbolt: its impact")
    p = P.Plan(2120)
    assert(p.rumble and p.rumble[1] == "flamestrike" and not p.imp, "Flamestrike: its burst at the release on the rumble only, no impact")
    p = P.Plan(10)
    assert(p.tick == "r_blizzard" and p.last == "r_blizzard" and p.n == 8, "Blizzard: eight waves")
    p = P.Plan(2136)
    assert(p.m == "instant" and p.w == "hit" and p.f == "r_fireBlast" and type(p.d) == "number", "Fire Blast: as it lands")
    p = P.Plan(122)
    assert(p.m == "instant" and p.w == "cast" and p.f == "r_frostNova" and p.d == nil, "Frost Nova: at the cast")
    -- the export carries them, and keeps another character's
    GamepadCompanionHapticsDB = GamepadCompanionHapticsDB or {}
    H.DB().export = { spellPlans = { [999001] = { m = "instant", w = "cast", f = "r_bash" } } }
    GamepadCompanionHapticsDB.export = H.DB().export
    local e = L.Export()
    assert(e.spellPlans and e.spellPlans[25345] and e.spellPlans[25345].tick == "r_missile", "in the export")
    assert(e.spellPlans[999001] and e.spellPlans[999001].f == "r_bash", "another character's kept")
    assert(e.spellBook and #e.spellBook == #book and e.spellBook[1] == 25345, "the ranks this character knows")
    assert(e.moments, "the moments still there (HelperCues' wrap)")
    io.write("PASS: spell plans: each book spell's rule exported for WoW Helper, other characters' kept\n")
end
