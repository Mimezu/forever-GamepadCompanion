-- A priest's feels: what each priest spell plays (docs/PRIEST-WARLOCK.md). Rumble's V.SpellRule
-- asks the table here through V.MageOf (ClassSpells.lua); the patterns join Rumble's.
-- tests/PriestWarlock.lua lists every priest spell of the client and what it plays.
local _, ns = ...
local CS, V = ns.ClassSpells, ns.Rumble
local Pu = CS.Pu
local PR = {}
ns.Priest = PR

---------------------------------------------------------------------------
-- The patterns. Holy: light, bright and clean; shadow: low, close, dragging. Heals land warm,
-- their weight by their size; a DoT's word is faint (its ticks: the Lab's DoT ticks, off).
---------------------------------------------------------------------------
PR.PATTERNS = {
    -- (casts, at their release: no flight)
    { key = "smite", label = "Smite", art = "radiance",            -- a bright crack from above, a short ring
        pulses = { Pu(0, 0.05, 0.55), Pu(0.06, 0.08, 0.3), Pu(0.2, 0.05, 0.08) } },
    { key = "holyFire", label = "Holy Fire", art = "radiance",     -- the crack of light, fire catching and burning on
        pulses = { Pu(0, 0.06, 0.7), Pu(0.08, 0.12, 0.45), Pu(0.3, 0.05, 0.12, -0.4), Pu(0.45, 0.05, 0.1, 0.4),
            Pu(0.62, 0.05, 0.07, -0.2) } },
    { key = "mindBlast", label = "Mind Blast", art = "shadow",     -- a deep thump inside the head, the pressure let go
        pulses = { Pu(0, 0.08, 0.25), Pu(0.08, 0.2, 0.85), Pu(0.32, 0.05, 0.12) } },
    { key = "manaBurn", label = "Mana Burn", art = "static",       -- their mana fizzing out, then a pop
        pulses = { Pu(0, 0.05, 0.1, 0.6), Pu(0.08, 0.05, 0.12, 0.3), Pu(0.16, 0.05, 0.15), Pu(0.26, 0.1, 0.55) } },
    { key = "mindSpike", label = "Mind Spike", art = "stab",       -- a thin cold spike, quick
        pulses = { Pu(0, 0.05, 0.6, 0.3), Pu(0.07, 0.05, 0.18, 0.3) } },
    { key = "flash", label = "Flash", art = "burst",               -- Confounding Flash: a blinding pop in both hands
        pulses = { Pu(0, 0.05, 0.6, -1), Pu(0, 0.05, 0.6, 1), Pu(0.08, 0.05, 0.15), Pu(0.2, 0.05, 0.07) } },
    { key = "shackle", label = "Shackle", art = "latch",           -- chains of light clamping shut
        pulses = { Pu(0, 0.05, 0.3, -0.6), Pu(0.06, 0.05, 0.3, 0.6), Pu(0.16, 0.1, 0.45) } },
    { key = "vampTouch", label = "Vampiric Touch", art = "hex",    -- a touch that clings (faint: a DoT)
        pulses = { Pu(0, 0.1, 0.14), Pu(0.2, 0.05, 0.06, -0.5) } },
    { key = "voidZone", label = "Void Zone", art = "surge",        -- a pool of void opening on the ground
        pulses = { Pu(0, 0.2, 0.55), Pu(0.25, 0.05, 0.15, -0.7), Pu(0.3, 0.05, 0.15, 0.7), Pu(0.45, 0.15, 0.08) } },
    -- (heals, as they land: warm, their weight by their size)
    { key = "lesserHeal", label = "Lesser Heal", art = "mend",     -- a soft warmth landing
        pulses = { Pu(0, 0.12, 0.15), Pu(0.18, 0.05, 0.06) } },
    { key = "heal", label = "Heal", art = "mend",                  -- a warm swell, settling
        pulses = { Pu(0, 0.05, 0.12), Pu(0.08, 0.18, 0.3), Pu(0.32, 0.05, 0.08) } },
    { key = "greaterHeal", label = "Greater Heal", art = "mend",   -- a deep warm swell, held
        pulses = { Pu(0, 0.05, 0.15), Pu(0.08, 0.3, 0.45), Pu(0.45, 0.1, 0.15), Pu(0.65, 0.05, 0.06) } },
    { key = "flashHeal", label = "Flash Heal", art = "mend", move = true, -- quick and bright: a flick of warmth
        pulses = { Pu(0, 0.05, 0.35), Pu(0.07, 0.08, 0.15) } },
    { key = "prayerHeal", label = "Prayer of Healing", art = "mend", -- warmth spreading to all: a wave over both hands
        pulses = { Pu(0, 0.1, 0.25, -0.8), Pu(0.06, 0.1, 0.25, 0.8), Pu(0.18, 0.2, 0.4), Pu(0.45, 0.05, 0.1, -0.5),
            Pu(0.5, 0.05, 0.1, 0.5) } },
    { key = "bindingHeal", label = "Binding Heal", art = "mend",   -- two at once: a warm touch in each hand
        pulses = { Pu(0, 0.12, 0.3, -0.8), Pu(0.04, 0.12, 0.3, 0.8), Pu(0.25, 0.05, 0.08) } },
    { key = "lightwell", label = "Lightwell", art = "rise",        -- a column of light rising
        pulses = { Pu(0, 0.05, 0.08), Pu(0.12, 0.05, 0.14), Pu(0.24, 0.05, 0.22), Pu(0.36, 0.15, 0.4), Pu(0.6, 0.05, 0.08) } },
    { key = "resurrect", label = "Resurrection", art = "rise",     -- a breath drawn back into them, slow
        pulses = { Pu(0, 0.1, 0.08), Pu(0.15, 0.12, 0.18), Pu(0.32, 0.25, 0.45), Pu(0.65, 0.05, 0.1) } },
    -- (channels: one feel per tick)
    { key = "flay", label = "Mind Flay", art = "shadow",           -- a dragging tear across
        pulses = { Pu(0, 0.05, 0.18, -0.5), Pu(0.06, 0.1, 0.12), Pu(0.18, 0.05, 0.08, 0.5) } },
    { key = "sear", label = "Mind Sear", art = "shadow",           -- shadow searing round the target
        pulses = { Pu(0, 0.05, 0.12, -0.8), Pu(0.08, 0.05, 0.12, 0.8), Pu(0.16, 0.08, 0.18) } },
    { key = "penance", label = "Penance", art = "radiance",        -- a bolt of holy light, quick and bright
        pulses = { Pu(0, 0.05, 0.35), Pu(0.07, 0.06, 0.12) } },
    { key = "starshard", label = "Starshards", art = "arcane",     -- a star falling: a bright tap, a scatter
        pulses = { Pu(0, 0.05, 0.3), Pu(0.08, 0.05, 0.08, -0.6), Pu(0.13, 0.05, 0.06, 0.6) } },
    -- (a mind held: a slow pull, a twitch now and then)
    { key = "dominate", label = "Mind Control", art = "draw",
        pulses = { cycle = 1.2, Pu(0, 0.3, 0.06), Pu(0.55, 0.05, 0.1, 0.5), Pu(0.9, 0.05, 0.05, -0.3) } },
    -- (instants at the target)
    { key = "chastise", label = "Chastise", art = "judge", move = true, -- a flat slap of light, the target reeling
        pulses = { Pu(0, 0.12, 0.75), Pu(0.2, 0.05, 0.12, -0.4), Pu(0.32, 0.05, 0.07, 0.4) } },
    { key = "swDeath", label = "Shadow Word: Death", art = "shadow", move = true, -- a heavy dark crack, its echo back at you
        pulses = { Pu(0, 0.1, 0.85), Pu(0.18, 0.05, 0.15, -0.6), Pu(0.3, 0.06, 0.25, -0.6) } },
    { key = "pain", label = "Shadow Word: Pain", art = "hex", move = true, -- a word whispered: a faint cold prick
        pulses = { Pu(0, 0.05, 0.12, -0.3), Pu(0.18, 0.05, 0.05, -0.3) } },
    { key = "plague", label = "Plague", art = "hex", move = true,  -- a sickness creeping in, faint
        pulses = { Pu(0, 0.05, 0.1), Pu(0.15, 0.05, 0.07, -0.4), Pu(0.3, 0.05, 0.06, 0.4), Pu(0.48, 0.05, 0.04) } },
    { key = "embrace", label = "Vampiric Embrace", art = "hex", move = true, -- warmth drawn back to you
        pulses = { Pu(0, 0.05, 0.06, 0.6), Pu(0.12, 0.05, 0.09), Pu(0.24, 0.08, 0.12, -0.6) } },
    -- (around you: both hands)
    { key = "holyNova", label = "Holy Nova", art = "burst", move = true, -- light bursting out of you
        pulses = { Pu(0, 0.05, 0.35, -1), Pu(0, 0.05, 0.35, 1), Pu(0.05, 0.12, 0.7), Pu(0.2, 0.05, 0.2, -1), Pu(0.2, 0.05, 0.2, 1),
            Pu(0.34, 0.05, 0.08) } },
    { key = "scream", label = "Psychic Scream", art = "burst", move = true, -- a hard shove in both hands, trembling out
        pulses = { Pu(0, 0.15, 0.85), Pu(0.2, 0.05, 0.3, -1), Pu(0.26, 0.05, 0.3, 1), Pu(0.34, 0.05, 0.18, -1),
            Pu(0.4, 0.05, 0.18, 1), Pu(0.5, 0.05, 0.08) } },
    { key = "circle", label = "Circle of Healing", art = "mend", move = true, -- a ring of light passing both hands
        pulses = { Pu(0, 0.05, 0.2, -1), Pu(0.08, 0.05, 0.25), Pu(0.16, 0.05, 0.2, 1), Pu(0.26, 0.12, 0.3) } },
    { key = "barrier", label = "Barrier", art = "ward", move = true, -- a dome set down, then held
        pulses = { Pu(0, 0.15, 0.55), Pu(0.22, 0.05, 0.15, -1), Pu(0.22, 0.05, 0.15, 1), Pu(0.4, 0.2, 0.08) } },
    -- (at the cast: heals over time, shields, yourself)
    { key = "renew", label = "Renew", art = "mend", move = true,   -- a soft pulse, a gentle hum after
        pulses = { Pu(0, 0.05, 0.18), Pu(0.15, 0.05, 0.07), Pu(0.3, 0.05, 0.05) } },
    { key = "mending", label = "Prayer of Mending", art = "mend", move = true, -- a prayer hopping on: hand to hand
        pulses = { Pu(0, 0.05, 0.2, -0.6), Pu(0.18, 0.05, 0.14, 0.6), Pu(0.36, 0.05, 0.09, -0.2) } },
    { key = "desperate", label = "Desperate Prayer", art = "mend", move = true, -- a gasp, warmth flooding back
        pulses = { Pu(0, 0.05, 0.3), Pu(0.1, 0.25, 0.5), Pu(0.4, 0.05, 0.1) } },
    { key = "pwShield", label = "Power Word: Shield", art = "ward", move = true, -- a bright shell closing round you
        pulses = { Pu(0, 0.05, 0.15, -1), Pu(0, 0.05, 0.15, 1), Pu(0.08, 0.05, 0.25, -0.5), Pu(0.08, 0.05, 0.25, 0.5),
            Pu(0.16, 0.2, 0.45) } },
    { key = "innerFire", label = "Inner Fire", art = "kindle", move = true, -- a fire kindled in the chest
        pulses = { Pu(0, 0.05, 0.08), Pu(0.1, 0.05, 0.14), Pu(0.2, 0.15, 0.3), Pu(0.4, 0.05, 0.07) } },
    { key = "focus", label = "Inner Focus", art = "tick", move = true, -- a breath held, then one beat
        pulses = { Pu(0, 0.1, 0.06), Pu(0.35, 0.05, 0.18) } },
    { key = "cleanse", label = "Cleanse", art = "sweep", move = true, -- brushed away, left to right
        pulses = { Pu(0, 0.05, 0.15, -0.8), Pu(0.08, 0.05, 0.12), Pu(0.16, 0.05, 0.08, 0.8) } },
    { key = "fadeOut", label = "Fade", art = "fade", move = true,  -- fading from their eyes, thinning
        pulses = { Pu(0, 0.12, 0.15), Pu(0.18, 0.1, 0.08), Pu(0.34, 0.1, 0.04) } },
    { key = "shadowform", label = "Shadowform", art = "shadow", move = true, -- darkness wrapping round you, close
        pulses = { Pu(0, 0.2, 0.2, -0.4), Pu(0.15, 0.2, 0.2, 0.4), Pu(0.4, 0.15, 0.35), Pu(0.6, 0.05, 0.06) } },
    { key = "dispersion", label = "Dispersion", art = "shadow", move = true, -- breaking into shadow, scattering
        pulses = { Pu(0, 0.1, 0.45), Pu(0.12, 0.05, 0.15, -0.8), Pu(0.18, 0.05, 0.13, 0.7), Pu(0.26, 0.05, 0.1, -0.4),
            Pu(0.33, 0.05, 0.08, 0.9), Pu(0.42, 0.05, 0.05, -0.9) } },
    { key = "fiend", label = "Shadowfiend", art = "ritual", move = true, -- a shadow torn open, something stepping out
        pulses = { Pu(0, 0.05, 0.15, -0.6), Pu(0.06, 0.05, 0.15, 0.6), Pu(0.15, 0.15, 0.5), Pu(0.38, 0.05, 0.12) } },
    -- (yours given for mana: Dark Sacrifice; a warlock's Life Tap)
    { key = "lifeTap", label = "Life Tap", art = "draw", move = true, -- a dull pull from you, then the rush
        pulses = { Pu(0, 0.15, 0.35, -0.3), Pu(0.2, 0.05, 0.08), Pu(0.3, 0.12, 0.25, 0.3) } },
    -- (the Lab's DoT ticks: a faint prick)
    { key = "dotTick", label = "DoT tick", art = "micro", group = "Combat",
        pulses = { Pu(0, 0.05, 0.07) } },
}
if V and V.AddPatterns then V.AddPatterns(PR.PATTERNS) end

---------------------------------------------------------------------------
-- What each priest spell plays (the first rank's ID: every rank by its name). Engraving a rune:
-- Enchanting's shimmer.
---------------------------------------------------------------------------
PR.RULES = {
    -- Holy and shadow casts, at their release (no flight: the wound comes with it)
    { { burst = "smite" }, { 585 } },
    { { burst = "holyFire" }, { 14914 } },
    { { burst = "mindBlast" }, { 8092 } },
    { { burst = "manaBurn" }, { 8129 } },
    { { burst = "mindSpike" }, { 431655 } },
    { { burst = "flash" }, { 1277455 } },                       -- Confounding Flash (Forever)
    { { burst = "shackle" }, { 9484 } },
    { { burst = "vampTouch" }, { 402668 } },
    { { burst = "voidZone" }, { 431681 } },
    -- Heals as they land
    { { burst = "lesserHeal" }, { 2050 } },
    { { burst = "heal" }, { 2054 } },
    { { burst = "greaterHeal" }, { 2060 } },
    { { burst = "flashHeal" }, { 2061 } },
    { { burst = "prayerHeal" }, { 596 } },
    { { burst = "bindingHeal" }, { 401937 } },
    { { burst = "lightwell" }, { 724 } },
    { { set = "healing", burst = "resurrect" }, { 2006 } },
    -- Channels, per tick (Mind Flay 3 over 3 s, by turns; Mind Sear, Starshards 6 over 6 s; Penance
    -- 2 more after its first bolt, here at its start)
    { { tick = "flay", ticks = 3, alternate = true }, { 15407 } },
    { { tick = "sear", ticks = 6 }, { 413259 } },
    { { tick = "penance", ticks = 2, alternate = true, first = true }, { 402174, 402289 } },
    { { tick = "starshard", ticks = 6, alternate = true }, { 10797 } },
    { { set = "feel:dominate" }, { 605 } },                      -- Mind Control
    { { set = "farsight" }, { 2096 } },                          -- Mind Vision
    -- At the target
    { { move = "chastise", when = "hit" }, { 1277331 } },
    { { move = "swDeath", when = "hit" }, { 401955 } },
    -- DoTs and debuffs: faint
    { { move = "pain", when = "cast" }, { 589 } },
    { { move = "plague", when = "cast" }, { 2944, 425204 } },     -- Devouring Plague, Void Plague
    { { move = "hex", when = "cast" }, { 9035 } },                -- Hex of Weakness
    { { move = "embrace", when = "cast" }, { 15286 } },
    { { move = "counterspell", when = "cast" }, { 15487 } },      -- Silence
    -- Around you
    { { move = "holyNova", when = "cast" }, { 15237 } },
    { { move = "scream", when = "cast" }, { 8122 } },
    { { move = "circle", when = "cast" }, { 401946 } },
    { { move = "barrier", when = "cast" }, { 425207 } },          -- Power Word: Barrier
    -- At the cast
    { { move = "renew", when = "cast" }, { 139, 7001 } },         -- Renew, Lightwell Renew
    { { move = "mending", when = "cast" }, { 401859 } },
    { { move = "desperate", when = "cast" }, { 13908 } },
    { { move = "flashHeal", when = "cast" }, { 1277370 } },       -- Divine Grace (Forever)
    { { move = "pwShield", when = "cast" }, { 17 } },
    { { move = "innerFire", when = "cast" }, { 588 } },
    { { move = "ward", when = "cast" }, { 6346, 402004 } },        -- Fear Ward, Pain Suppression
    { { move = "updraft", when = "cast" }, { 1706 } },            -- Levitate
    { { move = "empower", when = "cast" }, { 10060 } },           -- Power Infusion
    { { move = "focus", when = "cast" }, { 14751 } },             -- Inner Focus
    { { move = "cleanse", when = "cast" }, { 527, 528, 552 } },   -- Dispel Magic, Cure and Abolish Disease
    { { move = "fadeOut", when = "cast" }, { 586 } },
    { { move = "shadowform", when = "cast" }, { 15473 } },
    { { move = "dispersion", when = "cast" }, { 425294 } },
    { { move = "fiend", when = "cast" }, { 401977, 402799, 402789 } }, -- Shadowfiend, Homunculi, Eye of the Void
    { { move = "lifeTap", when = "cast" }, { 1277324 } },        -- Dark Sacrifice (Forever)
    { { move = "mantle", when = "cast" }, { 18137, 2652 } },      -- Shadowguard, Touch of Weakness
    -- Fortitude, Spirit, Shadow Protection and their prayers; Elune's Grace, Feedback, Mind Soothe;
    -- Contingency Plan (Forever)
    { { move = "glow", when = "cast" }, { 1243, 21562, 14752, 27681, 976, 27683, 2651, 13896, 453, 1277462 } },
}
PR.Of = CS.Register("PRIEST", PR.RULES)

-- Your DoTs (their ticks: the Lab's DoT ticks), by school
CS.AddDots("PRIEST", { [589] = 32, [2944] = 32, [425204] = 32, [402668] = 32, [14914] = 2 })

---------------------------------------------------------------------------
-- Penance: its first bolt as the channel starts (Rumble plays the two after it on its ticks)
---------------------------------------------------------------------------
function PR.ChannelStarted(spellID)
    if not spellID or (issecretvalue and issecretvalue(spellID)) then return end
    local m = PR.Of(spellID)
    if not (m and m.first and m.tick and V) then return end
    -- (Your spells: off, its own set instead, or its volume)
    local rule = V.SpellRule and V.SpellRule(spellID, 1)
    if rule and (rule.off or (rule.own and rule.set ~= rule.ruleSet)) then return end
    local gain = rule and rule.volume or 1
    if V.Active and V.Active() and V.Play then V.Play(m.tick, false, gain < 1 and { strength = gain } or nil) end
    if V.TickHD then V.TickHD(m.tick, 0, m.alternate) end
end

local frame = CreateFrame("Frame")
PR.frame = frame
if not pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_CHANNEL_START", "player") then
    pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_CHANNEL_START")
end
frame:SetScript("OnEvent", function(_, _, unit, _, spellID)
    if unit == "player" then PR.ChannelStarted(spellID) end
end)
