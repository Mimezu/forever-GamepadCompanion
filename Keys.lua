-- Button bindings: what L1, R1, L3, R3, Create, Options, PS and Mute run, on
-- each layer, per character.
--
-- A key Companion runs is bound once, to one secure button: "CLICK
-- GamepadCompanionKeys:p<n>", the click's button naming the key. At the press
-- a wrapped OnClick reads L2 / R2 from GetGamePadState (as the touchpad's
-- zones do) and runs that layer's macro, Base's when the layer has none. In
-- combat too, and the bindings never change while a trigger is held (that
-- made Forever drop Blizzard's own R2 bar, 2026-11-20): they change only when
-- the settings do, out of combat.
--
-- Blizzard's functions (Radial, Focus UI) run only from a binding, never from
-- a secure button (they're plain Blizzard code, called by the binding). So a
-- key whose Base is Blizzard's, its own default (Options: Radial) or a Gamepad
-- function chosen there, stays that binding; while L2 / R2 is held out of
-- combat, a watcher puts that layer's action on the key (the secure click, or
-- the Blizzard function's binding) and takes it off on release: only for a
-- layer that has one, on its own binding owner. In combat those wait: the key
-- runs its Base. Keys.Runs says which run where.
--
-- The watcher reads L2 / R2 from the pad itself (Sh.Held), the same state the
-- secure click reads: never the game's key state, which said L2 was down with
-- L2 up and left Focus UI on Create (2026-11-21). No pad to read, combat, a
-- pad change: the extras come off. Blizzard's own L2 / R2 handler is hooked
-- too, so a release clears them at once, not at the next tick. And every key
-- is checked against what it should run (Keys.Heal): 4 times a second, and the
-- moment a window takes or gives back the pad, since a window's binding sets
-- (the map focused with L2 + Create, then closed) can leave a key otherwise.
local _, ns = ...
local T, Sh = ns.TouchModel, ns.Shared
local Keys = {}
ns.Keys = Keys

-- (not L1 / R1: Blizzard's target bars live on them; taking them over is the
-- risk that broke the R2 bar. Saved actions on them drop at load: Normalize)
Keys.KEYS = { "PADLSTICK", "PADRSTICK", "PADSOCIAL", "PADFORWARD", "PADSYSTEM", "PAD5" }
Keys.LOCKED = { PADLSHOULDER = true, PADRSHOULDER = true }
local ALLOWED, CLICK_NAME = {}, {}
-- (click names fixed by the pad's order, so they never shift)
local ORDER = { "PADLSHOULDER", "PADRSHOULDER", "PADLSTICK", "PADRSTICK", "PADSOCIAL", "PADFORWARD", "PADSYSTEM", "PAD5" }
for _, key in ipairs(Keys.KEYS) do ALLOWED[key] = true end
for i, key in ipairs(ORDER) do CLICK_NAME[key] = "p" .. i end
Keys.BUTTON = "GamepadCompanionKeys"

local settings = {}
local bound = {}            -- key -> the command Companion bound there
local claimed = {}          -- the keys whose Base is ours: taken back from Blizzard (Sh.Claim)
local modes = {}            -- key -> "click" | "binding" | nil (Blizzard's), last Apply
local seen = {}             -- key -> what the game binds there without Companion
local extras = {}           -- key -> the command the watcher bound now
local used = 0              -- macro attributes set last time
local pending, loaded = false, false
local listeners = {}
local SetExtras             -- (below: the held layer's bindings on layerOwner)

--[[ The secure click (pre-body: self, button, down). button is the key's
click name ("p6"); attributes, set out of combat:
  gpc-lt / gpc-rt     the triggers' indexes in GetGamePadState().buttons
  gpc-<p>-<layer>     that key and layer's macro id ("k3"), or "none": runs nothing
The layer is read at the press and kept for its release, so the action runs
on the half the game's key-down setting says, with the layer of the press. ]]
Keys.SNIPPET = [[
    local pick = "gpc-pick-" .. button
    if not down then
        local id = self:GetAttribute(pick)
        self:SetAttribute(pick, nil)
        return id or false
    end
    local state = GetGamePadState()
    local pad = state and state.buttons
    local lti, rti = self:GetAttribute("gpc-lt"), self:GetAttribute("gpc-rt")
    local lt = pad and lti and pad[lti] and true or false
    local rt = pad and rti and pad[rti] and true or false
    local layer = (lt and rt and "both") or (lt and "lt") or (rt and "rt") or "base"
    local id = self:GetAttribute("gpc-" .. button .. "-" .. layer)
    if id == nil and layer ~= "base" then
        id = self:GetAttribute("gpc-" .. button .. "-base")
    end
    self:SetAttribute("gpc-layer", layer)
    if id == nil or id == "none" then
        self:SetAttribute(pick, nil)
        return false
    end
    self:SetAttribute(pick, id)
    return id
]]

local button = CreateFrame("Button", Keys.BUTTON, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
button:SetSize(1, 1)
button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
button:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(button, "OnClick", button, Keys.SNIPPET)
local owner = CreateFrame("Frame", "GamepadCompanionKeyBinds")
local layerOwner = CreateFrame("Frame", "GamepadCompanionKeyLayers")   -- the watcher's, while a layer is held

-- A button's index in GetGamePadState().buttons (1-based)
local function PadIndex(binding)
    local index = C_GamePad and C_GamePad.ButtonBindingToIndex and C_GamePad.ButtonBindingToIndex(binding)
    return index and index + 1 or nil
end

-- key -> layer -> action, valid entries only
function Keys.Normalize(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for key, layers in pairs(raw) do
        if ALLOWED[key] and type(layers) == "table" then
            for _, layer in ipairs(Sh.LAYERS) do
                local action = layers[layer]
                if T.ValidAction(action) then
                    out[key] = out[key] or {}
                    out[key][layer] = action
                end
            end
        end
    end
    return out
end

function Keys.Allowed(key) return ALLOWED[key] == true end
function Keys.Get(key, layer) return settings[key] and settings[key][layer] or nil end
function Keys.IsPending() return pending end
function Keys.OnChange(callback) listeners[#listeners + 1] = callback end
local function Notify() for _, callback in ipairs(listeners) do pcall(callback) end end

local function HasLayer(key)
    for _, layer in ipairs(Sh.LAYERS) do
        if layer ~= "base" and Keys.Get(key, layer) then return true end
    end
    return false
end

-- Any layer action at all (none: the watcher has nothing to read)
local anyLayer = false
local function CountLayers()
    anyLayer = false
    for _, key in ipairs(Keys.KEYS) do
        if HasLayer(key) then anyLayer = true; return end
    end
end

-- How a key is bound: "click" (Companion's secure button: every layer),
-- "binding", command (its Base is a Blizzard function) or nil (left to the
-- game). gameAction: what the game binds there without Companion ("" none).
function Keys.Mode(key, gameAction)
    local base = Keys.Get(key, "base")
    local binding = T.BindingOf(base)
    if binding then return "binding", binding end
    if base then return "click" end
    if not HasLayer(key) then return nil end
    -- (Base empty: the key's own default stays; a key with none is ours)
    if gameAction == nil or gameAction == "" then return "click" end
    return nil
end

-- Does the key's action on a layer run; and a note, a few words, when only
-- out of combat
function Keys.Runs(key, layer)
    local action = Keys.Get(key, layer)
    if not action then return false end
    if layer == "base" or (modes[key] == "click" and not T.BindingOf(action)) then return true end
    return true, "out of combat"
end

-- force: bind again even when nothing changed (Blizzard took a key). Else the
-- bindings are left alone when they'd be the same: macro and spell changes
-- (which can come while a trigger is held) only touch the attributes.
function Keys.Apply(force)
    if InCombatLockdown and InCombatLockdown() then pending = true; return false end
    pending = false
    button:SetAttribute("gpc-lt", PadIndex("PADLTRIGGER"))
    button:SetAttribute("gpc-rt", PadIndex("PADRTRIGGER"))
    local want, commands = {}, {}
    local n = 0
    for _, key in ipairs(Keys.KEYS) do
        local name = CLICK_NAME[key]
        -- (what the game binds there without Companion: under ours, the last seen)
        local game = GetBindingAction and GetBindingAction(key, true) or ""
        if (bound[key] and game == bound[key]) or (extras[key] and game == extras[key]) then game = seen[key] or "" end
        seen[key] = game
        local mode, command = Keys.Mode(key, game)
        modes[key] = mode
        -- (every key's: the watcher sends a Blizzard-based key here while a layer is held)
        for _, layer in ipairs(Sh.LAYERS) do
            local id
            local action = Keys.Get(key, layer)
            if T.BindingOf(action) then
                id = "none"      -- (a Blizzard function: not from a secure button)
            elseif action then
                local macro = T.MacroText(action, Sh.lookup)
                if macro then
                    n = n + 1
                    id = "k" .. n
                    button:SetAttribute("*type-" .. id, "macro")
                    button:SetAttribute("*macrotext-" .. id, macro)
                else
                    id = "none"  -- (nothing to run in this client)
                end
            end
            button:SetAttribute("gpc-" .. name .. "-" .. layer, id)
        end
        if mode == "click" then
            want[key] = "CLICK " .. Keys.BUTTON .. ":" .. name
        elseif mode == "binding" then
            want[key] = command
            commands[key] = true
        end
    end
    for i = n + 1, used do
        button:SetAttribute("*type-k" .. i, nil)
        button:SetAttribute("*macrotext-k" .. i, nil)
    end
    used = n
    local same = not force
    for key, command in pairs(want) do if bound[key] ~= command then same = false end end
    for key in pairs(bound) do if not want[key] then same = false end end
    if same then return true end
    ClearOverrideBindings(owner)
    wipe(bound)
    wipe(claimed)
    for _, key in ipairs(Keys.KEYS) do
        local command = want[key]
        if command and commands[key] then
            SetOverrideBinding(owner, true, key, command)
        elseif command then
            SetOverrideBindingClick(owner, true, key, Keys.BUTTON, CLICK_NAME[key])
        end
        bound[key] = command
        if command and (commands[key] or Keys.Get(key, "base")) then claimed[key] = command end
    end
    -- (a layer held through this: its extras back above Base, the newest
    -- priority binding being the one that runs)
    if next(extras) then
        local keep = {}
        for key, command in pairs(extras) do keep[key] = command end
        SetExtras({})
        SetExtras(keep)
    end
    return true
end

-- action nil or "none" clears
function Keys.Set(key, layer, action)
    if not ALLOWED[key] then return false end
    if action == "none" then action = nil end
    if action ~= nil and not T.ValidAction(action) then return false end
    settings[key] = settings[key] or {}
    settings[key][layer] = action
    if next(settings[key]) == nil then settings[key] = nil end
    Keys.Apply()
    CountLayers()
    Notify()
    return true
end

---------------------------------------------------------------------------
-- Out of combat: what a held layer needs on top, where the secure click
-- can't reach. Keys whose Base is ours never change here.
---------------------------------------------------------------------------

-- The layer L2 / R2 hold now, from the pad: "base", "lt", "rt" or "both"
-- (no pad to read: "base", so nothing of a layer stays bound on a guess)
function Keys.HeldLayer()
    return Sh.Layer() or "base"
end

-- key -> command, for a held layer: a Blizzard function on it (its binding),
-- or an action on a key whose Base is Blizzard's (the secure click, which
-- reads the layer). Empty for a layer with none (R2 empty: nothing changes)
function Keys.Extras(layer)
    local out = {}
    if layer == "base" then return out end
    for _, key in ipairs(Keys.KEYS) do
        local action = Keys.Get(key, layer)
        local binding = T.BindingOf(action)
        if binding then
            out[key] = binding
        elseif action and modes[key] ~= "click" then
            out[key] = "CLICK " .. Keys.BUTTON .. ":" .. CLICK_NAME[key]
        end
    end
    return out
end

SetExtras = function(want)
    local same = true
    for key, command in pairs(want) do if extras[key] ~= command then same = false end end
    for key in pairs(extras) do if not want[key] then same = false end end
    if same then return end
    ClearOverrideBindings(layerOwner)
    wipe(extras)
    for key, command in pairs(want) do
        local name = command:match("^CLICK " .. Keys.BUTTON .. ":(%w+)$")
        if name then SetOverrideBindingClick(layerOwner, true, key, Keys.BUTTON, name)
        else SetOverrideBinding(layerOwner, true, key, command) end
        extras[key] = command
    end
end

-- One look at the triggers (the watcher's tick)
function Keys.Watch()
    if not loaded or (InCombatLockdown and InCombatLockdown()) then return end
    -- (no layer action: nothing to read; extras left from the last one still cleared)
    if not anyLayer and not next(extras) then return end
    SetExtras(Keys.Extras(Keys.HeldLayer()))
end

-- Is command one Companion puts on key: its secure click, or a layer's
-- Blizzard function
function Keys.Ours(key, command)
    if command == "CLICK " .. Keys.BUTTON .. ":" .. CLICK_NAME[key] then return true end
    for _, layer in ipairs(Sh.LAYERS) do
        if T.BindingOf(Keys.Get(key, layer)) == command then return true end
    end
    return false
end

-- Every key runs what it should, whatever a window's binding sets left on it
-- (Focus UI stayed on Create after the map, focused with L2 + Create, closed:
-- 2026-11-21). Out of combat: the held layer's extras are dropped and set
-- again, Base put back on top when a key of ours reads otherwise. A key left
-- to the game is only checked for a leftover of ours; the game's own stays.
-- True when something was put right.
function Keys.Heal()
    if not loaded or not GetBindingAction or (InCombatLockdown and InCombatLockdown()) then return false end
    local stale = false
    for _, key in ipairs(Keys.KEYS) do
        local actual = GetBindingAction(key, true) or ""
        local should = extras[key] or bound[key]
        if should then
            if actual ~= should then stale = true end
        elseif actual ~= "" and actual ~= (seen[key] or "") and Keys.Ours(key, actual) then
            stale = true
        end
    end
    if not stale then return false end
    -- (layerOwner emptied outright: a leftover there may not be in extras)
    ClearOverrideBindings(layerOwner)
    wipe(extras)
    for _, key in ipairs(Keys.KEYS) do
        if bound[key] and (GetBindingAction(key, true) or "") ~= bound[key] then Keys.Apply(true); break end
    end
    Keys.Watch()
    return true
end

-- (a key whose Base is ours, taken by Blizzard: back on top. A key bound only
-- for its layers gives way to Blizzard instead)
Sh.Claim(claimed, function()
    if InCombatLockdown and InCombatLockdown() then pending = true; return end
    Keys.Apply(true)
end)

-- Blizzard's gamepad UI, hooked once it is there (at load, else at login):
--   OnCrossBarModifierChanged  L2 / R2 moved (GAMEPADLEFTMOD / RIGHTMOD): a look
--                              at the pad now, so a release clears the extras
--                              before the next press
--   SetUIFocusState, FrameHidden  a window took or gave back the pad (Focus UI,
--                              a window closed): its binding sets moved; every
--                              key checked, now and next frame
local hooked = false
local function HookBlizzard()
    if hooked or type(GamepadMode) ~= "table" then return end
    hooked = true
    if type(GamepadMode.OnCrossBarModifierChanged) == "function" then
        hooksecurefunc(GamepadMode, "OnCrossBarModifierChanged", function() Keys.Watch() end)
    end
    local manager = GamepadMode.FrameControlsManager
    local function Moved()
        Keys.Heal()
        if C_Timer and C_Timer.After then C_Timer.After(0, Keys.Heal) end
    end
    for _, method in ipairs({ "SetUIFocusState", "FrameHidden" }) do
        if type(manager) == "table" and type(manager[method]) == "function" then
            hooksecurefunc(manager, method, Moved)
        end
    end
end
HookBlizzard()

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "UPDATE_MACROS", "SPELLS_CHANGED", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= "GamepadCompanion" then return end
        local char = Sh.CharDB()
        settings = Keys.Normalize(char.keys)
        char.keys = settings
        CountLayers()
        loaded = true
        return
    end
    if not loaded then return end
    if event == "PLAYER_REGEN_DISABLED" then
        -- (the last moment bindings can change: the held layer's extras off)
        SetExtras({})
        return
    end
    if event == "GAME_PAD_ACTIVE_CHANGED" or event == "GAME_PAD_CONNECTED" then
        -- (another pad: the triggers' indexes again; the bindings stay, the
        -- held layer's extras come off until the new pad is read)
        if InCombatLockdown and InCombatLockdown() then pending = true; return end
        button:SetAttribute("gpc-lt", PadIndex("PADLTRIGGER"))
        button:SetAttribute("gpc-rt", PadIndex("PADRTRIGGER"))
        SetExtras({})
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then HookBlizzard() end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    Keys.Apply(event == "PLAYER_REGEN_ENABLED")
end)

-- The watcher: L2 / R2 out of combat, every 20 ms; every key checked 4 times a second
local since, healIn = 0, 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.02 then return end
    healIn = healIn - since
    since = 0
    Keys.Watch()
    if healIn <= 0 then
        healIn = 0.25
        Keys.Heal()
    end
end)
