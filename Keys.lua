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
local SetExtras, Layer      -- (below: the held layer's bindings, on the layer owner, above Base)

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
-- A held layer's bindings, above Base: a Blizzard function (Focus UI, Radial)
-- on the key's layer owner, our secure click on the click pool. Never both on one owner's
-- key: the game keeps a function's binding-context-9 slot in that owner's
-- record for the key, and a click put there later (even after clearing it)
-- runs the function instead, till /reload (login probe). Mute: L2 Focus UI,
-- then R2 for L2 + R2's Halo ring, ran Focus UI and never the ring, 2026-11-22
-- One function owner per key, taken off with ClearOverrideBindings: a nil binding left Focus
-- UI in the gamepad set ("off PAD5: gamepad set TOGGLEUIFOCUS" after every L2 release), the
-- whole owner cleared took it out (2026-11-23)
local layerOwners = {}       -- key -> its owner (made on first use)
local function LayerOwner(key)
    local o = layerOwners[key]
    if not o then o = CreateFrame("Frame", "GamepadCompanionKeyLayer" .. key); layerOwners[key] = o end
    return o
end
local changed = {}           -- key -> when its layer binding last changed

-- The game keeps a key's override in a record per owner, with a slot per binding context: a
-- click or plain command in 0, a gamepad function in 9. Let go (nil, "", ClearOverrideBindings)
-- the record keeps its slots, and the next owner binding the key, whoever it is, is handed it
-- back, slots and all: the function runs again under that owner's click (login probe: "focus"
-- after "nil" brought the old click back in context 0; trace 2026-11-24: Mute ran Focus UI under
-- R2's click with its L2 layer long cleared, and every Create leftover came 0.1 s after
-- "GamepadCompanionKeyBinds cleared", Base cleared whole and rewritten). So Base is written in
-- place, never cleared whole (a live record is never handed on), and a click is read back from
-- the gamepad set (PadSet): a function under it, and the pool's next owner takes the key while
-- the bad one still holds its record (so it can't be handed back), then the bad one is let go
-- and the key read again. PUT_OWNERS owners a pool. A click no owner holds clean: Base keeps the
-- last (the key bound at least), a layer's click is left off; both written down (REUSED).
-- And a click goes on as a click binding (SetOverrideBindingClick), not the command string:
-- the game keeps those records apart from commands' (Halo's ring and Blizzard's footer, both
-- click bindings, never ran Focus UI through two hours of it, 2026-11-24), so no record that
-- held a function should ever reach a click. The read-back is the proof, each time
Keys.PUT_OWNERS = 4
local Trace, OwnerName       -- (below)
local function Pool(name, keep)
    local p = { owners = {}, holder = {}, kind = {}, keep = keep }   -- holder: key -> the owner whose record is live
    for i = 1, Keys.PUT_OWNERS do p.owners[i] = CreateFrame("Frame", name .. (i > 1 and tostring(i) or "")) end
    return p
end
local base = Pool("GamepadCompanionKeyBinds", true)
local click = Pool("GamepadCompanionKeyLayerClicks", false)
local FUNCTION = {}          -- the gamepad set's commands (binding context 9)
for _, b in ipairs(T.BINDINGS) do FUNCTION[b.binding] = true end

-- What key runs in the game's gamepad set (nil: no way to read it)
local function PadSet(key)
    local K = C_KeyBindings
    if K and K.GetBindingByKey then return K.GetBindingByKey(key, 9) end
end
-- Does the gamepad set run a function where command, a click, should (not above: the held
-- layer's own function over the key, Base written under L2's Focus UI reads that, rightly. A
-- layer's click has none: Layer cleared it just before, L2 + R2 on Mute after L2's Focus UI)
local function Haunted(key, command, above)
    local pad = PadSet(key)
    return pad ~= nil and pad ~= command and pad ~= above and FUNCTION[pad] == true
end
local function Drop(pool, key)
    local o = pool.holder[key]
    if not o then return end
    SetOverrideBinding(o, true, key, nil)
    pool.holder[key] = nil
    pool.kind[key] = nil
