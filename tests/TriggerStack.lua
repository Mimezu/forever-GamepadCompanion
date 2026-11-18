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

-- Link off, then on: the stack's triggers come back (night review T2-1)
kind:Default()
St.Set("cast", true)
TS.Update({ cast = true, progress = 0.5 })
check(K.trig and K.trig.right.shape == TS.ID.tension, "casting: Cast tension on the row")
K.SetEnabled(false)
check(K.trig == nil and K.state.right.mode == 0, "Link off: the triggers free")
TS.Update({ cast = true, progress = 0.5 })
TS.Update({ cast = true, progress = 0.5 })
K.SetEnabled(true)
check(K.trig and K.trig.right.shape == TS.ID.tension and math.abs((K.trig.right.value or 0) - 0.5) < 0.011,
    "Link on: Cast tension back on the row")
check(K.state.right.mode ~= 0, "Link on: the strip's own fields back")
-- (and with no game update between)
K.SetEnabled(false)
K.SetEnabled(true)
check(K.trig and K.trig.right.shape == TS.ID.tension and K.state.right.mode ~= 0, "Link off and on at once: back")
St.Set("cast", false)
TS.Update({})

-- the old Setup rules: only the player's own edits move (T2-2), each keeping its bytes.
-- Alberich's saved list (SavedVariables, 0.49): rule 1 made "both"; rules 2 and 3 as shipped.
local function Alberich()
    return { v = 1, list = {
        { grow = true, side = "both", effect = "resist", on = true, from = 3, when = "cast", speed = 3, to = 15, strength = 13 },
        { grow = false, to = 8, effect = "weapon", on = true, from = 4, when = "autoShot", speed = 3, strength = 7, side = "R2" },
        { grow = false, side = "L2", effect = "vibrate", on = true, from = 0, when = "lowHp", to = 15, speed = 3, strength = 5 } } }
