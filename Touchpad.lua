-- Touchpad zones (PlayStation controllers). Clicking the touchpad runs what
-- the zone under the finger holds: a game window, a spell, an item or a macro,
-- with layers for L2, R2 and both, like the crossbar. The click is a real
-- button press, so the zone's macro runs untainted, in combat too.
--
-- Two modes share the pad with Blizzard's own touchpad function, the focus
-- toggle (an open window takes the pad, or gives it back to the world):
--   chord (B)  the whole pad is zones while the world has the pad, even with
--              windows open; a focused window gets the plain click back.
--              L1 + touchpad runs Blizzard's function, always, in combat too.
--   split (A)  a gamepad config makes the right half its own button (PAD6),
--              all zones; the left half stays Blizzard's, untouched.
-- Pure logic: TouchModel.lua. Off by default: `/gpc touch on`.
local _, ns = ...
local T = ns.TouchModel
local API = GamepadCompanionAPI

local Touch = {}
ns.Touch = Touch
API.Touch = Touch

local settings = T.Normalize()
local loaded = false
local pending = false        -- a change waiting for the end of combat
local boundKeys = {}         -- key -> the action we bound it to
local lastOurs = nil         -- chord mode: was the plain click ours at the last apply
local note = nil             -- why something isn't bound (status)
local debug = false

local function Say(message) print("|cff80c0ffGamepad Companion:|r " .. message) end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

