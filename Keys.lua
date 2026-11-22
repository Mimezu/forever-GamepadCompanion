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
-- layer that has one, in place of the key's Base on the same owner (never a
-- second owner stacked on top: 2026-11-21). In combat those wait: the key
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
local lastDown = {}         -- key -> when it was last seen down (GetTime)
-- A key's binding changes only once it has been up this long: the pad reads a key
-- up a moment before the game has run its release, and Focus UI taken off Create
-- in that moment stayed in the gamepad set till /reload (L2 and Create let go
-- together, 2026-11-22 15:0x: "off PADSOCIAL: gamepad set TOGGLEUIFOCUS")
Keys.GRACE = 0.25
local used = 0              -- macro attributes set last time
local pending, loaded = false, false
local later, laterForce = false, false   -- a rebind waiting for every key of ours to be up
local listeners = {}
local SetExtras             -- (below: the held layer's bindings, on the layer owner, above Base)

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
-- (the watcher's owner until 0.75.0; now only emptied, of a leftover: a
-- held layer's binding goes on owner, in place of the key's Base. Two owners
-- on one key: the game ran the other's, not the newest; Create ran Focus UI
-- with the map on it and L2 up, 2026-11-21)
local layerOwner = CreateFrame("Frame", "GamepadCompanionKeyLayers")

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
-- Is a key of ours held down now (the pad itself)
-- Is key down, or up for less than GRACE (`buttons`: Sh.PadButtons())
local function Busy(buttons, key)
    local now = GetTime and GetTime() or 0
    if Sh.PadDown(buttons, key) == true then lastDown[key] = now; return true end
    return lastDown[key] ~= nil and now - lastDown[key] < Keys.GRACE
end

local function AnyHeld()
    local buttons = Sh.PadButtons()
    for _, key in ipairs(Keys.KEYS) do if Busy(buttons, key) then return true end end
    return false
end

function Keys.Apply(force)
    if InCombatLockdown and InCombatLockdown() then pending = true; return false end
    -- (never with a key held: the game keeps the binding a press ran for the release, and
    -- Focus UI taken off Create mid-press stayed on it for good. The map focused by L2 +
    -- Create binds Blizzard's keys, and the rebind that followed ran with Create still
    -- down, 2026-11-22. Done once every key is up, the next tick)
    if AnyHeld() then later = true; laterForce = laterForce or force or false; return true end
    later, laterForce = false, false
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
            -- (the click as a command string, never SetOverrideBindingClick: see Put)
            SetOverrideBinding(owner, true, key, command)
        end
        bound[key] = command
        if command and (commands[key] or Keys.Get(key, "base")) then claimed[key] = command end
    end
    -- (a layer held through this: its extras back above Base, the newest
    -- priority binding being the one that runs)
    if next(extras) then
        local keep = {}
        for key, command in pairs(extras) do keep[key] = command end
        wipe(extras)
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

-- A trace of the layer's bindings, kept in the saved settings (read after a
-- /reload): each change of the extras, and a snapshot whenever the game says
-- "No interface frame to focus!" (what each key reads, the pad's L2 / R2, the
-- game's own key state). Focus UI kept firing on Create, PS and Mute with L2 up
-- (2026-11-21) after two fixes; this says which side is wrong. 200 lines.
local lastLine
local function Trace(line, list)
    -- (its own saved table: nothing else reads it, no profile copies it; the
    -- error snapshots in their own list, never pushed out by the rest; a line
    -- the same as the last one not written twice)
    if type(GamepadCompanionTraceDB) ~= "table" then GamepadCompanionTraceDB = {} end
    list = list or "focus"
    if list == "focus" and line == lastLine then return end
    if list == "focus" then lastLine = line end
    local t = GamepadCompanionTraceDB[list]
    if type(t) ~= "table" then t = {}; GamepadCompanionTraceDB[list] = t end
    t[#t + 1] = ("%.2f %s"):format(GetTime and GetTime() or 0, line)
    while #t > 200 do table.remove(t, 1) end
end
-- Every pad button down now (the one that just ran a binding among them)
local PAD_NAMES = { "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER",
    "PADRTRIGGER", "PADLSTICK", "PADRSTICK", "PADFORWARD", "PADBACK", "PADSYSTEM", "PADSOCIAL", "PADDUP", "PADDDOWN",
    "PADDLEFT", "PADDRIGHT" }
local function Down()
    local buttons, out = Sh.PadButtons(), {}
    for _, key in ipairs(PAD_NAMES) do if Sh.PadDown(buttons, key) then out[#out + 1] = key end end
    return #out > 0 and table.concat(out, "+") or "none"
end
local function PadState()
    local lt, rt = Sh.Held()
    local k1 = GetBindingKey and GetBindingKey("GAMEPADLEFTMOD")
    local down = k1 and IsKeyDown and IsKeyDown(k1)
    return ("pad L2 %s R2 %s, game L2 key %s down %s"):format(tostring(lt), tostring(rt), tostring(k1), tostring(down))
end
function Keys.Snapshot(why)
    local parts = {}
    for _, key in ipairs(Keys.KEYS) do
        parts[#parts + 1] = ("%s=%s/%s{%s|%s}"):format(key, tostring(GetBindingAction and GetBindingAction(key, true)),
            tostring(GetBindingAction and GetBindingAction(key, false)), tostring(extras[key]), tostring(bound[key]))
    end
    local focus = GamepadMode and GamepadMode.FrameControlsManager
    local focusKeys = { GetBindingKey and GetBindingKey("TOGGLEUIFOCUS") }
    local line = ("%s; down %s; layer %s; %s; focused %s; Focus UI keys %s; %s"):format(why, Down(), tostring(Sh.Layer()),
        PadState(), tostring(focus and focus.isUIFocused), #focusKeys > 0 and table.concat(focusKeys, ",") or "none",
        table.concat(parts, " ")) .. (Keys.Reads and ("; Create reads " .. Keys.Reads("PADSOCIAL")) or "")
    Trace(line, why == "NO FRAME TO FOCUS" and "errors" or "focus")
end

-- A one-time self-test at login (out of combat), on a spare key no one uses
-- (PADPADDLE4, a fresh owner): which ways of taking Focus UI off a key work. The
-- game reads Blizzard's gamepad functions back as "" and ran Focus UI on Create
-- after it was cleared or replaced by our click (2026-11-21). Each step: what
-- GetBindingAction and C_KeyBindings.GetBindingByKey (each context) read
local function Reads(key)
    local out = { "act=" .. tostring(GetBindingAction(key, true)) }
    local KB = C_KeyBindings
    if KB and KB.GetBindingByKey then
        for ctx = 0, 9 do
            local ok, v = pcall(KB.GetBindingByKey, key, ctx)
            if ok and v and v ~= "" then out[#out + 1] = ("c%d=%s"):format(ctx, tostring(v)) end
        end
        local ok, v = pcall(KB.GetBindingByKey, key)
        out[#out + 1] = "any=" .. tostring(ok and v)
    end
    return table.concat(out, " ")
end
Keys.Reads = Reads
-- The red message, however the game shows it (its error event, or straight
-- into the error frame)
local function Said(text)
    if text == ERROR_NO_FRAME_TO_FOCUS or text == "No interface frame to focus!" then
        Keys.Snapshot("NO FRAME TO FOCUS")
        -- (who asked for Focus UI: a binding, a Blizzard footer button, the map...; the
        -- bindings read back can't say, 2026-11-21)
        local stack = debugstack and debugstack(2, 14, 0) or "?"
        Trace("STACK " .. (stack:gsub("\n", " | ")), "errors")
    end
end
if UIErrorsFrame then
    for _, method in ipairs({ "AddMessage", "AddExternalErrorMessage" }) do
        if type(UIErrorsFrame[method]) == "function" then hooksecurefunc(UIErrorsFrame, method, function(_, text) Said(text) end) end
    end
end

-- A held layer's function on key, on the layer owner above Base (nil: taken off).
-- Base itself is never touched: Focus UI taken off Create and the map's click put back
-- in its place left Focus UI in the game's gamepad set (binding context 9) for good,
-- held key or not (2026-11-22). Halo's ring on Create, under our Focus UI on another
-- owner, only ever uncovered, never broke: the same way here
local function Layer(key, command)
    SetOverrideBinding(layerOwner, true, key, nil)
    if command then SetOverrideBinding(layerOwner, true, key, command) end
end

-- What key runs in the game's gamepad set (nil: no way to read it)
local function PadSet(key)
    local K = C_KeyBindings
    if K and K.GetBindingByKey then return K.GetBindingByKey(key, 9) end
end

-- The held layer's bindings: each above the key's Base on the layer owner, and
-- taken off on release (Base uncovered). Only the keys that change are touched,
-- and never a key held down: the game keeps the binding a press ran for its release,
-- and Focus UI swapped off Create mid-press stayed on it for good (L2 let go a moment
-- before Create, 2026-11-22). A held key changes once it has been up GRACE
SetExtras = function(want)
    local same = true
    for key, command in pairs(want) do if extras[key] ~= command then same = false end end
    for key in pairs(extras) do if not want[key] then same = false end end
    if same then return end
    local list = {}
    for key, command in pairs(want) do list[#list + 1] = key .. "=" .. command end
    Trace("extras " .. (#list > 0 and table.concat(list, " ") or "none") .. "; down " .. Down() .. "; " .. PadState())
    local buttons = Sh.PadButtons()
    local function Held(key) return Busy(buttons, key) end
    for key in pairs(extras) do
        if not want[key] and not Held(key) then
            Layer(key, nil); extras[key] = nil
            Trace("off " .. key .. ": gamepad set " .. tostring(PadSet(key)))
        end
    end
    for key, command in pairs(want) do
        if extras[key] ~= command and not Held(key) then Layer(key, command); extras[key] = command end
    end
end

-- One look at the triggers (the watcher's tick)
function Keys.Watch()
    if not loaded or (InCombatLockdown and InCombatLockdown()) then return end
    -- (no layer action: nothing to read; extras left from the last one still cleared)
    if not anyLayer and not next(extras) then return end
    -- (each tick, when the layer's keys were last down: the grace before one changes)
    if next(extras) then
        local buttons = Sh.PadButtons()
        for key in pairs(extras) do Busy(buttons, key) end
    end
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
local ghosts = {}
function Keys.Heal()
    if not loaded or not GetBindingAction or (InCombatLockdown and InCombatLockdown()) then return false end
    local stale, ghost = false, false
    for _, key in ipairs(Keys.KEYS) do
        local actual = GetBindingAction(key, true) or ""
        local should = extras[key] or bound[key]
        if should then
            -- (a Blizzard function, Radial on Options, reads back empty in game:
            -- 4 heals a second, every key rebound each time, 2026-11-21. Only
            -- our own click, or another command in its place, is wrong)
            local ourClick = should:find("^CLICK " .. Keys.BUTTON .. ":") ~= nil
            -- (a held layer's Blizzard function reads back as what's under it: not stale)
            local unread = extras[key] and not ourClick
            if actual ~= should and not unread and (ourClick or actual ~= "") then stale = true end
            -- (a layer's function of ours left in the gamepad set, under Base)
            local pad = PadSet(key)
            -- (once: one the rebind can't clear is the game's own, left till /reload)
            if pad and pad ~= should and Keys.Ours(key, pad) then
                if not ghosts[key] then stale = true; ghost = true end
                ghosts[key] = true
            else
                ghosts[key] = nil
            end
        elseif actual ~= "" and actual ~= (seen[key] or "") and Keys.Ours(key, actual) then
            stale = true
        end
    end
    if not stale then return false end
    Keys.Snapshot("heal")
    -- (the held layer's off, Base back; the old owner emptied of a leftover)
    ClearOverrideBindings(layerOwner)
    SetExtras({})
    if ghost then Keys.Apply(true) end
    for _, key in ipairs(Keys.KEYS) do
        local actual = GetBindingAction(key, true) or ""
        if bound[key] and actual ~= bound[key] and (bound[key]:find("^CLICK " .. Keys.BUTTON .. ":") or actual ~= "") then Keys.Apply(true); break end
    end
    Keys.Watch()
    return true
end

-- (a key whose Base is ours, taken by Blizzard: back on top. A key bound only
-- for its layers gives way to Blizzard instead)
Sh.Claim(claimed, function()
    if InCombatLockdown and InCombatLockdown() then pending = true; return end
    -- (a key under a held layer's function reads as that, or empty: not taken. A Blizzard
    -- function reads back empty too: only our click, or another command, is taken)
    for key, command in pairs(claimed) do
        local actual, should = GetBindingAction(key, true) or "", extras[key] or command
        if actual ~= should and (should:find("^CLICK " .. Keys.BUTTON .. ":") or actual ~= "") then
            Keys.Apply(true)
            return
        end
    end
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
    "PLAYER_REGEN_DISABLED", "UPDATE_MACROS", "SPELLS_CHANGED", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED",
    "UI_ERROR_MESSAGE" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg, msg)
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
    if event == "UI_ERROR_MESSAGE" then
        -- (the trace: what every key reads the moment Focus UI found nothing)
        Said(msg or arg)   -- (errorType, message)
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        -- (the last moment bindings can change: the held layer's extras off)
        SetExtras({})
        return
    end
    if event == "GAME_PAD_ACTIVE_CHANGED" or event == "GAME_PAD_CONNECTED" then
        -- (another pad: the triggers' indexes again; the bindings stay, the
        -- held layer's extras come off until the new pad is read)
        if Sh.ForgetPadIndexes then Sh.ForgetPadIndexes() end
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

-- A trigger stuck: the game holds L2 (or R2) down, the pad has it up. Blizzard's bars read the
-- game's key (IsKeyDown on GAMEPADLEFTMOD's key), so a release the game never got leaves the
-- L2 bar on: jump and every shortcut on L2's page till /reload (2026-11-22, twice while
-- fishing). Seen STUCK_AFTER: written down (the errors list: what the key runs, the pad), and
-- the key's binding put again once (out of combat) so the game lets go of it; then whether
-- that worked. Keys.STUCK_AFTER s.
-- Every pad button, not only the triggers: jump and Interact stopped too (2026-11-22 15:5x).
Keys.STUCK_AFTER = 0.5
local MODS = { GAMEPADLEFTMOD = "L2", GAMEPADRIGHTMOD = "R2" }
local stuck = {}             -- key -> { since, tried, said }
local unstickOwner = CreateFrame("Frame", "GamepadCompanionKeyUnstick")
function Keys.CheckStuck(now)
    if not (loaded and IsKeyDown) then return end
    local buttons = Sh.PadButtons()
    if not buttons then return end
    for _, key in ipairs(PAD_NAMES) do
        local game = IsKeyDown(key)
        local pad = Sh.PadDown(buttons, key)
        local s = stuck[key]
        if game and pad == false and not s then s = { since = now }; stuck[key] = s end
        if game and pad == false then
            -- (what the key runs; a modifier by its name: L2, R2)
            local binding = GetBindingAction and GetBindingAction(key, true) or ""
            local name = key
            for b, label in pairs(MODS) do if GetBindingKey and GetBindingKey(b) == key then binding, name = b, label end end
            if now - s.since >= Keys.STUCK_AFTER and not s.said then
                s.said, s.name = true, name
                Trace(("STUCK %s: the game holds %s down, the pad has it up; it runs %s; %s"):format(name, key,
                    tostring(GetBindingAction and GetBindingAction(key, true)), PadState()), "errors")
            end
            if s.said and not s.tried and not (InCombatLockdown and InCombatLockdown()) then
                -- (the key's own binding put on top, then off: the game takes it as a new one)
                s.tried = now
                if binding ~= "" then SetOverrideBinding(unstickOwner, true, key, binding) end
                SetOverrideBinding(unstickOwner, true, key, nil)
            elseif s.tried and s.tried ~= true and now - s.tried >= 0.3 then
                Trace(("STUCK %s: still held after a rebind"):format(name), "errors")
                s.tried = true
            end
        elseif s then
            if s.said then
                Trace(("STUCK %s: let go after %.1f s%s"):format(s.name or key, now - s.since, s.tried and " (rebound)" or ""), "errors")
            end
            stuck[key] = nil
        end
    end
end

-- The watcher: L2 / R2 out of combat, every 20 ms; every key checked 4 times a second
local since, healIn, stuckIn = 0, 0, 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.02 then return end
    healIn = healIn - since
    since = 0
    if later and not AnyHeld() then Keys.Apply(laterForce) end
    Keys.Watch()
    if healIn <= 0 then
        healIn = 0.25
        Keys.Heal()
    end
    -- (ten times a second: every pad button, the game's against the pad's)
    stuckIn = stuckIn - 0.02
    if stuckIn <= 0 then
        stuckIn = 0.1
        Keys.CheckStuck(GetTime and GetTime() or 0)
    end
end)
