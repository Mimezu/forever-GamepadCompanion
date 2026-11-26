-- PadRescue: the held Cross that reloads a stuck pad, and the first-taint catcher.
-- lua5.1 tests/PadRescue.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end
local function Load(ns)
    local chunk = assert(loadfile(root .. "/PadRescue.lua"))
    chunk("GamepadCompanion", ns)
    return ns.PadRescue
end

-- Pure ------------------------------------------------------------------------------------
CreateFrame = nil
local R = Load({})
local s = {}
local f, fire = R.Hold(s, 10, true)
eq(f, 0, "first frame down: nothing yet"); eq(fire, false, "no reload at once")
f, fire = R.Hold(s, 10.5, true)
check(math.abs(f - 0.5) < 1e-9, "half a second: half way"); eq(fire, false, "not yet")
f, fire = R.Hold(s, 10.7, false)
eq(f, 0, "let go: back to nothing")
R.Hold(s, 20, true)
f, fire = R.Hold(s, 21, true)
eq(fire, true, "held a second: reload"); eq(f, 1, "full")
f, fire = R.Hold(s, 21.5, true)
eq(fire, false, "still held after: once only")
R.Hold(s, 22, false)
R.Hold(s, 30, true)
f, fire = R.Hold(s, 31.2, true)
eq(fire, true, "a new hold after a release: again")
local w = { wait = true }
f, fire = R.Hold(w, 1, true); R.Hold(w, 5, true)
eq(fire, false, "down when the line came: waits for a release")
R.Hold(w, 6, false); R.Hold(w, 7, true)
f, fire = R.Hold(w, 8, true)
eq(fire, true, "then a real hold works")

