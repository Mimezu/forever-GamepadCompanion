-- Touchpad zones: the pure part (settings, zones, which keys are bound, the
-- split config, the secure snippet). No game calls here, so tests/Touchpad.lua
-- can run it under lua5.1. The runtime is Touchpad.lua.
--
-- The secure-click method (a real touchpad press clicks a secure button whose
-- snippet reads the finger position and runs that zone's macro) comes from
-- Improved Forever's Touchpad.lua (markgravity, MIT License).
local _, ns = ...
ns = ns or {}
local T = {}
ns.TouchModel = T

-- Two ways to share the pad with Blizzard's own touchpad function
-- (TOGGLEUIFOCUS: an open window takes or gives back the pad):
--   chord: the whole pad is zones while the world has the pad; L1 + touchpad
--          (the modifier L1 emulates) runs Blizzard's function, always.
--   split: the right half becomes button PAD6 (a gamepad config) and is all
--          zones; the left half stays Blizzard's PADBACK, untouched.
T.MODES = { chord = true, split = true }
T.MODE_ALIASES = { b = "chord", chord = "chord", a = "split", split = "split" }

-- Zones are a grid: "r<row>c<col>", row 1 at the top. chord covers the whole
-- pad; split covers the right half only.
T.GRID_LIMITS = { chord = { cols = 4, rows = 3 }, split = { cols = 2, rows = 4 } }
T.DEFAULT_GRID = { chord = { cols = 3, rows = 2 }, split = { cols = 1, rows = 3 } }
-- Swipes: the finger moves at least SWIPE_MIN (the pad is 2 wide) while pressed
T.GESTURES = { "swipe-up", "swipe-down", "swipe-left", "swipe-right" }
T.GESTURE_LABELS = { ["swipe-up"] = "Swipe up", ["swipe-down"] = "Swipe down",
    ["swipe-left"] = "Swipe left", ["swipe-right"] = "Swipe right" }
T.SWIPE_MIN = 0.6

function T.ZoneId(row, col) return "r" .. row .. "c" .. col end

-- Every zone id a mode can have (its largest grid)
T.ALL_ZONES = {}
for mode, limit in pairs(T.GRID_LIMITS) do
    T.ALL_ZONES[mode] = {}
    for row = 1, limit.rows do
        for col = 1, limit.cols do T.ALL_ZONES[mode][#T.ALL_ZONES[mode] + 1] = T.ZoneId(row, col) end
    end
end

-- The grid a settings table uses for a mode
function T.Grid(settings, mode)
    local g = settings and settings.grid and settings.grid[mode]
    return g or T.DEFAULT_GRID[mode]
end

-- The zones in use, row by row
function T.Zones(settings, mode)
    mode = mode or settings.mode
    local g, list = T.Grid(settings, mode), {}
    for row = 1, g.rows do
        for col = 1, g.cols do list[#list + 1] = T.ZoneId(row, col) end
    end
    return list
end

local ROW_NAMES = { [2] = { "Top", "Bottom" }, [3] = { "Top", "Middle", "Bottom" } }
local COL_NAMES = { [2] = { "left", "right" }, [3] = { "left", "centre", "right" } }
-- "Top left", "Middle", "Row 2, column 4", "Whole pad"
function T.ZoneLabel(zone, grid)
    local gesture = T.GESTURE_LABELS[zone]
    if gesture then return gesture end
    local row, col = tostring(zone):match("^r(%d)c(%d)$")
    row, col = tonumber(row), tonumber(col)
    if not row then return tostring(zone) end
    grid = grid or { cols = 4, rows = 4 }
    local r = ROW_NAMES[grid.rows] and ROW_NAMES[grid.rows][row]
    local c = COL_NAMES[grid.cols] and COL_NAMES[grid.cols][col]
    if grid.rows == 1 and grid.cols == 1 then return "Whole pad" end
    if grid.rows == 1 then return c and (c:sub(1, 1):upper() .. c:sub(2)) or ("Column " .. col) end
    if grid.cols == 1 then return r or ("Row " .. row) end
    if r and c then return r .. " " .. c end
    return "Row " .. row .. ", column " .. col
end

-- As the crossbar's: Base, L2 held, R2 held, both held
T.LAYERS = { "base", "lt", "rt", "both" }
T.LAYER_LABELS = { base = "Base", lt = "L2", rt = "R2", both = "L2 + R2" }

-- Old zone names (0.5.0)
T.OLD_ZONES = {
    chord = { tl = "r1c1", tc = "r1c2", tr = "r1c3", bl = "r2c1", bc = "r2c2", br = "r2c3" },
    split = { top = "r1c1", mid = "r2c1", bot = "r3c1" },
}


T.PAD_STICK = 4            -- the touchpad's finger position (PStick)
T.PAD_KEY = "PADBACK"      -- the touchpad click, both halves by default
T.SPLIT_KEY = "PAD6"       -- the right half, in split mode (unused by the game)
T.NATIVE_ACTION = "TOGGLEUIFOCUS"
T.DEFAULT_CHORD_BUTTON = "PADLSHOULDER"

-- Modifier prefixes in the game's order; the CVar that makes a pad button act as each
T.MODIFIERS = { "ALT", "CTRL", "SHIFT" }
T.EMULATE_CVARS = { ALT = "GamePadEmulateAlt", CTRL = "GamePadEmulateCtrl", SHIFT = "GamePadEmulateShift" }

local DEFAULT_ACTIONS = {
    chord = { base = { r1c1 = "window:character", r1c2 = "window:spellbook", r1c3 = "window:questlog",
        r2c1 = "window:talents", r2c2 = "window:professions", r2c3 = "window:bags" } },
    split = { base = { r1c1 = "window:character", r2c1 = "window:questlog", r3c1 = "window:bags" } },
}

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end
T.Copy = Copy

local function ValidAction(action)
    return type(action) == "string" and action:match("^(%a+):(.+)$") ~= nil
end
T.ValidAction = ValidAction

local function Clamp(value, low, high, default)
    value = tonumber(value)
    if not value then return default end
    value = math.floor(value)
    return value < low and low or (value > high and high or value)
end

function T.Normalize(raw)
    raw = type(raw) == "table" and raw or {}
    local out = {
        version = 2,
        enabled = raw.enabled == true,
        mode = T.MODES[raw.mode] and raw.mode or "chord",
        preview = raw.preview ~= false,
        tap = raw.tap == true,
        tapSaved = raw.tapSaved,
        chordButton = type(raw.chordButton) == "string" and raw.chordButton or T.DEFAULT_CHORD_BUTTON,
        actions = {},
        split = type(raw.split) == "table" and Copy(raw.split) or {},
        grid = {},
    }
    for mode, limit in pairs(T.GRID_LIMITS) do
        local g = type(raw.grid) == "table" and type(raw.grid[mode]) == "table" and raw.grid[mode] or {}
        out.grid[mode] = { cols = Clamp(g.cols, 1, limit.cols, T.DEFAULT_GRID[mode].cols),
            rows = Clamp(g.rows, 1, limit.rows, T.DEFAULT_GRID[mode].rows) }
    end
    local actions = type(raw.actions) == "table" and raw.actions or nil
    for mode in pairs(T.MODES) do
        out.actions[mode] = {}
        local saved = actions and type(actions[mode]) == "table" and actions[mode] or nil
        for _, layer in ipairs(T.LAYERS) do
            local layerSaved = saved and type(saved[layer]) == "table" and saved[layer] or nil
            local defaults = not saved and DEFAULT_ACTIONS[mode][layer] or nil
            out.actions[mode][layer] = {}
            local function Take(zone, action)
                -- ("none": cleared by the player, kept so defaults don't come back)
                if action == "none" or ValidAction(action) then out.actions[mode][layer][zone] = action end
            end
            if layerSaved == nil and defaults then
                for zone, action in pairs(defaults) do Take(zone, action) end
            elseif layerSaved then
                for old, zone in pairs(T.OLD_ZONES[mode]) do
                    if layerSaved[zone] == nil then Take(zone, layerSaved[old]) end
                end
                for _, zone in ipairs(T.ALL_ZONES[mode]) do
                    if layerSaved[zone] ~= nil then Take(zone, layerSaved[zone]) end
                end
                for _, gesture in ipairs(T.GESTURES) do Take(gesture, layerSaved[gesture]) end
            end
        end
    end
    return out
end

-- A zone of the grid in use, or a swipe
function T.IsZone(settings, mode, zone)
    for _, z in ipairs(T.Zones(settings, mode)) do if z == zone then return true end end
    for _, g in ipairs(T.GESTURES) do if g == zone then return true end end
    return false
end

-- Whether any layer of a mode has a swipe set (then zones act on release)
function T.HasSwipes(settings, mode)
    for _, layer in ipairs(T.LAYERS) do
        for _, g in ipairs(T.GESTURES) do
            local a = settings.actions[mode][layer][g]
            if a and a ~= "none" then return true end
        end
    end
    return false
end

function T.IsLayer(layer)
    for _, l in ipairs(T.LAYERS) do if l == layer then return true end end
    return false
end

-- The zone under a finger at x, y (-1..1, y up); the snippet below does the same
function T.ZoneAt(mode, x, y, grid)
    grid = grid or T.DEFAULT_GRID[mode]
    local left, width = -1, 2
    if mode == "split" then left, width = 0, 1 end
    local col, row = grid.cols, grid.rows
    for i = 1, grid.cols do if x < left + width * i / grid.cols then col = i; break end end
    for i = 1, grid.rows do if y > 1 - 2 * i / grid.rows then row = i; break end end
    return T.ZoneId(row, col)
end

-- The swipe from (x0, y0) to (x, y), or nil for a tap
function T.SwipeOf(x0, y0, x, y, min)
    local dx, dy = x - x0, y - y0
    min = min or T.SWIPE_MIN
    if dx * dx + dy * dy < min * min then return nil end
    local ax, ay = dx < 0 and -dx or dx, dy < 0 and -dy or dy
    if ax > ay then return dx > 0 and "swipe-right" or "swipe-left" end
    return dy > 0 and "swipe-up" or "swipe-down"
end

-- The layer from the triggers held
function T.LayerOf(lt, rt)
    if lt and rt then return "both" end
    return lt and "lt" or (rt and "rt" or "base")
end

-- Every prefix of the three modifiers ("", "ALT-", ..., "ALT-CTRL-SHIFT-")
function T.Prefixes()
    local list = {}
    for mask = 0, 7 do
        local prefix = ""
        for i, mod in ipairs(T.MODIFIERS) do
            if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then prefix = prefix .. mod .. "-" end
        end
        list[#list + 1] = prefix
    end
    return list
end

-- The modifier a pad button emulates ("CTRL"), from the CVars' values, or nil
function T.ModifierFor(button, emulate)
    for _, mod in ipairs(T.MODIFIERS) do
        if emulate and emulate[mod] == button then return mod end
    end
end

--[[ The bindings wanted now. env:
  padStyle   "Shapes" for a PlayStation pad
  ours       chord mode: the world has the pad (nothing focused), so the plain click is zones
  conflict   another addon's touchpad zones are on (Improved Forever): chord mode yields
  emulate    { ALT = button, CTRL = button, SHIFT = button } (the GamePadEmulate CVars)
  splitReady split mode: PAD6 is in place
Returns { { key, click = true } | { key, action = "TOGGLEUIFOCUS" } }, and a note. ]]
function T.BindingPlan(settings, env)
    local plan = {}
    if not settings.enabled then return plan, nil end
    if env.padStyle ~= "Shapes" then return plan, "not a PlayStation controller" end
    if settings.mode == "split" then
        if not env.splitReady then return plan, "the right half isn't PAD6 yet" end
        for _, prefix in ipairs(T.Prefixes()) do
            plan[#plan + 1] = { key = prefix .. T.SPLIT_KEY, click = true }
        end
        return plan, nil
    end
    if env.conflict then return plan, "Improved Forever's touchpad corners are on" end
    local chordMod = T.ModifierFor(settings.chordButton, env.emulate)
    for _, prefix in ipairs(T.Prefixes()) do
        local key = prefix .. T.PAD_KEY
        if chordMod and prefix:find(chordMod .. "-", 1, true) then
            plan[#plan + 1] = { key = key, action = T.NATIVE_ACTION }
        elseif env.ours then
            plan[#plan + 1] = { key = key, click = true }
        end
    end
    return plan, not chordMod and "no modifier on " .. settings.chordButton .. ": no chord for Blizzard's function" or nil
end

-- A gamepad config with the touchpad's right half on PAD6: a copy of config,
-- or nil when it has no right half to move. Found by its comment, else raw
-- button 22 (DualSense 1356:3302).
function T.SplitConfig(config)
    if type(config) ~= "table" or type(config.rawButtonMappings) ~= "table" then return nil end
    local out = Copy(config)
    local target
    for _, m in ipairs(out.rawButtonMappings) do
        if type(m.comment) == "string" and m.comment:find("TouchPad right side", 1, true) then target = m end
    end
    if not target and out.configID and out.configID.vendorID == 1356 and out.configID.productID == 3302 then
        for _, m in ipairs(out.rawButtonMappings) do if m.rawIndex == 22 then target = m end end
    end
    if not target then return nil end
    target.button = T.SPLIT_KEY
    return out
end

-- Whether a config has the right half on PAD6 already
function T.IsSplit(config)
    if type(config) ~= "table" or type(config.rawButtonMappings) ~= "table" then return false end
    for _, m in ipairs(config.rawButtonMappings) do
        if m.button == T.SPLIT_KEY then return true end
    end
    return false
end

-- A config's button mappings as one string, to tell two configs apart
function T.Signature(config)
    if type(config) ~= "table" or type(config.rawButtonMappings) ~= "table" then return "" end
    local parts = {}
    for _, m in ipairs(config.rawButtonMappings) do
        parts[#parts + 1] = tostring(m.rawIndex) .. "=" .. tostring(m.button)
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- The client's default DualSense config (WTF\GamePadConfig_Default.json, client
-- 1.60.1), used when C_GamePad.GetConfig has none to start from
function T.DualSenseDefault()
    local buttons = { "PAD1", "PAD2", "PAD3", "PAD4", "PADSOCIAL", "PADSYSTEM", "PADFORWARD", "PADLSTICK",
        "PADRSTICK", "PADLSHOULDER", "PADRSHOULDER", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD5",
        "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4" }
    local raw = {}
    for i, button in ipairs(buttons) do raw[i] = { rawIndex = i - 1, button = button } end
    raw[#raw + 1] = { rawIndex = 20, button = "None", comment = "TouchPad hardware button" }
    raw[#raw + 1] = { rawIndex = 21, button = "PADBACK",
        comment = "TouchPad left side (Also if hardware button clicked, but no touch detected)" }
    raw[#raw + 1] = { rawIndex = 22, button = "PADBACK", comment = "TouchPad right side" }
    local axes = { "LStickX", "LStickY", "RStickX", "RStickY", "LTrigger", "RTrigger", "GStickX", "GStickY",
        "PStickX", "PStickY" }
    local rawAxes = {}
    for i, axis in ipairs(axes) do rawAxes[i] = { rawIndex = i - 1, axis = axis } end
    local axisConfigs = {
        { axis = "LStickX", shift = 0, scale = 1 }, { axis = "LStickY", shift = 0, scale = -1 },
        { axis = "RStickX", shift = 0, scale = 1 }, { axis = "RStickY", shift = 0, scale = -1 },
        { axis = "GStickX", shift = 0, scale = 1 }, { axis = "GStickY", shift = 0, scale = 1 },
        { axis = "PStickX", shift = -0.5, scale = 2 }, { axis = "PStickY", shift = -0.5, scale = -2 },
        { axis = "LTrigger", shift = 0, scale = 1 }, { axis = "RTrigger", shift = 0, scale = 1 },
    }
    return {
        configID = { vendorID = 1356, productID = 3302 },
        comment = "Default Configuration for a 1356:3302 'DualSense Wireless Controller'",
        labelStyle = "Shapes",
        rawButtonMappings = raw, rawAxisMappings = rawAxes, axisConfigs = axisConfigs, stickConfigs = {},
    }
end

--[[ What the secure click runs, for the button's OnClick wrap (pre-body: self,
button, down). Attributes, set out of combat by Touchpad.lua:
  gpc-mode      "chord" | "split"
  gpc-cols/rows the grid
  gpc-stick     the touchpad's stick index
  gpc-lt/rt     the triggers' button indexes in GetGamePadState().buttons
  gpc-keydown   1: act on the press (ActionButtonUseKeyDown), 0: on the release
  gpc-swipe     1: swipes are set, so act on the release (the finger may move)
  gpc-swipe-min how far the finger moves for a swipe
  gpc-m-<layer>-<zone>  that zone's (or swipe's) macro text
useOnKeyDown follows, so the secure button runs the macro on the same half of
the click (it ignores the other half). It acts once per click (both halves of the pad can report the same press, so
a held flag debounces: the restricted environment has no clock). The zone is
where the press started. A layer with nothing there falls back to Base. ]]
T.SNIPPET = [[
    self:SetAttribute("type", nil)
    local swipes = self:GetAttribute("gpc-swipe") == 1
    local keydown = self:GetAttribute("gpc-keydown") ~= 0 and not swipes
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[self:GetAttribute("gpc-stick")]
    local x, y = stick and stick.x or 0, stick and stick.y or 0
    if down then
        if self:GetAttribute("gpc-held") then
            return false
        end
        self:SetAttribute("gpc-held", true)
        self:SetAttribute("useOnKeyDown", keydown)
        self:SetAttribute("gpc-x0", x)
        self:SetAttribute("gpc-y0", y)
        if not keydown then
            return false
        end
    else
        if not self:GetAttribute("gpc-held") then
            return false
        end
        self:SetAttribute("gpc-held", nil)
        if keydown then
            return false
        end
    end
    local x0, y0 = self:GetAttribute("gpc-x0") or x, self:GetAttribute("gpc-y0") or y
    local zone
    if swipes and not down then
        local dx, dy = x - x0, y - y0
        local min = self:GetAttribute("gpc-swipe-min") or 0.6
        if dx * dx + dy * dy >= min * min then
            local ax, ay = dx < 0 and -dx or dx, dy < 0 and -dy or dy
            if ax > ay then
                zone = dx > 0 and "swipe-right" or "swipe-left"
            else
                zone = dy > 0 and "swipe-up" or "swipe-down"
            end
        end
    end
    if not zone then
        local cols, rows = self:GetAttribute("gpc-cols") or 1, self:GetAttribute("gpc-rows") or 1
        local left, width = -1, 2
        if self:GetAttribute("gpc-mode") == "split" then
            left, width = 0, 1
        end
        local col, row = cols, rows
        for i = 1, cols do
            if x0 < left + width * i / cols then
                col = i
                break
            end
        end
        for i = 1, rows do
            if y0 > 1 - 2 * i / rows then
                row = i
                break
            end
        end
        zone = "r" .. row .. "c" .. col
    end
    local pad = state and state.buttons
    local lti, rti = self:GetAttribute("gpc-lt"), self:GetAttribute("gpc-rt")
    local lt = pad and lti and pad[lti] and true or false
    local rt = pad and rti and pad[rti] and true or false
    local layer = (lt and rt and "both") or (lt and "lt") or (rt and "rt") or "base"
    local macro = self:GetAttribute("gpc-m-" .. layer .. "-" .. zone)
    if not macro and layer ~= "base" then
        macro = self:GetAttribute("gpc-m-base-" .. zone)
    end
    self:SetAttribute("gpc-zone", zone)
    self:SetAttribute("gpc-layer", layer)
    if not macro then
        return false
    end
    self:SetAttribute("macrotext", macro)
    self:SetAttribute("type", "macro")
]]

-- The game windows a zone can open: the game's own button for each (the first
-- one this client has), clicked by the zone's macro. List adapted from
-- Improved Forever's Actions.lua (MIT).
local R = "gamepad-radial-icon-"
T.WINDOWS = {
    { key = "character", label = "Character", atlas = R .. "character", icon = "Interface\\Icons\\INV_Chest_Cloth_17",
        buttons = { "CharacterMicroButton" } },
    { key = "bags", label = "Bags", atlas = R .. "bags", icon = "Interface\\Icons\\INV_Misc_Bag_08",
        buttons = { "MainMenuBarBackpackButton", "BagsBarBackpackButton" } },
    { key = "spellbook", label = "Spellbook", atlas = R .. "spellbook", icon = "Interface\\Icons\\INV_Misc_Book_09",
        buttons = { "SpellbookMicroButton", "PlayerSpellsMicroButton" } },
    { key = "talents", label = "Talents", atlas = R .. "talents", icon = "Interface\\Icons\\Ability_Marksmanship",
        buttons = { "TalentMicroButton", "PlayerSpellsMicroButton" } },
    { key = "professions", label = "Professions", atlas = R .. "professions", icon = "Interface\\Icons\\Trade_BlackSmithing",
        buttons = { "ProfessionMicroButton" } },
    { key = "questlog", label = "Quests & Map", atlas = R .. "quests", icon = "Interface\\Icons\\INV_Misc_Book_08",
        buttons = { "QuestLogMicroButton" } },
    { key = "map", label = "World Map", icon = "Interface\\Icons\\INV_Misc_Map_01",
        buttons = { "WorldMapMicroButton", "MiniMapWorldMapButton" } },
    { key = "social", label = "Social", atlas = R .. "social", icon = "Interface\\Icons\\INV_Misc_GroupLooking",
        buttons = { "SocialsMicroButton", "FriendsMicroButton" } },
    { key = "guild", label = "Communities", atlas = R .. "communities", icon = "Interface\\Icons\\INV_BannerPVP_02",
        buttons = { "CommunitiesMicroButton", "GuildMicroButton" } },
    { key = "groupfinder", label = "Group Finder", atlas = R .. "groupfinder", icon = "Interface\\Icons\\INV_Misc_Eye_01",
        buttons = { "LFGMicroButton", "LFDMicroButton", "GroupFinderMicroButton" } },
    { key = "collections", label = "Collections", atlas = R .. "collections", icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
        buttons = { "CollectionsMicroButton" } },
    { key = "gamemenu", label = "Game Menu", atlas = R .. "gamemenu", icon = "Interface\\Icons\\INV_Misc_Gear_01",
        buttons = { "MainMenuMicroButton" } },
}
T.WINDOW_BY_KEY = {}
for _, w in ipairs(T.WINDOWS) do T.WINDOW_BY_KEY[w.key] = w end

--[[ A zone's macro text, or nil. lookup has the game calls:
  button(name)   true when that global button exists
  spellName(id), macroBody(name) ]]
function T.MacroText(action, lookup)
    if not ValidAction(action) then return nil end
    local kind, value = action:match("^(%a+):(.+)$")
    if kind == "window" then
        local w = T.WINDOW_BY_KEY[value]
        for _, name in ipairs(w and w.buttons or {}) do
            if lookup.button(name) then return "/click " .. name end
        end
    elseif kind == "spell" then
        local name = lookup.spellName(tonumber(value))
        return name and ("/cast " .. name) or nil
    elseif kind == "item" then
        return tonumber(value) and ("/use item:" .. value) or nil
    elseif kind == "macro" then
        return lookup.macroBody(value)
    elseif kind == "text" then
        return value
    end
end

return T