end
-- command on key for o: our click as a click binding, a function as its command
local function Bind(o, key, command)
    local name = command:match("^CLICK " .. Keys.BUTTON .. ":(%w+)$")
    if name then SetOverrideBindingClick(o, true, key, Keys.BUTTON, name) else SetOverrideBinding(o, true, key, command) end
end
-- command on key for pool: in place on its holder's record; fresh, on another owner's, the
-- holder's let go once that one is taken (the newest binding runs). True when the key reads right
local function Put(pool, key, command, fresh)
    local prev = pool.holder[key]
    local fn = FUNCTION[command] == true
    local above = pool.keep and extras[key] and FUNCTION[extras[key]] and extras[key] or nil
    -- (a click where a command was, or the other way: another owner, the old record let go; the
    -- game keeps the two kinds apart, so one written over the other leaves both live)
    local kind = command:find("^CLICK " .. Keys.BUTTON .. ":") and "click" or "command"
    if pool.kind[key] and pool.kind[key] ~= kind then fresh = true end
    pool.kind[key] = kind
    if prev and not fresh then
        Bind(prev, key, command)
        if fn or not Haunted(key, command, above) then return true end
    end
    for _, o in ipairs(pool.owners) do
        if o ~= prev then
            Bind(o, key, command)
            if prev then SetOverrideBinding(prev, true, key, nil) end
            prev = o
            if fn or not Haunted(key, command, above) then pool.holder[key] = o; return true end
            Trace(("REUSED %s: %s under %s on %s; the next owner"):format(key, tostring(PadSet(key)), command, OwnerName(o)), "errors")
        end
    end
    if pool.keep then
        pool.holder[key] = prev
    else
        SetOverrideBinding(prev, true, key, nil)
        pool.holder[key], pool.kind[key] = nil, nil
    end
    Trace(("REUSED %s: %s under %s on every owner; %s"):format(key, tostring(PadSet(key)), command,
        pool.keep and "kept on the last" or "left off"), "errors")
    return false
