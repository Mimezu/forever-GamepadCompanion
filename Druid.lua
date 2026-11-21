-- A druid's feels (WoW Forever: Alliance night elves and High Order Skyborne; Horde tauren and
-- Windshaper Skyborne). Each shape its own body as you take it (a bear's weight dropping into
-- your hands, a cat's ripple, a stag's lunge, a seal's glide, a moonkin's feathered settle, a
-- tree's creak); a cat's claws and bites, its finishers by the points they spend; a bear's
-- swipe sweeping across both hands; moon and sun from above, Hurricane gust by gust,
-- Tranquility breath by breath; heals over time barely there. docs/SHAMAN-DRUID.md;
-- tests/DruidCoverage.lua. As Shaman.lua: Rumble's V.CLASS_SPELLS.DRUID.
local _, ns = ...
local V = ns.Rumble
if not V or not V.AddPatterns then return end
local DR = {}
ns.Druid = DR

local function Pu(t, len, s, side) return { t, len, s, side or 0 } end
local function P(key, label, art, move, pulses) return { key = key, label = label, art = art, move = move or nil, pulses = pulses } end

DR.PATTERNS = {
    -- Shapes taken
    P("bearForm", "Bear Form", "slam", true, { Pu(0, 0.05, 0.15), Pu(0.08, 0.3, 0.85), Pu(0.42, 0.05, 0.15, -0.4),
        Pu(0.5, 0.05, 0.1, 0.4) }),
    P("catForm", "Cat Form", "purr", true, { Pu(0, 0.05, 0.15, -0.6), Pu(0.06, 0.05, 0.2), Pu(0.12, 0.05, 0.25, 0.6),
        Pu(0.24, 0.05, 0.08, -0.3), Pu(0.3, 0.05, 0.08, 0.3) }),
    P("travelForm", "Travel Form", "charge", true, { Pu(0, 0.05, 0.2), Pu(0.08, 0.12, 0.5), Pu(0.32, 0.05, 0.15, -0.5),
        Pu(0.46, 0.05, 0.12, 0.5) }),
    P("aquaticForm", "Aquatic Form", "bubble", true, { Pu(0, 0.15, 0.2, -0.6), Pu(0.12, 0.15, 0.25, 0.6), Pu(0.3, 0.2, 0.12) }),
    P("moonkinForm", "Moonkin Form", "arcane", true, { Pu(0, 0.2, 0.55), Pu(0.26, 0.05, 0.08, -0.5), Pu(0.32, 0.05, 0.08, 0.5),
        Pu(0.4, 0.15, 0.1) }),
    P("treeForm", "Tree of Life", "rise", true, { Pu(0, 0.05, 0.1, -0.4), Pu(0.1, 0.05, 0.12, 0.4), Pu(0.2, 0.05, 0.15, -0.2),
        Pu(0.3, 0.25, 0.5), Pu(0.6, 0.05, 0.08) }),
    -- (back to your own shape, the shape let go: Forms.lua)
    P("unshift", "Own shape", "fade", true, { Pu(0, 0.05, 0.12), Pu(0.1, 0.15, 0.22), Pu(0.3, 0.05, 0.05) }),
    P("prowl", "Prowl", "fade", true, { Pu(0, 0.15, 0.08), Pu(0.2, 0.1, 0.04) }),
    P("dash", "Dash", "charge", true, { Pu(0, 0.05, 0.15, -0.4), Pu(0.07, 0.05, 0.25, 0.4), Pu(0.14, 0.12, 0.45) }),
    -- A cat's claws and teeth
    P("claw", "Claw", "rend", true, { Pu(0, 0.05, 0.45, -0.5), Pu(0.08, 0.05, 0.35, 0.5) }),
    P("shred", "Shred", "rend", true, { Pu(0, 0.05, 0.4, -0.6), Pu(0.06, 0.05, 0.5, -0.2), Pu(0.12, 0.05, 0.55, 0.2),
        Pu(0.18, 0.08, 0.4, 0.6) }),
    P("rake", "Rake", "rend", true, { Pu(0, 0.05, 0.5, 0.3), Pu(0.2, 0.05, 0.06), Pu(0.4, 0.05, 0.04) }),
    P("ravage", "Ravage", "charge", true, { Pu(0, 0.05, 0.2), Pu(0.08, 0.15, 0.9), Pu(0.26, 0.05, 0.3, -0.5),
        Pu(0.32, 0.05, 0.3, 0.5) }),
    -- (finishers: their strength by the points spent)
    P("bite", "Ferocious Bite", "stab", true, { Pu(0, 0.05, 0.3, -0.7), Pu(0, 0.05, 0.3, 0.7), Pu(0.07, 0.12, 1),
        Pu(0.24, 0.05, 0.2) }),
    P("rip", "Rip", "rend", true, { Pu(0, 0.05, 0.5, -0.4), Pu(0.07, 0.08, 0.7, 0.4), Pu(0.3, 0.05, 0.08), Pu(0.6, 0.05, 0.06),
        Pu(0.9, 0.05, 0.04) }),
    P("savageRoar", "Savage Roar", "shadow", true, { Pu(0, 0.05, 0.15), Pu(0.08, 0.25, 0.6), Pu(0.36, 0.1, 0.15) }),
    P("pounce", "Pounce", "bash", true, { Pu(0, 0.05, 0.15), Pu(0.08, 0.2, 0.95), Pu(0.32, 0.05, 0.12) }),
    P("fury", "Fury", "rise", true, { Pu(0, 0.05, 0.1), Pu(0.1, 0.2, 0.35), Pu(0.34, 0.15, 0.5), Pu(0.52, 0.05, 0.1) }),
    P("cower", "Cower", "fade", true, { Pu(0, 0.1, 0.12), Pu(0.15, 0.05, 0.04) }),
    -- A bear's paws and jaws
    P("primalBite", "Primal Bite", "stab", true, { Pu(0, 0.08, 0.4), Pu(0.1, 0.15, 0.9), Pu(0.3, 0.05, 0.15) }),
    P("maul", "Maul", "slam", true, { Pu(0, 0.05, 0.2), Pu(0.06, 0.2, 1), Pu(0.3, 0.05, 0.2) }),
    -- (one wide arc from left to right, the claws catching hide after hide)
    P("swipe", "Swipe", "cleave", true, { Pu(0, 0.05, 0.3, -1), Pu(0.06, 0.05, 0.55, -0.6), Pu(0.12, 0.05, 0.5, -0.1),
        Pu(0.18, 0.05, 0.5, 0.4), Pu(0.24, 0.05, 0.45, 0.9), Pu(0.32, 0.05, 0.12, 1) }),
    P("roarBear", "Roar", "burst", true, { Pu(0, 0.05, 0.25, -1), Pu(0, 0.05, 0.25, 1), Pu(0.06, 0.4, 0.75), Pu(0.5, 0.05, 0.12) }),
    P("growl", "Growl", "shadow", true, { Pu(0, 0.2, 0.3), Pu(0.24, 0.05, 0.06) }),
    P("lacerate", "Lacerate", "rend", true, { Pu(0, 0.05, 0.35, -0.4), Pu(0.08, 0.05, 0.25, 0.4), Pu(0.25, 0.05, 0.05) }),
    -- Moon, sun, stars
    P("moonfire", "Moonfire", "judge", true, { Pu(0, 0.05, 0.12), Pu(0.06, 0.1, 0.65), Pu(0.2, 0.05, 0.12, -0.3),
        Pu(0.3, 0.05, 0.08, 0.3) }),
    P("sunfire", "Sunfire", "kindle", true, { Pu(0, 0.08, 0.6), Pu(0.12, 0.05, 0.15), Pu(0.24, 0.05, 0.08) }),
    P("starfire", "Starfire", "impact", false, { Pu(0, 0.25, 0.95), Pu(0.3, 0.05, 0.25, -0.4), Pu(0.4, 0.05, 0.18, 0.4),
        Pu(0.55, 0.08, 0.08) }),
    P("wrath", "Wrath", "static", false, { Pu(0, 0.06, 0.65, 0.2), Pu(0.08, 0.05, 0.15, -0.3), Pu(0.16, 0.05, 0.08, 0.3) }),
    P("starsurge", "Starsurge", "judge", true, { Pu(0, 0.05, 0.2), Pu(0.06, 0.12, 0.8), Pu(0.24, 0.05, 0.2, -0.5),
        Pu(0.3, 0.05, 0.15, 0.5) }),
    P("starfall", "Starfall", "arcane", true, { Pu(0, 0.05, 0.3, -0.6), Pu(0.12, 0.05, 0.25, 0.5), Pu(0.24, 0.05, 0.2, -0.2),
        Pu(0.38, 0.05, 0.18, 0.8), Pu(0.5, 0.05, 0.12, -0.8), Pu(0.64, 0.05, 0.08, 0.3) }),
    -- (a gust sweeping across you, debris knocking after it: each of Hurricane's ticks)
    P("hurricane", "Hurricane", "sweep", false, { Pu(0, 0.05, 0.06, -0.8), Pu(0.08, 0.12, 0.2, -0.3), Pu(0.24, 0.12, 0.22, 0.3),
        Pu(0.42, 0.05, 0.12, 0.8), Pu(0.55, 0.05, 0.07, -0.5), Pu(0.7, 0.05, 0.05, 0.5) }),
    P("swarm", "Insect Swarm", "hex", true, { Pu(0, 0.05, 0.06, -0.4), Pu(0.07, 0.05, 0.07, 0.4), Pu(0.14, 0.05, 0.06, -0.2),
        Pu(0.21, 0.05, 0.05, 0.2) }),
    P("faerie", "Faerie Fire", "shimmer", true, { Pu(0, 0.05, 0.08, -0.3), Pu(0.1, 0.05, 0.06, 0.3) }),
    -- (roots creaking up and gripping)
    P("roots", "Roots", "rise", true, { Pu(0, 0.05, 0.12, -0.3), Pu(0.1, 0.05, 0.18, 0.3), Pu(0.2, 0.05, 0.25),
        Pu(0.3, 0.15, 0.45), Pu(0.5, 0.05, 0.1) }),
    P("sleep", "Slumber", "fade", true, { Pu(0, 0.2, 0.12), Pu(0.3, 0.2, 0.06) }),
    P("bark", "Barkskin", "ward", true, { Pu(0, 0.05, 0.15, -0.4), Pu(0.08, 0.05, 0.18, 0.4), Pu(0.16, 0.2, 0.4) }),
    P("thorns", "Thorns", "hex", true, { Pu(0, 0.05, 0.1, -0.6), Pu(0.06, 0.05, 0.12, 0.6), Pu(0.12, 0.05, 0.1, -0.2),
        Pu(0.18, 0.05, 0.12, 0.2) }),
    P("innervate", "Innervate", "rise", true, { Pu(0, 0.05, 0.06), Pu(0.12, 0.05, 0.12), Pu(0.24, 0.05, 0.2),
        Pu(0.36, 0.2, 0.3) }),
    -- Heals over time: barely there; Swiftmend a quick bloom; Tranquility breath by breath
    P("hot", "Over time", "mend", true, { Pu(0, 0.15, 0.08), Pu(0.2, 0.05, 0.04) }),
    P("bloom", "Swiftmend", "mend", true, { Pu(0, 0.05, 0.1), Pu(0.08, 0.15, 0.25) }),
    P("tranquility", "Tranquility", "mend", false, { Pu(0, 0.2, 0.12, -0.5), Pu(0.1, 0.2, 0.12, 0.5), Pu(0.4, 0.1, 0.05) }),
    -- Swings in a shape: a cat's quick rake, a bear's paw (Forms.lua)
    { key = "swClaw", label = "Claws", art = "rend", swing = true, pulses = { Pu(0, 0.05, 0.12, -0.3), Pu(0.05, 0.05, 0.08, 0.3) } },
    { key = "swPaw", label = "Paw", art = "slam", swing = true, pulses = { Pu(0, 0.12, 0.4) } },
}
V.AddPatterns(DR.PATTERNS)

-- A finisher's strength: the points it spent (ComboPoints.lua)
local function Points() return ns.Combo and ns.Combo.Scale() or 1 end
DR.Points = Points

local function With(e, extra)
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end
local function Hit(move, extra) return With({ move = move, when = "hit" }, extra) end
local function Cast(move, extra) return With({ move = move, when = "cast" }, extra) end
local MELEE = { melee = true }
local SPELLS = {
    -- Shapes (their own body as you take them; Forms.lua the rest)
    [5487] = Cast("bearForm", { shift = true }), [9634] = Cast("bearForm", { shift = true }),
    [768] = Cast("catForm", { shift = true }), [783] = Cast("travelForm", { shift = true }),
    [1066] = Cast("aquaticForm", { shift = true }), [24858] = Cast("moonkinForm", { shift = true }),
    [439733] = Cast("treeForm", { shift = true }),
    [5215] = Cast("prowl"), [1850] = Cast("dash"),
    -- Cat
    [1082] = Hit("claw", MELEE), [5221] = Hit("shred", MELEE), [1822] = Hit("rake", MELEE), [6785] = Hit("ravage", MELEE),
    [22568] = Hit("bite", { melee = true, scale = Points }),             -- Ferocious Bite
    [1079] = Cast("rip", { scale = Points, avoidOnly = true }),          -- Rip: a bleed opened, at the cast
    [407988] = Cast("savageRoar", { scale = Points }),
    [9005] = Cast("pounce", { avoidOnly = true }),
    [5217] = Cast("fury"), [8998] = Cast("cower"), [417141] = Cast("empower"), -- Tiger's Fury, Cower, Berserk
    [1238122] = Cast("charge"), [16979] = Cast("charge"), [410176] = Cast("charge", { avoidOnly = true }),
                                                                       -- Feral Charge (cat, bear), Skull Bash
    -- Bear
    [407995] = Hit("primalBite", MELEE), [6807] = Hit("maul", MELEE), [769] = Hit("swipe", MELEE),
    [99] = Cast("roarBear"), [5209] = Cast("roarBear"), [6795] = Cast("growl"),
    [5211] = Cast("bash", { avoidOnly = true }), [414644] = Cast("lacerate", { avoidOnly = true }),
    [5229] = Cast("fury"), [22842] = Cast("fury"), [408024] = Cast("ward"), [1322605] = Cast("empower"),
                                                                       -- Enrage, Frenzied Regeneration, Survival Instincts, Shifting Power
    -- Balance
    [8921] = Hit("moonfire", { magic = true }), [414684] = Hit("sunfire", { magic = true }),
    [417157] = Hit("starsurge", { magic = true }),
    [2912] = { impact = "starfire" }, [5176] = { impact = "wrath" },
    [16914] = { tick = "hurricane", ticks = 10 }, [439748] = Cast("starfall"),
    [5570] = Cast("swarm", { avoidOnly = true }), [770] = Cast("faerie", { avoidOnly = true }),
    [339] = { burst = "roots" }, [16689] = Cast("roots"),             -- Entangling Roots, Nature's Grasp
    [2637] = { burst = "sleep" }, [2908] = { burst = "sleep" },       -- Hibernate, Soothe Animal
    [22812] = Cast("bark"), [467] = Cast("thorns"), [29166] = Cast("innervate"),
    [18960] = { set = "travel" },                                     -- Teleport: Moonglade
    [5225] = Cast("micro"),                                           -- Track Humanoids
    -- Restoration
    [5185] = { set = "healing" }, [8936] = { set = "healing" }, [408247] = { set = "healing" }, [408120] = { set = "healing" },
    [774] = Cast("hot"), [408124] = Cast("hot"), [414683] = Cast("hot"), [417148] = Cast("hot"),
                                                                       -- Rejuvenation, Lifebloom, Living Seed, Efflorescence
    [18562] = Cast("bloom"), [740] = { tick = "tranquility", ticks = 5 },
    [20484] = { set = "healing", burst = "ankh" }, [437138] = { set = "healing", burst = "ankh" }, -- Rebirth, Revive
    [1126] = Cast("glow"), [21849] = Cast("glow"),                    -- Mark, Gift of the Wild
    [2782] = Cast("mend"), [8946] = Cast("mend"), [2893] = Cast("mend"), -- Remove Curse, Cure, Abolish Poison
    [17116] = Cast("empower"),                                        -- Nature's Swiftness
}
V.CLASS_SPELLS.DRUID = SPELLS
DR.SPELLS = SPELLS