end
local function Ids(list)
    local out = {}
    for _, r in ipairs(list) do out[#out + 1] = r.id .. (r.on and "" or "-") end
    return table.concat(out, ",")
end
local REC = Ids(TS.Recommended())
local function Off(ids, id) return (("," .. ids .. ","):gsub("," .. id:gsub("%p", "%%%0") .. ",", "," .. id .. "-,")):sub(2, -2) end
db.triggerStack = nil
db.link.trigRules = Alberich()
rows = kind:Rows()
check(rows[1].id == "old1" and rows[1].R2 and rows[1].L2 and rows[1].R2.legacy and rows[1].R2.follows == "cast", "Casting · Both · Resist: both triggers, its bytes")
check(rows[2].id == "ready:Judgement" and #rows == 1 + #TS.Recommended(), "the shipped two don't move: " .. Ids(rows))
check(TS.Words(rows[1].R2) == "Resist · old · follows Cast" and TS.Words(rows[1].R2, true) == "Resist · old · Cast", "a moved rule: 'old'")
St.Set("cast", true)
TS.Update({ cast = true, progress = 0.5 })
local mode, a, b, c = T.Params(T.Clean({ when = "cast", side = "R2", effect = "resist", from = 3, strength = 13, grow = true }), 0.5)
check(K.state.right.mode == K.MODES[mode] and K.state.right.start == a and K.state.right.force == c and K.state.left.force == c,
    "the same bytes as before (resist from 3, force " .. c .. ")")
check(K.trig == nil or K.trig.right.shape == 0, "and no shape on the row: the old bytes rule")
St.Set("cast", false)
TS.Update({})
db.link.trigRules.list[1].on = false
check(kind:Rows()[1].on == true, "moved once: never again")

-- every rule as shipped: the Recommended reactions, untouched (T2-2)
local function Fresh(list, cues)
    db.triggerStack, db.link.cues = nil, cues
    db.link.trigRules = list
    return kind:Rows()
end
check(Ids(Fresh({ v = 1, list = T.Defaults() })) == REC and kind:IsDefault(), "all as shipped: Recommended, the Default link kept")
-- a shipped rule turned off (or its old switch): its equivalent off, the rest on
local off = T.Defaults()
off[3].on = false
check(Ids(Fresh({ v = 1, list = off })) == Off(REC, "hurt"), "Low health off: Weight off")
check(Ids(Fresh({ v = 1, list = T.Defaults({ castTrigger = false }) }, { castTrigger = false })) == Off(REC, "cast"),
    "the old cast switch off: Cast tension off")
-- a shipped rule removed: its equivalent off
local two = T.Defaults()
table.remove(two, 1)
check(Ids(Fresh({ v = 1, list = two })) == Off(REC, "cast"), "the cast rule removed: Cast tension off")
-- every rule removed: the triggers stay quiet (T2-3)
rows = Fresh({ v = 1, list = {} })
local anyOn = false
for _, r in ipairs(rows) do if r.on then anyOn = true end end
check(#rows == #TS.Recommended() and not anyOn, "an emptied list: every reaction off, " .. Ids(rows))
St.Set("cast", true)
TS.Update({ cast = true, progress = 0.5 })
check(K.trig == nil and K.state.right.mode == 0, "and nothing drives")
St.Set("cast", false)
TS.Update({})
-- never set up (no old list): Recommended
check(Ids(Fresh(nil)) == REC, "no old list: Recommended")

-- a profile moved by 0.50-0.53.1 (every rule on top): repaired once, carefully
local function OldForm(list)
    local out = {}
    for i, r in ipairs(list) do out[#out + 1] = TS.OldRow(i, T.Clean(St.Copy(r))) end
    for _, r in ipairs(TS.Recommended()) do out[#out + 1] = St.Copy(r) end
    return out
end
db.link.cues = nil
db.link.trigRules = Alberich()
db.triggerStack = { migrated = true, nextID = 1, rows = OldForm(Alberich().list) }
rows = kind:Rows()
check(rows[1].id == "old1" and rows[2].id == "ready:Judgement" and #rows == 1 + #TS.Recommended(), "Alberich repaired: his rule, then Recommended: " .. Ids(rows))
check(db.triggerStack.repaired == true and type(db.triggerStack.old) == "table", "once, the old rules kept")
-- an old row the player changed since stays
db.link.trigRules = Alberich()
db.triggerStack = { migrated = true, nextID = 1, rows = OldForm(Alberich().list) }
db.triggerStack.rows[2].condition = "combat"   -- (old2 edited)
db.triggerStack.rows[3].on = false              -- (old3 turned off)
rows = kind:Rows()
check(Ids(rows):find("old2", 1, true) and Ids(rows):find("old3-", 1, true), "an edited old row stays: " .. Ids(rows))
-- an emptied list moved by 0.50: every untouched Recommended reaction off
db.link.trigRules = { v = 1, list = {} }
db.triggerStack = { migrated = true, nextID = 1, rows = OldForm({}) }
db.triggerStack.rows[2].R2.shape = TS.ID.click   -- (changed: left as it is)
rows = kind:Rows()
check(rows[1].on == false and rows[2].on == true and rows[#rows].on == false, "emptied: untouched ones off, a changed one kept: " .. Ids(rows))
-- repaired already: never again
db.triggerStack.rows[1].on = true
kind:Rows()
check(db.triggerStack.rows[1].on == true, "repaired once")

-- an unknown shape id (a helper's own shape since removed): no error, the strip's fields off
db.triggerStack, db.link.trigRules = nil, nil
St.Set("cast", false)
row = kind:Add("always")
row.R2 = { shape = 999 }
kind:Refresh(true)
check(K.trig and K.trig.right.shape == 999 and K.state.right.mode == 0, "unknown shape: on the row, the strip's own fields off")
check(TS.Words(row.R2) == "Shape 999", "named by its number")
kind:Remove(row.id)
-- Hush frees both triggers
St.Set("cast", true)
TS.Update({ cast = true, progress = 0.5 })
check(K.trig and K.trig.right.shape == TS.ID.tension, "casting: tension")
St.Set("hush", true)
check(K.trig == nil and K.state.right.mode == 0 and K.state.left.mode == 0, "hushed: both free")
St.Set("hush", false)
check(K.trig and K.trig.right.shape == TS.ID.tension, "unhushed: back")
-- Stop ends a Try at once (T2-13)
check(TS.Try("swing", 3), "Try")
TS.Stop()
check(TS.Trying() == nil and K.trig and K.trig.right.shape == TS.ID.tension, "Stop: the Try over, the stack back")
-- a gauge moving by 1/100 always reaches the row (T2-9)
local missed = 0
for i = 0, 99 do
    TS.Update({ cast = true, progress = i / 100 })
    if not (K.trig and math.abs(K.trig.right.value - i / 100) < 0.001) then missed = missed + 1 end
end
check(missed == 0, "every 1/100 step sent (" .. missed .. " missed)")
St.Set("cast", false)
TS.Update({})
-- a migrated grow rule that isn't Casting: full strength outside a cast, as before (T2-10)
db.triggerStack = nil
db.link.trigRules = { v = 1, list = { { on = true, when = "combat", side = "R2", effect = "resist", from = 3, strength = 13, grow = true } } }
kind:Rows()
St.Set("combat", true)
kind:Refresh(true)
check(K.state.right.mode == K.MODES.resist and K.state.right.force == 13, "In combat · grow, no cast: force 13 (" .. K.state.right.force .. ")")
St.Set("combat", false)
-- hidden cooldowns (secret in combat): no error, no GCD (T2-7)
issecretvalue = function(v) return v == "secret" end
C_Spell = { GetSpellCooldown = function() return { startTime = "secret", duration = "secret" } end }
local ok, err = pcall(TS.Update, {})
check(ok and TS.Cooldown(61304) == nil, "secret cooldowns: nothing known, no error " .. tostring(err))
C_Spell, issecretvalue = nil, nil
db.link.trigRules = nil
db.triggerStack = nil

-- Default, with Undo: Alberich's moved rule comes back (T2-4)
db.triggerStack = nil
db.link.trigRules = Alberich()
check(kind:Rows()[1].id == "old1", "his rule on top")
local undo, still = TS.Default()
check(undo and kind:Rows()[1].id ~= "old1" and kind:IsDefault(), "Default: Recommended")
check(still(), "nothing since: Undo stands")
undo()
rows = kind:Rows()
check(rows[1].id == "old1" and rows[1].R2.legacy.strength == 13, "Undo: his rule back, its bytes")
check(TS.Default("old1") == nil, "a row with no Recommended: nothing to undo")
rows[2].on = false
undo, still = TS.Default("ready:Judgement")
check(undo and rows[2].on == true, "a row's Default")
kind:Rows()[3].on = false
check(not still(), "changed since: Undo stale")
kind:Rows()[3].on = true
undo()
check(kind:Rows()[2].on == false, "the row's Undo")
check(TS.Default() and TS.Default() == nil, "already as shipped: nothing to undo")
db.link.trigRules, db.triggerStack = nil, nil

-- a reload: the same saved stack, fresh files; the first update draws the triggers
db.link.trigRules = nil
do
    local ns2 = { Haptics = { DB = function() return db end } }
    for _, f in ipairs({ "HelperLink.lua", "TriggerRules.lua", "Stack.lua", "TriggerStack.lua" }) do
        assert(loadfile(root .. "/" .. f))("GamepadCompanion", ns2)
    end
    ns2.TriggerStack.kind:Default()
    ns2.Stack.Set("cast", true)
    ns2.TriggerStack.Update({ cast = true, progress = 0.5 })
    local K2 = ns2.HelperLink
    check(K2.trig and K2.trig.right.shape == TS.ID.tension and K2.state.right.mode ~= 0, "after a reload: the triggers drawn")
end

print(string.format("TriggerStack: %s (%d checks)", failed == 0 and "ok" or (failed .. " failed"), n))
os.exit(failed == 0 and 0 or 1)
