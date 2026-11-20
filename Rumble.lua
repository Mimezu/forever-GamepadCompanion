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
-- The set strength (0.8 before the settings load)
function V.Intensity() return IF.db and V.Settings().intensity or 0.8 end

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
    -- A critical hit: a hard, sharp strike with a short bright ring, above any
    -- plain hit (HD scale tier 4); no lead-in
    { key = "critHit", label = "Crit", art = "impact", steps = { { 1, 1, 0.1 }, { 0, 0, 0.06 }, { 0.35, 0.35, 0.1 } } },
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
    { key = "pickaxe", label = "Pickaxe", action = true,   -- mining: a firm knock, its faint ring, the swing
        steps = { { 0.7, 0.6, 0.1 }, { 0.15, 0.1, 0.1 }, { 0, 0, 0.68 } } },
    { key = "skin", label = "Cut", action = true,          -- skinning: the knife drawn back and forth
        steps = { { 0.5, 0.1, 0.15 }, { 0.1, 0.5, 0.15 }, { 0, 0, 0.15 } } },
    { key = "reel", label = "Line", action = true,         -- fishing: a still line, a bob now and then
        steps = { { 0.12, 0.12, 0.5 }, { 0.45, 0.35, 0.1 }, { 0.12, 0.12, 0.4 } } },
    { key = "flick", label = "Cast", action = true, art = "toss", once = true,  -- fishing: the pole drawn back, whipped, the line out
        steps = { { 0.08, 0.04, 0.14 }, { 0.1, 0.08, 0.1 }, { 0.68, 0.85, 0.12 }, { 0.04, 0.2, 0.1 }, { 0, 0.09, 0.45 } } },
    { key = "click", label = "Tumbler", action = true,     -- opening, a lock: small clicks, then give
        steps = { { 0.3, 0.3, 0.1 }, { 0, 0, 0.2 }, { 0.35, 0.35, 0.1 }, { 0, 0, 0.35 } } },
    { key = "hammer", label = "Anvil", action = true,      -- blacksmithing: hammer and its rebound
        steps = { { 0.55, 0.6, 0.1 }, { 0, 0, 0.15 }, { 0.2, 0.25, 0.1 }, { 0, 0, 0.45 } } },
    { key = "sew", label = "Stitch", action = true,        -- tailoring: quick small stitches
        steps = { { 0.3, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.3, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.3, 0.2, 0.1 },
            { 0, 0, 0.3 } } },
    { key = "punch", label = "Punch", action = true,       -- leatherworking: the awl through hide
        steps = { { 0.4, 0.25, 0.12 }, { 0.12, 0.08, 0.1 }, { 0, 0, 0.35 } } },
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
    { key = "wrap", label = "Wrap", art = "sew", action = true,     -- first aid: cloth wound round, pulled taut
        steps = { { 0.15, 0.05, 0.2 }, { 0.05, 0.15, 0.2 }, { 0.3, 0.3, 0.1 }, { 0, 0, 0.5 } } },
    { key = "bellows", label = "Bellows", art = "heart", action = true, -- smelting: the bellows heave, ore glowing
        steps = { { 0.35, 0.1, 0.35 }, { 0.15, 0.05, 0.25 }, { 0, 0, 0.2 }, { 0.05, 0.12, 0.1 }, { 0, 0, 0.5 } } },
    -- A craft's finish, once as it's made (V.CraftFinish): small, of its material
    { key = "quench", label = "Quench", art = "fade",      -- blacksmithing: hot steel in water, a hiss
        steps = { { 0.35, 0.35, 0.1 }, { 0.12, 0.2, 0.15 }, { 0.05, 0.1, 0.2 } } },
    { key = "snip", label = "Snip", art = "double",        -- tailoring: the thread cut
        steps = { { 0.15, 0.25, 0.1 }, { 0, 0, 0.1 }, { 0.1, 0.15, 0.1 } } },
    { key = "cinch", label = "Cinch", art = "punch",       -- leatherworking: a strap drawn tight
        steps = { { 0.3, 0.25, 0.12 }, { 0.08, 0.08, 0.1 } } },
    { key = "cork", label = "Cork", art = "bubble",        -- alchemy: the stopper in, a soft pop
        steps = { { 0.12, 0.12, 0.1 }, { 0.3, 0.3, 0.1 } } },
    { key = "plate", label = "Plated", art = "sizzle",     -- cooking: off the pan onto the plate
        steps = { { 0.2, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.08, 0.06, 0.1 } } },
    { key = "clunk", label = "Clunk", art = "gears",       -- engineering: the last part seats
        steps = { { 0.15, 0.05, 0.1 }, { 0.35, 0.35, 0.12 } } },
    { key = "chime", label = "Chime", art = "shimmer",     -- enchanting: the glow settles, ringing out
        steps = { { 0.2, 0.2, 0.1 }, { 0.1, 0.1, 0.15 }, { 0.05, 0.05, 0.15 } } },
    { key = "tie", label = "Tied off", art = "sew",        -- first aid: the knot pulled snug
        steps = { { 0.2, 0.2, 0.12 }, { 0, 0, 0.1 }, { 0.08, 0.08, 0.1 } } },
    { key = "pour", label = "Pour", art = "fade",          -- smelting: the bar poured, settling
        steps = { { 0.25, 0.1, 0.25 }, { 0.1, 0.05, 0.2 }, { 0.12, 0.12, 0.1 } } },
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
    { key = "surge", label = "Surge", action = true, move = true,     -- a ground effect laid down (Consecration): a low push, a warm spread
        steps = { { 0.8, 0.8, 0.2 }, { 0.3, 0.3, 0.12 }, { 0.12, 0.12, 0.12 } } },
    { key = "pillar", label = "Pillar", action = true, move = true, art = "radiance", -- a proc's pillar of fire: a sharp strike rising into a short rolling rumble
        steps = { { 0.7, 0.7, 0.06 }, { 0.15, 0.15, 0.05 }, { 0.25, 0.3, 0.08 }, { 0.38, 0.32, 0.08 }, { 0.42, 0.46, 0.1 },
            { 0.25, 0.22, 0.1 }, { 0.1, 0.1, 0.12 } } },
    { key = "blow", label = "Blow", action = true, move = true,       -- any other ability landing: a firm blow
        steps = { { 0.65, 0.6, 0.12 }, { 0, 0, 0.08 }, { 0.15, 0.15, 0.1 } } },
    { key = "judge", label = "Judgement", action = true, move = true, -- a seal let loose: a bright strike
        steps = { { 0.3, 0.3, 0.1 }, { 1, 1, 0.12 }, { 0.5, 0.5, 0.1 }, { 0.2, 0.2, 0.12 } } },
    { key = "ward", label = "Ward", action = true, move = true,       -- a shield raised around you
        steps = { { 0.2, 0.2, 0.12 }, { 0.4, 0.4, 0.15 }, { 0.2, 0.2, 0.12 } } },
    { key = "hex", label = "Hex", action = true, move = true,         -- a curse, a poison, a mark: something creeping in
        steps = { { 0.3, 0.05, 0.12 }, { 0.1, 0, 0.12 }, { 0.25, 0.05, 0.12 }, { 0.05, 0, 0.12 } } },
}

