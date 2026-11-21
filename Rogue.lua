-- A rogue's feels (the rogue pass, 2026-11-20; docs/WARRIOR-ROGUE.md): what each rogue spell
-- plays (Rumble's V.CLASS_SPELLS.ROGUE, as V.MAGE), its own patterns, finishers by the combo
-- points spent (ComboPoints.lua), Stealth in and out, poisons coating a blade, a lock giving.
-- Loaded right after Rumble.lua. tests/Rogue.lua lists every rogue spell of the client and what
-- it plays.
--
-- Materials: thin steel and points, leather, cloth, a cosh's dull weight, powder, a wire; the
-- dark is a breath held. Blows land at the weapon's impact (Rumble's AbilityResult, melee);
-- thrown blades at their landing (the ranged impact WoW Helper learned).
local _, ns = ...
local V = ns.Rumble
if not V or not V.AddPatterns then return end
local RG = {}
ns.Rogue = RG

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
local function Pu(t, len, s, side) return { t, len, s, side or 0 } end

RG.PATTERNS = {
    -- Blades in
    { key = "backstab", label = "Backstab", art = "stab", move = true,                  -- the point slid between the ribs, a twist
        steps = { { 0.6, 0.85, 0.1 }, { 0.2, 0.3, 0.1 } },
        pulses = { Pu(0, 0.05, 0.68, 0.3), Pu(0.07, 0.1, 0.24, 0.3), Pu(0.2, 0.05, 0.1, -0.1) } },
    { key = "ambush", label = "Ambush", art = "stab", move = true,                       -- out of the dark: a heavy thrust
        steps = { { 1, 1, 0.12 }, { 0.3, 0.3, 0.1 } },
        pulses = { Pu(0, 0.1, 0.9), Pu(0.13, 0.1, 0.24), Pu(0.3, 0.05, 0.08) } },
    { key = "mutilate", label = "Mutilate", art = "stab", move = true,                  -- two daggers at once, both hands
        steps = { { 0.75, 0.75, 0.1 }, { 0.15, 0.15, 0.1 } },
        pulses = { Pu(0, 0.06, 0.55, -0.9), Pu(0.02, 0.06, 0.55, 0.9), Pu(0.1, 0.08, 0.14) } },
    { key = "kick", label = "Kick", art = "bash", move = true,                          -- a boot heel, sharp
        steps = { { 0.4, 0.8, 0.1 }, { 0.05, 0.15, 0.1 } },
        pulses = { Pu(0, 0.05, 0.7, 0.6), Pu(0.07, 0.05, 0.12, 0.6) } },
    { key = "shuriken", label = "Thrown blade", art = "toss", move = true,              -- the blade thunks in, a faint ring
        steps = { { 0.4, 0.5, 0.1 }, { 0.05, 0.12, 0.1 } },
        pulses = { Pu(0, 0.05, 0.42, 0.4), Pu(0.13, 0.05, 0.14, -0.3) } },
    -- Openers and tricks, at the cast
    { key = "sap", label = "Sap", art = "bash", move = true,                            -- a cosh to the back of the head, dull
        steps = { { 0.55, 0.5, 0.12 }, { 0.08, 0.08, 0.1 } },
        pulses = { Pu(0, 0.08, 0.52), Pu(0.13, 0.05, 0.08) } },
    { key = "garrote", label = "Garrote", art = "rend", move = true,                    -- a wire round a throat, drawn tight
        steps = { { 0.15, 0.15, 0.1 }, { 0.35, 0.35, 0.3 }, { 0.08, 0.08, 0.1 } },
        pulses = { Pu(0, 0.05, 0.15, -0.8), Pu(0, 0.05, 0.15, 0.8), Pu(0.07, 0.3, 0.32), Pu(0.42, 0.05, 0.08) } },
    { key = "blind", label = "Blind", art = "toss", move = true,                        -- powder thrown in a face, a soft puff
        steps = { { 0.1, 0.25, 0.1 }, { 0.05, 0.12, 0.2 } },
        pulses = { Pu(0, 0.05, 0.18, 0.5), Pu(0.06, 0.2, 0.1, 0.3) } },
    { key = "pocket", label = "Pick Pocket", art = "micro", move = true,                -- fingers in, a coin's faint clink
        steps = { { 0.04, 0.08, 0.15 }, { 0.1, 0.2, 0.1 } },
        pulses = { Pu(0, 0.15, 0.04, 0.6), Pu(0.22, 0.05, 0.1, 0.7) } },
    { key = "cloak", label = "Stealth", art = "fade", move = true,                      -- the cloak drawn round, the world going quiet
        steps = { { 0.15, 0.15, 0.15 }, { 0.06, 0.06, 0.25 } },
        pulses = { Pu(0, 0.15, 0.14), Pu(0.2, 0.25, 0.05), Pu(0.5, 0.05, 0.03) } },
    { key = "emerge", label = "Out of stealth", art = "rise", move = true,              -- a breath let out
        steps = { { 0.05, 0.05, 0.1 }, { 0.12, 0.12, 0.15 } },
        pulses = { Pu(0, 0.05, 0.04), Pu(0.08, 0.15, 0.12) } },
    { key = "vanish", label = "Vanish", art = "burst", move = true,                     -- a flash of powder, a roll, gone
        steps = { { 0.6, 0.6, 0.1 }, { 0.15, 0.05, 0.1 }, { 0.05, 0.2, 0.1 }, { 0.05, 0.05, 0.2 } },
        pulses = { Pu(0, 0.06, 0.55), Pu(0.1, 0.05, 0.15, -0.6), Pu(0.22, 0.1, 0.18, 0.6), Pu(0.45, 0.2, 0.05) } },
    { key = "sprint", label = "Sprint", art = "charge", move = true,                    -- feet quickening, light and hard
        steps = { { 0.25, 0.05, 0.1 }, { 0.05, 0.25, 0.1 }, { 0.3, 0.05, 0.1 }, { 0.05, 0.3, 0.1 } },
        pulses = { Pu(0, 0.05, 0.18, -0.6), Pu(0.15, 0.05, 0.2, 0.6), Pu(0.27, 0.05, 0.23, -0.6), Pu(0.36, 0.05, 0.25, 0.6),
            Pu(0.44, 0.05, 0.18, -0.6) } },
    { key = "shadowstep", label = "Shadowstep", art = "fade", move = true,              -- a breath of nothing, then behind them
        steps = { { 0.08, 0.08, 0.15 }, { 0.3, 0.15, 0.1 } },
        pulses = { Pu(0, 0.1, 0.07), Pu(0.22, 0.05, 0.3, -0.4) } },
    { key = "coldBlood", label = "Cold Blood", art = "heart", move = true,                  -- a held breath, stillness, one beat
        steps = { { 0.05, 0.05, 0.2 }, { 0, 0, 0.2 }, { 0.3, 0.25, 0.1 } },
        pulses = { Pu(0, 0.2, 0.05), Pu(0.42, 0.08, 0.24) } },
    -- Around you
    { key = "fanOfKnives", label = "Fan of Knives", art = "whirl", move = true,         -- knives fanning out: small hits all round
        steps = { { 0.3, 0.3, 0.1 }, { 0.25, 0.1, 0.1 }, { 0.1, 0.25, 0.1 }, { 0.1, 0.1, 0.1 } },
        pulses = { Pu(0, 0.05, 0.25, -1), Pu(0.04, 0.05, 0.22, 1), Pu(0.09, 0.05, 0.2, -0.4), Pu(0.13, 0.05, 0.2, 0.5),
            Pu(0.18, 0.05, 0.15), Pu(0.24, 0.05, 0.12, -0.8), Pu(0.29, 0.05, 0.1, 0.8) } },
    { key = "blunderbuss", label = "Blunderbuss", art = "recoil", move = true,          -- black powder's kick, the shot spraying
        steps = { { 1, 1, 0.12 }, { 0.3, 0.3, 0.1 }, { 0.1, 0.1, 0.1 } },
        pulses = { Pu(0, 0.12, 1), Pu(0.14, 0.05, 0.25, -0.6), Pu(0.18, 0.05, 0.25, 0.6), Pu(0.28, 0.1, 0.1) } },
    -- Finishers (by the points spent: RG.Rule)
    { key = "cut1", label = "Eviscerate 1", art = "flurry", move = true,                -- one or two points: one clean cut
        steps = { { 0.45, 0.55, 0.1 }, { 0.1, 0.1, 0.1 } },
        pulses = { Pu(0, 0.06, 0.48, 0.3), Pu(0.08, 0.05, 0.12) } },
    { key = "cut3", label = "Eviscerate 3", art = "flurry", move = true,                -- three or four: a cross cut
        steps = { { 0.45, 0.2, 0.1 }, { 0.2, 0.7, 0.1 }, { 0.12, 0.12, 0.1 } },
        pulses = { Pu(0, 0.05, 0.4, -0.5), Pu(0.1, 0.07, 0.65, 0.5), Pu(0.2, 0.05, 0.12) } },
    { key = "cut5", label = "Eviscerate 5", art = "flurry", move = true,                -- five: blow on blow, the last the deepest
        steps = { { 0.4, 0.2, 0.1 }, { 0.2, 0.45, 0.1 }, { 0.5, 0.4, 0.1 }, { 1, 1, 0.14 } },
        pulses = { Pu(0, 0.05, 0.35, -0.5), Pu(0.08, 0.05, 0.4, 0.5), Pu(0.16, 0.05, 0.45, -0.3), Pu(0.25, 0.14, 0.95),
            Pu(0.43, 0.05, 0.18) } },
    { key = "kidney", label = "Kidney Shot", art = "bash", move = true,                 -- a fist low into the side, the breath knocked out
        steps = { { 0.85, 0.4, 0.12 }, { 0.1, 0.05, 0.25 } },
        pulses = { Pu(0, 0.1, 0.8, -0.4), Pu(0.14, 0.25, 0.1, -0.4) } },
    { key = "rupture", label = "Rupture", art = "rend", move = true,                    -- a deep tear, then the bleeding
        steps = { { 0.5, 0.35, 0.1 }, { 0.3, 0.45, 0.1 }, { 0.08, 0.08, 0.2 } },
        pulses = { Pu(0, 0.08, 0.45, 0.3), Pu(0.1, 0.08, 0.3, -0.3), Pu(0.3, 0.05, 0.08), Pu(0.55, 0.05, 0.06) } },
    { key = "sliceDice", label = "Slice and Dice", art = "flurry", move = true,         -- two blades flicked, faint
        steps = { { 0.15, 0.05, 0.1 }, { 0.05, 0.15, 0.1 } },
        pulses = { Pu(0, 0.05, 0.12, -0.6), Pu(0.08, 0.05, 0.12, 0.6) } },
    { key = "expose", label = "Expose Armor", art = "rend", move = true,                -- a strap cut, the plate sagging
        steps = { { 0.3, 0.4, 0.1 }, { 0.1, 0.1, 0.15 } },
        pulses = { Pu(0, 0.05, 0.3, 0.4), Pu(0.1, 0.15, 0.1) } },
    { key = "betweenEyes", label = "Between the Eyes", art = "recoil", move = true,     -- a crack at the brow, the head snapping back
        steps = { { 0.7, 0.7, 0.1 }, { 0.15, 0.15, 0.1 } },
        pulses = { Pu(0, 0.06, 0.7), Pu(0.1, 0.05, 0.15), Pu(0.2, 0.05, 0.06) } },
    { key = "crimsonTempest", label = "Crimson Tempest", art = "whirl", move = true,     -- a spin opening them all, then bleeding
        steps = { { 0.45, 0.05, 0.1 }, { 0.3, 0.3, 0.1 }, { 0.05, 0.45, 0.1 }, { 0.1, 0.05, 0.15 } },
        pulses = { Pu(0, 0.05, 0.35, -0.9), Pu(0.12, 0.05, 0.3), Pu(0.24, 0.05, 0.35, 0.9), Pu(0.4, 0.1, 0.1, -0.4),
            Pu(0.6, 0.1, 0.07, 0.4) } },
    { key = "bladeDance", label = "Blade Dance", art = "whirl", move = true,            -- blades flicked round you, a guard
        steps = { { 0.25, 0.05, 0.1 }, { 0.05, 0.25, 0.1 }, { 0.15, 0.15, 0.12 } },
        pulses = { Pu(0, 0.05, 0.2, -0.8), Pu(0.1, 0.05, 0.2, 0.8), Pu(0.2, 0.05, 0.2, -0.3), Pu(0.32, 0.12, 0.12) } },
    -- A blade coated (a loop, faint); a lock giving
    { key = "coat", label = "Coating", art = "sew", group = "Crafts",                  -- a cloth drawn along the blade, a drip
        steps = { { 0.06, 0, 0.3 }, { 0, 0.06, 0.3 }, { 0.08, 0.08, 0.1 }, { 0, 0, 0.2 } },
        pulses = { cycle = 0.9, Pu(0, 0.3, 0.05, -0.4), Pu(0.4, 0.3, 0.05, 0.4), Pu(0.75, 0.05, 0.07) } },
    { key = "coated", label = "Coated", art = "double", group = "Crafts",              -- the blade wiped, the vial stoppered
        steps = { { 0.15, 0.15, 0.1 }, { 0.08, 0.08, 0.1 } },
        pulses = { Pu(0, 0.05, 0.15), Pu(0.1, 0.05, 0.08) } },
    { key = "unlock", label = "Unlocked", art = "click", group = "Crafts",              -- the cylinder turning, the lock giving
        steps = { { 0.2, 0.3, 0.1 }, { 0.15, 0.15, 0.1 } },
        pulses = { Pu(0, 0.05, 0.25, 0.3), Pu(0.08, 0.1, 0.15) } },
}