end

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
        -- (read empty: a held layer's Blizzard function reads back "" in game, and so did what
        -- was seen under our click. The player's own binding then: PS's screenshot, under
        -- L2's Focus UI, was taken for a free key and became our click, 2026-11-23)
        if game == "" and GetBindingAction then game = GetBindingAction(key) or "" end
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
    wipe(claimed)
    -- (each key in place: a key dropped is let go, a changed one written over (Put sees a
    -- function's slot under a click and takes another record), one the same left as it is
    -- unless another owner's binding covers it (Blizzard's footer on Options with a window
    -- focused): that one set afresh, newest on the key. Never every key cleared and rewritten)
    local relayer = {}
    for _, key in ipairs(Keys.KEYS) do
        local command = want[key]
        if not command then
            if bound[key] then Drop(base, key) end
        elseif command ~= bound[key] then
            Put(base, key, command)
            if extras[key] then relayer[key] = true end
        elseif force then
            local actual = GetBindingAction and GetBindingAction(key, true) or ""
            local top = extras[key] or command
            if actual ~= top and (not FUNCTION[top] or actual ~= "") then
                if extras[key] then relayer[key] = true else Put(base, key, command, true) end
            end
        end
        bound[key] = command
        if command and (commands[key] or Keys.Get(key, "base")) then claimed[key] = command end
    end
    -- (a layer held through this on a key written or covered: its extra back above Base, the
    -- newest priority binding being the one that runs)
    for key in pairs(relayer) do Layer(key, extras[key], true) end
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
Trace = function(line, list)
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
-- A one-time self-test at login (out of combat), on a spare key no one uses (PROBE_KEY) with
-- owners of its own, never a key of ours: how the game hands a key's record on. Each step's
-- reads in GamepadCompanionTraceDB.probe (overwritten each login). What each line answers:
--   "C click over B cleared"      c9=TOGGLEUIFOCUS: another owner's click (a command string)
--                                 brings a cleared function back (the record handed on, slots
--                                 and all)
--   "C click binding over B cleared"  no c9 (any=the click): a click binding's record is apart
--                                 from commands' (the fix's way); c9=TOGGLEUIFOCUS: it is not
--   "B focus+clear, C click"      still c9: the function's owner setting it again and clearing
--                                 does not remove it
--   "B radial+clear, C click"     c9=OPENRADIAL: the slot is only ever overwritten
--   "D click, C let go first"     a fresh owner gets it too
--   "D click while C holds, C let go"  no c9 (any=click3): the fix's way, a record taken
--                                 while the bad one is still held, works
--   "B empty over A"              act=click1: an empty command falls through to the owner
--                                 under it; act= : it shadows the key
--   "C click over B focus live"   any=TOGGLEUIFOCUS: a live function anywhere on the key
--                                 wins; any=click2: the newest record wins
--   "A again under C"             any=click1: a write in place puts the record on top
--   "end"                         act= any=nil: nothing left on the spare key
Keys.PROBE_KEY = "PADPADDLE4"
function Keys.Probe()
    if InCombatLockdown and InCombatLockdown() then return end
    local KB, key = C_KeyBindings, Keys.PROBE_KEY
    if not (KB and KB.GetBindingByKey) then return end
    local A, B, C, D = CreateFrame("Frame", "GamepadCompanionProbeA"), CreateFrame("Frame", "GamepadCompanionProbeB"),
        CreateFrame("Frame", "GamepadCompanionProbeC"), CreateFrame("Frame", "GamepadCompanionProbeD")
    local lines = {}
    local function Step(name) lines[#lines + 1] = name .. ": " .. Reads(key) end
    local function Set(o, command) SetOverrideBinding(o, true, key, command) end
    local function Off(...) for _, o in ipairs({ ... }) do ClearOverrideBindings(o) end end
    if KB.GetBindingContextForAction then
        for _, a in ipairs({ "TOGGLEUIFOCUS", "OPENRADIAL", "CLICK " .. Keys.BUTTON .. ":p5" }) do
            local ok, v = pcall(KB.GetBindingContextForAction, a)
            lines[#lines + 1] = "context " .. a .. " = " .. tostring(ok and v)
        end
    end
    -- (clicks on buttons never bound: L1 and R1's names)
    local click1, click2, click3 = "CLICK " .. Keys.BUTTON .. ":p1", "CLICK " .. Keys.BUTTON .. ":p2", "CLICK " .. Keys.BUTTON .. ":p3"
    local FOCUS, RADIAL = "TOGGLEUIFOCUS", "OPENRADIAL"
    Step("start")
    -- another owner's click over a cleared function
    Set(A, click1); Step("A click")
    Set(B, FOCUS); Step("B focus over A")
    Off(B); Step("B cleared")
    Set(C, click2); Step("C click over B cleared")
    Set(C, nil); Step("C nil")
    Set(C, click2); Step("C click again")
    Set(C, nil); SetOverrideBindingClick(C, true, key, Keys.BUTTON, "p2"); Step("C click binding over B cleared")
    Set(C, nil); Set(B, FOCUS); Off(B); SetOverrideBindingClick(C, true, key, Keys.BUTTON, "p2"); Step("B focus+clear, C click binding")
    -- ways out
    Set(C, nil); Set(B, FOCUS); Off(B); Set(C, click2); Step("B focus+clear, C click")
    Set(C, nil); Set(B, RADIAL); Off(B); Set(C, click2); Step("B radial+clear, C click")
    Set(C, nil); Set(D, click3); Step("D click, C let go first")
    Set(D, nil)
    Set(C, click2); Set(D, click3); Set(C, nil); Step("D click while C holds, C let go")
    Set(D, nil); Step("D nil")
    -- an empty command
    Set(B, ""); Step("B empty over A")
    Set(B, FOCUS); Set(B, ""); Step("B focus then empty")
    Off(B); Step("B cleared again")
    -- the newest click over a live function
    Set(B, FOCUS); Set(C, click2); Step("C click over B focus live")
    Set(C, nil); Off(B); Step("B, C off")
    -- a write in place, to the top
    Set(C, click2); Set(A, click1); Step("A again under C")
    Set(C, nil); Step("C nil, A alone")
    -- parking (Layer's way since 2026-11-24): a function set to "" stays on its owner; the
    -- next owner's click must read clean (c9 = the click), the function back when set again
    Off(A, B, C, D)
    Set(A, click1); Set(B, FOCUS); Set(B, ""); Step("park: B focus then empty")
    Set(C, click2); Step("park: C click over B parked")
    Set(C, nil); Set(B, FOCUS); Step("park: B focus again")
    Set(B, ""); Set(D, click3); Step("park: B parked again, D click")
    Set(D, nil); Set(C, click2); Step("park: C click again")
    -- (2026-11-25: "" lets go like nil, C's click got Focus UI.) Ways to keep the record held:
    -- the function overwritten in place by a click, as a command and as a click binding; and
    -- the click put on first, the function let go after (the recipe that read clean)
    Off(A, B, C, D)
    Set(A, click1); Set(B, FOCUS); Set(B, click2); Step("hold: B focus, click in place")
    Set(C, click3); Step("hold: C click over B held")
    Off(A, B, C, D)
    Set(A, click1); Set(B, FOCUS); SetOverrideBindingClick(B, true, key, Keys.BUTTON, "p2"); Step("hold: B focus, click binding in place")
    Set(C, click3); Step("hold: C click over B held binding")
    Off(A, B, C, D)
    Set(A, click1); Set(B, FOCUS); SetOverrideBindingClick(C, true, key, Keys.BUTTON, "p2"); Set(B, nil); Step("hold: C click on, then B let go")
    Set(D, click3); Step("hold: D click after")
    Off(A, B, C, D)
    -- (2026-11-25: every "hold:" step read Focus UI: a record that once held it keeps it under any
    -- click written over it.) Blizzard runs its pad functions as clicks on its own buttons
    -- (UIParent binds "CLICK InputFunctionBindingButton_<KEY>:LeftButton"). Those buttons, what
    -- they hold, and a click binding on one: if it leaves no function in c9, Focus UI can go on a
    -- key as a click and never haunt it
    local found = {}
    for name, f in pairs(_G) do
        if type(name) == "string" and name:find("^InputFunctionBindingButton") and type(f) == "table" then found[#found + 1] = name end
    end
    table.sort(found)
    for i, name in ipairs(found) do
        if i > 12 then break end
        local f, attrs = _G[name], {}
        for _, a in ipairs({ "type", "binding", "action", "clickbutton", "func", "function", "macrotext" }) do
            local ok, v = pcall(f.GetAttribute, f, a)
            if ok and v ~= nil then attrs[#attrs + 1] = a .. "=" .. tostring(v) end
        end
        local ok, click = pcall(f.GetScript, f, "OnClick")
        lines[#lines + 1] = ("button %s: %s%s"):format(name, table.concat(attrs, " "), ok and click and " OnClick" or "")
    end
    lines[#lines + 1] = "buttons: " .. #found
    local back = _G["InputFunctionBindingButton_PADBACK"] and "InputFunctionBindingButton_PADBACK" or found[1]
    if back then
        Set(A, click1); SetOverrideBindingClick(B, true, key, back, "LeftButton"); Step("blizz: click on " .. back)
        Set(C, click2); Step("blizz: C click after")
        Off(A, B, C, D)
    end
    Step("end")
    if type(GamepadCompanionTraceDB) ~= "table" then GamepadCompanionTraceDB = {} end
    GamepadCompanionTraceDB.probe = lines
end
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
-- The game's own pad hand-back blocked. A window closing runs Blizzard's chain (!BugGrabber's
-- stacks, 2026-11-24, 12 addons blamed): HideUIPanel -> FrameControlsManager:FrameHidden ->
-- CheckForInputBinding -> DeactivateBindingGroup -> InputBindingManager:RemoveSet ->
-- CheckCoreBindingActive -> MainActionBarFrame:UpdateActionBarFocusedState ->
-- UpdateInteractIcons -> SetPreferredGamepadInteractTarget (protected). With another addon's
-- taint on the closing (the window's OnHide reading a field that addon wrote: Auctionator's
-- on the Auction House's own frames, the AH closing on an Auctionator tab), the game refuses
-- that one call and the rest of the listener runs tainted: it rewrites the HUD buttons'
-- ApplyExtraButtonStylesForState closures (ActionBarStyles.lua) and the manager's
-- currentCoreBindingActive / activeBindings. Cross and the jump button are plain OnClick
-- handlers that read that closure first (ApplyPressedStyle), so RunBinding("JUMP") and
-- InteractUnit are refused from then on; spells keep working (secure attributes). Every later
-- hand-back reads the tainted manager fields before writing, so it stays so until /reload.
-- Nothing here can undo it; it is said at once, with the addon the game blames, and the trace
-- keeps the stack and which slots are tainted (issecurevariable: reads, no writes of ours).
Keys.PAD_HANDBACK = { SetPreferredGamepadInteractTarget = true, ["SetPreferredGamepadInteractTarget()"] = true }
-- "name=addon" for each tainted slot among the hand-back's, then how many are clean
function Keys.PadSlots()
    if type(issecurevariable) ~= "function" then return "no issecurevariable" end
    local tainted, clean = {}, 0
    local function Add(label, t, key)
        if type(t) ~= "table" then return end
        local ok, who = issecurevariable(t, key)
        if ok then clean = clean + 1 else tainted[#tainted + 1] = ("%s=%s"):format(label, tostring(who or "?")) end
    end
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    if type(manager) == "table" then
        Add("core-active", manager, "currentCoreBindingActive")
        Add("assume-core", manager, "assumeCoreBindingsUsable")
        local stack = manager.bindingSetStack
        if type(stack) == "table" then
            for i = 1, #stack do
                local set = stack[i]
                Add(("stack%d(%s)"):format(i, type(set) == "table" and tostring(set.name) or "?"), stack, i)
            end
        end
        local active = manager.activeBindings
        if type(active) == "table" then
            local n, first = 0, nil
            for key in pairs(active) do
                local ok, who = issecurevariable(active, key)
                if not ok then n = n + 1; first = first or ("%s=%s"):format(tostring(key), tostring(who or "?")) else clean = clean + 1 end
            end
            if n > 0 then tainted[#tainted + 1] = ("active-bindings:%d(%s)"):format(n, first) end
        end
    end
    local focus = GamepadMode and GamepadMode.FrameControlsManager
    if type(focus) == "table" then
        Add("ui-focused", focus, "isUIFocused")
        Add("catcher", focus, "fallThroughCatcherActive")
        Add("focused-frame", focus, "focusedFrame")
        local shown = focus.shownFrames
        if type(shown) == "table" then for i = 1, #shown do Add("shown" .. i, shown, i) end end
    end
    local root = _G.GamepadMainActionBarFrame
    local top = root and type(root.PageUnit) == "table" and type(root.PageUnit.actionBars) == "table" and root.PageUnit.actionBars.topBar
    if type(top) == "table" then
        Add("top.style", top, "appliedStyle")
        Add("top.scaled", top, "actionBarScaledUp")
        for name, index in pairs({ interact = 1, back = 3, jump = 4 }) do
            local button = type(top.Right) == "table" and top.Right["ActionButton" .. index]
            Add(name .. ".closure", button, "ApplyExtraButtonStylesForState")
            Add(name .. ".mouse", button, "clickedUsingMouse")
        end
    end
    local ah = _G.AuctionHouseFrame
    if type(ah) == "table" then
        Add("ah.displayMode", ah, "displayMode")
        for _, key in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
            local f = ah[key]
            Add(key .. ".itemLocation", f, "itemLocation")
            Add(key .. ".pendingPost", f, "pendingPost")
            Add(key .. ".listKey", f, "listDisplayedItemKey")
            Add(key .. ".prevKey", f, "previousItemKey")
        end
    end
    return (#tainted > 0 and ("tainted " .. table.concat(tainted, " ")) or "none tainted") .. ("; %d clean"):format(clean)
end
-- The stuck pad found by its own mark, no event needed: Cross's style closure tainted. The
-- addon whose taint it carries, or nil while the pad is fine.
function Keys.PadStuckBy()
    if type(issecurevariable) ~= "function" then return nil end
    local root = _G.GamepadMainActionBarFrame
    local bars = root and type(root.PageUnit) == "table" and root.PageUnit.actionBars
    local button = type(bars) == "table" and type(bars.topBar) == "table" and type(bars.topBar.Right) == "table"
        and bars.topBar.Right.ActionButton1
    if type(button) ~= "table" then return nil end
    local ok, who = issecurevariable(button, "ApplyExtraButtonStylesForState")
    if ok then return nil end
    return tostring(who or "?")
end
local stuckSaid, blockedTraced = {}, 0
local function SayStuck(addon)
    if stuckSaid[addon] then return end
    stuckSaid[addon] = true
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(("Pad stuck by %s · /reload"):format(tostring(addon)), 1, 0.82, 0, 1, 6)
    end
end
function Keys.PadHealth()
    local who = Keys.PadStuckBy()
    if not who or stuckSaid[who] then return who end
    Trace(("STUCK by %s: Cross's style closure tainted (jump, Interact refused until /reload)"):format(who), "errors")
    Trace("SLOTS " .. Keys.PadSlots(), "errors")
    SayStuck(who)
    return who
end
function Keys.Blocked(addon, fn)
    if not (fn and Keys.PAD_HANDBACK[fn]) then return end
    Trace(("BLOCKED %s by %s: the pad's hand-back stopped (jump, Interact)"):format(tostring(fn), tostring(addon)), "errors")
    -- (the event comes inside the refused call: the stack is the closing's, Blizzard's frames
    -- and the addon's; the first three of a session, the rest would say the same)
    if blockedTraced < 3 then
        blockedTraced = blockedTraced + 1
        local stack = type(debugstack) == "function" and debugstack(2, 30, 30) or "?"
        Trace("STACK " .. (stack:gsub("Interface/AddOns/", ""):gsub("\n", " | ")), "errors")
        Trace("SLOTS " .. Keys.PadSlots(), "errors")
        -- (the listener writes its tainted closures after the refused call: read them next frame)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() Trace("SLOTS+1 " .. Keys.PadSlots(), "errors") end) end
    end
    SayStuck(tostring(addon))
end

if UIErrorsFrame then
    for _, method in ipairs({ "AddMessage", "AddExternalErrorMessage" }) do
        if type(UIErrorsFrame[method]) == "function" then hooksecurefunc(UIErrorsFrame, method, function(_, text) Said(text) end) end
    end
end

-- A held layer's command on key, above Base (nil: taken off): a function on
-- the key's layer owner, a click on the click pool (fresh: on another record, newest on the
-- key), the other owner's cleared. Base itself is never touched: Focus UI taken off Create
-- and the map's click put back in its place left Focus UI in the game's gamepad set (binding
-- context 9) for good, held key or not (2026-11-22). Halo's ring on Create, under our Focus
-- UI on another owner, only ever uncovered, never broke: the same way here. False: a click
-- no owner holds clean, left off
-- A layer's function is set to "" when let go. That does NOT keep its record: the login probe
-- of 2026-11-25 ("park: C click over B parked" -> Focus UI) shows "" lets go like nil, and the
-- game hands that record, Focus UI still in it, to the next owner that binds the key afresh.
-- Halo's whole-set rebind took it on Mute (fixed in Halo 0.9.42: written in place); a key kept
-- bound is never handed anything. The probe's "hold:" steps test ways to keep it held
local parked = {}            -- key -> true: its layer owner holds an empty binding
Layer = function(key, command, fresh)
    -- (fresh: parked again whatever we think, the heal's way)
    if layerOwners[key] and (not parked[key] or fresh) then
        SetOverrideBinding(layerOwners[key], true, key, "")
        parked[key] = true
    end
    local ok = true
    if command and FUNCTION[command] then
        Drop(click, key)
        SetOverrideBinding(LayerOwner(key), true, key, command)
        parked[key] = nil
    elseif command then
        ok = Put(click, key, command, fresh)
    else
        Drop(click, key)
    end
    changed[key] = GetTime and GetTime() or 0
    return ok
end

-- The held layer's bindings: each above the key's Base on the layer owner, and
-- taken off on release (Base uncovered). Only the keys that change are touched,
-- and never a key held down: the game keeps the binding a press ran for its release,
-- and Focus UI swapped off Create mid-press stayed on it for good (L2 let go a moment
-- before Create, 2026-11-22). A held key changes once it has been up GRACE
-- (a layer's click no owner could hold clean: not tried again every tick, only once the layer
-- changes; the key runs its Base meanwhile)
local withheld = {}
SetExtras = function(want)
    for key, command in pairs(withheld) do if want[key] ~= command then withheld[key] = nil end end
    local same = true
    for key, command in pairs(want) do if extras[key] ~= command and withheld[key] ~= command then same = false end end
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
        if extras[key] ~= command and withheld[key] ~= command and not Held(key) then
            if Layer(key, command) then extras[key] = command else withheld[key] = command end
        end
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
-- A function of ours left in the game's gamepad set under a key's Base (Create ran Focus UI,
-- no map), its layer off GHOST_AFTER s (a read right after a change can lag). A try: the key's
-- layer owners emptied (a function of ours still live there); still read, it sits in the
-- record Base holds (one the game handed back with Focus UI in it): the key's command put
-- again, on another record (Put), that key alone. GHOST_EVERY s apart, GHOST_TRIES tries,
-- each written down with what it left and who last wrote the key; then a note to /reload.
-- One under a key the game owns (Halo's ring on Mute), in a record of no owner of ours: the
-- layer owner cleared once, then written down and the note; nothing of ours can let it go.
Keys.GHOST_AFTER, Keys.GHOST_EVERY, Keys.GHOST_TRIES = 1, 2, 3

-- Who writes our keys (SetOverrideBinding / Click on one, and those owners' ClearOverrideBindings):
-- the last WRITES_KEEP, written down with a leftover so its owner can be named
Keys.WRITES_KEEP = 30
local writes, writers = {}, {}
local OUR_KEY = {}
for _, k in ipairs(Keys.KEYS) do OUR_KEY[k] = true end
OwnerName = function(o)
    local ok, name = pcall(function() return o and o.GetName and o:GetName() end)
    return ok and name or tostring(o)
end
local function Wrote(o, line)
    writes[#writes + 1] = ("%.2f %s %s"):format(GetTime and GetTime() or 0, OwnerName(o), line)
    if #writes > Keys.WRITES_KEEP then table.remove(writes, 1) end
end
if hooksecurefunc then
    hooksecurefunc("SetOverrideBinding", function(o, _, key, action)
        if OUR_KEY[key] then writers[o or "nil"] = true; Wrote(o, key .. "=" .. tostring(action)) end
    end)
    hooksecurefunc("SetOverrideBindingClick", function(o, _, key, b, mouse)
        if OUR_KEY[key] then writers[o or "nil"] = true; Wrote(o, key .. "=CLICK " .. tostring(b) .. ":" .. tostring(mouse)) end
    end)
    hooksecurefunc("ClearOverrideBindings", function(o) if writers[o or "nil"] then Wrote(o, "cleared") end end)
end
-- (the writes that touched key, or cleared an owner, oldest first)
function Keys.Writes(key)
    local list = {}
    for _, w in ipairs(writes) do
        if w:find(" " .. key .. "=", 1, true) or w:find(" cleared$") then list[#list + 1] = w end
    end
    return table.concat(list, " | ")
end
local KEY_NAMES = { PADSOCIAL = "Create", PADFORWARD = "Options", PADSYSTEM = "PS", PAD5 = "Mute", PADLSTICK = "L3", PADRSTICK = "R3" }
local FN_NAMES = { TOGGLEUIFOCUS = "Focus UI", OPENRADIAL = "Radial" }
local ghosts = {}           -- key -> { tries, at, said }
local function Note(key, pad)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(("%s stuck on %s · /reload"):format(KEY_NAMES[key] or key, FN_NAMES[pad] or pad), 1, 0.82, 0, 1, 6)
    end
end
function Keys.Heal()
    if not loaded or not GetBindingAction or (InCombatLockdown and InCombatLockdown()) then return false end
    local now = GetTime and GetTime() or 0
    local stale = false
    local tried = {}
    -- (a leftover on key, pad in its gamepad set: a try now, GHOST_EVERY after the last; the
    -- note once the tries are spent)
    local function Found(key, pad)
        local g = ghosts[key]
        if not g then g = { tries = 0, at = -math.huge }; ghosts[key] = g end
        if g.tries < Keys.GHOST_TRIES and now - g.at >= Keys.GHOST_EVERY then
            if g.tries == 0 then Trace(("GHOST %s writes: %s"):format(key, Keys.Writes(key)), "errors") end
            g.tries, g.at = g.tries + 1, now
            stale = true
            tried[key] = pad
        elseif g.tries >= Keys.GHOST_TRIES and not g.said then
            g.said = true
            Trace(("GHOST %s: %s stays in the gamepad set after %d tries"):format(key, pad, g.tries), "errors")
            Note(key, pad)
        end
    end
    local function Gone(key)
        if not ghosts[key] then return end
        Trace(("GHOST %s: gone after %d tries"):format(key, ghosts[key].tries), "errors")
        ghosts[key] = nil
    end
    for _, key in ipairs(Keys.KEYS) do
        local actual = GetBindingAction(key, true) or ""
        local should = extras[key] or bound[key]
        local pad = PadSet(key)
        local settled = now - (changed[key] or -math.huge) >= Keys.GHOST_AFTER
        if should then
            -- (a Blizzard function, Radial on Options, reads back empty in game:
            -- 4 heals a second, every key rebound each time, 2026-11-21. Only
            -- our own click, or another command in its place, is wrong)
            local ourClick = should:find("^CLICK " .. Keys.BUTTON .. ":") ~= nil
            -- (a held layer's Blizzard function reads back as what's under it: not stale)
            local unread = extras[key] and not ourClick
            if actual ~= should and not unread and (ourClick or actual ~= "") then stale = true end
            -- (a layer's function of ours left in the gamepad set, under Base)
            local left = pad ~= nil and pad ~= should and Keys.Ours(key, pad)
            if left and settled then Found(key, pad) elseif not left then Gone(key) end
        else
            if actual ~= "" and actual ~= (seen[key] or "") and Keys.Ours(key, actual) then stale = true end
            -- (a function of ours under the game's own binding, in a record of no owner of ours)
            local left = pad ~= nil and pad ~= actual and FUNCTION[pad] == true and Keys.Ours(key, pad)
            if left and settled then
                local g = ghosts[key]
                if not g or g.tries == 0 then
                    Found(key, pad)
                elseif now - g.at >= Keys.GHOST_EVERY and not g.said then
                    g.said = true
                    Trace(("GHOST %s: %s stays in the gamepad set under the game's %s, in no record of ours"):format(
                        key, pad, actual), "errors")
                    Note(key, pad)
                end
            elseif not left then
                Gone(key)
            end
        end
    end
    if not stale then return false end
    Keys.Snapshot("heal")
    -- (every key not held: its layer owners emptied, Base uncovered; a held key keeps its
    -- binding till it is up: the game keeps the one a press ran for its release)
    local buttons = Sh.PadButtons()
    for _, key in ipairs(Keys.KEYS) do
        if not Busy(buttons, key) then Layer(key, nil, true); extras[key] = nil end
    end
    -- (a leftover still read with them off, under Base: in the record Base holds. Its command
    -- put again, on another record; that key alone)
    for key, was in pairs(tried) do
        local verb = "clear"
        if bound[key] and not Busy(buttons, key) and PadSet(key) == was then
            Put(base, key, bound[key], true)
            verb = "put again"
        end
        Trace(("GHOST %s: %s in the gamepad set; %s %d, now %s"):format(key, was, verb, ghosts[key].tries,
            tostring(PadSet(key))), "errors")
    end
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
    "UI_ERROR_MESSAGE", "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
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
    if event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        Keys.Blocked(arg, msg)
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
    if event == "PLAYER_LOGIN" and C_Timer and C_Timer.After then C_Timer.After(3, function() pcall(Keys.Probe) end) end
    -- (the stuck pad found by its mark every few seconds, out of combat: said once per addon)
    if event == "PLAYER_LOGIN" and C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(5, function() if not (InCombatLockdown and InCombatLockdown()) then pcall(Keys.PadHealth) end end)
    end
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
                -- (cleared whole: a nil left a function in the gamepad set, 2026-11-23)
                if binding ~= "" then SetOverrideBinding(unstickOwner, true, key, binding) end
                ClearOverrideBindings(unstickOwner)
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
