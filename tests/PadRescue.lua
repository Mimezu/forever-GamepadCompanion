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
local new = R.New({ ["top.style"] = "X" }, { ["top.style"] = "X", ["binding PADLTRIGGER"] = "Auctionator", catcher = "Y" })
eq(#new, 2, "two new slots")
eq(new[1], "binding PADLTRIGGER=Auctionator", "sorted, label=addon")
eq(new[2], "catcher=Y", "second")
eq(#R.New({ a = "X" }, { a = "X" }), 0, "nothing new")
eq(#R.New(nil, nil), 0, "no maps")

-- Runtime: a stuck pad, the line, Cross bound to the /reload button -------------------------
local combat = false
InCombatLockdown = function() return combat end
local reloadCalled = 0
ReloadUI = function() reloadCalled = reloadCalled + 1 end
local frames = {}
CreateFrame = function(kind, name)
    local fr = { kind = kind, name = name, scripts = {}, events = {}, attributes = {} }
    function fr:SetScript(k, fn) self.scripts[k] = fn end
    function fr:HookScript(k, fn) self.scripts[k] = fn end
    function fr:RegisterEvent(e) self.events[e] = true end
    function fr:SetAttribute(k, v) self.attributes[k] = v end
    function fr:RegisterForClicks(...) self.clicks = { ... } end
    function fr:SetSize() end
    function fr:SetPoint() end
    if name then _G[name] = fr end
    frames[#frames + 1] = fr
    return fr
end
UIParent = {}
local overrides = {}
SetOverrideBindingClick = function(owner, priority, key, button, mouse)
    overrides[key] = { owner = owner, priority = priority, action = "CLICK " .. button .. ":" .. mouse }
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
local passage = { shown = {} }
local claims = {}
local ns = {
    Keys = {
        PadSlots = function(into) for k, v in pairs(tainted) do into[k] = v end; return "x" end,
        Trace = function(line, list) traced[#traced + 1] = { line = line, list = list } end,
    },
    Shared = { Claim = function(keys, apply) claims[#claims + 1] = { keys = keys, apply = apply } end },
    Passage = {
        Show = function(owner, spec) passage.shown[owner] = spec end,
        Update = function(owner, spec) passage.shown[owner] = spec end,
        Hide = function(owner) passage.shown[owner] = nil end,
    },
    ControllerModel = { Glyph = function(n) return "[" .. n .. "]" end },
}
R = Load(ns)
local b = _G.GamepadCompanionPadRescue
check(b ~= nil and b.kind == "Button", "the rescue button")
eq(b.attributes.type, "macro", "a macro button")
eq(b.attributes.macrotext, "/reload", "running /reload (securely, from a press: ReloadUI of ours is refused)")
eq(b.attributes.useOnKeyDown, false, "on release")
eq(reloadCalled, 0, "never ReloadUI from our code")
eq(overrides.PAD1, nil, "not stuck: Cross untouched")
eq(passage.shown.pad, nil, "not stuck: no line")

combat = true
R.Stuck("Auctionator")
eq(R.StuckBy(), "Auctionator", "stuck by the blamed addon")
eq(overrides.PAD1, nil, "found in a fight: no binding yet")
eq(passage.shown.pad, nil, "in a fight: no line")
combat = false
local driver = frames[#frames]
driver.scripts.OnEvent(driver, "PLAYER_REGEN_ENABLED")
eq(overrides.PAD1 and overrides.PAD1.action, "CLICK GamepadCompanionPadRescue:LeftButton", "after the fight: Cross on the button")
eq(overrides.PAD1 and overrides.PAD1.priority, true, "with priority")
check(passage.shown.pad ~= nil, "the line comes up")
eq(passage.shown.pad and passage.shown.pad.title, "Pad stuck", "its title")
check(passage.shown.pad and passage.shown.pad.sub:find("[Shp_Cross]  Reload", 1, true) ~= nil, "Cross's glyph, Reload")
check(traced[#traced] and traced[#traced].line:find("RESCUE: Cross runs /reload (pad stuck by Auctionator)", 1, true) ~= nil, "traced once bound")
eq(#claims, 1, "Cross claimed back from Blizzard's rebinds")
eq(claims[1] and claims[1].keys.PAD1, "CLICK GamepadCompanionPadRescue:LeftButton", "the claim's action")
overrides.PAD1 = nil
claims[1].apply("PAD1")
eq(overrides.PAD1 and overrides.PAD1.action, "CLICK GamepadCompanionPadRescue:LeftButton", "taken back")
local n = #traced
R.Stuck("Details")
eq(R.StuckBy(), "Auctionator", "the first addon kept")
eq(#claims, 1, "claimed once")
driver.scripts.OnEvent(driver, "PLAYER_REGEN_DISABLED")
eq(passage.shown.pad, nil, "a fight: the line goes")
check(overrides.PAD1 ~= nil, "the binding stays (works in a fight too)")
b.scripts.PostClick(b, "LeftButton", false)
check(traced[#traced].line:find("RELOAD: Cross", 1, true) ~= nil, "the reload traced on release")


local ns2 = {}
for k, v in pairs(ns) do ns2[k] = v end
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
