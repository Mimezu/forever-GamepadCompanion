-- A rogue's feels (the rogue pass, 2026-11-20; docs/WARRIOR-ROGUE.md): what each rogue spell
-- plays, its own patterns, finishers by the combo points spent, Stealth in and out, poisons
-- coating a blade, Pick Lock's picks. Loaded before Rumble.lua (ClassFeels.lua registers it
-- there). tests/Rogue.lua lists every rogue spell of the client and what it plays.
--
-- Materials: thin steel and points, leather, cloth, a cosh's dull weight, powder, a wire; the
-- dark is a breath held. Blows land at the weapon's impact (Rumble's AbilityResult); thrown
-- blades at their landing (the ranged impact WoW Helper learned).
local _, ns = ...
local CF = ns.ClassFeels
local RG = { class = "ROGUE", ENGRAVE = true }
ns.Rogue = RG

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
    { key = "focus", label = "Cold Blood", art = "heart", move = true,                  -- a held breath, stillness, one beat
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
    -- Loops: a blade coated, a lock picked, poisons ground (faint)
    { key = "coat", label = "Coating", art = "sew", group = "Crafts",                  -- a cloth drawn along the blade, a drip
        steps = { { 0.06, 0, 0.3 }, { 0, 0.06, 0.3 }, { 0.08, 0.08, 0.1 }, { 0, 0, 0.2 } },
        pulses = { cycle = 0.9, Pu(0, 0.3, 0.05, -0.4), Pu(0.4, 0.3, 0.05, 0.4), Pu(0.75, 0.05, 0.07) } },
    { key = "coated", label = "Coated", art = "double", group = "Crafts",              -- the blade wiped, the vial stoppered
        steps = { { 0.15, 0.15, 0.1 }, { 0.08, 0.08, 0.1 } },
        pulses = { Pu(0, 0.05, 0.15), Pu(0.1, 0.05, 0.08) } },
    { key = "picks", label = "Picks", art = "click", group = "Crafts",                  -- the pick raking, pins setting one by one
        steps = { { 0.06, 0.1, 0.1 }, { 0, 0, 0.1 }, { 0.08, 0.12, 0.1 }, { 0, 0, 0.25 }, { 0.1, 0.15, 0.1 }, { 0, 0, 0.35 } },
        pulses = { cycle = 1, Pu(0, 0.05, 0.06, 0.3), Pu(0.18, 0.05, 0.08, 0.3), Pu(0.32, 0.05, 0.05, 0.3), Pu(0.6, 0.05, 0.1, 0.3) } },
    { key = "unlock", label = "Unlocked", art = "click", group = "Crafts",              -- the cylinder turning, the lock giving
        steps = { { 0.2, 0.3, 0.1 }, { 0.15, 0.15, 0.1 } },
        pulses = { Pu(0, 0.05, 0.25, 0.3), Pu(0.08, 0.1, 0.15) } },
    { key = "grind", label = "Grinding", art = "bubble", group = "Crafts",              -- a pestle in a mortar
        steps = { { 0.06, 0.03, 0.2 }, { 0.03, 0.06, 0.2 } },
        pulses = { cycle = 0.8, Pu(0, 0.2, 0.06, -0.3), Pu(0.4, 0.2, 0.06, 0.3) } },
}

