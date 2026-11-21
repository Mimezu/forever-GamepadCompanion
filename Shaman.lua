-- A shaman's feels (WoW Forever: Horde orcs, tauren, trolls and Windshaper Skyborne; Alliance
-- dwarves). Each spell its own: lightning cracking on the target (Chain Lightning hop by hop),
-- shocks by their element, totems set into the ground by theirs (earth a stone thud, fire
-- embers, water a slosh, air a breath), weapons imbued, Ghost Wolf dropping to all fours,
-- Reincarnation's breath back. docs/SHAMAN-DRUID.md; tests/ShamanCoverage.lua.
-- Rumble's V.CLASS_SPELLS.SHAMAN as V.MAGE: impact (a cast's, at its wound), burst (at the
-- release), move + when (an instant's, at the cast or as it lands), set (a cast's loop),
-- melee (a weapon's blow, timed as a swing), magic (only a magic wound is its).
local _, ns = ...
local V = ns.Rumble
if not V or not V.AddPatterns then return end
local SH = {}
ns.Shaman = SH

local function Pu(t, len, s, side) return { t, len, s, side or 0 } end
-- (key, label, icon art, an ability's (true) or a spell's, pulses)
local function P(key, label, art, move, pulses) return { key = key, label = label, art = art, move = move or nil, pulses = pulses } end

SH.PATTERNS = {
    -- Lightning: a snap at the first moment, a thin crackle running off it
    P("lightning", "Lightning Bolt", "static", false, { Pu(0, 0.05, 0.85), Pu(0.07, 0.05, 0.25, -0.6), Pu(0.13, 0.05, 0.18, 0.6),
        Pu(0.2, 0.05, 0.12, -0.3), Pu(0.28, 0.05, 0.07, 0.4) }),
    -- (each hop to the next enemy a moment later, fainter, the other hand)
    P("chain", "Chain Lightning", "static", false, { Pu(0, 0.05, 0.8), Pu(0.06, 0.05, 0.2, -0.5), Pu(0.16, 0.05, 0.5, 0.7),
        Pu(0.22, 0.05, 0.12, 0.4), Pu(0.32, 0.05, 0.3, -0.7), Pu(0.38, 0.05, 0.08, -0.4) }),
    -- (molten rock: a heavy whoomp, the heat rolling side to side)
    P("lavaBurst", "Lava Burst", "kindle", false, { Pu(0, 0.25, 1), Pu(0.3, 0.05, 0.25, -0.5), Pu(0.38, 0.05, 0.2, 0.5),
        Pu(0.5, 0.08, 0.1) }),
    -- Shocks, by element: stone, flame, frost
    P("earthShock", "Earth Shock", "bash", true, { Pu(0, 0.1, 0.8, -0.2), Pu(0.14, 0.05, 0.2), Pu(0.24, 0.05, 0.08) }),
    P("flameShock", "Flame Shock", "kindle", true, { Pu(0, 0.06, 0.6), Pu(0.1, 0.05, 0.15, -0.4), Pu(0.2, 0.05, 0.1, 0.4),
        Pu(0.32, 0.05, 0.06) }),
    P("frostShock", "Frost Shock", "frost", true, { Pu(0, 0.05, 0.65), Pu(0.08, 0.05, 0.2, -0.7), Pu(0.14, 0.05, 0.15, 0.7),
        Pu(0.3, 0.15, 0.08) }),
    P("moltenBlast", "Molten Blast", "burst", true, { Pu(0, 0.15, 0.75), Pu(0.18, 0.05, 0.25, -0.8), Pu(0.18, 0.05, 0.25, 0.8),
        Pu(0.3, 0.05, 0.1) }),
    -- Weapon strikes: the blow, then the element on it
    P("lavaLash", "Lava Lash", "slash", true, { Pu(0, 0.08, 0.8, -0.3), Pu(0.1, 0.15, 0.18, 0.3), Pu(0.3, 0.05, 0.06) }),
    P("stormstrike", "Stormstrike", "slash", true, { Pu(0, 0.06, 0.6, -0.5), Pu(0.1, 0.06, 0.6, 0.5), Pu(0.2, 0.05, 0.4),
        Pu(0.27, 0.05, 0.12, -0.4), Pu(0.33, 0.05, 0.08, 0.4) }),
    -- (fire bursting out of you to both hands, embers after)
    P("fireNova", "Fire Nova", "burst", true, { Pu(0, 0.2, 0.9, -1), Pu(0, 0.2, 0.9, 1), Pu(0.26, 0.05, 0.2, -0.6),
        Pu(0.34, 0.05, 0.15, 0.6), Pu(0.46, 0.05, 0.07) }),
    -- Totems set down: a thud into the ground, then their element
    P("totemEarth", "Earth totem", "slam", true, { Pu(0, 0.18, 0.85), Pu(0.22, 0.05, 0.12, -0.4), Pu(0.3, 0.05, 0.07, 0.4) }),
    P("totemFire", "Fire totem", "kindle", true, { Pu(0, 0.12, 0.6), Pu(0.16, 0.05, 0.15, -0.5), Pu(0.24, 0.05, 0.12, 0.5),
        Pu(0.34, 0.05, 0.08, -0.2), Pu(0.46, 0.05, 0.05, 0.3) }),
    P("totemWater", "Water totem", "bubble", true, { Pu(0, 0.12, 0.55), Pu(0.18, 0.2, 0.14, -0.4), Pu(0.36, 0.15, 0.08, 0.4) }),
    P("totemAir", "Air totem", "sweep", true, { Pu(0, 0.1, 0.5), Pu(0.14, 0.05, 0.05, -0.6), Pu(0.22, 0.05, 0.08),
        Pu(0.3, 0.2, 0.1, 0.6) }),
    -- (four at once: earth, fire, water, air, hand to hand)
    P("totemCall", "Totems", "slam", true, { Pu(0, 0.12, 0.7, -0.6), Pu(0.18, 0.1, 0.55, -0.2), Pu(0.34, 0.1, 0.5, 0.2),
        Pu(0.5, 0.1, 0.45, 0.6), Pu(0.66, 0.05, 0.1) }),
    P("recall", "Totemic Recall", "rise", true, { Pu(0, 0.05, 0.25, -0.8), Pu(0.1, 0.05, 0.2, 0.8), Pu(0.2, 0.05, 0.15, -0.3),
        Pu(0.3, 0.1, 0.3) }),
    -- Weapons imbued: stone grinding along the blade, a flare, frost creeping, a gust
    P("imbueRock", "Rockbiter", "pickaxe", true, { Pu(0, 0.05, 0.18, -0.4), Pu(0.07, 0.05, 0.2, -0.2), Pu(0.14, 0.05, 0.22),
        Pu(0.21, 0.05, 0.24, 0.2), Pu(0.3, 0.1, 0.35, 0.4) }),
    P("imbueFlame", "Flametongue", "kindle", true, { Pu(0, 0.05, 0.1, -0.5), Pu(0.08, 0.05, 0.2, -0.2), Pu(0.16, 0.15, 0.4, 0.2),
        Pu(0.36, 0.05, 0.08, 0.4) }),
    P("imbueFrost", "Frostbrand", "frost", true, { Pu(0, 0.05, 0.3), Pu(0.1, 0.05, 0.12, -0.6), Pu(0.2, 0.05, 0.1, 0.6),
        Pu(0.32, 0.05, 0.07, -0.3) }),
    P("imbueWind", "Windfury", "sweep", true, { Pu(0, 0.05, 0.08, -0.8), Pu(0.08, 0.05, 0.15, -0.3), Pu(0.16, 0.12, 0.3, 0.3),
        Pu(0.32, 0.05, 0.08, 0.8) }),
    -- (three orbs settling round you: Lightning, Water, Earth Shield)
    P("shieldOrbs", "Shield orbs", "ward", true, { Pu(0, 0.05, 0.18, -0.7), Pu(0.12, 0.05, 0.18, 0.7), Pu(0.24, 0.05, 0.18),
        Pu(0.36, 0.12, 0.12) }),
    -- (down to all fours, the paws finding the ground)
    P("ghostWolf", "Ghost Wolf", "charge", true, { Pu(0, 0.15, 0.5), Pu(0.22, 0.05, 0.18, -0.6), Pu(0.3, 0.05, 0.18, 0.6),
        Pu(0.42, 0.05, 0.12, -0.6), Pu(0.5, 0.05, 0.12, 0.6) }),
    -- (a heartbeat coming back, then breath filling you: Reincarnation, a resurrection)
    P("ankh", "Rebirth", "heart", true, { Pu(0, 0.08, 0.4), Pu(0.18, 0.08, 0.25), Pu(0.6, 0.08, 0.4), Pu(0.78, 0.08, 0.25),
        Pu(1.1, 0.3, 0.6) }),
    P("purge", "Purge", "shock", true, { Pu(0, 0.05, 0.2, -0.5), Pu(0.06, 0.08, 0.5, 0.5), Pu(0.2, 0.05, 0.06) }),
    -- (heals: faint; rain drops scattered, a heal hopping on)
    P("healingRain", "Healing Rain", "mend", false, { Pu(0, 0.05, 0.08, -0.6), Pu(0.11, 0.05, 0.06, 0.5), Pu(0.2, 0.05, 0.07, -0.2),
        Pu(0.31, 0.05, 0.05, 0.8), Pu(0.42, 0.05, 0.06, -0.8), Pu(0.55, 0.05, 0.04, 0.3) }),
    P("chainHeal", "Chain Heal", "mend", false, { Pu(0, 0.1, 0.25), Pu(0.18, 0.1, 0.15, 0.6), Pu(0.36, 0.1, 0.1, -0.6) }),
    -- (two spirit wolves bounding in at your sides)
    P("wolves", "Feral Spirit", "charge", true, { Pu(0, 0.05, 0.2, -0.8), Pu(0.08, 0.05, 0.2, 0.8), Pu(0.2, 0.05, 0.25, -0.8),
        Pu(0.28, 0.05, 0.25, 0.8), Pu(0.42, 0.1, 0.35) }),
}
V.AddPatterns(SH.PATTERNS)

-- Each spell (any rank's ID: every rank by its name)
local function Hit(move, extra)
    local e = { move = move, when = "hit" }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end
local function Cast(move) return { move = move, when = "cast" } end
local SPELLS = {
    -- Lightning, lava: felt where they land
    [403] = { impact = "lightning" }, [421] = { impact = "chain" },
    [408490] = { impact = "lavaBurst" },
    -- Shocks, Molten Blast: as they land, a magic wound only
    [8042] = Hit("earthShock", { magic = true }), [8050] = Hit("flameShock", { magic = true }),
    [8056] = Hit("frostShock", { magic = true }), [425339] = Hit("moltenBlast", { magic = true }),
    -- Weapon strikes: at the weapon's blow
    [408507] = Hit("lavaLash", { melee = true }), [17364] = Hit("stormstrike", { melee = true }),
    [408341] = Cast("fireNova"),
    -- Totems, by element
    [2484] = Cast("totemEarth"), [5730] = Cast("totemEarth"), [8071] = Cast("totemEarth"), [8075] = Cast("totemEarth"),
    [8143] = Cast("totemEarth"), [425874] = Cast("totemEarth"),        -- Earthbind, Stoneclaw, Stoneskin, Strength, Tremor, Decoy
    [3599] = Cast("totemFire"), [8190] = Cast("totemFire"), [8227] = Cast("totemFire"), [8181] = Cast("totemFire"),
                                                                       -- Searing, Magma, Flametongue, Frost Resistance
    [5394] = Cast("totemWater"), [5675] = Cast("totemWater"), [16190] = Cast("totemWater"), [8184] = Cast("totemWater"),
    [8166] = Cast("totemWater"), [8170] = Cast("totemWater"),         -- Healing Stream, Mana Spring, Mana Tide, Fire Resistance,
                                                                       -- Poison and Disease Cleansing
    [8177] = Cast("totemAir"), [8512] = Cast("totemAir"), [8835] = Cast("totemAir"), [10595] = Cast("totemAir"),
    [15107] = Cast("totemAir"), [6495] = Cast("totemAir"),            -- Grounding, Windfury, Grace of Air, Nature Resistance,
                                                                       -- Windwall, Sentry
    [437009] = Cast("totemCall"), [36936] = Cast("recall"),           -- Totemic Call, Totemic Recall
    [66842] = { burst = "totemCall" }, [66843] = { burst = "totemCall" }, [66844] = { burst = "totemCall" }, -- Call of the ...
    -- Weapons
    [8017] = Cast("imbueRock"), [8024] = Cast("imbueFlame"), [8033] = Cast("imbueFrost"), [8232] = Cast("imbueWind"),
    -- Shields
    [324] = Cast("shieldOrbs"), [408510] = Cast("shieldOrbs"), [408514] = Cast("shieldOrbs"),
    -- Ghost Wolf: its cast, then down to all fours (instant with Greater Ghost Wolf)
    [2645] = { burst = "ghostWolf", move = "ghostWolf", when = "cast", shift = true },
    [21169] = Cast("ankh"),                                            -- Reincarnation
    [2008] = { set = "healing", burst = "ankh" },                      -- Ancestral Spirit
    [440580] = Cast("wolves"),                                         -- Feral Spirit
    [370] = { move = "purge", when = "cast", avoidOnly = true },       -- Purge
    [526] = Cast("mend"), [2870] = Cast("mend"),                       -- Cure Poison, Cure Disease
    -- Heals: their faint set; Chain Heal and Healing Rain end with theirs
    [331] = { set = "healing" }, [8004] = { set = "healing" },
    [1064] = { set = "healing", burst = "chainHeal" }, [415236] = { set = "healing", burst = "healingRain" },
    [408521] = Cast("hot"),                                            -- Riptide
    -- Buffs, cooldowns
    [131] = Cast("glow"), [546] = Cast("glow"), [409324] = Cast("glow"), [408696] = Cast("glow"),
                                                                       -- Water Breathing, Water Walking, Ancestral Guidance, Spirit of the Alpha
    [16188] = Cast("empower"), [425336] = Cast("empower"),             -- Nature's Swiftness, Rage of the Farseer
    [6196] = { set = "farsight" }, [556] = { set = "travel" },          -- Far Sight, Astral Recall
}
V.CLASS_SPELLS.SHAMAN = SPELLS
SH.SPELLS = SPELLS

-- Reincarnation's own breath back: the Lab's Alive stays quiet a moment after it
SH.REBORN_QUIET = 3
local rebornAt = -math.huge
function SH.RebornLately() return GetTime and GetTime() - rebornAt < SH.REBORN_QUIET or false end
local frame = CreateFrame("Frame")
SH.frame = frame
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
frame:SetScript("OnEvent", function(_, _, unit, _, spellID)
    if issecretvalue and issecretvalue(spellID) then return end
    if unit == "player" and spellID == 21169 and GetTime then rebornAt = GetTime() end
end)
