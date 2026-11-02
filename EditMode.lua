local ADDON, ns = ...
local M, E = ns.Model, ns.NativeLayoutExport
local API = {}
ns.EditMode = API
GamepadCompanionAPI.EditMode = API

-- Since build 70338 Blizzard Edit Mode has real controller layouts: each one is
-- tagged for the gamepad UI, reconciled against the gamepad preset, and the
-- client keeps a separate active layout per input mode, switching by itself.
-- Companion no longer places frames. It converts the Companion layout a
-- character was using into one native gamepad layout, once, selects it and
-- reloads. The old profiles stay in GamepadCompanionEditModeDB as a backup.
-- Only public C_EditMode functions write native state; Blizzard's manager
-- tables and frames are read, never written.

local events = CreateFrame("Frame")
local ready, attempted, scheduled, repaired = false, false, false, false

local function Say(message)
    print("|cff80c0ffGamepad Companion:|r " .. message)
end
local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and M.Readable(value) then return value end
end
local function Gamepad()
    return InputUtil and Safe(InputUtil.IsGamepadUIEnabled) == true
end
local function Editor()
    local manager = EditModeManagerFrame
    return manager and manager.editModeActive == true
end
local function ManagerReady()
    local manager = EditModeManagerFrame
    return manager and Safe(manager.IsInitialized, manager) == true
end
local function GamepadStyle()
    return Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad
end

local function DB()
    if type(GamepadCompanionEditModeDB) ~= "table" then GamepadCompanionEditModeDB = {} end
    local db = GamepadCompanionEditModeDB
    db.characters = type(db.characters) == "table" and db.characters or {}
    return db
end
local function State()
    local guid = Safe(UnitGUID, "player")
    if type(guid) ~= "string" then return nil end
    local db = DB()
    local state = db.characters[guid]
    if type(state) ~= "table" then state = {}; db.characters[guid] = state end
    state.profiles = type(state.profiles) == "table" and state.profiles or {}
    local character, realm = Safe(UnitName, "player"), Safe(GetRealmName)
    if type(character) == "string" then
        state.characterName = character .. (type(realm) == "string" and ("-" .. realm) or "")
    end
    return state
end

-- Native system for each frame Companion profiles can hold. Used when the
-- frame has not registered yet (the cooldown viewers load on demand).
local knownSystems = {
    PlayerFrame = { "UnitFrame", "EditModeUnitFrameSystemIndices", "Player" },
    TargetFrame = { "UnitFrame", "EditModeUnitFrameSystemIndices", "Target" },
    FocusFrame = { "UnitFrame", "EditModeUnitFrameSystemIndices", "Focus" },
    PartyFrame = { "UnitFrame", "EditModeUnitFrameSystemIndices", "Party" },
    CompactRaidFrameContainer = { "UnitFrame", "EditModeUnitFrameSystemIndices", "Raid" },
    BossTargetFrameContainer = { "UnitFrame", "EditModeUnitFrameSystemIndices", "Boss" },
    PetFrame = { "UnitFrame", "EditModeUnitFrameSystemIndices", "Pet" },
    PlayerCastingBarFrame = { "CastBar" },
    MinimapCluster = { "Minimap" },
    ObjectiveTrackerFrame = { "ObjectiveTracker" },
    ChatFrame1 = { "ChatFrame" },
    BuffFrame = { "AuraFrame", "EditModeAuraFrameSystemIndices", "BuffFrame" },
    DebuffFrame = { "AuraFrame", "EditModeAuraFrameSystemIndices", "DebuffFrame" },
    EssentialCooldownViewer = { "CooldownViewer", "EditModeCooldownViewerSystemIndices", "Essential" },
    UtilityCooldownViewer = { "CooldownViewer", "EditModeCooldownViewerSystemIndices", "Utility" },
    BuffIconCooldownViewer = { "CooldownViewer", "EditModeCooldownViewerSystemIndices", "BuffIcon" },
    BuffBarCooldownViewer = { "CooldownViewer", "EditModeCooldownViewerSystemIndices", "BuffBar" },
    QueueStatusButton = { "GroupFinder" },
    DurabilityFrame = { "DurabilityFrame" },
    MicroMenuContainer = { "MicroMenu" },
    GameTooltipDefaultContainer = { "HudTooltip" },
}