-- Swings, by melee weapon (Auto attack's "Match the weapon"): a quick
-- one-hander a faint slash, a slow two-hander a long hit (the player's ask)
for _, p in ipairs({
    { key = "swDagger", art = "stab", label = "Dagger", steps = { { 0.12, 0.12, 0.1 } } },
    { key = "swFist", art = "bash", label = "Fist", steps = { { 0.15, 0.12, 0.1 } } },
    { key = "swSword", art = "slash", label = "Light slash", steps = { { 0.12, 0.2, 0.1 } } },
    { key = "swAxe", art = "cleave", label = "Chop", steps = { { 0.3, 0.25, 0.1 } } },
    { key = "swMace", art = "hammer", label = "Knock", steps = { { 0.35, 0.3, 0.12 } } },
    { key = "swSword2", art = "slash", label = "Heavy slash", steps = { { 0.6, 0.5, 0.2 } } },
    { key = "swAxe2", art = "cleave", label = "Heavy chop", steps = { { 0.75, 0.6, 0.22 } } },
    { key = "swMace2", art = "slam", label = "Thud", steps = { { 0.9, 0.8, 0.28 } } },
    { key = "swPolearm", art = "whirl", label = "Sweep", steps = { { 0.5, 0.5, 0.2 } } },
    { key = "swStaff", art = "bash", label = "Staff", steps = { { 0.3, 0.3, 0.15 } } },
}) do
    p.action, p.swing = true, true
    V.PATTERNS[#V.PATTERNS + 1] = p
end

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
    slam = { 6343 },                                        -- Thunder Clap
    -- Ground effects with no direct hit, felt as you lay them down: Consecration
    surge = { 26573 },
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
    judge = { 20271, 20066, 3044 },                         -- Judgement, Repentance, Arcane Shot
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
    p.icon = VIBE_ICONS .. (p.art or p.key)
    PATTERN[p.key] = p
end

-- Each pattern as pulses, for the Beta engine (Haptics.lua): { t, length,
-- strength, side -1 left .. 1 right }. Rhythm and contrast (the player,
-- 2026-11-16): faint 50 ms micro taps for small things, long rumbles for big
-- ones. Through the game a pulse under 50 ms is often lost and a strength
-- changing while it runs is smoothed away (docs/HAPTICS.md). The steps above
-- stay for when the engine is off. cycle: a loop's length.
local function Pu(t, len, s, side) return { t, len, s, side or 0 } end
local PULSES = {
    micro = { Pu(0, 0.05, 0.08) },
    tick = { Pu(0, 0.05, 0.2) },
    double = { Pu(0, 0.05, 0.3), Pu(0.12, 0.05, 0.3) },
    pulse = { Pu(0, 0.15, 0.5) },
    long = { Pu(0, 0.6, 0.6) },
    heart = { cycle = 0.9, Pu(0, 0.12, 0.7, -0.3), Pu(0.25, 0.05, 0.2, -0.3) },
    rise = { Pu(0, 0.05, 0.1), Pu(0.15, 0.05, 0.2), Pu(0.28, 0.05, 0.35), Pu(0.4, 0.5, 1) },
    impact = { Pu(0, 0.25, 1) },
    critHit = { Pu(0, 0.08, 1), Pu(0.14, 0.05, 0.3), Pu(0.24, 0.05, 0.12) },
    triple = { Pu(0, 0.05, 0.25), Pu(0.1, 0.05, 0.25), Pu(0.2, 0.05, 0.25) },
    purr = { cycle = 0.56, Pu(0, 0.05, 0.06), Pu(0.28, 0.05, 0.04) },
    sweep = { cycle = 0.6, Pu(0, 0.05, 0.12, -1), Pu(0.15, 0.05, 0.12), Pu(0.3, 0.05, 0.12, 1), Pu(0.45, 0.05, 0.12) },
    fade = { Pu(0, 0.3, 0.9), Pu(0.4, 0.05, 0.25), Pu(0.52, 0.05, 0.12), Pu(0.64, 0.05, 0.06) },
    -- Gathering and crafting, while the cast lasts
    pluck = { cycle = 0.85, Pu(0, 0.05, 0.07, -0.4), Pu(0.11, 0.05, 0.1, 0.4), Pu(0.2, 0.05, 0.06, -0.2),
        Pu(0.45, 0.12, 0.35) },
    -- (a short firm knock, a faint ring: in game the old 150 ms hit at 90%
    -- felt like a plain rumble; a cast with known timing strikes in time
    -- with the swings instead, V.StrikeAt)
    pickaxe = { cycle = 1, Pu(0, 0.055, 0.45), Pu(0.1, 0.05, 0.07) },
    skin = { cycle = 0.45, Pu(0, 0.05, 0.15, -0.8), Pu(0.15, 0.05, 0.15, 0.8) },
    reel = { cycle = 1.2, Pu(0, 0.05, 0.05), Pu(0.6, 0.05, 0.05), Pu(0.75, 0.1, 0.25) },
    -- (the cast, once: the pole drawn back over the left shoulder, faint; whipped forward, one
    -- firm short pulse; the line leaving the tip toward the right hand, the spool running out in
    -- faint ticks slowing down. WoW Helper carries it on into R2's own buzz; the bobber's
    -- landing is a moment of its own, Bobber lands)
    flick = { cycle = 1.25, Pu(0, 0.12, 0.08, -0.5), Pu(0.14, 0.05, 0.12, -0.3), Pu(0.24, 0.12, 0.85, 0.2),
        Pu(0.38, 0.05, 0.2, 0.6), Pu(0.48, 0.05, 0.12, 0.8), Pu(0.56, 0.05, 0.09, 0.9), Pu(0.65, 0.05, 0.07, 1),
        Pu(0.75, 0.05, 0.05, 1), Pu(0.87, 0.05, 0.04, 1) },
    click = { cycle = 0.9, Pu(0, 0.05, 0.1), Pu(0.3, 0.05, 0.1), Pu(0.5, 0.12, 0.3) },
    -- (crafts last long and repeat: faint, each its own rhythm and material)
    hammer = { cycle = 0.8, Pu(0, 0.08, 0.4), Pu(0.25, 0.05, 0.1) },
    sew = { cycle = 0.6, Pu(0, 0.05, 0.08, -0.3), Pu(0.1, 0.05, 0.06, 0.3), Pu(0.2, 0.05, 0.08, -0.3) },
    punch = { cycle = 0.6, Pu(0, 0.08, 0.3), Pu(0.2, 0.05, 0.08) },
    bubble = { cycle = 0.7, Pu(0, 0.05, 0.08, -0.6), Pu(0.17, 0.05, 0.12, 0.5), Pu(0.3, 0.05, 0.06, -0.1),
        Pu(0.5, 0.05, 0.1, 0.7) },
    sizzle = { cycle = 0.4, Pu(0, 0.05, 0.06, -0.5), Pu(0.1, 0.05, 0.08, 0.5), Pu(0.2, 0.05, 0.05, -0.2),
        Pu(0.3, 0.05, 0.07, 0.3) },
    gears = { cycle = 0.4, Pu(0, 0.05, 0.12, -0.6), Pu(0.2, 0.05, 0.12, 0.6) },
    shimmer = { cycle = 0.84, Pu(0, 0.05, 0.05), Pu(0.12, 0.05, 0.1), Pu(0.24, 0.05, 0.16), Pu(0.36, 0.05, 0.1),
        Pu(0.48, 0.05, 0.05) },
    -- (first aid: cloth wound round, side to side, then pulled taut)
    wrap = { cycle = 1.2, Pu(0, 0.18, 0.06, -0.6), Pu(0.3, 0.18, 0.08, 0.6), Pu(0.62, 0.08, 0.2) },
    -- (smelting: a deep slow heave of the bellows, the coals answering faintly)
    bellows = { cycle = 1.4, Pu(0, 0.35, 0.25, -0.5), Pu(0.45, 0.25, 0.1, -0.3), Pu(0.95, 0.05, 0.05, 0.5) },
    -- (a craft's finish, once)
    quench = { Pu(0, 0.05, 0.3), Pu(0.08, 0.15, 0.1, 0.4), Pu(0.26, 0.2, 0.04, 0.6) },
    snip = { Pu(0, 0.05, 0.15, 0.3), Pu(0.09, 0.05, 0.1, 0.3) },
    cinch = { Pu(0, 0.1, 0.25), Pu(0.16, 0.05, 0.06) },
    cork = { Pu(0, 0.05, 0.08), Pu(0.07, 0.06, 0.25) },
    plate = { Pu(0, 0.06, 0.18), Pu(0.14, 0.05, 0.06) },
    clunk = { Pu(0, 0.05, 0.1, -0.4), Pu(0.1, 0.1, 0.3, 0.2) },
    chime = { Pu(0, 0.05, 0.18), Pu(0.15, 0.05, 0.09), Pu(0.3, 0.05, 0.04) },
    tie = { Pu(0, 0.12, 0.15), Pu(0.2, 0.05, 0.07) },
    pour = { Pu(0, 0.3, 0.2, -0.3), Pu(0.38, 0.05, 0.1) },
    chew = { cycle = 1.9, Pu(0, 0.1, 0.3), Pu(0.25, 0.05, 0.08), Pu(0.55, 0.05, 0.08) },
    gulp = { cycle = 1.9, Pu(0, 0.05, 0.1), Pu(0.2, 0.1, 0.3) },
    -- Spell families (a cast's taps follow them, faint, building up)
    kindle = { cycle = 0.6, Pu(0, 0.05, 0.12, -0.3), Pu(0.09, 0.05, 0.08, 0.4), Pu(0.24, 0.05, 0.18, 0),
        Pu(0.38, 0.05, 0.1, 0.6) },
    frost = { cycle = 0.7, Pu(0, 0.05, 0.06, 0.6), Pu(0.35, 0.05, 0.08, 0.8) },
    arcane = { cycle = 0.3, Pu(0, 0.05, 0.15, -1), Pu(0.15, 0.05, 0.15, 1) },
    shadow = { cycle = 0.9, Pu(0, 0.2, 0.3, -0.6), Pu(0.45, 0.05, 0.08, -0.6) },
    radiance = { cycle = 0.8, Pu(0, 0.05, 0.05), Pu(0.15, 0.05, 0.1), Pu(0.3, 0.05, 0.16), Pu(0.45, 0.12, 0.22) },
    mend = { cycle = 1, Pu(0, 0.08, 0.2), Pu(0.5, 0.05, 0.06) },
    static = { cycle = 0.5, Pu(0, 0.05, 0.12, -0.7), Pu(0.08, 0.05, 0.2, 0.6), Pu(0.2, 0.05, 0.1, 0),
        Pu(0.3, 0.05, 0.25, -0.4), Pu(0.41, 0.05, 0.1, 0.8) },
    draw = { 0.05, 0.08, 0.12, 0.16, 0.2 },   -- (tightening: built below)
    hearth = { cycle = 1.2, Pu(0, 0.05, 0.04), Pu(0.3, 0.05, 0.08), Pu(0.6, 0.05, 0.12), Pu(0.9, 0.05, 0.15) },
    ritual = { cycle = 1, Pu(0, 0.15, 0.5, -0.5), Pu(0.5, 0.15, 0.5, 0.5) },
    -- Shots
    string = { Pu(0, 0.05, 0.5, 0.6), Pu(0.08, 0.05, 0.15, 0.6), Pu(0.16, 0.05, 0.06, 0.6) },
    latch = { Pu(0, 0.05, 0.3), Pu(0.1, 0.12, 0.6) },
    recoil = { Pu(0, 0.2, 1), Pu(0.28, 0.05, 0.15) },
    zap = { Pu(0, 0.05, 0.3, 0.3), Pu(0.08, 0.05, 0.2, -0.3), Pu(0.16, 0.05, 0.1, 0.3) },
    toss = { Pu(0, 0.05, 0.08), Pu(0.1, 0.1, 0.45) },
    -- Moves
    slash = { Pu(0, 0.05, 0.08), Pu(0.1, 0.18, 0.9), Pu(0.33, 0.05, 0.12) },
    cleave = { Pu(0, 0.12, 0.7, -1), Pu(0.14, 0.05, 0.3), Pu(0.22, 0.12, 0.7, 1) },
    stab = { Pu(0, 0.1, 0.6, 0.3) },
    blow = { Pu(0, 0.12, 0.65), Pu(0.2, 0.05, 0.15) },
    -- (a firm low push into the ground, then a warm spread out to both sides)
    surge = { Pu(0, 0.2, 0.75), Pu(0.28, 0.05, 0.2, -0.7), Pu(0.28, 0.05, 0.2, 0.7), Pu(0.42, 0.05, 0.1, -1),
        Pu(0.42, 0.05, 0.1, 1) },
    -- (a sharp strike, then the fire rising and rolling side to side, fading)
    pillar = { Pu(0, 0.05, 0.7), Pu(0.1, 0.06, 0.25, -0.4), Pu(0.17, 0.06, 0.34, 0.4), Pu(0.24, 0.07, 0.42, -0.3),
        Pu(0.32, 0.08, 0.36, 0.3), Pu(0.42, 0.1, 0.2), Pu(0.54, 0.1, 0.1) },
    rend = { Pu(0, 0.05, 0.3, -0.6), Pu(0.08, 0.05, 0.3, 0.6), Pu(0.16, 0.05, 0.25, -0.6), Pu(0.24, 0.05, 0.15, 0.6) },
    slam = { Pu(0, 0.3, 1), Pu(0.4, 0.05, 0.2), Pu(0.52, 0.05, 0.1), Pu(0.64, 0.05, 0.05) },
    bash = { Pu(0, 0.2, 1, -0.3), Pu(0.3, 0.05, 0.12) },
    charge = { Pu(0, 0.05, 0.08), Pu(0.2, 0.05, 0.12), Pu(0.35, 0.05, 0.18), Pu(0.46, 0.05, 0.25), Pu(0.55, 0.15, 1) },
    whirl = { Pu(0, 0.05, 0.2, -1), Pu(0.1, 0.05, 0.2), Pu(0.2, 0.05, 0.2, 1), Pu(0.3, 0.05, 0.2), Pu(0.4, 0.05, 0.2, -1),
        Pu(0.5, 0.05, 0.06) },
    flurry = { Pu(0, 0.05, 0.2, -0.3), Pu(0.1, 0.05, 0.2, 0.3), Pu(0.2, 0.05, 0.25), Pu(0.3, 0.2, 0.9) },
    shock = { Pu(0, 0.05, 0.3, -0.5), Pu(0.07, 0.08, 0.6, 0.5), Pu(0.2, 0.05, 0.1) },
    burst = { Pu(0, 0.25, 0.9), Pu(0.35, 0.05, 0.2), Pu(0.47, 0.05, 0.1) },
    seal = { Pu(0, 0.05, 0.05), Pu(0.12, 0.05, 0.1), Pu(0.24, 0.05, 0.18), Pu(0.36, 0.12, 0.35) },
    judge = { Pu(0, 0.05, 0.15), Pu(0.1, 0.25, 1), Pu(0.42, 0.05, 0.15) },
    ward = { Pu(0, 0.05, 0.1), Pu(0.12, 0.3, 0.4) },
    hex = { Pu(0, 0.05, 0.08, -0.5), Pu(0.2, 0.05, 0.06, -0.5), Pu(0.4, 0.05, 0.1, -0.5), Pu(0.6, 0.05, 0.05, -0.5) },
    -- Swings: quick and faint for light weapons, long for heavy ones
    swDagger = { Pu(0, 0.05, 0.07) },
    swFist = { Pu(0, 0.05, 0.1) },
    swSword = { Pu(0, 0.05, 0.06), Pu(0.07, 0.05, 0.12) },
    swAxe = { Pu(0, 0.07, 0.25) },
    swMace = { Pu(0, 0.05, 0.06), Pu(0.08, 0.09, 0.32) },
    swSword2 = { Pu(0, 0.05, 0.1), Pu(0.1, 0.18, 0.55), Pu(0.33, 0.05, 0.1) },
    swAxe2 = { Pu(0, 0.05, 0.1), Pu(0.1, 0.22, 0.7) },
    swMace2 = { Pu(0, 0.3, 0.9), Pu(0.4, 0.05, 0.14), Pu(0.52, 0.05, 0.06) },
    swPolearm = { Pu(0, 0.05, 0.12, -0.6), Pu(0.08, 0.16, 0.5, 0.6) },
    swStaff = { Pu(0, 0.12, 0.3) },
}
-- (draw: an aimed shot, the string tightening: taps closer and stronger)
do
    local list, t = { cycle = 1.1 }, 0
    for i, s in ipairs(PULSES.draw) do
        list[#list + 1] = Pu(t, 0.05, s)
        t = t + 0.3 - 0.05 * i
    end
    PULSES.draw = list
end
for key, list in pairs(PULSES) do
    local p = PATTERN[key]
    if p then
        local pulses = {}
        for i, pulse in ipairs(list) do pulses[i] = pulse end
        p.feel = { pulses = pulses, length = list.cycle, gap = list.cycle and 0 or nil, label = p.label, icon = p.icon }
    end
end
V.PULSES = PULSES

-- The events, by group (Easy Controller's groups and naming), each with its
-- default state and pattern
V.GROUPS = {
    { key = "combat", label = "Combat" },
    { key = "casting", label = "Casting" },
    { key = "rest", label = "Food & drink" },
    { key = "wheel", label = "Halo rings" },
    { key = "progress", label = "Progress" },
}
V.EVENTS = {
    { key = "crit", group = "combat", label = "Critical hit: melee", icon = EVENT_ICONS .. "crit", on = true,
        combo = true, pattern = "critHit", tip = "Your melee lands a critical hit: a swing or a melee ability (in"
            .. " WoW Forever: your target takes a critical physical hit while you aren't shooting)." },
    { key = "critRanged", group = "combat", label = "Critical hit: ranged", icon = EVENT_ICONS .. "crit", on = false,
        combo = true, pattern = "critHit", tip = "A shot or a spell of yours lands a critical hit, or a heal"
            .. " a critical heal (in WoW Forever: your target takes one while you shoot, a spell's, or a"
            .. " critical heal lands on you or it). Off by default: Shooting and spell casts have their own." },
    { key = "critted", group = "combat", label = "Critical hit taken", icon = EVENT_ICONS .. "critted", on = true,
        combo = true,
        pattern = "double", tip = "An enemy lands a critical hit on you." },
    { key = "autoAttack", group = "combat", label = "Auto attack", icon = VIBE_ICONS .. "slash", on = false,
        pattern = "auto", auto = "Match the weapon", family = "swing", gap = 0.1, tip = "Each melee swing that lands"
            .. " (hit, miss, dodge...), main hand and off hand. Match the weapon: a dagger or sword a faint"
            .. " slash, a two-handed mace a thud. Off by default." },
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
    { key = "instant", group = "combat", label = "Your abilities", icon = EVENT_ICONS .. "instant", on = true,
        pattern = "auto", auto = "Match the ability", family = "move", gap = 0.15, tip = "Your own attack"
            .. " abilities as they land on your target (Heroic Strike, Sinister Strike, Shield Bash, Cleave,"
            .. " Judgement, Arcane Shot...), at the blow; a seal, a shout, a shield as you use it. Match the"
            .. " ability: each its own feel." },
    { key = "eat", group = "rest", label = "Eating", icon = EVENT_ICONS .. "eat", on = true,
        pattern = "chew", loop = true, family = "rest", tip = "While you sit eating, until you stand up or the"
            .. " food is done. Munch goes with your character: a bite as the hand reaches the mouth, chewing"
            .. " while it stays. Another pattern: played over and over." },
    { key = "drink", group = "rest", label = "Drinking", icon = EVENT_ICONS .. "drink", on = true,
        pattern = "gulp", loop = true, family = "rest", tip = "While you sit drinking, until you stand up or"
            .. " the drink is done. Gulp goes with your character: a sip as the hand reaches the mouth, then"
            .. " a swallow. Another pattern: played over and over. Food and drink at once (a mage's"
            .. " Refreshment, Dim Sum): both, drinking felt over eating." },
    -- Halo's rings (Gamepad Companion; Halo tells, below)
    { key = "haloOpen", group = "wheel", label = "Open a ring", icon = EVENT_ICONS .. "wheel", on = true,
        pattern = "tick", tip = "A Halo ring opens, or another ring takes its place." },
    { key = "wheelTick", group = "wheel", label = "Slot change", icon = VIBE_ICONS .. "micro", on = true,
        pattern = "micro", gap = 0.03, tip = "In an open Halo ring, the pick moves to another slot." },
    { key = "haloUse", group = "wheel", label = "Fire the ring", icon = VIBE_ICONS .. "impact", on = true,
        pattern = "pulse", tip = "A Halo ring closes using its slot: the spell, item or mount goes." },
    { key = "haloClose", group = "wheel", label = "Close the ring", icon = VIBE_ICONS .. "fade", on = false,
        pattern = "micro", tip = "A Halo ring closes without using anything. Off by default." },
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
    { key = "fishing", label = "Fishing", kind = "gather", pattern = "flick", spell = 7620 },
    { key = "opening", label = "Opening", kind = "gather", pattern = "click", spell = 3365 },
    -- (a craft: its loop while making, its finish once as it's made)
    { key = "blacksmithing", label = "Blacksmithing", kind = "craft", pattern = "hammer", finish = "quench", spell = 2018 },
    { key = "tailoring", label = "Tailoring", kind = "craft", pattern = "sew", finish = "snip", spell = 3908 },
    { key = "leatherworking", label = "Leatherworking", kind = "craft", pattern = "punch", finish = "cinch", spell = 2108 },
    { key = "alchemy", label = "Alchemy", kind = "craft", pattern = "bubble", finish = "cork", spell = 2259 },
    { key = "cooking", label = "Cooking", kind = "craft", pattern = "sizzle", finish = "plate", spell = 2550 },
    { key = "engineering", label = "Engineering", kind = "craft", pattern = "gears", finish = "clunk", spell = 4036 },
    { key = "enchanting", label = "Enchanting", kind = "craft", pattern = "shimmer", finish = "chime", spell = 7411 },
    { key = "firstaid", label = "First Aid", kind = "craft", pattern = "wrap", finish = "tie", spell = 3273 },
    -- (Mining's smelting: its window is Smelting's, its casts Smelt Copper... below)
    { key = "smelting", label = "Smelting", kind = "craft", pattern = "bellows", finish = "pour", spell = 2656 },
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
-- Any feel as a cast set ("feel:<pattern>", the Feel picker on a cast-time
-- row): it plays while casting, with the usual alerts when it ends badly
setmetatable(PRESET, { __index = function(t, key)
    local pattern = type(key) == "string" and key:match("^feel:(.+)$")
    if not pattern then return nil end
    local p = { key = key, label = pattern, feel = true, cast = pattern, interrupted = "impact", cancelled = "micro",
        pushback = "tick", icon = VIBE_ICONS .. "pulse" }
    rawset(t, key, p)
    return p
end })
function V.FeelSet(pattern) return "feel:" .. pattern end
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
            .. " own feel. Fishing: the cast, the bobber landing, nibbles while you wait, the catch." },
    { key = "craft", label = "Crafting", icon = EVENT_ICONS .. "craft", preset = "auto",
        tip = "Making something with a profession (cast with its window open)." },
}
local CAST_KIND = {}
for _, k in ipairs(V.CAST_KINDS) do CAST_KIND[k.key] = k end

-- Gathering's and Crafting's actions, each a moment of its own under its kind
-- ("gather:mining", "craft:cooking", as a spell is: UX.md §9): its own feel, sound and
-- volumes, its kind's until it has its own. The feel: V.Settings().gatherFeels[action] =
-- a pattern or "off" (crafts too: one table, the action keys never meet)
V.GATHER_ACTIONS, V.CRAFT_ACTIONS = {}, {}
local GATHER_ACTION, ACTION_KIND, ACTION = {}, {}, {}
for _, a in ipairs(V.CAST_ACTIONS) do
    if a.kind == "gather" then
        V.GATHER_ACTIONS[#V.GATHER_ACTIONS + 1] = a
        GATHER_ACTION[a.key] = a
    elseif a.kind == "craft" then
        V.CRAFT_ACTIONS[#V.CRAFT_ACTIONS + 1] = a
    end
    if a.kind == "gather" or a.kind == "craft" then ACTION_KIND[a.key], ACTION[a.key] = a.kind, a end
end
-- The actions under a kind ("gather", "craft"), in order
function V.KindActions(kind)
    return kind == "gather" and V.GATHER_ACTIONS or kind == "craft" and V.CRAFT_ACTIONS or nil
end
function V.GatherKey(action) return GATHER_ACTION[action] and ("gather:" .. action) or nil end
-- An action's own moment ("craft:cooking"; nil: none)
function V.ActionKey(action) return ACTION_KIND[action] and (ACTION_KIND[action] .. ":" .. action) or nil end
-- "craft:cooking" -> "cooking", "craft" (nil: not an action's moment)
function V.ActionOf(key)
    local kind, a = (type(key) == "string" and key or ""):match("^(%a+):(%a+)$")
    if a and ACTION_KIND[a] == kind then return a, kind end
    return nil
end
function V.GatherAction(action) return ACTION[action] end
-- The moment a cast's cue goes as now: its action's own, else its kind
function V.CastMomentKey()
    local own = V.castAction and ACTION_KIND[V.castAction] == V.castKind and V.ActionKey(V.castAction)
    return own or V.castKind
end
-- An action's own feel (a pattern, "off"), nil: its kind's
function V.ActionFeel(action)
    local own = V.Settings().gatherFeels[action]
    return type(own) == "string" and own or nil
end
-- What an action plays with its kind's set (nil: nothing)
local function InheritedPattern(action)
    local preset = PRESET[V.CastPreset(ACTION_KIND[action])]
    if not preset or preset.key == "off" then return nil end
    if preset.auto then preset = PRESET[action] end
    return preset and preset.cast or nil
end
-- What an action plays now (nil: nothing): its own while its kind is on, else its kind's
function V.ActionPattern(action)
    if not ACTION_KIND[action] then return nil end
    local inherited = InheritedPattern(action)
    local own = V.ActionFeel(action)
    if own == nil or V.CastPreset(ACTION_KIND[action]) == "off" then return inherited end
    if own == "off" then return nil end
    return own
end
-- pattern: its own ("off": none), nil or what its kind plays: its kind's
function V.SetActionFeel(action, pattern)
    if not ACTION_KIND[action] then return end
    if pattern ~= nil and pattern ~= "off" and pattern == InheritedPattern(action) then pattern = nil end
    V.Settings().gatherFeels[action] = pattern
end
-- A craft's finish, once as it's made (nil: none; not while it's off)
function V.CraftFinish(action)
    local a = ACTION[action]
    if not (a and a.kind == "craft" and a.finish) then return nil end
    if not V.ActionPattern(action) then return nil end
    return a.finish
end

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

-- Defaults that changed (the old pattern, a version number)
V.MOVED = { crit = { from = "tick", v = 1 }, critRanged = { from = "tick", v = 1 } }

-- db.vibration = { enabled, intensity, events = { key = { on, pattern } } }
local checked   -- (the vibration table last validated: the shaper asks every frame)
function V.Recheck() checked = nil end
function V.Settings()
    local s = IF.db.vibration
    if s and checked == s then return s end
    IF.db.fishLog, IF.db.eatLog = nil, nil   -- (logs of probes, since removed)
    IF.db.vibration = IF.db.vibration or {}
    s = IF.db.vibration
    if s.enabled == nil then s.enabled = true end
    s.casts = s.casts or {}
    if type(s.gatherFeels) ~= "table" then s.gatherFeels = {} end
    for _, k in ipairs(V.CAST_KINDS) do
        if not PRESET[s.casts[k.key]] then s.casts[k.key] = k.preset end
    end
    s.intensity = s.intensity or 0.8
    s.strikes = s.strikes or {}
    -- (timing is WoW Helper's now: a mining timing once synced or set here goes, once)
    -- (and once more (night review 2 H2-5): set in Lab after that and before 0.52.3,
    -- when its controls went, nothing was left to clear it)
    if s.ownTimingCleared ~= 2 then
        for k in pairs(s.strikes) do s.strikes[k] = nil end
        s.ownTimingCleared = 2
    end
    s.hitTiming = s.hitTiming or {}
    s.events = s.events or {}
    for _, e in ipairs(V.EVENTS) do
        local cfg = s.events[e.key]
        if type(cfg) ~= "table" then
            cfg = { on = e.on, pattern = e.pattern }
            s.events[e.key] = cfg
        end
        -- (a default that changed: a saved pattern still on the old default
        -- moves to the new one, once; one picked by hand stays)
        local moved = V.MOVED[e.key]
        if moved and (cfg.moved or 0) < moved.v then
            if cfg.pattern == moved.from then cfg.pattern = e.pattern end
            cfg.moved = moved.v
        end
        -- (a Beta feel, "x_...": kept, even before the Beta tab registers it)
        if not (PATTERN[cfg.pattern] or (e.auto and cfg.pattern == "auto")
            or (type(cfg.pattern) == "string" and cfg.pattern:match("^x_"))) then cfg.pattern = e.pattern end
    end
    checked = s
    return s
end

function V.Pattern(key)
    return PATTERN[key]
end

-- A Beta feel (Haptics.lua) as a pattern: in the grid while the Beta engine
-- is on, played by the mixer at frame rate. steps: a stand-in for the
-- shapes that read a pattern's steps (a cast's ripple).
function V.AddFeel(key, feel)
    local p = PATTERN[key]
    if not p then
        p = { key = key }
        V.PATTERNS[#V.PATTERNS + 1] = p
        PATTERN[key] = p
    end
    p.label, p.icon, p.feel, p.beta = feel.label or key, feel.icon or (VIBE_ICONS .. "pulse"), feel, true
    p.steps, p.length, p.top = { { 0.5, 0.5, 0.1 } }, nil, nil
    return p
end

-- A kind of cast's set ("off": none)
function V.CastPreset(kind)
    return V.Settings().casts[kind or "spell"] or "off"
end

function V.SetCastPreset(kind, presetKey)
    V.Settings().casts[kind] = PRESET[presetKey] and presetKey or "off"
end

function V.Preset(key)
    local p = PRESET[key]
    -- (a feel's set: named and drawn as its feel, once that feel is known)
    if p and p.feel then
        local pat = V.Pattern and V.Pattern(p.cast)
        if pat then p.label, p.icon = pat.label, pat.icon end
    end
    return p
end

-- The cast in progress' kind (Gathering, Crafting...; spell by default)
-- and action (Mining, Tailoring...; nil for a spell)
V.castKind = "spell"
V.castAction = nil

-- Match the weapon: the ranged weapon equipped's pattern (a bow's when
-- there is none to tell)
local WEAPON_PATTERNS = { [2] = "string", [18] = "latch", [3] = "recoil", [19] = "zap", [16] = "toss" }

-- Melee: the weapon in a hand's pattern (slot 16 main hand, 17 off hand;
-- no weapon: a fist). Item subclasses: 0 axe, 1 two-handed axe, 4 mace, 5
-- two-handed mace, 6 polearm, 7 sword, 8 two-handed sword, 10 staff, 13 fist,
-- 15 dagger
local SWING_PATTERNS = { [0] = "swAxe", [1] = "swAxe2", [4] = "swMace", [5] = "swMace2", [6] = "swPolearm",
    [7] = "swSword", [8] = "swSword2", [10] = "swStaff", [13] = "swFist", [15] = "swDagger" }

function V.SwingPattern(slot)
    local id = GetInventoryItemID and GetInventoryItemID("player", slot or 16)
    local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if id and info then
        local classID, subclassID = select(6, info(id))
        if classID == 2 and SWING_PATTERNS[subclassID] then return SWING_PATTERNS[subclassID] end
    end
    return "swFist"
end

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
        local preset = PRESET[V.castSet or V.CastPreset(V.castKind)]
        -- (a gathering action's own feel, while Gathering is on: its set)
        local own = not V.castSet and V.castAction and ACTION_KIND[V.castAction] == V.castKind
            and V.ActionFeel(V.castAction)
        if own and preset and preset.key ~= "off" then
            if own == "off" then return nil end
            preset = PRESET[V.FeelSet(own)]
        elseif preset and preset.auto then
            local kind = CAST_KIND[V.castKind]
            preset = PRESET[V.castAction] or PRESET[kind and kind.fallback or "subtle"]
        end
        return preset and preset[PHASE[eventKey]] or nil
    end
    local choice = V.EventChoice(eventKey)
    if choice == "off" then return nil end
    if choice == "auto" then
        if eventKey == "shot" then return WeaponPattern() end
        if eventKey == "autoAttack" then return V.SwingPattern(V.swingSlot or 16) end
        return V.instantMove
    end
    return choice
end

-- An event as Recommended for this class (Profiles.lua: the same the profile's Reset gives)
function V.DefaultOn(eventKey)
    local P = ns.Profiles
    local on = P and P.RecommendedOn and P.RecommendedOn("vibration", eventKey)
    if on == nil then
        for _, e in ipairs(V.EVENTS) do if e.key == eventKey then on = e.on end end
    end
    return on
end
function V.IsEventDefault(eventKey)
    local cfg = V.Settings().events[eventKey]
    local e
    for _, x in ipairs(V.EVENTS) do if x.key == eventKey then e = x end end
    return cfg.on == V.DefaultOn(eventKey) and cfg.pattern == e.pattern
end
function V.EventDefault(eventKey)
    local cfg = V.Settings().events[eventKey]
    for _, e in ipairs(V.EVENTS) do if e.key == eventKey then cfg.pattern = e.pattern end end
    cfg.on = V.DefaultOn(eventKey)
end

-- A pattern for an event ("off": none)
function V.SetEventPattern(eventKey, patternKey)
    local cfg = V.Settings().events[eventKey]
    if patternKey == "off" then
        cfg.on = false
    else
        cfg.on, cfg.pattern = true, patternKey
    end
    V.Recheck()   -- (a pattern Settings checks)
end

---------------------------------------------------------------------------
-- Playing a pattern
---------------------------------------------------------------------------
local timers = {}

-- Low drives the left grip, High the right (a DualSense, /if vibe). The
-- right one is felt only from about half strength: any non-zero value is
-- lifted into that range, so both sides feel alike.
local HIGH_FLOOR = 0.5

-- The Beta engine's mixer (Haptics.lua), when it has the motors: our levels
-- go in as one of its voices, its calibration doing the floor
local function Mixer()
    local H = ns.Haptics
    return H and H.Routing() and H or nil
end

local function motors(low, high)
    -- (no pad API on this client: nothing to drive)
    if not (C_GamePad and C_GamePad.SetVibration) then return end
    local H = Mixer()
    if H then return H.Set("rumble", low, high) end
    -- (the Feel channel: Hush, Resting 30 %… Hush.lua; the mixer applies it itself)
    local scale = ns.FeelScale and ns.FeelScale() or 1
    low, high = low * scale, high * scale
    if high > 0 then high = HIGH_FLOOR + (1 - HIGH_FLOOR) * high end
    C_GamePad.SetVibration("Low", low)
    C_GamePad.SetVibration("High", high)
end

-- The motors off (ours only, under the mixer)
local function silence()
    local H = Mixer()
    if H then return H.Set("rumble", 0, 0) end
    if C_GamePad and C_GamePad.StopVibration then C_GamePad.StopVibration() end
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
local shapeFn, shapeOnce = nil, false

local function StopShape()
    shapeFn = nil
    shaper:Hide()
end

function V.Stop()
    StopShape()
    for _, t in ipairs(timers) do t:Cancel() end
    wipe(timers)
    if ns.Haptics then ns.Haptics.Stop("rumbleFeel") end
    silence()
end

local shapeScale = 1
local function StartShape(fn, once, scale)
    V.Stop()
    shapeFn, shapeOnce, shapeScale = fn, once, scale or 1
    shaper:Show()
end

-- Full feels (FullFeel.lua): a moment's plain rumble from WoW Helper, and its scale (faint
-- under HD); nil without one (it plays as before)
local function Plain(key)
    local F = ns.FullFeel
    if F then return F.Rumble(key) end
end
-- A plain rumble once, at `scale` (the moment's volume, faint under HD)
function V.PlayPlain(points, scale)
    local F = ns.FullFeel
    if not (F and C_GamePad and C_GamePad.SetVibration) then return end
    StartShape(F.Shape(points, 1, GetTime()), true, scale)
end

shaper:SetScript("OnUpdate", function()
    if not shapeFn then return shaper:Hide() end
    local now = GetTime()
    local low, high = shapeFn(now)
    if not low then
        local resume = shapeOnce and V.looping
        StopShape()
        silence()
        if resume then Resume(resume) end
        return
    end
    local gain = V.Settings().intensity * shapeScale
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
    later(0.22, silence)
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
    -- A Beta feel: the mixer plays it (a loop: over and over; once: then
    -- back to the loop under it)
    if pattern.beta and not Mixer() then pattern = PATTERN.tick end
    if pattern.feel and Mixer() then
        ns.Haptics.Play(pattern.feel, { voice = "rumbleFeel", gain = gain, left = left, right = right,
            stretch = stretch, loop = loop and true or false, onDone = function()
                if not loop and V.looping then Resume(V.looping) end
            end })
        return
    end
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
        later(t, silence)
        later(t + 0.12, function() V.Play(key, true, shape) end)
    else
        later(t, function()
            silence()
            -- Over a looping event (a cast still going): back to its loop
            if V.looping then Resume(V.looping) end
        end)
    end
end

-- A loop: its shape (a spell's, below) or its pattern, over and over
Resume = function(loop)
    if loop.shape then
        StartShape(loop.shape, nil, loop.gain)
    else
        V.Play(loop.pattern, true, loop.gain and { strength = loop.gain } or nil)
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

-- (as pulses, rhythm and contrast: a cast's faint taps build up, the release
-- is a long hit trailing off in taps; a channel's ticks each a short pulse)
local PULSE = 0.055
local RELEASE_LONG, RELEASE_END = 0.28, 0.7
local RELEASE_TAPS = { { 0.38, 0.2 }, { 0.5, 0.1 }, { 0.62, 0.05 } }
local releasedAt = -math.huge

-- What is left of the last release d seconds on: a long hit, then taps
local function ReleaseEnv(d)
    if d < 0 or d >= RELEASE_END then return 0 end
    if d < RELEASE_LONG then return 1 end
    for _, tap in ipairs(RELEASE_TAPS) do
        if d >= tap[1] and d < tap[1] + PULSE then return tap[2] end
    end
    return 0
end

-- The spell family's own rhythm (fire's crackle, frost's sparse ticks...)
-- at t seconds into the cast, or nil
local function Family(t)
    local key = cast.timing and cast.timing.texture
    local p = key and PATTERN[key]
    local H = ns.Haptics
    if not (p and p.feel and H) then return nil end
    return H.Sample(p.feel, t % H.Length(p.feel), 1)
end

-- A cast: the family's faint rhythm, stronger toward the release (plain taps,
-- closer and closer, when it has none); a release just before trailing off
local function BuildUp(now)
    local t = cast.timing
    local span = t.finish - t.start
    local p = span > 0 and math.max(0, math.min(1, (now - t.start) / span)) or 1
    local g = 0.35 + 0.65 * p ^ 1.5
    local low, high = Family(now - t.start)
    if low then
        low, high = low * g, high * g
    else
        local interval = 0.4 - 0.27 * p
        if not cast.beatAt or now - cast.beatAt >= interval then cast.beatAt = now end
        local a = now - cast.beatAt < PULSE and (0.05 + 0.3 * p * p) or 0
        low, high = a, a
    end
    local tail = ReleaseEnv(now - releasedAt)
    return math.max(low, tail), math.max(high, tail)
end

-- A channel: the family's rhythm, faint; each tick a short pulse, left and
-- right by turns, as missiles fly from either hand
local function Missiles(now)
    local t = cast.timing
    local since = now - t.start
    local ticks = math.floor(since / t.interval)
    local low, high = Family(since)
    low, high = (low or 0) * 0.4, (high or 0) * 0.4
    if ticks >= 1 and since - ticks * t.interval < 0.1 then
        local left, right = 0.6, 0.35
        if ticks % 2 == 0 then left, right = 0.35, 0.6 end
        low, high = math.max(low, left), math.max(high, right)
    end
    local tail = ReleaseEnv(now - releasedAt)
    return math.max(low, tail), math.max(high, tail)
end

local function Release(now)
    local d = now - releasedAt
    if d >= RELEASE_END then return nil end
    local env = ReleaseEnv(d)
    return env, env
end

-- Fishing: the throw, the Cast pattern's pulses once (the pole drawn back,
-- whipped forward, the line running out), then nothing: the bobber's landing,
-- the nibbles and the catch are moments of their own (Fishing.lua). (No bite
-- to feel from here: WoW Forever tells addons nothing when a fish bites. The
-- bobber's soft interact state, the events and its cursor icon all stay as
-- they are. WoW Helper hears it.) Side: left (the heavy motor) .. right.
local function Fishing(now)
    local t = now - cast.timing.start
    local list = PULSES.flick
    if t >= list.cycle then return nil end
    for _, p in ipairs(list) do
        if t >= p[1] and t < p[1] + p[2] then
            local side = p[4] or 0
            return p[3] * math.min(1, 1 - side), p[3] * math.min(1, 1 + side)
        end
    end
    return 0, 0
end

---------------------------------------------------------------------------
-- Mining: a strike on each swing of the pickaxe, from the cast's start to
-- its end, then a crack when the ore breaks loose. The swing's period and
-- first strike are a guess until set or synced (squeeze R2 on each strike).
---------------------------------------------------------------------------
-- (measured by WoW Helper, 2026-11-18: the pickaxe heard at +1.42..1.55 s
-- after the cast's start, median 1.49, and again at ~2.85-2.90; the ore
-- breaks at the cast's end, ~3.2 s. The guess was 0.5 s, then every 1 s)
local STRIKES = { mining = { period = 1.4, offset = 1.49 } }
V.STRIKES = STRIKES
-- A strike d seconds on: a short firm knock, then a faint ring
V.STRIKE_KNOCK, V.STRIKE_RING, V.STRIKE_RING_AT = 0.45, 0.07, 0.1
function V.StrikeEnv(d)
    if d < 0 then return 0 end
    if d < PULSE then return V.STRIKE_KNOCK end
    if d >= V.STRIKE_RING_AT and d < V.STRIKE_RING_AT + PULSE then return V.STRIKE_RING end
    return 0
end

-- An action's swing period and first strike (seconds), and whether synced
-- An action's period and first strike, whether synced by you, and where
-- they come from ("synced", "set", "learned": WoW Helper's, "guess")
function V.StrikeTiming(action)
    local guess = STRIKES[action] or STRIKES.mining
    -- (the default: WoW Helper's published one, else the fallback here)
    local d = ns.Timing and ns.Timing.Default(action)
    if d and tonumber(d.first) and tonumber(d.period) then guess = { period = tonumber(d.period), offset = tonumber(d.first) } end
    local cal = V.Settings().strikes[action]
    if type(cal) == "table" then
        local synced = (cal.taps or 0) > 0
        return cal.period or guess.period, cal.offset or guess.offset, synced, synced and "synced" or "set"
    end
    local learned = ns.Timing and ns.Timing.LearnedStrikes and ns.Timing.LearnedStrikes(action)
    if learned then return learned.period, learned.first, false, "learned", learned.strikes end
    return guess.period, guess.offset, false, "guess"
end

-- Set by hand (period or first strike; nil keeps it)
function V.SetStrikeTiming(action, period, offset)
    local all = V.Settings().strikes
    local p, o = V.StrikeTiming(action)
    local cal = type(all[action]) == "table" and all[action] or { taps = 0 }
    cal.period = math.max(0.3, math.min(3, period or p))
    cal.offset = math.max(0, math.min(3, offset or o))
    all[action] = cal
end

-- The strike envelope t seconds into the cast
function V.StrikeAt(t, period, offset)
    if t < offset then return 0 end
    return V.StrikeEnv((t - offset) % period)
end

-- The k-th strike of a cast (seconds after its start) and whether it's the
-- crack: strikes a period apart from the first while one more fits half a
-- period clear of the cast's end, then the crack at the end itself (mining:
-- the first strike at ~1.49 s, then the ore cracking loose as the cast ends;
-- a second strike a period on landed before the crack, the user heard). nil:
-- no more. (WoW Helper's gather::strike_time, the same rule.)
function V.StrikeTimeOf(k, first, period, crack)
    if not crack then return first + k * period, false end
    local periodic = 0
    if first < crack - 0.3 then periodic = 1 + math.max(0, math.floor((crack - 0.5 * period - first) / period)) end
    if k < periodic then return first + k * period, false end
    if k == periodic then return crack, true end
    return nil
end

local function Strikes(now)
    local t = cast.timing
    local period, offset = V.StrikeTiming(t.strikes)
    -- (the clock the link lead ahead; each strike from the frame it begins,
    -- so a slow frame shortens or loses none)
    local at = now + (ns.Timing and ns.Timing.Lead() or 0) - t.start
    local span = t.finish and t.finish > t.start and (t.finish - t.start) or nil
    local k = (t.strikeN or -1) + 1
    local tk, isCrack = V.StrikeTimeOf(k, offset, period, span)
    if tk and at >= tk then
        t.strikeN, t.strikeAt, t.crackNow = k, now, isCrack
        if isCrack then t.cracked = now end
        -- (its HD with it, one per strike: unless WoW Helper plays them)
        if not cast.helperTimed and V.StrikeHD then V.StrikeHD(t.strikes) end
    end
    if not t.strikeAt then return 0, 0 end
    -- (Full feels: each strike and the crack play the action's plain rumble, on the strikes' clock)
    local points, scale = Plain(V.GatherKey(t.strikes) or "gather")
    if points then
        local l, r = ns.FullFeel.Sample(points, now - t.strikeAt)
        if not l then return 0, 0 end
        return l * scale, r * scale
    end
    -- (the last: the ore cracking loose, on the cast's end)
    if t.crackNow then
        local l, r = V.CrackAt(now - t.strikeAt)
        if l then return l, r end
        return 0, 0
    end
    local e = V.StrikeEnv(now - t.strikeAt)
    return e, e
end

-- A strike's HD feel (the pickaxe's) and the action's sound ("gather:mining"),
-- sent with the rumble's strike, the crack too: once a strike (the cast's start
-- sends none: V.cueTimed). The strikes' own clock, not the loop's (each cycle
-- from the cast's start was out of step with the swings)
function V.StrikeHD(action)
    local C, L = ns.HelperCues, ns.HapticsLab
    if not (C and C.Moment and L) then return end
    local p = V.EventPattern("cast")
    if p then C.Moment(V.GatherKey(action) or "gather", L.FeelFor(p)) end
end

-- The ore breaks loose: a longer crack, then crumbling taps left and right
local CRACK = { { 0, 0.2, 0.85, 0 }, { 0.28, 0.05, 0.14, -0.6 }, { 0.38, 0.05, 0.09, 0.6 }, { 0.5, 0.05, 0.05, -0.3 } }
local crackedAt = -math.huge
function V.CrackAt(d)
    for _, p in ipairs(CRACK) do
        if d >= p[1] and d < p[1] + p[2] then
            return p[3] * math.min(1, 1 - p[4]), p[3] * math.min(1, 1 + p[4])
        end
    end
    if d >= 0.6 then return nil end
    return 0, 0
end
local function Crack(now) return V.CrackAt(now - crackedAt) end

-- (at: the crack began then, on the cast's end: it goes on, not again)
function V.Crack(at)
    if not (C_GamePad and C_GamePad.SetVibration and V.Active()) then return end
    crackedAt = at or GetTime()
    StartShape(Crack, true)
end

-- The cast in progress' shape, or nil: its own pattern loops instead (a
-- set other than Match the action, gathering, crafting, a channel whose
-- ticks we don't know, a cast whose timing is hidden)
local function CastShape()
    local t = cast.timing
    if not t then return nil end
    local preset = PRESET[V.castSet or V.CastPreset(V.castKind)]
    if not (preset and preset.auto) then return nil end
    if V.castKind == "gather" and V.castAction == "fishing" and t.channel then
        t.fishing = true
        return Fishing
    end
    if V.castKind == "gather" and STRIKES[V.castAction] and not t.channel then
        t.strikes = V.castAction
        return Strikes
    end
    if V.castKind ~= "spell" then return nil end
    if t.channel and not t.interval then return nil end
    t.texture = V.EventPattern("cast")
    return t.channel and Missiles or BuildUp
end

-- The cast in progress, 0 at its start to 1 at its end (nil: none, or its
-- timing hidden)
function V.CastProgress()
    local t = cast.timing
    if not (t and t.start and t.finish) or t.finish <= t.start then return nil end
    return math.max(0, math.min(1, (GetTime() - t.start) / (t.finish - t.start)))
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
        if d < 0.1 then return 0.3, 0.2 end                       -- the bite
        if d < near then
            -- chewing: a faint tap every 0.3 s
            if (d - 0.1) % 0.3 >= 0.25 then return 0.08, 0.06 end
        end
        return 0, 0
    end
end

local function Gulp(m, timer, start)
    return function(now)
        local d, near = MotionAt(m, timer, start, now)
        if not d then return 0, 0 end
        if d < 0.05 then return 0.08, 0.12 end                     -- the sip
        local swallow = d - near / 2
        if swallow >= 0 and swallow < 0.1 then return 0.25, 0.3 end
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

-- A moment's shape at its own volume (Volume.lua): a copy, strength scaled
-- (extra: a spell's own volume, over the moment's)
function V.Scaled(shape, eventKey, extra)
    local f = (ns.Volume and ns.Volume.Feel(eventKey) or 1) * (extra or 1)
    if f >= 1 then return shape end
    local copy = {}
    for k, v in pairs(shape or {}) do copy[k] = v end
    copy.strength = (copy.strength or 1) * f
    return copy
end

function V.Fire(eventKey)
    if not IF.db then return end
    local pattern = V.EventPattern(eventKey)
    if not (V.Active() and pattern) then return end
    if EVENT[eventKey].loop then
        V.EndLoop(eventKey)
        local shape
        if eventKey == "cast" then shape = CastShape() else shape = RestShape(eventKey, pattern) end
        -- (Full feels: the plain rumble over and over; mining's strikes keep their clock)
        local key = eventKey
        if eventKey == "cast" then key = V.CastMomentKey() end
        local points, scale = Plain(key)
        if points and shape ~= Strikes then shape = ns.FullFeel.Shape(points, scale, GetTime(), true) end
        -- (a loop keeps its shape: its volume as a gain, a spell's own on top)
        local gain = (ns.Volume and ns.Volume.Feel(eventKey) or 1) * (V.fireGain or 1)
        V.looping = { key = eventKey, pattern = pattern, shape = shape, gain = gain < 1 and gain or nil }
        -- (a once-only pattern, the fishing cast: its HD cue once, not each cycle)
        if PATTERN[pattern] and PATTERN[pattern].once then V.looping.once = true end
        if eventKey == "cast" then cast.shaped = V.looping.shape ~= nil end
        loops[#loops + 1] = V.looping
        Resume(V.looping)
        return
    end
    local now = GetTime()
    local combo = EVENT[eventKey].combo
    local since = last[eventKey] and now - last[eventKey]
    -- (Your abilities: the gap is per ability, a Judgement right after a seal is not a repeat)
    local gapKey = eventKey == "instant" and V.instantMove and ("instant:" .. V.instantMove) or eventKey
    local sinceSame = last[gapKey] and now - last[gapKey]
    if sinceSame and sinceSame < (EVENT[eventKey].gap or (combo and 0.15 or 0.4)) then return end
    last[eventKey], last[gapKey] = now, now
    -- (Full feels: WoW Helper's plain rumble instead, when it has one)
    local points, scale = Plain(eventKey)
    if points then
        return V.PlayPlain(points, (ns.Volume and ns.Volume.Feel(eventKey) or 1) * (V.fireGain or 1) * scale)
    end
    local shape = combo and ComboShape(eventKey, since ~= nil and since < COMBO_WINDOW) or nil
    if eventKey == "autoAttack" and V.swingShape then shape = V.swingShape end
    V.Play(pattern, false, V.Scaled(shape, eventKey, V.fireGain))
end

-- A looping event is over (the cast ended): its loop stops
function V.EndLoop(eventKey)
    if eventKey == "cast" and V.StrikeCastOver then V.StrikeCastOver() end
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
    -- Gathering, Match the action: a vein mined, the ore cracking loose;
    -- then fishing: the throw
    if V.castKind == "gather" and preset and preset.auto then
        local now = GetTime()
        V.castAction = "mining"
        cast.timing = { start = now, finish = now + 3.2 }
        cast.ended = false
        onStep(SpellName(2575) or "Mining")
        play("cast", true)
        at(3.2, function() V.EndLoop("cast"); V.Crack() end)
        at(4.2, function()
            local now = GetTime()
            V.castAction = "fishing"
            cast.timing = { start = now, finish = now + 30, channel = true }
            cast.ended = false
            onStep((SpellName(7620) or "Fishing") .. ": the throw")
            play("cast", true)
        end)
        at(6.2, finish)
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

-- Melee auto attack (below): on, each hand's last real swing, the last
-- ability used (its blow is not a swing)
local swing = { on = false, last = {}, ability = -math.huge }
local AtImpact   -- (set below)

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
    -- (your melee swing, landed or not: its feel; the log says which hand)
    if (sub == "SWING_DAMAGE" or sub == "SWING_MISSED") and not secret(info[4]) and info[4] == UnitGUID("player") then
        local offHand = info[sub == "SWING_DAMAGE" and 21 or 13]
        local result
        if sub == "SWING_DAMAGE" then
            result = (not secret(info[18]) and info[18]) and "crit" or "hit"
        else
            result = not secret(info[12]) and V.SWING_RESULT[info[12]] or "miss"
        end
        -- (its crit too, at the impact)
        return V.SwingLanded((not secret(offHand) and offHand) and 17 or 16, true, result)
    end
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
-- (a melee result on your target: a swing of yours, while auto attack is
-- on, not shooting, physical, not just after an ability)
-- What a swing's result is (its own feel: a crit, the Beta engine's miss,
-- dodge, parry, block on your target; a hit: the swing's and the Lab's Hit)
V.SWING_RESULT = { WOUND = "hit", MISS = "miss", DODGE = "dodge", PARRY = "parry", BLOCK = "block", DEFLECT = "parry",
    ABSORB = "hit", IMMUNE = "miss", EVADE = "miss" }
-- A UNIT_COMBAT result on your target is your swing's (played at its impact
-- by Rumble, the Beta engine's Hit, Miss, Parry... with it; the Lab leaves it)
function V.ClaimsSwing(action, school)
    if not swing.on or secret(action) or not V.SWING_RESULT[action] then return false end
    if secret(school) then school = nil end
    if school ~= nil and school ~= PHYSICAL then return false end
    if Shooting() or (not V.hitSync and GetTime() - swing.ability <= 0.3) then return false end
    local can = UnitCanAttack and UnitCanAttack("player", "target")
    if secret(can) then return true end
    return can and true or false
end

local function UnitCombat(unit, action, flag, _, school)
    if secret(action) then return end
    if secret(school) then school = nil end
    if unit == "target" and V.AbilityResult(action, flag, school) then return end
    if unit == "target" and V.ClaimsSwing(action, school) then
        local result = V.SWING_RESULT[action]
        if result == "hit" and not secret(flag) and flag == "CRITICAL" then result = "crit" end
        return V.SwingLanded(nil, false, result)
    end
    -- (no one's claim: a proc of yours, by its mixed school)
    if unit == "target" and action == "WOUND" then
        local can = UnitCanAttack and UnitCanAttack("player", "target")
        local id = (secret(can) or can) and V.ProcOf(school) or nil
        if id then return V.ProcLanded(id, not secret(flag) and flag == "CRITICAL") end
    end
    if secret(flag) or flag ~= "CRITICAL" then return end
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

-- After seconds (0: now), less WoW Helper's link lead (Timing). (Not
-- Rumble's own timers: a pattern starting meanwhile must not cancel an
-- impact on its way.)
AtImpact = function(seconds, fn)
    if ns.Timing then return ns.Timing.After(seconds, fn) end
    if seconds <= 0 or not (C_Timer and C_Timer.After) then return fn() end
    C_Timer.After(seconds, fn)
end
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
-- Smelting's casts (Smelt Copper, Tin, Bronze, Silver, Iron, Gold, Steel, Mithril,
-- Truesilver, Dark Iron, Thorium, Elementium): smelting, whatever the window says
local SMELT_IDS = { 2657, 3304, 2659, 2658, 3307, 3308, 3569, 10097, 10098, 14891, 16153, 22967 }
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
    2643, 5116, 1978, 3043, 3034, 19386, 19503, 20736, 19801,
}
-- Eating and drinking: the buffs of sitting with food or a drink (each
-- also the spell the item casts). Most are Food or Drink; a few have their
-- own name, some both at once (a mage's Refreshment, Dim Sum...).
local REST_SPELLS = {
    eat = { 433, 26030, 18124, 21149, 29041 },
    drink = { 430, 18140, 23698 },
    both = { 167152, 25990, 26263, 29055, 1312719, 1269354 },
}
local smeltByName = {}
local gatherByName, craftByName, spellByName, ticksByName, shotByName, moveByName, restByName
-- (built again until every gathering spell has its name: a name not loaded
-- yet at login would leave mining a plain spell all session)
-- (a gathering name the client lacks: tried again at most every 10 s, not on every aura)
local namesComplete, namesTried = false, -math.huge
local function Names()
    if gatherByName and (namesComplete or GetTime() - namesTried < 10) then return end
    namesTried = GetTime()
    namesComplete = true
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
            if name then gatherByName[name] = action else namesComplete = false end
        end
    end
    spellByName = {}
    for _, id in ipairs(SMELT_IDS) do
        local name = SpellName(id)
        if name then smeltByName[name] = true end
    end
    for _, a in ipairs(V.CAST_ACTIONS) do
        local name = a.kind == "craft" and SpellName(a.spell)
        if name then craftByName[name] = a.key end
        -- (Smelting's window may name itself Mining: only smelting has a window there)
        if a.key == "smelting" then
            local mining = SpellName(2575)
            if mining then craftByName[mining] = "smelting" end
        end
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
    -- (a smelt: Smelting's, by the spell)
    if spellID and not secret(spellID) then
        local name = SpellName(spellID)
        if name and not secret(name) and smeltByName[name] then return "craft", "smelting" end
    end
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

-- Next-swing abilities (Heroic Strike, Cleave, Maul, Raptor Strike: every
-- rank shares its name): their blow is the swing
local NEXT_SWING_IDS = { 78, 845, 6807, 2973 }
local nextSwingByName
local function NextSwing(spellID)
    if not spellID or secret(spellID) then return false end
    if not nextSwingByName then
        nextSwingByName = {}
        for _, id in ipairs(NEXT_SWING_IDS) do
            local name = SpellName(id)
            if name and not secret(name) then nextSwingByName[name] = true end
        end
    end
    local name = SpellName(spellID)
    return name ~= nil and not secret(name) and nextSwingByName[name] == true
end

-- An event about this cast (another one's attempt failing doesn't count;
-- hidden or missing IDs: it does)
local function SameCast(guid)
    if guid == nil or cast.guid == nil or secret(guid) or secret(cast.guid) then return true end
    return guid == cast.guid
end

---------------------------------------------------------------------------
-- Gathering markers for WoW Helper (its src/gather.rs): with the HD link on,
-- a marker as a gathering cast starts, succeeds (the ore cracks) or stops:
-- moments 100-102 mining, 103-105 herbalism, 106-108 skinning (start,
-- succeeded, stopped); side = race id; seed = sex (bit 7) and the addon's
-- first strike in 10 ms steps (127: unknown). Once WoW Helper's timing for
-- the action is known (strikeTiming, read at load), the start marker
-- carries the strike's HD feel: WoW Helper plays each strike itself, and
-- the addon sends no HD for that cast.
---------------------------------------------------------------------------
V.GATHER_MARKERS = { mining = 100, herbalism = 103, skinning = 106 }
local GATHER_PHASE = { start = 0, succeeded = 1, stopped = 2 }
local gatherOpen

local function RaceSex()
    local race = UnitRace and select(3, UnitRace("player")) or 0
    local sex = UnitSex and UnitSex("player") or 2
    if secret(race) or type(race) ~= "number" then race = 0 end
    return math.min(15, race), sex == 3 and 128 or 0
end

-- Send a gathering marker; true: the start's carries the strikes' HD feel
function V.GatherMarker(action, phase)
    local base = V.GATHER_MARKERS[action]
    local K, C = ns.HelperLink, ns.HelperCues
    if not (base and K and K.Marker and K.Enabled and K.Enabled() and K.V2 and K.V2()) then return false end
    local race, sexBit = RaceSex()
    local _, first, _, source = V.StrikeTiming(action)
    -- (10 ms steps up to 1.26 s; later, or not known: 127, WoW Helper's own guess)
    local steps = 127
    if (STRIKES[action] or source == "learned" or source == "synced" or source == "set") and first <= 1.26 then
        steps = math.max(0, math.floor(first / 0.01 + 0.5))
    end
    local item
    if phase == "start" and source == "learned" and C and C.MomentItem then
        local pattern = V.EventPattern("cast")
        local L = ns.HapticsLab
        -- (the action's own moment: its sound, which WoW Helper replays on each strike)
        item = pattern and L and C.MomentItem(V.GatherKey(action) or "gather", L.FeelFor(pattern))
        if type(item) ~= "table" then item = nil end
    end
    local carries = item ~= nil and ((item.touch or 0) > 0 or (item.sound or 0) > 0)
    item = item or {}
    item.moment, item.side, item.seed, item.level, item.open = base + GATHER_PHASE[phase], race, sexBit + steps, 0, nil
    K.Marker(item)
    return carries
end

-- A gathering cast open (its start sent): its end, once
local function GatherEnd(ok)
    local open = gatherOpen
    if not open then return end
    gatherOpen = nil
    V.GatherMarker(open.action, ok and "succeeded" or "stopped")
end
V.GatherEnd = GatherEnd

local function CastStarted(event, _, guid, spellID)
    -- (a gathering cast still open: it stopped)
    GatherEnd(false)
    V.castKind, V.castAction = CastKind(spellID)
    -- (the spell's own choice: off, its set, its volume; Your spells)
    local rule = V.castKind == "spell" and V.SpellRule(spellID, 1) or nil
    V.castSet = rule and rule.own and rule.set or nil
    cast.off = rule and rule.off or false
    if V.castKind == "spell" and not V.castAction and rule and rule.schoolSet then V.castAction = rule.schoolSet end
    cast.gain = rule and rule.volume or 1
    cast.ended, cast.shaped = false, false
    cast.guid = guid
    local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
    cast.casting = not channel
    local start, finish = CastTimes(channel)
    cast.channelEnd = channel and finish or nil
    local kinds = V.SpellKinds(spellID)
    cast.timing = start and { start = start, finish = finish, channel = channel,
        interval = channel and (ChannelTicks(spellID) or (kinds and kinds.h and kinds.tick)) or nil } or nil
    -- (gathering: its marker first; WoW Helper timing the strikes: no HD from here)
    local timed = false
    if V.castKind == "gather" and V.GATHER_MARKERS[V.castAction] then
        timed = V.GatherMarker(V.castAction, "start")
        gatherOpen = { action = V.castAction, guid = guid }
        -- (its node, right after: WoW Helper learns per ore and herb too)
        V.GatherNode(V.castAction, V.sentTarget)
    end
    -- (a striking cast, mining: its HD goes with each strike, from Strikes)
    local striking = V.castKind == "gather" and STRIKES[V.castAction] ~= nil
    V.cueTimed = (timed or striking) or nil
    V.fireGain = rule and rule.volume < 1 and rule.volume or nil
    if not cast.off then V.Fire("cast") end
    V.cueTimed, V.fireGain = nil, nil
    cast.helperTimed = timed
    if (timed or striking) and V.looping and V.looping.key == "cast" then V.looping.helperTimed = true end
    if V.strikeSync then V.StrikeCastBegan(V.castAction, cast.timing and cast.timing.start or GetTime()) end
end

local function CastEnded(how)
    GatherEnd(false)
    V.EndLoop("cast")
    if cast.ended then return end
    cast.ended = true
    if cast.off then return end
    -- (fishing stopped early: most often the catch, looted)
    if how == "cancelled" and cast.timing and cast.timing.fishing then return end
    V.Fire(how)
end

-- Done as it should: the spell flies off (with its own feel only)
local function CastReleased()
    GatherEnd(true)
    V.EndLoop("cast")
    if cast.ended then return end
    cast.ended = true
    if cast.off then return end
    -- (a damaging spell, its family's set: felt as it lands)
    if V.castKind == "spell" and not V.castSet and cast.timing and not cast.timing.channel
        and V.CastImpactWindow(V.castAction, cast.gain) then return end
    if cast.shaped and not cast.timing.fishing then
        if cast.timing.strikes then V.Crack(cast.timing.cracked) else V.Release() end
    end
    -- (a craft made: its finish, once, at the craft's volume)
    local finish = V.castKind == "craft" and not V.castSet and V.CraftFinish(V.castAction)
    if finish and V.Active() then V.Play(finish, false, V.Scaled(nil, V.ActionKey(V.castAction))) end
end

---------------------------------------------------------------------------
-- Strike sync: mine and squeeze R2 (or L2) on each strike of the pickaxe,
-- over one cast or more; the squeezes give the swing's period and the first
-- strike's time after the cast starts
---------------------------------------------------------------------------
V.STRIKE_SYNC_TAPS = 6

local function StrikeSay(text) if V.onStrikeSync then V.onStrikeSync(text) end end

function V.StrikeSync(action)
    local s = { action = action or "mining", casts = {} }
    V.strikeSync = s
    ns.Timing.StartSync({ name = "strikes",
        onTap = function(now)
            if not s.current then return end
            s.current[#s.current + 1] = now - s.current.start
            local n = #s.current
            for _, c in ipairs(s.casts) do n = n + #c end
            StrikeSay(n .. " strikes")
        end,
        onStop = function(cancelled)
            if V.strikeSync == s then V.strikeSync = nil end
            if cancelled then StrikeSay("") end
        end })
    StrikeSay("Mine: squeeze R2 on each strike")
end

function V.StrikeSyncCancel()
    ns.Timing.StopSync("strikes", true)
    V.strikeSync = nil
end

function V.StrikeCastBegan(action, start)
    local s = V.strikeSync
    if not s then return end
    s.current = action == s.action and { start = start } or nil
end

-- The taps of each cast (seconds after its start) to a period and a first
-- strike: strikes may be missed, so each tap counts as the nearest whole
-- number of strikes after the earliest first one; then a straight line
function V.FitStrikes(casts)
    local gaps, total, first = {}, 0, math.huge
    for _, c in ipairs(casts) do
        for i = 2, #c do gaps[#gaps + 1] = c[i] - c[i - 1] end
        total = total + #c
        if c[1] and c[1] < first then first = c[1] end
    end
    if total < 4 or #gaps < 2 then return nil end
    table.sort(gaps)
    local period = gaps[math.floor((#gaps + 1) / 2)]
    if period < 0.3 then return nil end
    local sx, sy, sxx, sxy, m = 0, 0, 0, 0, 0
    for _, c in ipairs(casts) do
        for _, t in ipairs(c) do
            local n = math.max(0, math.floor((t - first) / period + 0.5))
            sx, sy, sxx, sxy, m = sx + n, sy + t, sxx + n * n, sxy + n * t, m + 1
        end
    end
    local den = m * sxx - sx * sx
    if den == 0 then return nil end
    local b = (m * sxy - sx * sy) / den
    local a = (sy - b * sx) / m
    if b < 0.3 or b > 3 then return nil end
    while a < 0 do a = a + b end
    return b, a
end

function V.StrikeSyncEnd()
    local s = V.strikeSync
    ns.Timing.StopSync("strikes")
    V.strikeSync = nil
    if not s then return end
    local period, offset = V.FitStrikes(s.casts)
    if not period then return StrikeSay("|cffff7a5cToo few strikes: try again|r") end
    local n = 0
    for _, c in ipairs(s.casts) do n = n + #c end
    V.SetStrikeTiming(s.action, period, offset)
    V.Settings().strikes[s.action].taps = n
    StrikeSay(string.format("Synced: a strike every %.2f s, first after %.2f s", period, offset))
end

-- A cast over: its taps kept; enough of them, the sync is done
function V.StrikeCastOver()
    local s = V.strikeSync
    if not (s and s.current) then return end
    local taps = s.current
    s.current = nil
    if #taps > 0 then s.casts[#s.casts + 1] = taps end
    local n = 0
    for _, c in ipairs(s.casts) do n = n + #c end
    if n >= V.STRIKE_SYNC_TAPS then return V.StrikeSyncEnd() end
    StrikeSay(n .. " strikes: mine again")
end


---------------------------------------------------------------------------
-- A spell's rule: what plays for it. One function for both: the play path
-- acts on it (casts, instants, abilities at the hit) and Your spells shows
-- it (V.SpellPlan), so the page never says other than what plays.
-- { id, name, moment ("spell" a cast-time spell's set, "instant" a feel,
-- "quiet" none by the rules, or a linked moment: autoAttack, shot, gather,
-- craft, eat, drink), when ("hit", "cast", "channel", "none"), move /
-- pattern (Rumble's pattern), feel (the library's), set (a cast set),
-- how { melee, ranged, atCast }, guessed, own (Your spells has a choice),
-- off, volume, timing ("default", "learned", "yours"), hd, why }
---------------------------------------------------------------------------
-- A spell's cast time in seconds (0: instant; nil: unknown)
local function CastTimeOf(spellID)
    local ms
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then ms = info.castTime end
    end
    if ms == nil and GetSpellInfo then
        local ok, _, _, _, t = pcall(GetSpellInfo, spellID)
        if ok then ms = t end
    end
    if type(ms) ~= "number" or secret(ms) then return nil end
    return ms / 1000
end

local TIMING_WORD = { guess = "default", learned = "learned", set = "yours" }

-- The spell kinds table (WoW Helper writes it from the client's own tables:
-- WowHelperData.spellKinds = { [spellID] = { letters, school mask, tick s } }):
-- h a direct hit on an enemy, n harmful with no hit, c control, i interrupt,
-- t taunt, d a DoT or debuff, s a summon (g on the ground, p a pet or a
-- creature, b a helpful one), a around you. nil: not in it (or no table)
local kindsCache = {}
function V.SpellKinds(spellID)
    if not spellID or secret(spellID) then return nil end
    local d = _G.WowHelperData
    local t = type(d) == "table" and type(d.spellKinds) == "table" and d.spellKinds[spellID]
    if type(t) ~= "table" then return nil end
    local k = kindsCache[spellID]
    if k and k.src == t then return k end
    k = { src = t, school = tonumber(t[2]), tick = tonumber(t[3]) }
    for ch in tostring(t[1] or ""):gmatch("%a") do k[ch] = true end
    kindsCache[spellID] = k
    return k
end

-- (the lowest magic school of a mask: its family and its cast set)
local SCHOOL_BITS = { { 2, "judge", "holy" }, { 4, "shock", "fire" }, { 8, "shock", "nature" }, { 16, "shock", "frostSpells" },
    { 32, "shock", "shadowSpells" }, { 64, "judge", "arcaneSpells" } }
local function SchoolOf(mask)
    if type(mask) ~= "number" then return nil end
    for _, b in ipairs(SCHOOL_BITS) do
        if math.floor(mask / b[1]) % 2 == 1 then return b end
    end
    return nil
end

-- Spells with no direct hit (spell coverage, 2026-11-17): control and
-- interrupts felt at the cast; routine debuffs, DoTs, single taunts and
-- tricks quiet (false). By their first rank's name (every rank shares it).
local NO_HIT_IDS = {
    bash = { 6770, 1833, 408, 853, 12809, 5211, 676 },     -- Sap, Cheap Shot, Kidney Shot, Hammer of Justice, Concussion Blow, Bash, Disarm
    whirl = { 12292, 13877 },                              -- Sweeping Strikes, Blade Flurry
    shock = { 2139 },                                      -- Counterspell
    judge = { 20066 },                                     -- Repentance
    quiet = { 772, 7386, 8647, 703, 1943, 1079, 5171,      -- Rend, Sunder and Expose Armor, Garrote, Rupture, Rip, Slice and Dice
        355, 6795, 921, 1725, 1966 },                      -- Taunt, Growl, Pick Pocket, Distract, Feint
}
-- Spells the rules would leave quiet (helpful, or no kind) felt at the cast
-- all the same: big and rare (Lay on Hands), a cleanse (faint), breaking
-- free, a silence around you, a racial of its own. By first rank's ID.
local AT_CAST_IDS = {
    rise = { 633 },                                        -- Lay on Hands: a full, warm swell
    mend = { 1152, 4987 },                                 -- Purify, Cleanse: a faint, calm pulse
    shock = { 7744, 20589 },                               -- Will of the Forsaken, Escape Artist: a jolt free
    burst = { 28730 },                                     -- Arcane Torrent: a silence around you
    chew = { 20577 },                                      -- Cannibalize
}
local atCastByName
local function AtCastOf(name)
    if not atCastByName then
        atCastByName = {}
        for fam, ids in pairs(AT_CAST_IDS) do
            for _, id in ipairs(ids) do
                local n = SpellName(id)
                if n and not secret(n) then atCastByName[n] = fam end
            end
        end
    end
    return atCastByName[name]
end
-- Summons: on the ground (harmful: felt as laid down), a pet or a creature
-- (a short ritual), a helpful totem (quiet). By name, lower case.
local SUMMON_NAMES = { ["searing totem"] = "ground", ["magma totem"] = "ground", ["earthbind totem"] = "ground",
    ["fire nova totem"] = "ground", ["stoneclaw totem"] = "ground", ["flare"] = "ground",
    ["call pet"] = "pet", ["shadowfiend"] = "pet", ["frozen orb"] = "pet", ["eye of the void"] = "pet" }
local noHitByName
local function NoHitOf(name)
    if not noHitByName then
        noHitByName = {}
        for fam, ids in pairs(NO_HIT_IDS) do
            for _, id in ipairs(ids) do
                local n = SpellName(id)
                if n and not secret(n) then
                    if fam == "quiet" then noHitByName[n] = false else noHitByName[n] = fam end
                end
            end
        end
    end
    return noHitByName[name]
end
local function SummonOf(name, kinds)
    if kinds and kinds.s then return kinds.g and "ground" or kinds.p and "pet" or "buff" end
    local lower = name:lower()
    if SUMMON_NAMES[lower] then return SUMMON_NAMES[lower] end
    if lower:find("%f[%a]trap%f[%A]") then return "ground" end
    if lower:find("%f[%a]totem%f[%A]") or lower:find("totemic") then return "buff" end
    return nil
end

-- castTime: known by the caller (a cast started: > 0; an instant: 0)
function V.SpellRule(spellID, castTime)
    if not spellID or secret(spellID) then return nil end
    Names()
    local proc = V.IsProc(spellID)
    local name = spellID == V.OTHER_PROC and V.OTHER_PROC_NAME or SpellName(spellID)
    if not name or secret(name) then return nil end
    local r = { id = spellID, name = name, volume = 1 }
    local L = ns.HapticsLab
    local linked = false
    if proc then
        -- (never cast: felt as its wound lands, faint, fuller on a crit)
        r.moment, r.move, r.when, r.proc = "instant", "pillar", "hit", true
        r.why = "A proc: as it lands, stronger on a crit"
        linked = true
    elseif spellID == ATTACK then
        r.moment, r.when, r.why, linked = "autoAttack", "hit", "Auto attack: each swing as it lands", true
    elseif IsShot(spellID) then
        r.moment, r.when, r.why, linked = "shot", "cast", "A shot: as it leaves", true
    elseif RestOf(spellID) then
        r.moment, r.when, linked = RestOf(spellID) == "drink" and "drink" or "eat", "channel", true
        r.why = "Food or drink: with each bite or sip"
    end
    if not linked then
        local ct = castTime or CastTimeOf(spellID) or 0
        local channel = ChannelTicks(spellID) ~= nil
        if ct > 0 or channel then
            local kind, action = CastKind(spellID)
            if kind == "gather" or kind == "craft" then
                r.moment, r.when, r.why, linked = kind, "cast", kind == "gather" and "Gathering" or "Crafting", true
            else
                r.moment, r.when = "spell", channel and "channel" or "cast"
                local preset = PRESET[V.CastPreset("spell")]
                if preset and preset.auto then
                    -- (not listed: its school's set; a heal: Healing; a summon: Summoning)
                    if not action then
                        local kinds = V.SpellKinds(spellID)
                        local b = kinds and SchoolOf(kinds.school)
                        if kinds and kinds.s then action = "summon"
                        elseif V.SpellHelpful(spellID) then action = "healing"
                        elseif b then action = b[3]
                        elseif kinds and kinds.h and kinds.school == PHYSICAL then action = "shots" end
                        r.schoolSet = action
                    end
                    r.set = action or CAST_KIND.spell.fallback
                    r.why = action and ("Its family: " .. (PRESET[action] and PRESET[action].label or action)) or "A cast: the spell set"
                else
                    r.set = V.CastPreset("spell")
                    r.why = "Your cast set"
                end
            end
        else
            local move = V.MoveOf(spellID)
            local kinds = V.SpellKinds(spellID)
            local nohit = NoHitOf(name)
            -- (curses, poisons, marks: routine debuffs, quiet)
            if nohit == nil and move == "hex" then nohit = false end
            local summon = SummonOf(name, kinds)
            r.moment = "instant"
            if NextSwing(spellID) then
                r.move, r.when, r.next = move or "slash", "hit", true
                r.why = "On the next swing: felt as the ability"
            elseif summon then
                if summon == "ground" then r.move, r.when, r.why = "surge", "cast", "Laid on the ground: at the cast"
                elseif summon == "pet" then r.move, r.when, r.why = "ritual", "cast", "A summon: at the cast"
                else r.moment, r.when, r.why = "quiet", "none", "A helpful totem: nothing" end
            elseif AtCastOf(name) then
                r.move, r.when, r.why = AtCastOf(name), "cast", "Felt at the cast"
            elseif nohit ~= nil or (kinds and kinds.n and not kinds.h) then
                local fam = nohit
                if fam == nil then
                    -- (a big taunt or fear around you first: Psychic Scream "nca" is a Burst)
                    if kinds.a and (kinds.t or kinds.c) then fam = "burst"
                    elseif kinds.c or kinds.i then fam = (kinds.school == nil or kinds.school == PHYSICAL) and "bash" or "shock"
                    else fam = false end
                end
                r.avoidOnly = true
                if fam then r.move, r.when, r.why = fam, "cast", "No direct hit: at the cast"
                else r.moment, r.when, r.why = "quiet", "none", "A debuff: nothing" end
            elseif move then
                r.move, r.when = move, V.LANDS[move] and "hit" or "cast"
                r.why = "Known: " .. (PATTERN[move] and PATTERN[move].label or move)
            elseif V.SpellHelpful(spellID) then
                r.moment, r.when, r.why = "quiet", "none", "Helpful: a heal or a buff"
            else
                local m, how = V.FamilyOfName(name)
                local b = kinds and kinds.h and SchoolOf(kinds.school)
                if not m and b then m = b[2] end
                r.move, r.how, r.guessed = m or "blow", how, m == nil
                r.when = how and how.atCast and "cast" or "hit"
                -- (known to nothing: only a magic wound may be its (a swing, a pet's
                -- blow are physical); a direct hit by the table: any)
                r.magicOnly = m == nil and not (kinds and kinds.h) and not (how and how.ranged) or nil
                r.why = how and how.atCast and "No direct hit: at the cast"
                    or m and ("By its name: " .. (PATTERN[m] and PATTERN[m].label or m))
                    or "Blow, when a spell's damage lands"
            end
        end
    end
    r.pattern = r.move
    r.feel = r.move and L and L.FeelFor(r.move) or nil
    r.ruleSet, r.ruleFeel = r.set, r.feel
    -- (your own choice, Your spells: off, another feel or set, a volume)
    local O = ns.SpellOverrides
    local o = (not linked or proc) and O and O.Get(name) or nil
    if o then
        r.own = true
        if o.on == false then r.off = true end
        if o.feel and (r.moment == "instant" or r.moment == "quiet") then
            r.feel = o.feel
            r.pattern = L and L.PatternFor(o.feel) or o.feel
            if r.moment == "quiet" then r.when = "cast" end
            r.guessed = false
            r.why = "Your choice"
        end
        if o.set and r.moment == "spell" and PRESET[o.set] then r.set, r.why = o.set, "Your choice" end
        if type(o.volume) == "number" then r.volume = o.volume end
    end
    if r.off then r.why = "Off: your choice" end
    -- (its light and sound: a moment of its own under the one it plays in,
    -- Instant ability or Spell released; a linked spell has its moment's)
    if not linked or proc then
        r.base = r.moment == "spell" and "release" or "instant"
        r.key = O and O.Key(r.base, name) or nil
    end
    -- (when it waits for the hit: where its timing comes from)
    if r.when == "hit" and not proc then
        local kind = r.how and r.how.ranged and "ranged" or V.WeaponKind and V.WeaponKind(16) or "oneHand"
        local _, _, source = V.HitDelay and V.HitDelay(kind)
        r.timing = TIMING_WORD[source] or "default"
    else
        r.timing = "default"
    end
    local C = ns.HelperCues
    r.hd = r.feel and C and C.HasHD and C.HasHD(r.feel) or false
    return r
end

-- Your spells: what plays for a spell (the rule itself)
function V.SpellPlan(spellID) return V.SpellRule(spellID) end

-- A spell's moment firing (V.spellNow): its own light and sound go with it
-- (Lights, HelperCues: SpellOverrides.Now)
local function FireAs(name, key)
    V.spellNow = name and { name = name, parent = key } or nil
    V.Fire(key)
    V.spellNow = nil
end
V.FireAs = FireAs

-- A spell whose feel plays nothing (quiet, or its feel off): its own light
-- and sound still, at the cast
function V.SpellCue(rule)
    local O = ns.SpellOverrides
    if not (O and rule and rule.base == "instant") then return end
    local light, sound = O.MomentFor("instant", rule.name, "light"), O.MomentFor("instant", rule.name, "sound")
    if light ~= "instant" and ns.Lights then ns.Lights.Fire(light) end
    if sound ~= "instant" and ns.HelperCues then ns.HelperCues.Moment(sound, nil) end
end

-- An instant felt as you use it: its pattern at its volume
function V.FireSpell(rule)
    if not (rule and rule.pattern) then return end
    V.instantMove = rule.pattern
    V.fireGain = rule.volume < 1 and rule.volume or nil
    FireAs(rule.name, "instant")
    V.fireGain = nil
end

-- Try (Your spells): the spell's feel as it would play (its set's cast for a cast-time one)
function V.TrySpell(spellID)
    local r = V.SpellRule(spellID)
    if not r or r.off then return false end
    local pattern = r.pattern
    if r.moment == "spell" then pattern = PRESET[r.set] and PRESET[r.set].cast end
    if not pattern then return false end
    V.Play(pattern, false, r.volume < 1 and { strength = r.volume } or nil)
    local C = ns.HelperCues
    if C and C.TryHD and r.feel then C.TryHD("instant", r.feel) end
    return true
end


-- The node a gathering cast is aimed at (the cast's target, as sent):
-- moment 109, seed = its number in Timing's list (0: unknown, not sent)
function V.GatherNode(action, name)
    local K = ns.HelperLink
    local n = ns.Timing and ns.Timing.NodeIndex(action, name) or 0
    if n == 0 or not (K and K.Marker and K.Enabled and K.Enabled() and K.V2 and K.V2()) then return false end
    return K.Marker({ moment = 109, seed = n, side = 0, level = 0 })
end

local CAST_HANDLERS = {
    -- (the cast's target as sent: a node's name, for gathering)
    UNIT_SPELLCAST_SENT = function(_, _, target)
        V.sentTarget = (type(target) == "string" and not secret(target)) and target or nil
    end,
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
    UNIT_SPELLCAST_STOP = function()
        V.EndLoop("cast")
        -- (a gathering cast: SUCCEEDED may come just after STOP; none: it stopped)
        local open = gatherOpen
        if open then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.25, function() if gatherOpen == open then GatherEnd(false) end end)
            else
                GatherEnd(false)
            end
        end
    end,
    UNIT_SPELLCAST_FAILED = function(_, _, guid)
        if SameCast(guid) then V.EndLoop("cast"); GatherEnd(false) end
    end,
    -- (a channel's start says so too: not its end)
    UNIT_SPELLCAST_SUCCEEDED = function(_, _, guid, spellID)
        -- (an ability's blow is not a swing; a next-swing one, Heroic Strike,
        -- is the swing itself, felt as the ability)
        if NextSwing(spellID) then
            local rule = V.SpellRule(spellID, 0)
            if rule and not rule.off then V.AbilityCast(rule.pattern, spellID, true, rule.how, rule) end
            return
        end
        if secret(spellID) or spellID ~= ATTACK then swing.ability = GetTime() end
        if IsShot(spellID) then
            ranged.shot = GetTime()
            if V.HitSyncEvent then V.HitSyncEvent("ranged", "ranged", ranged.shot) end
            local d = V.ImpactDelay("ranged", "ranged")
            local timed = V.SwingMarker("ranged", "ranged", "hit", d)
            return AtImpact(d, function()
                V.why1, V.why2, V.why3 = "shot", "ranged", d
                V.cueTimed = timed or nil
                V.Fire("shot")
                V.cueTimed, V.why1 = nil, nil
            end)
        end
        -- The cast in progress, done
        if cast.timing and not cast.timing.channel and not cast.ended and SameCast(guid) then
            return CastReleased()
        end
        -- (a cast whose timing is hidden; a channel starting; Attack)
        if cast.casting and not cast.ended and SameCast(guid) then
            cast.ended = true
            GatherEnd(true)
            return
        end
        if UnitChannelInfo and UnitChannelInfo("player") then return end
        if not secret(spellID) and spellID == ATTACK then return end
        -- (sitting down with food or a drink: Eating, Drinking)
        if RestOf(spellID) then return end
        -- (an instant: as its rule says, the one Your spells shows)
        local rule = V.SpellRule(spellID, 0)
        -- (no blow of its own: the next swing on the target is a swing)
        if rule and rule.when ~= "hit" then swing.ability = -math.huge end
        if rule and (rule.off or rule.when == "none") then V.SpellCue(rule) end
        if not rule or rule.off or rule.when == "none" then return end
        if rule.moment ~= "instant" and rule.moment ~= "quiet" then return end
        if rule.when == "cast" then
            V.FireSpell(rule)
            -- (a stun, an interrupt: a dodge or a parry of it still shows)
            if rule.avoidOnly then V.AbilityCast(rule.pattern, spellID, nil, rule.how, rule) end
            return
        end
        V.AbilityCast(rule.pattern, spellID, nil, rule.how, rule)
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

---------------------------------------------------------------------------
-- Melee swings: one feel per real swing, as it lands (hit, miss, dodge,
-- parry, block), main hand and off hand apart (the main hand leaning
-- right, the off hand left, softer). Auto attack turned on alone plays
-- nothing: out of range, turned away or the target dead, no swing lands.
-- Where the combat log is readable it names your swings and their hand;
-- in WoW Forever, UNIT_COMBAT on your target while auto attack is on (the
-- hand: the one due, by weapon speed; a blow too soon after that hand's
-- last swing is someone else's).
---------------------------------------------------------------------------
-- (hidden in combat: the last speeds read)
local known = { main = 2, off = nil }
local function Speeds()
    if UnitAttackSpeed then
        local ok, m, o = pcall(UnitAttackSpeed, "player")
        if ok and not secret(m) and not secret(o) then
            known.main = m and m > 0.2 and m or 2
            known.off = o and o > 0.2 and o or nil
        end
    end
    return known.main, known.off
end

local SIDES = { [16] = { left = 0.6, right = 1 }, [17] = { left = 1, right = 0.6, strength = 0.7 } }
local function SwingNow(slot)
    V.swingSlot, V.swingShape = slot, SIDES[slot]
    V.Fire("autoAttack")
    V.swingSlot, V.swingShape = nil, nil
end

-- The hand a swing result came from: the one due nearest now among those
-- that could swing again; sooner than either (an extra attack: Windfury,
-- Sword Specialization; a parry-hasted swing), the one due nearest anyway
local SOONEST = 0.5
local function HandDue(now)
    local main, off = Speeds()
    local best, bestErr, near, nearErr
    for _, h in ipairs({ { 16, main }, { 17, off } }) do
        local slot, speed = h[1], h[2]
        if speed then
            local last = swing.last[slot]
            local err = last and math.abs(now - (last + speed)) or (slot == 16 and 0 or 0.001)
            if not nearErr or err < nearErr then near, nearErr = slot, err end
            if (not last or now - last >= speed * SOONEST) and (not bestErr or err < bestErr) then best, bestErr = slot, err end
        end
    end
    return best or near or 16
end

---------------------------------------------------------------------------
-- Hit timing (Timing.lua): the game tells of a swing as its animation
-- starts; the blow lands (and its sound plays) later. Each feel waits for
-- the impact: an offset per model, form, kind of weapon and hand, in
-- proportion when attacks come faster than the animation
---------------------------------------------------------------------------
V.HIT_KINDS = {}   -- (Timing.lua fills it: it loads after this file)
local KIND_OF_SWING = { swDagger = "dagger", swFist = "fist", swSword = "oneHand", swAxe = "oneHand", swMace = "oneHand",
    swSword2 = "twoHand", swAxe2 = "twoHand", swMace2 = "twoHand", swPolearm = "polearm", swStaff = "staff" }
-- (cat, bear, dire bear: the form's own swipes, whatever the weapon)
local CLAW_FORMS = { [1] = true, [5] = true, [8] = true }

-- The kind of weapon in a hand (16 main, 17 off) or "ranged"
function V.WeaponKind(slot)
    if slot == "ranged" then return "ranged" end
    local form = type(GetShapeshiftFormID) == "function" and GetShapeshiftFormID() or nil
    if form and not secret(form) and CLAW_FORMS[form] then return "form" end
    local id = GetInventoryItemID and GetInventoryItemID("player", slot or 16)
    if not id or secret(id) then return "unarmed" end
    return KIND_OF_SWING[V.SwingPattern(slot or 16)] or "oneHand"
end

local HANDS = { [16] = "main", [17] = "off" }
local function HandOf(kind, hand) return hand or (kind == "ranged" and "ranged" or "main") end

-- (0.30.0 kept one delay per kind in Rumble's settings: now yours in Timing)
-- (0.30.0 kept one delay per kind in Rumble's settings: timing is WoW
-- Helper's now, so they go, not into Timing (that brought set values back
-- after Timing's own clean))
local function Migrate()
    local old = V.Settings().hitTiming
    if next(old) then wipe(old) end
end

-- An offset (game time), whether yours or learned (not a guess), where it
-- comes from ("set", "learned", "guess") and, learned, from how many hits
function V.HitDelay(kind, hand)
    Migrate()
    local v, source, hits = ns.Timing.Offset(kind, HandOf(kind, hand))
    return v, source ~= "guess", source, hits
end

function V.SetHitDelay(kind, seconds, hand) ns.Timing.Set(kind, HandOf(kind, hand), seconds) end

-- The live swing time of a hand (main, off, ranged)
local function Interval(hand)
    if hand == "ranged" then
        if type(UnitRangedDamage) == "function" then
            local ok, speed = pcall(UnitRangedDamage, "player")
            if ok and type(speed) == "number" and not secret(speed) and speed > 0.2 then return speed end
        end
        return nil
    end
    local main, off = Speeds()
    return hand == "off" and off or main
end

-- Seconds from the news to the impact (never before the news)
function V.ImpactDelay(kind, hand)
    Migrate()
    hand = HandOf(kind, hand)
    return math.max(0, ns.Timing.Impact(kind, hand, Interval(hand)))
end

-- (the Beta engine's moment for a result on your target, if it plays)
local LAB_RESULT = { hit = "hit", miss = "miss", dodge = "targetDodge", parry = "targetParry", block = "targetBlock" }
local function LabPlays(key)
    local L, H = ns.HapticsLab, ns.Haptics
    if not (L and H and H.Engine and H.Engine()) then return false end
    local ok, on = pcall(function() return L.EventSettings(key).on end)
    return ok and on and true or false
end

-- The impact: a crit its own; a miss, dodge, parry or block its own (the
-- swing's when the Beta engine has none); a hit the swing and the Lab's Hit.
-- mine: false for a blow that was not one of your swings (no swing feel).
-- (Quiet while syncing hits: you squeeze to the game's sound, not to us)
function V.SwingImpact(slot, result, mine)
    if V.hitSync then return end
    if mine and (swing.tryLeft or 0) > 0 then
        swing.tryLeft = swing.tryLeft - 1
        V.Play(V.SwingPattern(slot or 16), false, SIDES[slot or 16])
        if swing.tryLeft == 0 and V.onHitSync then V.onHitSync("") end
        return
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    result = result or "hit"
    if result == "crit" then return YourCrit(false) end
    local lab = LAB_RESULT[result]
    if result == "hit" then
        if mine then SwingNow(slot or 16) end
        if lab and LabPlays(lab) then ns.HapticsLab.Fire(lab) end
        return
    end
    if lab and LabPlays(lab) then return ns.HapticsLab.Fire(lab) end
    if mine then SwingNow(slot or 16) end
end

local function result_or_hit(r) return r or "hit" end

---------------------------------------------------------------------------
-- Swing markers for WoW Helper (its src/calib.rs; the side-session note
-- swing-marker-proposal.md): at each swing's or shot's news, while the HD
-- link is on, a marker cue: moment 110-117 main hand by kind (Timing's
-- order), 118-125 off hand, 126 ranged; side = race id; seed = sex (bit 7)
-- and the addon's delay in 5 ms steps (127: unknown); level = the result.
-- It carries the blow's own HD cue (and sound) when there is one: WoW Helper
-- plays it at the impact it has learned, and the addon doesn't send it again.
---------------------------------------------------------------------------
V.MARKER_KINDS = { "dagger", "oneHand", "twoHand", "polearm", "staff", "fist", "unarmed", "form" }
local MARKER_INDEX = {}
for i, k in ipairs(V.MARKER_KINDS) do MARKER_INDEX[k] = i - 1 end
local MARKER_LEVEL = { hit = 0, crit = 1, miss = 2, dodge = 2, parry = 2, block = 3 }

function V.MarkerMoment(kind, hand)
    if hand == "ranged" or kind == "ranged" then return 126 end
    local i = MARKER_INDEX[kind]
    if not i then return nil end
    return (hand == "off" and 118 or 110) + i
end

-- The moment (and its feel) that plays at the blow, for its cue
local function BlowCue(result)
    local L = ns.HapticsLab
    if result == "shot" then
        local p = V.EventPattern("shot")
        return p and "shot", p and L and L.FeelFor(p)
    end
    if result == "crit" then
        local p = V.EventPattern("crit")
        return p and "crit", p and L and L.FeelFor(p)
    end
    local lab = LAB_RESULT[result or "hit"]
    if result ~= "hit" and lab and LabPlays(lab) then return lab, L.EventSettings(lab).feel end
    local p = V.EventPattern("autoAttack")
    if p then return "autoAttack", L and L.FeelFor(p) end
    if lab and LabPlays(lab) then return lab, L.EventSettings(lab).feel end
    return nil
end

-- Send the marker; true: it carries the blow's cue (WoW Helper times it)
function V.SwingMarker(kind, hand, result, delay)
    local K, C = ns.HelperLink, ns.HelperCues
    if not (K and K.Marker and K.Enabled and K.Enabled() and K.V2 and K.V2()) then return false end
    local moment = V.MarkerMoment(kind, hand)
    if not moment then return false end
    local item
    if not V.hitSync and C and C.MomentItem then
        local key, feel = BlowCue(kind == "ranged" and "shot" or (result or "hit"))
        if key then item = C.MomentItem(key, feel) end
        if type(item) ~= "table" then item = nil end
    end
    local carries = item ~= nil and ((item.touch or 0) > 0 or (item.sound or 0) > 0)
    item = item or {}
    local race = UnitRace and select(3, UnitRace("player")) or 0
    local sex = UnitSex and UnitSex("player") or 2
    if secret(race) or type(race) ~= "number" then race = 0 end
    local steps = delay and math.min(126, math.max(0, math.floor(delay / 0.005 + 0.5))) or 127
    item.moment, item.side, item.level, item.open = moment, math.min(15, race), MARKER_LEVEL[result or "hit"] or 0, nil
    item.seed = (sex == 3 and 128 or 0) + steps
    K.Marker(item)
    return carries
end

-- A real swing landed: its feel at the impact (sure: the combat log said it
-- was yours; result: hit, crit, miss, dodge, parry, block)
function V.SwingLanded(slot, sure, result)
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    local now = GetTime()
    if not sure then
        if not swing.on then return end
        slot = HandDue(now)
    end
    slot = slot or 16
    swing.last[slot] = now
    local kind, hand = V.WeaponKind(slot), HANDS[slot] or "main"
    if V.HitSyncEvent then V.HitSyncEvent(kind, hand, now) end
    local d = V.ImpactDelay(kind, hand)
    -- (WoW Helper on: a marker now; it learns the delay, and plays the
    -- blow's HD cue itself when it carries one)
    local timed = V.SwingMarker(kind, hand, result, d)
    AtImpact(d, function()
        V.why1, V.why2, V.why3 = "swing " .. result_or_hit(result), hand .. " hand", d
        V.cueTimed = timed or nil
        V.SwingImpact(slot, result, true)
        V.cueTimed, V.why1 = nil, nil
    end)
end

---------------------------------------------------------------------------
-- Your abilities as they land: an attack ability's cast (UNIT_SPELLCAST_
-- SUCCEEDED, the player's own) waits a moment for its result on your target
-- (UNIT_COMBAT: a wound, a crit, a miss, dodge, parry or block); then its
-- feel at the blow (the weapon's impact, as a swing's; ranged its own; a
-- spell's at once). Nothing comes of others' damage: no cast of yours, no
-- feel. A next-swing ability (Heroic Strike) is the swing, felt as itself.
---------------------------------------------------------------------------
-- (the families felt as they land; the others as you use them)
V.LANDS = { slash = true, stab = true, rend = true, bash = true, cleave = true, whirl = true, flurry = true,
    judge = true, shock = true, slam = true, blow = true }
local SPELL_MOVES = { shock = true }
local ABILITY_RESULT = { WOUND = "hit", MISS = "miss", DODGE = "dodge", PARRY = "parry", BLOCK = "block",
    DEFLECT = "parry", ABSORB = "hit", IMMUNE = "miss", EVADE = "miss", RESIST = "miss" }
V.ABILITY_WINDOW, V.ABILITY_WINDOW_UNKNOWN, V.ABILITY_WINDOW_FAR = 0.6, 0.5, 1.5
local RANGED_ABILITIES = { [3044] = true }
local pending

-- move: its family (nil: an ability we don't know: the default, Blow);
-- nextSwing: on the next swing (until a swing time has passed)
-- how (from the name): { melee: a weapon strike, ranged: a shot }; rule: its
-- rule (V.SpellRule), for its volume and whether its school may decide
function V.AbilityCast(move, spellID, nextSwing, how, rule)
    how = how or {}
    local now = GetTime()
    local ranged = how.ranged or (not secret(spellID) and RANGED_ABILITIES[spellID]) or false
    local spell = not how.melee and not ranged and (SPELL_MOVES[move] or move == "judge") or false
    local window = nextSwing and ((Speeds()) + 0.5) or (ranged or spell) and V.ABILITY_WINDOW_FAR
        or move and V.ABILITY_WINDOW or V.ABILITY_WINDOW_UNKNOWN
    pending = { move = move or "blow", guessed = rule and rule.guessed or (not rule and move == nil), at = now,
        until_ = now + window, ranged = ranged, next = nextSwing, spell = spell, gain = rule and rule.volume or 1,
        avoidOnly = rule and rule.avoidOnly or nil, magicOnly = rule and rule.magicOnly or nil,
        name = rule and rule.name or nil }
end

-- A helpful spell (a heal, a buff), when the client says so
function V.SpellHelpful(spellID)
    if not spellID or secret(spellID) then return false end
    local fn = C_Spell and C_Spell.IsSpellHelpful or IsSpellHelpful
    if type(fn) ~= "function" then return false end
    local ok, helpful = pcall(fn, spellID)
    return ok and not secret(helpful) and helpful == true
end

-- A family from a spell's name (whole words, in this order: the school's
-- light first, then the blow): Holy Strike a bright strike at the weapon's
-- impact; nil: none (the default, Blow). how = { melee, ranged }
local NAME_FAMILIES = {
    { "holy", "judge" }, { "judgement", "judge" }, { "arcane", "judge" }, { "divine", "judge" }, { "crusader", "judge" },
    { "shadow", "shock" }, { "frost", "shock" }, { "fire", "shock" }, { "flame", "shock" }, { "lightning", "shock" },
    { "shock", "shock" }, { "bolt", "shock" }, { "blast", "shock" },
    { "backstab", "stab" }, { "stab", "stab" }, { "ambush", "stab" },
    { "slam", "bash" }, { "bash", "bash" }, { "smash", "bash" }, { "crush", "bash" },
    { "cleave", "cleave" }, { "sweep", "cleave" }, { "whirlwind", "whirl" },
    { "strike", "slash" }, { "slash", "slash" }, { "chop", "slash" }, { "blow", "slash" },
}
local MELEE_WORDS = { "strike", "blow", "slam", "bash", "smash", "crush", "cleave", "sweep", "stab", "backstab",
    "slash", "chop", "ambush" }
local function Word(name, w) return name:find("%f[%a]" .. w .. "%f[%A]") ~= nil end
-- (no direct hit, the damage comes later as ticks: felt as you cast it)
local AT_CAST_WORDS = { "consecration", "totem", "trap", "rain", "blizzard", "volley", "hurricane" }
function V.FamilyOfName(name)
    if type(name) ~= "string" or secret(name) then return nil, nil end
    local lower = name:lower()
    local how = {}
    for _, w in ipairs(AT_CAST_WORDS) do
        if Word(lower, w) then how.atCast = true; return "surge", how end
    end
    for _, w in ipairs(MELEE_WORDS) do if Word(lower, w) then how.melee = true end end
    if Word(lower, "shot") or Word(lower, "shots") then how.ranged = true end
    for _, f in ipairs(NAME_FAMILIES) do
        if Word(lower, f[1]) then return f[2], how end
    end
    return nil, how
end

-- (what a window takes: a no-hit spell's only a miss, dodge, parry, resist
-- or immune; an ability we know nothing of only a magic wound (a swing, a
-- pet's blow are physical); a damaging cast only its own school's wound,
-- not in its first moment)
local function Pending(action, school)
    if not pending or GetTime() > pending.until_ then pending = nil; return nil end
    if secret(action) or not ABILITY_RESULT[action] then return nil end
    local wound = ABILITY_RESULT[action] == "hit"
    if wound then
        if pending.avoidOnly then return nil end
        if secret(school) then school = nil end
        if pending.magicOnly and (school == nil or school == PHYSICAL) then return nil end
        if pending.school and school and school ~= pending.school then return nil end
        if pending.notBefore and GetTime() < pending.notBefore then return nil end
    end
    local can = UnitCanAttack and UnitCanAttack("player", "target")
    if not secret(can) and not can then return nil end
    return pending
end
-- (the Lab may see the same blow after Rumble took it: claimed this frame)
local claimedAt

-- A UNIT_COMBAT result on your target is your ability's (the Lab leaves it)
function V.ClaimsResult(action, school)
    if claimedAt == GetTime() then return true end
    return V.ClaimsSwing(action, school) or Pending(action, school) ~= nil
end

-- Your ability's result: its feel at the blow (true: taken)
-- (school: an ability we don't know, its family from the damage: holy a
-- bright strike, another magic a shock)
local SCHOOL_FAMILY = { [2] = "judge", [4] = "shock", [8] = "shock", [16] = "shock", [32] = "shock", [64] = "judge" }
function V.AbilityResult(action, flag, school)
    local p = Pending(action, school)
    if not p then return false end
    pending = nil
    claimedAt = GetTime()
    if p.guessed and not secret(school) and SCHOOL_FAMILY[school] then p.move = SCHOOL_FAMILY[school] end
    local result = ABILITY_RESULT[action]
    if result == "hit" and not secret(flag) and flag == "CRITICAL" then result = "crit" end
    local now = GetTime()
    local delay = 0
    if p.ranged then
        delay = V.ImpactDelay("ranged", "ranged")
    elseif not p.spell then
        delay = V.ImpactDelay(V.WeaponKind(16), "main")
        -- (a next-swing ability is the main hand's swing: its timer goes on)
        if p.next then swing.last[16] = now end
    end
    AtImpact(delay, function()
        V.why1, V.why2, V.why3 = "ability " .. result, p.move, delay
        V.spellNow = p.name and { name = p.name, parent = "instant" } or nil
        V.AbilityImpact(p.move, result, p.ranged or p.spell, p.gain)
        V.why1, V.spellNow = nil, nil
    end)
    return true
end

---------------------------------------------------------------------------
-- Procs: a spell of yours you never cast, set off by an item or a talent
-- (Wolfsbane's Blazewind Blast, a pillar of fire). WoW Forever gives addons
-- no combat log, so a proc is only its wound on your target (UNIT_COMBAT:
-- no spell, no source). Taken as a proc: a wound no cast, ability or swing
-- of yours claimed, of a mixed school (two school bits or more: Holystorm is
-- holy and nature) that none of your own spells deals. A known proc plays as
-- itself (Your spells > Procs); another mixed school as Other procs. A proc
-- of one school stays unfelt: it can't be told from a DoT's tick.
---------------------------------------------------------------------------
-- spellID = its school mask (the client's tables), and WowHelperData.procs too
V.PROCS = { [1282503] = 10 } -- Blazewind Blast (Wolfsbane): Holystorm
V.OTHER_PROC, V.OTHER_PROC_NAME = "proc", "Other procs"
V.PROC_GAIN = 0.7            -- faint; a crit at full
local function Mixed(mask)
    if type(mask) ~= "number" or mask <= 0 then return false end
    local bits = 0
    for b = 0, 6 do if math.floor(mask / 2 ^ b) % 2 == 1 then bits = bits + 1 end end
    return bits > 1
end
local function Procs()
    local d = _G.WowHelperData
    local extra = type(d) == "table" and type(d.procs) == "table" and d.procs or nil
    if not extra then return V.PROCS end
    local all = {}
    for id, m in pairs(V.PROCS) do all[id] = m end
    for id, m in pairs(extra) do if type(id) == "number" and type(m) == "number" then all[id] = m end end
    return all
end
function V.IsProc(spellID)
    if spellID == V.OTHER_PROC then return true end
    return type(spellID) == "number" and not secret(spellID) and Procs()[spellID] ~= nil
end
-- The mixed schools your own spells deal (WoW Helper's spell kinds: Frostfire
-- Bolt, Living Flame), read again at most every 30 s, out of combat
local ownMasks, ownAt = {}, nil
local function OwnMasks()
    if ownAt and (GetTime() - ownAt < 30 or (InCombatLockdown and InCombatLockdown())) then return ownMasks end
    ownAt = GetTime()
    local P = ns.Picker
    local ok, lines = pcall(function() return P and P.SpellLines and P.SpellLines() or {} end)
    local masks = {}
    for _, line in ipairs(ok and type(lines) == "table" and lines or {}) do
        for _, e in ipairs(line.list or {}) do
            local k = V.SpellKinds(e.spell)
            if k and Mixed(k.school) then masks[k.school] = true end
        end
    end
    ownMasks = masks
    return masks
end
function V.ForgetOwnSchools() ownAt = nil end
-- A wound's proc (its spellID, or V.OTHER_PROC), nil: not one
function V.ProcOf(school)
    if secret(school) or not Mixed(school) or OwnMasks()[school] then return nil end
    for id, m in pairs(Procs()) do if m == school then return id end end
    return V.OTHER_PROC
end
-- Your spells > Procs: the known ones, then Other procs
function V.ProcList()
    local list = {}
    for id in pairs(Procs()) do
        local name = SpellName(id)
        if name and not secret(name) then
            local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
                or (GetSpellTexture and GetSpellTexture(id))
            list[#list + 1] = { id = id, name = name, icon = icon }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    list[#list + 1] = { id = V.OTHER_PROC, name = V.OTHER_PROC_NAME }
    return list
end
-- A proc's wound on your target: its feel now (true: taken)
function V.ProcLanded(id, crit)
    claimedAt = GetTime()
    local r = V.SpellRule(id)
    if r and r.off then V.SpellCue(r) end
    if not r or r.off or not r.pattern then return true end
    local gain = r.volume * (crit and 1 or V.PROC_GAIN)
    V.why1, V.why2 = crit and "proc crit" or "proc", r.name
    V.instantMove = r.pattern
    V.fireGain = gain < 1 and gain or nil
    FireAs(r.name, "instant")
    V.fireGain, V.why1 = nil, nil
    return true
end

-- The blow: a crit the Crit feel; a miss, dodge, parry, block the Beta
-- engine's own; a hit the ability's family
-- A damaging cast released: its feel at the impact, not the release (the
-- release silent): the next wound of its school on your target, from 0.15 s
-- to 2.5 s on (travel time), as Judgement (holy, arcane) or Shock (others)
V.CAST_IMPACT = { fire = { "shock", 4 }, frostSpells = { "shock", 16 }, arcaneSpells = { "judge", 64 },
    shadowSpells = { "shock", 32 }, holy = { "judge", 2 }, nature = { "shock", 8 } }
V.CAST_WINDOW = 2.5
function V.CastImpactWindow(action, gain)
    local f = V.CAST_IMPACT[action]
    if not f then return false end
    local now = GetTime()
    pending = { move = f[1], school = f[2], at = now, until_ = now + V.CAST_WINDOW, notBefore = now + 0.15,
        spell = true, gain = gain or 1 }
    return true
end

function V.AbilityImpact(move, result, far, gain)
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    if result == "crit" then return YourCrit(far and true or false) end
    if result ~= "hit" then
        local lab = LAB_RESULT[result]
        if lab and LabPlays(lab) then ns.HapticsLab.Fire(lab) end
        return
    end
    V.instantMove = move
    V.fireGain = gain and gain < 1 and gain or nil
    V.Fire("instant")
    V.fireGain = nil
end

---------------------------------------------------------------------------
-- Hit sync (on Timing's one sync): attack (or shoot) and squeeze R2 on each
-- impact you hear, the feels quiet meanwhile. Each squeeze pairs with the
-- nearest news, before or after it; the median of V.HIT_SYNC_TAPS, unless
-- they spread too wide, is kept for the weapon and hand. The raw pairs go
-- to the log (GamepadCompanionHapticsDB.timing.log).
---------------------------------------------------------------------------
V.HIT_SYNC_TAPS = 5
local function HitSay(text) if V.onHitSync then V.onHitSync(text) end end

-- What the sync sees, live: "swings 4 · squeezes 3 · paired 2"
local function HitSeen(s, paired)
    return string.format("swings %d · squeezes %d · paired %d", s.swings, s.squeezes, paired or s.paired or 0)
end

-- (no reading of the triggers: say so, once)
local function HitWatch(now)
    local s = V.hitSync
    if not s or s.noAxes ~= nil then return end
    local L = ns.HapticsLab
    local l = L and L.TriggerAxes and L.TriggerAxes()
    if l == nil and now - s.began > 1 then
        s.noAxes = true
        HitSay("Can't read R2 from the pad · use the seconds instead")
    elseif l ~= nil then
        s.noAxes = false
    end
end

function V.HitSync(kind, hand)
    if not kind then
        if ranged.auto then kind, hand = "ranged", "ranged" else kind, hand = V.WeaponKind(16), "main" end
    end
    local s = { kind = kind, hand = HandOf(kind, hand), anchors = {}, taps = {}, swings = 0, squeezes = 0,
        began = GetTime() }
    V.hitSync = s
    swing.tryLeft = nil
    ns.Timing.StartSync({ name = "hits",
        onTap = function(now) V.HitSyncTap(now) end,
        onUpdate = HitWatch,
        onStop = function(cancelled)
            if V.hitSync == s then V.hitSync = nil end
            if cancelled then HitSay("") end
        end })
    HitSay(ns.Timing.Label(kind) .. ": attack, squeeze R2 on each impact you hear · feels off meanwhile")
end

function V.HitSyncCancel()
    ns.Timing.StopSync("hits", true)
    V.hitSync = nil
end

-- A swing's (or shot's) news, for the sync
function V.HitSyncEvent(kind, hand, at)
    local s = V.hitSync
    if not s or kind ~= s.kind or hand ~= s.hand then return end
    s.anchors[#s.anchors + 1] = at
    s.swings = s.swings + 1
    while #s.anchors > 24 do table.remove(s.anchors, 1) end
    HitSay(HitSeen(s))
end

-- A squeeze at t: paired again with all the news; enough pairs, the fit.
-- Uneven: the oldest squeezes give way to new ones (never a silent restart).
-- Both lists logged each time (seconds after the sync began).
function V.HitSyncTap(t)
    local s = V.hitSync
    if not s then return nil end
    s.taps[#s.taps + 1] = t
    s.squeezes = s.squeezes + 1
    while #s.taps > 10 do table.remove(s.taps, 1) end
    local T = ns.Timing
    local delays = T.PairTaps(s.anchors, s.taps, Interval(s.hand) or 2)
    s.paired = #delays
    local function list(l)
        local out = {}
        for i, v in ipairs(l) do out[i] = string.format("%.2f", v - s.began) end
        return table.concat(out, " ")
    end
    local parts = {}
    for i, d in ipairs(delays) do parts[i] = string.format("%+.2f", d) end
    T.Log(T.Key(s.kind, s.hand) .. " swings " .. list(s.anchors) .. " | squeezes " .. list(s.taps)
        .. " | pairs " .. table.concat(parts, " "))
    if #delays < V.HIT_SYNC_TAPS then
        HitSay(HitSeen(s))
        return #delays
    end
    local d = T.FitDelay(delays, V.HIT_SYNC_TAPS)
    if not d then
        HitSay(HitSeen(s) .. " · uneven: keep squeezing on the sound")
        return #delays
    end
    T.Set(s.kind, s.hand, d)
    T.StopSync("hits")
    V.hitSync = nil
    if d < 0 then
        HitSay("Synced: the sound comes with the news: hits at once")
    else
        HitSay(string.format("Synced: %s hits %.2f s after the swing", T.Label(s.kind), d))
    end
    return #delays
end

-- Try: the next swings each play the weapon's swing feel at the impact (even
-- with Auto attack off), to check the timing by feel
V.HIT_TRY_SWINGS = 6
function V.HitTry()
    if V.hitSync then V.HitSyncCancel() end
    swing.tryLeft = V.HIT_TRY_SWINGS
    HitSay(swing.on and ("Try: the next " .. V.HIT_TRY_SWINGS .. " swings") or "Try: attack something")
end

function V.HitTrying() return (swing.tryLeft or 0) > 0 end

function V.SwingStart()
    swing.on, swing.last = true, {}
end

function V.SwingStop()
    swing.on = false
end

function V.Swinging() return swing.on end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_LEAVE_COMBAT")
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
-- (why: the event that set a moment off, for the debug window's fight log)
local function OnRumbleEvent(_, event, ...)
    if not IF.db then return end
    if event == "PLAYER_LEVEL_UP" then
        V.Fire("levelUp")
    elseif event == "PLAYER_ENTER_COMBAT" then
        V.SwingStart()
    elseif event == "PLAYER_LEAVE_COMBAT" then
        V.SwingStop()
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
end
events:SetScript("OnEvent", function(self, event, ...)
    V.why1, V.why2, V.why3 = event, ...
    OnRumbleEvent(self, event, ...)
    V.why1, V.why2, V.why3 = nil, nil, nil
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
local LOW_HP = 0.35   -- (as it ships: When.lua's; the game's warning is at 35 % too)
local low = false

-- The level it starts below (the row's When chip), and health as a fraction when it can be read
local function LowBelow()
    local W = ns.When
    return W and W.Get("lowHp", "below") or LOW_HP
end
local function HealthNow()
    local hp, max = UnitHealth("player"), UnitHealthMax("player")
    if secret(hp) or secret(max) or not max or max <= 0 then return nil end
    return hp / max
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
    -- (health readable: its own level decides; hidden: the warning)
    warning:HookScript("OnShow", function()
        if IF.db and not FullscreenPanel() and not UnitIsDeadOrGhost("player") then
            local f = HealthNow()
            if f then SetLow(f <= LowBelow()) else SetLow(true) end
        end
    end)
    warning:HookScript("OnHide", function()
        local f = HealthNow()
        if f and not UnitIsDeadOrGhost("player") then SetLow(f <= LowBelow()) else SetLow(false) end
    end)
end

local health = CreateFrame("Frame")
health:RegisterUnitEvent("UNIT_HEALTH", "player")
health:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
health:RegisterEvent("PLAYER_DEAD")
-- Health readable: below its level (When). Hidden: the game's warning does it, when it is on
function V.CheckLowHealth(event)
    if not IF.db then return end
    if event == "PLAYER_DEAD" or UnitIsDeadOrGhost("player") then return SetLow(false) end
    local f = HealthNow()
    if f then return SetLow(f <= LowBelow()) end
end
health:SetScript("OnEvent", function(_, event) V.CheckLowHealth(event) end)

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
-- Halo's rings: its event bus (H.On) says when a ring opens, its pick moves,
-- and it closes (with the slot used, or none)
local haloHooked = false
local function HookHalo()
    local halo = _G.Halo
    if haloHooked or type(halo) ~= "table" or type(halo.On) ~= "function" then return end
    haloHooked = true
    halo.On("open", function() V.Fire("haloOpen") end)
    halo.On("switch", function() V.Fire("haloOpen") end)
    halo.On("pick", function() V.Fire("wheelTick") end)
    halo.On("close", function(_, used) V.Fire(used and "haloUse" or "haloClose") end)
end
V.HookHalo = HookHalo

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == "GamepadCompanion" then
        IF.db = ns.Shared.CharDB()
        V.Settings()
    end
    HookHalo()
end)