local new = R.New({ ["top.style"] = "X" }, { ["top.style"] = "X", ["binding PADLTRIGGER"] = "Auctionator", catcher = "Y" })
eq(#new, 2, "two new slots")
eq(new[1], "binding PADLTRIGGER=Auctionator", "sorted, label=addon")
eq(new[2], "catcher=Y", "second")
eq(#R.New({ a = "X" }, { a = "X" }), 0, "nothing new")
eq(#R.New(nil, nil), 0, "no maps")

-- Runtime: a stuck pad, the line, Cross held -----------------------------------------------
local now, combat, crossDown, reloaded = 100, false, false, 0
GetTime = function() return now end
InCombatLockdown = function() return combat end
ReloadUI = function() reloaded = reloaded + 1 end
local frames = {}
CreateFrame = function()
    local fr = { scripts = {}, events = {} }
    function fr:SetScript(k, fn) self.scripts[k] = fn end
    function fr:RegisterEvent(e) self.events[e] = true end
    frames[#frames + 1] = fr
    return fr
end
local hooks = {}
hooksecurefunc = function(t, name, fn)
    local orig = t[name]
    t[name] = function(...) local a, b = orig(...); fn(...); return a, b end
    hooks[#hooks + 1] = name
end
debugstack = function() return "Interface/AddOns/SomeAddon/Thing.lua:42: in function 'Open'\n[C]: ?" end
C_Timer = { NewTicker = function(_, fn) return { fn = fn } end }

local tainted = {}
local traced = {}
local passage = { shown = {}, updates = 0 }
local ns = {
    Keys = {
        PadSlots = function(into) for k, v in pairs(tainted) do into[k] = v end; return "x" end,
        Trace = function(line, list) traced[#traced + 1] = { line = line, list = list } end,
    },
    Shared = {
        PadButtons = function() return {} end,
        PadDown = function(_, key) return key == "PAD1" and crossDown or false end,
    },
    Passage = {
        Show = function(owner, spec) passage.shown[owner] = spec end,
        Update = function(owner, spec) passage.shown[owner] = spec; passage.updates = passage.updates + 1 end,
        Hide = function(owner) passage.shown[owner] = nil end,
    },
    ControllerModel = { Glyph = function(n) return "[" .. n .. "]" end },
}
R = Load(ns)
check(R.Step ~= nil, "runtime loaded")

R.Step()
eq(passage.shown.pad, nil, "not stuck: no line")
R.Stuck("Auctionator")
eq(R.StuckBy(), "Auctionator", "stuck by the blamed addon")
R.Step()
check(passage.shown.pad ~= nil, "the line comes up")
eq(passage.shown.pad and passage.shown.pad.title, "Pad stuck", "its title")
check(passage.shown.pad and passage.shown.pad.sub:find("Hold to reload", 1, true) ~= nil, "its prompt")
check(passage.shown.pad and passage.shown.pad.sub:find("[Shp_Cross]", 1, true) ~= nil, "Cross's glyph")
crossDown = true; R.Step(); now = now + 0.5; R.Step()
check(passage.shown.pad.frac > 0.4 and passage.shown.pad.frac < 0.6, "the line fills while held")
eq(reloaded, 0, "half a second: no reload")
crossDown = false; R.Step(); now = now + 2; R.Step()
eq(reloaded, 0, "a tap never reloads")
combat = true; crossDown = true; R.Step(); now = now + 2; R.Step()
eq(passage.shown.pad, nil, "in combat: the line goes")
eq(reloaded, 0, "in combat: no reload")
combat = false; R.Step(); now = now + 1.1; R.Step()
eq(reloaded, 1, "out of combat, Cross held a second: reload")
local last = traced[#traced]
check(last and last.line:find("RELOAD", 1, true) ~= nil and last.list == "errors", "the reload traced")

-- Cross already down when it's found stuck: waits for the release
local ns2 = {}
for k, v in pairs(ns) do ns2[k] = v end
reloaded = 0; crossDown = true
local R2 = Load(ns2)
R2.Stuck("Details")
R2.Step(); now = now + 3; R2.Step()
eq(reloaded, 0, "held from before: no reload")
crossDown = false; R2.Step(); crossDown = true; R2.Step(); now = now + 1.1; R2.Step()
eq(reloaded, 1, "released and held again: reload")

-- The catcher --------------------------------------------------------------------------------
local manager = { bindingSetStack = {} }
local bindingWrites = 0
function manager:AddBindingSet() end
function manager:RemoveSet() end
function manager:AssumeCoreBindingsAreUsable() end
local named = { GetName = function() return "AuctionHouseFrame" end }
local fcm = {}
for _, m in ipairs({ "FrameShown", "FrameHidden", "SetUIFocusState", "SetFallThroughCatcherActive",
    "HandlePopupShown", "HandlePopupHide", "FocusNextFrame", "FocusPreviousFrame" }) do fcm[m] = function() end end
GamepadMode = { FrameControlsManager = fcm, ActivateBindingGroup = function() end, DeactivateBindingGroup = function() end }
GamepadSharedUtility = { InputBindingManager = manager }
traced = {}
tainted = { ["top.style"] = "Old" }
local R3 = Load(ns2)
R3.Arm()
check(#hooks >= 13, "the writers hooked (" .. #hooks .. ")")
check(traced[1] and traced[1].line:find("TAINT at login top.style=Old", 1, true) ~= nil, "what was tainted at login: traced")
local before = #traced
fcm.FrameShown(fcm, named)
eq(#traced, before, "nothing new: nothing traced")
tainted["binding PADLTRIGGER"] = "Auctionator"
GamepadMode.ActivateBindingGroup({ name = "FrameControlsManagerBindings" })
local first = traced[before + 1] and traced[before + 1].line or ""
check(first:find("TAINT FIRST binding PADLTRIGGER=Auctionator after ActivateBindingGroup(FrameControlsManagerBindings)", 1, true) ~= nil,
    "the first new slot, the call and its argument: " .. first)
check(first:find("clean after FrameShown", 1, true) ~= nil, "the last clean call named")
check(not first:find("top.style", 1, true), "the old taint isn't new")
local stack = traced[before + 2] and traced[before + 2].line or ""
check(stack:find("TAINT STACK SomeAddon/Thing.lua:42", 1, true) ~= nil, "the caller's stack: " .. stack)
tainted.catcher = "Other"
fcm.FrameHidden(fcm, named)
eq(#traced, before + 2, "once a session")
R3.Arm()
eq(#hooks >= 13 and #hooks < 26, true, "armed once")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
