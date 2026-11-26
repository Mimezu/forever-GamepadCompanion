-- Button bindings: what L3, R3, Create, Options, PS and Mute run, on each
-- layer, per character.
--
-- A key with no action of ours on any layer: the game's own, untouched.
-- A key whose only action is a Blizzard gamepad function on Base (Focus UI,
-- Radial, Ping wheel): that function bound on the key itself.
-- Any other key: one secure click binding, "CLICK GamepadCompanionKeys:p<n>",
-- written in place on one owner, only when the settings change, out of
-- combat; never when L2 / R2 move. At the press the snippet reads L2 / R2
-- from GetGamePadState and picks that layer's action:
--   k<n>   a macro of ours
--   h<n>   a WoW Helper chord, held while the key is: 1 Focus UI, 2 Radial,
--          3 Ping wheel; 4-9 the key's own game command (Base empty)
--   none   nothing
-- The helper reads the hold cells (HelperLink K.Hold) and holds the chord
-- ALT-CTRL-SHIFT-<n>, bound here once: a gamepad function never goes on a pad
-- key that shares it with other actions.
local _, ns = ...
local T, Sh = ns.TouchModel, ns.Shared
local Keys = {}
ns.Keys = Keys

-- (not L1 / R1: Blizzard's target bars live on them. Saved actions on them drop at load: Normalize)
Keys.KEYS = { "PADLSTICK", "PADRSTICK", "PADSOCIAL", "PADFORWARD", "PADSYSTEM", "PAD5" }
Keys.LOCKED = { PADLSHOULDER = true, PADRSHOULDER = true }
local ALLOWED, CLICK_NAME = {}, {}
-- (click names fixed by the pad's order, so they never shift)
local ORDER = { "PADLSHOULDER", "PADRSHOULDER", "PADLSTICK", "PADRSTICK", "PADSOCIAL", "PADFORWARD", "PADSYSTEM", "PAD5" }
for _, key in ipairs(Keys.KEYS) do ALLOWED[key] = true end
for i, key in ipairs(ORDER) do CLICK_NAME[key] = "p" .. i end
local KEY_OF = {}         -- click name -> pad key
for key, name in pairs(CLICK_NAME) do KEY_OF[name] = key end
Keys.BUTTON = "GamepadCompanionKeys"

-- WoW Helper's chords: Keys.CHORD .. n. 1-3 the gamepad functions, bound once;
-- 4-9 the keys' own game commands, as needed
Keys.CHORD = "ALT-CTRL-SHIFT-"   -- (WoW names chords Alt, Ctrl, Shift in that order)
Keys.HELPER = { TOGGLEUIFOCUS = 1, OPENRADIAL = 2, TOGGLEPINGSYSTEM = 3 }
Keys.GAME_CHORDS = { 4, 5, 6, 7, 8, 9 }

local settings = {}
local bound = {}          -- key -> "click" | a function | nil: what is on it now
local onOwner = { click = {}, native = {} }   -- key -> held there (native: its function)
local basePick = {}       -- key -> its click's Base pick, last Apply
local gameChord = {}      -- 4..9 -> the command bound on that chord
local claimed = {}        -- key -> what it runs, for keys of ours (Sh.Claim)
local used = 0            -- macro attributes set last time
local pending, loaded, helperBound = false, false, false
local holding             -- the click name whose press holds a chord
local listeners = {}

--[[ The secure click (pre-body: self, button, down). button is the key's
click name ("p6"); attributes, set out of combat:
  gpc-lt / gpc-rt     the triggers' indexes in GetGamePadState().buttons
  gpc-<p>-<layer>     that key and layer's pick ("k3", "h1"), or "none"
The pick is read at the press and kept for its release, so the action runs on
the half the game's key-down setting says, with the layer of the press.
gpc-down / gpc-up: the key of the last press / release, for PostClick. ]]
Keys.SNIPPET = [[
    local pick = "gpc-pick-" .. button
    if not down then
        self:SetAttribute("gpc-up", button)
        local id = self:GetAttribute(pick)
        self:SetAttribute(pick, nil)
        return id or false
    end
    self:SetAttribute("gpc-down", button)
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
-- A chord pick held: the hold cells say n from the press to that key's release
-- (two keys: the last press wins, its release lets go). While held, the pad
-- itself is read every HOLD_POLL s: a release a window ate lets go too
Keys.HOLD_POLL = 0.05
local watch = CreateFrame("Frame", "GamepadCompanionKeyHold")
local function Release()
    if not holding then return end
    holding = nil
    watch:SetScript("OnUpdate", nil)
    local K = ns.HelperLink
    if K and K.Hold then K.Hold(0) end
end
Keys.Release = Release
local since = 0
local function Watch(_, elapsed)
    since = since + (elapsed or 0)
    if since < Keys.HOLD_POLL then return end
    since = 0
    if holding and Sh.PadDown(Sh.PadButtons(), KEY_OF[holding]) == false then Release() end
end
button:HookScript("PostClick", function(self, _, down)
    if down then
        local name = self:GetAttribute("gpc-down")
        local pick = name and self:GetAttribute("gpc-pick-" .. name)
        local n = type(pick) == "string" and tonumber(pick:match("^h(%d)$"))
        if n then
            holding, since = name, 0
            watch:SetScript("OnUpdate", Watch)
            local K = ns.HelperLink
            if K and K.Hold then K.Hold(n) end
        end
    elseif holding and self:GetAttribute("gpc-up") == holding then
        Release()
    end
end)

local clickOwner = CreateFrame("Frame", "GamepadCompanionKeyBinds")
local nativeOwner = CreateFrame("Frame", "GamepadCompanionKeyNative")
local helperOwner = CreateFrame("Frame", "GamepadCompanionHelperChords")
local gameOwner = CreateFrame("Frame", "GamepadCompanionGameChords")

-- The helper's chords 1-3, once (out of combat)
function Keys.BindHelperChords()
    if helperBound or (InCombatLockdown and InCombatLockdown()) then return helperBound end
    for fn, n in pairs(Keys.HELPER) do SetOverrideBinding(helperOwner, true, Keys.CHORD .. n, fn) end
    helperBound = true
    return true
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

-- How a key is bound: "click" (our secure button, every layer), "binding",
-- function (only a Blizzard function, on Base), or nil (the game's)
function Keys.Mode(key)
    local base = Keys.Get(key, "base")
    local layers = HasLayer(key)
    if not base and not layers then return nil end
    local binding = T.BindingOf(base)
    if binding and not layers then return "binding", binding end
    return "click"
end

-- Does the key's action on a layer run; and a note, a few words, when not
-- (no action: a note only when Base's game command needs WoW Helper)
local function HelperOn()
    local K = ns.HelperLink
    return K and K.HoldCellsOn and K.HoldCellsOn() or false
end
function Keys.Runs(key, layer)
    local action = Keys.Get(key, layer)
    if not action then
        if layer == "base" and bound[key] == "click" and (basePick[key] or ""):find("^h") and not HelperOn() then
            return false, "needs WoW Helper"
        end
        return false
    end
    if T.BindingOf(action) and bound[key] == "click" and not HelperOn() then return false, "needs WoW Helper" end
    return true
end

local function ClickCommand(key) return "CLICK " .. Keys.BUTTON .. ":" .. CLICK_NAME[key] end

-- What the game runs on key without us ("" none): its own keybinding, never an
-- override (a window's or ours); a gamepad function reads back empty, found by
-- its keys; else Blizzard's core set's default
local FUNCTIONS = { "TOGGLEUIFOCUS", "OPENRADIAL", "TOGGLEPINGSYSTEM", "TOGGLEGAMEMENU" }
local CORE = { PADFORWARD = "TOGGLEGAMEMENU", PADLSTICK = "TOGGLEAUTORUN", PADRSTICK = "TOGGLEPINGSYSTEM" }
local function GameCommand(key)
    local now = GetBindingAction and GetBindingAction(key) or ""
    if now == "" and GetBindingKey then
        for _, fn in ipairs(FUNCTIONS) do
            for _, k in ipairs({ GetBindingKey(fn) }) do if k == key then now = fn end end
            if now ~= "" then break end
        end
    end
    if now == "" then now = CORE[key] or "" end
    if now:find("^CLICK " .. Keys.BUTTON .. ":") then now = "" end
    return now
end

-- Chords 4-9 for these commands: a chord keeps its command while needed; one
-- no longer needed is written over in place
local function AssignChords(needed)
    local keep = {}
    for _, c in ipairs(needed) do keep[c] = true end
    for _, c in ipairs(needed) do
        local have
        for _, n in ipairs(Keys.GAME_CHORDS) do if gameChord[n] == c then have = n end end
        if not have then
            for _, n in ipairs(Keys.GAME_CHORDS) do
                if not gameChord[n] or not keep[gameChord[n]] then have = n; break end
            end
            if have then
                gameChord[have] = c
                SetOverrideBinding(gameOwner, true, Keys.CHORD .. have, c)
            end
        end
    end
end
-- A command's chord pick ("h2", "h5"), or nil
local function ChordPick(command)
    if not command or command == "" then return nil end
    if Keys.HELPER[command] then return "h" .. Keys.HELPER[command] end
    for _, n in ipairs(Keys.GAME_CHORDS) do if gameChord[n] == command then return "h" .. n end end
end

-- One owner's binding on key: in place when it holds one (newest on the key)
local function Write(kind, key, command)
    if kind == "click" then
        SetOverrideBindingClick(clickOwner, true, key, Keys.BUTTON, CLICK_NAME[key])
        onOwner.click[key] = true
    else
        SetOverrideBinding(nativeOwner, true, key, command)
        onOwner.native[key] = command
    end
end
-- key to run want ("click", a function, nil). A record that carried a function
-- is never let go (the game would hand the function to the next binding of the
-- key, anyone's): a click goes on a newer record above it, and a key given back
-- stays our click (Apply: its game command through a chord) till /reload
local function Put(key, want)
    if want == bound[key] then return end
    if want == "click" then
        Write("click", key)
    elseif want then
        Write("native", key, want)
    elseif onOwner.click[key] then
        SetOverrideBinding(clickOwner, true, key, nil)
        onOwner.click[key] = nil
    end
    bound[key] = want
end

-- Every key's attributes and binding, from the settings (out of combat)
function Keys.Apply()
    if InCombatLockdown and InCombatLockdown() then pending = true; return false end
    pending = false
    Keys.BindHelperChords()
    button:SetAttribute("gpc-lt", PadIndex("PADLTRIGGER"))
    button:SetAttribute("gpc-rt", PadIndex("PADRTRIGGER"))
    local want, game, needed, listed = {}, {}, {}, {}
    for _, key in ipairs(Keys.KEYS) do
        game[key] = GameCommand(key)
        local mode, fn = Keys.Mode(key)
        -- (given back after a function: our click still, Base the game's command)
        if not mode and onOwner.native[key] then mode = "click" end
        want[key] = mode == "click" and "click" or fn
        -- (Base empty on a click: the game's own command through a chord)
        local c = game[key]
        if mode == "click" and not Keys.Get(key, "base") and c ~= "" and not Keys.HELPER[c] and not listed[c] then
            listed[c] = true
            needed[#needed + 1] = c
        end
    end
    AssignChords(needed)
    local n = 0
    for _, key in ipairs(Keys.KEYS) do
        local name = CLICK_NAME[key]
        for _, layer in ipairs(Sh.LAYERS) do
            local id
            local action = Keys.Get(key, layer)
            if want[key] == "click" then
                local binding = T.BindingOf(action)
                if binding then
                    id = ChordPick(binding) or "none"
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
                elseif layer == "base" then
                    id = ChordPick(game[key]) or "none"
                elseif not Keys.Mode(key) then
                    id = "none"
                end
            end
            if layer == "base" then basePick[key] = id end
            button:SetAttribute("gpc-" .. name .. "-" .. layer, id)
        end
    end
    for i = n + 1, used do
        button:SetAttribute("*type-k" .. i, nil)
        button:SetAttribute("*macrotext-k" .. i, nil)
    end
    used = n
    wipe(claimed)
    for _, key in ipairs(Keys.KEYS) do
        Put(key, want[key])
        if want[key] then claimed[key] = want[key] == "click" and ClickCommand(key) or want[key] end
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
    Notify()
    return true
end

-- (a key of ours covered by Blizzard's binding (its core set again after a
-- window, a window's footer): ours written again in place, back on top)
Sh.Claim(claimed, function()
    if InCombatLockdown and InCombatLockdown() then pending = true; return end
    for key, command in pairs(claimed) do
        local actual = GetBindingAction(key, true) or ""
        -- (a Blizzard function reads back empty: only another command over it is a cover)
        if actual ~= command and (bound[key] == "click" or actual ~= "") then
            Write(bound[key] == "click" and "click" or "native", key, bound[key])
        end
    end
end)

-- A trace kept in the saved settings (read after a /reload), a list per
-- topic (PadRescue's "errors"), 200 lines each
local function Trace(line, list)
    if type(GamepadCompanionTraceDB) ~= "table" then GamepadCompanionTraceDB = {} end
    list = list or "errors"
    local t = GamepadCompanionTraceDB[list]
    if type(t) ~= "table" then t = {}; GamepadCompanionTraceDB[list] = t end
    t[#t + 1] = ("%.2f %s"):format(GetTime and GetTime() or 0, line)
    while #t > 200 do table.remove(t, 1) end
end
function Keys.Trace(line, list) return Trace(line, list) end

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
-- "name=addon" for each tainted slot among the hand-back's, then how many are clean. into
-- (optional): each tainted slot put there, label -> addon, an active binding by its own key
-- ("binding PADLTRIGGER"): PadRescue's first-taint catcher compares two of them
function Keys.PadSlots(into)
    if type(issecurevariable) ~= "function" then return "no issecurevariable" end
    local tainted, clean = {}, 0
    local function Add(label, t, key)
        if type(t) ~= "table" then return end
        local ok, who = issecurevariable(t, key)
        if ok then clean = clean + 1 else
            tainted[#tainted + 1] = ("%s=%s"):format(label, tostring(who or "?"))
            if into then into[label] = tostring(who or "?") end
        end
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
                if not ok then
                    n = n + 1; first = first or ("%s=%s"):format(tostring(key), tostring(who or "?"))
                    if into then into["binding " .. tostring(key)] = tostring(who or "?") end
                else clean = clean + 1 end
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
    -- (the way out: PadRescue's line, Cross held reloads)
    if ns.PadRescue and ns.PadRescue.Stuck then ns.PadRescue.Stuck(addon) end
    if stuckSaid[addon] then return end
    stuckSaid[addon] = true
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(("Pad stuck by %s · hold Cross to reload"):format(tostring(addon)), 1, 0.82, 0, 1, 6)
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

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "UPDATE_MACROS", "SPELLS_CHANGED", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED",
    "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg, msg)
    if event == "ADDON_LOADED" then
        if arg ~= "GamepadCompanion" then return end
        local char = Sh.CharDB()
        settings = Keys.Normalize(char.keys)
        char.keys = settings
        loaded = true
        return
    end
    if not loaded then return end
    if event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        Keys.Blocked(arg, msg)
        return
    end
    if event == "GAME_PAD_ACTIVE_CHANGED" or event == "GAME_PAD_CONNECTED" then
        -- (another pad: the triggers' indexes again; the bindings stay)
        if Sh.ForgetPadIndexes then Sh.ForgetPadIndexes() end
        Release()
        if InCombatLockdown and InCombatLockdown() then pending = true; return end
        button:SetAttribute("gpc-lt", PadIndex("PADLTRIGGER"))
        button:SetAttribute("gpc-rt", PadIndex("PADRTRIGGER"))
        return
    end
    -- (the stuck pad found by its mark every few seconds, out of combat: said once per addon)
    if event == "PLAYER_LOGIN" and C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(5, function() if not (InCombatLockdown and InCombatLockdown()) then pcall(Keys.PadHealth) end end)
    end
    if event == "PLAYER_ENTERING_WORLD" then Release() end
    if event == "PLAYER_REGEN_ENABLED" then
        Keys.BindHelperChords()
        if not pending then return end
    end
    Keys.Apply()
end)