-- A poison put on a blade (the item's own cast, 3 s; every rank): its own set, Coated as it's done
RG.POISONS = { 8679, 8686, 8688, 11338, 11339, 11340, 2823, 2824, 11355, 11356, 25351, 3408, 11202, 5761, 8693, 11399,
    13219, 13225, 13226, 13227, 439462, 439464, 439465, 458821, 1214171 }
RG.CAST_ACTIONS = {
    { key = "poison", label = "Poison", kind = "spell", pattern = "coat", spells = RG.POISONS },
    -- (Pick Lock and Disarm Trap: a lock's picks, not any Opening's tumbler)
    { key = "lockpicking", label = "Pick Lock", kind = "gather", pattern = "picks", spell = 1804 },
    -- (Poisons, the craft: ground in a mortar, stoppered as Alchemy's)
    { key = "poisons", label = "Poisons", kind = "craft", pattern = "grind", finish = "cork", spell = 2842 },
}
RG.GATHER = { lockpicking = { 1804, 1842 } }
RG.GATHER_FINISH = { lockpicking = "unlock" }

RG.RULES = {
    -- In and out of sight (leaving Stealth: RG.StealthChanged)
    { "cloak", "cast", "Into the dark; out: a breath", { 1784 } },
    { "vanish", "cast", "A puff, a roll, gone", { 1856 } },
    { "shadowstep", "cast", "Behind them", { 400029 } },                                 -- (rune)
    { "sprint", "cast", "Feet quickening", { 2983 } },
    -- At the weapon's impact
    { "backstab", "hit", "Between the ribs", { 53 } },
    { "ambush", "hit", "Out of the dark", { 8676 } },
    { "mutilate", "hit", "Both blades at once", { 399956 } },
    -- Sinister Strike, Ghostly Strike, Hemorrhage, Riposte, Shank, Main Gauche, Shadowstrike
    { "stab", "hit", "Known: Stab", { 1752, 14278, 16511, 14251, 1329283, 424919, 399985 } },
    { "slash", "hit", "Known: Slash", { 424785 } },                                      -- Saber Slash
    { "bash", "hit", "Known: Bash", { 1776 } },                                          -- Gouge
    { "kick", "hit", "A boot heel", { 1766 } },
    -- Thrown: at its landing (Shuriken Toss, Poisoned Knife, Quick Draw)
    { "shuriken", "hit", "Thrown: at the hit", { 399986, 425013, 398196 }, { ranged = true } },
    -- Openers and tricks: at the cast (a dodge or a parry of it still shows)
    { "sap", "cast", "A cosh", { 6770 }, { avoid = true } },
    { "bash", "cast", "A stun", { 1833 }, { avoid = true } },                            -- Cheap Shot
    { "garrote", "cast", "A wire drawn tight", { 703 }, { avoid = true } },
    { "blind", "cast", "Powder in the eyes", { 2094 }, { avoid = true } },
    { "pocket", "cast", "Fingers in a pocket", { 921 } },
    { "stab", "cast", "A quick nick", { 424799 }, { volume = 0.6, avoid = true } },     -- Shiv
    { "hex", "cast", "A mark", { 1316709 } },                                            -- Death Mark (Forever)
    -- Around you
    { "fanOfKnives", "cast", "Knives all round", { 409240, 409239 } },                   -- (rune)
    { "blunderbuss", "cast", "Black powder", { 436564 } },                               -- (rune)
    -- Cooldowns
    { "ward", "cast", "Known: Ward", { 5277 } },                                         -- Evasion
    { "whirl", "cast", "Known: Whirl", { 13877 } },                                      -- Blade Flurry
    { "enrage", "cast", "Blood racing", { 13750 } },                                     -- Adrenaline Rush
    { "focus", "cast", "A held breath", { 14177, 14183, 14185 } },                       -- Cold Blood, Premeditation, Preparation
    -- Finishers: by the points spent (RG.Rule)
    { "cut5", "hit", "By the points: a cut to a flurry", { 2098 }, { finisher = "tiers" } },  -- Eviscerate
    { "betweenEyes", "hit", "By the points", { 400009 }, { finisher = true, ranged = true } },
    { "kidney", "cast", "By the points", { 408 }, { finisher = true, avoid = true } },
    { "rupture", "cast", "By the points", { 1943 }, { finisher = true, avoid = true } },
    { "expose", "cast", "By the points", { 8647 }, { finisher = true, avoid = true } },
    { "sliceDice", "cast", "By the points", { 5171 }, { finisher = true } },
    { "crimsonTempest", "cast", "By the points", { 412096 }, { finisher = true } },      -- (rune)
    { "bladeDance", "cast", "By the points", { 400012 }, { finisher = true } },          -- (rune)
    -- Quiet by design
    { nil, "none", "A trick: nothing", { 1966, 1725, 438040 } },                         -- Feint, Distract, Redirect
    { nil, "none", "Vanish says it", { 14093 } },                                        -- Vanished
    { nil, "none", "Set off by another: quiet", { 13706, 13977 } },                      -- Hack and Slash, Initiative
}

---------------------------------------------------------------------------
-- Combo points: the points a finisher spends. The client may drop them to 0
-- before or after the cast's news: the last count, if it dropped just now.
---------------------------------------------------------------------------
RG.SPENT_WINDOW = 0.6
local points = { now = 0, before = 0, droppedAt = -math.huge }
RG.points = points
local function Read()
    local n
    if GetComboPoints then
        local ok, v = pcall(GetComboPoints, "player", "target")
        if ok and not CF.secret(v) then n = v end
    end
    if n == nil and UnitPower then
        local ok, v = pcall(UnitPower, "player", 4)
        if ok and not CF.secret(v) then n = v end
    end
    return type(n) == "number" and n or nil
end
function RG.PointsChanged()
    local n = Read()
    if not n then return end
    if n < points.now then points.before, points.droppedAt = points.now, CF.Now() end
    points.now = n
end
-- The points a finisher used now (0: none known): as you sent it (UNIT_SPELLCAST_SENT, before
-- the client spends them), else the count now, else the count before a drop just now
RG.SENT_WINDOW = 1
function RG.Spent()
    if CF.Now() - (points.sentAt or -math.huge) <= RG.SENT_WINDOW and (points.sent or 0) > 0 then return points.sent end
    local n = Read() or points.now
    if n > 0 then return n end
    if CF.Now() - points.droppedAt <= RG.SPENT_WINDOW then return points.before end
    return 0
end
-- Eviscerate's cut by the points, the others' volume (nothing known: as designed)
RG.TIERS = { "cut1", "cut1", "cut3", "cut3", "cut5" }
function RG.Gain(n) return math.min(1, 0.55 + 0.09 * n) end
function RG.Rule(_, _, r)
    if not r.finisher then return end
    local n = RG.Spent()
    if n <= 0 then return end
    if r.finisher == "tiers" then
        r.move = RG.TIERS[math.min(n, #RG.TIERS)]
    else
        r.volume = math.min(r.volume or 1, RG.Gain(n))
    end
    r.why = r.why .. " (" .. n .. ")"
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
        if ok and not CF.secret(v) then return v and true or false end
    end
    return hidden.on
end
local function Emerge(left)
    if math.abs(hidden.cast - left) <= RG.OPENER_SAYS or hidden.on then return end
    CF.Play(CF.SpellName(1784), "emerge")
end
function RG.StealthChanged()
    local on = Stealthed()
    if on == hidden.on then return end
    hidden.on = on
    if on then hidden.at = CF.Now(); return end
    if CF.Class() ~= "ROGUE" then return end
    local left = CF.Now()
    if C_Timer and C_Timer.After then C_Timer.After(RG.EMERGE_AFTER, function() Emerge(left) end) else Emerge(left) end
end

-- (a cast of yours: the opener that broke Stealth says it; Stealth itself is not one)
local STEALTH = 1784
local handlers = {}
RG.handlers = handlers
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    if unit ~= "player" then return end
    if spellID and not CF.secret(spellID) and CF.SpellName(spellID) == CF.SpellName(STEALTH) then return end
    hidden.cast = CF.Now()
end
handlers.UNIT_SPELLCAST_SENT = function(unit)
    if unit == "player" then points.sent, points.sentAt = Read() or points.now, CF.Now() end
end
handlers.UPDATE_STEALTH = function() RG.StealthChanged() end
handlers.UNIT_POWER_UPDATE = function(unit, kind)
    if unit == "player" and kind == "COMBO_POINTS" then RG.PointsChanged() end
end
handlers.PLAYER_TARGET_CHANGED = function() points.now, points.droppedAt = Read() or 0, -math.huge end
handlers.PLAYER_ENTERING_WORLD = function() hidden.on = Stealthed(); points.now = Read() or 0 end

-- (Stealth cast while hidden a while: leaving it, the breath says it)
local baseRule = RG.Rule
function RG.Rule(spellID, name, r)
    if r.move == "cloak" and Stealthed() and CF.Now() - hidden.at > 0.3 then
        r.move, r.when, r.why = nil, "none", "Leaving: Out of stealth"
        return
    end
    return baseRule(spellID, name, r)
end

local Listen
RG.frame, Listen = CF.Frame(handlers)
Listen("UNIT_SPELLCAST_SUCCEEDED", "player")
Listen("UNIT_SPELLCAST_SENT", "player")
Listen("UPDATE_STEALTH")
Listen("UNIT_POWER_UPDATE", "player")
Listen("PLAYER_TARGET_CHANGED")
Listen("PLAYER_ENTERING_WORLD")

---------------------------------------------------------------------------
-- A poison on a blade done: Coated (its HD is WoW Helper's, at the release)
---------------------------------------------------------------------------
function RG.Released(action)
    if action ~= "poison" then return false end
    local V = ns.Rumble
    if V and V.Active and V.Active() and V.Play then V.Play("coated", false) end
    return true
end

CF.Register(RG)
