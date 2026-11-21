-- A warlock's feels: what each warlock spell plays (docs/PRIEST-WARLOCK.md), each demon's
-- arrival, a Soul Shard gained. Rumble's V.SpellRule asks the table here through V.MageOf
-- (ClassSpells.lua); the patterns join Rumble's. The demon's own moments are the Pet group's
-- (Hunter.lua): its blows and the blows on it off by default, as for every pet.
-- tests/PriestWarlock.lua lists every warlock spell of the client and what it plays.
local _, ns = ...
local CS, V = ns.ClassSpells, ns.Rumble
local Pu = CS.Pu
local WL = {}
ns.Warlock = WL

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- The patterns. Shadow: dark thumps and drags; fire: whoomps and crackle; a DoT's curse faint
-- (its ticks: the Lab's DoT ticks, off); each demon its own weight as it steps out.
---------------------------------------------------------------------------
WL.PATTERNS = {
    -- (bolts: felt where they land, after the flight)
    { key = "shadowBolt", label = "Shadow Bolt", art = "shadow",   -- a dark thump, shadow bursting and smoking off
        pulses = { Pu(0, 0.12, 0.75), Pu(0.15, 0.05, 0.2, -0.5), Pu(0.25, 0.05, 0.12, 0.5), Pu(0.38, 0.05, 0.06) } },
    { key = "soulFire", label = "Soul Fire", art = "kindle",       -- a great fireball: a deep whoomp, fire roaring on
        pulses = { Pu(0, 0.25, 1), Pu(0.32, 0.05, 0.25, -0.5), Pu(0.42, 0.05, 0.2, 0.5), Pu(0.55, 0.05, 0.12, -0.3),
            Pu(0.7, 0.05, 0.08, 0.3) } },
    { key = "incinerate", label = "Incinerate", art = "kindle",    -- a hard burst of fire, crackling
        pulses = { Pu(0, 0.12, 0.7), Pu(0.16, 0.05, 0.18, -0.5), Pu(0.24, 0.05, 0.14, 0.5) } },
    { key = "chaosBolt", label = "Chaos Bolt", art = "slam",       -- chaos breaking: a crushing blow, the air torn
        pulses = { Pu(0, 0.06, 0.5, -0.4), Pu(0.04, 0.25, 1), Pu(0.35, 0.05, 0.3, 0.6), Pu(0.45, 0.05, 0.2, -0.6),
            Pu(0.6, 0.05, 0.1) } },
    { key = "haunt", label = "Haunt", art = "fade",                -- a ghost slips in: a soft hit, a chill crawling
        pulses = { Pu(0, 0.1, 0.5), Pu(0.18, 0.05, 0.1, -0.6), Pu(0.32, 0.05, 0.08, 0.6), Pu(0.48, 0.05, 0.05, -0.3) } },
    -- (casts at their release: no flight)
    { key = "immolate", label = "Immolate", art = "kindle",        -- flames erupting on them, then burning
        pulses = { Pu(0, 0.05, 0.35), Pu(0.05, 0.12, 0.6), Pu(0.25, 0.05, 0.12, -0.4), Pu(0.38, 0.05, 0.1, 0.4),
            Pu(0.52, 0.05, 0.06) } },
    { key = "searingPain", label = "Searing Pain", art = "kindle", -- a sharp sear, hot and quick
        pulses = { Pu(0, 0.05, 0.5, 0.3), Pu(0.06, 0.08, 0.3, 0.3), Pu(0.2, 0.05, 0.08) } },
    { key = "shadowflame", label = "Shadowflame", art = "slam",    -- a cone of dark flame roaring out ahead
        pulses = { Pu(0, 0.05, 0.2), Pu(0.05, 0.25, 0.6), Pu(0.35, 0.05, 0.15, -0.5), Pu(0.43, 0.05, 0.12, 0.5) } },
    { key = "fear", label = "Fear", art = "fade",                  -- a cold shove, then them fleeing: a fading tremor
        pulses = { Pu(0, 0.1, 0.55), Pu(0.15, 0.05, 0.12, 0.6), Pu(0.25, 0.05, 0.09, 0.8), Pu(0.35, 0.05, 0.06, 1) } },
    { key = "banish", label = "Banish", art = "fade",              -- drawn out of this world: a pull away, then gone
        pulses = { Pu(0, 0.15, 0.4), Pu(0.2, 0.1, 0.15), Pu(0.38, 0.05, 0.05) } },
    { key = "subjugate", label = "Subjugate", art = "latch",       -- a chain snapping tight
        pulses = { Pu(0, 0.05, 0.2, -0.5), Pu(0.08, 0.1, 0.55, 0.3), Pu(0.25, 0.05, 0.1) } },
    { key = "affliction", label = "Affliction", art = "hex", move = true, -- a curse settling in: a faint shiver
        pulses = { Pu(0, 0.05, 0.12, -0.4), Pu(0.12, 0.05, 0.07, 0.4), Pu(0.26, 0.05, 0.04, -0.4) } },
    { key = "corruption", label = "Corruption", art = "hex", move = true, -- rot set in: a faint slow creep
        pulses = { Pu(0, 0.08, 0.1), Pu(0.2, 0.05, 0.06, -0.4), Pu(0.4, 0.05, 0.04, -0.4) } },
    -- (stones: grit gathering while it forms, a solid clack in the palm when made)
    { key = "stoneForm", label = "Stone forming", art = "pluck",
        pulses = { cycle = 1, Pu(0, 0.05, 0.06, -0.4), Pu(0.2, 0.05, 0.04, 0.4), Pu(0.5, 0.08, 0.12), Pu(0.75, 0.05, 0.04, -0.2) } },
    { key = "stone", label = "Stone", art = "click", move = true,
        pulses = { Pu(0, 0.08, 0.45), Pu(0.12, 0.05, 0.1) } },
    -- (summons: a circle drawn while it lasts, a low hum, a rune flaring; each demon's own arrival)
    { key = "summonCircle", label = "Summoning circle", art = "ritual",
        pulses = { cycle = 1.2, Pu(0, 0.2, 0.08, -0.5), Pu(0.6, 0.2, 0.08, 0.5), Pu(0.95, 0.05, 0.14) } },
    { key = "imp", label = "Imp", art = "kindle",                  -- an imp pops out: a small quick crackle
        pulses = { Pu(0, 0.05, 0.3, 0.4), Pu(0.07, 0.05, 0.18, -0.3), Pu(0.13, 0.05, 0.12, 0.5) } },
    { key = "voidwalker", label = "Voidwalker", art = "shadow",    -- a voidwalker rises: deep, slow, heavy
        pulses = { Pu(0, 0.35, 0.6), Pu(0.45, 0.15, 0.3), Pu(0.7, 0.05, 0.08) } },
    { key = "succubus", label = "Succubus", art = "whirl",         -- she steps out: a whip's crack
        pulses = { Pu(0, 0.05, 0.15, -0.6), Pu(0.12, 0.05, 0.65, 0.6), Pu(0.2, 0.05, 0.12, 0.6) } },
    { key = "felhunter", label = "Felhunter", art = "charge",      -- a felhunter lands: a pounce, a snarl
        pulses = { Pu(0, 0.12, 0.55), Pu(0.2, 0.05, 0.12, -0.4), Pu(0.27, 0.05, 0.12, 0.4), Pu(0.34, 0.05, 0.08, -0.4) } },
    { key = "felguard", label = "Felguard", art = "slam",          -- a heavy stomp, an axe set down
        pulses = { Pu(0, 0.2, 0.85), Pu(0.32, 0.08, 0.35, 0.4), Pu(0.5, 0.05, 0.08) } },
    { key = "infernal", label = "Infernal", art = "slam",          -- falling from the sky: a whistle, the crash, the ground shaking
        pulses = { Pu(0, 0.05, 0.05), Pu(0.15, 0.05, 0.1), Pu(0.3, 0.05, 0.18), Pu(0.42, 0.3, 1), Pu(0.8, 0.05, 0.3, -1),
            Pu(0.8, 0.05, 0.3, 1), Pu(0.95, 0.05, 0.15, -1), Pu(1, 0.05, 0.15, 1), Pu(1.15, 0.05, 0.06) } },
    -- (channels: one feel per tick)
    { key = "drainLife", label = "Drain Life", art = "draw",       -- life pulled from them into you, across, warm
        pulses = { Pu(0, 0.05, 0.12, 0.7), Pu(0.08, 0.05, 0.14, 0.2), Pu(0.16, 0.1, 0.2, -0.4) } },
    { key = "drainMana", label = "Drain Mana", art = "draw",       -- a thin pull, fizzing
        pulses = { Pu(0, 0.05, 0.08, 0.6), Pu(0.07, 0.05, 0.1), Pu(0.14, 0.05, 0.12, -0.6) } },
    { key = "drainSoul", label = "Drain Soul", art = "draw",       -- the soul pulled, slow and deep
        pulses = { Pu(0, 0.1, 0.1, 0.6), Pu(0.15, 0.15, 0.2), Pu(0.35, 0.1, 0.25, -0.6) } },
    { key = "funnel", label = "Health Funnel", art = "mend",       -- health pushed out to your demon, faint
        pulses = { Pu(0, 0.08, 0.12, -0.6), Pu(0.12, 0.05, 0.07, 0.6) } },
    { key = "hellfire", label = "Hellfire", art = "kindle",        -- heat bursting round you, uneven, both hands
        pulses = { Pu(0, 0.05, 0.25, -0.6), Pu(0.1, 0.05, 0.18, 0.7), Pu(0.22, 0.05, 0.22, -0.2), Pu(0.36, 0.05, 0.15, 0.4),
            Pu(0.5, 0.05, 0.12, -0.8), Pu(0.66, 0.05, 0.18, 0.9), Pu(0.8, 0.05, 0.1, -0.4) } },
    { key = "rainOfFire", label = "Rain of Fire", art = "slam",    -- meteors around the target: scattered thuds, the ground burning
        pulses = { Pu(0, 0.08, 0.45, -0.6), Pu(0.25, 0.08, 0.38, 0.7), Pu(0.55, 0.08, 0.42, -0.2), Pu(0.85, 0.08, 0.3, 0.5),
            Pu(1.15, 0.08, 0.25, -0.8), Pu(1.4, 0.05, 0.12, 0.3) } },
    { key = "wrack", label = "Wrack", art = "rend",                -- a twist of pain, hand to hand
        pulses = { Pu(0, 0.08, 0.3, -0.4), Pu(0.1, 0.08, 0.2, 0.4) } },
    -- (instants at the target)
    { key = "deathCoil", label = "Death Coil", art = "shadow", move = true, -- a dark hit, then life flowing back to you
        pulses = { Pu(0, 0.1, 0.7), Pu(0.18, 0.05, 0.12, 0.6), Pu(0.28, 0.05, 0.12), Pu(0.38, 0.1, 0.2, -0.6) } },
    { key = "shadowburn", label = "Shadowburn", art = "shock", move = true, -- a hard pop of shadowflame, smouldering
        pulses = { Pu(0, 0.08, 0.75), Pu(0.12, 0.05, 0.2), Pu(0.26, 0.05, 0.08, -0.4) } },
    { key = "conflagrate", label = "Conflagrate", art = "kindle", move = true, -- the fire flaring up: a whoosh, a roar
        pulses = { Pu(0, 0.05, 0.25), Pu(0.05, 0.18, 0.8), Pu(0.3, 0.05, 0.18, -0.5), Pu(0.38, 0.05, 0.12, 0.5) } },
    { key = "shadowCleave", label = "Shadow Cleave", art = "cleave", move = true, -- a claw of shadow swept across
        pulses = { Pu(0, 0.1, 0.7, -1), Pu(0.12, 0.05, 0.3), Pu(0.2, 0.1, 0.7, 1) } },
    { key = "curse", label = "Curse", art = "hex", move = true,   -- a word of malice: a faint dark tug
        pulses = { Pu(0, 0.05, 0.1, -0.5), Pu(0.14, 0.08, 0.06, -0.5) } },
    { key = "howl", label = "Howl", art = "burst", move = true,    -- a howl round you, both hands shaking out
        pulses = { Pu(0, 0.2, 0.8), Pu(0.25, 0.05, 0.25, -1), Pu(0.25, 0.05, 0.25, 1), Pu(0.38, 0.05, 0.15, -1),
            Pu(0.38, 0.05, 0.15, 1), Pu(0.52, 0.05, 0.06) } },
    -- (at the cast: yourself)
    { key = "felArmor", label = "Demon armor", art = "seal", move = true, -- a hot dark weight settling on your shoulders
        pulses = { Pu(0, 0.15, 0.2, -0.4), Pu(0.18, 0.15, 0.2, 0.4), Pu(0.42, 0.05, 0.08) } },
    { key = "sacrifice", label = "Demonic Sacrifice", art = "ritual", move = true, -- your demon given up, its power poured into you
        pulses = { Pu(0, 0.12, 0.6), Pu(0.2, 0.05, 0.1), Pu(0.32, 0.05, 0.15), Pu(0.44, 0.2, 0.35) } },
    { key = "metamorphosis", label = "Metamorphosis", art = "rise", move = true, -- becoming the demon: a deep heavy swell
        pulses = { Pu(0, 0.05, 0.1), Pu(0.1, 0.05, 0.2), Pu(0.2, 0.4, 0.75), Pu(0.7, 0.12, 0.3), Pu(0.92, 0.05, 0.1) } },
    { key = "immolationAura", label = "Immolation Aura", art = "kindle", move = true, -- fire flaring round you, hot
        pulses = { Pu(0, 0.12, 0.45, -1), Pu(0, 0.12, 0.45, 1), Pu(0.18, 0.05, 0.18, -0.6), Pu(0.26, 0.05, 0.18, 0.6),
            Pu(0.4, 0.05, 0.08) } },
    { key = "healthstone", label = "Healthstone", art = "mend", move = true, -- a stone crushed in the hand, warmth flooding in
        pulses = { Pu(0, 0.05, 0.45, 0.3), Pu(0.08, 0.05, 0.15, 0.3), Pu(0.2, 0.25, 0.35) } },
    -- (the Lab's Soul Shard: a soul caught, a small cold drop into your bag)
    { key = "soulShard", label = "Soul Shard", art = "double", group = "Combat",
        pulses = { Pu(0, 0.05, 0.12, 0.5), Pu(0.12, 0.05, 0.3, -0.3), Pu(0.22, 0.05, 0.06, -0.3) } },
}
if V and V.AddPatterns then V.AddPatterns(WL.PATTERNS) end

-- The demons: each summon's arrival (by the summon's first rank)
WL.DEMONS = { [688] = "imp", [445459] = "imp", [697] = "voidwalker", [712] = "succubus", [713] = "succubus",
    [691] = "felhunter", [427733] = "felguard" }

---------------------------------------------------------------------------
-- What each warlock spell plays (the first rank's ID: every rank by its name). Engraving a rune:
-- Enchanting's shimmer. Healthstones, Spellstone and Soulstone: anyone's who uses one.
---------------------------------------------------------------------------
local FARSIGHT = { set = "farsight" }
WL.RULES = {
    -- Bolts, as they land
    { { impact = "shadowBolt" }, { 686 } },
    { { impact = "soulFire" }, { 6353 } },
    { { impact = "incinerate" }, { 412758 } },
    { { impact = "chaosBolt" }, { 403629 } },
    { { impact = "haunt" }, { 403501 } },
    -- Casts at their release
    { { burst = "immolate" }, { 348 } },
    { { burst = "searingPain" }, { 5676 } },
    { { burst = "shadowflame" }, { 426320 } },
    { { burst = "fear" }, { 5782 } },
    { { burst = "howl" }, { 5484 } },                             -- Howl of Terror
    { { burst = "banish" }, { 710 } },
    { { burst = "subjugate" }, { 1098 } },
    { { burst = "affliction" }, { 427717 } },                     -- Unstable Affliction
    { { burst = "corruption", move = "corruption", when = "cast" }, { 172 } }, -- (instant with its talent)
    { { burst = "infernal" }, { 1122 } },                         -- Inferno
    -- Summons: the circle, then the demon
    { { set = "feel:summonCircle", burst = "imp" }, { 688, 445459 } },  -- Imp, Explorer Imp (Forever)
    { { set = "feel:summonCircle", burst = "voidwalker" }, { 697 } },
    { { set = "feel:summonCircle", burst = "succubus" }, { 712, 713 } }, -- Succubus, Incubus
    { { set = "feel:summonCircle", burst = "felhunter" }, { 691 } },
    { { set = "feel:summonCircle", burst = "felguard" }, { 427733 } },
    { { set = "feel:summonCircle" }, { 698, 18540, 437169 } },     -- Ritual of Summoning, of Doom; Portal of Summoning
    { FARSIGHT, { 126 } },                                         -- Eye of Kilrogg
    -- Stones made
    { { set = "feel:stoneForm", burst = "stone" }, { 6201, 693, 2362, 17727, 6366 } },
    -- Channels, per tick (Drain Life, Mana 5 over 5 s; Drain Soul 5 over 15 s; Health Funnel 10 over
    -- 10 s; Hellfire 15 over 15 s; Rain of Fire 4 over 8 s; Wrack 6 over 6 s)
    { { tick = "drainLife", ticks = 5 }, { 689 } },
    { { tick = "drainMana", ticks = 5 }, { 5138 } },
    { { tick = "drainSoul", ticks = 5 }, { 1120 } },
    { { tick = "funnel", ticks = 10 }, { 755 } },
    { { tick = "hellfire", ticks = 15, alternate = true }, { 1949 } },
    { { tick = "rainOfFire", ticks = 4, alternate = true }, { 5740 } },
    { { tick = "wrack", ticks = 6, alternate = true }, { 1316697 } },
    -- At the target
    { { move = "deathCoil", when = "hit" }, { 6789 } },
    { { move = "shadowburn", when = "hit" }, { 17877, 426241 } }, -- Shadowburn, Invocation
    { { move = "conflagrate", when = "hit" }, { 1293817 } },
    { { move = "shadowCleave", when = "hit" }, { 403835 } },
    -- Curses and banes, Siphon Life: faint
    { { move = "curse", when = "cast" }, { 980, 603, 1225228, 18223, 1010, 704, 1714, 702, 440892 } },
    { { move = "affliction", when = "cast" }, { 18265 } },
    -- Around you; Metamorphosis' own
    { { move = "howl", when = "cast" }, { 412789 } },             -- Demonic Howl
    { { move = "charge", when = "cast" }, { 412788 } },           -- Demon Charge
    { { move = "roar", when = "cast" }, { 403828 } },             -- Menace
    { { move = "immolationAura", when = "cast" }, { 427726 } },
    -- At the cast: yourself
    { { move = "lifeTap", when = "cast" }, { 1454 } },
    { { move = "felArmor", when = "cast" }, { 706, 687, 403619, 440882 } }, -- Demon Armor, Skin; Fel, Infernal Armor
    { { move = "ward", when = "cast" }, { 6229 } },               -- Shadow Ward
    { { move = "sacrifice", when = "cast" }, { 18788 } },
    { { move = "metamorphosis", when = "cast" }, { 403789 } },
    { { move = "empower", when = "cast" }, { 18288, 18708, 425463, 426195 } }, -- Amplify Curse, Fel Domination, Demonic Grace, Vengeance
    { { move = "glow", when = "cast" }, { 5697, 132, 5500, 19028 } }, -- Unending Breath, Detect Invisibility, Sense Demons, Soul Link
    -- Anyone's: a Healthstone eaten, a Spellstone's ward, a Soulstone set on someone
    { { move = "healthstone", when = "cast" }, { 6262, 6263, 5720, 5723, 11732 }, any = true },
    { { move = "ward", when = "cast" }, { 128 }, any = true },
    { { burst = "stone" }, { 20707 }, any = true },
}
WL.Of = CS.Register("WARLOCK", WL.RULES)

-- Your DoTs (their ticks: the Lab's DoT ticks), by school
CS.AddDots("WARLOCK", { [172] = 32, [980] = 32, [603] = 32, [18265] = 32, [427717] = 32, [348] = 4, [426320] = 36 })

---------------------------------------------------------------------------
-- Your demon: its arrival is the summon's own feel, at the release; Pet arrives, Pet leaves and
-- Pet dies (Hunter.lua) stay quiet while you summon, a moment after, and on Demonic Sacrifice
---------------------------------------------------------------------------
WL.QUIET_AFTER = 3
local quietUntil = 0
local summoning = false
function WL.QuietPet()
    return summoning or Now() < quietUntil
end
local function Demon(spellID)
    if not spellID or secret(spellID) then return nil end
    local m = WL.Of(spellID)
    if not m then return nil end
    for _, key in pairs(WL.DEMONS) do if m.burst == key then return key end end
    return nil
end
WL.Demon = Demon
local SACRIFICE = 18788

---------------------------------------------------------------------------
-- Soul Shards: one more in your bags, a soul caught (the Lab's Soul Shard)
---------------------------------------------------------------------------
WL.SHARD = 6265
local shards
local function ShardCount()
    local get = C_Item and C_Item.GetItemCount
    local n = CS.call(get, WL.SHARD)
    return type(n) == "number" and n or nil
end
function WL.BagsChanged()
    if CS.PlayerClass() ~= "WARLOCK" then return end
    local n = ShardCount()
    if not n then return end
    if shards and n > shards then
        local L = ns.HapticsLab
        if L and L.Fire and L.EVENT and L.EVENT.soulShard then L.Fire("soulShard") end
    end
    shards = n
end

local frame = CreateFrame("Frame")
WL.frame = frame
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_STOP" }) do
    if not pcall(frame.RegisterUnitEvent, frame, e, "player") then pcall(frame.RegisterEvent, frame, e) end
end
pcall(frame.RegisterEvent, frame, "BAG_UPDATE_DELAYED")
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
local handlers = {}
handlers.UNIT_SPELLCAST_START = function(unit, _, spellID)
    if unit == "player" and Demon(spellID) then summoning = true end
end
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    if unit ~= "player" or not spellID or secret(spellID) then return end
    if Demon(spellID) or spellID == SACRIFICE or CS.SpellName(spellID) == CS.SpellName(SACRIFICE) then
        summoning, quietUntil = false, Now() + WL.QUIET_AFTER
    end
end
handlers.UNIT_SPELLCAST_INTERRUPTED = function(unit) if unit == "player" then summoning = false end end
handlers.UNIT_SPELLCAST_FAILED = handlers.UNIT_SPELLCAST_INTERRUPTED
-- (a cast stopped some other way; after a summon done, its quiet moment already set)
handlers.UNIT_SPELLCAST_STOP = handlers.UNIT_SPELLCAST_INTERRUPTED
handlers.BAG_UPDATE_DELAYED = function() WL.BagsChanged() end
-- (the bags as you come into the world: counted, not felt)
handlers.PLAYER_ENTERING_WORLD = function() shards = nil; WL.BagsChanged() end
WL.handlers = handlers
frame:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