-- name -> { system, systemIndex, settingDisplayInfoMap } (read only).
local function Targets()
    local result = {}
    local displayInfo = EditModeSettingDisplayInfoManager and EditModeSettingDisplayInfoManager.displayInfoMap or {}
    for name, info in pairs(knownSystems) do
        local system = Enum.EditModeSystem and Enum.EditModeSystem[info[1]]
        local index = info[2] and Enum[info[2]] and Enum[info[2]][info[3]]
        if system ~= nil and (not info[2] or index ~= nil) then
            result[name] = { system = system, systemIndex = index, settingDisplayInfoMap = displayInfo[system] }
        end
    end
    local manager = EditModeManagerFrame
    for _, target in pairs(manager and manager.registeredSystemFrames or {}) do
        local name = Safe(target.GetName, target)
        if type(name) == "string" and name ~= "" and _G[name] == target then
            result[name] = { system = target.system, systemIndex = target.systemIndex,
                settingDisplayInfoMap = target.settingDisplayInfoMap or displayInfo[target.system] }
        end
    end
    return result
end

local function GamepadPreset()
    local manager = EditModePresetLayoutManager
    local presets = manager and Safe(manager.GetCopyOfPresetLayouts, manager)
    local style = GamepadStyle()
    for _, preset in ipairs(type(presets) == "table" and presets or {}) do
        if style ~= nil and preset.interfaceStyle == style and type(preset.systems) == "table" then
            return preset.systems, #presets
        end
    end
end

local function Key(system) return tostring(system.system) .. ":" .. tostring(system.systemIndex) end

-- The gamepad preset's systems, each replaced by the gamepad layout in use
-- when that layout has it. Frames Companion never moved, and the controller
-- action bar block with its Compact / Expand settings, stay as they are now.
function API.BaseSystems(data, presetSystems, presetCount)
    local systems = M.Copy(presetSystems)
    local active = data.activeLayout
    local layout = type(active) == "number" and active > presetCount and data.layouts[active - presetCount]
    if not layout or layout.interfaceStyle ~= GamepadStyle() then return systems, nil end
    local saved = {}
    for _, system in ipairs(layout.systems or {}) do saved[Key(system)] = system end
    for index, system in ipairs(systems) do
        if saved[Key(system)] then systems[index] = M.Copy(saved[Key(system)]) end
    end
    return systems, layout.layoutName
end

