-- Stack: the generic state stack (Stack.lua), as a second kind would use it (triggers: L2, R2).
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
local world = { combat = false, speed = 0, mounted = false, resting = false }
UnitAffectingCombat = function() return world.combat end
GetUnitSpeed = function() return world.speed end
IsMounted = function() return world.mounted end
IsResting = function() return world.resting end

local ns = {}
assert(loadfile(root .. "/Stack.lua"))("GamepadCompanion", ns)
local St = ns.Stack
local checks = 0
local function ok(c, msg) checks = checks + 1; assert(c, msg) end
local function event(name) frames[1].scripts.OnEvent(frames[1], name) end

-- the conditions are read on their events, never every frame
ok(frames[1].events.PLAYER_REGEN_DISABLED and frames[1].events.PLAYER_STARTED_MOVING and frames[1].events.PLAYER_UPDATE_RESTING, "event-driven")
ok(frames[1].scripts.OnUpdate == nil, "no OnUpdate")

-- a kind: two channels, three states (one of them pushed by its module), a base
local saved, settings, applied = {}, {
    combat = { on = true, L2 = "resist" },               -- sets L2 only (R2 passes)
    moving = { on = true, L2 = "light", R2 = "light" },
    lowHp = { on = true, R2 = "pulse" },
}, 0
local result
local k = St.Kind("triggers", {
    channels = { "L2", "R2" },
    layers = { { key = "lowHp" }, { key = "combat" }, { key = "moving" } },
    recommended = { "lowHp", "combat", "moving" },
    store = function() return saved end,
    enabled = function(key) return settings[key].on end,
    value = function(key, ch) return settings[key][ch] end,
    base = function(ch) return "free" end,
    apply = function(r) applied = applied + 1; result = r end,
})
ok(St.Get("triggers") == k, "registered")
St.ReadAll(); St.Refresh()
ok(result.L2.layer == "base" and result.L2.value == "free" and result.R2.layer == "base", "nothing true: the base")

-- in combat: L2 from In combat, R2 passes to the base
world.combat = true
event("PLAYER_REGEN_DISABLED")
ok(result.L2.value == "resist" and result.L2.layer == "combat" and result.R2.layer == "base", "pass-through")
local n = applied
St.Refresh()
ok(applied == n, "nothing changed: not applied again")

-- moving too: In combat is above, so L2 stays combat's; R2 from Movement
world.speed = 7
event("PLAYER_STARTED_MOVING")
ok(result.L2.layer == "combat" and result.R2.value == "light" and result.R2.layer == "moving", "first true wins, per channel")

-- the order: Movement above In combat
ok(k:Move("moving", -1) and k:Order()[2] == "moving" and saved.order ~= nil, "moved, saved")
ok(result.L2.layer == "moving", "Movement wins L2 now")
ok(not k:Move("lowHp", -1), "the top can't go up")
ok(not k:IsDefaultOrder(), "not the Recommended order")
k:DefaultOrder()
ok(k:IsDefaultOrder() and saved.order == nil and result.L2.layer == "combat", "Default order")

-- a pushed condition (Low health): R2 from it, L2 still combat's (Low health passes L2)
St.Set("lowHp", true)
ok(result.R2.layer == "lowHp" and result.L2.layer == "combat", "pushed")
St.Set("lowHp", false)
ok(result.R2.layer == "moving", "and back")

-- a state switched off passes everything
settings.combat.on = false
k:Refresh(true)
ok(result.L2.layer == "moving", "off: what is below")
settings.combat.on = true

-- a saved order missing a state (added later): it takes its Recommended place
saved.order = { "moving", "lowHp" }
local o = k:Order()
ok(#o == 3 and o[1] == "moving" and o[2] == "lowHp" and o[3] == "combat", "a new state after its Recommended neighbour: " .. table.concat(o, ","))
saved.order = { "gone", "combat", "combat", "moving", "lowHp" }
o = k:Order()
ok(#o == 3 and o[1] == "combat", "unknown and doubled keys dropped")
saved.order = nil

-- labels from the shared conditions
ok(St.Label("combat") == "In combat" and St.Label("rested") == "Resting", "labels")
print("Stack: ok (" .. checks .. " checks)")
