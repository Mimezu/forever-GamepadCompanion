-- Touchpad zones: TouchModel.lua's logic, the secure snippet run as the
-- restricted environment would, and Touchpad.lua driven with stubbed game calls.
-- lua5.1 tests/Touchpad.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

---------------------------------------------------------------------------
-- The game, stubbed
---------------------------------------------------------------------------
local now, combat = 100, false
local cvars = { ActionButtonUseKeyDown = "1", GamePadEmulateCtrl = "PADLSHOULDER", GamePadEmulateShift = "PADLTRIGGER",
    GamePadEmulateAlt = "none", GamePadTouchCursorEnable = "1" }
local overrides = {}          -- key -> { owner, action }
local secureHooks = {}
local timers = {}
local printed = {}
local pad = { labelStyle = "Shapes", x = 0, y = 0, lt = false, rt = false, vendorID = 1356, productID = 3302 }
local configs = {}            -- "v:p" -> config
local uiFocused, coreOnly = false, true

function GetTime() return now end
function InCombatLockdown() return combat end
function GetCVar(name) return cvars[name] end
function SetCVar(name, value) cvars[name] = tostring(value) end
function print(text) printed[#printed + 1] = tostring(text) end
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
function hooksecurefunc(name, fn) secureHooks[name] = fn end
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function() return { Cancel = function() end } end,
}
local function RunTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
end

local frames = {}
local function Frame(kind, name)
    local f = { kind = kind, name = name, attributes = {}, scripts = {}, shown = true, events = {} }
    function f:SetAttribute(k, v) self.attributes[k] = v end
    function f:GetAttribute(k) return self.attributes[k] end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:GetName() return self.name end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:CreateTexture() return Frame("Texture") end
    function f:CreateFontString() return Frame("FontString") end
    setmetatable(f, { __index = function() return function() end end })
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
function CreateFrame(kind, name) return Frame(kind, name) end
UIParent = Frame("Frame", "UIParent")

local wrapped
function SecureHandlerWrapScript(frame, script, _, body) wrapped = { frame = frame, script = script, body = body } end

function ClearOverrideBindings(owner)
    for key, b in pairs(overrides) do if b.owner == owner then overrides[key] = nil end end
end
function SetOverrideBindingClick(owner, _, key, name, button)
    overrides[key] = { owner = owner, action = "CLICK " .. name .. ":" .. button }
end
function SetOverrideBinding(owner, priority, key, action)
    overrides[key] = { owner = owner, action = action }
    if secureHooks.SetOverrideBinding then secureHooks.SetOverrideBinding(owner, priority, key, action) end
end
function GetBindingAction(key) return overrides[key] and overrides[key].action or "" end

local INDEX = { PADLTRIGGER = 9, PADRTRIGGER = 10 }   -- 0-based, as the game's
C_GamePad = {
    GetActiveDeviceID = function() return 1 end,
    ButtonBindingToIndex = function(b) return INDEX[b] end,
    GetDeviceMappedState = function()
        local buttons = {}
        buttons[INDEX.PADLTRIGGER + 1] = pad.lt
        buttons[INDEX.PADRTRIGGER + 1] = pad.rt
        return { labelStyle = pad.labelStyle, name = "DualSense", sticks = { [4] = { x = pad.x, y = pad.y, len = 0 } },
            buttons = buttons }
    end,
    GetDeviceRawState = function() return { vendorID = pad.vendorID, productID = pad.productID } end,
    GetConfig = function(id) return configs[id.vendorID .. ":" .. id.productID] end,
    SetConfig = function(config) configs[config.configID.vendorID .. ":" .. config.configID.productID] = config end,
    DeleteConfig = function(id) configs[id.vendorID .. ":" .. id.productID] = nil end,
    ApplyConfigs = function() end,
}
InputUtil = { IsGamepadUIEnabled = function() return true end }
GamepadMode = { FrameControlsManager = {} }
setmetatable(GamepadMode.FrameControlsManager, { __index = function(_, k) if k == "isUIFocused" then return uiFocused end end })
GamepadSharedUtility = { InputBindingManager = { IsOnlyCoreBindingSetActive = function() return coreOnly end } }
function GetMacroInfo(name) if name == "Mount" then return "Mount", 132261, "/cast Swift Horse" end end
C_Spell = { GetSpellName = function(id) return id == 133 and "Fireball" or nil end }
GamepadCompanionAPI = {}

