-- Converts real saved Companion profiles into native gamepad Edit Mode layouts,
-- using Blizzard's 1.60.1.70338 gamepad preset and setting metadata.
-- Run from the client root:
--   lua5.1 Interface/AddOns/GamepadCompanion/tests/NativeMigration.lua Interface/AddOns/GamepadCompanion [SavedVariables file]
local root = (arg[1] or "Interface/AddOns/GamepadCompanion") .. "/"
local svFile = arg[2] or "StorageInvestigation/fixtures/GamepadCompanion-beta-70338.lua"
local blizzard = "StorageInvestigation/forever-ui-70338/Interface/AddOns/"

-- Blizzard data -------------------------------------------------------------
-- The constants table refers to this enum while it is being built.
Enum, Constants = { EditModePresetLayouts = { Modern = 0, Classic = 1, Gamepad = 2 } }, {}
APIDocumentation = { AddDocumentationTable = function(_, doc)
    for _, t in ipairs(doc.Tables or {}) do
        if t.Type == "Enumeration" then
            Enum[t.Name] = {}
            for _, f in ipairs(t.Fields) do Enum[t.Name][f.Name] = f.EnumValue end
        elseif t.Type == "Constants" then
            Constants[t.Name] = {}
            for _, f in ipairs(t.Values or {}) do Constants[t.Name][f.Name] = f.Value end
        end
    end
end }
assert(loadfile(blizzard .. "Blizzard_APIDocumentationGenerated/InputConstantsDocumentation.lua"))()
assert(loadfile(blizzard .. "Blizzard_APIDocumentationGenerated/EditModeManagerConstantsDocumentation.lua"))()
local function CopyTable(t)
    if type(t) ~= "table" then return t end
    local c = {}; for k, v in pairs(t) do c[k] = CopyTable(v) end; return c
end
_G.CopyTable = CopyTable
TableUtil = { GetHighestNumericalValueInTable = function(t) local n = 0; for _, v in pairs(t) do n = math.max(n, v) end; return n end }
Clamp = function(v, a, b) return math.min(b, math.max(a, v)) end
C_AddOns = { EnableAddOn = function() end }
for _, file in ipairs({ "Blizzard_EditMode/Camelot/EditModePresetLayoutConstants.lua",
    "Blizzard_EditMode/Mainline/EditModePresetLayouts.lua", "Blizzard_EditMode/Shared/EditModePresetLayoutSystemUtils.lua",
    "Blizzard_EditMode/Shared/EditModePresetLayoutsManager.lua", "Blizzard_EditMode/Shared/EditModeSettingDisplayInfo.lua" }) do
    assert(loadfile(blizzard .. file))()
