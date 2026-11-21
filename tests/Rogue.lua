-- A rogue: every rogue spell of the client and what it plays (tests/fixtures/rogue-spells.txt), then
-- the moments of its own: finishers by the combo points spent (whichever comes first, the points'
-- drop or the cast's news), Stealth in and out, Vanish, a poison put on a blade, Pick Lock, Poisons.
-- lua5.1 tests/Rogue.lua <addon folder>   (ROGUE_REPORT=1: the list, spell by spell)
local root = arg[1] or "."
local T = dofile(root .. "/tests/support/ClassHarness.lua")
local check, eq = T.check, T.eq
T.LoadSpells("rogue-spells.txt")
local V, RG = T.V, T.ns.Rogue
check(RG ~= nil, "Rogue.lua loads")

---------------------------------------------------------------------------
-- Coverage
---------------------------------------------------------------------------
T.Coverage("ROGUE", os.getenv("ROGUE_REPORT"))
for _, p in ipairs(RG.PATTERNS) do
    check(V.PULSES[p.key] ~= nil and #p.pulses > 0, p.key .. ": pulses")
    local ok = true
    for _, s in ipairs(p.steps) do if s[3] < 0.1 then ok = false end end
    check(ok, p.key .. ": every step 0.1 s or more")
    check(T.H.Feel("r_" .. p.key) ~= nil, p.key .. ": in the library")
end
T.game.class = "ROGUE"

---------------------------------------------------------------------------
-- Finishers: by the points spent
---------------------------------------------------------------------------
T.Capture()
local function Succeeded(id) T.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. id, id) end
local function Points(n) T.game.combo = n; T.Event("UNIT_POWER_UPDATE", "player", "COMBO_POINTS") end

-- Eviscerate: one cut, a cross cut, a flurry
for n, want in pairs({ [1] = "cut1", [2] = "cut1", [3] = "cut3", [4] = "cut3", [5] = "cut5" }) do
    Points(n)
    eq(V.SpellRule(31016, 0).pattern, want, "Eviscerate with " .. n)
end
-- (the points dropped just before the cast's news: the count before the drop)
Points(5)
T.Advance(0.1)
Points(0)
eq(V.SpellRule(2098, 0).pattern, "cut5", "Eviscerate: the points gone first, still five")
T.Advance(1)
eq(V.SpellRule(2098, 0).pattern, "cut5", "Eviscerate: no points known, as designed")
-- (and played: the cast's news before the drop, at the blow)
T.Clear()
Points(4)
Succeeded(31016)
Points(0)
T.Event("UNIT_COMBAT", "target", "WOUND", "", 900, 1)
T.Run(); T.Run()
check(T.Has("instant:cut3"), "Eviscerate (4): the cross cut at the blow")
-- (as sent: the points read before the client spends them, the drop long before the news)
T.Advance(2)
Points(2)
T.Event("UNIT_SPELLCAST_SENT", "player", "target", "cast-2098", 2098)
T.game.combo = 0
T.Advance(0.8)
eq(V.SpellRule(2098, 0).pattern, "cut1", "Eviscerate: the points as sent (2)")
-- Kidney Shot, Slice and Dice, Rupture: fainter with fewer points, full at five
T.Advance(2)
Points(1)
local one = V.RuleGain(V.SpellRule(408, 0))
Points(5)
local five = V.RuleGain(V.SpellRule(408, 0))
check(one < five and five == 1, "Kidney Shot: 1 point fainter than 5 (" .. one .. ", " .. five .. ")")
Points(2)
T.Clear()
Succeeded(5171)
check(T.Has("instant:sliceDice") and T.GainOf("instant:sliceDice") < 1, "Slice and Dice (2): faint, at the cast")
check(V.SpellRule(1943, 0).avoidOnly and V.SpellRule(408, 0).avoidOnly, "Rupture, Kidney Shot: a dodge of them still shows")

---------------------------------------------------------------------------
-- Stealth: the cloak in, a breath out (unless an opener says it); Vanish
---------------------------------------------------------------------------
T.Advance(5)
T.Clear()
Succeeded(1787)
check(T.Has("instant:cloak"), "Stealth: the cloak at the cast")
T.game.stealthed = true
T.Event("UPDATE_STEALTH")
T.Advance(10)
-- (out of it on its own: a breath, a moment later)
T.Clear()
T.game.stealthed = false
T.Event("UPDATE_STEALTH")
check(not T.Has("instant:emerge"), "out of stealth: the breath waits a moment")
T.Run()
check(T.Has("instant:emerge"), "out of stealth: a breath")
-- (an opener breaks it: the opener says it, either order)
T.game.stealthed = true
T.Event("UPDATE_STEALTH")
T.Advance(10)
T.Clear()
T.game.stealthed = false
T.Event("UPDATE_STEALTH")
T.Advance(0.05)
Succeeded(11269)
T.Run()
check(not T.Has("instant:emerge"), "Ambush out of stealth: no breath over it")
T.game.stealthed = true
T.Event("UPDATE_STEALTH")
T.Advance(10)
T.Clear()
Succeeded(1833)
T.game.stealthed = false
T.Event("UPDATE_STEALTH")
T.Run()
check(T.Has("instant:bash") and not T.Has("instant:emerge"), "Cheap Shot: the stun, no breath")
-- (Stealth cast again to leave it: the breath, not the cloak)
T.game.stealthed = true
T.Event("UPDATE_STEALTH")
T.Advance(10)
T.Clear()
Succeeded(1787)
T.game.stealthed = false
T.Event("UPDATE_STEALTH")
T.Run()
check(not T.Has("instant:cloak") and T.Has("instant:emerge"), "Stealth again: out, a breath")
-- Vanish: its own; the stealth it brings, nothing more
T.Advance(10)
T.Clear()
Succeeded(1857)
T.game.stealthed = true
T.Event("UPDATE_STEALTH")
T.Run()
check(T.Has("instant:vanish") and not T.Has("instant:cloak") and not T.Has("instant:emerge"), "Vanish: a puff, a roll, gone")
T.game.stealthed = false
T.Event("UPDATE_STEALTH")
T.Run()
-- (another class's stealth falling off: nothing)
T.game.class = "DRUID"
T.game.stealthed = true
T.Event("UPDATE_STEALTH")
T.Advance(10)
T.Clear()
T.game.stealthed = false
T.Event("UPDATE_STEALTH")
T.Run()
check(not T.Has("instant:emerge"), "a druid's prowl: not a rogue's breath")
T.game.class = "ROGUE"

---------------------------------------------------------------------------
-- A poison on a blade; Pick Lock; Poisons, the craft
---------------------------------------------------------------------------
local castEnd, castName
UnitCastingInfo = function() if castEnd then return castName, nil, nil, (castEnd - 3) * 1000, castEnd * 1000 end end
local function Cast(id, name, length)
    castName, castEnd = name, T.Now() + length
    T.Event("UNIT_SPELLCAST_START", "player", "cast-" .. id, id)
end
T.Advance(10)
T.Clear()
Cast(11340, "Instant Poison VI", 3)
eq(V.castAction, "feel:coat", "Instant Poison VI on a blade: its own set")
check(T.Has("cast"), "the coat's loop")
T.Advance(3)
T.Clear()
Succeeded(11340)
check(T.Has("play:coated"), "the blade coated")
-- (made in the Poisons window: the craft's grinding, not a coat)
T.game.trade = "Poisons"
Cast(11343, "Instant Poison VI", 3)
eq(V.castKind, "craft", "Instant Poison VI made: a craft")
T.game.trade = nil
T.Advance(3)
Succeeded(11343)
-- Pick Lock: the picks, then the lock giving
T.Clear()
Cast(1804, "Pick Lock", 5)
eq(V.castKind .. " " .. tostring(V.castAction), "gather opening", "Pick Lock: Opening's tumbler")
T.Advance(5)
T.Clear()
Succeeded(1804)
check(T.Has("play:unlock"), "Pick Lock: the lock gives")
Cast(3365, "Opening", 5)
eq(V.castAction, "opening", "Opening a chest: still Opening's")
T.Advance(5)
Succeeded(3365)
Cast(1842, "Disarm Trap", 2)
eq(V.castAction, "feel:click", "Disarm Trap: the tumbler too")
T.Advance(2)
Succeeded(1842)
UnitCastingInfo = nil

-- Thrown: at its landing (the ranged impact), not at the throw
check(V.SpellRule(399986, 0).how.ranged and V.SpellRule(400009, 0).how.ranged, "Shuriken Toss, Between the Eyes: from afar")
-- A thrown blade's crit: its own feel, then the crit (a class pattern is a spell's, as the mage's)
T.Clear()
V.AbilityImpact("shuriken", "crit", true, 1)
check(T.Has("instant:shuriken"), "Shuriken Toss crit: its own feel too")
-- Shiv: a nick, faint
check(V.RuleGain(V.SpellRule(424799, 0)) < 1, "Shiv: faint")

T.Done("Rogue")

-- WoW Helper's plans (SpellPlans.lua): a finisher at 3 points, a poison's coat on the rumble only
do
    assert(loadfile(root .. "/SpellPlans.lua"))("GamepadCompanion", T.ns)
    local SP = T.ns.SpellPlans
    T.game.combo = 0
    local p = SP.Plan(5171)
    check(p and p.sc and p.sc > 0 and p.sc < 1, "Slice and Dice's plan: a middling strength")
    check(T.ns.Combo.Spent() == 0, "the points as they were after")
    p = SP.Plan(8679)
    check(p and p.rumble and p.rumble[1] == "released" and not p.imp, "a poison: its coat on the rumble, no impact")
end
T.Done("Rogue plans")
