-- lua5.1 tests/TriggerStack.lua .   (from the addon folder)
local root = arg and arg[1] or "."
local now = 100
GetTime = function() return now end
local timers = {}
C_Timer = { After = function(d, fn) timers[#timers + 1] = { at = now + d, fn = fn } end }
local function RunTimers()
    local list = timers
    timers = {}
    for _, t in ipairs(list) do if t.at <= now then t.fn() else timers[#timers + 1] = t end end
end
UnitClass = function() return "Paladin", "PALADIN" end
local health, power = 1000, 50
UnitHealth = function() return health end
UnitHealthMax = function() return 1000 end
UnitPower = function() return power end
UnitPowerMax = function() return 100 end
UnitAttackSpeed = function() return 3.6 end
UnitRangedDamage = function() return 2.8 end
local cooldowns = {}
GetSpellCooldown = function(s) local c = cooldowns[s]; if c then return c[1], c[2] end return 0, 0 end
GetComboPoints = function() return 0 end

local db = { link = { on = true } }
local ns = { Haptics = { DB = function() return db end } }
for _, f in ipairs({ "HelperLink.lua", "TriggerRules.lua", "Stack.lua", "TriggerStack.lua" }) do
    assert(loadfile(root .. "/" .. f))("GamepadCompanion", ns)
end
local K, St, TS, T = ns.HelperLink, ns.Stack, ns.TriggerStack, ns.TriggerRules
GamepadCompanionHapticsDB = { link = { on = true } }
local kind = TS.kind

local n, failed = 0, 0
local function check(ok, what)
    n = n + 1
    if not ok then failed = failed + 1; print("FAIL " .. what) end
end

-- the Paladin's Recommended stack (R2 the hand, L2 the body)
local rows = kind:Rows()
check(rows[1].condition == "ready:Judgement" and rows[2].condition == "ready:Hammer of Justice", "ready clicks first")
check(rows[3].condition == "cast" and rows[3].R2.shape == TS.ID.tension and rows[3].R2.follows == "cast", "cast tension follows the cast")
local body = {}
for _, r in ipairs(rows) do if r.L2 then body[#body + 1] = r.condition end end
check(table.concat(body, ",") == "player_health,mounted,swimming", "L2: health, mount, water: " .. table.concat(body, ","))
for _, r in ipairs(rows) do check((r.R2 == nil) ~= (r.L2 == nil), r.id .. ": one trigger a row (the other passes)") end

-- order: the first match wins per trigger; an event on top hands back
St.Set("cast", true)
St.SetValue("cast", 0.25)
kind:Refresh(true)
local res = kind:Now()
check(res.R2.row and res.R2.row.condition == "cast" and res.R2.value.value == 0.25, "casting: R2 Cast tension at 0.25")
check(res.L2.row == nil, "L2 free")
check(K.trig and K.trig.right.shape == TS.ID.tension and K.trig.right.value == 0.25, "the trigger row carries it")
St.Fire("ready:Judgement")
res = kind:Now()
check(res.R2.row.condition == "ready:Judgement" and res.R2.value.effect == TS.ID.ready, "Judgement ready: the click on top")
now = now + 0.5
RunTimers()
check(kind:Now().R2.row.condition == "cast", "and hands back to the cast")
-- reorder: the cast above the ready click
kind:MoveTo("cast", 1)
St.Fire("ready:Judgement")
check(kind:Now().R2.row.condition == "cast", "moved up: the cast wins")
kind:Default()
St.Set("cast", false)
now = now + 1   -- (the ready click over)

-- gauges: the values pushed from the game
St.Set("autoAttack", true)
TS.Update({ autoAttack = true, swingAt = now - 1.8 })
res = kind:Now()
check(res.R2.row.condition == "autoAttack" and math.abs(res.R2.value.value - 0.5) < 0.011, "half a 3.6 s swing: 0.5")
health = 200
St.ReadAll()
TS.Update({})
res = kind:Now()
check(res.L2.row and res.L2.row.condition == "player_health" and math.abs(res.L2.value.value - 0.8) < 0.011, "20 % health: Weight at 0.8")
health = 1000
St.ReadAll()
TS.Update({})
check(kind:Now().L2.row == nil, "healthy: L2 free")

-- detents: a count
local row = kind:Add("combat")
TS.SetChannel(row.id, "R2", TS.ID.detents)
check(row.R2.count == "combo", "detents count combo points")
GetComboPoints = function() return 3 end
TS.Update({})
St.Set("combat", true)
kind:Refresh(true)
check(kind:Now().R2.value.count == 3 and K.trig.right.count == 3, "three combo points: three detents on the row")
GetComboPoints = function() return 0 end
kind:Remove(row.id)
St.Set("combat", false)

-- ready clicks: a cooldown (beyond the GCD) back
cooldowns["Judgement"] = { now - 1, 8 }
TS.CheckReady()
cooldowns["Judgement"] = nil
TS.CheckReady()
check(St.Is("ready:Judgement"), "Judgement back: its moment")

-- Pass and the near equivalent for an older helper
now = now + 1   -- (the ready click over)
TS.Update({ cast = true, progress = 1 })
check(K.state.right.mode == K.MODES.resist and K.state.right.force == 13, "cast at its end: the old bytes' force 13 on the strip's own fields")
TS.Update({})

-- Try: a row's triggers for a few seconds, its value sweeping
kind:Default()
check(TS.Try("swing", 2), "Try")
check(K.trig.right.shape == TS.ID.swing and K.trig.right.value == 0, "trying: the swing at 0")
now = now + 1
RunTimers()
check(K.trig.right.value > 0.5, "sweeping up")
now = now + 2
RunTimers()
check(TS.Trying() == nil, "then back to the stack")

-- the old Setup rules move once, silently, each keeping its bytes; then the Recommended ones
db.triggerStack = nil
db.link.trigRules = { v = 1, list = {
    { on = true, when = "cast", side = "both", effect = "resist", from = 3, strength = 13, grow = true },
    { on = true, when = "autoShot", side = "R2", effect = "weapon", from = 4, to = 8, strength = 7 },
    { on = false, when = "lowHp", side = "L2", effect = "vibrate", from = 0, strength = 5, speed = 3 } } }
rows = kind:Rows()
check(rows[1].id == "old1" and rows[1].R2 and rows[1].L2 and rows[1].R2.legacy and rows[1].R2.follows == "cast", "Casting · Both · Resist: both triggers, its bytes")
check(rows[3].on == false and rows[3].L2.legacy.effect == "vibrate", "an old rule off stays off")
check(rows[4] and rows[4].condition == "ready:Judgement", "the Recommended ones below")
St.Set("cast", true)
TS.Update({ cast = true, progress = 0.5 })
local mode, a, b, c = T.Params(T.Clean({ when = "cast", side = "R2", effect = "resist", from = 3, strength = 13, grow = true }), 0.5)
check(K.state.right.mode == K.MODES[mode] and K.state.right.start == a and K.state.right.force == c and K.state.left.force == c,
    "the same bytes as before (resist from 3, force " .. c .. ")")
check(K.trig == nil or K.trig.right.shape == 0, "and no shape on the row: the old bytes rule")
db.link.trigRules.list[1].on = false
kind:Rows()
check(rows[1].on == true, "moved once: never again")

print(string.format("TriggerStack: %s (%d checks)", failed == 0 and "ok" or (failed .. " failed"), n))
os.exit(failed == 0 and 0 or 1)
