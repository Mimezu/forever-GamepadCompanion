local _, ns = ...
local M, E = ns.Model, {}
ns.NativeLayoutExport = E

local function Number(v)
    return M.Readable(v) and type(v) == "number" and v == v and v > -math.huge and v < math.huge
end
local function Key(s) return tostring(s.system) .. ":" .. tostring(s.systemIndex) end
local points = { CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true,
    TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true }
local function Anchor(a)
    assert(type(a) == "table" and points[a.point] and points[a.relativePoint]
        and type(a.relativeTo) == "string" and a.relativeTo ~= ""
        and Number(a.offsetX) and Number(a.offsetY), "Invalid saved anchor")
    return M.Copy(a)
end

-- Pure conversion: never call frame setters or change native systemInfo/maps.
-- `baseSystems` supplies system membership and every frame Companion never
-- moved (the gamepad preset, overlaid with the gamepad layout in use, so the
-- controller action bar keeps its position and Compact/Expand settings).
-- Companion supplies the saved content. A frame with no native system is
-- skipped and reported; the rest of the layout still converts.
function E.Build(profile, baseSystems, frames, name, layoutType, style)
    assert(type(profile) == "table" and type(profile.frames) == "table", "No Companion profile")
    local layout = { layoutName=name, layoutType=layoutType, interfaceStyle=style, systems=M.Copy(baseSystems) }
    local bySystem, used, report = {}, {}, { frames={}, warnings={}, skipped={} }
    for _, s in ipairs(layout.systems) do bySystem[Key(s)] = s end
    local function Warn(frameName, message)
        report.warnings[#report.warnings+1] = frameName .. ": " .. message
    end
    local names = {}
    for frameName in pairs(profile.frames) do names[#names+1] = frameName end
    table.sort(names)
    for _, frameName in ipairs(names) do
        local entry = profile.frames[frameName]
        local target = frames[frameName]
        if frameName == "GamepadPlayerCastingBarFrame" then target = frames.PlayerCastingBarFrame or target end
        local key = target and target.system ~= nil and Key(target)
        local system = key and bySystem[key]
        if not system or used[key] then
            report.skipped[#report.skipped+1] = frameName
            Warn(frameName, not target and "no Edit Mode system in this client; skipped"
                or used[key] and "shares a system with another saved frame; skipped"
                or "not part of the gamepad layout; skipped")
        else
            used[key] = true
            local settings = {}
            for _, setting in ipairs(system.settings or {}) do settings[setting.setting] = setting end
            assert(type(entry.systemSettings) == "table", "Missing saved native settings: " .. frameName)
            -- Settings this client no longer has would be dropped by Blizzard's
            -- reconcile anyway; only the current ones are carried over.
            for _, saved in ipairs(entry.systemSettings) do
                assert(Number(saved.setting) and Number(saved.value), "Invalid saved setting: " .. frameName)
                if settings[saved.setting] then settings[saved.setting].value = saved.value end
            end
            -- Runtime cosmetic adapters can differ from the original setting array.
            -- Encode those preferences through Blizzard's read-only display metadata.
            local function Display(enum, field, value)
                if value == nil then return end
                local id = enum and enum[field]
                local info = id ~= nil and target.settingDisplayInfoMap and target.settingDisplayInfoMap[id]
                if not (settings[id] and info) then
                    Warn(frameName, field .. " has no Edit Mode setting in this client; kept Blizzard's value")
                    return
                end
                if type(value) == "boolean" then value = value and 1 or 0 end
                assert(Number(value), "Invalid preference: " .. frameName .. "." .. field)
                if ((info.minValue and value < info.minValue - .001)
                    or (info.maxValue and value > info.maxValue + .001)) then
                    -- In particular, a Frame Gambit fade captured as cooldown opacity
                    -- must not become an illegal native slider value.
                    Warn(frameName, field .. " is outside Blizzard's range; kept Blizzard's value")
                    return
                end
                local raw = info.ConvertValue and info:ConvertValue(value) or value
                assert(Number(raw), "Cannot encode preference: " .. frameName .. "." .. field)
                local rounded = math.floor(raw + .5)
                if math.abs(raw-rounded) < .001 then raw = rounded end
                settings[id].value = raw
            end
            local d = entry.details or {}
            if d.kind == "group" then
                Display(Enum.EditModeUnitFrameSetting, "FrameWidth", d.width)
                Display(Enum.EditModeUnitFrameSetting, "FrameHeight", d.height)
            elseif d.kind == "objective" then
                Display(Enum.EditModeObjectiveTrackerSetting, "TextSize", d.textSize)
                Display(Enum.EditModeObjectiveTrackerSetting, "Opacity", d.opacity)
            elseif d.kind == "minimap" then
                Display(Enum.EditModeMinimapSetting, "HeaderUnderneath", d.header)
                Display(Enum.EditModeMinimapSetting, "Size", d.scale and d.scale*100)
            elseif d.kind == "cast" then
                Display(Enum.EditModeCastBarSetting, "ShowCastTime", d.showCastTime)
            elseif d.kind == "cooldown" then
                local fields = { Orientation="orientationSetting", IconLimit="iconLimit", IconDirection="iconDirection",
                    IconSize="iconScale", IconPadding="iconPadding", Opacity="opacity", VisibleSetting="visibleSetting",
                    BarContent="barContent", HideWhenInactive="hideWhenInactive", ShowTimer="timerShown",
                    ShowTooltips="tooltipsShown", BarWidthScale="barWidthScale" }
                for field, member in pairs(fields) do
                    local value = d[member]
                    if value ~= nil and (field == "IconSize" or field == "Opacity" or field == "BarWidthScale") then value=value*100 end
                    Display(Enum.EditModeCooldownViewerSetting, field, value)
                end
            end
            if frameName == "ObjectiveTrackerFrame" then
                Display(Enum.EditModeObjectiveTrackerSetting, "Height", entry.objectiveHeight or d.height or entry.height)
            end
            if entry.ratio and (frameName == "GamepadPlayerCastingBarFrame" or frameName == "PlayerCastingBarFrame") then
                Display(Enum.EditModeCastBarSetting, "BarSize", entry.ratio*100)
            end
            if target.system == (Enum.EditModeSystem or {}).ChatFrame and not entry.settingsOnly and not entry.anchors then
                -- Chat dimensions are four raw integer settings, not ordinary
                -- sliders. Snapshot size can differ from the old setting array.
                for _, dimension in ipairs({{"Width",entry.width},{"Height",entry.height}}) do
                    local value=dimension[2]
                    assert(Number(value) and value > 0 and value < 10000, "Invalid chat dimensions")
                    value=math.floor(value+.5)
                    local hundreds=Enum.EditModeChatFrameSetting[dimension[1].."Hundreds"]
                    local ones=Enum.EditModeChatFrameSetting[dimension[1].."TensAndOnes"]
                    assert(settings[hundreds] and settings[ones], "Native chat size settings unavailable")
                    settings[hundreds].value=math.floor(value/100)
                    settings[ones].value=value%100
                end
            end
            if not entry.settingsOnly then
                system.isInDefaultPosition = false
                system.anchorInfo2 = nil
                if entry.anchors then
                    assert(#entry.anchors >= 1 and #entry.anchors <= 2, "Unsupported anchor count: " .. frameName)
                    system.anchorInfo = Anchor(entry.anchors[1])
                    if entry.anchors[2] then system.anchorInfo2 = Anchor(entry.anchors[2]) end
                else
                    assert(Number(entry.x) and Number(entry.y) and Number(entry.ratio) and entry.ratio > 0,
                        "Invalid saved position: " .. frameName)
                    -- Snapshot offsets already use UIParent coordinates. Blizzard
                    -- divides native anchor offsets by the frame scale on apply.
                    local x, y, point = entry.x, entry.y, "CENTER"
                    if frameName == "ObjectiveTrackerFrame" then
                        point = "TOPLEFT"
                        if not entry.topLeft then
                            assert(Number(entry.width) and Number(entry.height), "Missing tracker size")
                            x, y = x-entry.width*entry.ratio/2, y+entry.height*entry.ratio/2
                        end
                    end
                    system.anchorInfo = {point=point, relativeTo="UIParent", relativePoint="CENTER", offsetX=x, offsetY=y}
                end
            end
            report.frames[#report.frames+1] = frameName
        end
    end
    assert(#report.frames > 0, "Companion profile has no saved frames")
    E.Round(layout)
    return layout, report
end

-- Blizzard keeps setting values as small integers and anchor offsets to one
-- decimal (edit-mode-cache files). Store exactly that, so the saved layout
-- reads back, survives a restart and compares equal.
local function Tenth(v) return math.floor(v*10+.5)/10 end
function E.Round(layout)
    for _, system in ipairs(layout.systems) do
        for _, anchor in ipairs({system.anchorInfo, system.anchorInfo2}) do
            anchor.offsetX, anchor.offsetY = Tenth(anchor.offsetX), Tenth(anchor.offsetY)
        end
        for _, setting in ipairs(system.settings or {}) do setting.value = math.floor(setting.value+.5) end
    end
    return layout
end

-- Compare a saved layout with Blizzard's readback. The first result is false
-- only when the layout itself is wrong (name, kind, controller tag or a
-- missing system); value differences are listed in the second result.
function E.Verify(expected, actual)
    if not actual or actual.interfaceStyle ~= expected.interfaceStyle or actual.layoutType ~= expected.layoutType
        or actual.layoutName ~= expected.layoutName then return false, {"layout name, kind or controller tag differs"} end
    local function Equal(a,b)
        if type(a) ~= type(b) then return false end
        if type(a) == "number" then return math.abs(a-b) < .06 end
        if type(a) ~= "table" then return a == b end
        for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
        return true
    end
    local found, diffs, ok = {}, {}, true
    for _, system in ipairs(actual.systems or {}) do found[Key(system)] = system end
    for _, system in ipairs(expected.systems) do
        local key = Key(system)
        local saved = found[key]
        if not saved then ok = false; diffs[#diffs+1] = key .. " missing"
        else
            if saved.isInDefaultPosition ~= system.isInDefaultPosition
                or not Equal(system.anchorInfo,saved.anchorInfo) or not Equal(system.anchorInfo2,saved.anchorInfo2) then
                diffs[#diffs+1] = key .. " position"
            end
            local settings = {}
            for _, setting in ipairs(saved.settings or {}) do settings[setting.setting] = setting.value end
            for _, setting in ipairs(system.settings or {}) do
                if not Equal(setting.value,settings[setting.setting]) then
                    diffs[#diffs+1] = key .. " setting " .. tostring(setting.setting) .. ": " .. tostring(setting.value)
                        .. " -> " .. tostring(settings[setting.setting])
                end
            end
        end
    end
    return ok, diffs
end