-- Blizzard's ReconcileWithGamepad on a saved copy: exactly the gamepad
-- preset's systems and settings. Layouts saved before 70338 lack the controller
-- action bar system (GamepadMainActionBar), and Edit Mode hides a registered
-- frame whose system the active layout lacks: no bar, and nothing to select.
-- Kept systems keep their position and values; missing ones get the preset's.
function API.ReconcileGamepad(layout, presetSystems)
    local saved, matched, changed = {}, 0, false
    for _, system in ipairs(layout.systems or {}) do saved[Key(system)] = system end
    local systems = {}
    for _, preset in ipairs(presetSystems) do
        local system = saved[Key(preset)]
        if system then
            matched = matched + 1
            local known, have, settings = {}, {}, {}
            for _, setting in ipairs(preset.settings or {}) do known[setting.setting] = true end
            for _, setting in ipairs(system.settings or {}) do
                if known[setting.setting] and not have[setting.setting] then
                    have[setting.setting] = true
                    settings[#settings + 1] = M.Copy(setting)
                else changed = true end
            end
            for _, setting in ipairs(preset.settings or {}) do
                if not have[setting.setting] then settings[#settings + 1] = M.Copy(setting); changed = true end
            end
            local copy = M.Copy(system)
            copy.settings = settings
            systems[#systems + 1] = copy
        else
            systems[#systems + 1] = M.Copy(preset)
            changed = true
        end
    end
    if matched ~= #(layout.systems or {}) then changed = true end
    if changed then layout.systems = systems end
    return changed
end

-- Reconcile every custom gamepad layout in `data`; returns the changed names.
local function RepairAll(data, presetSystems)
    local names = {}
    for _, layout in ipairs(data.layouts or {}) do
        if layout.interfaceStyle == GamepadStyle() and API.ReconcileGamepad(layout, presetSystems) then
            names[#names + 1] = '"' .. tostring(layout.layoutName) .. '"'
        end
    end
    return names
end

local function LayoutIndex(data, name)
    for index, layout in ipairs(data and data.layouts or {}) do
        if layout.layoutName == name then return index, layout end
    end
end

-- "<Character> Gamepad", then "... 2", "... 3" if that name is taken.
function API.FreeName(data, character)
    local base = (character or "Companion"):sub(1, 22) .. " Gamepad"
    for n = 1, 9 do
        local name = n == 1 and base or (base .. " " .. n)
        local valid = not (C_EditMode and C_EditMode.IsValidLayoutName) or Safe(C_EditMode.IsValidLayoutName, name) ~= false
        if valid and not LayoutIndex(data, name) then return name end
    end
end

local function Remember(receipt)
    local db = DB()
    db.nativeExportHistory = type(db.nativeExportHistory) == "table" and db.nativeExportHistory or {}
    table.insert(db.nativeExportHistory, receipt)
    while #db.nativeExportHistory > 6 do table.remove(db.nativeExportHistory, 1) end
end

local function Select(state, data, index, presetCount)
    local wanted = presetCount + index
    local ok, err = pcall(C_EditMode.SetActiveLayout, wanted)
    local active = Safe(C_EditMode.GetLayouts)
    if not ok or not active or active.activeLayout ~= wanted then
        return false, tostring(err or "Blizzard kept the previous layout")
    end
    state.native.status, state.native.select = "selected", nil
    return true
end

-- Convert a saved Companion layout (default: the one this character used)
-- into a native character layout for the gamepad UI. With `activate`, also make
-- it the active gamepad layout. ReloadUI is protected (blocked from a timer),
-- so there is no reload; Blizzard applies the layout through its own event.
function API.Convert(profileName, activate)
    local state = State()
    if not state then return false, "Character data is not ready yet." end
    if profileName == "" then profileName = nil end
    profileName = profileName or state.active or (state.native and state.native.sourceName)
    local profile = profileName and state.profiles[profileName]
    if not profile then
        return false, profileName and ("No Companion layout named \"" .. profileName .. "\" on this character.")
            or "This character has no Companion layout to convert."
    end
    if InCombatLockdown() then return false, "Finish combat first." end
    if Editor() then return false, "Close Edit Mode first." end
    if activate and not Gamepad() then activate = false end
    local style = GamepadStyle()
    local kind = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character
    local data = C_EditMode and Safe(C_EditMode.GetLayouts)
    local preset, presetCount = GamepadPreset()
    if not E or style == nil or kind == nil or type(data) ~= "table" or type(data.layouts) ~= "table"
        or not preset or not C_EditMode.SaveLayouts or not C_EditMode.SetActiveLayout then
        return false, "Blizzard's gamepad Edit Mode is not available in this client."
    end
    local count = 0
    for _, layout in ipairs(data.layouts) do if layout.layoutType == kind then count = count + 1 end end
    local limit = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType or 5
    if count >= limit then
        return false, "Blizzard's " .. limit .. " character layout slots are full. Delete one in Edit Mode, then type /gpc edit convert."
    end
    local name = API.FreeName(data, Safe(UnitName, "player"))
    if not name then return false, "No free layout name. Rename a layout in Edit Mode, then type /gpc edit convert." end
    local base, baseName = API.BaseSystems(data, preset, presetCount)
    local built, layout, report = pcall(E.Build, profile, base, Targets(), name, kind, style)
    if not built then return false, "Nothing was saved: " .. tostring(layout) end

    local receipt = { time = time and time(), character = Safe(UnitGUID, "player"), sourceName = profileName,
        baseName = baseName, previousNative = M.Copy(data), exported = M.Copy(layout), report = M.Copy(report), status = "prepared" }
    Remember(receipt)
    local copy = M.Copy(data)
    local repaired = RepairAll(copy, preset)
    copy.layouts[#copy.layouts + 1] = layout
    local saved, err = pcall(C_EditMode.SaveLayouts, copy)
    if not saved then
        receipt.status = "save-failed"
        return false, "Blizzard did not save the layout: " .. tostring(err)
    end
    local readback = Safe(C_EditMode.GetLayouts)
    local index, returned = LayoutIndex(readback, name)
    local good, diffs = E.Verify(layout, returned)
    receipt.diffs = diffs
    if not good then
        receipt.status = "verification-failed"
        state.native = { layoutName = name, sourceName = profileName, status = "failed", time = receipt.time,
            reason = table.concat(diffs, "; ") }
        return false, "Blizzard did not keep the layout \"" .. name .. "\" as built (" .. state.native.reason .. ")."
    end
    receipt.status = "saved"
    state.native = { layoutName = name, sourceName = profileName, status = "saved", select = true, time = receipt.time,
        warnings = report.warnings, diffs = #diffs > 0 and diffs or nil }
    if state.active == profileName then state.active = nil end
    Say(string.format("\"%s\" -> Blizzard layout \"%s\": %d frames%s.", profileName, name, #report.frames,
        baseName and (", other frames and the action bar from \"" .. baseName .. "\"") or ""))
    for _, warning in ipairs(report.warnings) do Say(warning) end
    if #repaired > 0 then Say("Added the controller action bar to " .. table.concat(repaired, ", ") .. ".") end
    if #diffs > 0 then Say(#diffs .. " value(s) were adjusted by Blizzard when saving.") end
    if not activate then
        return true, "Saved. It is selected the next time you use the gamepad UI, or pick it in Edit Mode."
    end
    local selected, reason = Select(state, readback, index, presetCount)
    if not selected then
        receipt.status = "select-failed"
        return false, "Saved, but Blizzard did not select it (" .. reason .. "). Pick \"" .. name .. "\" in Edit Mode."
    end
    receipt.status = "selected"
    return true, '"' .. name .. '" is now your gamepad layout.'
end

-- A layout converted while the keyboard UI was in use is selected here.
local function SelectSaved(state)
    local native = state.native
    local data = Safe(C_EditMode.GetLayouts)
    local _, presetCount = GamepadPreset()
    local index = LayoutIndex(data, native.layoutName)
    if not index or not presetCount then
        native.status, native.reason, native.select = "failed", "the layout was deleted", nil
        return false, "\"" .. native.layoutName .. "\" no longer exists. Type /gpc edit convert to make it again."
    end
    local selected, reason = Select(state, data, index, presetCount)
    if not selected then
        native.select = nil
        return false, "Blizzard did not select \"" .. native.layoutName .. "\" (" .. reason .. "). Pick it in Edit Mode."
    end
    return true, '"' .. native.layoutName .. '" is now your gamepad layout.'
end

-- The gamepad layout Blizzard is using, when the gamepad UI is up. The second
-- result is true when that is Blizzard's preset.
local function ActiveGamepadLayout()
    local data = C_EditMode and Safe(C_EditMode.GetLayouts)
    local _, presetCount = GamepadPreset()
    if not Gamepad() or type(data) ~= "table" or not presetCount or type(data.activeLayout) ~= "number" then return nil end
    if data.activeLayout <= presetCount then return nil, true end
    return data.layouts[data.activeLayout - presetCount]
end

-- Once per session: give every custom gamepad layout the systems of Blizzard's
-- gamepad preset, so each of them has the controller action bar.
local function Repair()
    local data = C_EditMode and Safe(C_EditMode.GetLayouts)
    local preset = GamepadPreset()
    if type(data) ~= "table" or type(data.layouts) ~= "table" or not preset or not C_EditMode.SaveLayouts then return end
    local before = M.Copy(data)
    local names = RepairAll(data, preset)
    if #names == 0 then return end
    Remember({ time = time and time(), character = Safe(UnitGUID, "player"), status = "repaired",
        repaired = names, previousNative = before })
    local ok, err = pcall(C_EditMode.SaveLayouts, data)
    if not ok then Say("Could not update the gamepad layouts: " .. tostring(err)); return end
    Say("Added the controller action bar to " .. table.concat(names, ", ")
        .. " (gamepad layouts saved before build 70338 did not have it). Type /reload if the bar is still missing.")
end

local function Auto()
    scheduled = false
    if attempted or not ready then return end
    local state = State()
    if not state then return end
    -- Wait (until the next event) for the end of combat and Edit Mode.
    if InCombatLockdown() or Editor() or not ManagerReady() then return end
    if not repaired then repaired = true; Repair() end
    local native = state.native
    local convert = state.active and state.profiles[state.active] and not (native and native.status ~= "failed")
    -- A failed conversion is not retried by itself; /gpc edit convert does.
    if native and native.status == "failed" and native.sourceName == state.active then convert = false end
    local selectSaved = native and native.status == "saved" and native.select
    local check = native and native.status == "selected" and not native.checked
    if not convert and not selectSaved and not check then attempted = true; return end
    -- Conversion and selection also wait for the gamepad UI.
    if not Gamepad() then return end
    attempted = true
    local ok, message
    if convert then
        Say("Companion no longer moves frames itself. Converting your Companion layout to a Blizzard Edit Mode layout...")
        ok, message = API.Convert(state.active, true)
    elseif selectSaved then
        ok, message = SelectSaved(state)
    else
        -- A layout selected last session may not have been kept; say so once.
        native.checked = true
        local active = ActiveGamepadLayout()
        if active and active.layoutName ~= native.layoutName then
            message = 'Blizzard is using "' .. tostring(active.layoutName) .. '" for the gamepad. To use "'
                .. native.layoutName .. '", pick it in the layout list at the top of Edit Mode.'
        end
    end
    if message then Say(message) end
end

local function Schedule(delay)
    if attempted or scheduled or not ready then return end
    scheduled = true
    C_Timer.After(delay, Auto)
end

function API.Status()
    local status = API.NativeStatus()
    local active, preset = ActiveGamepadLayout()
    if active then
        local hasBar = false
        for _, system in ipairs(active.systems or {}) do
            if system.system == (Enum.EditModeSystem or {}).GamepadMainActionBar then hasBar = true end
        end
        status = status .. ' Gamepad layout in use: "' .. tostring(active.layoutName) .. '"'
            .. (hasBar and "." or " (no controller action bar in it; /reload adds it).")
    elseif preset then
        status = status .. " Gamepad layout in use: Blizzard's preset."
    end
    return status
end

function API.NativeStatus()
    local state = State()
    local native = state and state.native
    if native and native.status == "selected" then
        return "Your Companion layout is the Blizzard Edit Mode layout \"" .. native.layoutName
            .. "\". Change it in Edit Mode; Blizzard switches layouts with the input mode."
    elseif native and native.status == "saved" then
        return "Your Companion layout is saved as the Blizzard layout \"" .. native.layoutName
            .. "\". It is selected the next time you use the gamepad UI."
    elseif state and state.active and state.profiles[state.active] then
        if native and native.status == "failed" then
            return "Converting \"" .. state.active .. "\" failed: " .. tostring(native.reason) .. ". Type /gpc edit convert to try again."
        end
        return "Your Companion layout \"" .. state.active .. "\" becomes a Blizzard Edit Mode layout the next time you use the gamepad UI."
    end
    return "Use Blizzard Edit Mode in the gamepad UI to move frames. Blizzard keeps a separate layout for the gamepad and switches by itself."
end

function API.List()
    local state = State()
    local names = {}
    for name in pairs(state and state.profiles or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function API.Command(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "convert" then
        local _, result = API.Convert(rest, true)
        if result then Say(result) end
    elseif command == "list" then
        local state = State() or {}
        for _, name in ipairs(API.List()) do
            local native = state.native
            Say("Companion layout: " .. name .. (native and native.sourceName == name and native.status ~= "failed"
                and (" -> Blizzard \"" .. native.layoutName .. "\"") or ""))
        end
        local data = C_EditMode and Safe(C_EditMode.GetLayouts)
        for _, layout in ipairs(data and data.layouts or {}) do
            if layout.interfaceStyle == GamepadStyle() then Say("Blizzard gamepad layout: " .. tostring(layout.layoutName)) end
        end
    else
        Say(API.Status())
        if command ~= "" and command ~= "status" then Say("/gpc edit convert [Companion layout] makes a Blizzard layout; /gpc edit list.") end
    end
end
SLASH_GAMEPADEDITMODE1 = "/gpedit"
SlashCmdList.GAMEPADEDITMODE = API.Command

events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= ADDON then return end
        ready = true
        DB()
        return
    end
    Schedule(event == "PLAYER_ENTERING_WORLD" and 3 or 1)
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "INPUT_DEVICE_INTERFACE_TRANSITION",
    "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED" }) do
    events:RegisterEvent(event)
end
ns.EditModeEventFrame, ns.EditModeAuto = events, Auto
