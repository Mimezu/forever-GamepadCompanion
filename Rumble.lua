-- Controller vibration on game events, adapted from Easy Controller -
-- Forever's Vibration module (moust4ki, MIT License, see
-- LICENSE-EasyController.md): its patterns, played on the two
-- standard motors at one strength for all. Three events: you level up, you
-- land a critical hit (damage or heal), you take one; ours: you start a
-- melee auto attack, you jump; casts, matched to
-- what they are (fire, Hearthstone, mining, tailoring...); eating and
-- drinking, while you sit with food or a drink. Each has a pattern of
-- its own, or none, grouped as Easy Controller does (Combat, Progress). Set
-- in the Vibration tab (VibeEditor.lua); on / off
-- and strength in the Vibration tab (Settings).
--
-- Ported into Gamepad Companion from Improved Forever: Vibration 0.6.3
-- (markg, MIT License: licenses/ImprovedForever_Vibration-LICENSE.txt), itself
-- adapted from Easy Controller - Forever (moust4ki, MIT License:
-- licenses/EasyController-LICENSE.md). Icons from Improved Forever (MIT:
-- licenses/ImprovedForever-LICENSE.txt). Changes: settings in the character's
-- profile, Gamepad Companion's chat line, its own copy of the icons, and off
-- while Improved Forever: Vibration is loaded (two addons would both rumble).
local _, ns = ...
-- (the original's IF: its saved settings and chat line)
local IF = {
    Print = function(message) print("|cff80c0ffGamepad Companion:|r " .. message) end,
}

local V = {}
ns.Rumble = V
GamepadCompanionAPI.Rumble = V

-- Improved Forever: Vibration loaded: it rumbles, Companion stays quiet
function V.Other()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return loaded ~= nil and loaded("ImprovedForever_Vibration") == true
end
-- On, and not left to the other addon
function V.Active()
    return IF.db ~= nil and V.Settings().enabled and not V.Other()
end

-- The events' icons, drawn in the radial menu's style (tools/make_vibe_icons.py)
local EVENT_ICONS = "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_event_"

-- Patterns: steps of { low motor, high motor, seconds }; 0, 0 is a pause.
-- Low is the left grip, high the right. Every step lasts 0.1 s or more: a
-- DualSense (on a Mac at least) gives nothing for Easy Controller's shorter
-- taps.
V.PATTERNS = {
    { key = "micro", label = "Micro tick", steps = { { 0.35, 0.35, 0.1 } } },
    { key = "tick", label = "Tick", steps = { { 0.6, 0.6, 0.12 } } },
    { key = "double", label = "Double tick",
        steps = { { 0.7, 0.7, 0.12 }, { 0, 0, 0.12 }, { 0.7, 0.7, 0.12 } } },
    { key = "pulse", label = "Pulse", steps = { { 0.8, 0.8, 0.18 } } },
    { key = "long", label = "Long", steps = { { 0.8, 0.8, 0.6 } } },
    { key = "heart", label = "Heartbeat",
        steps = { { 0.9, 0.9, 0.1 }, { 0, 0, 0.12 }, { 0.6, 0.6, 0.1 } } },
    { key = "rise", label = "Crescendo",
        steps = { { 0.3, 0.3, 0.12 }, { 0.6, 0.6, 0.12 }, { 1, 1, 0.18 } } },
    -- Ours: a hard knock, its opposite, three taps, a soft purr (a cast's:
    -- it loops while the cast lasts) and a rumble that fades out
    { key = "impact", label = "Impact", steps = { { 1, 1, 0.16 } } },
    { key = "triple", label = "Triple tick",
        steps = { { 0.7, 0.7, 0.11 }, { 0, 0, 0.1 }, { 0.7, 0.7, 0.11 }, { 0, 0, 0.1 }, { 0.7, 0.7, 0.11 } } },
    { key = "purr", label = "Purr",
        steps = { { 0.22, 0.22, 0.1 }, { 0, 0, 0.18 }, { 0.22, 0.22, 0.1 }, { 0, 0, 0.18 } } },
    -- Sweep: left (low motor) to right (high motor) and back; a cast's
    { key = "sweep", label = "Sweep",
        steps = { { 0.7, 0, 0.15 }, { 0.4, 0.4, 0.15 }, { 0, 0.7, 0.15 }, { 0.4, 0.4, 0.15 } } },
    { key = "fade", label = "Fade out",
        steps = { { 1, 1, 0.15 }, { 0.6, 0.6, 0.15 }, { 0.3, 0.3, 0.2 } } },
    -- Actions, felt as they go (a cast's loop): gathering, then crafting
    { key = "pluck", label = "Rustle", action = true,      -- herbalism: leaves, then the pull
        steps = { { 0.2, 0.3, 0.1 }, { 0.3, 0.2, 0.1 }, { 0, 0, 0.15 }, { 0.25, 0.35, 0.1 }, { 0, 0, 0.25 } } },
    { key = "pickaxe", label = "Pickaxe", action = true,   -- mining: a hard strike, its ring, a swing
        steps = { { 1, 0.8, 0.12 }, { 0.25, 0.15, 0.1 }, { 0, 0, 0.55 } } },
    { key = "skin", label = "Cut", action = true,          -- skinning: the knife drawn back and forth
        steps = { { 0.5, 0.1, 0.15 }, { 0.1, 0.5, 0.15 }, { 0, 0, 0.15 } } },
    { key = "reel", label = "Line", action = true,         -- fishing: a still line, a bob now and then
        steps = { { 0.12, 0.12, 0.5 }, { 0.45, 0.35, 0.1 }, { 0.12, 0.12, 0.4 } } },
    { key = "click", label = "Tumbler", action = true,     -- opening, a lock: small clicks, then give
        steps = { { 0.3, 0.3, 0.1 }, { 0, 0, 0.2 }, { 0.35, 0.35, 0.1 }, { 0, 0, 0.35 } } },
    { key = "hammer", label = "Anvil", action = true,      -- blacksmithing: hammer and its rebound
        steps = { { 0.9, 1, 0.1 }, { 0, 0, 0.15 }, { 0.45, 0.55, 0.1 }, { 0, 0, 0.45 } } },
    { key = "sew", label = "Stitch", action = true,        -- tailoring, first aid: quick small stitches
        steps = { { 0.3, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.3, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.3, 0.2, 0.1 },
            { 0, 0, 0.3 } } },
    { key = "punch", label = "Punch", action = true,       -- leatherworking: the awl through hide
        steps = { { 0.6, 0.35, 0.12 }, { 0.15, 0.1, 0.1 }, { 0, 0, 0.35 } } },
    { key = "bubble", label = "Bubbles", action = true,    -- alchemy: a brew, bubbling here and there
        steps = { { 0.2, 0, 0.1 }, { 0, 0, 0.15 }, { 0, 0.3, 0.1 }, { 0, 0, 0.1 }, { 0.25, 0.25, 0.1 },
            { 0, 0, 0.25 } } },
    { key = "sizzle", label = "Sizzle", action = true,     -- cooking: a pan, never quite still
        steps = { { 0.15, 0.3, 0.1 }, { 0.1, 0.2, 0.1 }, { 0.2, 0.25, 0.1 }, { 0.1, 0.15, 0.1 } } },
    { key = "gears", label = "Ratchet", action = true,     -- engineering: a wrench, notch by notch
        steps = { { 0.5, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.2, 0.5, 0.1 }, { 0, 0, 0.1 } } },
    { key = "shimmer", label = "Shimmer", action = true,   -- enchanting: magic swelling and fading
        steps = { { 0.1, 0.1, 0.1 }, { 0.3, 0.3, 0.1 }, { 0.5, 0.5, 0.1 }, { 0.3, 0.3, 0.1 }, { 0.1, 0.1, 0.1 },
            { 0, 0, 0.1 } } },
    -- Eating and drinking (their loop, while you sit with it), in time with
    -- the hand going to the mouth (V.RestMotion); these steps only where it
    -- can't be (a race we have no motion for)
    { key = "chew", label = "Munch", action = true, rest = true,     -- food: a bite, chewing, a pause
        steps = { { 0.3, 0.2, 0.12 }, { 0, 0, 0.15 }, { 0.2, 0.12, 0.1 }, { 0, 0, 0.15 }, { 0.2, 0.12, 0.1 },
            { 0, 0, 1.3 } } },
    { key = "gulp", label = "Gulp", action = true, rest = true,      -- a drink: a sip, a swallow, a pause
        steps = { { 0.12, 0.2, 0.15 }, { 0, 0, 0.1 }, { 0.25, 0.35, 0.15 }, { 0, 0, 1.5 } } },
    -- Spells, by family
    { key = "kindle", label = "Kindle", action = true,     -- fire: crackling, building heat
        steps = { { 0.3, 0.15, 0.1 }, { 0.1, 0.35, 0.1 }, { 0.45, 0.25, 0.1 }, { 0.15, 0.4, 0.1 }, { 0.55, 0.45, 0.1 },
            { 0.2, 0.2, 0.1 } } },
    { key = "frost", label = "Frost", action = true,       -- frost: thin, crisp, cold ticks
        steps = { { 0.08, 0.3, 0.1 }, { 0, 0, 0.12 }, { 0.08, 0.25, 0.1 }, { 0.05, 0.1, 0.2 } } },
    { key = "arcane", label = "Arcane", action = true,     -- arcane: bolts flying side to side
        steps = { { 0.5, 0, 0.1 }, { 0, 0, 0.12 }, { 0, 0.5, 0.1 }, { 0, 0, 0.12 } } },
    { key = "shadow", label = "Shadow", action = true,     -- shadow: a low, heavy throb
        steps = { { 0.55, 0.05, 0.25 }, { 0.2, 0, 0.2 }, { 0.4, 0.05, 0.2 }, { 0.1, 0, 0.2 } } },
    { key = "radiance", label = "Radiance", action = true, -- holy: light swelling, both sides
        steps = { { 0.1, 0.1, 0.15 }, { 0.25, 0.25, 0.15 }, { 0.4, 0.4, 0.2 }, { 0.25, 0.25, 0.15 } } },
    { key = "mend", label = "Mend", action = true,         -- healing: a calm, slow pulse
        steps = { { 0.3, 0.3, 0.15 }, { 0.12, 0.12, 0.15 }, { 0, 0, 0.3 } } },
    { key = "static", label = "Static", action = true,     -- nature, lightning: jittery crackle
        steps = { { 0.4, 0, 0.1 }, { 0, 0.45, 0.1 }, { 0.2, 0.2, 0.1 }, { 0.5, 0.1, 0.1 }, { 0, 0, 0.1 },
            { 0.1, 0.5, 0.1 } } },
    { key = "draw", label = "Draw", action = true,         -- aimed shots: the bowstring, tighter and tighter
        steps = { { 0.08, 0.08, 0.2 }, { 0.16, 0.16, 0.2 }, { 0.26, 0.26, 0.2 }, { 0.36, 0.36, 0.2 } } },
    { key = "hearth", label = "Hearth", action = true,     -- Hearthstone, teleports: a long hum rising
        steps = { { 0.08, 0.08, 0.3 }, { 0.15, 0.15, 0.3 }, { 0.25, 0.25, 0.3 }, { 0.12, 0.12, 0.2 } } },
    { key = "ritual", label = "Ritual", action = true,     -- summoning: deep slow beats
        steps = { { 0.6, 0.3, 0.15 }, { 0, 0, 0.35 }, { 0.35, 0.6, 0.15 }, { 0, 0, 0.35 } } },
    -- Shots, by ranged weapon (Shooting's "Match the weapon")
    { key = "string", label = "Bowstring", action = true, weapon = true, -- bow: the string's snap, buzzing out
        steps = { { 0.2, 0.8, 0.1 }, { 0.1, 0.35, 0.1 }, { 0, 0.12, 0.1 } } },
    { key = "latch", label = "Latch", action = true, weapon = true,      -- crossbow: the latch's clack, the limbs' thud
        steps = { { 0.7, 0.5, 0.1 }, { 0, 0, 0.1 }, { 0.35, 0.2, 0.1 } } },
    { key = "recoil", label = "Recoil", action = true, weapon = true,    -- gun: a hard kick, settling
        steps = { { 1, 1, 0.12 }, { 0.45, 0.25, 0.1 }, { 0.15, 0.05, 0.12 } } },
    { key = "zap", label = "Zap", action = true, weapon = true,          -- wand: a crackling spark
        steps = { { 0.25, 0.5, 0.1 }, { 0.5, 0.2, 0.1 }, { 0.1, 0.3, 0.1 } } },
    { key = "toss", label = "Toss", action = true, weapon = true,        -- thrown: the arm's swing, the let-go
        steps = { { 0.15, 0.15, 0.1 }, { 0.5, 0.4, 0.12 }, { 0.08, 0.05, 0.1 } } },
    -- Moves, by what an ability does (Abilities' "Match the move")
    { key = "slash", label = "Slash", action = true, move = true,     -- a heavy blow brought down: wind-up, chop, rebound
        steps = { { 0.15, 0.1, 0.1 }, { 1, 0.9, 0.14 }, { 0.3, 0.2, 0.1 } } },
    { key = "cleave", label = "Cleave", action = true, move = true,   -- a wide swing, left to right
        steps = { { 0.9, 0.2, 0.12 }, { 0.6, 0.6, 0.1 }, { 0.2, 0.9, 0.12 } } },
    { key = "stab", label = "Stab", action = true, move = true,       -- a quick thrust
        steps = { { 0.6, 0.8, 0.1 }, { 0.1, 0.15, 0.1 } } },
    { key = "rend", label = "Rend", action = true, move = true,       -- a ragged tear: claws, a blade dragged
        steps = { { 0.5, 0.2, 0.1 }, { 0.2, 0.5, 0.1 }, { 0.45, 0.25, 0.1 }, { 0.1, 0.1, 0.1 } } },
    { key = "slam", label = "Slam", action = true, move = true,       -- the ground struck, a shock wave rolling out
        steps = { { 1, 1, 0.15 }, { 0.55, 0.55, 0.12 }, { 0.3, 0.3, 0.12 }, { 0.12, 0.12, 0.12 } } },
    { key = "bash", label = "Bash", action = true, move = true,       -- a shield, a fist, a hammer: a knock that stuns
        steps = { { 1, 0.6, 0.12 }, { 0, 0, 0.1 }, { 0.3, 0.15, 0.1 } } },
    { key = "charge", label = "Charge", action = true, move = true,   -- a rush, faster and faster, then the crash
        steps = { { 0.15, 0.15, 0.1 }, { 0.3, 0.3, 0.1 }, { 0.5, 0.5, 0.1 }, { 1, 1, 0.15 }, { 0.2, 0.2, 0.1 } } },
    { key = "whirl", label = "Whirl", action = true, move = true,     -- a spin, the blade going round
        steps = { { 0.8, 0, 0.1 }, { 0.4, 0.4, 0.1 }, { 0, 0.8, 0.1 }, { 0.4, 0.4, 0.1 }, { 0.8, 0, 0.1 },
            { 0.15, 0.15, 0.1 } } },
    { key = "flurry", label = "Flurry", action = true, move = true,   -- a finisher: blow on blow, the last the hardest
        steps = { { 0.5, 0.35, 0.1 }, { 0, 0, 0.1 }, { 0.35, 0.5, 0.1 }, { 0, 0, 0.1 }, { 1, 1, 0.14 } } },
    { key = "shock", label = "Shock", action = true, move = true,     -- an instant spell's jolt
        steps = { { 0.7, 0.3, 0.1 }, { 0.2, 0.6, 0.1 }, { 0.1, 0.1, 0.1 } } },
    { key = "burst", label = "Burst", action = true, move = true,     -- a nova or a shout, spreading out from you
        steps = { { 0.9, 0.9, 0.12 }, { 0.45, 0.45, 0.12 }, { 0.2, 0.2, 0.15 } } },
    { key = "seal", label = "Seal", action = true, move = true,       -- a seal or a blessing: light gathering, settling
        steps = { { 0.1, 0.1, 0.1 }, { 0.3, 0.3, 0.1 }, { 0.5, 0.5, 0.12 }, { 0.25, 0.25, 0.12 }, { 0.1, 0.1, 0.12 } } },
    { key = "judge", label = "Judgement", action = true, move = true, -- a seal let loose: a bright strike
        steps = { { 0.3, 0.3, 0.1 }, { 1, 1, 0.12 }, { 0.5, 0.5, 0.1 }, { 0.2, 0.2, 0.12 } } },
    { key = "ward", label = "Ward", action = true, move = true,       -- a shield raised around you
        steps = { { 0.2, 0.2, 0.12 }, { 0.4, 0.4, 0.15 }, { 0.2, 0.2, 0.12 } } },
    { key = "hex", label = "Hex", action = true, move = true,         -- a curse, a poison, a mark: something creeping in
        steps = { { 0.3, 0.05, 0.12 }, { 0.1, 0, 0.12 }, { 0.25, 0.05, 0.12 }, { 0.05, 0, 0.12 } } },
}

-- The instant abilities each move matches (every rank shares its name: the
-- first's ID names them)
V.MOVES = {
    -- Heroic Strike, Mortal Strike, Execute, Overpower, Revenge, Bloodthirst,
    -- Mocking Blow, Stormstrike, Maul, Ravage, Raptor Strike, Mongoose Bite
    slash = { 78, 12294, 5308, 7384, 6572, 23881, 694, 17364, 6807, 6785, 2973, 1495 },
    cleave = { 845, 779 },                                  -- Cleave, Swipe
    -- Sinister Strike, Backstab, Ambush, Ghostly Strike, Riposte, Hemorrhage
    stab = { 1752, 53, 8676, 14278, 14251, 16511 },
    -- Rend, Hamstring, Sunder Armor, Garrote, Rupture, Expose Armor, Claw,
    -- Rake, Shred, Rip, Wing Clip
    rend = { 772, 1715, 7386, 703, 1943, 8647, 1082, 1822, 5221, 1079, 2974 },
    slam = { 6343, 26573 },                                 -- Thunder Clap, Consecration
    -- Shield Bash, Shield Slam, Pummel, Concussion Blow, Disarm, Kick, Gouge,
    -- Kidney Shot, Cheap Shot, Sap, Hammer of Justice, Bash
    bash = { 72, 23922, 6552, 12809, 676, 1766, 1776, 408, 1833, 6770, 853, 5211 },
    charge = { 100, 20252, 9005, 1953 },                    -- Charge, Intercept, Pounce, Blink
    whirl = { 1680, 12292, 13877 },                         -- Whirlwind, Sweeping Strikes, Blade Flurry
    flurry = { 2098, 22568, 5171 },                         -- Eviscerate, Ferocious Bite, Slice and Dice
    -- Earth, Flame and Frost Shock, Fire Blast, Holy Shock, Death Coil,
    -- Shadowburn, Conflagrate, Counterspell, Moonfire
    shock = { 8042, 8050, 8056, 2136, 20473, 6789, 17877, 17962, 2139, 8921 },
    -- Arcane Explosion, Frost Nova, Cone of Cold, Blast Wave, Holy Nova,
    -- Psychic Scream; Battle, Demoralizing and Intimidating Shout, Piercing
    -- Howl, Bloodrage, Berserker Rage
    burst = { 1449, 122, 120, 11113, 15237, 8122, 6673, 1160, 5246, 12323, 2687, 18499 },
    -- The seals (Righteousness, the Crusader, Command, Light, Wisdom,
    -- Justice), the blessings, Inner Fire, Renew, Lightning Shield; and
    -- Forever's own seals: Might, Protection, Fury, Reckoning, Sacrifice,
    -- Martyrdom (their base IDs in Forever's spell table)
    seal = { 20154, 21082, 20375, 20165, 20166, 20164, 19740, 19742, 20217, 1044, 588, 139,
        324, 626, 1023, 1037, 3694, 13903, 407798 },
    judge = { 20271, 20066 },                               -- Judgement, Repentance
    -- Power Word: Shield, Divine Shield, Divine Protection, Blessing of
    -- Protection, Holy Shield, Ice Barrier, Ice Block, Mana Shield, Shield
    -- Block, Shield Wall, Evasion
    ward = { 17, 642, 498, 1022, 20925, 11426, 11958, 1463, 2565, 871, 5277 },
    -- Shadow Word: Pain, Corruption, the banes (Forever's: Agony, Doom), the
    -- curses (Forever's Elements), Siphon Life, Life Tap, Hunter's Mark,
    -- Faerie Fire, Insect Swarm (IDs as Forever's spell table has them)
    hex = { 589, 172, 980, 603, 702, 704, 1714, 1311676, 18265, 1454, 1130, 770, 5570 },
}
-- Each pattern's icon, drawn in the radial menu's style (tools/make_vibe_icons.py)
local VIBE_ICONS = "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_"
V.OFF_ICON = VIBE_ICONS .. "off"
local PATTERN = {}
for _, p in ipairs(V.PATTERNS) do
    p.icon = VIBE_ICONS .. p.key
    PATTERN[p.key] = p
end

-- The events, by group (Easy Controller's groups and naming), each with its
-- default state and pattern
V.GROUPS = {
    { key = "combat", label = "Combat" },
    { key = "casting", label = "Casting" },
    { key = "rest", label = "Food & drink" },
    { key = "wheel", label = "Wheel" },
    { key = "progress", label = "Progress" },
}
V.EVENTS = {
    { key = "crit", group = "combat", label = "Critical hit: melee", icon = EVENT_ICONS .. "crit", on = true,
        combo = true, pattern = "tick", tip = "Your melee lands a critical hit: a swing or a melee ability (in"
            .. " WoW Forever: your target takes a critical physical hit while you aren't shooting)." },
    { key = "critRanged", group = "combat", label = "Critical hit: ranged", icon = EVENT_ICONS .. "crit", on = false,
        combo = true, pattern = "tick", tip = "A shot or a spell of yours lands a critical hit, or a heal"
            .. " a critical heal (in WoW Forever: your target takes one while you shoot, a spell's, or a"
            .. " critical heal lands on you or it). Off by default: Shooting and spell casts have their own." },
    { key = "critted", group = "combat", label = "Critical hit taken", icon = EVENT_ICONS .. "critted", on = true,
        combo = true,
        pattern = "double", tip = "An enemy lands a critical hit on you." },
    { key = "autoAttack", group = "combat", label = "Auto attack", icon = VIBE_ICONS .. "slash", on = false,
        pattern = "pulse", tip = "You start attacking in melee: Attack, or an ability that starts your"
            .. " swings. Once as they start, not on every swing. Off by default." },
    { key = "shot", group = "combat", label = "Shooting", icon = EVENT_ICONS .. "shot", on = true,
        pattern = "auto", auto = "Match the weapon", family = "weapon", gap = 0.15, tip = "Each ranged shot you fire: Auto Shot,"
            .. " Shoot (a wand, a bow, a gun), Throw, a hunter's instant shots. Match the weapon: a bow's"
            .. " string, a crossbow's latch, a gun's recoil, a wand's zap, a throw." },
    { key = "lowHp", group = "combat", label = "Low health", icon = EVENT_ICONS .. "lowhp", on = true,
        pattern = "heart", loop = true, tip = "While your health is at 35% or less (the game's red"
            .. " low-health warning), its pattern plays over and over." },
    { key = "jump", group = "combat", label = "Jump", icon = VIBE_ICONS .. "charge", on = false,
        pattern = "micro", tip = "You jump (not while swimming, flying or already in the air). Off by"
            .. " default: it comes often." },
    { key = "cast", group = "combat", parent = "spellcast", label = "Casting", icon = EVENT_ICONS .. "cast", on = false,
        pattern = "sweep", loop = true, tip = "While you cast or channel a spell, its pattern plays over"
            .. " and over until the spell ends (instant spells: nothing)." },
    { key = "interrupted", group = "combat", parent = "spellcast", label = "Interrupted", icon = EVENT_ICONS .. "interrupted",
        on = true, pattern = "impact", tip = "Someone interrupts your cast or channel (a kick, a stun, a"
            .. " silence...)." },
    { key = "cancelled", group = "combat", parent = "spellcast", label = "Cancelled", icon = EVENT_ICONS .. "cancelled",
        on = false, pattern = "micro", tip = "You stop your own cast or channel early: you move, jump or"
            .. " cancel it." },
    { key = "pushback", group = "combat", parent = "spellcast", label = "Pushed back", icon = EVENT_ICONS .. "pushback",
        on = true, pattern = "micro", tip = "A hit while you cast or channel costs you cast time: the"
            .. " cast slows, or the channel shortens." },
    { key = "instant", group = "casting", label = "Abilities", icon = EVENT_ICONS .. "instant", on = true,
        pattern = "auto", auto = "Match the move", family = "move", gap = 0.15, tip = "Each instant ability you"
            .. " use (Heroic Strike, Sinister Strike, a seal, a shock...). Match the move: each its own feel (a"
            .. " slash, a stab, a bash, a charge, a whirl, a seal's light, a Judgement...); any other: none. A"
            .. " pattern: every instant ability." },
    { key = "eat", group = "rest", label = "Eating", icon = EVENT_ICONS .. "eat", on = true,
        pattern = "chew", loop = true, family = "rest", tip = "While you sit eating, until you stand up or the"
            .. " food is done. Munch goes with your character: a bite as the hand reaches the mouth, chewing"
            .. " while it stays. Another pattern: played over and over." },
    { key = "drink", group = "rest", label = "Drinking", icon = EVENT_ICONS .. "drink", on = true,
        pattern = "gulp", loop = true, family = "rest", tip = "While you sit drinking, until you stand up or"
            .. " the drink is done. Gulp goes with your character: a sip as the hand reaches the mouth, then"
            .. " a swallow. Another pattern: played over and over. Food and drink at once (a mage's"
            .. " Refreshment, Dim Sum): both, drinking felt over eating." },
    { key = "wheelTick", group = "wheel", label = "Slot change", icon = EVENT_ICONS .. "wheel", on = true,
        pattern = "micro", gap = 0.03, tip = "In an open wheel, the pick moves to another slot (stick,"
            .. " D-pad or a new page)." },
    { key = "levelUp", group = "progress", label = "Level up", icon = EVENT_ICONS .. "levelup", on = true,
        pattern = "rise", tip = "You reach a new level." },
}
local EVENT = {}
for _, e in ipairs(V.EVENTS) do EVENT[e.key] = e end

-- A cast's four moments (its loop, interrupted, cancelled, pushed back)
-- take their patterns from one ready-made set, chosen per kind of cast
V.CAST_PRESETS = {
    { key = "off", label = "Off", icon = V.OFF_ICON },
    { key = "subtle", label = "Subtle", cast = "purr", interrupted = "tick", cancelled = "micro", pushback = "micro" },
    { key = "sweep", label = "Sweep", cast = "sweep", interrupted = "impact", cancelled = "micro", pushback = "tick" },
    { key = "pulse", label = "Pulse", cast = "pulse", interrupted = "double", cancelled = "micro", pushback = "micro" },
    { key = "heart", label = "Heartbeat", cast = "heart", interrupted = "impact", cancelled = "tick", pushback = "micro" },
    { key = "alerts", label = "Alerts only", interrupted = "impact", cancelled = "micro", pushback = "tick" },
}
-- The actions a cast can be (gathering, crafting), each with a set of its
-- own: its pattern while casting, the usual alerts when it ends badly
V.CAST_ACTIONS = {
    { key = "herbalism", label = "Herbalism", kind = "gather", pattern = "pluck", spell = 2366 },
    { key = "mining", label = "Mining", kind = "gather", pattern = "pickaxe", spell = 2575 },
    { key = "skinning", label = "Skinning", kind = "gather", pattern = "skin", spell = 8613 },
    { key = "fishing", label = "Fishing", kind = "gather", pattern = "reel", spell = 7620 },
    { key = "opening", label = "Opening", kind = "gather", pattern = "click", spell = 3365 },
    { key = "blacksmithing", label = "Blacksmithing", kind = "craft", pattern = "hammer", spell = 2018 },
    { key = "tailoring", label = "Tailoring", kind = "craft", pattern = "sew", spell = 3908 },
    { key = "leatherworking", label = "Leatherworking", kind = "craft", pattern = "punch", spell = 2108 },
    { key = "alchemy", label = "Alchemy", kind = "craft", pattern = "bubble", spell = 2259 },
    { key = "cooking", label = "Cooking", kind = "craft", pattern = "sizzle", spell = 2550 },
    { key = "engineering", label = "Engineering", kind = "craft", pattern = "gears", spell = 4036 },
    { key = "enchanting", label = "Enchanting", kind = "craft", pattern = "shimmer", spell = 7411 },
    { key = "firstaid", label = "First Aid", kind = "craft", pattern = "sew", spell = 3273 },
    -- Spells, by family (every rank shares its name: the first's ID names them)
    { key = "fire", label = "Fire", kind = "spell", pattern = "kindle",
        spells = { 133, 11366, 2120, 2948, 348, 6353, 1949, 5740, 5676 } },
    { key = "frostSpells", label = "Frost", kind = "spell", pattern = "frost", spells = { 116, 10, 120 } },
    { key = "arcaneSpells", label = "Arcane", kind = "spell", pattern = "arcane",
        spells = { 5143, 12051, 118, 2912 } },
    { key = "shadowSpells", label = "Shadow", kind = "spell", pattern = "shadow",
        spells = { 686, 689, 1120, 5138, 15407, 8092, 5782, 755, 6201, 693 } },
    { key = "holy", label = "Holy", kind = "spell", pattern = "radiance",
        spells = { 585, 14914, 2006, 7328, 2008, 20484, 879, 10318 } },
    { key = "healing", label = "Healing", kind = "spell", pattern = "mend",
        spells = { 2050, 2054, 2060, 2061, 596, 5185, 8936, 740, 331, 8004, 1064, 635, 19750 } },
    { key = "nature", label = "Nature", kind = "spell", pattern = "static",
        spells = { 403, 421, 5176, 339, 16914, 2637, 6795 } },
    { key = "shots", label = "Shots", kind = "spell", pattern = "draw", spells = { 19434, 1510, 2643 } },
    { key = "travel", label = "Hearthstone", kind = "spell", pattern = "hearth",
        spells = { 8690, 556, 3561, 3562, 3563, 3565, 3566, 3567, 10059, 11416, 11417, 11418, 11419, 11420 } },
    { key = "summon", label = "Summoning", kind = "spell", pattern = "ritual",
        spells = { 688, 697, 712, 691, 698, 5784, 883, 982, 1122 } },
}
-- "Match the action": the set of the action going on
table.insert(V.CAST_PRESETS, 2, { key = "auto", label = "Match the action", auto = true,
    icon = VIBE_ICONS .. "shimmer" })
for _, a in ipairs(V.CAST_ACTIONS) do
    V.CAST_PRESETS[#V.CAST_PRESETS + 1] = { key = a.key, label = a.label, action = a.kind, cast = a.pattern,
        interrupted = "impact", cancelled = "micro", pushback = "tick" }
end

local PRESET = {}
for _, p in ipairs(V.CAST_PRESETS) do
    p.icon = p.icon or VIBE_ICONS .. (p.cast or p.interrupted)
    PRESET[p.key] = p
end
-- (which field of a set each moment uses)
local PHASE = { cast = "cast", interrupted = "interrupted", cancelled = "cancelled", pushback = "pushback" }
V.CAST_PHASES = { "cast", "interrupted", "cancelled", "pushback" }

V.CAST_KINDS = {
    { key = "spell", label = "Spell", icon = EVENT_ICONS .. "cast", preset = "auto", fallback = "sweep",
        tip = "Casting or channelling a spell or an ability. Match the action: fire, frost, healing,"
            .. " Hearthstone... each its own feel. A cast builds up until the spell is released, then"
            .. " fades as it flies off (Fireball). A channel hums and swells with each missile or tick"
            .. " (Arcane Missiles, Drain Life)." },
    { key = "gather", label = "Gathering", icon = EVENT_ICONS .. "gather", preset = "auto",
        tip = "Herbalism, mining, skinning, fishing, opening a chest or a lock. Match the action: each its"
            .. " own feel. Fishing: the throw, then still (the game doesn't tell addons when a fish bites)." },
    { key = "craft", label = "Crafting", icon = EVENT_ICONS .. "craft", preset = "auto",
        tip = "Making something with a profession (cast with its window open)." },
}
local CAST_KIND = {}
for _, k in ipairs(V.CAST_KINDS) do CAST_KIND[k.key] = k end

-- What the Vibration tab lists: each event, and the kinds of cast (each a
-- set for its four moments)
V.RAIL = {}
for _, e in ipairs(V.EVENTS) do
    if e.parent then
        if e.key == "cast" then
            for _, k in ipairs(V.CAST_KINDS) do
                V.RAIL[#V.RAIL + 1] = { key = "cast_" .. k.key, group = "casting", label = k.label, icon = k.icon,
                    castKind = k.key, tip = k.tip, subs = { e } }
            end
        end
    else
        V.RAIL[#V.RAIL + 1] = { key = e.key, group = e.group, label = e.label, icon = e.icon, subs = { e } }
    end
end

-- db.vibration = { enabled, intensity, events = { key = { on, pattern } } }
function V.Settings()
    IF.db.fishLog, IF.db.eatLog = nil, nil   -- (logs of probes, since removed)
    IF.db.vibration = IF.db.vibration or {}
    local s = IF.db.vibration
    if s.enabled == nil then s.enabled = true end
    s.casts = s.casts or {}
    for _, k in ipairs(V.CAST_KINDS) do
        if not PRESET[s.casts[k.key]] then s.casts[k.key] = k.preset end
    end
    s.intensity = s.intensity or 0.8
    s.events = s.events or {}
    for _, e in ipairs(V.EVENTS) do
        local cfg = s.events[e.key]
        if type(cfg) ~= "table" then
            cfg = { on = e.on, pattern = e.pattern }
            s.events[e.key] = cfg
        end
        if not (PATTERN[cfg.pattern] or (e.auto and cfg.pattern == "auto")) then cfg.pattern = e.pattern end
    end
    return s
end

function V.Pattern(key)
    return PATTERN[key]
end

-- A kind of cast's set ("off": none)
function V.CastPreset(kind)
    return V.Settings().casts[kind or "spell"] or "off"
end

function V.SetCastPreset(kind, presetKey)
    V.Settings().casts[kind] = PRESET[presetKey] and presetKey or "off"
end

function V.Preset(key)
    return PRESET[key]
end

-- The cast in progress' kind (Gathering, Crafting...; spell by default)
-- and action (Mining, Tailoring...; nil for a spell)
V.castKind = "spell"
V.castAction = nil

-- Match the weapon: the ranged weapon equipped's pattern (a bow's when
-- there is none to tell)
local WEAPON_PATTERNS = { [2] = "string", [18] = "latch", [3] = "recoil", [19] = "zap", [16] = "toss" }

local function WeaponPattern()
    local id = GetInventoryItemID and GetInventoryItemID("player", INVSLOT_RANGED or 18)
    local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if id and info then
        local classID, subclassID = select(6, info(id))
        if classID == 2 and WEAPON_PATTERNS[subclassID] then return WEAPON_PATTERNS[subclassID] end
    end
    return "string"
end

-- An event's choice: a pattern, "auto" (its Match the...) or "off"
function V.EventChoice(eventKey)
    local cfg = V.Settings().events[eventKey]
    return cfg and cfg.on and cfg.pattern or "off"
end

-- An event's pattern, or nil when it is off (a cast's moments: from the
-- set of the kind of cast going on)
function V.EventPattern(eventKey)
    if PHASE[eventKey] then
        local preset = PRESET[V.CastPreset(V.castKind)]
        if preset and preset.auto then
            local kind = CAST_KIND[V.castKind]
            preset = PRESET[V.castAction] or PRESET[kind and kind.fallback or "subtle"]
        end
        return preset and preset[PHASE[eventKey]] or nil
    end
    local choice = V.EventChoice(eventKey)
    if choice == "off" then return nil end
    if choice == "auto" then
        if eventKey == "shot" then return WeaponPattern() end
        return V.instantMove
    end
    return choice
end

-- A pattern for an event ("off": none)
function V.SetEventPattern(eventKey, patternKey)
    local cfg = V.Settings().events[eventKey]
    if patternKey == "off" then
        cfg.on = false
    else
        cfg.on, cfg.pattern = true, patternKey
    end
end

---------------------------------------------------------------------------
-- Playing a pattern
---------------------------------------------------------------------------
local timers = {}

-- Low drives the left grip, High the right (a DualSense, /if vibe). The
-- right one is felt only from about half strength: any non-zero value is
-- lifted into that range, so both sides feel alike.
local HIGH_FLOOR = 0.5

local function motors(low, high)
    -- (no pad API on this client: nothing to drive)
    if not (C_GamePad and C_GamePad.SetVibration) then return end
    if high > 0 then high = HIGH_FLOOR + (1 - HIGH_FLOOR) * high end
    C_GamePad.SetVibration("Low", low)
    C_GamePad.SetVibration("High", high)
end

-- /if vibe sides: each vibration type alone, then both motors, so the
-- player can tell which side each one drives (and which do nothing)
local SIDE_TESTS = {
    { "Low", function(v) C_GamePad.SetVibration("Low", v) end },
    { "High", function(v) C_GamePad.SetVibration("High", v) end },
    { "LTrigger", function(v) C_GamePad.SetVibration("LTrigger", v) end },
    { "RTrigger", function(v) C_GamePad.SetVibration("RTrigger", v) end },
    { "Low + High", function(v) motors(v, v) end },
    { "High + Low", function(v)
        C_GamePad.SetVibration("High", v)
        C_GamePad.SetVibration("Low", v)
    end },
}

function V.TestSides()
    if not (C_GamePad and C_GamePad.SetVibration) then
        return IF.Print("vibration: not available on this client")
    end
    V.Stop()
    for i, test in ipairs(SIDE_TESTS) do
        local start = (i - 1) * 2
        C_Timer.After(start, function()
            IF.Print(format("vibe %d/%d: %s", i, #SIDE_TESTS, test[1]))
            -- Sent again every 0.1 s for a second, as patterns do
            for t = 0, 0.9, 0.1 do
                C_Timer.After(t, function()
                    local ok, err = pcall(test[2], 1)
                    if not ok and t == 0 then IF.Print("  refused: " .. tostring(err)) end
                end)
            end
            C_Timer.After(1, function() C_GamePad.StopVibration() end)
        end)
    end
    C_Timer.After(#SIDE_TESTS * 2, function() IF.Print("vibe: done. Which ones did you feel, and on which side?") end)
end

local function later(delay, fn)
    if delay <= 0 then
        fn()
    else
        timers[#timers + 1] = C_Timer.NewTimer(delay, fn)
    end
end

-- A loop picked up again (after a pattern played over it); set below
local Resume

-- A shaped vibration: fn(now) gives the low and high motors (0 to 1, before
-- the set strength) at that moment, nil once done. Sent every 0.05 s, so it
-- rises and falls smoothly. once: a one-off; when done, the loop under it
-- (V.looping) goes on.
local shaper = CreateFrame("Frame")
shaper:Hide()
local shapeFn, shapeOnce, shapeSent = nil, false, 0

local function StopShape()
    shapeFn = nil
    shaper:Hide()
end

function V.Stop()
    StopShape()
    for _, t in ipairs(timers) do t:Cancel() end
    wipe(timers)
    if C_GamePad and C_GamePad.StopVibration then C_GamePad.StopVibration() end
end

local function StartShape(fn, once)
    V.Stop()
    shapeFn, shapeOnce, shapeSent = fn, once, 0
    shaper:Show()
end

shaper:SetScript("OnUpdate", function()
    if not shapeFn then return shaper:Hide() end
    local now = GetTime()
    if now - shapeSent < 0.05 then return end
    shapeSent = now
    local low, high = shapeFn(now)
    if not low then
        local resume = shapeOnce and V.looping
        StopShape()
        if C_GamePad and C_GamePad.StopVibration then C_GamePad.StopVibration() end
        if resume then Resume(resume) end
        return
    end
    local gain = V.Settings().intensity
    motors(math.min(1, low * gain), math.min(1, high * gain))
end)

-- A hold's peak (its bar full, its thump when done): both grips at the set
-- strength, never under PEAK_FLOOR, so it still stands out from the
-- filling (at most 0.45 of the strength) when the strength is low
local PEAK_FLOOR = 0.6
local function Peak()
    return math.max(PEAK_FLOOR, math.min(1, V.Settings().intensity))
end

-- A hold under way (a "Hold to" bar): a rumble on the left grip rising with
-- its progress (0 to 1), both grips at the peak once full; the caller sends it every
-- update (sent on at most every 0.1 s); nil: stopped
local holdSent = 0
function V.Hold(progress)
    if not (C_GamePad and C_GamePad.SetVibration and IF.db) then return end
    if not progress then
        holdSent = 0
        return V.Stop()
    end
    local s = V.Settings()
    if not V.Active() then return end
    local now = GetTime()
    if now - holdSent < 0.1 then return end
    holdSent = now
    local gain = s.intensity
    if progress >= 1 then
        local peak = Peak()
        motors(peak, peak)
    else
        motors((0.1 + 0.35 * progress) * gain, 0)
    end
end

-- A hold done (let go full: sold, bought, cancelled; a task removed): a
-- short hard thump on both grips, at the peak
function V.Confirm()
    if not (C_GamePad and C_GamePad.SetVibration and IF.db) then return end
    if not V.Active() then return end
    V.Stop()
    holdSent = 0
    local peak = Peak()
    motors(peak, peak)
    later(0.1, function() motors(peak, peak) end)
    later(0.22, function() C_GamePad.StopVibration() end)
end

-- A pattern at the set strength; the newest replaces the one playing.
-- loop: played again and again (with a short gap) until V.Stop. shape
-- (optional) varies it: { strength, duration (times each step's length),
-- left, right (each side's share, 0 to 1) }
function V.Play(key, loop, shape)
    if not (C_GamePad and C_GamePad.SetVibration and IF.db) then return end
    local pattern = PATTERN[key] or PATTERN.tick
    shape = shape or {}
    local gain = math.max(0, math.min(1, V.Settings().intensity * (shape.strength or 1)))
    local left, right, stretch = shape.left or 1, shape.right or 1, shape.duration or 1
    V.Stop()
    local t = 0
    for _, step in ipairs(pattern.steps) do
        local low, high = step[1] * gain * left, step[2] * gain * right
        local length = math.max(0.1, step[3] * stretch)
        -- Sent again every 0.1 s: holds on a client that lets it fade
        local at = 0
        repeat
            later(t + at, function() motors(low, high) end)
            at = at + 0.1
        until at >= length
        t = t + length
    end
    if loop then
        later(t, function() C_GamePad.StopVibration() end)
        later(t + 0.12, function() V.Play(key, true) end)
    else
        later(t, function()
            C_GamePad.StopVibration()
            -- Over a looping event (a cast still going): back to its loop
            if V.looping then Resume(V.looping) end
        end)
    end
end

-- A loop: its shape (a spell's, below) or its pattern, over and over
Resume = function(loop)
    if loop.shape then
        StartShape(loop.shape)
    else
        V.Play(loop.pattern, true)
    end
end

---------------------------------------------------------------------------
-- A spell's own feel (a spell cast's "Match the action"). A cast builds up
-- with its progress until the spell is released, then fades out as it flies
-- off (Fireball). A channel hums, and swells and fades again with each
-- missile or tick (Arcane Missiles, Drain Life). The spell's family pattern
-- (fire, frost...) ripples through it.
---------------------------------------------------------------------------
-- The cast in progress: its timing ({ start, finish: GetTime seconds;
-- channel; interval: seconds between ticks; texture: family pattern }),
-- whether it has a shape (shaped), and how it ended
local cast = {}

-- Combat values WoW Forever may hide from addons
local function secret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- A spell's name, in the game's language
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

local BUILD_FROM, BUILD_TO = 0.1, 0.8                 -- a cast's start, its release
local RELEASE_PEAK, RELEASE_HOLD, RELEASE_FADE = 1, 0.1, 0.6
local HUM = 0.1                                       -- a channel between ticks
local SWELL_PEAK, SWELL_RISE, SWELL_FALL = 0.75, 0.15, 0.5
local releasedAt = -math.huge

-- A pattern's motors at t seconds into it (looped), each a share of its
-- strongest step
local function Texture(key, t)
    local p = PATTERN[key]
    if not p then return 1, 1 end
    if not p.length then
        local length, top = 0, 0
        for _, step in ipairs(p.steps) do
            length = length + step[3]
            top = math.max(top, step[1], step[2])
        end
        p.length, p.top = length, top > 0 and top or 1
    end
    t = t % p.length
    for _, step in ipairs(p.steps) do
        if t < step[3] then return step[1] / p.top, step[2] / p.top end
        t = t - step[3]
    end
    return 0, 0
end

-- The family's ripple over a strength: never below 70% of it
local function Rippled(env, t)
    local tl, th = Texture(cast.timing.texture, t)
    return env * (0.7 + 0.3 * tl), env * (0.7 + 0.3 * th)
end

-- What is left of the last release d seconds on (0 once faded)
local function ReleaseEnv(d)
    if d < 0 or d >= RELEASE_HOLD + RELEASE_FADE then return 0 end
    if d < RELEASE_HOLD then return RELEASE_PEAK end
    return RELEASE_PEAK * (1 - (d - RELEASE_HOLD) / RELEASE_FADE) ^ 1.5
end

-- A cast: slow at first, steeper toward the release (a cast that runs
-- past its end holds at the top); a release just before still fading
local function BuildUp(now)
    local t = cast.timing
    local span = t.finish - t.start
    local p = span > 0 and math.max(0, math.min(1, (now - t.start) / span)) or 1
    local low, high = Rippled(BUILD_FROM + (BUILD_TO - BUILD_FROM) * p ^ 1.5, now - t.start)
    local tail = ReleaseEnv(now - releasedAt)
    return math.max(low, tail), math.max(high, tail)
end

-- A channel: a hum, and a swell with each tick (the first one interval in),
-- leaning left and right by turns, as missiles fly from either hand
local function Missiles(now)
    local t = cast.timing
    local since = now - t.start
    local ticks = math.floor(since / t.interval)
    local low, high = Rippled(HUM, since)
    if ticks >= 1 then
        local d = since - ticks * t.interval
        local swell = d < SWELL_RISE and d / SWELL_RISE or math.max(0, 1 - (d - SWELL_RISE) / SWELL_FALL)
        swell = SWELL_PEAK * swell
        local left, right = 1, 0.7
        if ticks % 2 == 0 then left, right = 0.7, 1 end
        low, high = low + swell * left, high + swell * right
    end
    local tail = ReleaseEnv(now - releasedAt)
    return math.max(low, tail), math.max(high, tail)
end

local function Release(now)
    local d = now - releasedAt
    if d >= RELEASE_HOLD + RELEASE_FADE then return nil end
    local env = ReleaseEnv(d)
    return env, env
end

-- Fishing: the throw (the pole drawn back, whipped forward, the line
-- running out, the bobber landing), then nothing. (No bite to feel: WoW
-- Forever tells addons nothing when a fish bites. The bobber's soft
-- interact state, the events and its cursor icon all stay as they are.)
local function Fishing(now)
    local t = now - cast.timing.start
    if t < 0.35 then return 0.1 + 0.25 * t / 0.35, 0 end
    if t < 0.5 then return 1, 0.9 end
    if t < 1.1 then
        local env = 0.03 + 0.4 * (1 - (t - 0.5) / 0.6) ^ 1.5
        return env, env * 0.6
    end
    if t < 1.25 then return 0.35, 0.3 end
end

-- The cast in progress' shape, or nil: its own pattern loops instead (a
-- set other than Match the action, gathering, crafting, a channel whose
-- ticks we don't know, a cast whose timing is hidden)
local function CastShape()
    local t = cast.timing
    if not t then return nil end
    local preset = PRESET[V.CastPreset(V.castKind)]
    if not (preset and preset.auto) then return nil end
    if V.castKind == "gather" and V.castAction == "fishing" and t.channel then
        t.fishing = true
        return Fishing
    end
    if V.castKind ~= "spell" then return nil end
    if t.channel and not t.interval then return nil end
    t.texture = V.EventPattern("cast")
    return t.channel and Missiles or BuildUp
end

-- The spell is released (a cast done, a channel run to its end): a strong
-- rumble, fading out as it flies off
function V.Release()
    if not (C_GamePad and C_GamePad.SetVibration and V.Active()) then return end
    releasedAt = GetTime()
    StartShape(Release, true)
end

---------------------------------------------------------------------------
-- Eating and drinking in time with the character: sitting with food or a
-- drink, the server has the character play the eat motion (EmoteEat) once
-- on each of its ticks (REST_TIMER), lifting the hand to the mouth. Munch
-- bites as the hand gets there and chews while it stays; Gulp sips, then
-- swallows. Only while the hand is at the mouth: still while it goes and
-- comes back.
---------------------------------------------------------------------------
-- The motion's length, when the hand reaches the mouth and when it leaves
-- (ms), by race and sex (male, female): from each model's animation, the
-- right hand's distance to the mouth (tools/make_rest_motion.py)
local REST_MOTION = {
    [1] = { { 2600, 940, 2040 }, { 2600, 640, 1980 } },     -- Human
    [2] = { { 2500, 1120, 1920 }, { 2500, 240, 2140 } },    -- Orc
    [3] = { { 2000, 600, 1700 }, { 3000, 840, 2220 } },     -- Dwarf
    [4] = { { 2000, 780, 1580 }, { 2500, 460, 1900 } },     -- Night Elf
    [5] = { { 3334, 820, 1600 }, { 2000, 1120, 1720 } },    -- Undead
    [6] = { { 2000, 900, 2000 }, { 2000, 720, 1880 } },     -- Tauren
    [7] = { { 2666, 800, 1820 }, { 2666, 1040, 2100 } },    -- Gnome
    [8] = { { 3000, 600, 2220 }, { 1500, 260, 1180 } },     -- Troll
    [95] = { { 3334, 400, 1280 }, { 2000, 540, 1440 } },    -- High Order Skyborne
    [96] = { { 3334, 400, 1280 }, { 2000, 540, 1440 } },    -- Windshaper Skyborne
}

-- The server's ticks (seconds), each playing the motion once: the first
-- some time after the buff goes on, then one every so often. Every 5 s, as
-- classic servers have eating (cMaNGOS, Aura::HandleModRegen), drinking
-- too; the first 3 s in, not 5 (both felt in game in WoW Forever). The
-- game tells addons nothing of them.
local REST_TIMER = { eat = { first = 3, every = 5 }, drink = { first = 3, every = 5 } }

-- When the buff went on (GetTime seconds), per event; set below
local restStart = {}

-- The player's motion: { length, reaches, leaves } in seconds, or nil
function V.RestMotion()
    local race = select(3, UnitRace("player"))
    local sex = UnitSex("player")
    local m = REST_MOTION[race] and REST_MOTION[race][sex == 3 and 2 or 1]
    if not m then return nil end
    return { m[1] / 1000, m[2] / 1000, m[3] / 1000 }
end

-- Where the motion is: seconds since the hand last reached the mouth, and
-- how long it stays there (cut short by the next tick); nil before the
-- first time
local function MotionAt(m, timer, start, now)
    local t = now - start - timer.first - m[2]
    if t < 0 then return nil end
    return t % timer.every, math.min((m[3] - m[2]) % m[1], timer.every)
end

local function Munch(m, timer, start)
    return function(now)
        local d, near = MotionAt(m, timer, start, now)
        if not d then return 0, 0 end
        if d < 0.14 then return 0.55, 0.4 end                     -- the bite
        if d < near then
            -- chewing: a small tick every 0.3 s
            if (d - 0.14) % 0.3 < 0.1 then return 0.18, 0.12 end
        end
        return 0, 0
    end
end

local function Gulp(m, timer, start)
    return function(now)
        local d, near = MotionAt(m, timer, start, now)
        if not d then return 0, 0 end
        if d < 0.2 then return 0.1 + 0.15 * d / 0.2, 0.2 + 0.15 * d / 0.2 end   -- the sip
        local swallow = d - near / 2
        if swallow >= 0 and swallow < 0.16 then return 0.3, 0.4 end
        return 0, 0
    end
end

-- Eating's or drinking's shape (its own patterns only), else nil: the
-- pattern loops as it is
local function RestShape(eventKey, pattern)
    if eventKey ~= "eat" and eventKey ~= "drink" then return nil end
    local m = V.RestMotion()
    if not m or (pattern ~= "chew" and pattern ~= "gulp") then return nil end
    local start = restStart[eventKey] or GetTime()
    local timer = REST_TIMER[eventKey]
    return pattern == "chew" and Munch(m, timer, start) or Gulp(m, timer, start)
end

-- Combo events (critical hits, given or taken): one soon after another
-- (within COMBO_WINDOW) plays with a random strength, length and side
-- (more left or more right), each well apart from the last one's, so a run
-- of crits feels like a flurry of blows rather than one buzz repeated. The
-- first of a run plays as set.
local COMBO_WINDOW = 2
local COMBO_STRENGTH, COMBO_LENGTH, COMBO_PAN = { 0.45, 1 }, { 0.7, 1.6 }, 0.8
local comboLast = {}

-- A random value in range, at least gap from previous
local function Apart(lo, hi, previous, gap)
    local v
    repeat
        v = lo + math.random() * (hi - lo)
    until not previous or math.abs(v - previous) >= gap
    return v
end

local function ComboShape(eventKey, chained)
    if not chained then
        comboLast[eventKey] = { strength = 1, duration = 1, pan = 0 }
        return nil
    end
    local previous = comboLast[eventKey] or {}
    local shape = {
        strength = Apart(COMBO_STRENGTH[1], COMBO_STRENGTH[2], previous.strength, 0.2),
        duration = Apart(COMBO_LENGTH[1], COMBO_LENGTH[2], previous.duration, 0.25),
        -- -1 all left .. 1 all right; the far side keeps a little
        pan = Apart(-COMBO_PAN, COMBO_PAN, previous.pan, 0.5),
    }
    shape.left = math.min(1, 1 - shape.pan)
    shape.right = math.min(1, 1 + shape.pan)
    comboLast[eventKey] = shape
    return shape
end

-- An event happened: its pattern, if it is on (the same event at most
-- every 0.4 s; a combo event every 0.15 s, others at their own gap). A looping event's plays until
-- V.EndLoop.
-- Loops still wanted under the one playing (low health under a cast):
-- the newest plays; when it ends, the one before it resumes
local loops = {}

local last = {}
function V.ResetLast(eventKey)
    last[eventKey] = nil
    comboLast[eventKey] = nil
end

function V.Fire(eventKey)
    if not IF.db then return end
    local pattern = V.EventPattern(eventKey)
    if not (V.Active() and pattern) then return end
    if EVENT[eventKey].loop then
        V.EndLoop(eventKey)
        local shape
        if eventKey == "cast" then shape = CastShape() else shape = RestShape(eventKey, pattern) end
        V.looping = { key = eventKey, pattern = pattern, shape = shape }
        if eventKey == "cast" then cast.shaped = V.looping.shape ~= nil end
        loops[#loops + 1] = V.looping
        Resume(V.looping)
        return
    end
    local now = GetTime()
    local combo = EVENT[eventKey].combo
    local since = last[eventKey] and now - last[eventKey]
    if since and since < (EVENT[eventKey].gap or (combo and 0.15 or 0.4)) then return end
    last[eventKey] = now
    local shape = combo and ComboShape(eventKey, since ~= nil and since < COMBO_WINDOW) or nil
    V.Play(pattern, false, shape)
end

-- A looping event is over (the cast ended): its loop stops
function V.EndLoop(eventKey)
    for i = #loops, 1, -1 do
        if loops[i].key == eventKey then table.remove(loops, i) end
    end
    if V.looping and V.looping.key == eventKey then
        V.looping = loops[#loops]
        if V.looping then
            Resume(V.looping)
        else
            V.Stop()
        end
    end
end

-- Try it on Spell cast: a cast played out with its four patterns, as a
-- real one would (casting, interrupted; casting, cancelled; casting, pushed
-- back, casting on to its end; a spell's own feel: a cast released, a
-- channel's missiles). onStep(label) as each part starts.
local sim = {}

function V.StopSimulation()
    if #sim == 0 then return end
    for _, t in ipairs(sim) do t:Cancel() end
    wipe(sim)
    V.EndLoop("cast")
    if V.loopDemo then
        V.EndLoop(V.loopDemo)
        V.loopDemo = nil
    end
end

-- Try it on a looping event (low health): its loop for a few seconds, as
-- it would run while the state lasts. Triangle again, or closing the
-- panel, stops it.
function V.SimulateLoop(eventKey, seconds)
    local wasDemo = V.loopDemo == eventKey
    V.StopSimulation()
    if wasDemo then return false end
    V.loopDemo = eventKey
    V.Fire(eventKey)
    sim[#sim + 1] = C_Timer.NewTimer(seconds or 6, function()
        wipe(sim)
        V.EndLoop(eventKey)
        V.loopDemo = nil
    end)
    return true
end

-- Try it on a combo event: a run of six hits at uneven intervals, each
-- shaped as a real run's would be. onStep(n) as hit n lands.
function V.SimulateCombo(eventKey, onStep)
    V.StopSimulation()
    V.ResetLast(eventKey)
    local t = 0
    for n = 1, 6 do
        local hit = n
        sim[#sim + 1] = C_Timer.NewTimer(t, function()
            onStep(hit)
            V.Fire(eventKey)
        end)
        t = t + 0.25 + math.random() * 0.4
    end
    sim[#sim + 1] = C_Timer.NewTimer(t, function() wipe(sim) end)
end

-- Try it on Shooting: three shots, as an Auto Shot or a wand would fire
-- them (quicker, to feel them sooner). onStep(n) as shot n goes.
function V.SimulateShots(eventKey, onStep)
    V.StopSimulation()
    V.ResetLast(eventKey)
    for n = 1, 3 do
        local shot = n
        sim[#sim + 1] = C_Timer.NewTimer((n - 1) * 0.8, function()
            onStep(shot)
            V.Fire(eventKey)
        end)
    end
    sim[#sim + 1] = C_Timer.NewTimer(2.4, function() wipe(sim) end)
end

-- Try it on Abilities: a warrior's and a paladin's moves in turn. onStep(name)
-- as each one goes.
local DEMO_MOVES = { 100, 78, 845, 1680, 20154, 20271 }

function V.SimulateMoves(eventKey, onStep)
    V.StopSimulation()
    V.ResetLast(eventKey)
    for n, id in ipairs(DEMO_MOVES) do
        sim[#sim + 1] = C_Timer.NewTimer((n - 1) * 1.1, function()
            V.instantMove = V.MoveOf(id)
            onStep(SpellName(id) or tostring(id))
            V.Fire(eventKey)
        end)
    end
    sim[#sim + 1] = C_Timer.NewTimer(#DEMO_MOVES * 1.1, function() wipe(sim) end)
end

function V.SimulateCast(onStep, kind, action)
    V.StopSimulation()
    V.castKind = kind or "spell"
    -- (Match the action: a likely one of that kind)
    if not action then
        for _, a in ipairs(V.CAST_ACTIONS) do
            if a.kind == kind then action = action or a.key end
        end
    end
    V.castAction = action
    local function at(t, fn)
        sim[#sim + 1] = C_Timer.NewTimer(t, fn)
    end
    local function play(key, loop)
        local pattern = V.EventPattern(key)
        if not pattern then return end
        if loop then
            V.looping = { key = key, pattern = pattern, shape = key == "cast" and CastShape() or nil }
            return Resume(V.looping)
        end
        V.Play(pattern)
    end
    local function casting()
        onStep(EVENT.cast.label)
        play("cast", true)
    end
    local function ended(key)
        V.EndLoop("cast")
        onStep(EVENT[key].label)
        play(key)
    end
    local function finish()
        V.EndLoop("cast")
        wipe(sim)
        V.castKind, V.castAction = "spell", nil
        cast.timing = nil
        onStep(nil)
    end
    local preset = PRESET[V.CastPreset(V.castKind)]
    -- Gathering, Match the action: a herb picked; then fishing: the throw
    if V.castKind == "gather" and preset and preset.auto then
        V.castAction = "herbalism"
        onStep(SpellName(2366) or "Herbalism")
        play("cast", true)
        at(2.5, function() V.EndLoop("cast") end)
        at(3.5, function()
            local now = GetTime()
            V.castAction = "fishing"
            cast.timing = { start = now, finish = now + 30, channel = true }
            cast.ended = false
            onStep((SpellName(7620) or "Fishing") .. ": the throw")
            play("cast", true)
        end)
        at(5.5, finish)
        return
    end
    -- A spell, Match the action: a Fireball pushed back, then released;
    -- Arcane Missiles, three of them; a Frostbolt interrupted
    if V.castKind == "spell" and preset and preset.auto then
        local name
        local function begin(id, actionKey, seconds, interval)
            local now = GetTime()
            V.castAction = actionKey
            cast.timing = { start = now, finish = now + seconds, channel = interval ~= nil, interval = interval }
            cast.ended = false
            name = SpellName(id) or EVENT.cast.label
            onStep(name)
            play("cast", true)
        end
        local function released()
            V.EndLoop("cast")
            cast.ended = true
            onStep(name .. ": released")
            V.Release()
        end
        begin(133, "fire", 2.5)
        at(1.2, function()
            cast.timing.finish = cast.timing.finish + 0.5
            onStep(EVENT.pushback.label)
            play("pushback")
        end)
        at(3, released)
        at(4, function() begin(5143, "arcaneSpells", 3, 1) end)
        at(7, released)
        at(8, function() begin(116, "frostSpells", 2.5) end)
        at(9.4, function() ended("interrupted") end)
        at(10.4, finish)
        return
    end
    -- Each cast 2 s, then how it ends; a second's pause before the next
    casting()
    at(2, function() ended("interrupted") end)
    at(3, casting)
    at(5, function() ended("cancelled") end)
    at(6, casting)
    -- Pushed back after 2 s: its pattern, then the cast's loop 2 s more
    at(8, function()
        onStep(EVENT.pushback.label)
        play("pushback")
    end)
    at(10, finish)
end

---------------------------------------------------------------------------
-- The events
---------------------------------------------------------------------------
-- Where each kind of combat log entry keeps its "critical" flag
local CRIT_ARG = {
    SWING_DAMAGE = 18, RANGE_DAMAGE = 21, SPELL_DAMAGE = 21, SPELL_PERIODIC_DAMAGE = 21,
    SPELL_HEAL = 18, SPELL_PERIODIC_HEAL = 18,
}
local HEALS = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }
local PHYSICAL = 1

-- Shooting now or just now (Auto Shot or a wand repeating; a shot in the
-- last RANGED_WINDOW seconds, its arrow maybe still flying): a physical
-- crit is the shot's, not a swing's
local RANGED_WINDOW = 1.5
local ranged = { auto = false, shot = -math.huge }

local function Shooting()
    return ranged.auto or GetTime() - ranged.shot < RANGED_WINDOW
end

-- Your crit: melee, or ranged (a shot, a spell, a heal)
local function YourCrit(isRanged)
    V.Fire(isRanged and "critRanged" or "crit")
end

-- WoW Forever takes the combat log away from addons (no
-- CombatLogGetCurrentEventInfo), so there the crits come from UNIT_COMBAT,
-- which says what a unit took but not from whom: a critical wound on you is
-- "you get crit"; one on your target, or a critical heal on you or it, is
-- "you crit" (in a group, someone else's crit on your target counts too).
-- Where the combat log is still readable, it says exactly who crit whom.
local function CombatLog()
    local info = { CombatLogGetCurrentEventInfo() }
    local sub = info[2]
    local index = CRIT_ARG[sub]
    if not index then return end
    local critical = info[index]
    if secret(critical) or not critical then return end
    local player = UnitGUID("player")
    if secret(info[4]) or secret(info[8]) then return end
    if info[4] == player then
        local school = sub ~= "SWING_DAMAGE" and sub ~= "RANGE_DAMAGE" and info[14] or nil
        if secret(school) then school = nil end
        YourCrit(sub == "RANGE_DAMAGE" or HEALS[sub]
            or (sub ~= "SWING_DAMAGE" and ((school and school ~= PHYSICAL) or Shooting())))
    elseif info[8] == player and not HEALS[sub] then
        V.Fire("critted")
    end
end

-- (a wound's school, unless hidden: physical is a swing's or a shot's,
-- any other a spell's)
local function UnitCombat(unit, action, flag, _, school)
    if secret(action) or secret(flag) or flag ~= "CRITICAL" then return end
    if secret(school) then school = nil end
    if unit == "player" then
        if action == "WOUND" then
            V.Fire("critted")
        elseif action == "HEAL" then
            YourCrit(true)
        end
    elseif unit == "target" then
        if action == "HEAL" then
            YourCrit(true)
        elseif action == "WOUND" then
            YourCrit((school and school ~= PHYSICAL) or Shooting())
        end
    end
end

local hasCombatLog = type(CombatLogGetCurrentEventInfo) == "function"
-- Casts and channels: the loop while one lasts, then how it ended. A cast
-- interrupted by someone names who (interruptedBy, hidden: someone still);
-- without one, a cast stopped before its end was the player's doing (a
-- channel's natural end has none either: its end time tells them apart).
-- Each cast's end counts once (a channel stopping says so twice, in
-- either order: a stop with no interrupter waits a moment for one).
local function interrupter(by)
    return secret(by) or (by ~= nil and by ~= "")
end

-- Gathering: these spells (by their names in the game's language), each
-- an action
local GATHER_IDS = {
    herbalism = { 2366, 2368, 3570, 11993 },
    mining = { 2575, 2576, 3564, 10248 },
    skinning = { 8613, 8617, 8618, 10768 },
    fishing = { 7620, 7731, 7732, 18248 },
    opening = { 3365, 6247, 6477, 6478, 21651, 1804 },
}
-- Channels that fire a missile or tick every so many seconds (a swell
-- each): Arcane Missiles, Mind Flay, Drain Life, Drain Mana, Drain Soul,
-- Health Funnel, Blizzard, Hurricane, Tranquility, Rain of Fire, Hellfire,
-- Volley
local CHANNEL_TICKS = {
    [5143] = 1, [15407] = 1, [689] = 1, [5138] = 1, [1120] = 3, [755] = 1,
    [10] = 1, [16914] = 1, [740] = 2, [5740] = 2, [1949] = 1, [1510] = 1,
}
-- Shots (Shooting): Auto Shot, Shoot (a wand; a bow, gun or crossbow),
-- Throw, and a hunter's instant shots and stings
local SHOT_IDS = {
    75, 5019, 3018, 2480, 7918, 7919, 2764,
    3044, 2643, 5116, 1978, 3043, 3034, 19386, 19503, 20736, 19801,
}
-- Eating and drinking: the buffs of sitting with food or a drink (each
-- also the spell the item casts). Most are Food or Drink; a few have their
-- own name, some both at once (a mage's Refreshment, Dim Sum...).
local REST_SPELLS = {
    eat = { 433, 26030, 18124, 21149, 29041 },
    drink = { 430, 18140, 23698 },
    both = { 167152, 25990, 26263, 29055, 1312719, 1269354 },
}
local gatherByName, craftByName, spellByName, ticksByName, shotByName, moveByName, restByName
local function Names()
    if gatherByName then return end
    gatherByName, craftByName, ticksByName, shotByName, moveByName, restByName = {}, {}, {}, {}, {}, {}
    for kind, ids in pairs(REST_SPELLS) do
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            if name then restByName[name] = kind end
        end
    end
    for move, ids in pairs(V.MOVES) do
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            if name then moveByName[name] = move end
        end
    end
    for _, id in ipairs(SHOT_IDS) do
        local name = SpellName(id)
        if name then shotByName[name] = true end
    end
    for id, interval in pairs(CHANNEL_TICKS) do
        local name = SpellName(id)
        if name then ticksByName[name] = interval end
    end
    for action, ids in pairs(GATHER_IDS) do
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            if name then gatherByName[name] = action end
        end
    end
    spellByName = {}
    for _, a in ipairs(V.CAST_ACTIONS) do
        local name = a.kind == "craft" and SpellName(a.spell)
        if name then craftByName[name] = a.key end
        for _, id in ipairs(a.spells or {}) do
            name = SpellName(id)
            if name and not spellByName[name] then spellByName[name] = a.key end
        end
    end
end

-- The profession whose window is open (its name, in the game's language)
local function OpenProfession()
    if _G.CraftFrame and _G.CraftFrame:IsShown() then
        local name = GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()
        return name or SpellName(7411)
    end
    if (_G.TradeSkillFrame and _G.TradeSkillFrame:IsShown())
        or (_G.ProfessionsFrame and _G.ProfessionsFrame:IsShown()) then
        if GetTradeSkillLine then return (GetTradeSkillLine()) or "" end
        local info = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
        return info and info.professionName or ""
    end
end

-- A cast's kind and action
local function CastKind(spellID)
    Names()
    local profession = OpenProfession()
    if profession then
        if secret(profession) then return "craft", nil end
        return "craft", craftByName[profession]
    end
    if spellID and not secret(spellID) then
        local name = SpellName(spellID)
        if name and not secret(name) then
            if gatherByName[name] then return "gather", gatherByName[name] end
            return "spell", spellByName[name]
        end
    end
    return "spell", nil
end

-- An instant ability's move (nil: none we know)
function V.MoveOf(spellID)
    if not spellID or secret(spellID) then return nil end
    Names()
    local name = SpellName(spellID)
    return name and not secret(name) and moveByName[name] or nil
end

-- A ranged shot (every rank shares its name)
local function IsShot(spellID)
    if not spellID or secret(spellID) then return false end
    Names()
    local name = SpellName(spellID)
    return name ~= nil and not secret(name) and shotByName[name] == true
end

-- Food or a drink (eat, drink or both; nil: neither)
local function RestOf(spellID)
    if not spellID or secret(spellID) then return nil end
    Names()
    local name = SpellName(spellID)
    return name and not secret(name) and restByName[name] or nil
end

-- A channel's seconds between ticks (nil: not one we know)
local function ChannelTicks(spellID)
    if not spellID or secret(spellID) then return nil end
    local name = SpellName(spellID)
    return name and not secret(name) and ticksByName[name] or nil
end

-- The cast or channel in progress' start and end (GetTime seconds), unless
-- hidden
local function CastTimes(channel)
    local info = channel and UnitChannelInfo or UnitCastingInfo
    if not info then return nil end
    local startMs, endMs = select(4, info("player"))
    if not (startMs and endMs) or secret(startMs) or secret(endMs) then return nil end
    return startMs / 1000, endMs / 1000
end

-- Auto attack's spell (turning it on is no ability)
local ATTACK = 6603

-- An event about this cast (another one's attempt failing doesn't count;
-- hidden or missing IDs: it does)
local function SameCast(guid)
    if guid == nil or cast.guid == nil or secret(guid) or secret(cast.guid) then return true end
    return guid == cast.guid
end

local function CastStarted(event, _, guid, spellID)
    V.castKind, V.castAction = CastKind(spellID)
    cast.ended, cast.shaped = false, false
    cast.guid = guid
    local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
    cast.casting = not channel
    local start, finish = CastTimes(channel)
    cast.channelEnd = channel and finish or nil
    cast.timing = start and { start = start, finish = finish, channel = channel,
        interval = channel and ChannelTicks(spellID) or nil } or nil
    V.Fire("cast")
end

local function CastEnded(how)
    V.EndLoop("cast")
    if cast.ended then return end
    cast.ended = true
    -- (fishing stopped early: most often the catch, looted)
    if how == "cancelled" and cast.timing and cast.timing.fishing then return end
    V.Fire(how)
end

-- Done as it should: the spell flies off (with its own feel only)
local function CastReleased()
    V.EndLoop("cast")
    if cast.ended then return end
    cast.ended = true
    if cast.shaped and not cast.timing.fishing then V.Release() end
end

local CAST_HANDLERS = {
    UNIT_SPELLCAST_START = CastStarted,
    UNIT_SPELLCAST_CHANNEL_START = CastStarted,
    UNIT_SPELLCAST_INTERRUPTED = function(_, _, _, _, by)
        CastEnded(interrupter(by) and "interrupted" or "cancelled")
    end,
    UNIT_SPELLCAST_CHANNEL_STOP = function(_, _, _, _, by)
        if interrupter(by) then return CastEnded("interrupted") end
        V.EndLoop("cast")
        if not cast.channelEnd then return end
        if GetTime() < cast.channelEnd - 0.25 then
            C_Timer.After(0.1, function()
                if not cast.ended then CastEnded("cancelled") end
            end)
        else
            -- Run to its end: the last missile flies off
            CastReleased()
        end
    end,
    -- A cast's end; how it ended comes with UNIT_SPELLCAST_INTERRUPTED, or
    -- UNIT_SPELLCAST_SUCCEEDED (either order)
    UNIT_SPELLCAST_STOP = function() V.EndLoop("cast") end,
    UNIT_SPELLCAST_FAILED = function(_, _, guid)
        if SameCast(guid) then V.EndLoop("cast") end
    end,
    -- (a channel's start says so too: not its end)
    UNIT_SPELLCAST_SUCCEEDED = function(_, _, guid, spellID)
        if IsShot(spellID) then
            ranged.shot = GetTime()
            return V.Fire("shot")
        end
        -- The cast in progress, done
        if cast.timing and not cast.timing.channel and not cast.ended and SameCast(guid) then
            return CastReleased()
        end
        -- (a cast whose timing is hidden; a channel starting; Attack)
        if cast.casting and not cast.ended and SameCast(guid) then
            cast.ended = true
            return
        end
        if UnitChannelInfo and UnitChannelInfo("player") then return end
        if not secret(spellID) and spellID == ATTACK then return end
        -- (sitting down with food or a drink: Eating, Drinking)
        if RestOf(spellID) then return end
        V.instantMove = V.MoveOf(spellID)
        V.Fire("instant")
    end,
    UNIT_SPELLCAST_DELAYED = function()
        if cast.ended then return end
        local start, finish = CastTimes(false)
        if start and cast.timing then cast.timing.start, cast.timing.finish = start, finish end
        V.Fire("pushback")
    end,
    UNIT_SPELLCAST_CHANNEL_UPDATE = function()
        if cast.ended then return end
        local _, newEnd = CastTimes(true)
        if newEnd then
            -- Shortened by a hit (not lengthened)
            if cast.channelEnd and newEnd < cast.channelEnd - 0.05 then V.Fire("pushback") end
            cast.channelEnd = newEnd
            if cast.timing then cast.timing.finish = newEnd end
        end
    end,
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
-- (melee auto-attack starting; ranged's is START_AUTOREPEAT_SPELL)
events:RegisterEvent("PLAYER_ENTER_COMBAT")
events:RegisterEvent("START_AUTOREPEAT_SPELL")
events:RegisterEvent("STOP_AUTOREPEAT_SPELL")
for event in pairs(CAST_HANDLERS) do events:RegisterUnitEvent(event, "player") end
if hasCombatLog then
    events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
else
    events:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
end
events:SetScript("OnEvent", function(_, event, ...)
    if not IF.db then return end
    if event == "PLAYER_LEVEL_UP" then
        V.Fire("levelUp")
    elseif event == "PLAYER_ENTER_COMBAT" then
        -- (started by an ability: its own feel just played, kept)
        if last.instant and GetTime() - last.instant < 0.3 then return end
        V.Fire("autoAttack")
    elseif event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
        -- (stopped: its last shot may still be flying)
        ranged.auto = event == "START_AUTOREPEAT_SPELL"
        ranged.shot = GetTime()
    elseif CAST_HANDLERS[event] then
        CAST_HANDLERS[event](event, ...)
    elseif event == "UNIT_COMBAT" then
        UnitCombat(...)
    else
        CombatLog()
    end
end)

---------------------------------------------------------------------------
-- Jumping: the game's Jump binding (pad, keyboard) calls JumpOrAscendStart;
-- hooked after it (hooksecurefunc: the jump itself stays the game's). Not
-- in water, in the air or on a flight: no jump comes of it there.
---------------------------------------------------------------------------
local function Airborne()
    return (IsSwimming and IsSwimming()) or (IsFlying and IsFlying()) or (IsFalling and IsFalling())
        or (UnitOnTaxi and UnitOnTaxi("player"))
end

if JumpOrAscendStart then
    hooksecurefunc("JumpOrAscendStart", function()
        if IF.db and not Airborne() then V.Fire("jump") end
    end)
end

---------------------------------------------------------------------------
-- Low health. WoW Forever hides the player's health from addons in combat,
-- but the game's own low-health warning (LowHealthFrame: the red screen
-- edge, at 35%) reads it untainted: its showing is our cue. (It also pulses
-- in combat behind a full-screen window: not low health, skipped.) With
-- that warning off in the game's options, health is read directly when it
-- isn't hidden.
---------------------------------------------------------------------------
local LOW_HP = 0.35
local low = false

local function Secret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

local function FullscreenPanel()
    return GetUIPanel ~= nil and GetUIPanel("fullscreen") ~= nil
end

-- Low: its loop for as long as it lasts
local function SetLow(on)
    if on and not low then
        low = true
        V.Fire("lowHp")
    elseif not on and low then
        low = false
        V.EndLoop("lowHp")
    end
end

local warning = _G.LowHealthFrame
if warning then
    warning:HookScript("OnShow", function()
        if IF.db and not FullscreenPanel() and not UnitIsDeadOrGhost("player") then SetLow(true) end
    end)
    warning:HookScript("OnHide", function() SetLow(false) end)
end

local health = CreateFrame("Frame")
health:RegisterUnitEvent("UNIT_HEALTH", "player")
health:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
health:RegisterEvent("PLAYER_DEAD")
health:SetScript("OnEvent", function(_, event)
    if not IF.db then return end
    if event == "PLAYER_DEAD" or UnitIsDeadOrGhost("player") then return SetLow(false) end
    -- The game's warning does it, when it is on
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if warning and get and get("doNotFlashLowHealthWarning") ~= "1" then return end
    local hp, max = UnitHealth("player"), UnitHealthMax("player")
    if Secret(hp) or Secret(max) or not max or max <= 0 then return end
    SetLow(hp / max <= LOW_HP)
end)

---------------------------------------------------------------------------
-- Eating and drinking: a loop while the food's or the drink's buff is on
-- you, stopped when it goes (you stand up, or it is done). Names hidden
-- (combat): left as they are.
---------------------------------------------------------------------------
local resting = { eat = false, drink = false }

-- start: when the buff went on (nil: now)
local function SetResting(key, start)
    local on = start ~= false
    if on == resting[key] then return end
    resting[key] = on
    restStart[key] = on and start or nil
    if on then V.Fire(key) else V.EndLoop(key) end
end

-- Returned by Buff when the auras can't be read (secret, e.g. in combat)
local HIDDEN = {}

-- The player's buff i's name, and when it went on (nil: no more)
local function Buff(i)
    local name, duration, expires
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        -- Secret auras error when read from addon code: ask first, and catch
        -- the error where that can't be asked
        if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
            return HIDDEN
        end
        local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
        if not ok then return HIDDEN end
        if not aura then return nil end
        name, duration, expires = aura.name, aura.duration, aura.expirationTime
    elseif UnitBuff then
        local _
        name, _, _, _, duration, expires = UnitBuff("player", i)
    end
    if name == nil or secret(name) then return name end
    if secret(duration) or secret(expires) or not (duration and expires) or duration <= 0 then return name end
    return name, expires - duration
end

local rest = CreateFrame("Frame")
rest:RegisterUnitEvent("UNIT_AURA", "player")
rest:RegisterEvent("PLAYER_ENTERING_WORLD")
rest:SetScript("OnEvent", function()
    if not IF.db then return end
    Names()
    local eat, drink = false, false
    for i = 1, 40 do
        local name, start = Buff(i)
        if name == nil then break end
        if name == HIDDEN or secret(name) then return end
        local kind = restByName[name]
        if kind == "eat" or kind == "both" then eat = start or GetTime() end
        if kind == "drink" or kind == "both" then drink = start or GetTime() end
    end
    -- (both: drinking played over eating)
    SetResting("eat", eat)
    SetResting("drink", drink)
end)

---------------------------------------------------------------------------
-- Gamepad Companion: the settings live in the character's profile
-- (GamepadCompanionCharDB.vibration, Shared.lua)
---------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name ~= "GamepadCompanion" then return end
    IF.db = ns.Shared.CharDB()
    V.Settings()
end)
