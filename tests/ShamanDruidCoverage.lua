-- Shaman and Druid coverage: every spell of both classes in WoW Forever and what it plays (the
-- shaman and druid pass, 2026-11-20). The spells are the client's own (tests/fixtures/shaman-spells.txt,
-- druid-spells.txt, from WoW Helper's --spells and --spell-kinds); each must play its own feel, none
-- generic. Then the iconic ones played out: lightning landing, totems set down, Ghost Wolf, a druid's
-- shapes (swings, steps, the shape let go), finishers by their points, Swipe at the paw's blow,
-- Hurricane and Tranquility tick by tick.
-- lua5.1 tests/ShamanDruidCoverage.lua <addon folder>
-- (the game's stubs: as tests/Haptics.lua has them)
local root = arg[1] or "."
local CLASS_SPELLS, byId = {}, {}
local kinds = {}
for _, cls in ipairs({ "shaman", "druid" }) do
    local list = {}
    CLASS_SPELLS[cls] = list
    for line in io.lines(root .. "/tests/fixtures/" .. cls .. "-spells.txt") do
        if not line:match("^#") then
            local f = {}
            for v in (line .. "	"):gmatch("([^	]*)	") do f[#f + 1] = v end
            local s = { id = tonumber(f[1]), name = f[2], line = f[3], school = tonumber(f[4]), cast = tonumber(f[5]),
                channel = f[6] == "1", helpful = f[7] == "1" }
            list[#list + 1] = s
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
for _, file in ipairs({ "Profiles.lua", "Model.lua", "Shared.lua", "TouchModel.lua", "Gestures.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "ComboPoints.lua", "Forms.lua", "Shaman.lua", "Druid.lua", "Haptics.lua", "Timing.lua", "Volume.lua",
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
-- (C_Timer.After at its time: impacts after a swing's delay, the shape let go a moment later)
local due = {}
C_Timer.After = function(d, fn) due[#due + 1] = { at = now + (d or 0), fn = fn } end
local function Due()
    local i = 1
    while i <= #due do
        if due[i].at <= now + 1e-9 then table.remove(due, i).fn() else i = i + 1 end
    end
end
local function run(seconds, step)
    step = step or 0.01
    for _ = 1, math.floor(seconds / step + 0.5) do
        now = now + step
        Due()
        for _, f in ipairs(created) do
            if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, step) end
        end
    end
end
local V, H, L, C, K = ns.Rumble, ns.Haptics, ns.HapticsLab, ns.HelperCues, ns.HelperLink
V.Settings().enabled = true
CraftFrame, TradeSkillFrame, ProfessionsFrame = false, false, false
local form = 0
GetShapeshiftFormID = function() return form end
UnitRace = function() return "Tauren", "Tauren", 6 end
UnitSex = function() return 3 end

---------------------------------------------------------------------------
-- 1. Coverage: every spell of each class the client has, and what it plays
---------------------------------------------------------------------------
local function Plays(s)
    local r = V.SpellRule(s.id, s.channel and 1 or s.cast / 1000)
    if not r then return "none" end
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

local function Cover(cls, token, EXPECT, triggered)
    UnitClass = function() return cls, token end
    local wrong, seen, ids = {}, {}, 0
    for _, s in ipairs(CLASS_SPELLS[cls:lower()]) do
        local key = s.line == "Engraving" and "Engrave" or s.name
        if not triggered(s) then
            local got, r = Plays(s)
            ids = ids + 1
            if EXPECT[key] ~= got then wrong[#wrong + 1] = s.id .. " " .. s.name .. ": " .. got .. " (expected " .. tostring(EXPECT[key]) .. ")" end
            -- (nothing generic: not the fallback set, not a guessed Blow, never a quiet one)
            if got == "set:sweep" or got == "cast:blow" or got == "hit:blow" or got == "quiet" or (r and r.guessed) then
                wrong[#wrong + 1] = s.id .. " " .. s.name .. ": " .. got .. " is generic"
            end
            -- (each feel exists: its pulses and its HD library entry)
            local pattern = got:match(":(.+)$")
            if pattern and got:sub(1, 4) ~= "set:" then
                assert(V.PULSES[pattern], s.name .. ": no pulses for " .. pattern)
                assert(H.Feel("r_" .. pattern), s.name .. ": no library feel r_" .. pattern)
            end
            seen[key] = true
        end
    end
    assert(#wrong == 0, cls .. " spells that play something else:\n  " .. table.concat(wrong, "\n  "))
    for key in pairs(EXPECT) do assert(seen[key], "expected but not in the client's list: " .. key) end
    io.write("PASS: " .. ids .. " " .. cls:lower() .. " spell IDs (every rank, the runes): each its own feel, none generic\n")
end

-- Shaman (both factions: orcs, tauren, trolls, Windshaper Skyborne; dwarves)
local ST = { ["Ancestral Fortitude"] = true, ["Elemental Devastation"] = true, ["Lightning Mastery"] = true,
    ["Two-Handed Axes and Maces"] = true }
Cover("Shaman", "SHAMAN", {
    ["Lightning Bolt"] = "impact:lightning", ["Chain Lightning"] = "impact:chain", ["Lava Burst"] = "impact:lavaBurst",
    ["Earth Shock"] = "hit:earthShock", ["Flame Shock"] = "hit:flameShock", ["Frost Shock"] = "hit:frostShock",
    ["Molten Blast"] = "hit:moltenBlast", ["Lava Lash"] = "hit:lavaLash", ["Stormstrike"] = "hit:stormstrike",
    ["Fire Nova"] = "cast:fireNova",
    ["Earthbind Totem"] = "cast:totemEarth", ["Stoneclaw Totem"] = "cast:totemEarth", ["Stoneskin Totem"] = "cast:totemEarth",
    ["Strength of Earth Totem"] = "cast:totemEarth", ["Tremor Totem"] = "cast:totemEarth", ["Decoy Totem"] = "cast:totemEarth",
    ["Searing Totem"] = "cast:totemFire", ["Magma Totem"] = "cast:totemFire", ["Flametongue Totem"] = "cast:totemFire",
    ["Frost Resistance Totem"] = "cast:totemFire",
    ["Healing Stream Totem"] = "cast:totemWater", ["Mana Spring Totem"] = "cast:totemWater", ["Mana Tide Totem"] = "cast:totemWater",
    ["Fire Resistance Totem"] = "cast:totemWater", ["Poison Cleansing Totem"] = "cast:totemWater",
    ["Disease Cleansing Totem"] = "cast:totemWater",
    ["Grounding Totem"] = "cast:totemAir", ["Windfury Totem"] = "cast:totemAir", ["Grace of Air Totem"] = "cast:totemAir",
    ["Nature Resistance Totem"] = "cast:totemAir", ["Windwall Totem"] = "cast:totemAir", ["Sentry Totem"] = "cast:totemAir",
    ["Totemic Call"] = "cast:totemCall", ["Totemic Recall"] = "cast:recall", ["Call of the Elements"] = "burst:totemCall",
    ["Call of the Ancestors"] = "burst:totemCall", ["Call of the Spirits"] = "burst:totemCall",
    ["Rockbiter Weapon"] = "cast:imbueRock", ["Flametongue Weapon"] = "cast:imbueFlame", ["Frostbrand Weapon"] = "cast:imbueFrost",
    ["Windfury Weapon"] = "cast:imbueWind",
    ["Lightning Shield"] = "cast:shieldOrbs", ["Water Shield"] = "cast:shieldOrbs", ["Earth Shield"] = "cast:shieldOrbs",
    ["Ghost Wolf"] = "burst:ghostWolf", ["Reincarnation"] = "cast:ankh", ["Ancestral Spirit"] = "burst:ankh",
    ["Feral Spirit"] = "cast:wolves", ["Purge"] = "cast:purge", ["Cure Poison"] = "cast:mend", ["Cure Disease"] = "cast:mend",
    ["Healing Wave"] = "set:healing", ["Lesser Healing Wave"] = "set:healing", ["Chain Heal"] = "burst:chainHeal",
    ["Healing Rain"] = "burst:healingRain", ["Riptide"] = "cast:hot",
    ["Water Breathing"] = "cast:glow", ["Water Walking"] = "cast:glow", ["Ancestral Guidance"] = "cast:glow",
    ["Spirit of the Alpha"] = "cast:glow", ["Nature's Swiftness"] = "cast:empower", ["Rage of the Farseer"] = "cast:empower",
    ["Far Sight"] = "set:farsight", ["Astral Recall"] = "set:travel", ["Engrave"] = "set:enchanting",
}, function(s)
    -- (set off, never cast: talents' procs; Overload's bolts and Healing Rain's drops (no cast time);
    -- Lightning Shield's discharge on an enemy)
    if ST[s.name] then return true end
    if (s.name == "Lightning Bolt" or s.name == "Chain Lightning" or s.name == "Healing Rain") and s.cast == 0 then return true end
    return s.name == "Lightning Shield" and not s.helpful
end)

-- Druid (both factions: night elves, High Order Skyborne; tauren, Windshaper Skyborne)
local DT = { ["Abolish Poison Effect"] = true, ["Pounce Bleed"] = true, ["Moonkin Aura"] = true }
Cover("Druid", "DRUID", {
    ["Bear Form"] = "cast:bearForm", ["Dire Bear Form"] = "cast:bearForm", ["Cat Form"] = "cast:catForm",
    ["Travel Form"] = "cast:travelForm", ["Aquatic Form"] = "cast:aquaticForm", ["Moonkin Form"] = "cast:moonkinForm",
    ["Tree of Life"] = "cast:treeForm", ["Prowl"] = "cast:prowl", ["Dash"] = "cast:dash",
    ["Claw"] = "hit:claw", ["Shred"] = "hit:shred", ["Rake"] = "hit:rake", ["Ravage"] = "hit:ravage",
    ["Ferocious Bite"] = "hit:bite", ["Rip"] = "cast:rip", ["Savage Roar"] = "cast:savageRoar", ["Pounce"] = "cast:pounce",
    ["Tiger's Fury"] = "cast:fury", ["Cower"] = "cast:cower", ["Berserk"] = "cast:empower",
    ["Feral Charge"] = "cast:charge", ["Feral Charge (Bear)"] = "cast:charge", ["Skull Bash"] = "cast:charge",
    ["Primal Bite"] = "hit:primalBite", ["Maul"] = "hit:maul", ["Swipe"] = "hit:swipe",
    ["Demoralizing Roar"] = "cast:roarBear", ["Challenging Roar"] = "cast:roarBear", ["Growl"] = "cast:growl",
    ["Bash"] = "cast:bash", ["Lacerate"] = "cast:lacerate", ["Enrage"] = "cast:fury", ["Frenzied Regeneration"] = "cast:fury",
    ["Survival Instincts"] = "cast:ward", ["Shifting Power"] = "cast:empower",
    ["Moonfire"] = "hit:moonfire", ["Sunfire"] = "hit:sunfire", ["Starsurge"] = "hit:starsurge",
    ["Starfire"] = "impact:starfire", ["Wrath"] = "impact:wrath", ["Hurricane"] = "tick:hurricane", ["Starfall"] = "cast:starfall",
    ["Insect Swarm"] = "cast:swarm", ["Faerie Fire"] = "cast:faerie", ["Entangling Roots"] = "burst:roots",
    ["Nature's Grasp"] = "cast:roots", ["Hibernate"] = "burst:sleep", ["Soothe Animal"] = "burst:sleep",
    ["Barkskin"] = "cast:bark", ["Thorns"] = "cast:thorns", ["Innervate"] = "cast:innervate",
    ["Teleport: Moonglade"] = "set:travel", ["Track Humanoids"] = "cast:micro",
    ["Healing Touch"] = "set:healing", ["Regrowth"] = "set:healing", ["Nourish"] = "set:healing", ["Wild Growth"] = "set:healing",
    ["Rejuvenation"] = "cast:hot", ["Lifebloom"] = "cast:hot", ["Living Seed"] = "cast:hot", ["Efflorescence"] = "cast:hot",
    ["Swiftmend"] = "cast:bloom", ["Tranquility"] = "tick:tranquility", ["Rebirth"] = "burst:ankh", ["Revive"] = "burst:ankh",
    ["Mark of the Wild"] = "cast:glow", ["Gift of the Wild"] = "cast:glow", ["Remove Curse"] = "cast:mend",
    ["Cure Poison"] = "cast:mend", ["Abolish Poison"] = "cast:mend", ["Nature's Swiftness"] = "cast:empower",
    ["Engrave"] = "set:enchanting",
}, function(s)
    -- (set off, never cast: Starfall's stars on an enemy)
    return DT[s.name] or (s.name == "Starfall" and not s.helpful)
end)
-- (a class's own are its own: another class's spell of the same name keeps its rule)
UnitClass = function() return "Mage", "MAGE" end
assert(V.ClassSpellOf(8042) == nil, "Earth Shock: a shaman's only")
UnitClass = function() return "Rogue", "ROGUE" end
assert(V.ClassSpellOf(1082) == nil, "Claw: a druid's only")
-- (a name that never loads: the map built again at most every 10 s, not on every cast)
UnitClass = function() return "Druid", "DRUID" end
now = now + 20
V.ClassSpellOf(1082)
local asked, info = 0, GetSpellInfo
local getName = C_Spell and C_Spell.GetSpellName
local function count(id) asked = asked + 1; if id == 768 then return nil end; return (info(id)) end
GetSpellInfo = count
if getName then C_Spell.GetSpellName = count end
V.ForgetClassSpells()
now = now + 20
V.ClassSpellOf(9830); local first = asked
V.ClassSpellOf(9830); V.ClassSpellOf(9896)
assert(first > 20 and asked - first < 5, "no rebuild on every call: " .. first .. " then " .. (asked - first))
now = now + 11
V.ClassSpellOf(9830)
assert(asked - first > 20, "tried again after 10 s")
GetSpellInfo = info
if getName then C_Spell.GetSpellName = getName end
now = now + 20
V.ClassSpellOf(9830)
-- (a form's swings are a weapon's patterns, never a spell's)
for _, p in ipairs(V.PATTERNS) do
    if p.key == "swClaw" or p.key == "swPaw" then assert(p.swing and not p.mage, p.key .. ": a swing") end
end

---------------------------------------------------------------------------
-- 2. Play: the iconic spells as they happen (events in, rumble and HD out)
---------------------------------------------------------------------------
local rf
for _, f in ipairs(created) do if f.events and f.events.START_AUTOREPEAT_SPELL and f.events.PLAYER_LEVEL_UP then rf = f end end
local function rev(...) rf.scripts.OnEvent(rf, ...) end
-- (every frame listening to an event: the class files' own too)
local function all(event, ...)
    for _, f in ipairs(created) do
        if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
local hd, moments, fired = {}, {}, {}
local cFeel, cMoment = C.Feel, C.Moment
C.Feel = function(key, gain, side) hd[#hd + 1] = { t = now, key = key, side = side } end
C.Moment = function(key, feel, opts) moments[#moments + 1] = { t = now, key = key, feel = feel }; return cMoment(key, feel, opts) end
local vfire = V.Fire
V.Fire = function(key, ...)
    if key == "instant" then fired[#fired + 1] = { t = now, move = V.instantMove, gain = V.fireGain } end
    return vfire(key, ...)
end
local played = {}
local vplay = V.Play
V.Play = function(key, ...) played[#played + 1] = key; return vplay(key, ...) end
UnitCanAttack = function() return true end
local chan, casting
UnitChannelInfo = function() if chan then return "x", nil, nil, chan[1] * 1000, chan[2] * 1000 end end
UnitCastingInfo = function() if casting then return "x", nil, nil, casting[1] * 1000, casting[2] * 1000 end end
local function reset() fired, moments, hd, played = {}, {}, {}, {} end
local function cast(id, seconds, woundAfter, school)
    reset()
    now = now + 5
    casting = { now, now + seconds }
    rev("UNIT_SPELLCAST_START", "player", "k" .. id, id)
    run(seconds)
    casting = nil
    all("UNIT_SPELLCAST_SUCCEEDED", "player", "k" .. id, id)
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
local function instant(id, woundAfter, school, flag)
    reset()
    now = now + 5
    all("UNIT_SPELLCAST_SENT", "player", "target", "i" .. id, id)
    all("UNIT_SPELLCAST_SUCCEEDED", "player", "i" .. id, id)
    local t0 = now
    if woundAfter then run(woundAfter); rev("UNIT_COMBAT", "target", "WOUND", flag or "", 100, school) end
    run(0.4)
    RunTimers()
    return fired, t0
end
local function channel(id, seconds)
    reset()
    now = now + 5
    chan = { now, now + seconds }
    local t0 = now
    rev("UNIT_SPELLCAST_CHANNEL_START", "player", "c" .. id, id)
    run(seconds - 0.02)
    rev("UNIT_SPELLCAST_CHANNEL_STOP", "player", "c" .. id, id)
    chan = nil
    run(0.5)
    local out = {}
    for _, e in ipairs(hd) do out[#out + 1] = { e.t - t0, e.key, e.side } end
    return out
end
local function hdOf(key)
    for _, e in ipairs(moments) do if e.feel == key then return true end end
    return false
end

-- The shaman ----------------------------------------------------------------
UnitClass = function() return "Shaman", "SHAMAN" end
UnitRace = function() return "Dwarf", "Dwarf", 3 end
-- Lightning Bolt: felt where it lands (after its flight), a nature wound only
local f, t0 = cast(403, 2.5, 0.6, 8)
assert(#f == 1 and f[1].move == "lightning", "Lightning Bolt lands as itself: " .. tostring(f[1] and f[1].move))
near(f[1].t - t0, 0.6, 0.02, "at the wound")
f = cast(403, 2.5, 0.6, 1)
assert(#f == 0, "a swing's wound isn't the bolt's")
-- Chain Lightning: its own impact, then each hop fainter, hand to hand
f = cast(421, 2.5, 0.5, 8)
assert(#f == 1 and f[1].move == "chain", "Chain Lightning lands as itself")
local hops = {}
for _, p in ipairs(V.PULSES.chain) do if p[3] >= 0.3 then hops[#hops + 1] = p end end
assert(#hops == 3 and hops[1][3] > hops[2][3] and hops[2][3] > hops[3][3], "three hops, each fainter")
assert(hops[2][4] * hops[3][4] < 0, "the hops cross from hand to hand")
-- Shocks: as they land, a magic wound only (a swing's isn't theirs)
f = instant(8042, 0.1, 8)
assert(#f == 1 and f[1].move == "earthShock", "Earth Shock as it lands")
f = instant(8056, 0.1, 1)
assert(#f == 0, "a physical wound isn't Frost Shock's")
-- Stormstrike: the weapon's blow, timed as a swing
f, t0 = instant(17364, 0.05, 1)
assert(#f == 1 and f[1].move == "stormstrike", "Stormstrike")
near(f[1].t - t0, 0.05 + V.ImpactDelay(V.WeaponKind(16), "main"), 0.02, "at the weapon's impact")
-- Totems set down: each element its own, at the cast, its HD too
for id, move in pairs({ [8071] = "totemEarth", [3599] = "totemFire", [5394] = "totemWater", [8512] = "totemAir",
    [437009] = "totemCall", [36936] = "recall", [8017] = "imbueRock", [324] = "shieldOrbs" }) do
    f = instant(id)
    assert(#f == 1 and f[1].move == move, move .. " at the cast: " .. tostring(f[1] and f[1].move))
    assert(hdOf("r_" .. move), move .. ": its HD feel")
end
-- (the earth totem: a stone set down, its first moment the heaviest)
assert(V.PULSES.totemEarth[1][3] >= 0.8, "a stone's thud")
-- Ghost Wolf: its cast, then down to all fours at the release
cast(2645, 3)
assert(played[#played] == "ghostWolf", "Ghost Wolf at the release: " .. tostring(played[#played]))
-- Reincarnation: its breath back; the Lab's Alive stays quiet for it
local labFired = {}
local lfire = L.Fire
L.Fire = function(key, ...) labFired[#labFired + 1] = key; return lfire(key, ...) end
f = instant(21169)
assert(#f == 1 and f[1].move == "ankh", "Reincarnation: its own")
all("PLAYER_ALIVE")
for _, k in ipairs(labFired) do assert(k ~= "alive", "no Alive on top of Reincarnation") end
run(4)
all("PLAYER_ALIVE")
assert(labFired[#labFired] == "alive", "a later return: Alive as ever")
L.Fire = lfire
-- a shaman's Recommended: low mana, an enemy's cast (Earth Shock's interrupt)
local P = ns.Profiles
local feel = P.Recommended("SHAMAN")
assert(feel.events.oom.on and feel.events.targetCast.on, "a shaman's warnings on")
io.write("PASS: shaman: lightning lands as itself (Chain Lightning hop by hop), shocks on a magic wound, Stormstrike at the blow, totems by element, Ghost Wolf, Reincarnation\n")

-- The druid -----------------------------------------------------------------
UnitClass = function() return "Druid", "DRUID" end
UnitRace = function() return "Tauren", "Tauren", 6 end
-- Shapes: each its own body as you take it; then the swings, the steps, the timing key
for id, move in pairs({ [5487] = "bearForm", [9634] = "bearForm", [768] = "catForm", [783] = "travelForm",
    [1066] = "aquaticForm", [24858] = "moonkinForm" }) do
    f = instant(id)
    assert(#f == 1 and f[1].move == move, move .. ": " .. tostring(f[1] and f[1].move))
    assert(hdOf("r_" .. move), move .. ": its HD feel")
end
local F = ns.Forms
form = 5
assert(V.SwingPattern(16) == "swPaw" and V.WeaponKind(16) == "form", "a bear's swings: its paw, the form's timing")
assert(ns.Timing.Key("form", "main") == "6-3-f5|form|main", "learned per form: " .. ns.Timing.Key("form", "main"))
form = 1
assert(V.SwingPattern(16) == "swClaw", "a cat's swings: its claws")
form = 31
assert(V.SwingPattern(16) ~= "swClaw" and V.SwingPattern(16) ~= "swPaw", "a moonkin swings its weapon")
-- (no feet of yours in a beast form; travel form rides)
local feet
local markers = L.StepMarkers
L.StepMarkers = function(t, onFoot, speed) feet = onFoot; return markers(t, onFoot, speed) end
GetUnitSpeed = function() return 7 end
local engine = H.DB().engine
H.DB().engine = true
form = 0; L.Poll(); assert(feet == true, "your own feet")
form = 1; L.Poll(); assert(feet == false, "a cat: no steps of yours (nor markers to learn from)")
form = 3; L.Poll(); assert(feet == false and select(2, F.Beast()) == true, "travel form: rides")
form = 0; L.Poll()
H.DB().engine = engine
GetUnitSpeed = function() return 0 end
L.StepMarkers = markers
-- (the shape let go: its own feel; one shape to another: only the new one's)
now = now + 5
form = 5; all("UPDATE_SHAPESHIFT_FORM")
reset()
form = 0; all("UPDATE_SHAPESHIFT_FORM")
run(0.4); RunTimers()
assert(fired[#fired] and fired[#fired].move == "unshift", "back to your own shape: " .. tostring(fired[1] and fired[1].move))
form = 5; all("UPDATE_SHAPESHIFT_FORM")
now = now + 5
reset()
form = 0; all("UPDATE_SHAPESHIFT_FORM")
run(0.05)
all("UNIT_SPELLCAST_SUCCEEDED", "player", "cat", 768)
form = 1; all("UPDATE_SHAPESHIFT_FORM")
run(0.4); RunTimers()
assert(fired[1] and fired[1].move == "catForm", "the cat's own")
for _, e in ipairs(fired) do assert(e.move ~= "unshift", "bear to cat: no shape let go between") end
-- Finishers: by the points they spend (sent with 5, then the points gone)
local points = 5
GetComboPoints = function() return points end
local function finisher(id, n, woundAfter)
    points = n
    reset()
    now = now + 5
    all("UNIT_SPELLCAST_SENT", "player", "target", "f" .. id, id)
    points = 0
    all("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    all("UNIT_SPELLCAST_SUCCEEDED", "player", "f" .. id, id)
    if woundAfter then run(woundAfter); rev("UNIT_COMBAT", "target", "WOUND", "", 400, 1) end
    run(0.4)
    RunTimers()
    return fired[1]
end
local full, faint = finisher(22568, 5, 0.05), finisher(22568, 1, 0.05)
assert(full and full.move == "bite" and full.gain == nil, "Ferocious Bite with 5: full")
assert(faint and faint.move == "bite" and math.abs(faint.gain - 0.35) < 1e-6, "with 1: faint " .. tostring(faint and faint.gain))
local mid = finisher(1079, 3)
assert(mid.move == "rip" and math.abs(mid.gain - 0.675) < 1e-6, "Rip with 3: between " .. tostring(mid.gain))
GetComboPoints = nil
-- Swipe: one wide arc, felt at the paw's blow (the form's impact), sweeping left to right
form = 5
f, t0 = instant(769, 0.05, 1)
assert(#f == 1 and f[1].move == "swipe", "Swipe at its blow")
near(f[1].t - t0, 0.05 + V.ImpactDelay("form", "main"), 0.02, "the form's impact")
local sw = V.PULSES.swipe
assert(sw[1][4] < 0 and sw[#sw][4] > 0 and #sw >= 5, "left to right, catching hide after hide")
-- Maul: the next swing is the paw's
reset()
now = now + 5
UnitAttackSpeed = function() return 2.5 end
all("UNIT_SPELLCAST_SUCCEEDED", "player", "m", 6807)
run(0.3)
rev("UNIT_COMBAT", "target", "WOUND", "", 400, 1)
run(0.5); RunTimers()
assert(fired[1] and fired[1].move == "maul", "Maul: " .. tostring(fired[1] and fired[1].move))
form = 0
-- Moonfire: a magic wound only; Starfire and Wrath where they land
f = instant(8921, 0.1, 1)
assert(#f == 0, "a swing's wound isn't Moonfire's")
f = instant(8921, 0.1, 64)
assert(#f == 1 and f[1].move == "moonfire", "Moonfire as it lands")
f = cast(2912, 3.5, 0.8, 64)
assert(#f == 1 and f[1].move == "starfire", "Starfire lands as itself")
f = cast(5176, 2, 0.6, 8)
assert(#f == 1 and f[1].move == "wrath", "Wrath lands as itself")
-- Entangling Roots: the roots at the release
cast(339, 1.5)
assert(played[#played] == "roots", "roots at the release")
-- Hurricane: ten gusts over its ten seconds; Tranquility five breaths
local m = channel(16914, 10)
assert(#m == 10, "Hurricane: ten gusts: " .. #m)
for i, e in ipairs(m) do near(e[1], i, 0.03, "gust " .. i); assert(e[2] == "r_hurricane", "a gust") end
m = channel(740, 10)
assert(#m == 5 and m[1][2] == "r_tranquility", "Tranquility: five breaths: " .. #m)
near(m[1][1], 2, 0.03, "the first at 2 s")
-- (heals over time: barely there)
for _, p in ipairs(V.PULSES.hot) do assert(p[3] <= 0.1, "a heal over time: faint") end
local dfeel = P.Recommended("DRUID")
assert(dfeel.events.combo.on and dfeel.events.oom.on, "a druid's: combo points, low mana")
io.write("PASS: druid: each shape its body, a cat's claws and a bear's paw as swings (timed per form), no steps in a beast form, the shape let go; finishers by their points; Swipe at the blow; Maul; moon and sun; Hurricane and Tranquility tick by tick\n")
C.Feel, C.Moment, V.Fire, V.Play = cFeel, cMoment, vfire, vplay
