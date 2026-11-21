-- A paladin's feels: what the paladin spells the moves leave out play (Rumble's V.SpellRule asks
-- Of here, in the shape of V.MAGE's entries), and Consecration's ground felt each second you
-- stand in it. The moves already set (seals, blessings, Judgement, Consecration's laying down,
-- Hammer of Justice, Divine Shield, Lay on Hands, Purify, Cleanse) stay Rumble's.
-- tests/PaladinCoverage.lua lists every paladin spell of the client and what it plays.
local _, ns = ...
local PD = {}
ns.Paladin = PD

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

---------------------------------------------------------------------------
-- What each spell plays, by its first rank's ID (every rank shares its name).
-- move, when: an instant's feel, at the "cast" or as it lands ("hit"); set: a
-- cast's loop; burst: a cast's feel at its release; magic: only a magic wound is its (holy, from
-- afar: never your swing landing first).
---------------------------------------------------------------------------
local AT_CAST = {
    -- Auras: a warm ring round you (Devotion, Retribution, Concentration, the resistances, Sanctity;
    -- Divine Sacrifice, Horn of Lordaeron, Voice of Truth spread round you too)
    aura = { 465, 7294, 19746, 19876, 19888, 19891, 20218, 407804, 425600, 1310897 },
    -- Blessings and seals the moves don't list: the Greater ones, Sacrifice (Blessing, Hand),
    -- Seal of Fury, Oath of Light
    seal = { 25782, 25894, 25898, 6940, 462853, 20163, 1328548 },
    -- Power rushing in: Righteous Fury, Aura Mastery, Inspiration Exemplar
    empower = { 25780, 416863, 407880 },
    wings = { 407788 },                                     -- Avenging Wrath
    glow = { 20216, 409906 },                               -- Divine Favor, Beacon of Light
    -- A guard raised: Divine Intervention, Sacred Shield, Templar's Bulwark
    ward = { 19752, 412019, 1311015 },
    -- A faint tick: Sense Undead (tracking), Hand of Reckoning (a taunt)
    micro = { 5502, 407774 },
}
local AT_HIT = {
    avenger = { 470264 },                                   -- Avenger's Shield
    exorcism = { 879, 415068 },                             -- Exorcism (the book's, the rune's)
}
PD.SPELLS = {
    [7328] = { burst = "raise" },                           -- Redemption (its loop: Holy's)
    [2878] = { set = "holy", burst = "turn" },              -- Turn Undead (nature by its school)
    [13819] = { set = "feel:steed", burst = "hooves" },     -- Summon Warhorse
    [23214] = { set = "feel:steed", burst = "hooves" },     -- Summon Charger
}
for move, ids in pairs(AT_CAST) do
    for _, id in ipairs(ids) do PD.SPELLS[id] = { move = move, when = "cast" } end
end
for move, ids in pairs(AT_HIT) do
    for _, id in ipairs(ids) do PD.SPELLS[id] = { move = move, when = "hit", magic = true } end
end

function PD.IsPaladin()
    if not UnitClass then return false end
    local _, class = UnitClass("player")
    return class == "PALADIN"
end

-- A paladin spell's entry, by its ID, else (a paladin only) by its name; nil: none
local byName
function PD.Of(spellID, name)
    if not spellID or secret(spellID) then return nil end
    local e = PD.SPELLS[spellID]
    if e then return e end
    if not PD.IsPaladin() then return nil end
    if not byName then
        byName = {}
        for id, entry in pairs(PD.SPELLS) do
            local n = SpellName(id)
            if n and not secret(n) and not byName[n] then byName[n] = entry end
        end
    end
    name = name or SpellName(spellID)
    if not name or secret(name) then return nil end
    return byName[name]
end

---------------------------------------------------------------------------
-- Consecration: the ground hallowed round you for 8 s, felt once a second (its
-- damage ticks) while you stand in it: faint, warm, uneven, by turns from either
-- hand; fainter towards its edge, nothing once you're out (where the client gives
-- your position; else each tick). Its laying down is Rumble's Surge.
---------------------------------------------------------------------------
PD.CONSECRATION = 26573
PD.HALLOW_TICKS, PD.HALLOW_PERIOD, PD.HALLOW_RADIUS = 8, 1, 8
local hallow

local function Position()
    if not UnitPosition then return nil end
    local ok, y, x = pcall(UnitPosition, "player")
    if not ok or secret(y) or secret(x) or type(y) ~= "number" or type(x) ~= "number" then return nil end
    return x, y
end

-- The gain of a tick where you stand (0: out of it)
function PD.HallowGain(h)
    local x, y = Position()
    if not (h.x and x) then return 1 end
    local d = math.sqrt((x - h.x) ^ 2 + (y - h.y) ^ 2)
    if d > PD.HALLOW_RADIUS then return 0 end
    return 1 - 0.5 * d / PD.HALLOW_RADIUS
end

function PD.HallowStop() hallow = nil end
function PD.Hallowing() return hallow end

-- Consecration laid down (its rule as Rumble has it: off, its volume)
function PD.HallowStart(rule)
    local x, y = Position()
    hallow = { start = Now(), sent = 0, x = x, y = y, volume = rule and rule.volume or 1 }
end

local function Tick(k)
    local V = ns.Rumble
    if not (V and V.Active() and V.EventPattern("instant")) then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then hallow = nil; return end
    if IsMounted and IsMounted() then hallow = nil; return end
    local g = PD.HallowGain(hallow)
    if g <= 0 then return end
    g = g * (hallow.volume or 1)
    local side = (k % 2 == 0 and 0.3 or -0.3) + (math.random() - 0.5) * 0.2
    V.Play("hallow", false, V.Scaled({ strength = g, left = math.min(1, 1 - side), right = math.min(1, 1 + side) }, "instant"))
    local C = ns.HelperCues
    if C and C.Feel then C.Feel("r_hallow", g * (ns.Volume and ns.Volume.Feel and ns.Volume.Feel("instant") or 1), side) end
end

function PD.HallowUpdate()
    local h = hallow
    if not h then return end
    local k = math.floor((Now() - h.start) / PD.HALLOW_PERIOD + 1e-6)
    if k > h.sent and k >= 1 then
        h.sent = math.min(k, PD.HALLOW_TICKS)
        Tick(h.sent)
    end
    if hallow and hallow.sent >= PD.HALLOW_TICKS then hallow = nil end
end

local consecrationName
local function IsConsecration(spellID)
    if secret(spellID) then return false end
    consecrationName = consecrationName or SpellName(PD.CONSECRATION)
    local name = SpellName(spellID)
    return name ~= nil and not secret(name) and name == consecrationName
end

local f = CreateFrame("Frame")
PD.frame = f
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "PLAYER_ENTERING_WORLD" then hallow = nil; return end
    if not IsConsecration(spellID) then return end
    local V = ns.Rumble
    local rule = V and V.SpellRule(spellID, 0)
    if not rule or rule.off then return end
    PD.HallowStart(rule)
end)
f:SetScript("OnUpdate", function() if hallow then PD.HallowUpdate() end end)
