-- Stack: the generic state stack (Stack.lua), FrameGambit's model, as a second kind would use it
-- (triggers: L2, R2, with gauge values).
-- lua5.1 tests/Stack.lua <addon folder>
local root = arg[1] or "."

local frames = {}
function CreateFrame()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e) self.events[e] = true end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    frames[#frames + 1] = f
    return f
end
local now = 100
function GetTime() return now end
local timers = {}
C_Timer = { After = function(t, fn) timers[#timers + 1] = { now + t, fn } end }
local function Run(to)
    now = to
    for i = #timers, 1, -1 do
        local t = timers[i]
        if t[1] <= now then table.remove(timers, i); t[2]() end
    end
end
local world = { combat = false, speed = 0, mounted = false, hp = 100, maxHp = 100 }
UnitAffectingCombat = function() return world.combat end
GetUnitSpeed = function() return world.speed end
IsMounted = function() return world.mounted end
UnitHealth = function() return world.hp end
UnitHealthMax = function() return world.maxHp end

local ns = {}
assert(loadfile(root .. "/Stack.lua"))("GamepadCompanion", ns)
local St = ns.Stack
local checks = 0
local function ok(c, msg) checks = checks + 1; assert(c, msg) end
local function event(name, unit) frames[1].scripts.OnEvent(frames[1], name, unit) end

-- conditions: read on their events, never every frame; FrameGambit's families and words
ok(frames[1].events.PLAYER_REGEN_DISABLED and frames[1].events.PLAYER_STARTED_MOVING and frames[1].events.UNIT_HEALTH, "event-driven")
ok(frames[1].scripts.OnUpdate == nil, "no OnUpdate")
ok(St.Label("combat") == "In combat" and St.Label("moving") == "Movement" and St.Label("dead") == "Dead or ghost", "FrameGambit's words")
local families = {}
for _, c in ipairs(St.CATEGORIES) do families[c.label] = true end
ok(families.Player and families.Travel and families["Group & instances"] and families.Events, "its families")
ok(#St.OPERATORS == 6 and St.OPERATORS[1].label == "Less than", "its operators")

-- a kind: triggers, L2 / R2, a gauge on R2
local store = {}
local result
local recommended = {
    { id = "lowHp", condition = "player_health", operator = "<", threshold = 35, on = true, R2 = { effect = 3 } },
    { id = "combat", condition = "combat", on = true, L2 = { effect = 1 } },
    { id = "moving", condition = "moving", on = true, L2 = { effect = 2 }, R2 = { effect = 2 } },
}
local k = St.Kind("triggers", {
    channels = { "L2", "R2" },
    recommended = recommended,
    store = function() return store end,
    value = function(row, ch)
        local v = row[ch]
        if not v then return nil end
        -- (a gauge: the live value of its source)
        return { effect = v.effect, value = row.source and St.Value(row.source) or nil }
    end,
    base = function() return { effect = 0 } end,
    apply = function(r) result = r end,
    live = true,
})
St.ReadAll(); St.Refresh()
ok(result.L2.row == nil and result.L2.value.effect == 0 and result.R2.row == nil, "nothing matches: Otherwise")
ok(#k:Rows() == 3 and k:IsDefault(), "the Recommended reactions")

-- In combat: L2 from it, R2 passes (In combat has none) to Otherwise
world.combat = true
event("PLAYER_REGEN_DISABLED")
ok(result.L2.row.id == "combat" and result.R2.row == nil, "a channel left empty passes")
-- moving too: In combat is above, so L2 stays combat's; R2 from Movement
world.speed = 7
event("PLAYER_STARTED_MOVING")
ok(result.L2.row.id == "combat" and result.R2.row.id == "moving", "first match wins, per channel")
local d = k:Driving()
ok(d.combat[1] == "L2" and d.moving[1] == "R2", "the rows driving now (the teal rows)")

-- a percentage with its operator: health 30 < 35
world.hp = 30
event("UNIT_HEALTH", "player")
ok(result.R2.row.id == "lowHp", "Health percentage < 35")
k:Row("lowHp").operator = ">="
k:Refresh(true)
ok(result.R2.row.id == "moving", "At least 35: no longer")
k:Row("lowHp").operator = "<"
world.hp = 100
event("UNIT_HEALTH", "player")

-- reorder: Movement to the top (drag), Up / Down, saved in the kind's table
ok(k:MoveTo("moving", 1) and k:Rows()[1].id == "moving" and store.rows ~= nil, "dragged to the top, saved")
ok(result.L2.row.id == "moving", "Movement wins L2 now")
ok(not k:Move("moving", -1), "the top can't go up")
ok(k:Move("moving", 1) and k:Rows()[2].id == "moving", "down one")
ok(not k:IsDefault(), "changed")
k:MoveTo("moving", 3)   -- (back under In combat)

-- On / Off: off passes everything
ok(result.L2.row.id == "combat", "In combat above Movement again")
k:SetOn("combat", false)
ok(result.L2.row.id == "moving", "off: the next match")
k:SetOn("combat", true)

-- requirements: all must be true; FrameGambit's conflicts refused
ok(k:AddRequirement("combat", "mounted"), "a requirement")
ok(result.L2.row.id == "moving", "In combat + Mounted: not yet")
world.mounted = true
event("PLAYER_MOUNT_DISPLAY_CHANGED")
ok(result.L2.row.id == "combat", "both true: it matches")
local okAdd, bad = k:AddRequirement("combat", "out_of_combat")
ok(not okAdd and bad == "combat", "In combat + Out of combat: refused")
ok(St.Words(k:Row("combat")) == "In combat + Mounted", "its words")
ok(k:RemoveRequirement("combat", "mounted") and k:Row("combat").requirements == nil, "removed")

-- + Add: a reaction on top; × removes it
local row = k:Add("whispered")
row.L2 = { effect = 9 }
ok(k:Rows()[1] == row and row.id == "r1", "added on top")
-- an event: true for its duration, and the duration restarts
event("CHAT_MSG_WHISPER")
ok(result.L2.row == row, "a whisper: its reaction for 10 s")
Run(105)
event("CHAT_MSG_WHISPER")
Run(112)
ok(result.L2.row == row, "again at 5 s: still on at 12 s")
Run(115.1)
ok(result.L2.row.id ~= row.id, "10 s after the last one: over")
k:Remove(row.id)
ok(not k:Row(row.id), "removed")

-- a gauge: the live value moves the channel (live kinds re-resolve on St.SetValue)
k:Row("moving").source = "cast"
St.SetValue("cast", 0.4)
ok(result.R2.value.value == 0.4, "gauge value")
St.SetValue("cast", 0.6)
ok(result.R2.value.value == 0.6, "it follows")

-- Wait before fade-out: a reaction that stops matching holds for Wait
k:SetTiming("wait", 0.5)
world.speed = 0
event("PLAYER_STOPPED_MOVING")
ok(result.R2.row and result.R2.row.id == "moving", "still Movement during Wait")
Run(now + 0.6)
ok(result.R2.row == nil, "then the next")

-- L6: Wait counts from when the reaction stopped matching, not from the last refresh
k:SetTiming("wait", 2)
world.speed = 7
event("PLAYER_STARTED_MOVING")
ok(result.R2.row and result.R2.row.id == "moving", "moving")
local stop = now
world.speed = 0
event("PLAYER_STOPPED_MOVING")
Run(stop + 0.5)
event("UNIT_HEALTH", "player")   -- (another event half way)
Run(stop + 1.9)
ok(result.R2.row and result.R2.row.id == "moving", "L6: still held at 1.9 s")
Run(stop + 2.1)
ok(result.R2.row == nil, "L6: released at 2 s after it stopped, not 2 s after the last event")
k:SetTiming("wait", 0)

-- L10: each percentage requirement has its own operator and threshold
local pr = k:Row("combat")
k:AddRequirement("combat", "player_health")
St.SetReqParams(pr, "player_health", "<", 30)
world.combat, world.hp = true, 40
event("PLAYER_REGEN_DISABLED"); event("UNIT_HEALTH", "player")
ok(result.L2.row == nil or result.L2.row.id ~= "combat", "In combat + Health < 30 %: 40 % no")
world.hp = 20
event("UNIT_HEALTH", "player")
ok(result.L2.row.id == "combat" and St.Words(pr) == "In combat + Health percentage < 30%", "20 %: yes")
k:RemoveRequirement("combat", "player_health")
world.hp = 100
event("UNIT_HEALTH", "player")

-- Default: reactions, order and timing as they ship; one row back too
k:Row("combat").on = false
k:Default("combat")
ok(k:Row("combat").on == true and k:IsDefault("combat"), "one reaction back")
k:Default()
ok(k:IsDefault() and k:Timing().wait == 0 and k:Row("moving").source == nil, "all back")
-- a Recommended reaction shipped later reaches a saved list, at its place; a removed one stays out
store.rows = { St.Copy(recommended[2]), St.Copy(recommended[3]) }   -- (saved before lowHp existed)
ok(k:Rows()[1].id == "lowHp" and #k:Rows() == 3, "a new Recommended reaction joins a saved list")
k:Remove("lowHp")
ok(#k:Rows() == 2 and not k:Row("lowHp"), "removed: it stays removed")
k:Default()
ok(k:Row("lowHp") ~= nil, "Default brings it back")

-- Hush: every kind shows Otherwise (triggers free), except one that mixes it with its rows
world.combat = true
event("PLAYER_REGEN_DISABLED")
ok(result.L2.row and result.L2.row.id == "combat", "in combat")
St.Set("hush", true)
ok(result.L2.row == nil and result.R2.row == nil and result.hushed, "hushed: Otherwise everywhere")
local mixed
local feel = St.Kind("feel", { channels = { "feel" }, store = function() return {} end, hush = "rows",
    recommended = { { id = "hush", condition = "hush", on = true, feel = 0.3 } },
    value = function(row) return row.feel end, base = function() return 1 end, apply = function(r) mixed = r.feel.value end })
feel:Refresh(true)
ok(mixed == 0.3, "a mixing kind: its Hush row (30 %)")
St.Set("hush", false)
ok(result.L2.row.id == "combat" and mixed == 1, "unhushed: as before")

-- The second night review ----------------------------------------------------------------------
-- L2-1: hushed with a Wait pending: no timer spinning (one at most, then none)
local armed = 0
local after0 = C_Timer.After
C_Timer.After = function(t, fn) armed = armed + 1; after0(t, fn) end
world.combat = false
event("PLAYER_REGEN_ENABLED")
k:SetTiming("wait", 2)
world.speed = 7
event("PLAYER_STARTED_MOVING")
local t0 = now
world.speed = 0
event("PLAYER_STOPPED_MOVING")       -- (a Wait of 2 s now pending)
St.Set("hush", true)
armed = 0
for i = 1, 150 do Run(t0 + i * 0.03) end   -- (4.5 s)
ok(armed <= 1, "L2-1: hushed, the Wait timer doesn't re-arm (" .. armed .. " timers)")
St.Set("hush", false)
ok(result.R2.row == nil, "after: released")
-- L2-2: a reaction that stops matching while hushed: its Wait runs then, not again after
world.speed = 7
event("PLAYER_STARTED_MOVING")
ok(result.R2.row and result.R2.row.id == "moving", "moving")
St.Set("hush", true)
local t1 = now
world.speed = 0
event("PLAYER_STOPPED_MOVING")
Run(t1 + 3)
St.Set("hush", false)
ok(result.R2.row == nil, "L2-2: its Wait ran out while hushed: released when Hush ends")
C_Timer.After = after0
k:SetTiming("wait", 0)
for _ = 1, 3 do Run(now + 1) end

-- L2-6: the whole list back to Recommended can be undone
k:Row("combat").on = false
k:MoveTo("moving", 1)
local snap = k:Snapshot()
k:Default()
ok(k:IsDefault(), "Default: Recommended")
k:Restore(snap)
ok(k:Row("combat").on == false and k:Rows()[1].id == "moving" and not k:IsDefault(), "L2-6: Undo puts the list back")
ok(St.Sig(k:Snapshot()) == St.Sig(snap) and St.Sig({ a = 1, b = { 2 } }) == St.Sig({ b = { 2 }, a = 1 }), "a list in words: equal when equal")
k:Default()

-- L2-7: a list saved before 0.51 (no removals written): a Recommended reaction it lacks was removed
store.rows, store.removed, store.joinV = { St.Copy(recommended[2]), St.Copy(recommended[3]) }, nil, nil
ok(#k:Rows() == 2 and not k:Row("lowHp"), "L2-7: removed under 0.49 stays removed")
ok(store.removed and store.removed.lowHp and store.joinV == St.JOIN, "and is written down as removed")
recommended[1].since = St.JOIN + 1   -- (a reaction shipped later says so)
St.JOIN = St.JOIN + 1
store.rows, store.removed, store.joinV = { St.Copy(recommended[2]), St.Copy(recommended[3]) }, nil, St.JOIN - 1
k.checked = nil
ok(k:Rows()[1].id == "lowHp", "one shipped later joins")
recommended[1].since, St.JOIN = nil, St.JOIN - 1
k:Default()

-- L2-8: reading the reactions and the timing again allocates nothing
k:Rows(); k:Timing()
collectgarbage("collect"); collectgarbage("stop")
local kb = collectgarbage("count")
for _ = 1, 200 do k:Rows(); k:Timing(); k:Row("moving") end
local grew = (collectgarbage("count") - kb) * 1024
collectgarbage("restart")
ok(grew < 256, "L2-8: 200 reads: " .. math.floor(grew) .. " bytes")
k:SetTiming("wait", 1)
ok(k:Timing().wait == 1, "a new timing is read")
k:SetTiming("wait", 0)

-- L2-10: a reaction added with its fields: the refresh sees them at once
local fstore, fv = {}, nil
local fk = St.Kind("feelT", { channels = { "feel" }, store = function() return fstore end, hush = "rows",
    recommended = {}, value = function(row) return row.feel end, base = function() return 1 end,
    apply = function(r) fv = r.feel.value end })
world.combat = true
event("PLAYER_REGEN_DISABLED")
fk:Add("combat", nil, { feel = 0.5 })
ok(fv == 0.5, "L2-10: In combat 50 %: at once")
world.combat = false
event("PLAYER_REGEN_ENABLED")

-- L2-13: Hush is offered only where it can show (Feel); everything else everywhere
ok(St.Offered("hush", "feel") and not St.Offered("hush", "triggers") and not St.Offered("hush", "lights"), "L2-13: Hush: Feel only")
ok(St.Offered("combat", "triggers") and St.Offered("combat", "feel") and not St.Offered("nope", "feel"), "the others: everywhere")
-- Secret values (health, speed in combat, BugGrabber 2026-11-19: Stack.lua:78 x6873, :86 x11196):
-- arithmetic or tonumber on one errors in the game; here a table that errors the same way
local SECRET = setmetatable({}, { __arith = function() error("arithmetic on a secret") end,
    __lt = function() error("compare a secret") end, __le = function() error("compare a secret") end })
local mt = getmetatable(SECRET)
mt.__add, mt.__sub, mt.__mul, mt.__div = mt.__arith, mt.__arith, mt.__arith, mt.__arith
issecretvalue = function(v) return v == SECRET end
local realTonumber = tonumber
tonumber = function(v, ...) if v == SECRET then error("numeric conversion on a secret") end return realTonumber(v, ...) end
UnitHealth = function() return SECRET end
GetUnitSpeed = function() return SECRET end
world.combat = true
local fine = pcall(function() event("UNIT_HEALTH", "player"); event("PLAYER_STARTED_MOVING") end)
ok(fine, "secret health and speed: no error")
ok(St.Value("player_health") == nil, "secret health: unknown, not a number")
ok(St.Is("moving") == true, "secret speed: moving from the game's event")
event("PLAYER_STOPPED_MOVING")
ok(St.Is("moving") == false, "secret speed: stopped from the game's event")
ok(St.Is("combat") == true, "the other conditions still read")
tonumber, issecretvalue = realTonumber, nil
UnitHealth = function() return world.hp end
GetUnitSpeed = function() return world.speed end
world.combat = false
event("PLAYER_REGEN_ENABLED")
print("Stack: ok (" .. checks .. " checks)")
