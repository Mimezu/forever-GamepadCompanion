-- A warrior: every warrior spell of the client and what it plays (tests/fixtures/warrior-spells.txt),
-- then the moments of its own: Charge's crash as it reaches the target, Slam's blow at the weapon's
-- impact, Whirlwind's bodies one by one, a shout's volume, Heroic Strike on the next swing.
-- lua5.1 tests/Warrior.lua <addon folder>   (WARRIOR_REPORT=1: the list, spell by spell)
local root = arg[1] or "."
local T = dofile(root .. "/tests/support/ClassHarness.lua")
local check, eq = T.check, T.eq
T.LoadSpells("warrior-spells.txt")
local V, WR = T.V, T.ns.Warrior
check(WR ~= nil and WR.SPELLS ~= nil, "Warrior.lua loads")

---------------------------------------------------------------------------
-- Coverage
---------------------------------------------------------------------------
T.Coverage("WARRIOR", os.getenv("WARRIOR_REPORT"))
-- (every pattern of Warrior.lua is in Rumble's list, with its pulses and steps of 0.1 s or more)
for _, p in ipairs(WR.PATTERNS) do
    check(V.PULSES[p.key] ~= nil and #p.pulses > 0, p.key .. ": pulses")
    local ok = true
    for _, s in ipairs(p.steps) do if s[3] < 0.1 then ok = false end end
    check(ok, p.key .. ": every step 0.1 s or more")
    check(T.H.Feel("r_" .. p.key) ~= nil, p.key .. ": in the library")
end
-- (another class: none of it)
T.game.class = "MAGE"
eq(T.Plays(V.SpellRule(1680, 0)), "instant whirl hit", "a mage's Whirlwind (none): Rumble's own move, not the warrior's")
T.game.class = "WARRIOR"

---------------------------------------------------------------------------
-- Moments
---------------------------------------------------------------------------
T.Capture()
local function Succeeded(id) T.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. id, id) end

-- Charge: the run at once; the crash when its stun lands on the target (from you), once
T.Clear()
Succeeded(100)
check(T.Has("instant:rush"), "Charge: the run as you set off")
check(not T.Has("instant:crash"), "Charge: no crash before you reach it")
T.Advance(0.4)
T.Event("UNIT_AURA", "target", { addedAuras = { { spellId = 7922, name = "Charge Stun", sourceUnit = "player" } } })
check(T.Has("instant:crash"), "Charge: the crash as its stun lands")
T.Clear()
T.Event("UNIT_AURA", "target", { addedAuras = { { spellId = 7922, name = "Charge Stun", sourceUnit = "player" } } })
check(not T.Has("instant:crash"), "Charge: one crash per charge")
-- (someone else's stun: not yours)
T.Clear()
Succeeded(100)
T.Event("UNIT_AURA", "target", { addedAuras = { { spellId = 7922, name = "Charge Stun", sourceUnit = "party1" } } })
check(not T.Has("instant:crash"), "Charge: another warrior's stun is theirs")
-- (too late: the charge is long over)
T.Advance(2)
T.Event("UNIT_AURA", "target", { addedAuras = { { spellId = 7922, name = "Charge Stun", sourceUnit = "player" } } })
check(not T.Has("instant:crash"), "Charge: nothing past its time")
-- (no list of what was added: the stun found on the target)
T.Clear()
Succeeded(100)
T.game.auras.target = { { id = 7922, source = "player" } }
T.Event("UNIT_AURA", "target", { isFullUpdate = true })
check(T.Has("instant:crash"), "Charge: a full update finds the stun")
T.game.auras.target = nil
-- Intercept: the run, the crash as its stun lands
T.Clear()
Succeeded(20617)
check(T.Has("instant:rush"), "Intercept: the run")
T.Advance(0.3)
-- (a wound on the target meanwhile (anyone's): not the arrival)
T.Event("UNIT_COMBAT", "target", "WOUND", "", 120, 1)
T.Run(); T.Run()
check(not T.Has("instant:crash"), "Intercept: someone's hit is not its arrival")
T.Event("UNIT_AURA", "target", { addedAuras = { { spellId = 20615, name = "Intercept Stun", sourceUnit = "player" } } })
check(T.Has("instant:crash"), "Intercept: the crash as its stun lands")
T.Advance(3)

-- Slam: the wind-up while it's cast, the blow at the weapon's impact (not the release)
T.Clear()
local castEnd
UnitCastingInfo = function() if castEnd then return "Slam", nil, nil, (castEnd - 1.5) * 1000, castEnd * 1000 end end
castEnd = T.Now() + 1.5
T.Event("UNIT_SPELLCAST_START", "player", "cast-11605", 11605)
eq(V.castAction, "feel:windup", "Slam: its own wind-up")
check(T.Has("cast"), "Slam: the wind-up loops")
T.Advance(1.5)
T.Clear()
Succeeded(11605)
castEnd = nil
check(not T.Has("instant:slamHit"), "Slam: nothing at the release")
T.Advance(0.1)
T.Event("UNIT_COMBAT", "target", "WOUND", "", 300, 1)
T.Run(); T.Run()
check(T.Has("instant:slamHit"), "Slam: the blow as it lands")
check(V.ClassSpellOf(11605).released ~= nil and not (V.ClassSpellOf(133) or {}).released, "Slam's release is the warrior's; a fireball's is not")
UnitCastingInfo = nil

-- Whirlwind: one feel, several bodies in it (three soft hits, left to right)
local p
for _, q in ipairs(WR.PATTERNS) do if q.key == "whirlwind" then p = q end end
local hits, left, right = 0, false, false
for _, u in ipairs(p.pulses) do
    if u[3] >= 0.25 then hits = hits + 1 end
    if u[4] < -0.5 then left = true end
    if u[4] > 0.5 then right = true end
end
check(hits >= 3 and left and right, "Whirlwind: three bodies, round you")
for _, u in ipairs(p.pulses) do check(u[3] < 0.6, "Whirlwind: soft hits, never one blob") end

-- Shouts: the buffs fainter than the big ones; Shield Block fainter than Shield Wall
check(V.RuleGain(V.SpellRule(25289, 0)) < 1 and V.RuleGain(V.SpellRule(5246, 0)) == 1, "Battle Shout fainter than Intimidating")
check(V.RuleGain(V.SpellRule(2565, 0)) < V.RuleGain(V.SpellRule(871, 0)), "Shield Block fainter than Shield Wall")
-- Concussion Blow, Disarm: a dodge of them still shows (their window takes no wound)
check(V.SpellRule(12809, 0).avoidOnly and V.SpellRule(676, 0).avoidOnly, "stuns at the cast: a dodge still shows")
check(not V.SpellRule(1680, 0).avoidOnly, "Whirlwind's blow is its own")
-- Heroic Strike, Cleave: on the next swing
check(V.SpellRule(25286, 0).next and V.SpellRule(20569, 0).next, "Heroic Strike, Cleave: the next swing")
-- Engraving a rune: Enchanting's shimmer
eq(T.Plays(V.SpellRule(403475, 3)), "cast enchanting", "a rune engraved")

T.Done("Warrior")