end
local GAMEPAD, CHARACTER, ACCOUNT = Enum.InputDeviceInterfaceType.Gamepad, Enum.EditModeLayoutType.Character, Enum.EditModeLayoutType.Account
local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
local gamepadPreset = presets[3]
assert(gamepadPreset.interfaceStyle == GAMEPAD and #presets == 3)
local function Key(s) return tostring(s.system) .. ":" .. tostring(s.systemIndex) end

-- Client stand-ins ----------------------------------------------------------
local native, printed, gamepad, combat, timers = nil, {}, true, false, {}
local function Rounded(data)
    -- What the client keeps: offsets to a tenth, integer setting values.
    data = CopyTable(data)
    for _, layout in ipairs(data.layouts) do
        for _, s in ipairs(layout.systems) do
            for _, a in ipairs({ s.anchorInfo, s.anchorInfo2 }) do
                a.offsetX = math.floor(a.offsetX * 10 + .5) / 10; a.offsetY = math.floor(a.offsetY * 10 + .5) / 10
            end
            for _, setting in ipairs(s.settings) do setting.value = math.floor(setting.value) end
        end
    end
    return data
end
C_EditMode = {
    GetLayouts = function() return CopyTable(native) end,
    SaveLayouts = function(data) native = Rounded(data) end,
    SetActiveLayout = function(index) native.activeLayout = index end,
    IsValidLayoutName = function(name) return #name <= 32 end,
    GetEditModeDefaultLayout = function() return Enum.EditModePresetLayouts.Modern end,
}
InputUtil = { IsGamepadUIEnabled = function() return gamepad end }
InCombatLockdown = function() return combat end
EditModeManagerFrame = { registeredSystemFrames = {}, IsInitialized = function() return true end }
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
-- Protected: an addon call from a timer is blocked (ADDON_ACTION_BLOCKED in game).
ReloadUI = function() error("ReloadUI is protected; Companion must not call it") end
time = os.time
print = function(message) printed[#printed + 1] = message end
local frames = {}
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end
local guid, character = "Player-4618-00D2CA64", "Alberich"
UnitGUID = function() return guid end
UnitName = function() return character end
GetRealmName = function() return "Classic Beta PvE" end
SlashCmdList = {}
GamepadCompanionAPI = {}
issecretvalue = nil

local env = {}
local chunk = assert(loadfile(svFile)); setfenv(chunk, env); chunk()
local saved = assert(env.GamepadCompanionEditModeDB, "no Companion Edit Mode data in " .. svFile)
-- Live data may already be converted: start every character from before that.
for _, data in pairs(saved.characters or {}) do
    if type(data.native) == "table" then data.active, data.native = data.active or data.native.sourceName, nil end
end

local ns = {}
assert(loadfile(root .. "Model.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "NativeLayoutExport.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "EditMode.lua"))("GamepadCompanion", ns)
local events = frames[#frames]
local API = ns.EditMode
local function Fire(event, arg) events.onEvent(events, event, arg) end
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
-- A fresh UI session: module state resets, saved data stays.
local function Session()
    timers = {}
    assert(loadfile(root .. "EditMode.lua"))("GamepadCompanion", ns)
    events, API = frames[#frames], ns.EditMode
    Fire("ADDON_LOADED", "GamepadCompanion")
end

-- The account's gamepad layout in use: moved controller bar, Compact on.
local function ActiveGamepadLayout()
    local layout = { layoutName = "[GP] Gamepad Mime 2", layoutType = ACCOUNT, interfaceStyle = GAMEPAD, systems = CopyTable(gamepadPreset.systems) }
    for _, s in ipairs(layout.systems) do
        if s.system == Enum.EditModeSystem.GamepadMainActionBar then
            s.isInDefaultPosition = false
            s.anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 12, offsetY = 140 }
            for _, setting in ipairs(s.settings) do
                if setting.setting == Enum.EditModeGamepadMainActionBarSetting.Compact then setting.value = 1 end
            end
        end
    end
    return layout
end
-- A gamepad layout as stored before build 70338: keyboard systems, no
-- controller action bar (what the client returned for "gamepad new" etc.).
local function StaleGamepadLayout(name)
    local layout = { layoutName = name, layoutType = ACCOUNT, interfaceStyle = GAMEPAD, systems = CopyTable(presets[1].systems) }
    for _, s in ipairs(layout.systems) do
        if s.system == Enum.EditModeSystem.Minimap then
            s.isInDefaultPosition = false
            s.anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = -30, offsetY = -40 }
        end
    end
    return layout
end
local function HasBar(layout)
    for _, s in ipairs(layout.systems) do if s.system == Enum.EditModeSystem.GamepadMainActionBar then return s end end
end
local function FreshNative(extraCharacterLayouts)
    native = { layouts = {
        { layoutName = "Mime", layoutType = ACCOUNT, interfaceStyle = 0, systems = CopyTable(presets[1].systems) },
        ActiveGamepadLayout(),
        StaleGamepadLayout("gamepad new"),
    }, activeLayout = 3 + 2 }
    for i = 1, extraCharacterLayouts or 0 do
        native.layouts[#native.layouts + 1] = { layoutName = "Old " .. i, layoutType = CHARACTER, interfaceStyle = GAMEPAD, systems = {} }
    end
end

local function Check(profile, layout)
    assert(layout.layoutType == CHARACTER and layout.interfaceStyle == GAMEPAD)
    assert(#layout.systems == #gamepadPreset.systems, "exactly the gamepad preset's systems")
    -- Blizzard's ReconcileWithGamepad would change nothing: no extra system or setting.
    local preset = {}
    for _, s in ipairs(gamepadPreset.systems) do
        local ids = {}; for _, setting in ipairs(s.settings) do ids[setting.setting] = true end
        preset[Key(s)] = ids
    end
    local byKey = {}
    for _, s in ipairs(layout.systems) do
        local ids = assert(preset[Key(s)], "not a gamepad system: " .. Key(s))
        for _, setting in ipairs(s.settings) do assert(ids[setting.setting], "stale setting on " .. Key(s)) end
        byKey[Key(s)] = s
    end
    -- The controller action bar block keeps the position and Compact setting in use.
    local bar = byKey[Key({ system = Enum.EditModeSystem.GamepadMainActionBar })]
    assert(not bar.isInDefaultPosition and bar.anchorInfo.offsetX == 12 and bar.anchorInfo.offsetY == 140)
    for _, setting in ipairs(bar.settings) do
        if setting.setting == Enum.EditModeGamepadMainActionBarSetting.Compact then assert(setting.value == 1) end
    end
    -- Every positioned Companion frame is a moved native system.
    local moved = 0
    for _, s in ipairs(layout.systems) do if not s.isInDefaultPosition then moved = moved + 1 end end
    local positioned = 0
    for _, entry in pairs(profile.frames) do if not entry.settingsOnly then positioned = positioned + 1 end end
    assert(moved == positioned + 1, moved .. " moved systems for " .. positioned .. " positioned frames")
    local cast = byKey[Key({ system = Enum.EditModeSystem.CastBar })]
    local entry = profile.frames.GamepadPlayerCastingBarFrame
    if entry and not entry.settingsOnly and not entry.anchors then
        assert(math.abs(cast.anchorInfo.offsetX - entry.x) <= .05 and math.abs(cast.anchorInfo.offsetY - entry.y) <= .05)
        assert(cast.anchorInfo.relativeTo == "UIParent", "the cast bar no longer follows the controller bar")
    end
    return byKey
end

-- 1. Alberich, in the gamepad UI: converted, verified and selected (no reload);
-- the older gamepad layout in the saved copy gets the controller action bar (silently),
-- keyboard ones are untouched.
GamepadCompanionEditModeDB = CopyTable(saved)
FreshNative()
Session()
local state = GamepadCompanionEditModeDB.characters[guid]
local sourceName = assert(state.active, "Alberich has an active Companion layout")
local profile = CopyTable(state.profiles[sourceName])
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
local stale = native.layouts[3]
assert(stale.layoutName == "gamepad new" and HasBar(stale) and #stale.systems == #gamepadPreset.systems,
    "old gamepad layout reconciled to the gamepad preset")
for _, s in ipairs(stale.systems) do
    if s.system == Enum.EditModeSystem.Minimap then assert(s.anchorInfo.offsetX == -30 and not s.isInDefaultPosition, "kept its own positions") end
end
assert(not HasBar(native.layouts[1]) and #native.layouts[1].systems == #presets[1].systems, "keyboard layout untouched")
assert(not table.concat(printed, "\n"):find("Added the controller action bar"), "no repair chat line (Blizzard reconciles since 70532)")
local index, layout
for i, l in ipairs(native.layouts) do if l.layoutName == "Alberich Gamepad" then index, layout = i, l end end
assert(layout and native.activeLayout == 3 + index, "the new layout is the active gamepad layout")
local byKey = Check(profile, layout)
local chat = byKey[Key({ system = Enum.EditModeSystem.ChatFrame })]
local values = {}; for _, s in ipairs(chat.settings) do values[s.setting] = s.value end
local c = Enum.EditModeChatFrameSetting
assert(values[c.WidthHundreds] * 100 + values[c.WidthTensAndOnes] == 402, "Companion chat width")
assert(state.active == nil and state.native.status == "selected" and state.native.sourceName == sourceName)
assert(state.profiles[sourceName] and state.profiles.GP2, "old Companion layouts stay as a backup")
local receipts = GamepadCompanionEditModeDB.nativeExportHistory
assert(receipts[#receipts].status == "selected" and #receipts <= 6)
for _, message in ipairs(printed) do assert(not message:find("adjusted"), "readback matches: " .. message) end

-- 2. The next session changes nothing and reports the layout in use.
printed = {}
local before = CopyTable(native)
Session(); Fire("PLAYER_ENTERING_WORLD"); RunTimers()
assert(#native.layouts == 4 and #printed == 0, table.concat(printed, "\n"))
assert(API.Status():find('in use: "Alberich Gamepad"'))
-- If Blizzard did not keep the selection, say so once and name the layout list.
native.activeLayout = 3 + 2
state.native.checked = nil
Session(); Fire("PLAYER_ENTERING_WORLD"); RunTimers()
assert(table.concat(printed, "\n"):find('Blizzard is using "%[GP%] Gamepad Mime 2"'), table.concat(printed, "\n"))
assert(native.activeLayout == 3 + 2, "the player's choice is not overridden")
printed = {}
Session(); Fire("PLAYER_ENTERING_WORLD"); RunTimers()
assert(#printed == 0, "said once")

-- 3. Logged in with the keyboard UI: nothing is saved (no per-login repair; Blizzard
-- reconciles old gamepad layouts itself since 70532); the conversion waits for the
-- gamepad UI and the end of combat.
GamepadCompanionEditModeDB = CopyTable(saved)
FreshNative(); gamepad = false
Session(); Fire("PLAYER_ENTERING_WORLD"); RunTimers()
assert(#native.layouts == 3 and not HasBar(native.layouts[3]) and #printed == 0, "keyboard UI: nothing saved, conversion waits")
gamepad = true; combat = true
Fire("INPUT_DEVICE_INTERFACE_TRANSITION"); RunTimers()
assert(#native.layouts == 3, "combat: waits")
combat = false
Fire("PLAYER_REGEN_ENABLED"); RunTimers()
assert(#native.layouts == 4 and native.activeLayout == 3 + 4)
-- Converting from the keyboard UI (by command) saves, then selects on the switch.
GamepadCompanionEditModeDB = CopyTable(saved)
FreshNative(); gamepad = false
Session()
API.Command("convert")
state = GamepadCompanionEditModeDB.characters[guid]
assert(#native.layouts == 4 and state.native.status == "saved" and native.activeLayout == 5)
gamepad = true
Fire("INPUT_DEVICE_INTERFACE_TRANSITION"); RunTimers()
assert(native.activeLayout == 3 + 4 and state.native.status == "selected")

-- 4. Character slots full: no new layout, and the reason is shown.
GamepadCompanionEditModeDB = CopyTable(saved)
FreshNative(5); printed = {}
Session(); Fire("PLAYER_ENTERING_WORLD"); RunTimers()
assert(#native.layouts == 8)
local said = table.concat(printed, "\n")
assert(said:find("slots are full"), said)

-- 5. A name already in use gets a number.
GamepadCompanionEditModeDB = CopyTable(saved)
FreshNative()
native.layouts[#native.layouts + 1] = { layoutName = "Alberich Gamepad", layoutType = ACCOUNT, interfaceStyle = 0, systems = {} }
Session(); Fire("PLAYER_ENTERING_WORLD"); RunTimers()
assert(native.layouts[#native.layouts].layoutName == "Alberich Gamepad 2" and native.activeLayout == 3 + 5)

-- 6. Every character's active Companion layout converts.
local converted = 0
for characterGuid, data in pairs(saved.characters) do
    if data.active and data.profiles[data.active] then
        GamepadCompanionEditModeDB = CopyTable(saved)
        FreshNative()
        guid, character = characterGuid, (data.characterName or "Someone"):match("^[^-]+")
        Session(); Fire("PLAYER_ENTERING_WORLD"); RunTimers()
        local s = GamepadCompanionEditModeDB.characters[characterGuid]
        assert(s.native and s.native.status == "selected", characterGuid .. ": " .. tostring(s.native and s.native.reason))
        Check(data.profiles[data.active], native.layouts[#native.layouts])
        converted = converted + 1
    end
end
assert(converted >= 1)
print = _G.print
io.write("PASS: " .. converted .. " saved Companion layouts convert to native gamepad layouts (70338 preset, "
    .. #gamepadPreset.systems .. " systems): controller bar position/Compact kept, reconcile-clean, readback exact, selected without ReloadUI; old gamepad layouts in the saved copy get the controller bar (no chat line, no per-login repair), keyboard layouts untouched; lost selection reported once; keyboard-UI deferral, combat wait, full slots, name clash\n")
