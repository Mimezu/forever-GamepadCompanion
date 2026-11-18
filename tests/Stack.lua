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

-- Default: reactions, order and timing as they ship; one row back too
k:Row("combat").on = false
k:Default("combat")
ok(k:Row("combat").on == true and k:IsDefault("combat"), "one reaction back")
k:Default()
ok(k:IsDefault() and k:Timing().wait == 0 and k:Row("moving").source == nil, "all back")
print("Stack: ok (" .. checks .. " checks)")