---------------------------------------------------------------------------
-- Load
---------------------------------------------------------------------------
local ns = {}
assert(loadfile(root .. "/TouchModel.lua"))("GamepadCompanion", ns)
local T = ns.TouchModel
assert(loadfile(root .. "/Touchpad.lua"))("GamepadCompanion", ns)
local Touch = ns.Touch
local click = _G.GamepadCompanionTouchClick

---------------------------------------------------------------------------
-- TouchModel
---------------------------------------------------------------------------
do
    local s = T.Normalize()
    eq(s.enabled, false, "off by default")
    eq(s.mode, "chord", "chord (B) by default")
    eq(s.actions.chord.base.tl, "window:character", "default top left")
    eq(s.actions.split.base.bot, "window:bags", "default split bottom")
    local cleared = T.Normalize({ actions = { chord = { base = { tl = "none", tc = "junk" } } } })
    eq(cleared.actions.chord.base.tl, "none", "a cleared zone stays cleared")
    eq(cleared.actions.chord.base.tc, nil, "an invalid action is dropped")
    eq(cleared.actions.chord.base.tr, nil, "a saved layer gets no defaults back")
    eq(T.Normalize({ mode = "weird" }).mode, "chord", "unknown mode")
    eq(T.ZoneAt("chord", -0.9, 0.5), "tl", "zone top left")
    eq(T.ZoneAt("chord", 0, -0.5), "bc", "zone bottom centre")
    eq(T.ZoneAt("chord", 0.5, -0.5), "br", "zone bottom right")
    eq(T.ZoneAt("split", 0.5, 0.9), "top", "split top")
    eq(T.ZoneAt("split", 0.5, 0), "mid", "split middle")
    eq(T.ZoneAt("split", 0.5, -0.9), "bot", "split bottom")
    eq(T.LayerOf(true, true), "both", "both triggers")
    eq(#T.Prefixes(), 8, "eight modifier prefixes")
    eq(T.ModifierFor("PADLSHOULDER", { CTRL = "PADLSHOULDER" }), "CTRL", "L1 emulates Ctrl")
end

-- Binding plans
do
    local s = T.Normalize({ enabled = true })
    local env = { padStyle = "Shapes", ours = true, emulate = { CTRL = "PADLSHOULDER", SHIFT = "PADLTRIGGER" } }
    local plan = T.BindingPlan(s, env)
    local byKey = {}
    for _, e in ipairs(plan) do byKey[e.key] = e end
    eq(#plan, 8, "chord: eight keys")
    check(byKey.PADBACK and byKey.PADBACK.click, "chord: plain click is zones")
    check(byKey["SHIFT-PADBACK"] and byKey["SHIFT-PADBACK"].click, "chord: L2 + click is zones (LT layer)")
    eq(byKey["CTRL-PADBACK"] and byKey["CTRL-PADBACK"].action, "TOGGLEUIFOCUS", "chord: L1 + click is Blizzard's")
    eq(byKey["CTRL-SHIFT-PADBACK"] and byKey["CTRL-SHIFT-PADBACK"].action, "TOGGLEUIFOCUS", "chord: L1 + L2 + click too")
    env.ours = false
    plan = T.BindingPlan(s, env)
    eq(#plan, 4, "chord, window focused: only the chord keys")
    for _, e in ipairs(plan) do check(e.action == "TOGGLEUIFOCUS", "chord, window focused: no zone keys") end
    env.ours, env.conflict = true, true
    local _, why = T.BindingPlan(s, env)
    eq(#T.BindingPlan(s, env), 0, "chord yields to Improved Forever")
    check(why ~= nil, "conflict has a note")
    env.conflict, env.emulate = false, {}
    local _, noChord = T.BindingPlan(s, env)
    check(noChord and noChord:find("no modifier", 1, true), "no chord without an emulated modifier")
    s.mode = "split"
    eq(#T.BindingPlan(s, { padStyle = "Shapes", splitReady = false }), 0, "split waits for PAD6")
    plan = T.BindingPlan(s, { padStyle = "Shapes", splitReady = true })
    eq(#plan, 8, "split: eight PAD6 keys")
    for _, e in ipairs(plan) do check(e.key:find("PAD6$") and e.click, "split binds only PAD6") end
    eq(#T.BindingPlan(s, { padStyle = "Letters", splitReady = true }), 0, "Xbox pad: nothing")
end

-- Split config
do
    local default = T.DualSenseDefault()
    local split = T.SplitConfig(default)
    local by = {}
    for _, m in ipairs(split.rawButtonMappings) do by[m.rawIndex] = m.button end
    eq(by[22], "PAD6", "right half on PAD6")
    eq(by[21], "PADBACK", "left half stays PADBACK")
    eq(by[15], "PAD5", "mic button untouched")
    eq(default.rawButtonMappings[23].button, "PADBACK", "the original isn't changed")
    check(T.IsSplit(split) and not T.IsSplit(default), "IsSplit")
    check(T.Signature(split) ~= T.Signature(default), "signatures differ")
    eq(T.SplitConfig({ configID = { vendorID = 1, productID = 2 }, rawButtonMappings = { { rawIndex = 22, button = "PADBACK" } } }),
        nil, "an unknown pad without the comment isn't changed")
end

-- Macro text
do
    local lookup = { button = function(n) return n == "CharacterMicroButton" end,
        spellName = function(id) return id == 133 and "Fireball" or nil end,
        macroBody = function(n) return n == "Mount" and "/cast Swift Horse" or nil end }
    eq(T.MacroText("window:character", lookup), "/click CharacterMicroButton", "window macro")
    eq(T.MacroText("window:bags", lookup), nil, "window without a button")
    eq(T.MacroText("spell:133", lookup), "/cast Fireball", "spell macro")
    eq(T.MacroText("item:6948", lookup), "/use item:6948", "item macro")
    eq(T.MacroText("macro:Mount", lookup), "/cast Swift Horse", "macro body")
    eq(T.MacroText("none", lookup), nil, "none")
end

---------------------------------------------------------------------------
-- The secure snippet, as the restricted environment runs it
---------------------------------------------------------------------------
check(wrapped and wrapped.frame == click and wrapped.script == "OnClick", "snippet wrapped on the click")
local snippet = assert(loadstring("local self, button, down = ...\n" .. wrapped.body))
setfenv(snippet, {
    GetGamePadState = function() return C_GamePad.GetDeviceMappedState() end,
})
-- A full press: down then up; returns what ran (macrotext) or nil
local function Press(x, y, lt, rt)
    pad.x, pad.y, pad.lt, pad.rt = x, y, lt or false, rt or false
    local ran
    for _, down in ipairs({ true, false }) do
        local result = snippet(click, "LeftButton", down)
        if result ~= false and click:GetAttribute("type") == "macro" then ran = click:GetAttribute("macrotext") end
    end
    return ran
end

---------------------------------------------------------------------------
-- Runtime
---------------------------------------------------------------------------
GamepadCompanionTouchDB = nil
for _, f in ipairs(frames) do
    if f.events and f.events.ADDON_LOADED then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end
local function Fire(event)
    for _, f in ipairs(frames) do
        if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
    end
end
local watcher
for _, f in ipairs(frames) do if f.scripts.OnUpdate then watcher = f end end
local function Tick() now = now + 0.1; watcher.scripts.OnUpdate(watcher, 0.1) end

Fire("PLAYER_LOGIN")
eq(next(overrides), nil, "off by default: nothing bound")
_G.CharacterMicroButton = { Click = function() end }

Touch.Command("on")
eq(GetBindingAction("PADBACK"), "CLICK GamepadCompanionTouchClick:LeftButton", "B: plain click is ours")
eq(GetBindingAction("CTRL-PADBACK"), "TOGGLEUIFOCUS", "B: L1 + click is Blizzard's")
eq(GetBindingAction("PAD6"), "", "B: no PAD6")
eq(cvars.GamePadTouchCursorEnable, "0", "touch cursor off while ours")
eq(Press(-0.8, 0.6), "/click CharacterMicroButton", "click top left: Character")
eq(Press(0, -0.6), nil, "bottom centre (Professions): no button in this test")

-- Layers
local fireball = "spell:133"
_G.GetCursorInfo = function() return "spell", 1, "spell", 133 end
Touch.Command("set tr lt")
_G.GetCursorInfo = nil
eq(Press(0.8, 0.6, true, false), "/cast Fireball", "L2 + top right: the LT layer")
eq(Press(0.8, 0.6, false, true), nil, "R2 + top right: falls back to Base (Quests, no button here)")
eq(Press(-0.8, 0.6, true, false), "/click CharacterMicroButton", "L2 + an empty LT zone: Base")
check(fireball, "")

-- Debounce: two downs (both halves) act once
pad.x, pad.y = -0.8, 0.6
local first = snippet(click, "LeftButton", true)
local second = snippet(click, "LeftButton", true)
check(first ~= false and second == false, "second down of the same click ignored")
snippet(click, "LeftButton", false)

-- A window takes focus: the plain click goes back to Blizzard
uiFocused = true
Tick()
eq(GetBindingAction("PADBACK"), "", "focused window: plain click is Blizzard's again")
eq(GetBindingAction("CTRL-PADBACK"), "TOGGLEUIFOCUS", "focused window: chord stays")
uiFocused = false
Tick()
eq(GetBindingAction("PADBACK"), "CLICK GamepadCompanionTouchClick:LeftButton", "back in the world: zones again")

-- In combat the ownership freezes; it catches up after
combat = true
uiFocused = true
Tick()
eq(GetBindingAction("PADBACK"), "CLICK GamepadCompanionTouchClick:LeftButton", "combat: no binding changes")
combat = false
Fire("PLAYER_REGEN_ENABLED")
eq(GetBindingAction("PADBACK"), "", "after combat: caught up")
uiFocused = false
Tick()

-- Blizzard's core set takes PADBACK back: put ours on top again
SetOverrideBinding(UIParent, true, "PADBACK", "TOGGLEUIFOCUS")
eq(GetBindingAction("PADBACK"), "TOGGLEUIFOCUS", "Blizzard took the key")
RunTimers()
eq(GetBindingAction("PADBACK"), "CLICK GamepadCompanionTouchClick:LeftButton", "re-asserted")

-- Split (A): PAD6 config made, PADBACK left alone
Touch.Command("mode split")
check(T.IsSplit(configs["1356:3302"]), "A: config with the right half on PAD6")
eq(GetBindingAction("PAD6"), "CLICK GamepadCompanionTouchClick:LeftButton", "A: PAD6 is ours")
eq(GetBindingAction("PADBACK"), "", "A: PADBACK untouched")
eq(GetBindingAction("CTRL-PADBACK"), "", "A: no chord")
eq(Press(0.5, 0.8), "/click CharacterMicroButton", "A: right half top is Character")
-- Back to chord: the config goes
Touch.Command("mode chord")
eq(configs["1356:3302"], nil, "B again: split config removed")
eq(GetBindingAction("PAD6"), "", "B again: PAD6 free")
-- A config of the player's own comes back as it was
local own = T.DualSenseDefault()
own.configID = { vendorID = 1356, productID = 3302 }
own.rawButtonMappings[1].button = "PAD2"
configs["1356:3302"] = own
Touch.Command("mode split")
check(T.IsSplit(configs["1356:3302"]), "A over the player's own config")
Touch.Command("restore")
eq(configs["1356:3302"] and configs["1356:3302"].rawButtonMappings[1].button, "PAD2", "restore: the player's config is back")
eq(next(overrides), nil, "restore: zones off, nothing bound")
eq(cvars.GamePadTouchCursorEnable, "1", "touch cursor back as it was")

-- Improved Forever's corners on: chord mode yields
Touch.Command("mode chord")
Touch.Command("on")
_G.ImprovedForever = { Touch = {}, db = { touch = {} } }
Touch.Apply()
eq(GetBindingAction("PADBACK"), "", "yields to Improved Forever")
_G.ImprovedForever.db.touch.enabled = false
Touch.Apply()
eq(GetBindingAction("PADBACK"), "CLICK GamepadCompanionTouchClick:LeftButton", "Improved Forever corners off: ours")

-- Xbox pad: nothing
pad.labelStyle = "Letters"
Touch.Apply()
eq(next(overrides), nil, "Xbox pad: nothing bound")
pad.labelStyle = "Shapes"

-- Saved settings survive
local saved = GamepadCompanionTouchDB
eq(saved.enabled, true, "saved: enabled")
eq(saved.actions.chord.lt.tr, "spell:133", "saved: the LT zone")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
