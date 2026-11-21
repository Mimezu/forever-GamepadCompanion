-- A warrior's feels (the warrior pass, 2026-11-20; docs/WARRIOR-ROGUE.md): what each warrior
-- spell plays (Rumble's V.CLASS_SPELLS.WARRIOR, as V.MAGE), its own patterns, Slam's wind-up and
-- its blow, Charge's run and its crash. Loaded right after Rumble.lua. tests/Warrior.lua lists
-- every warrior spell of the client and what it plays.
--
-- Materials: steel on steel and on bodies, a shield's wood and iron boss, boots on the ground,
-- the chest of a shout. Blows land at the weapon's impact (Rumble's AbilityResult, melee), never
-- at the press; area blows are several bodies, one after another, never one blob.
local _, ns = ...
local V = ns.Rumble
if not V or not V.AddPatterns then return end
local WR = {}
ns.Warrior = WR

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
local function Pu(t, len, s, side) return { t, len, s, side or 0 } end

-- Patterns (Rumble's V.AddPatterns: the Lab's library as "r_" + key, WoW Helper crafts their
-- HD): steps for the plain engine (each 0.1 s or more), pulses for the Beta engine.
WR.PATTERNS = {
    -- Stances: a change of footing, faint
    { key = "stanceBattle", label = "Battle Stance", art = "slash", move = true,        -- feet set, the grip closing
        steps = { { 0.12, 0.08, 0.1 }, { 0.25, 0.3, 0.12 } },
        pulses = { Pu(0, 0.05, 0.08, -0.3), Pu(0.13, 0.08, 0.2, 0.3) } },
    { key = "stanceDefensive", label = "Defensive Stance", art = "ward", move = true,   -- the shield brought up against the arm
        steps = { { 0.15, 0.05, 0.1 }, { 0.35, 0.1, 0.12 }, { 0.08, 0.08, 0.1 } },
        pulses = { Pu(0, 0.05, 0.1, -0.6), Pu(0.1, 0.1, 0.28, -0.6), Pu(0.27, 0.05, 0.07) } },
    { key = "stanceBerserker", label = "Berserker Stance", art = "heart", move = true,  -- the blood up: two hard beats
        steps = { { 0.4, 0.4, 0.1 }, { 0, 0, 0.1 }, { 0.5, 0.5, 0.1 }, { 0.1, 0.1, 0.1 } },
        pulses = { Pu(0, 0.08, 0.26, -0.2), Pu(0.17, 0.05, 0.1, -0.2), Pu(0.4, 0.08, 0.34, -0.2), Pu(0.57, 0.05, 0.13, -0.2) } },
    -- Charge, Intercept: the run as you go, the crash as you reach it (WR.Arrived)
    { key = "rush", label = "Rush", art = "charge", move = true,                         -- footfalls quickening
        steps = { { 0.15, 0.05, 0.1 }, { 0.05, 0.2, 0.1 }, { 0.25, 0.1, 0.1 } },
        pulses = { Pu(0, 0.05, 0.08, -0.5), Pu(0.14, 0.05, 0.1, 0.5), Pu(0.25, 0.05, 0.12, -0.5), Pu(0.34, 0.05, 0.14, 0.5) } },
    { key = "crash", label = "Crash", art = "charge", move = true,                       -- a shoulder into a body
        steps = { { 1, 0.9, 0.14 }, { 0.25, 0.2, 0.1 } },
        pulses = { Pu(0, 0.12, 0.85), Pu(0.16, 0.05, 0.2), Pu(0.27, 0.05, 0.08) } },
    -- Blows, at the weapon's impact
    { key = "whirlwind", label = "Whirlwind", art = "whirl", move = true,               -- round you: three bodies, one at a time
        steps = { { 0.6, 0.05, 0.1 }, { 0.4, 0.4, 0.1 }, { 0.05, 0.6, 0.1 }, { 0.12, 0.12, 0.1 } },
        pulses = { Pu(0, 0.05, 0.4, -0.9), Pu(0.13, 0.05, 0.1, -0.3), Pu(0.2, 0.05, 0.34, 0.1), Pu(0.33, 0.05, 0.1, 0.6),
            Pu(0.41, 0.05, 0.3, 0.9), Pu(0.55, 0.08, 0.09) } },
    { key = "cleaveArc", label = "Cleave", art = "cleave", move = true,                 -- the edge bites one, drags through to the next
        steps = { { 0.8, 0.2, 0.12 }, { 0.2, 0.2, 0.1 }, { 0.15, 0.55, 0.1 } },
        pulses = { Pu(0, 0.08, 0.6, -0.7), Pu(0.1, 0.1, 0.12), Pu(0.22, 0.06, 0.38, 0.7) } },
    { key = "execute", label = "Execute", art = "slash", move = true,                   -- the finishing chop, deep; the edge wrenched free
        steps = { { 1, 1, 0.2 }, { 0, 0, 0.1 }, { 0.3, 0.25, 0.1 } },
        pulses = { Pu(0, 0.22, 1), Pu(0.3, 0.05, 0.22), Pu(0.43, 0.05, 0.08) } },
    { key = "mortal", label = "Mortal Strike", art = "slash", move = true,              -- a hard chop, then the tear
        steps = { { 0.9, 0.8, 0.12 }, { 0.3, 0.4, 0.12 } },
        pulses = { Pu(0, 0.1, 0.8), Pu(0.12, 0.12, 0.25, 0.3), Pu(0.3, 0.05, 0.08) } },
    { key = "overpower", label = "Overpower", art = "stab", move = true,                -- two quick cuts through the opening
        steps = { { 0.6, 0.7, 0.1 }, { 0.75, 0.5, 0.1 } },
        pulses = { Pu(0, 0.05, 0.5, 0.4), Pu(0.09, 0.06, 0.62, -0.2) } },
    { key = "shieldBash", label = "Shield Bash", art = "bash", move = true,             -- wood and an iron boss, into a face
        steps = { { 1, 0.5, 0.12 }, { 0.2, 0.1, 0.1 } },
        pulses = { Pu(0, 0.08, 0.85, -0.5), Pu(0.1, 0.05, 0.18, -0.5), Pu(0.2, 0.05, 0.07) } },
    { key = "slamHit", label = "Slam", art = "slam", move = true,                       -- the overhead blow come down
        steps = { { 1, 1, 0.18 }, { 0.3, 0.3, 0.1 } },
        pulses = { Pu(0, 0.16, 0.95), Pu(0.2, 0.05, 0.25), Pu(0.32, 0.05, 0.1) } },
    -- At the cast
    { key = "brace", label = "Brace", art = "ward", move = true,                        -- the shield set, braced
        steps = { { 0.45, 0.15, 0.1 }, { 0.15, 0.05, 0.2 } },
        pulses = { Pu(0, 0.08, 0.35, -0.5), Pu(0.12, 0.2, 0.12, -0.5) } },
    { key = "shout", label = "Shout", art = "burst", move = true,                       -- the chest swelling, the voice going out
        steps = { { 0.25, 0.25, 0.1 }, { 0.6, 0.6, 0.25 }, { 0.2, 0.2, 0.12 } },
        pulses = { Pu(0, 0.1, 0.15), Pu(0.1, 0.25, 0.45), Pu(0.38, 0.05, 0.18, -0.8), Pu(0.42, 0.05, 0.18, 0.8),
            Pu(0.56, 0.05, 0.07) } },
    { key = "enrage", label = "Enrage", art = "heart", move = true,                     -- the blood pounding, faster, harder
        steps = { { 0.4, 0.25, 0.1 }, { 0, 0, 0.15 }, { 0.5, 0.3, 0.1 }, { 0, 0, 0.1 }, { 0.6, 0.35, 0.1 } },
        pulses = { Pu(0, 0.08, 0.28, -0.3), Pu(0.11, 0.05, 0.1, -0.3), Pu(0.36, 0.08, 0.36, -0.3), Pu(0.46, 0.05, 0.14, -0.3),
            Pu(0.64, 0.08, 0.44, -0.3), Pu(0.73, 0.05, 0.17, -0.3) } },
    { key = "secondWind", label = "Second wind", art = "rise", move = true,             -- a deep breath, the body steadying
        steps = { { 0.2, 0.2, 0.2 }, { 0.45, 0.45, 0.25 }, { 0.12, 0.12, 0.1 } },
        pulses = { Pu(0, 0.25, 0.18), Pu(0.3, 0.3, 0.38), Pu(0.7, 0.05, 0.1) } },
    { key = "disarm", label = "Disarm", art = "bash", move = true,                      -- the wrist struck, the weapon wrenched away, landing
        steps = { { 0.5, 0.6, 0.1 }, { 0.15, 0.3, 0.1 }, { 0, 0, 0.15 }, { 0.05, 0.12, 0.1 } },
        pulses = { Pu(0, 0.05, 0.45, 0.3), Pu(0.08, 0.1, 0.2, 0.6), Pu(0.4, 0.05, 0.1, 0.9) } },
    { key = "hook", label = "Meathook", art = "charge", move = true,                    -- the chain thrown, catching, yanked back
        steps = { { 0.1, 0.2, 0.1 }, { 0.4, 0.5, 0.1 }, { 0.5, 0.3, 0.15 } },
        pulses = { Pu(0, 0.05, 0.12, 0.6), Pu(0.18, 0.05, 0.35, 0.8), Pu(0.25, 0.15, 0.5, -0.2) } },
    -- Slam's cast: the weapon raised over the head, held, the grip tightening (a loop: faint)
    { key = "windup", label = "Wind-up", art = "draw", group = "Spells",
        steps = { { 0.08, 0.08, 0.2 }, { 0.15, 0.15, 0.2 }, { 0, 0, 0.2 } },
        pulses = { cycle = 0.8, Pu(0, 0.1, 0.05), Pu(0.4, 0.05, 0.08) } },
}

