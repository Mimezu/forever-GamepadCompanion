local _, ns = ...
ns.Model = {}
local M = ns.Model
M.layers = { "base", "lt", "rt", "both" }
M.classLayers = { "classLeft", "classRight" }
-- Standard layout: one entry per native bar. Compact layout: Blizzard stacks the
-- four trigger bars on one anchor and shows only the active one, so a single
-- "bars" entry drives all four there.
M.layoutLayers = { "base", "lt", "rt", "both", "stance", "classLeft", "classRight" }
M.compactLayers = { "bars", "stance", "classLeft", "classRight" }
M.barKeys = { base = "topBar", lt = "leftBar", rt = "rightBar", both = "bottomBar", stance = "stanceBar" }
M.classKeys = { classLeft = "LeftClassAction", classRight = "RightClassAction" }
M.promptKeys = { classLeft = "LeftInputPrompt", classRight = "RightInputPrompt" }
M.modes = { "compact", "standard" }
-- Active zoom was removed in 0.4.0: Blizzard's Edit Mode "Expand" setting on the
-- controller action bar enlarges the selected bar natively.
M.bounds = { x = { -2000, 2000 }, y = { -2000, 2000 }, scale = { 0.5, 2 } }
-- Options window styles: A controller-friendly (default), B Legacy window,
-- C classic. Version 2 swapped A and C; older saves keep the look they had.
M.styles = { A = true, B = true, C = true }
M.styleVersion = 2
function M.OptionsStyle(raw)
    local style = M.styles[raw.optionsStyle] and raw.optionsStyle or "A"
    if raw.optionsStyleVersion ~= M.styleVersion and style == "C" then style = "A" end
    return style
end

-- Which native class-action button each class receives in Forever (Camelot).
M.classButtonUse = {
    DRUID = { classLeft = "Forms" },
    PALADIN = { classLeft = "Auras" },
    WARRIOR = { classRight = "Stances" },
    HUNTER = { classLeft = "Pet", classRight = "Pet spells" },
    WARLOCK = { classLeft = "Pet", classRight = "Pet spells" },
}

function M.Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

function M.Copy(value)
    if not M.Readable(value) then return nil end
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = M.Copy(child) end
    return result
end

function M.Number(value, low, high, fallback)
    if not M.Readable(value) or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    return math.max(low, math.min(high, value))
end

local function Entry(raw)
    raw = type(raw) == "table" and raw or {}
    return {
        x = M.Number(raw.x, -2000, 2000, 0), y = M.Number(raw.y, -2000, 2000, 0),
        scale = M.Number(raw.scale, 0.5, 2, 1),
    }
end
M.Entry = Entry

function M.IsLayer(mode, layer)
    for _, key in ipairs(mode == "compact" and M.compactLayers or M.layoutLayers) do
        if key == layer then return true end
    end
    return false
end

function M.Normalize(raw)
    raw = type(raw) == "table" and raw or {}
    local result = { version = 2, enabled = raw.enabled ~= false, bars = {}, compact = {},
        classPrompts = raw.classPrompts ~= false, optionsStyle = M.OptionsStyle(raw),
        optionsStyleVersion = M.styleVersion }
    local bars = type(raw.bars) == "table" and raw.bars or {}
    for _, layer in ipairs(M.layoutLayers) do result.bars[layer] = Entry(bars[layer]) end
    -- Version 1 saves predate compact mode; its layout starts at native placement.
    local compact = type(raw.compact) == "table" and raw.compact or {}
    for _, layer in ipairs(M.compactLayers) do result.compact[layer] = Entry(compact[layer]) end
    return result
end

-- Settings table for one mode: standard is `bars`, compact is `compact`.
function M.Layout(settings, mode)
    return mode == "compact" and settings.compact or settings.bars
end

-- The entry that actually drives a native layer in the given mode.
function M.Config(settings, mode, layer)
    if mode == "compact" then
        if M.barKeys[layer] and layer ~= "stance" then layer = "bars" end
        return settings.compact[layer]
    end
    return settings.bars[layer]
end

function M.DesiredScale(hostScale, settings)
    return hostScale * settings.scale
end

function M.IsDefault(settings)
    return settings.x == 0 and settings.y == 0 and settings.scale == 1
end

function M.SameState(a, b)
    for key, value in pairs(a) do if b[key] ~= value then return false end end
    for key, value in pairs(b) do if a[key] ~= value then return false end end
    return true
end
