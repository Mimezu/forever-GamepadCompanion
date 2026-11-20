-- A hunter's feels (and a Skyborne's racials): what each hunter spell plays
-- (Rumble's V.SpellRule asks Rule and TailOf here), the pet's own moments,
-- traps set, armed and sprung, and the pet's blows told from yours.
--
-- WoW Forever gives addons no combat log, so everything here comes from the
-- events the client still gives: UNIT_PET, UNIT_HEALTH / UNIT_COMBAT for
-- "pet", the pet's happiness, UNIT_AURA (a trap's effect landing on an enemy,
-- Feed Pet Effect on the pet, Dazed on you), the pet bar's commands.
-- tests/Hunter.lua lists every hunter spell of the client and what it plays.
local _, ns = ...
local HN = {}
ns.Hunter = HN

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
-- (a game call that may be missing or hide its answer: nil then)
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok or secret(a) then return nil end
    return a, b, c
end

---------------------------------------------------------------------------
-- What each spell plays. By the first rank's ID (every rank shares its name).
-- move: Rumble's pattern; when: "cast" or "hit"; ranged: its blow comes
-- from afar (a shot's travel); magic: only a magic wound is its; move nil: quiet (why says
-- what plays instead).
-- Shots (Rumble's SHOT_IDS) play Shooting, timed to the impact; TAILS add
-- theirs after it. Casts and channels play their set (Rumble's CAST_ACTIONS:
-- shots, volley, petCare, tame, farsight, summon).
---------------------------------------------------------------------------
HN.RULES = {
    -- Aspects, auras, a hunter's own buffs: a soft change of stance
    { "aspect", "cast", "A change of stance", { 13161, 5118, 469145, 13165, 13163, 13159, 415423, 20043, 1299346,
        409580, 3045, 23989 } }, -- the Beast, Cheetah, Falcon, Hawk, Monkey, Pack, Viper, Wild; Trueshot Aura,
                                 -- Heart of the Lion, Rapid Fire, Readiness
    { "feign", "cast", "A body dropping", { 5384 } },                       -- Feign Death
    { "leap", "cast", "A leap back", { 781 } },                             -- Disengage
    { "ward", "cast", "A guard raised", { 19263 } },                        -- Deterrence
    { "trap", "cast", "Laid down; armed, sprung: Abilities", { 1499, 13809, 13795, 13813 } }, -- the traps
    { "toss", "cast", "A flare thrown", { 1543, 1221404 } },                -- Flare, Enchanted Flare
    { "micro", "cast", "A faint tick", { 1130, 1462, 1494, 19878, 19879, 19880, 19882, 19885, 19883, 19884 } },
                                 -- Hunter's Mark, Beast Lore, the eight Trackings
    -- (your pet's fury: the pet's, faint)
    { "roar", "cast", "Your pet's: faint", { 19574, 19577, 409379 } },     -- Bestial Wrath, Intimidation, Kill Command
    -- Blows from afar, at the hit
    -- (a magic shot: only a magic wound is its, never the pet's blow just after it)
    { "judge", "hit", "Arcane: at the hit", { 3044 }, true, true },         -- Arcane Shot (every rank: from afar)
    { "shock", "hit", "Nature: at the hit", { 409433 }, true, true },       -- Chimera Shot
    { "rend", "hit", "Talons: at the hit", { 1293241 }, true },             -- Summon Hawk (Forever)
    -- Melee (Raptor Strike, Mongoose Bite, Wing Clip: Rumble's own moves)
    { "cleave", "hit", "Known: Cleave", { 425711 } },                       -- Carve
    { "stab", "hit", "Known: Stab", { 19306 } },                            -- Counterattack
    { "slash", "hit", "Known: Slash", { 415320 } },                         -- Flanking Strike
    { "bash", "hit", "Known: Bash", { 1317257 } },                          -- Strider Kick (Forever)
    -- Skyborne (Forever's race): Walk on Air, a gust lifting you
    { "updraft", "cast", "Air under you", { 1259416, 1308663 } },
    -- Quiet by design: what plays is elsewhere, or nothing should
    { nil, "none", "Pet arrives: Pet", { 883 } },                           -- Call Pet
    { nil, "none", "Pet eats: Pet", { 6991 } },                             -- Feed Pet
    { nil, "none", "A bleed: quiet", { 24118 } },                           -- Lacerate (a routine DoT)
    { nil, "none", "Set off by another: quiet", { 409495, 409493, 409494, 19185, 24406, 24529, 13535, 13481 } },
                                 -- Chimera Shot's three, Entrapment, Improved Mend Pet, Spirit Bond, Tame Beast's own
}
-- A shot's tail, after Shooting: by the first rank's ID
HN.TAILS = {
    multi = { 2643 },                                   -- Multi-Shot: two more arrows fanning out
    sting = { 1978, 3043, 3034, 19386, 3674 },          -- Serpent, Scorpid, Viper, Wyvern Sting; Black Arrow
    daze = { 5116, 19503 },                             -- Concussive Shot, Scatter Shot
}
-- (how long after the shot's own feel each tail comes)
HN.TAIL_AFTER = { multi = 0.1, sting = 0.22, daze = 0.08 }
-- Casts whose end is quiet here: the pet's own moment says the rest (Revive Pet: Pet arrives)
HN.QUIET_SETS = { petCare = true, tame = true, farsight = true }
HN.QUIET_CASTS = { 982 }                                -- Revive Pet
HN.AIMED = { 19434, 1310687 }                           -- Aimed Shot, Sniper Shot: their release a shot
-- Channels the client calls instant (cast time 0): Mend Pet, Tame Beast, Eagle Eye, Eyes of the
-- Beast, Volley
HN.CHANNELS = { 136, 1515, 6197, 1002, 1510 }

local byName, tailByName, quietByName, aimedByName, channelByName
local function Build()
    if byName then return end
    byName, tailByName, quietByName, aimedByName, channelByName = {}, {}, {}, {}, {}
    for _, id in ipairs(HN.CHANNELS) do
        local name = SpellName(id)
        if name and not secret(name) then channelByName[name] = true end
    end
    for _, id in ipairs(HN.AIMED) do
        local name = SpellName(id)
        if name and not secret(name) then aimedByName[name] = true end
    end
    local missing = false
    for _, r in ipairs(HN.RULES) do
        for _, id in ipairs(r[4]) do
            local name = SpellName(id)
            if name and not secret(name) then
                byName[name] = { move = r[1], when = r[2], why = r[3], ranged = r[5] or nil, magic = r[6] or nil }
            else
                missing = true
            end
        end
    end
    for tail, ids in pairs(HN.TAILS) do
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            if name and not secret(name) then tailByName[name] = tail end
        end
    end
    for _, id in ipairs(HN.QUIET_CASTS) do
        local name = SpellName(id)
        if name and not secret(name) then quietByName[name] = true end
    end
    -- (a name not loaded yet at login: built again later)
    if missing then HN.rebuildAt = Now() + 10 end
end
local function Fresh()
    if byName and HN.rebuildAt and Now() >= HN.rebuildAt then byName, HN.rebuildAt = nil, nil end
    Build()
end
function HN.Forget() byName = nil end

-- A spell's own rule (nil: not a hunter's or a Skyborne's): { move, when, why, ranged, magic }
function HN.Rule(name)
    if type(name) ~= "string" or secret(name) then return nil end
    Fresh()
    return byName[name]
end

-- A channel the client calls instant (Your spells asks with no cast going)
function HN.IsChannel(name)
    if type(name) ~= "string" or secret(name) then return false end
    Fresh()
    return channelByName[name] == true
end

-- A shot's tail pattern (nil: none)
function HN.TailOf(name)
    if type(name) ~= "string" or secret(name) then return nil end
    Fresh()
    return tailByName[name]
end

-- At a shot's impact (Rumble's V.ShotLoosed): its tail, a moment after Shooting's feel
function HN.ShotTail(spellID)
    if not spellID or secret(spellID) then return end
    local name = SpellName(spellID)
    local tail = HN.TailOf(name)
    local V = ns.Rumble
    if not (tail and V and V.FireAs) then return end
    local function play()
        V.instantMove = tail
        V.FireAs(name, "instant")
    end
    local after = HN.TAIL_AFTER[tail] or 0.1
    if C_Timer and C_Timer.After then C_Timer.After(after, play) else play() end
end

-- A cast of a hunter's set done (Rumble's CastReleased): true when it is handled here.
-- Aimed Shot and Sniper Shot loose their arrow (Shooting at its impact); a pet's cast, a
-- taming, a far look end quiet.
function HN.CastReleased(action, spellID)
    local V = ns.Rumble
    -- (a listed aimed shot only: "shots" is also any physical cast's school set)
    if action == "shots" and V and V.ShotLoosed and spellID and not secret(spellID) then
        Fresh()
        local name = SpellName(spellID)
        if name and aimedByName[name] then
            V.ShotLoosed(spellID)
            return true
        end
    end
    if HN.QUIET_SETS[action] then return true end
    if spellID and not secret(spellID) then
        Fresh()
        local name = SpellName(spellID)
        if name and quietByName[name] then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The pet's moments (the Lab's, group Pet), fired through the Lab
---------------------------------------------------------------------------
local function Fire(key, gain)
    local L = ns.HapticsLab
    if L and L.Fire and L.EVENT and L.EVENT[key] then L.Fire(key, gain) end
end
HN.Fire = Fire

local pet = { guid = nil, dead = false, happiness = nil, quietUntil = 0 }
local feeding = { on = false, token = 0, at = 0 }
HN.pet = pet
local tameEnded, tameOn = -math.huge, false
local fedAt = -math.huge

HN.TAXI_QUIET = 5
local function PetState()
    local exists = call(UnitExists, "pet")
    if not exists then return nil, false end
    local guid = call(UnitGUID, "pet")
    local dead = call(UnitIsDead, "pet")
    return guid or "pet", dead and true or false
end

-- The pet came, went, died or got up (UNIT_PET, UNIT_HEALTH, UNIT_FLAGS)
function HN.PetChanged()
    local guid, dead = PetState()
    local now = Now()
    -- (a flight path sends the pet away and back: quiet on it and a few seconds after)
    if call(UnitOnTaxi, "player") then pet.quietUntil = math.max(pet.quietUntil, now + HN.TAXI_QUIET) end
    local quiet = now < pet.quietUntil
    if guid and not pet.guid then
        -- (a new pet: tamed just now, or called; a loading screen's: none)
        if not quiet and not dead then
            if tameOn or now - tameEnded < 3 then Fire("petTamed") else Fire("petArrive") end
        end
    elseif not guid and pet.guid then
        if not pet.dead and not quiet then Fire("petDismiss") end
    elseif guid and pet.guid then
        if dead and not pet.dead then
            if not quiet then Fire("petDeath") end
        elseif not dead and pet.dead then
            -- (Revive Pet: back on its feet)
            if not quiet then Fire("petArrive") end
        elseif guid ~= pet.guid and not quiet and not dead then
            Fire((tameOn or now - tameEnded < 3) and "petTamed" or "petArrive")
        end
    end
    pet.guid, pet.dead = guid, dead
    if not guid then pet.happiness = nil end
    -- (gone or dead: no more munching)
    if (not guid or dead) and feeding.on then feeding.on, feeding.token = false, feeding.token + 1 end
end

-- A heavy blow on the pet (UNIT_COMBAT "pet"): a crit, or a fifth of its health or more
local hurtAt = -math.huge
function HN.PetCombat(action, flag, amount)
    if secret(action) or action ~= "WOUND" then return end
    local heavy = not secret(flag) and flag == "CRITICAL"
    if not heavy and type(amount) == "number" and not secret(amount) then
        local mx = call(UnitHealthMax, "pet")
        heavy = mx ~= nil and mx > 0 and amount >= mx * 0.2
    end
    if not heavy or Now() - hurtAt < 1.5 then return end
    hurtAt = Now()
    Fire("petHurt")
end

-- Happiness (1 unhappy, 2 content, 3 happy): happier or less
function HN.HappinessChanged()
    local h = call(GetPetHappiness)
    if type(h) ~= "number" then return end
    local was = pet.happiness
    pet.happiness = h
    if not was or h == was or Now() < pet.quietUntil then return end
    if h > was then
        -- (just fed: its own happy beat already played)
        if Now() - fedAt > 5 then Fire("petHappy") end
    else
        Fire("petUnhappy")
    end
end

---------------------------------------------------------------------------
-- Auras: Feed Pet Effect on the pet (munching while it lasts, a happy beat
-- at its end), Dazed on you in Cheetah or Pack, a trap's effect on an enemy
---------------------------------------------------------------------------
local FEED_EFFECT, DAZED = 1539, 1604
local CHEETAH = { 5118, 13159 }   -- Aspect of the Cheetah, of the Pack

-- An aura on a unit by name (helpful or harmful): its spell ID check first
local function HasAura(unit, ids, filter)
    local names = {}
    for _, id in ipairs(ids) do
        local n = SpellName(id)
        if n and not secret(n) then names[n] = true end
    end
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    for i = 1, 40 do
        local name, spellId
        if get then
            local ok, a = pcall(get, unit, i, filter)
            if not ok or type(a) ~= "table" then break end
            name, spellId = a.name, a.spellId
        elseif UnitAura then
            local ok, n, _, _, _, _, _, _, _, _, sid = pcall(UnitAura, unit, i, filter)
            if not ok or n == nil then break end
            name, spellId = n, sid
        else
            break
        end
        if not secret(spellId) and spellId then
            for _, id in ipairs(ids) do if spellId == id then return true end end
        end
        if not secret(name) and name and names[name] then return true end
    end
    return false
end
HN.HasAura = HasAura

HN.FEED_EVERY, HN.FEED_MAX = 1.6, 25   -- (Feed Pet Effect lasts 20 s: never longer than this)
local function Munch(token)
    if not feeding.on or feeding.token ~= token then return end
    -- (the pet gone, dead, or the meal too long: over, quietly)
    local guid, dead = PetState()
    if not guid or dead or Now() - feeding.at > HN.FEED_MAX then
        feeding.on, feeding.token = false, feeding.token + 1
        return
    end
    Fire("petFeed")
    if C_Timer and C_Timer.After then C_Timer.After(HN.FEED_EVERY, function() Munch(token) end) end
end
function HN.PetAuras()
    local now = HasAura("pet", { FEED_EFFECT }, "HELPFUL")
    if now and not feeding.on then
        feeding.on, feeding.token, feeding.at = true, feeding.token + 1, Now()
        Munch(feeding.token)
    elseif not now and feeding.on then
        feeding.on = false
        fedAt = Now()
        -- (the bowl empty: a happy beat)
        Fire("petHappy")
    end
end

local dazedNow = false
function HN.PlayerAuras()
    local dazed = HasAura("player", { DAZED }, "HARMFUL")
    -- (your own Cheetah or Pack only: a party hunter's Pack on you is theirs)
    if dazed and not dazedNow and HasAura("player", CHEETAH, "HELPFUL|PLAYER") then Fire("dazed") end
    dazedNow = dazed
end

-- Traps: laid (the spell's own feel, Rumble), armed a moment later, sprung
-- when its effect lands on an enemy (the effect is named as the trap is).
-- One sprung per trap laid.
HN.TRAPS = { 1499, 13809, 13795, 13813 }   -- Freezing, Frost, Immolation, Explosive Trap
-- Each trap's effects on an enemy, every rank. Forever's own SpellName names them as the trap
-- (3355 "Freezing Trap", 13810 "Frost Trap"): matched by id first, then by name
HN.TRAP_EFFECTS = { [1499] = { 3355, 14308, 14309 }, [13809] = { 13810 },
    [13795] = { 13797, 14298, 14299, 14300, 14301 }, [13813] = { 13812, 14314, 14315 } }
HN.ARM_AFTER, HN.TRAP_LIFE = 2, 60
local traps = {}                            -- name -> { at, token }
HN.traps = traps
local trapNames
local function TrapNames()
    if trapNames then return trapNames end
    local t, full = {}, true
    for _, id in ipairs(HN.TRAPS) do
        local n = SpellName(id)
        if n and not secret(n) then t[n] = true else full = false end
    end
    if full then trapNames = t end
    return t
end
local function TrapOut()
    local now = Now()
    for name, t in pairs(traps) do
        if now - t.at > HN.TRAP_LIFE then traps[name] = nil end
    end
    return next(traps) ~= nil
end

function HN.TrapLaid(name)
    local t = { at = Now() }
    traps[name] = t
    local function arm() if traps[name] == t then Fire("trapArmed") end end
    if C_Timer and C_Timer.After then C_Timer.After(HN.ARM_AFTER, arm) end
end

local function Sprung(name)
    if not traps[name] then return false end
    traps[name] = nil
    Fire("trapSprung")
    return true
end

-- The trap (its name, as laid) an effect id comes from
local function TrapOfEffect(id)
    for tid, effects in pairs(HN.TRAP_EFFECTS) do
        for _, e in ipairs(effects) do if e == id then return SpellName(tid) end end
    end
    return nil
end

-- A unit's auras changed: a trap's effect newly on it, from you
local function FromYou(src)
    return src == nil or secret(src) or src == "player" or src == "pet"
end
function HN.EnemyAuras(unit, info)
    if not TrapOut() then return end
    local names = TrapNames()
    if type(info) == "table" and not info.isFullUpdate and type(info.addedAuras) == "table" then
        for _, a in ipairs(info.addedAuras) do
            local trap = not secret(a.spellId) and a.spellId and TrapOfEffect(a.spellId) or nil
            if not trap and not secret(a.name) and names[a.name] then trap = a.name end
            if trap and FromYou(a.sourceUnit) and Sprung(trap) then return end
        end
        return
    end
    -- (no list of what was added: a trap's effect there now, from you)
    for name in pairs(traps) do
        for tid, effects in pairs(HN.TRAP_EFFECTS) do
            if SpellName(tid) == name and HasAura(unit, effects, "HARMFUL|PLAYER") and Sprung(name) then return end
        end
    end
end

---------------------------------------------------------------------------
-- The pet's blows: a result on your target nothing of yours claimed (no
-- swing, ability or shot of yours just then) while your pet fights it is
-- your pet's. Its crit plays Pet crit, faint; nothing of it plays as yours
-- (your Crit, Miss, Target dodges). Asked by Rumble and the Lab for the same
-- event: one answer per event.
---------------------------------------------------------------------------
local PHYSICAL = 1
-- (a shot's result comes about when WoW Helper heard it land (Rumble's ImpactDelay), give or
-- take SHOT_MARGIN; not learned yet (no delay), anywhere up to SHOT_WINDOW after it left)
HN.SHOT_WINDOW, HN.SHOT_MARGIN = 1.2, 0.3
local takenShot = -math.huge
-- (Rumble asks first, then the Lab for the same event: the Lab takes Rumble's answer, once)
local memo = { at = nil }
local function PetFighting()
    local guid, dead = PetState()
    if not guid or dead then return false end
    local same = call(UnitIsUnit, "pettarget", "target")
    if same ~= nil then return same and true or false end
    return call(UnitAffectingCombat, "pet") and true or false
end
-- A shot of yours whose result this may be: it fits the shot's landing, and no result took it
local function ShotFits(now)
    local V = ns.Rumble
    local shot = V and V.LastShot and V.LastShot() or -math.huge
    if shot <= takenShot then return false end
    local d = V.ImpactDelay and V.ImpactDelay("ranged", "ranged") or 0
    if d > 0.05 then return math.abs(now - (shot + d)) <= HN.SHOT_MARGIN end
    return now >= shot and now - shot <= HN.SHOT_WINDOW
end
HN.ShotFits = ShotFits
-- second: the Lab asking after Rumble for the same event (two alike in one frame: each its own)
function HN.ClaimsResult(action, flag, school, second)
    if secret(action) then return false end
    local now = Now()
    local key = tostring(action) .. "|" .. tostring(not secret(flag) and flag) .. "|" .. tostring(not secret(school) and school)
    if second and memo.at == now and memo.key == key and not memo.used then
        memo.used = true
        return memo.result
    end
    local result = false
    if secret(school) then school = nil end
    local physical = school == nil or school == PHYSICAL
    if physical and (action == "WOUND" or action == "MISS" or action == "DODGE" or action == "PARRY" or action == "BLOCK")
        and PetFighting() then
        if ShotFits(now) then
            -- (where your shot lands: yours, its crit your crit)
            takenShot = ns.Rumble.LastShot()
        else
            result = true
            if action == "WOUND" and not secret(flag) and flag == "CRITICAL" then Fire("petCrit") end
        end
    end
    memo.at, memo.key, memo.result, memo.used = now, key, result, second and true or false
    return result
end

---------------------------------------------------------------------------
-- Commands (the pet bar, its keys, /petattack...): attack, follow, stay
---------------------------------------------------------------------------
local COMMAND = { PET_ACTION_ATTACK = "petAttack", PET_ACTION_FOLLOW = "petCommand", PET_ACTION_WAIT = "petCommand" }
function HN.Command(token)
    local key = COMMAND[token]
    if key then Fire(key) end
end
if hooksecurefunc then
    if PetAttack then hooksecurefunc("PetAttack", function() HN.Command("PET_ACTION_ATTACK") end) end
    if PetFollow then hooksecurefunc("PetFollow", function() HN.Command("PET_ACTION_FOLLOW") end) end
    if PetWait then hooksecurefunc("PetWait", function() HN.Command("PET_ACTION_WAIT") end) end
    if CastPetAction then
        hooksecurefunc("CastPetAction", function(index)
            local token, _, isToken = call(GetPetActionInfo, index)
            if type(token) == "string" and isToken ~= false then HN.Command(token) end
        end)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
HN.frame = frame
local function Listen(event, ...)
    if select("#", ...) > 0 then
        if pcall(frame.RegisterUnitEvent, frame, event, ...) then return end
    end
    pcall(frame.RegisterEvent, frame, event)
end
Listen("UNIT_PET", "player")
Listen("UNIT_HEALTH", "pet")
Listen("UNIT_FLAGS", "pet")
Listen("UNIT_COMBAT", "pet")
Listen("UNIT_HAPPINESS", "pet")
Listen("UNIT_POWER_UPDATE", "pet")
Listen("UNIT_SPELLCAST_SUCCEEDED", "player")
Listen("UNIT_SPELLCAST_CHANNEL_START", "player")
Listen("UNIT_SPELLCAST_CHANNEL_STOP", "player")
Listen("UNIT_AURA")
Listen("PLAYER_ENTERING_WORLD")

local TAME = 1515
local handlers = {}
handlers.PLAYER_ENTERING_WORLD = function()
    -- (the pet comes with the world: no arrival felt)
    pet.quietUntil = Now() + 5
    HN.PetChanged()
    HN.HappinessChanged()
end
handlers.UNIT_PET = function(unit) if unit == "player" then HN.PetChanged() end end
handlers.UNIT_HEALTH = function(unit) if unit == "pet" then HN.PetChanged() end end
handlers.UNIT_FLAGS = handlers.UNIT_HEALTH
handlers.UNIT_COMBAT = function(unit, action, flag, amount)
    if unit == "pet" then HN.PetCombat(action, flag, amount) end
end
handlers.UNIT_HAPPINESS = function() HN.HappinessChanged() end
handlers.UNIT_POWER_UPDATE = function(unit, kind)
    if unit == "pet" and kind == "HAPPINESS" then HN.HappinessChanged() end
end
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    if unit ~= "player" or secret(spellID) or not spellID then return end
    local name = SpellName(spellID)
    if name and not secret(name) and TrapNames()[name] then HN.TrapLaid(name) end
end
handlers.UNIT_SPELLCAST_CHANNEL_START = function(unit, _, spellID)
    if unit == "player" and not secret(spellID) and spellID and SpellName(spellID) == SpellName(TAME) then tameOn = true end
end
handlers.UNIT_SPELLCAST_CHANNEL_STOP = function(unit)
    if unit == "player" and tameOn then tameOn, tameEnded = false, Now() end
end
handlers.UNIT_AURA = function(unit, info)
    if unit == "pet" then return HN.PetAuras() end
    if unit == "player" then return HN.PlayerAuras() end
    if unit == "target" or (type(unit) == "string" and unit:sub(1, 9) == "nameplate") then return HN.EnemyAuras(unit, info) end
end
HN.handlers = handlers
frame:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