local function GetCVarSafe(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, value = pcall(getter, name)
    return ok and value or nil
end

local function SetCVarSafe(name, value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    return pcall(setter, name, value)
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
local function MappedState()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return nil end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState, C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID() or nil)
    return ok and type(state) == "table" and state or nil
end

local function PadStyle()
    local state = MappedState()
    return state and state.labelStyle
end

-- The controller's vendor and product IDs. This client hides the raw state
-- from addons, so a PlayStation pad without them is taken as a DualSense
-- (the pad whose touchpad buttons Companion knows).
local DUALSENSE = { vendorID = 1356, productID = 3302 }
local function DeviceID()
    if C_GamePad and C_GamePad.GetDeviceRawState and C_GamePad.GetActiveDeviceID then
        local ok, raw = pcall(C_GamePad.GetDeviceRawState, C_GamePad.GetActiveDeviceID())
        if ok and type(raw) == "table" and raw.vendorID then
            return { vendorID = raw.vendorID, productID = raw.productID }
        end
    end
    if PadStyle() == "Shapes" then return { vendorID = DUALSENSE.vendorID, productID = DUALSENSE.productID } end
end

-- A button's index in GetGamePadState().buttons (1-based)
local function PadIndex(binding)
    local index = C_GamePad and C_GamePad.ButtonBindingToIndex and C_GamePad.ButtonBindingToIndex(binding)
    return index and index + 1 or nil
end

local function Finger()
    local state = MappedState()
    local stick = state and state.sticks and state.sticks[T.PAD_STICK]
    if stick then return stick.x or 0, stick.y or 0, stick.len or 0 end
end

local function TriggersHeld()
    local state = MappedState()
    local pad = state and state.buttons
    local lt, rt = PadIndex("PADLTRIGGER"), PadIndex("PADRTRIGGER")
    return pad and lt and pad[lt] and true or false, pad and rt and pad[rt] and true or false
end

---------------------------------------------------------------------------
-- Who has the plain click (chord mode). Read only: never a call that changes
-- Blizzard's gamepad state, never a callback in its lists.
---------------------------------------------------------------------------
local function GamepadUI()
    if not (InputUtil and InputUtil.IsGamepadUIEnabled) then return false end
    local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
    return ok and on == true
end

local function CoreOnly()
    local shared = GamepadSharedUtility
    local manager = shared and (shared.InputBindingManager or (shared.BindingStack and shared.BindingStack.InputBindingManager))
    if not (manager and manager.IsOnlyCoreBindingSetActive) then return nil end
    local ok, only = pcall(manager.IsOnlyCoreBindingSetActive, manager)
    if ok and type(only) == "boolean" then return only end
end

local function UIFocused()
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    return manager ~= nil and manager.isUIFocused == true
end

local function WindowsShown()
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if not (manager and manager.GetShownFrameCount) then return 0 end
    local ok, count = pcall(manager.GetShownFrameCount, manager)
    return ok and tonumber(count) or 0
end

-- The plain click is zones: no gamepad panel (radial, HUD mode, bar editing)
-- on the binding stack, and no window focused. Over windows (default): an
-- open window keeps the zones too (its own binding set doesn't count), so a
-- zone opens, closes or swaps windows; L1 + touchpad still focuses.
function Touch.WorldHasPad()
    if not GamepadUI() then return true end
    if settings.overWindows and WindowsShown() > 0 then return true end
    return CoreOnly() ~= false and not UIFocused()
end

-- Improved Forever's touchpad corners are on (both would bind PADBACK)
function Touch.Conflict()
    local IF = _G.ImprovedForever
    if type(IF) ~= "table" or not IF.Touch or type(IF.db) ~= "table" then return false end
    if IF.db.padOverrides == false then return false end
    return not (type(IF.db.touch) == "table" and IF.db.touch.enabled == false)
end

local function Emulate()
    local out = {}
    for mod, cvar in pairs(T.EMULATE_CVARS) do out[mod] = GetCVarSafe(cvar) end
    return out
end

---------------------------------------------------------------------------
-- Split mode: the right half on PAD6 (a gamepad config for this controller)
---------------------------------------------------------------------------
local function GetConfig(id)
    if not (C_GamePad and C_GamePad.GetConfig) then return nil end
    local ok, config = pcall(C_GamePad.GetConfig, id)
    return ok and type(config) == "table" and config or nil
end

local function ApplyConfigs()
    if C_GamePad and C_GamePad.ApplyConfigs then pcall(C_GamePad.ApplyConfigs) end
end

-- The controller config Companion needs: "split" (the right half on PAD6)
-- or "click" (the physical click on PAD6). true when in place.
local CONFIGS = {
    split = { make = function(c) return T.SplitConfig(c) end, is = function(c) return T.IsSplit(c) end },
    click = { make = function(c) return T.ClickConfig(c) end, is = function(c) return T.IsClickMoved(c) end },
}
local function EnsureConfig(kind)
    local id = DeviceID()
    if not id then return false, "no controller" end
    local want, other = CONFIGS[kind], CONFIGS[kind == "split" and "click" or "split"]
    local current = GetConfig(id)
    if want.is(current) and not other.is(current) then return true end
    -- (ours already, of the other kind: start again from what was there before)
    local ours = settings.split and settings.split.device
    local before = ours and settings.split.backup or current
    local base = before
    if not base and id.vendorID == 1356 and id.productID == 3302 then base = T.DualSenseDefault() end
    if base and other.is(base) then base = T.DualSenseDefault() end
    local config = want.make(base)
    if not config then return false, "touchpad buttons unknown" end
    config.configID = id
    if not (C_GamePad and C_GamePad.SetConfig) then return false, "no gamepad config API" end
    -- (kept to put back: a config of the player's own, or the default the game gave)
    if not ours then settings.split = { device = id, backup = current and T.Copy(current) or nil } end
    local ok, err = pcall(C_GamePad.SetConfig, config)
    if not ok then return false, "config refused: " .. tostring(err) end
    ApplyConfigs()
    if not want.is(GetConfig(id)) then return false, "config not kept" end
    return true
end

-- Touch or click probe (12 s): which buttons a light tap and a full click
-- press. Tap to click is on meanwhile, and the touchpad's physical click
-- (raw button 20, unbound by default) is moved to PAD6, so the game itself
-- tells them apart if it can. Prints each change; everything is put back.
local rawProbing = false
function Touch.RawProbe()
    if rawProbing then return end
    if settings.enabled and settings.mode == "split" then return Say("Not in Right half mode") end
    if InCombat() then return Say("Not in combat") end
    rawProbing = true
    local function P(text) print("|cff80c0ffGamepad Companion:|r " .. text) end
    -- What the raw state looks like here
    local okRaw, raw = false, nil
    if C_GamePad and C_GamePad.GetDeviceRawState and C_GamePad.GetActiveDeviceID then
        okRaw, raw = pcall(C_GamePad.GetDeviceRawState, C_GamePad.GetActiveDeviceID())
    end
    P(("raw state: %s, %s buttons"):format(okRaw and type(raw) or "error",
        tostring(type(raw) == "table" and (raw.rawButtonCount or (raw.rawButtons and #raw.rawButtons)) or "-")))
    -- Click on PAD6 for the probe
    local id = DeviceID() or { vendorID = 1356, productID = 3302 }
    local before = GetConfig(id)
    local base = before or T.DualSenseDefault()
    local config = T.Copy(base)
    config.configID = id
    local moved = false
    for _, m in ipairs(config.rawButtonMappings or {}) do
        if m.rawIndex == 20 then m.button = T.SPLIT_KEY; moved = true end
    end
    if moved and C_GamePad and C_GamePad.SetConfig then
        moved = pcall(C_GamePad.SetConfig, config)
        ApplyConfigs()
    end
    P("click on PAD6: " .. (moved and "yes" or "no"))
    local tapCVar, oldTap = "GamePadTouchTapButtons", GetCVarSafe("GamePadTouchTapButtons")
    if oldTap ~= nil then SetCVarSafe(tapCVar, "1") end
    P("12 s: tap 3 times, then click 3 times")
    local watch = { PADBACK = PadIndex("PADBACK"), PAD6 = PadIndex("PAD6") }
    local last, lastRaw, f, left = {}, {}, CreateFrame("Frame"), 12
    f:SetScript("OnUpdate", function(self, elapsed)
        left = left - elapsed
        local t = 12 - left
        local state = MappedState()
        local buttons = state and state.buttons
        for name, index in pairs(watch) do
            local pressed = buttons and buttons[index] and true or false
            if last[name] ~= nil and last[name] ~= pressed then
                P(("%s %s (%.2f s)"):format(name, pressed and "down" or "up", t))
            end
            last[name] = pressed
        end
        local ok, r = pcall(C_GamePad.GetDeviceRawState, C_GamePad.GetActiveDeviceID())
        local rb = ok and type(r) == "table" and r.rawButtons
        if type(rb) == "table" then
            for i = 20, 23 do
                local pressed = rb[i] and true or false
                if lastRaw[i] ~= nil and lastRaw[i] ~= pressed then
                    P(("raw %d %s (%.2f s)"):format(i - 1, pressed and "down" or "up", t))
                end
                lastRaw[i] = pressed
            end
        end
        if left > 0 then return end
        self:SetScript("OnUpdate", nil)
        if oldTap ~= nil then SetCVarSafe(tapCVar, oldTap) end
        if moved and C_GamePad then
            if before then pcall(C_GamePad.SetConfig, before)
            elseif C_GamePad.DeleteConfig then pcall(C_GamePad.DeleteConfig, id) end
            ApplyConfigs()
        end
        rawProbing = false
        P("probe done, config back")
        Touch.Apply()
    end)
end

-- The controller's config as it was before split mode
function Touch.RestoreSplit()
    local saved = settings.split
    local id = saved and saved.device
    if not id then return false end
    if C_GamePad and C_GamePad.DeleteConfig then pcall(C_GamePad.DeleteConfig, id) end
    ApplyConfigs()
    -- (a config the player had of their own, unlike what the game falls back to: back as it was)
    local backup = saved.backup
    if backup and not T.IsSplit(backup) and not T.IsClickMoved(backup) and T.Signature(GetConfig(id)) ~= T.Signature(backup)
        and C_GamePad.SetConfig then
        pcall(C_GamePad.SetConfig, backup)
        ApplyConfigs()
    end
    settings.split = {}
    return true
end

---------------------------------------------------------------------------
-- The secure click
---------------------------------------------------------------------------
local click = CreateFrame("Button", "GamepadCompanionTouchClick", UIParent,
    "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
click:SetSize(1, 1)
click:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
click:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(click, "OnClick", click, T.SNIPPET)

-- The bindings' owner (cleared and set again as a whole)
local binds = CreateFrame("Frame", "GamepadCompanionTouchBinds")

local lastClick = { at = -math.huge }
-- Debug: the finger every frame, to compare with what a press read
local track = { x = nil, y = nil, len = nil, movedAt = 0, prevX = nil, prevY = nil }
local tracker = CreateFrame("Frame")
local keptX, keptY
tracker:SetScript("OnUpdate", function()
    local x, y, len = Finger()
    if not x then return end
    -- The finger's spot for taps (they arrive after it left the pad), kept
    -- on the secure button while out of combat
    if settings.enabled and settings.input ~= "click" and (x ~= 0 or y ~= 0 or (len or 0) > 0)
        and (x ~= keptX or y ~= keptY) and not InCombat() then
        keptX, keptY = x, y
        click:SetAttribute("gpc-lx", x)
        click:SetAttribute("gpc-ly", y)
    end
    if not debug then return end
    if x ~= track.x or y ~= track.y then
        track.prevX, track.prevY = track.x, track.y
        track.movedAt = GetTime()
    end
    track.x, track.y, track.len = x, y, len
end)

click:SetScript("PostClick", function(self, _, down)
    local onDown = self:GetAttribute("useOnKeyDown")
    local acts = (down and onDown ~= false) or (not down and onDown == false)
    local zone, layer = self:GetAttribute("gpc-zone"), self:GetAttribute("gpc-layer")
    if debug then
        local ran = acts and self:GetAttribute("type") == "macro"
            and (tostring(self:GetAttribute("macrotext")):gsub("\n", " | "))
        Say(("%s %s: %s, %s -> %s"):format(tostring(self:GetAttribute("gpc-input") or "touch"), down and "down" or "up",
            tostring(zone and T.ZoneLabel(zone, T.Grid(settings, settings.mode)) or "-"),
            tostring(layer and T.LAYER_LABELS[layer] or "-"), ran or "nothing"))
        if not down then
            local tx, ty = tonumber(self:GetAttribute("gpc-tx")), tonumber(self:GetAttribute("gpc-ty"))
            Say(("  press %s, touch path %s · read %.2f, %.2f · finger now %.2f, %.2f (len %.2f) · moved %.2f s ago from %s"):format(
                tostring(settings.input), self:GetAttribute("gpc-dual") == 1 and "on" or "off",
                tx or 0, ty or 0, track.x or 0, track.y or 0, track.len or 0, GetTime() - track.movedAt,
                track.prevX and ("%.2f, %.2f"):format(track.prevX, track.prevY) or "-"))
        end
    end
    if not acts then return end
    lastClick = { at = GetTime(), zone = zone, layer = layer }
end)

local lookup = {
    button = function(name) local b = _G[name]; return type(b) == "table" and b.Click ~= nil end,
    spellName = function(id)
        if not id then return nil end
        if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
        return GetSpellInfo and (GetSpellInfo(id))
    end,
    macroBody = function(name)
        if not GetMacroInfo then return nil end
        local _, _, body = GetMacroInfo(name)
        return body
    end,
}

-- The finger slides the mouse cursor (the game's touch cursor) and shows it:
-- off while Companion has the pad, the player's own setting back after
local CURSOR_CVAR = "GamePadTouchCursorEnable"
local function BlockTouchCursor(block)
    local current = GetCVarSafe(CURSOR_CVAR)
    if current == nil then return end
    if block then
        if current ~= "0" then
            settings.touchCursor = current
            SetCVarSafe(CURSOR_CVAR, "0")
        end
    elseif settings.touchCursor ~= nil then
        local saved = settings.touchCursor
        settings.touchCursor = nil
        if current ~= saved then SetCVarSafe(CURSOR_CVAR, saved) end
    end
end

-- Tap to click: a light touch presses the pad (GamePadTouchTapButtons), on
-- while Companion has the pad, the player's own setting back after
local TAP_CVAR = "GamePadTouchTapButtons"
local TAP_MS_CVAR = "GamePadTouchTapMaxMs"
local function TapTime(on)
    local current = GetCVarSafe(TAP_MS_CVAR)
    if current == nil then return end
    if on then
        if settings.tapMsSaved == nil then settings.tapMsSaved = current end
        local want = tostring(settings.tapMs)
        if current ~= want then SetCVarSafe(TAP_MS_CVAR, want) end
    elseif settings.tapMsSaved ~= nil then
        local saved = settings.tapMsSaved
        settings.tapMsSaved = nil
        if current ~= saved then SetCVarSafe(TAP_MS_CVAR, saved) end
    end
end
local function TapToClick(on)
    TapTime(on)
    local current = GetCVarSafe(TAP_CVAR)
    if current == nil then return end
    if on then
        if settings.tapSaved == nil then settings.tapSaved = current end
        if current ~= "1" then SetCVarSafe(TAP_CVAR, "1") end
    elseif settings.tapSaved ~= nil then
        local saved = settings.tapSaved
        settings.tapSaved = nil
        if current ~= saved then SetCVarSafe(TAP_CVAR, saved) end
    end
end

-- The macro an action runs now, or nil (a window with no button in this client)
function Touch.Runs(action)
    return T.MacroText(action, lookup)
end

local function Env()
    return {
        padStyle = PadStyle(),
        ours = Touch.WorldHasPad(),
        conflict = Touch.Conflict(),
        emulate = Emulate(),
        splitReady = false,
    }
end

function Touch.Apply()
    if not loaded then return end
    if InCombat() then pending = true; return end
    pending = false
    -- A press whose release went to another binding (a window took the pad
    -- between the two) must not block the next one
    click:SetAttribute("gpc-held", nil)
    click:SetAttribute("gpc-zone", nil)
    click:SetAttribute("gpc-layer", nil)
    -- Attributes: this mode's zones, everything else cleared
    click:SetAttribute("gpc-mode", settings.mode)
    click:SetAttribute("gpc-stick", T.PAD_STICK)
    click:SetAttribute("gpc-lt", PadIndex("PADLTRIGGER"))
    click:SetAttribute("gpc-rt", PadIndex("PADRTRIGGER"))
    click:SetAttribute("gpc-swiped", nil)
    click:SetAttribute("gpc-t-held", nil)
    click:SetAttribute("gpc-t-click", nil)
    click:SetAttribute("gpc-c-echo", nil)
    local grid = T.Grid(settings, settings.mode)
    click:SetAttribute("gpc-cols", grid.cols)
    click:SetAttribute("gpc-rows", grid.rows)
    click:SetAttribute("gpc-swipe", T.HasSwipes(settings, settings.mode) and 1 or 0)
    click:SetAttribute("gpc-swipe-min", T.SWIPE_MIN)
    local inUse = {}
    for _, zone in ipairs(T.Zones(settings)) do inUse[zone] = true end
    for _, zone in ipairs(T.GESTURES) do inUse[zone] = true end
    local every = {}
    for _, zones in pairs(T.ALL_ZONES) do for _, zone in ipairs(zones) do every[zone] = true end end
    for _, zone in ipairs(T.GESTURES) do every[zone] = true end
    for _, layer in ipairs(T.LAYERS) do
        for zone in pairs(every) do
            local macro = settings.enabled and inUse[zone]
                and T.MacroText(settings.actions[settings.mode][layer][zone], lookup) or nil
            click:SetAttribute("gpc-m-" .. layer .. "-" .. zone, macro)
        end
    end
    -- The controller config: right half or click on PAD6
    local env = Env()
    local splitNote
    local kind = settings.enabled and env.padStyle == "Shapes"
        and (settings.mode == "split" and "split" or (settings.input == "dual" and "click")) or nil
    if kind then
        local ready
        ready, splitNote = EnsureConfig(kind)
        if kind == "split" then env.splitReady = ready else env.clickReady = ready end
    elseif settings.split and settings.split.device then
        Touch.RestoreSplit()
    end
    local dual = settings.mode == "chord" and settings.input == "dual" and env.clickReady == true
    click:SetAttribute("gpc-dual", dual and 1 or 0)
    click:SetAttribute("gpc-click-key", PadIndex(T.SPLIT_KEY))
    click:SetAttribute("gpc-key", PadIndex((settings.mode == "split" or dual) and T.SPLIT_KEY or T.PAD_KEY))
    for _, layer in ipairs(T.LAYERS) do
        for _, zone in ipairs(T.ALL_ZONES.chord) do
            local macro = dual and settings.enabled and inUse[zone]
                and T.MacroText(settings.touchActions[layer][zone], lookup) or nil
            click:SetAttribute("gpc-t-" .. layer .. "-" .. zone, macro)
        end
    end
    -- The bindings
    local plan, planNote = T.BindingPlan(settings, env)
    ClearOverrideBindings(binds)
    wipe(boundKeys)
    for _, entry in ipairs(plan) do
        if entry.click then
            local mouse = entry.mouse or "LeftButton"
            SetOverrideBindingClick(binds, true, entry.key, click:GetName(), mouse)
            boundKeys[entry.key] = "CLICK " .. click:GetName() .. ":" .. mouse
        else
            SetOverrideBinding(binds, true, entry.key, entry.action)
            boundKeys[entry.key] = entry.action
        end
    end
    lastOurs = env.ours
    note = splitNote or planNote
    BlockTouchCursor(#plan > 0)
    TapToClick(#plan > 0 and settings.input ~= "click")
end

function Touch.BindsKeys() return next(boundKeys) ~= nil end

-- Blizzard's core set binds the touchpad (TOGGLEUIFOCUS) again at login and
-- whenever one of its panels closes; the most recent priority binding wins.
-- Put ours back on top when it really took one (Halo 0.9.8's fix).
local reassertQueued = false
local function Reassert()
    reassertQueued = false
    if InCombat() then pending = true; return end
    for key, action in pairs(boundKeys) do
        if GetBindingAction and GetBindingAction(key, true) ~= action then
            Touch.Apply()
            if debug then Say("touch: Blizzard took " .. key .. "; put back") end
            return
        end
    end
end
-- (windows bind the touchpad with SetOverrideBindingClick: search boxes, map focus)
local function Taken(owner, _, key)
    if owner ~= UIParent or not boundKeys[key] or reassertQueued then return end
    reassertQueued = true
    C_Timer.After(0, Reassert)
end
hooksecurefunc("SetOverrideBinding", Taken)
hooksecurefunc("SetOverrideBindingClick", Taken)

---------------------------------------------------------------------------
-- The preview: a small drawing of the pad while the finger is on it, with
-- each zone's action and the zone under the finger lit. Display only.
---------------------------------------------------------------------------
local preview
local PAD_W, PAD_H = 240, 100

local function ActionLook(action)
    if action == nil or action == "none" then return nil end
    local kind, value = action:match("^(%a+):(.+)$")
    if kind == "window" then
        local w = T.WINDOW_BY_KEY[value]
        if not w then return value end
        local atlas = w.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(w.atlas) and w.atlas
        return w.label, atlas or w.icon, atlas ~= nil and atlas ~= false
    elseif kind == "spell" then
        local id = tonumber(value)
        local name = lookup.spellName(id)
        local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
            or (GetSpellTexture and GetSpellTexture(id))
        return name or action, icon
    elseif kind == "item" then
        local id = tonumber(value)
        local name = GetItemInfo and GetItemInfo(id)
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
        return name or action, icon
    elseif kind == "macro" then
        local name, icon = GetMacroInfo(value)
        return name or value, icon
    elseif kind == "text" then
        local first = value:match("^[^\n]*") or value
        return #first > 24 and (first:sub(1, 23) .. "…") or first, "Interface\\Icons\\INV_Misc_Note_01"
    end
    return action
end
Touch.ActionLook = ActionLook

local function Cell(parent)
    local c = CreateFrame("Frame", nil, parent)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(22, 22)
    c.icon:SetPoint("TOP", 0, -4)
    -- (dual input: the Touch action, small, over the Click one's corner)
    c.touch = c:CreateTexture(nil, "OVERLAY")
    c.touch:SetSize(13, 13)
    c.touch:SetPoint("CENTER", c.icon, "TOPRIGHT", 1, -1)
    c.touch:Hide()
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.label:SetPoint("BOTTOMLEFT", 2, 3)
    c.label:SetPoint("BOTTOMRIGHT", -2, 3)
    c.label:SetJustifyH("CENTER")
    c.label:SetWordWrap(false)
    return c
end

local function BuildPreview()
    local f = CreateFrame("Frame", "GamepadCompanionTouchPreview", UIParent)
    f:SetSize(PAD_W + 12, PAD_H + 34)
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 250)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(false)
    f:Hide()
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.55)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOP", 0, -5)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOM", 0, 4)
    f.cells = {}
    f.native = Cell(f)
    f.native.label:SetText("Blizzard")
    f.dot = f:CreateTexture(nil, "OVERLAY")
    f.dot:SetSize(8, 8)
    f.dot:SetColorTexture(1, 0.82, 0.2, 0.95)
    return f
end

local function LayoutPreview(layer)
    local f = preview
    local mode = settings.mode
    local zones = T.Zones(settings)
    local grid = T.Grid(settings, mode)
    local left, top = 6, -20
    local native = f.native
    native:Hide()
    for _, c in pairs(f.cells) do c:Hide() end
    f.zones = {}
    local function Place(c, col, row, cols, rows, x0, w)
        local cw, ch = w / cols, PAD_H / rows
        c:ClearAllPoints()
        c:SetSize(cw - 2, ch - 2)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + (col - 1) * cw + 1, top - (row - 1) * ch - 1)
        c:Show()
    end
    if mode == "split" then
        Place(native, 1, 1, 1, 1, left, PAD_W / 2)
        native.bg:SetColorTexture(0.25, 0.25, 0.3, 0.6)
        native.icon:Hide()
    end
    for i, zone in ipairs(zones) do
        local c = f.cells[zone] or Cell(f)
        f.cells[zone] = c
        f.zones[zone] = true
        local row, col = zone:match("^r(%d)c(%d)$")
        row, col = tonumber(row), tonumber(col)
        if mode == "split" then
            Place(c, col, row, grid.cols, grid.rows, left + PAD_W / 2, PAD_W / 2)
        else
            Place(c, col, row, grid.cols, grid.rows, left, PAD_W)
        end
        local action = settings.actions[mode][layer][zone]
        if (action == nil or action == "none") and layer ~= "base" then action = settings.actions[mode].base[zone] end
        local label, icon, isAtlas = ActionLook(action)
        c.label:SetText(label or "")
        if icon then
            if isAtlas then c.icon:SetAtlas(icon) else c.icon:SetTexture(icon) end
            c.icon:Show()
        else
            c.icon:Hide()
        end
        local touch = mode == "chord" and settings.input == "dual" and settings.touchActions[layer] and settings.touchActions[layer][zone]
        if (touch == nil or touch == "none") and layer ~= "base" and mode == "chord" and settings.input == "dual" then
            touch = settings.touchActions.base[zone]
        end
        local _, tIcon, tAtlas = ActionLook(touch)
        if tIcon then
            if tAtlas then c.touch:SetAtlas(tIcon) else c.touch:SetTexture(tIcon) end
            c.touch:Show()
        else
            c.touch:Hide()
        end
    end
end

local function UpdatePreview(x, y, show)
    if not show then
        if preview then preview:Hide() end
        return
    end
    preview = preview or BuildPreview()
    local lt, rt = TriggersHeld()
    local layer = T.LayerOf(lt, rt)
    if preview.layer ~= layer or preview.mode ~= settings.mode or preview.dirty then
        preview.layer, preview.mode, preview.dirty = layer, settings.mode, false
        LayoutPreview(layer)
    end
    local mode = settings.mode
    local onNative = mode == "split" and x < 0
    local blizzard = mode == "chord" and not lastOurs
    local zone = not onNative and T.ZoneAt(mode, x, y, T.Grid(settings, mode)) or nil
    for z, c in pairs(preview.cells) do
        if z == zone and preview.zones[z] and not blizzard then c.bg:SetColorTexture(1, 0.82, 0.2, 0.35)
        else c.bg:SetColorTexture(1, 1, 1, 0.08) end
    end
    preview.native.bg:SetColorTexture(onNative and 0.4 or 0.25, onNative and 0.6 or 0.25, onNative and 1 or 0.3, 0.6)
    preview.title:SetText(blizzard and "Touchpad: Blizzard (Focus UI)"
        or ("Touchpad" .. (layer ~= "base" and (" | " .. T.LAYER_LABELS[layer]) or "")))
    preview.hint:SetText(mode == "chord" and "L1 + touchpad: Focus UI" or "Left half: Focus UI")
    preview.dot:ClearAllPoints()
    preview.dot:SetPoint("CENTER", preview, "TOPLEFT", 6 + (x + 1) / 2 * PAD_W, -20 - (1 - y) / 2 * PAD_H)
    preview:Show()
end

function Touch.RefreshPreview()
    if preview then preview.dirty = true end
end

---------------------------------------------------------------------------
-- Watching: who has the plain click (chord), the finger (preview)
---------------------------------------------------------------------------
local watcher = CreateFrame("Frame")
local wait, lastX, lastY, movedAt = 0, nil, nil, -math.huge
watcher:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 or not loaded or not settings.enabled then return end
    wait = 0.05
    if settings.mode == "chord" and Touch.WorldHasPad() ~= lastOurs then
        if InCombat() then pending = true else Touch.Apply() end
    end
    if not settings.preview or PadStyle() ~= "Shapes" then return UpdatePreview(0, 0, false) end
    local x, y = Finger()
    if not x then return UpdatePreview(0, 0, false) end
    local now = GetTime()
    if lastX and (math.abs(x - lastX) > 0.004 or math.abs(y - lastY) > 0.004) then movedAt = now end
    lastX, lastY = x, y
    UpdatePreview(x, y, now - movedAt < 1 or now - lastClick.at < 0.8)
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "CVAR_UPDATE", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "UPDATE_MACROS",
    "SPELLS_CHANGED", "PLAYER_LOGOUT" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= "GamepadCompanion" then return end
        settings = T.Normalize(GamepadCompanionTouchDB)
        GamepadCompanionTouchDB = settings
        loaded = true
        return
    end
    if not loaded then return end
    if event == "PLAYER_LOGOUT" then BlockTouchCursor(false); return TapToClick(false) end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    if event == "SPELLS_CHANGED" or event == "UPDATE_MACROS" then Touch.RefreshPreview() end
    Touch.Apply()
end)

---------------------------------------------------------------------------
-- Commands (/gpc touch ...)
---------------------------------------------------------------------------
local function Changed(message)
    Touch.RefreshPreview()
    Touch.Apply()
    if Touch.Notify then Touch.Notify() end
    Say(message .. (pending and " · after combat" or ""))
end

local function ActionText(action)
    if action == nil or action == "none" then return "-" end
    local label = ActionLook(action)
    return label or action
end

function Touch.Status()
    local env = Env()
    return {
        enabled = settings.enabled, mode = settings.mode, preview = settings.preview, chordButton = settings.chordButton,
        input = settings.input,
        padStyle = env.padStyle, ours = env.ours, conflict = env.conflict, note = note, pending = pending,
        bound = T.Copy(boundKeys),
    }
end

local function PrintStatus()
    local s = Touch.Status()
    Say(("touchpad %s, mode %s (%s), preview %s"):format(s.enabled and "on" or "off",
        s.mode == "chord" and "B: chord" or "A: split", s.mode == "chord" and "L1 + pad = Focus UI" or "left half = Focus UI",
        s.preview and "on" or "off"))
    local keys = {}
    for key in pairs(s.bound) do keys[#keys + 1] = key end
    table.sort(keys)
    Say("bound: " .. (#keys > 0 and table.concat(keys, " ") or "nothing")
        .. (s.mode == "chord" and s.enabled and ("; plain click is " .. (s.ours and "zones" or "Blizzard's")) or ""))
    if s.note then Say("note: " .. s.note) end
end

local function PrintList()
    local mode = settings.mode
    local grid = T.Grid(settings, mode)
    Say(("zones, %s, %d x %d:"):format(mode == "chord" and "whole pad" or "right half", grid.cols, grid.rows))
    for _, layer in ipairs(T.LAYERS) do
        local parts = {}
        local list = T.Zones(settings)
        for _, g in ipairs(T.GESTURES) do list[#list + 1] = g end
        for _, zone in ipairs(list) do
            local action = settings.actions[mode][layer][zone]
            if action and action ~= "none" then parts[#parts + 1] = zone .. "=" .. ActionText(action) end
        end
        if #parts > 0 or layer == "base" then
            Say("  " .. T.LAYER_LABELS[layer] .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "-"))
        end
    end
end

local function FromCursor()
    if not GetCursorInfo then return nil end
    local kind, a, _, d = GetCursorInfo()
    if kind == "spell" then
        local id = d or a
        if type(id) == "number" then return "spell:" .. id end
    elseif kind == "item" and type(a) == "number" then
        return "item:" .. a
    elseif kind == "macro" and a then
        local name = GetMacroInfo(a)
        if name then return "macro:" .. name end
    end
end

-- The probe: what the pad and the game report, then the finger for 6 s
local probing = false
local function Probe()
    if probing then return end
    probing = true
    local id = DeviceID()
    local state = MappedState()
    Say(("probe: pad %s, %s:%s, style %s, sticks %s, buttons %s"):format(tostring(state and state.name),
        tostring(id and id.vendorID), tostring(id and id.productID), tostring(state and state.labelStyle),
        tostring(state and state.stickCount), tostring(state and state.buttonCount)))
    local power = C_GamePad and C_GamePad.GetPowerLevel and select(2, pcall(C_GamePad.GetPowerLevel, C_GamePad.GetActiveDeviceID()))
    Say(("probe: power %s, gamepad UI %s, core set only %s, window focused %s, Improved Forever corners %s"):format(
        tostring(power), tostring(GamepadUI()), tostring(CoreOnly()), tostring(UIFocused()), tostring(Touch.Conflict())))
    for _, key in ipairs({ "PADBACK", "CTRL-PADBACK", "SHIFT-PADBACK", "PAD6" }) do
        Say(("probe: %s -> %s"):format(key, tostring(GetBindingAction and GetBindingAction(key, true))))
    end
    local e = Emulate()
    Say(("probe: L1/L2 emulate: Ctrl %s, Shift %s, Alt %s; touch cursor %s, touch tap buttons %s"):format(
        tostring(e.CTRL), tostring(e.SHIFT), tostring(e.ALT), tostring(GetCVarSafe(CURSOR_CVAR)),
        tostring(GetCVarSafe("GamePadTouchTapButtons"))))
    Say(("probe: right half on PAD6: %s"):format(tostring(id and T.IsSplit(GetConfig(id)))))
    Say("probe: touch the pad, no click, 6 s")
    local last, n = nil, 0
    local ticker
    ticker = C_Timer.NewTicker(0.2, function()
        n = n + 1
        local x, y, len = Finger()
        local line = x and ("%.2f, %.2f (len %.2f)"):format(x, y, len) or "no reading"
        if line ~= last then Say("finger " .. line) end
        last = line
        if n >= 30 then
            ticker:Cancel()
            probing = false
            Say("probe: done")
        end
    end)
end

-- Setters for the Touchpad window (no chat line)
local listeners = {}
function Touch.OnChange(callback) listeners[#listeners + 1] = callback end
local function Notify() for _, callback in ipairs(listeners) do pcall(callback) end end
Touch.Notify = Notify
local function Update()
    Touch.RefreshPreview()
    Touch.Apply()
    Notify()
end
function Touch.Settings() return settings end
function Touch.SetEnabled(value) settings.enabled = value == true; Update() end
function Touch.SetMode(mode)
    mode = T.MODE_ALIASES[mode] or mode
    if not T.MODES[mode] then return false end
    settings.mode = mode
    Update()
    return true
end
function Touch.SetInput(input)
    if not T.INPUTS[input] then return false end
    settings.input = input
    Update()
    return true
end
function Touch.SetTapTime(ms)
    ms = tonumber(ms)
    if not ms or ms < T.TAP_MS.min or ms > T.TAP_MS.max then return false end
    settings.tapMs = math.floor(ms)
    Update()
    return true
end
function Touch.SetTap(value) return Touch.SetInput(value == true and "tap" or "click") end
function Touch.SetOverWindows(value) settings.overWindows = value == true; Update() end
function Touch.SetPreview(value)
    settings.preview = value == true
    if not settings.preview then UpdatePreview(0, 0, false) end
    Notify()
end
-- action: "window:<key>", "spell:<id>", "item:<id>", "macro:<name>" or "none"
function Touch.SetGrid(cols, rows)
    local limit = T.GRID_LIMITS[settings.mode]
    cols, rows = tonumber(cols), tonumber(rows)
    if not cols or not rows or cols < 1 or rows < 1 or cols > limit.cols or rows > limit.rows then return false end
    settings.grid[settings.mode] = { cols = cols, rows = rows }
    Update()
    return true
end
-- slot: "click" (default) or "touch" (dual input; zones only, whole pad)
function Touch.SetZone(layer, zone, action, slot)
    local mode = settings.mode
    if not T.IsZone(settings, mode, zone) or not T.IsLayer(layer) then return false end
    if slot == "touch" then
        if mode ~= "chord" or not settings.touchActions[layer] or T.GESTURE_LABELS[zone] then return false end
        settings.touchActions[layer][zone] = action or "none"
        Update()
        return true
    end
    settings.actions[mode][layer][zone] = action or "none"
    Update()
    return true
end
-- The spell, item or macro on the cursor, taken off it
function Touch.TakeCursor()
    local action = FromCursor()
    if action and ClearCursor then ClearCursor() end
    return action
end
function Touch.IsPending() return pending end

function Touch.Command(text)
    local words = {}
    for w in (text or ""):gmatch("%S+") do words[#words + 1] = w end
    local command = (words[1] or ""):lower()
    if command == "" and API.ToggleTouchpad then return API.ToggleTouchpad() end
    if command == "" or command == "status" then return PrintStatus() end
    if command == "on" or command == "off" then
        settings.enabled = command == "on"
        return Changed("Touchpad zones " .. command)
    elseif command == "mode" then
        local mode = T.MODE_ALIASES[(words[2] or ""):lower()]
        if not mode then return Say("Modes: chord (B), split (A)") end
        settings.mode = mode
        return Changed(mode == "chord" and "Mode B: chord" or "Mode A: split")
    elseif command == "set" or command == "clear" then
        local mode = settings.mode
        local zone, layer, rest, slot = (words[2] or ""):lower(), "base", 3, "click"
        zone = T.OLD_ZONES[mode][zone] or zone
        if (words[rest] or ""):lower() == "touch" then slot, rest = "touch", rest + 1 end
        if T.IsLayer((words[rest] or ""):lower()) then layer, rest = words[rest]:lower(), rest + 1 end
        if not T.IsZone(settings, mode, zone) then
            return Say("Zones: " .. table.concat(T.Zones(settings), ", ") .. ", " .. table.concat(T.GESTURES, ", "))
        end
        local action = "none"
        if command == "set" then
            local window = words[rest] and words[rest]:lower()
            if window then
                if not T.WINDOW_BY_KEY[window] then return Say("Unknown window · /gpc touch windows") end
                action = "window:" .. window
            else
                action = FromCursor()
                if not action then return Say("Nothing on cursor") end
                if ClearCursor then ClearCursor() end
            end
        end
        if slot == "touch" then
            if mode ~= "chord" or T.GESTURE_LABELS[zone] then return Say("Touch: whole pad zones only") end
            settings.touchActions[layer][zone] = action
        else
            settings.actions[mode][layer][zone] = action
        end
        return Changed(("%s, %s%s: %s"):format(T.ZoneLabel(zone, T.Grid(settings, mode)), T.LAYER_LABELS[layer],
            slot == "touch" and ", touch" or "", ActionText(action)))
    elseif command == "grid" then
        if not Touch.SetGrid(words[2], words[3]) then
            local limit = T.GRID_LIMITS[settings.mode]
            return Say(("Grid: 1-%d columns, 1-%d rows"):format(limit.cols, limit.rows))
        end
        return Changed(("Grid %s x %s"):format(words[2], words[3]))
    elseif command == "list" then
        return PrintList()
    elseif command == "windows" then
        local keys = {}
        for _, w in ipairs(T.WINDOWS) do keys[#keys + 1] = w.key end
        return Say("windows: " .. table.concat(keys, ", "))
    elseif command == "preview" then
        settings.preview = (words[2] or ""):lower() ~= "off"
        if not settings.preview then UpdatePreview(0, 0, false) end
        Touch.Notify()
        return Say("Preview " .. (settings.preview and "on" or "off"))
    elseif command == "windows-over" or command == "over" then
        Touch.SetOverWindows((words[2] or ""):lower() ~= "off")
        return Say("Over windows " .. (settings.overWindows and "on" or "off"))
    elseif command == "tap" then
        Touch.SetTap((words[2] or ""):lower() ~= "off")
        return Say("Tap to click " .. (settings.input == "tap" and "on" or "off"))
    elseif command == "taptime" then
        if not Touch.SetTapTime(words[2]) then
            return Say(("Tap time: %d-%d ms"):format(T.TAP_MS.min, T.TAP_MS.max))
        end
        return Say("Tap time " .. settings.tapMs .. " ms")
    elseif command == "input" then
        if not Touch.SetInput((words[2] or ""):lower()) then return Say("Input: click, tap, dual") end
        return Say("Input " .. settings.input)
    elseif command == "chord" then
        local button = (words[2] or ""):upper()
        if not button:match("^PAD") then return Say("Pad buttons only (PADLSHOULDER)") end
        settings.chordButton = button
        return Changed("Focus UI: " .. button .. " + touchpad")
    elseif command == "restore" then
        if InCombat() then return Say("Not in combat") end
        settings.enabled = false
        local restored = Touch.RestoreSplit()
        Touch.Apply()
        return Say("Touchpad zones off" .. (restored and " · config restored" or ""))
    elseif command == "probe" then
        return Probe()
    elseif command == "raw" then
        return Touch.RawProbe()
    elseif command == "debug" then
        debug = (words[2] or ""):lower() ~= "off"
        return Say("Touch debug " .. (debug and "on" or "off"))
    end
    Say("/gpc touch [status | on | off | mode chord|split | grid <cols> <rows> | set <zone> [lt|rt|both] [window]"
        .. " | clear <zone> [layer]"
        .. " | list | windows | preview on|off | tap on|off | input click|tap|dual | taptime <ms> | over on|off | chord <button> | probe | debug on|off | restore]")
end

-- Harness access
ns.TouchClick = click
ns.TouchSettings = function() return settings end
