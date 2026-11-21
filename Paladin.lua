-- A paladin's feels: what the paladin spells the moves leave out play (Rumble's
-- V.CLASS_SPELLS.PALADIN, as V.MAGE), its own patterns (V.AddPatterns), and Consecration's ground
-- felt each second you stand in it. The moves already set (seals, blessings, Judgement,
-- Consecration's laying down, Hammer of Justice, Divine Shield, Lay on Hands, Purify, Cleanse)
-- stay Rumble's. docs/PALADIN.md; tests/PaladinCoverage.lua lists every paladin spell of the
-- client and what it plays.
local _, ns = ...
local V = ns.Rumble
if not V or not V.AddPatterns then return end
local PD = {}
ns.Paladin = PD

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
local function Pu(t, len, s, side) return { t, len, s, side or 0 } end

---------------------------------------------------------------------------
-- The gaps' own feels (every step 0.1 s or more, for the engine off)
---------------------------------------------------------------------------
PD.PATTERNS = {
    -- (at the cast)
    { key = "aura", label = "Aura", art = "radiance", move = true,   -- a warm ring spreading round you, settling
        steps = { { 0.1, 0.1, 0.1 }, { 0.3, 0.3, 0.15 }, { 0.1, 0.1, 0.15 } },
        pulses = { Pu(0, 0.06, 0.1, -1), Pu(0, 0.06, 0.1, 1), Pu(0.12, 0.18, 0.28, -0.8), Pu(0.15, 0.18, 0.28, 0.8),
            Pu(0.42, 0.1, 0.09) } },
    { key = "wings", label = "Wings", art = "rise", move = true,      -- Avenging Wrath: light rushing up both arms, held, let go
        steps = { { 0.15, 0.15, 0.1 }, { 0.35, 0.35, 0.1 }, { 0.7, 0.7, 0.12 }, { 1, 1, 0.3 }, { 0.3, 0.3, 0.15 },
            { 0.1, 0.1, 0.15 } },
        pulses = { Pu(0, 0.05, 0.15, -0.6), Pu(0.06, 0.05, 0.15, 0.6), Pu(0.14, 0.06, 0.35, -0.8), Pu(0.2, 0.06, 0.35, 0.8),
            Pu(0.3, 0.08, 0.7), Pu(0.42, 0.3, 1), Pu(0.8, 0.1, 0.25, -0.5), Pu(0.8, 0.1, 0.25, 0.5), Pu(1, 0.05, 0.08) } },
    -- (Consecration's ground, once a second while you stand in it: faint, warm, uneven)
    { key = "hallow", label = "Hallowed", art = "surge",
        steps = { { 0.1, 0.12, 0.15 }, { 0.04, 0.04, 0.1 } },
        pulses = { Pu(0, 0.12, 0.12, -0.3), Pu(0.08, 0.12, 0.12, 0.3), Pu(0.3, 0.05, 0.05) } },
}
V.AddPatterns(PD.PATTERNS)

---------------------------------------------------------------------------
-- What each spell plays, by its first rank's ID (every rank shares its name).
-- move, when: an instant's feel, at the "cast".
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
    micro = { 5502 },                                       -- Sense Undead (tracking): a faint tick
}
-- (only what played nothing: anything that played a feel keeps it, a guessed Blow too: Exorcism's
-- Judgement, Avenger's Shield's and Hand of Reckoning's Blow, Redemption's and Turn Undead's
-- casts, the steeds' Healing loop)
PD.SPELLS = {}
for move, ids in pairs(AT_CAST) do
    for _, id in ipairs(ids) do PD.SPELLS[id] = { move = move, when = "cast" } end
end

V.CLASS_SPELLS.PALADIN = PD.SPELLS

-- A paladin spell's entry (Rumble's, every rank by its name, a paladin's only); nil: none
function PD.Of(spellID, name) return V.ClassSpellOf(spellID, name) end

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

function PD.HallowStop() hallow = nil; PD.frame:Hide() end
function PD.Hallowing() return hallow end

-- Consecration laid down (its rule as Rumble has it: off, its volume)
function PD.HallowStart(rule)
    local x, y = Position()
    hallow = { start = Now(), sent = 0, x = x, y = y, volume = rule and rule.volume or 1 }
    PD.frame:Show()
end

-- A tick's rumble waits for whatever plays (a blow, a swing, a seal: never cut short), at most
-- PD.HALLOW_WAIT s, else it's dropped; its HD goes on time (WoW Helper mixes it under the rest)
PD.HALLOW_WAIT = 0.5
local function Rumble(g, side)
    local F = ns.FullFeel
    local points, scale
    if F and F.Rumble then points, scale = F.Rumble("instant") end
    local vol = ns.Volume and ns.Volume.Feel and ns.Volume.Feel("instant") or 1
    if points then
        -- (as the other instants: the moment's plain rumble, faint while WoW Helper plays the HD)
        return V.PlayPlain(points, vol * g * scale)
    end
    V.Play("hallow", false, V.Scaled({ strength = g, left = math.min(1, 1 - side), right = math.min(1, 1 + side) }, "instant"))
end

local function Tick(k)
    if not (V.Active() and V.EventPattern("instant")) then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then hallow = nil; return end
    if IsMounted and IsMounted() then hallow = nil; return end
    local g = PD.HallowGain(hallow)
    if g <= 0 then return end
    g = g * (hallow.volume or 1)
    local side = (k % 2 == 0 and 0.3 or -0.3) + (math.random() - 0.5) * 0.2
    hallow.rumble = { g = g, side = side, by = Now() + PD.HALLOW_WAIT }
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
    local r = hallow and hallow.rumble
    if r then
        if Now() > r.by then hallow.rumble = nil
        elseif not V.Busy() then hallow.rumble = nil; Rumble(r.g, r.side) end
    end
    if hallow and hallow.sent >= PD.HALLOW_TICKS and not hallow.rumble then hallow = nil end
    if not hallow then PD.frame:Hide() end
end

local consecrationName
local function IsConsecration(spellID)
    if secret(spellID) then return false end
    consecrationName = consecrationName or SpellName(PD.CONSECRATION)
    local name = SpellName(spellID)
    return name ~= nil and not secret(name) and name == consecrationName
end

-- (its frame runs only while the ground lasts)
local f = CreateFrame("Frame")
PD.frame = f
f:Hide()
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "PLAYER_ENTERING_WORLD" then return PD.HallowStop() end
    if not IsConsecration(spellID) then return end
    local rule = V.SpellRule(spellID, 0)
    if not rule or rule.off then return end
    PD.HallowStart(rule)
end)
f:SetScript("OnUpdate", PD.HallowUpdate)
