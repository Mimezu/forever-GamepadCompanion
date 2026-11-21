-- A warrior's feels (the warrior pass, 2026-11-20; docs/WARRIOR-ROGUE.md): what each warrior
-- spell plays, its own patterns, Slam's wind-up and its blow, Charge's run and its crash.
-- Loaded before Rumble.lua (ClassFeels.lua registers it there). tests/Warrior.lua lists every
-- warrior spell of the client and what it plays.
--
-- Materials: steel on steel and on bodies, a shield's wood and iron boss, boots on the ground,
-- the chest of a shout. Blows land at the weapon's impact (Rumble's AbilityResult), never at the
-- press; area blows are several bodies, one after another, never one blob.
local _, ns = ...
local CF = ns.ClassFeels
local WR = { class = "WARRIOR", ENGRAVE = true }
ns.Warrior = WR

local function Pu(t, len, s, side) return { t, len, s, side or 0 } end

-- Patterns (Rumble adds them, the Lab's library as "r_" + key, WoW Helper crafts their HD):
-- steps for the plain engine (each 0.1 s or more), pulses for the Beta engine.
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

-- Slam: its own cast set (its release waits for the blow, WR.Released)
WR.SLAM = { 1464, 8820, 11604, 11605, 1240193 }
WR.CAST_ACTIONS = {
    { key = "slam", label = "Slam", kind = "spell", pattern = "windup", spells = WR.SLAM },
}

-- What each warrior spell plays (ClassFeels.lua's rows). Any rank's ID: every rank shares a name.
WR.RULES = {
    -- Stances (Gladiator Stance: Forever's rune)
    { "stanceBattle", "cast", "Weight forward", { 2457, 412513 } },
    { "stanceDefensive", "cast", "Shield up", { 71 } },
    { "stanceBerserker", "cast", "Blood up", { 2458 } },
    -- The run; the crash as you reach it (the stun on the target, WR.Arrived)
    { "rush", "cast", "The run, then the crash", { 100, 20252 } },                       -- Charge, Intercept
    -- At the weapon's impact
    { "mortal", "hit", "A deep gash", { 12294, 23881 } },                                -- Mortal Strike, Bloodthirst
    { "overpower", "hit", "Two quick cuts", { 7384, 402911 } },                          -- Overpower, Raging Blow
    { "execute", "hit", "The finishing chop", { 20647 } },
    { "whirlwind", "hit", "Round you, body by body", { 1680 } },
    { "cleaveArc", "hit", "Two bodies, one swing", { 845 } },                            -- (on the next swing)
    -- Heroic Strike (next swing), Mocking Blow, Revenge, Quick Strike, Victory Rush, Devastate
    { "slash", "hit", "Known: Slash", { 78, 694, 6572, 429765, 402927, 403196 } },
    { "stab", "hit", "A spear's thrust", { 1310222 } },                                  -- Spearing Strike (Forever)
    { "rend", "hit", "Known: Rend", { 1715 } },                                          -- Hamstring
    { "shieldBash", "hit", "Wood and iron", { 72, 23922 } },                             -- Shield Bash, Shield Slam
    { "bash", "hit", "A fist", { 6552 } },                                               -- Pummel
    -- Around you, at the cast (no flight, nothing to wait for)
    { "slam", "cast", "The ground struck", { 6343, 440488 } },                           -- Thunder Clap, Shockwave
    -- No blow of their own: at the cast (a dodge or a parry of it still shows)
    { "bash", "cast", "A stun", { 12809 }, { avoid = true } },                           -- Concussion Blow
    { "disarm", "cast", "Wrenched away", { 676 }, { avoid = true } },
    { "hook", "cast", "Thrown, caught, yanked", { 403228 }, { avoid = true } },          -- Meathook (Forever)
    -- Shouts: the big ones full, the buffs (cast often) fainter
    { "shout", "cast", "A shout", { 1161, 5246, 1160, 12323, 426490 } },                -- Challenging, Intimidating, Demoralizing, Piercing Howl, Rallying Cry
    { "shout", "cast", "A shout, faint", { 6673, 403215, 461475 }, { volume = 0.6 } },  -- Battle, Commanding Shout, Valor of Azeroth
    -- Cooldowns
    { "enrage", "cast", "Blood pounding", { 2687, 18499, 12328, 1719, 426940 } },       -- Bloodrage, Berserker Rage, Death Wish, Recklessness, Rampage
    { "secondWind", "cast", "A deep breath", { 12975, 402913 } },                        -- Last Stand, Enraged Regeneration
    { "brace", "cast", "Shield set", { 871 } },                                          -- Shield Wall
    { "brace", "cast", "Shield set, faint", { 2565 }, { volume = 0.7 } },                -- Shield Block (often)
    { "ward", "cast", "Blades ready", { 20230 } },                                       -- Retaliation
    { "whirl", "cast", "Known: Whirl", { 12292 } },                                      -- Sweeping Strikes
    -- Quiet by design
    { nil, "none", "A debuff: nothing", { 772, 7386 } },                                 -- Rend, Sunder Armor
    { nil, "none", "A single taunt: nothing", { 355 } },
    -- (set off by another: Charge's rage, procs and talents)
    { nil, "none", "Set off by another: quiet", { 12695, 12705, 12966, 12281, 12964, 1329555 } },
}
-- Set off by another, though named as a spell you cast: by its ID (Sweeping Strikes' extra blow)
WR.QUIET_IDS = { [12723] = true }

function WR.Rule(spellID, _, r)
    if spellID and not CF.secret(spellID) and WR.QUIET_IDS[spellID] then
        r.move, r.when, r.why = nil, "none", "Set off by another: quiet"
    end
end

---------------------------------------------------------------------------
-- Slam: its release opens the blow's window, felt at the weapon's impact
---------------------------------------------------------------------------
function WR.Released(action, spellID)
    if action ~= "slam" then return false end
    local V = ns.Rumble
    if V and V.AbilityCast then
        V.AbilityCast("slamHit", spellID, nil, { melee = true },
            { volume = 1, name = spellID and not CF.secret(spellID) and CF.SpellName(spellID) or nil })
    end
    return true
end

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
        local n = CF.SpellName(id)
        if n and not CF.secret(n) then t[n] = true else full = false end
    end
    if full then named[ids] = t end
    return t
end
local function IsStun(id, name)
    if id and not CF.secret(id) then
        for _, sid in ipairs(WR.STUNS) do if sid == id then return true end end
    end
    return name ~= nil and not CF.secret(name) and NamesOf(WR.STUNS)[name] == true
end

-- (Intercept wounds as it stuns: its wound may say it too)
function WR.SetOff(name)
    charging.at, charging.name = CF.Now(), name
    charging.wounds = name == CF.SpellName(CHARGES[2])
end
function WR.Arrived()
    if CF.Now() - charging.at > WR.CHARGE_MAX then return false end
    local name = charging.name
    charging.at = -math.huge
    CF.Play(name, "crash")
    return true
end

local handlers = {}
WR.handlers = handlers
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    if unit ~= "player" or not spellID or CF.secret(spellID) or CF.Class() ~= "WARRIOR" then return end
    local name = CF.SpellName(spellID)
    if name and not CF.secret(name) and NamesOf(CHARGES)[name] then WR.SetOff(name) end
end
-- (the stun, from you, newly on the target)
handlers.UNIT_AURA = function(unit, info)
    if unit ~= "target" or CF.Now() - charging.at > WR.CHARGE_MAX then return end
    if type(info) == "table" and not info.isFullUpdate and type(info.addedAuras) == "table" then
        for _, a in ipairs(info.addedAuras) do
            local from = a.sourceUnit
            local mine = from == nil or CF.secret(from) or from == "player"
            if mine and IsStun(a.spellId, a.name) then WR.Arrived(); return end
        end
        return
    end
    -- (no list of what was added: the stun there now)
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return end
    for i = 1, 40 do
        local ok, a = pcall(get, "target", i, "HARMFUL|PLAYER")
        if not ok or type(a) ~= "table" then break end
        if IsStun(a.spellId, a.name) then WR.Arrived(); return end
    end
end
-- (Intercept's own wound, should its stun not show: the crash all the same)
handlers.UNIT_COMBAT = function(unit, action)
    if unit == "target" and charging.wounds and not CF.secret(action) and action == "WOUND" then WR.Arrived() end
end
local Listen
WR.frame, Listen = CF.Frame(handlers)
Listen("UNIT_SPELLCAST_SUCCEEDED", "player")
Listen("UNIT_AURA")
Listen("UNIT_COMBAT", "target")

CF.Register(WR)