V.AddPatterns(WR.PATTERNS)

---------------------------------------------------------------------------
-- What each warrior spell plays: V.CLASS_SPELLS.WARRIOR (every rank by its name, a warrior's
-- only). melee: timed at the weapon's impact; avoidOnly: no blow of its own (a dodge of it
-- still shows); scale: its strength now.
---------------------------------------------------------------------------
local function With(e, extra)
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end
local function Hit(move, extra) return With({ move = move, when = "hit", melee = true }, extra) end
local function Cast(move, extra) return With({ move = move, when = "cast" }, extra) end
local function Faint(g) return function() return g end end
-- (quiet by design, by its ID: Sweeping Strikes' extra blow is named as the cast)
local function Quiet(why) return { moveOf = function() return false end, why = why } end

-- Slam: a wind-up loop while cast; its release opens the blow's window (at the weapon's impact)
function WR.SlamReleased(spellID)
    if V.AbilityCast then
        V.AbilityCast("slamHit", spellID, nil, { melee = true },
            { volume = 1, name = spellID and not secret(spellID) and SpellName(spellID) or nil })
    end
    return true
end
local SLAM = { set = "feel:windup", released = WR.SlamReleased }

local SPELLS = {
    -- Stances (Gladiator Stance: Forever's rune)
    [2457] = Cast("stanceBattle"), [412513] = Cast("stanceBattle"),
    [71] = Cast("stanceDefensive"), [2458] = Cast("stanceBerserker"),
    -- The run; the crash as you reach it (the stun on the target, WR.Arrived)
    [100] = Cast("rush"), [20252] = Cast("rush"),                             -- Charge, Intercept
    -- At the weapon's impact
    [12294] = Hit("mortal"), [23881] = Hit("mortal"),                         -- Mortal Strike, Bloodthirst
    [7384] = Hit("overpower"), [402911] = Hit("overpower"),                   -- Overpower, Raging Blow
    [20647] = Hit("execute"), [1680] = Hit("whirlwind"),
    [845] = Hit("cleaveArc"), [78] = Hit("slash"),                            -- Cleave, Heroic Strike (next swing)
    [694] = Hit("slash"), [6572] = Hit("slash"), [429765] = Hit("slash"),     -- Mocking Blow, Revenge, Quick Strike
    [402927] = Hit("slash"), [403196] = Hit("slash"),                         -- Victory Rush, Devastate
    [1310222] = Hit("stab"), [1715] = Hit("rend"),                            -- Spearing Strike (Forever), Hamstring
    [72] = Hit("shieldBash"), [23922] = Hit("shieldBash"), [6552] = Hit("bash"), -- Shield Bash, Shield Slam, Pummel
    -- Around you, at the cast (no flight, nothing to wait for)
    [6343] = Cast("slam"), [440488] = Cast("slam"),                           -- Thunder Clap, Shockwave
    -- No blow of their own: at the cast
    [12809] = Cast("bash", { avoidOnly = true }), [676] = Cast("disarm", { avoidOnly = true }),
    [403228] = Cast("hook", { avoidOnly = true }),                            -- Concussion Blow, Disarm, Meathook
    -- Shouts: the big ones full, the buffs (cast often) fainter
    [1161] = Cast("shout"), [5246] = Cast("shout"), [1160] = Cast("shout"), [12323] = Cast("shout"), [426490] = Cast("shout"),
    [6673] = Cast("shout", { scale = Faint(0.6) }), [403215] = Cast("shout", { scale = Faint(0.6) }),
    [461475] = Cast("shout", { scale = Faint(0.6) }),                         -- Battle, Commanding Shout, Valor of Azeroth
    -- Cooldowns
    [2687] = Cast("enrage"), [18499] = Cast("enrage"), [12328] = Cast("enrage"), [1719] = Cast("enrage"),
    [426940] = Cast("enrage"),                                                -- Bloodrage, Berserker Rage, Death Wish, Recklessness, Rampage
    [12975] = Cast("secondWind"), [402913] = Cast("secondWind"),              -- Last Stand, Enraged Regeneration
    [871] = Cast("brace"), [2565] = Cast("brace", { scale = Faint(0.7) }),    -- Shield Wall, Shield Block (often)
    [20230] = Cast("ward"), [12292] = Cast("whirl"),                          -- Retaliation, Sweeping Strikes
    [12723] = Quiet("Set off by another: quiet"),                             -- (Sweeping Strikes' extra blow)
    [12705] = Quiet("Set off by another: quiet"),                             -- Long Daze (Charge's)
    -- Slam: its own wind-up
    [1464] = SLAM, [1240193] = SLAM,
}
V.CLASS_SPELLS.WARRIOR = SPELLS
WR.SPELLS = SPELLS

---------------------------------------------------------------------------
-- Charge, Intercept: the crash as you reach the target (its stun on it, from
-- you), once per charge, within WR.CHARGE_MAX of setting off
---------------------------------------------------------------------------
WR.CHARGE_MAX = 1.5
WR.STUNS = { 7922, 20253, 20614, 20615 }      -- Charge Stun, Intercept Stun (every rank)
local CHARGES = { 100, 20252 }
local charging = { at = -math.huge, name = nil }
WR.charging = charging
-- (names by ID, kept once all are loaded)
local named = {}
local function NamesOf(ids)
    if named[ids] then return named[ids] end
    local t, full = {}, true
    for _, id in ipairs(ids) do
        local n = SpellName(id)
        if n and not secret(n) then t[n] = true else full = false end
    end
    if full then named[ids] = t end
    return t
end
local function IsStun(id, name)
    if id and not secret(id) then
        for _, sid in ipairs(WR.STUNS) do if sid == id then return true end end
    end
    return name ~= nil and not secret(name) and NamesOf(WR.STUNS)[name] == true
end

function WR.SetOff(name) charging.at, charging.name = Now(), name end
function WR.Arrived()
    if Now() - charging.at > WR.CHARGE_MAX then return false end
    charging.at = -math.huge
    V.instantMove = "crash"
    V.FireAs(charging.name, "instant")
    return true
end

local function Warrior()
    if not UnitClass then return false end
    local _, class = UnitClass("player")
    return not secret(class) and class == "WARRIOR"
end

local handlers = {}
WR.handlers = handlers
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    if unit ~= "player" or not spellID or secret(spellID) or not Warrior() then return end
    local name = SpellName(spellID)
    if name and not secret(name) and NamesOf(CHARGES)[name] then WR.SetOff(name) end
end
-- (the stun, from you, newly on the target)
handlers.UNIT_AURA = function(unit, info)
    if unit ~= "target" or Now() - charging.at > WR.CHARGE_MAX then return end
    if type(info) == "table" and not info.isFullUpdate and type(info.addedAuras) == "table" then
        for _, a in ipairs(info.addedAuras) do
            local from = a.sourceUnit
            local mine = from == nil or secret(from) or from == "player"
            if mine and IsStun(a.spellId, a.name) then WR.Arrived(); return end
        end
        return
    end
    -- (no list of what was added: the stun there now, yours)
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return end
    for i = 1, 40 do
        local ok, a = pcall(get, "target", i, "HARMFUL|PLAYER")
        if not ok or type(a) ~= "table" then break end
        if IsStun(a.spellId, a.name) then WR.Arrived(); return end
    end
end
local frame = CreateFrame("Frame")
WR.frame = frame
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "target")
frame:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