V.AddPatterns(RG.PATTERNS)

---------------------------------------------------------------------------
-- Finishers: by the points spent (ComboPoints.lua: read as the spell was sent).
-- Eviscerate one cut, a cross cut, a flurry; the others by strength.
---------------------------------------------------------------------------
local function Spent() return ns.Combo and ns.Combo.Spent() or 0 end
local function Points() return ns.Combo and ns.Combo.Scale() or 1 end
RG.TIERS = { "cut1", "cut1", "cut3", "cut3", "cut5" }
function RG.Cut()
    local n = Spent()
    if n <= 0 then return "cut5" end
    return RG.TIERS[math.min(n, #RG.TIERS)]
end

---------------------------------------------------------------------------
-- Stealth: into it, the cloak at its cast; out of it, a breath, unless an
-- opener just said it (Ambush, Cheap Shot, Garrote...). Stealth cast again to
-- leave it: the breath, not the cloak.
---------------------------------------------------------------------------
-- (the cast's news may come just before or just after the stealth drops: the breath waits
-- EMERGE_AFTER, then plays unless a cast came within OPENER_SAYS of the drop)
RG.OPENER_SAYS, RG.EMERGE_AFTER = 0.5, 0.15
local hidden = { on = false, at = -math.huge, cast = -math.huge }
RG.hidden = hidden
local function Stealthed()
    if IsStealthed then
        local ok, v = pcall(IsStealthed)
        if ok and not secret(v) then return v and true or false end
    end
    return hidden.on
end
local function Rogue()
    if not UnitClass then return false end
    local _, class = UnitClass("player")
    return not secret(class) and class == "ROGUE"
end
local STEALTH = 1784
local function Emerge(left)
    if math.abs(hidden.cast - left) <= RG.OPENER_SAYS or hidden.on then return end
    V.instantMove = "emerge"
    V.FireAs(SpellName(STEALTH), "instant")
end
function RG.StealthChanged()
    local on = Stealthed()
    if on == hidden.on then return end
    hidden.on = on
    if on then hidden.at = Now(); return end
    if not Rogue() then return end
    local left = Now()
    if C_Timer and C_Timer.After then C_Timer.After(RG.EMERGE_AFTER, function() Emerge(left) end) else Emerge(left) end
end
-- (Stealth cast while hidden a while: leaving it, the breath says it)
function RG.Cloak()
    if Stealthed() and Now() - hidden.at > 0.3 then return false end
    return "cloak"
end

---------------------------------------------------------------------------
-- A poison on a blade done: Coated (its HD is WoW Helper's, at the release);
-- a lock picked: it gives
---------------------------------------------------------------------------
function RG.Coated()
    if V.Active and V.Active() and V.Play then V.Play("coated", false) end
    return true
end
function RG.Unlocked()
    if V.Active and V.Active() and V.Play then V.Play("unlock", false) end
    return true
end

---------------------------------------------------------------------------
-- What each rogue spell plays: V.CLASS_SPELLS.ROGUE (every rank by its name, a rogue's only)
---------------------------------------------------------------------------
local function With(e, extra)
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end
local function Hit(move, extra) return With({ move = move, when = "hit", melee = true }, extra) end
local function Cast(move, extra) return With({ move = move, when = "cast" }, extra) end
local THROWN = { melee = false, ranged = true }
local function Quiet(why) return { moveOf = function() return false end, why = why } end
local POISON = { set = "feel:coat", released = RG.Coated }
local LOCK = { released = RG.Unlocked }
-- A poison put on a blade (the item's own cast, 3 s; every rank)
RG.POISONS = { 8679, 8686, 8688, 11338, 11339, 11340, 2823, 2824, 11355, 11356, 25351, 3408, 11202, 5761, 8693, 11399,
    13219, 13225, 13226, 13227, 439462, 439464, 439465, 458821, 1214171 }

local SPELLS = {
    -- In and out of sight (leaving Stealth: RG.StealthChanged)
    [1784] = Cast("cloak", { moveOf = RG.Cloak }), [1856] = Cast("vanish"),
    [400029] = Cast("shadowstep"), [2983] = Cast("sprint"),                   -- Shadowstep (rune), Sprint
    -- At the weapon's impact
    [53] = Hit("backstab"), [8676] = Hit("ambush"), [399956] = Hit("mutilate"),
    [1752] = Hit("stab"), [14278] = Hit("stab"), [16511] = Hit("stab"), [14251] = Hit("stab"), -- Sinister, Ghostly Strike, Hemorrhage, Riposte
    [1329283] = Hit("stab"), [424919] = Hit("stab"), [399985] = Hit("stab"),  -- Shank, Main Gauche, Shadowstrike
    [424785] = Hit("slash"), [1776] = Hit("bash"), [1766] = Hit("kick"),      -- Saber Slash, Gouge, Kick
    -- Thrown: at its landing (Shuriken Toss, Poisoned Knife, Quick Draw)
    [399986] = Hit("shuriken", THROWN), [425013] = Hit("shuriken", THROWN), [398196] = Hit("shuriken", THROWN),
    -- Openers and tricks: at the cast (a dodge or a parry of it still shows)
    [6770] = Cast("sap", { avoidOnly = true }), [1833] = Cast("bash", { avoidOnly = true }),  -- Sap, Cheap Shot
    [703] = Cast("garrote", { avoidOnly = true }), [2094] = Cast("blind", { avoidOnly = true }),
    [921] = Cast("pocket"), [424799] = Cast("stab", { avoidOnly = true, scale = function() return 0.6 end }), -- Pick Pocket, Shiv
    [1316709] = Cast("hex"),                                                  -- Death Mark (Forever)
    -- Around you
    [409240] = Cast("fanOfKnives"), [409239] = Cast("fanOfKnives"), [436564] = Cast("blunderbuss"), -- (runes)
    -- Cooldowns
    [5277] = Cast("ward"), [13877] = Cast("whirl"), [13750] = Cast("enrage"), -- Evasion, Blade Flurry, Adrenaline Rush
    [14177] = Cast("coldBlood"), [14183] = Cast("coldBlood"), [14185] = Cast("coldBlood"), -- Cold Blood, Premeditation, Preparation
    -- Finishers: by the points spent
    [2098] = Hit("cut5", { moveOf = RG.Cut }),                                -- Eviscerate
    [400009] = Hit("betweenEyes", { melee = false, ranged = true, scale = Points }),
    [408] = Cast("kidney", { avoidOnly = true, scale = Points }),
    [1943] = Cast("rupture", { avoidOnly = true, scale = Points }),
    [8647] = Cast("expose", { avoidOnly = true, scale = Points }),
    [5171] = Cast("sliceDice", { scale = Points }),
    [412096] = Cast("crimsonTempest", { scale = Points }), [400012] = Cast("bladeDance", { scale = Points }), -- (runes)
    -- Quiet by design
    [1966] = Quiet("A trick: nothing"), [1725] = Quiet("A trick: nothing"), [438040] = Quiet("A trick: nothing"), -- Feint, Distract, Redirect
    [14093] = Quiet("Vanish says it"),                                        -- Vanished
    [13706] = Quiet("Set off by another: quiet"), [13977] = Quiet("Set off by another: quiet"), -- Hack and Slash, Initiative
    -- A lock picked (Opening's tumbler while it lasts), a trap disarmed: the lock gives
    [1804] = LOCK, [1842] = { set = "feel:click", released = RG.Unlocked },
}
for _, id in ipairs(RG.POISONS) do SPELLS[id] = POISON end
V.CLASS_SPELLS.ROGUE = SPELLS
RG.SPELLS = SPELLS

-- (a cast of yours: the opener that broke Stealth says it; Stealth itself is not one)
local handlers = {}
RG.handlers = handlers
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    if unit ~= "player" then return end
    if spellID and not secret(spellID) and SpellName(spellID) == SpellName(STEALTH) then return end
    hidden.cast = Now()
end
handlers.UPDATE_STEALTH = function() RG.StealthChanged() end
handlers.PLAYER_ENTERING_WORLD = function() hidden.on = Stealthed() end
local frame = CreateFrame("Frame")
RG.frame = frame
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
pcall(frame.RegisterEvent, frame, "UPDATE_STEALTH")
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
