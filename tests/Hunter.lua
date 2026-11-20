-- A hunter (and a Skyborne): every hunter spell of the client and what it plays, the shots' tails,
-- Aimed Shot's release, the pet's moments, traps, the pet's blows told from yours, the class defaults.
-- lua5.1 tests/Hunter.lua <addon folder>   (HUNTER_REPORT=1: the list, spell by spell)
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

local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- The client's hunter spells (tests/fixtures/hunter-spells.txt): every rank, its name and cast
local SPELLS, NAME, CAST = {}, {}, {}
for line in io.lines(root .. "/tests/fixtures/hunter-spells.txt") do
    local id, name, ms, channel, school, kind = line:match("^(%d+)\t([^\t]+)\t(%d+)\t(%d)\t(%a+)\t([^\r]+)")
    if id then
        id = tonumber(id)
        SPELLS[#SPELLS + 1] = { id = id, name = name, ms = tonumber(ms), channel = channel == "1", school = school, kind = kind }
        NAME[id], CAST[id] = name, tonumber(ms)
    end
end
-- (other spells the addon names: theirs, so name lookups never collide)
local OTHER = { [1539] = "Feed Pet Effect", [1604] = "Dazed", [6603] = "Attack", [5019] = "Shoot", [3018] = "Shoot",
    [2480] = "Shoot Bow", [7918] = "Shoot Gun", [7919] = "Shoot Crossbow", [2764] = "Throw", [19386] = "Wyvern Sting",
    [3355] = "Freezing Trap", [13810] = "Frost Trap", [14309] = "Freezing Trap" }
for id, name in pairs(OTHER) do NAME[id] = NAME[id] or name end
GetSpellInfo = function(id) return NAME[id] or ("Spell " .. tostring(id)), nil, nil, CAST[id] or 0 end
-- (the client calls buffs helpful)
local HELPFUL = {}
for _, s in ipairs(SPELLS) do
    if s.kind == "instant buff/other" or s.kind == "instant heal" or s.kind == "racial" then HELPFUL[s.id] = true end
end
IsSpellHelpful = function(id) return HELPFUL[id] == true end

-- The pet, the target, the auras: stood in for
local game = { pet = nil, petDead = false, petHp = 1000, happiness = 2, petTarget = true, auras = {} }
UnitExists = function(u) if u == "pet" then return game.pet ~= nil end return u == "player" or u == "target" end
UnitGUID = function(u) if u == "pet" then return game.pet end return "Player-1" end
UnitIsDead = function(u) if u == "pet" then return game.petDead end return false end
UnitHealthMax = function(u) return u == "pet" and game.petHp or 3000 end
UnitIsUnit = function(a, b) if a == "pettarget" and b == "target" then return game.petTarget end return a == b end
UnitAffectingCombat = function() return true end
UnitOnTaxi = function() return game.taxi == true end
UnitCanAttack = function() return true end
GetPetHappiness = function() return game.happiness end
C_UnitAuras = { GetAuraDataByIndex = function(unit, i, filter)
    local list = game.auras[unit] or {}
    local n = 0
    for _, a in ipairs(list) do
        if (filter or ""):find(a.harmful and "HARMFUL" or "HELPFUL") then
            n = n + 1
            if n == i and (not (filter or ""):find("PLAYER") or a.source == "player") then
                return { name = NAME[a.id], spellId = a.id, sourceUnit = a.source }
            end
            if n == i then return { name = "other", spellId = 0 } end
        end
    end
end }
local hooks = {}
hooksecurefunc = function(name, fn) hooks[name] = fn end
PetAttack, PetFollow, PetWait, CastPetAction = function() end, function() end, function() end, function() end
GetPetActionInfo = function(i) return ({ "PET_ACTION_ATTACK", "PET_ACTION_FOLLOW", "PET_ACTION_WAIT" })[i], nil, true end
GetTime = function() return now end
CraftFrame, TradeSkillFrame, ProfessionsFrame = false, false, false

-- The addon, Hunter.lua with it
for _, file in ipairs({ "Model.lua", "Shared.lua", "When.lua", "OptionsSkin.lua", "Window.lua", "Rumble.lua", "Haptics.lua",
    "Timing.lua", "Volume.lua", "SpellOverrides.lua", "HapticsLab.lua", "HelperLink.lua", "Stack.lua", "Hush.lua",
    "LightPresets.lua", "Lights.lua", "HelperCues.lua", "Hunter.lua", "FullFeel.lua", "Profiles.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
for _, f in ipairs(created) do
    if f.events and f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end
local V, L, HN, H = ns.Rumble, ns.HapticsLab, ns.Hunter, ns.Haptics
check(HN ~= nil, "Hunter.lua loads")

---------------------------------------------------------------------------
-- Coverage: every hunter spell of the client, and what it plays. A spell new to
-- the fixture with no line here fails: nothing falls through to a guess.
--   shot [tail]          Shooting at the impact (the weapon's), then its tail
--   cast <set>           its cast set while it lasts
--   instant <pattern> <when>
--   next <pattern>       on the next swing, felt as the ability
--   quiet                nothing at the cast (its own moment plays elsewhere, or nothing should)
---------------------------------------------------------------------------
local EXPECT = {
    ["Auto Shot"] = "shot", ["Multi-Shot"] = "shot multi", ["Serpent Sting"] = "shot sting",
    ["Scorpid Sting"] = "shot sting", ["Viper Sting"] = "shot sting", ["Black Arrow"] = "shot sting",
    ["Concussive Shot"] = "shot daze", ["Scatter Shot"] = "shot daze", ["Distracting Shot"] = "shot",
    ["Tranquilizing Shot"] = "shot",
    ["Aimed Shot"] = "cast shots", ["Sniper Shot"] = "cast shots", ["Volley"] = "cast volley",
    ["Arcane Shot"] = "instant judge hit ranged", ["Chimera Shot"] = "instant shock hit ranged",
    ["Summon Hawk"] = "instant rend hit ranged",
    ["Raptor Strike"] = "next slash", ["Mongoose Bite"] = "instant slash hit", ["Wing Clip"] = "instant rend hit",
    ["Carve"] = "instant cleave hit", ["Counterattack"] = "instant stab hit", ["Flanking Strike"] = "instant slash hit",
    ["Strider Kick"] = "instant bash hit", ["Lacerate"] = "quiet",
    ["Freezing Trap"] = "instant trap cast", ["Frost Trap"] = "instant trap cast", ["Immolation Trap"] = "instant trap cast",
    ["Explosive Trap"] = "instant trap cast",
    ["Aspect of the Beast"] = "instant aspect cast", ["Aspect of the Cheetah"] = "instant aspect cast",
    ["Aspect of the Falcon"] = "instant aspect cast", ["Aspect of the Hawk"] = "instant aspect cast",
    ["Aspect of the Monkey"] = "instant aspect cast", ["Aspect of the Pack"] = "instant aspect cast",
    ["Aspect of the Viper"] = "instant aspect cast", ["Aspect of the Wild"] = "instant aspect cast",
    ["Trueshot Aura"] = "instant aspect cast", ["Heart of the Lion"] = "instant aspect cast",
    ["Rapid Fire"] = "instant aspect cast", ["Readiness"] = "instant aspect cast",
    ["Feign Death"] = "instant feign cast", ["Disengage"] = "instant leap cast", ["Deterrence"] = "instant ward cast",
    ["Hunter's Mark"] = "instant micro cast", ["Beast Lore"] = "instant micro cast",
    ["Flare"] = "instant toss cast", ["Enchanted Flare"] = "instant toss cast",
    ["Bestial Wrath"] = "instant roar cast", ["Intimidation"] = "instant roar cast", ["Kill Command"] = "instant roar cast",
    ["Call Pet"] = "quiet", ["Feed Pet"] = "quiet", ["Dismiss Pet"] = "cast petCare", ["Revive Pet"] = "cast summon",
    ["Mend Pet"] = "cast petCare", ["Tame Beast"] = "cast tame", ["Scare Beast"] = "cast tame",
    ["Eyes of the Beast"] = "cast farsight", ["Eagle Eye"] = "cast farsight",
    ["Chimera Shot - Scorpid"] = "quiet", ["Chimera Shot - Serpent"] = "quiet", ["Chimera Shot - Viper"] = "quiet",
    ["Entrapment"] = "quiet", ["Improved Mend Pet"] = "quiet", ["Spirit Bond"] = "quiet",
    -- Skyborne
    ["Walk on Air"] = "instant updraft cast", ["Skysight"] = "cast farsight", ["Read Leyline"] = "cast farsight",
}
for _, t in ipairs({ "Beasts", "Demons", "Dragonkin", "Elementals", "Giants", "Hidden", "Humanoids", "Undead" }) do
    EXPECT["Track " .. t] = "instant micro cast"
end
-- (Tame Beast's own two, cast by the channel itself: quiet)
local BY_ID = { [13481] = "quiet", [13535] = "quiet" }

-- What a rule plays, in the words above
local function Plays(r)
    if not r then return "nothing (no rule)" end
    if r.moment == "shot" then return "shot" .. (r.tail and (" " .. r.tail) or "") end
    if r.moment == "spell" then return "cast " .. tostring(r.set) end
    if r.moment == "quiet" then return "quiet" end
    if r.moment == "instant" and r.next then return "next " .. tostring(r.pattern) end
    if r.moment == "instant" then
        return "instant " .. tostring(r.pattern) .. " " .. tostring(r.when) .. (r.how and r.how.ranged and " ranged" or "")
    end
    return tostring(r.moment)
end

-- (as the game asks: a cast or a channel as it starts, an instant as it goes off)
local function RuleAsCast(s)
    return V.SpellRule(s.id, (s.ms > 0 or s.channel) and math.max(s.ms, 1000) / 1000 or 0)
end

local KINDS_LETTERS = { ["instant hit"] = "h", ["cast hit"] = "h", ["instant offensive, no hit"] = "n",
    ["cast offensive, no hit"] = "nc", summon = "sg" }
local SCHOOL = { Physical = 1, Holy = 2, Fire = 4, Nature = 8, Frost = 16, Shadow = 32, Arcane = 64 }
local report = {}
for pass = 1, 2 do
    -- (pass 2: WoW Helper's spell kinds loaded, as in game)
    if pass == 2 then
        local kinds = {}
        for _, s in ipairs(SPELLS) do kinds[s.id] = { KINDS_LETTERS[s.kind] or "", SCHOOL[s.school] or 1 } end
        WowHelperData = { at = "test", spellKinds = kinds }
    end
    local names = {}
    for _, s in ipairs(SPELLS) do
        local want = BY_ID[s.id] or EXPECT[s.name]
        names[s.name] = true
        local r = RuleAsCast(s)
        local got = Plays(r)
        if not want then
            check(false, "pass " .. pass .. ": " .. s.name .. " (" .. s.id .. ") has no expectation: plays " .. got)
        else
            eq(got, want, "pass " .. pass .. ": " .. s.name .. " (" .. s.id .. ")")
        end
        check(not (r and r.guessed), s.name .. ": not a guess")
        check(not (r and r.moment == "spell" and r.set == "sweep"), s.name .. ": not the fallback set")
        check(not (r and r.moment == "instant" and r.pattern == "blow"), s.name .. ": not the generic Blow")
        -- (every pattern it names exists, with its pulses and its library feel)
        local pat = r and (r.pattern or r.tail)
        if pat then
            check(V.PULSES[pat] ~= nil, s.name .. ": " .. pat .. " has pulses")
            check(H.Feel("r_" .. pat) ~= nil, s.name .. ": r_" .. pat .. " is in the library")
        end
        if r and r.moment == "spell" then
            check(V.CAST_PRESETS and (function()
                for _, p in ipairs(V.CAST_PRESETS) do if p.key == r.set then return true end end
            end)(), s.name .. ": its set " .. tostring(r.set) .. " exists")
        end
        if pass == 1 then report[#report + 1] = string.format("%-8d %-24s %s", s.id, s.name, got) end
    end
    for name in pairs(EXPECT) do check(names[name], "the fixture has " .. name) end
end
WowHelperData = nil

---------------------------------------------------------------------------
-- Simulation: the shots, Aimed Shot's release, Volley's rain
---------------------------------------------------------------------------
V.Settings().enabled = true
local fired = {}
local vFire, labFire = V.Fire, L.Fire
V.Fire = function(key) fired[#fired + 1] = key .. (key == "instant" and (":" .. tostring(V.instantMove)) or "") end
L.Fire = function(key, gain) fired[#fired + 1] = "lab:" .. key end
local function Run() local list = timers; timers = {}; for _, t in ipairs(list) do if type(t) == "function" then t() elseif not t.cancelled then t.fn() end end end
local function Has(what) for _, f in ipairs(fired) do if f == what then return true end end return false end
local function Event(event, ...)
    for _, f in ipairs(created) do
        if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
    if HN.frame.events and HN.frame.events[event] then HN.handlers[event](...) end
end
-- (Hunter.lua's own frame: its handlers straight)
local function HunterEvent(event, ...) HN.handlers[event](...) end

-- Multi-Shot: Shooting, then the other arrows
V.ShotLoosed(2643)
Run(); Run()
check(Has("shot") and Has("instant:multi"), "Multi-Shot: the shot, then two more arrows")
fired = {}
V.ShotLoosed(25295)
Run(); Run()
check(Has("shot") and Has("instant:sting"), "Serpent Sting (any rank): the shot, then the venom")
fired = {}
V.ShotLoosed(75)
Run(); Run()
check(Has("shot") and #fired == 1, "Auto Shot: the shot alone")
-- Aimed Shot: its release looses the arrow
fired = {}
check(HN.CastReleased("shots", 20904), "Aimed Shot's release: handled here")
Run()
check(Has("shot"), "Aimed Shot: the arrow at its impact")
check(HN.CastReleased("petCare", 136) and HN.CastReleased("tame", 1515) and HN.CastReleased("summon", 982),
    "Mend Pet, Tame Beast, Revive Pet: a quiet end (the pet's moment plays)")
check(not HN.CastReleased("summon", 688), "a warlock's summon keeps its release")
NAME[900100] = "Steady Swing"
fired = {}
check(not HN.CastReleased("shots", 900100) and not Has("shot"), "another physical cast in the Shots set: no arrow")
-- (Your spells, asked with no cast going: a channel the client calls instant is a cast; an
-- instant listed in a set is not)
eq(Plays(V.SpellRule(13544)), "cast petCare", "Your spells: Mend Pet a channel")
eq(Plays(V.SpellRule(883)), "quiet", "Your spells: Call Pet an instant")
eq(Plays(V.SpellRule(2643)), "shot multi", "Your spells: Multi-Shot a shot")
-- (Arcane Shot's window takes only a magic wound: never the pet's blow just after it)
check(V.SpellRule(14287, 0).magicOnly == true and V.SpellRule(409433, 0).magicOnly == true, "Arcane, Chimera Shot: magic only")
check(not V.SpellRule(1495, 0).magicOnly, "Mongoose Bite: any wound")

---------------------------------------------------------------------------
-- The pet: called, dismissed, dead, revived, tamed; fed; happier
---------------------------------------------------------------------------
fired = {}
HunterEvent("PLAYER_ENTERING_WORLD")
now = now + 6
game.pet = "Pet-1"
HunterEvent("UNIT_PET", "player")
check(Has("lab:petArrive"), "Call Pet: paws in")
fired = {}
game.pet = nil
HunterEvent("UNIT_PET", "player")
check(Has("lab:petDismiss"), "Dismiss Pet: paws away")
fired = {}
game.pet = "Pet-1"
HunterEvent("UNIT_PET", "player")
game.petDead = true
HunterEvent("UNIT_HEALTH", "pet")
check(Has("lab:petDeath"), "the pet dies: its sad cue")
fired = {}
game.pet = nil
HunterEvent("UNIT_PET", "player")
check(not Has("lab:petDismiss"), "a dead pet gone: no Dismiss")
game.pet, game.petDead = "Pet-1", true
HunterEvent("UNIT_PET", "player")
fired = {}
game.petDead = false
HunterEvent("UNIT_HEALTH", "pet")
check(Has("lab:petArrive"), "Revive Pet: back on its feet")
-- (taming: the channel, then a new pet)
fired = {}
game.pet = nil
HunterEvent("UNIT_PET", "player")
fired = {}
HunterEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 1515)
now = now + 20
HunterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
game.pet = "Pet-2"
HunterEvent("UNIT_PET", "player")
check(Has("lab:petTamed") and not Has("lab:petArrive"), "Tame Beast: the bond, not a plain arrival")
-- (a loading screen: the pet comes with the world, no arrival)
fired = {}
game.pet = nil
HunterEvent("UNIT_PET", "player")
fired = {}
game.pet = "Pet-2"
HunterEvent("PLAYER_ENTERING_WORLD")
HunterEvent("UNIT_PET", "player")
check(not Has("lab:petArrive"), "a loading screen: no arrival")
now = now + 6
-- Feeding: munching while Feed Pet Effect lasts, a happy beat at its end
fired = {}
game.auras.pet = { { id = 1539 } }
HunterEvent("UNIT_AURA", "pet")
check(Has("lab:petFeed"), "Feed Pet: munching")
now = now + HN.FEED_EVERY
Run()
local munches = 0
for _, f in ipairs(fired) do if f == "lab:petFeed" then munches = munches + 1 end end
eq(munches, 2, "a munch every " .. HN.FEED_EVERY .. " s")
game.auras.pet = {}
HunterEvent("UNIT_AURA", "pet")
check(Has("lab:petHappy"), "the bowl empty: a happy beat")
now = now + HN.FEED_EVERY
fired = {}
Run()
check(not Has("lab:petFeed"), "no munching after")
-- Happiness: happier just after feeding plays once; later changes each their own
HunterEvent("UNIT_HAPPINESS", "pet")
fired = {}
game.happiness = 3
HunterEvent("UNIT_HAPPINESS", "pet")
check(not Has("lab:petHappy"), "happier right after feeding: no second beat")
now = now + 10
game.happiness = 2
HunterEvent("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
check(Has("lab:petUnhappy"), "less happy: a sulk")
-- (fed, then dismissed mid-meal: no munching on)
game.auras.pet = { { id = 1539 } }
HunterEvent("UNIT_AURA", "pet")
game.pet = nil
HunterEvent("UNIT_PET", "player")
fired = {}
Run(); Run()
check(not Has("lab:petFeed"), "the pet gone: no more munching")
game.pet = "Pet-2"
HunterEvent("UNIT_PET", "player")
-- (a meal that never ends: over after FEED_MAX)
fired = {}
HunterEvent("UNIT_AURA", "pet")
now = now + HN.FEED_MAX + 1
Run(); fired = {}; Run()
check(not Has("lab:petFeed"), "no munching past " .. HN.FEED_MAX .. " s")
game.auras.pet = {}
HunterEvent("UNIT_AURA", "pet")
now = now + 6
-- (a flight path: the pet goes and comes back quietly)
fired = {}
game.taxi = true
game.pet = nil
HunterEvent("UNIT_PET", "player")
game.pet = "Pet-2"
game.taxi = false
HunterEvent("UNIT_PET", "player")
check(not Has("lab:petDismiss") and not Has("lab:petArrive"), "a flight path: quiet")
now = now + 6
-- A heavy blow on the pet; a light one
fired = {}
HunterEvent("UNIT_COMBAT", "pet", "WOUND", nil, 50, 1)
check(not Has("lab:petHurt"), "a light blow on the pet: nothing")
HunterEvent("UNIT_COMBAT", "pet", "WOUND", nil, 300, 1)
check(Has("lab:petHurt"), "a fifth of its health: Pet hurt")
-- Commands
fired = {}
hooks.CastPetAction(1); hooks.PetFollow(); hooks.PetWait()
check(Has("lab:petAttack") and Has("lab:petCommand"), "attack, follow, stay")

---------------------------------------------------------------------------
-- The pet's blows: never your crit; a shot's result stays yours
---------------------------------------------------------------------------
fired = {}
now = now + 5
check(HN.ClaimsResult("WOUND", "CRITICAL", 1), "a physical crit on the target, your pet fighting it, no shot of yours: the pet's")
check(Has("lab:petCrit"), "its crit: Pet crit")
-- (a pet's plain blows: no feel at all, for any class: only its crit, faint (Nip), is felt)
fired = {}
now = now + 3
check(HN.ClaimsResult("WOUND", nil, 1), "a pet's plain hit: the pet's")
check(HN.ClaimsResult("DODGE", nil, 1) and HN.ClaimsResult("PARRY", nil, 1), "its dodged and parried blows: the pet's")
eq(#fired, 0, "a pet's plain hits, dodges, parries: nothing plays")
check(L.EVENT.petHit == nil, "no Pet hit moment")
check(L.EVENT.petCrit.on == false and L.EVENT.petHurt.on == false, "Pet crit, Pet hurt: off by default, any class")
check(ns.Profiles.RecommendedOn("events", "petCrit") == nil, "no class turns them on")
fired = {}
check(HN.ClaimsResult("WOUND", "CRITICAL", 1, true), "the Lab asking after Rumble for the same event: the same answer")
local crits = 0
for _, f in ipairs(fired) do if f == "lab:petCrit" then crits = crits + 1 end end
eq(crits, 1, "one Pet crit per event")
-- (two alike in one frame: two events, each its own)
check(HN.ClaimsResult("WOUND", "CRITICAL", 1) and HN.ClaimsResult("WOUND", "CRITICAL", 1, true), "a second like it in the same frame")
crits = 0
for _, f in ipairs(fired) do if f == "lab:petCrit" then crits = crits + 1 end end
eq(crits, 2, "two Pet crits for two events")
now = now + 0.5
V.ShotLoosed(75)
now = now + 0.4
check(not HN.ClaimsResult("WOUND", "CRITICAL", 1), "a shot of yours just left: its result is yours")
now = now + 0.1
check(HN.ClaimsResult("MISS", nil, 1), "the next one is the pet's (its miss is not yours)")
now = now + 1
check(not HN.ClaimsResult("WOUND", nil, 4), "a fire wound: not the pet's")
-- (WoW Helper learned the shot lands 0.5 s on: only a result near then is the shot's, the
-- pet's blow just after the shot leaves stays the pet's and never eats your crit)
local impact = V.ImpactDelay
V.ImpactDelay = function() return 0.5 end
now = now + 3
V.ShotLoosed(75)
now = now + 0.05
check(HN.ClaimsResult("WOUND", nil, 1), "learned: a blow 0.05 s after the shot left is the pet's")
now = now + 0.45
check(not HN.ClaimsResult("WOUND", "CRITICAL", 1), "learned: the crit where the shot lands is yours")
V.ImpactDelay = impact
game.pet = nil
now = now + 1
check(not HN.ClaimsResult("WOUND", "CRITICAL", 1), "no pet: not the pet's")
game.pet = "Pet-2"

---------------------------------------------------------------------------
-- Traps: laid, armed after 2 s, sprung when its effect lands; once
---------------------------------------------------------------------------
fired = {}
timers = {}
HunterEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 14311)
check(not Has("lab:trapArmed"), "laid: not armed yet")
Run()
check(Has("lab:trapArmed"), "armed")
fired = {}
HunterEvent("UNIT_AURA", "nameplate3", { addedAuras = { { name = "Freezing Trap", spellId = 14309, sourceUnit = "player" } } })
check(Has("lab:trapSprung"), "sprung on a mob nearby")
fired = {}
HunterEvent("UNIT_AURA", "target", { addedAuras = { { name = "Freezing Trap", sourceUnit = "player" } } })
check(not Has("lab:trapSprung"), "once per trap")
-- (no list of added auras: a scan)
HunterEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 13809)
game.auras.target = { { id = 13810, harmful = true, source = "player" } }
HunterEvent("UNIT_AURA", "target", { isFullUpdate = true })
check(Has("lab:trapSprung"), "Frost Trap sprung, by a scan")
-- (none out: nothing is looked at)
fired = {}
HunterEvent("UNIT_AURA", "target", { addedAuras = { { name = "Frost Trap", sourceUnit = "player" } } })
check(not Has("lab:trapSprung"), "no trap out: nothing")
-- (by id, whatever the client calls it)
HunterEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 14311)
HunterEvent("UNIT_AURA", "target", { addedAuras = { { name = "Freezing Trap Effect", spellId = 3355, sourceUnit = "player" } } })
check(Has("lab:trapSprung"), "sprung, matched by the effect's id")

---------------------------------------------------------------------------
-- Dazed in Cheetah
---------------------------------------------------------------------------
fired = {}
game.auras.player = { { id = 1604, harmful = true } }
HunterEvent("UNIT_AURA", "player")
check(not Has("lab:dazed"), "dazed without Cheetah: nothing here")
game.auras.player = {}
HunterEvent("UNIT_AURA", "player")
game.auras.player = { { id = 13159, source = "party1" }, { id = 1604, harmful = true } }
HunterEvent("UNIT_AURA", "player")
check(not Has("lab:dazed"), "dazed under a party hunter's Pack: theirs, nothing")
game.auras.player = {}
HunterEvent("UNIT_AURA", "player")
game.auras.player = { { id = 5118, source = "player" }, { id = 1604, harmful = true } }
HunterEvent("UNIT_AURA", "player")
check(Has("lab:dazed"), "dazed in your own Cheetah: a wobble")
V.Fire, L.Fire = vFire, labFire

---------------------------------------------------------------------------
-- The moments exist, unnumbered (95 is the last number), each feel in the library
---------------------------------------------------------------------------
for _, key in ipairs({ "trapArmed", "trapSprung", "dazed", "petArrive", "petDismiss", "petTamed", "petAttack",
    "petCommand", "petCrit", "petHurt", "petDeath", "petFeed", "petHappy", "petUnhappy" }) do
    local e = L.EVENT[key]
    check(e ~= nil, key .. ": a moment")
    check(e and H.Feel(e.feel) ~= nil, key .. ": its feel " .. tostring(e and e.feel) .. " in the library")
    check(ns.HelperCues.UNNUMBERED[key] == true and ns.HelperCues.MOMENT_N[key] == nil, key .. ": unnumbered")
end
-- (pets are fainter than you: no pet feel's strongest pulse above a third)
for _, key in ipairs({ "pawsIn", "pawsOut", "petFall", "nip", "bruise", "wag", "sulk", "crunch", "sic", "heel", "bond" }) do
    local top = 0
    for _, p in ipairs(H.Feel(key).pulses) do top = math.max(top, p[3]) end
    check(top <= 0.36, key .. ": faint (" .. top .. ")")
end

---------------------------------------------------------------------------
-- A Skyborne (race 95 High Order, 96 Windshaper): the markers carry race 15 (4 bits), so
-- WoW Helper learns under "15-<sex>"; what it learned is read back for her
---------------------------------------------------------------------------
local T = ns.Timing
for _, race in ipairs({ 95, 96 }) do
    UnitRace = function() return "Skyborne", "Skyborne", race end
    UnitSex = function() return 3 end
    eq(T.HelperModel(), "15-3", "race " .. race .. ": WoW Helper's key")
    T.Store().learned = { ["15-3|ranged|ranged"] = { v = 0.42, hits = 30 } }
    local v, source = T.Offset("ranged", "ranged")
    check(v == 0.42 and source == "learned", "race " .. race .. ": the learned shot timing applies (got " .. tostring(v) .. " " .. tostring(source) .. ")")
    WowHelperData = { at = "t" .. race, stepTiming = { ["15-3|run"] = { rate = 3, speed = 7, offset = 0.05, steps = 40 } } }
    local cal = L.StepCal("run")
    check(cal and cal.rate == 3, "race " .. race .. ": the learned footsteps apply")
    WowHelperData = nil
end
UnitRace = function() return "Human", "Human", 1 end
UnitSex = function() return 2 end
eq(T.HelperModel(), "1-2", "a human: unchanged")
T.Store().learned = {}

-- Class defaults
local P = ns.Profiles
local hunter = P.Recommended("HUNTER")
check(hunter.vibration.events.shot and hunter.vibration.events.shot.on, "Hunter: Shooting on")
check(hunter.vibration.events.critRanged and hunter.vibration.events.critRanged.on, "Hunter: ranged crits on")

if os.getenv("HUNTER_REPORT") then for _, line in ipairs(report) do io.write(line, "\n") end end
if failures > 0 then error(failures .. " of " .. checks .. " checks failed") end
io.write("PASS: hunter: ", #SPELLS, " spell ranks covered, ", checks, " checks\n")
