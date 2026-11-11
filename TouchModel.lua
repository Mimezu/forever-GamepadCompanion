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

T.ZONES = {
    chord = { "tl", "tc", "tr", "bl", "bc", "br" },   -- the whole pad, 3 x 2
    split = { "top", "mid", "bot" },                  -- the right half, 3 rows
}
T.ZONE_LABELS = {
    tl = "Top left", tc = "Top centre", tr = "Top right",
    bl = "Bottom left", bc = "Bottom centre", br = "Bottom right",
    top = "Top", mid = "Middle", bot = "Bottom",
}
-- As the crossbar's: Base, L2 held, R2 held, both held
T.LAYERS = { "base", "lt", "rt", "both" }
T.LAYER_LABELS = { base = "Base", lt = "L2", rt = "R2", both = "L2 + R2" }

-- (column edges of the 3 x 2 grid, row edges of the 3 rows; x and y run -1..1)
T.EDGE = 1 / 3

T.PAD_STICK = 4            -- the touchpad's finger position (PStick)
T.PAD_KEY = "PADBACK"      -- the touchpad click, both halves by default
T.SPLIT_KEY = "PAD6"       -- the right half, in split mode (unused by the game)
T.NATIVE_ACTION = "TOGGLEUIFOCUS"
T.DEFAULT_CHORD_BUTTON = "PADLSHOULDER"

-- Modifier prefixes in the game's order; the CVar that makes a pad button act as each
T.MODIFIERS = { "ALT", "CTRL", "SHIFT" }
T.EMULATE_CVARS = { ALT = "GamePadEmulateAlt", CTRL = "GamePadEmulateCtrl", SHIFT = "GamePadEmulateShift" }

local DEFAULT_ACTIONS = {
    chord = { base = { tl = "window:character", tc = "window:spellbook", tr = "window:questlog",
        bl = "window:talents", bc = "window:professions", br = "window:bags" } },
    split = { base = { top = "window:character", mid = "window:questlog", bot = "window:bags" } },
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

function T.Normalize(raw)
    raw = type(raw) == "table" and raw or {}
    local out = {
        version = 1,
        enabled = raw.enabled == true,
        mode = T.MODES[raw.mode] and raw.mode or "chord",
        preview = raw.preview ~= false,
        chordButton = type(raw.chordButton) == "string" and raw.chordButton or T.DEFAULT_CHORD_BUTTON,
        actions = {},
        split = type(raw.split) == "table" and Copy(raw.split) or {},
    }
    local actions = type(raw.actions) == "table" and raw.actions or nil
    for mode, zones in pairs(T.ZONES) do
        out.actions[mode] = {}
        local saved = actions and type(actions[mode]) == "table" and actions[mode] or nil
        for _, layer in ipairs(T.LAYERS) do
            local layerSaved = saved and type(saved[layer]) == "table" and saved[layer] or nil
            local defaults = not saved and DEFAULT_ACTIONS[mode][layer] or nil
            out.actions[mode][layer] = {}
            for _, zone in ipairs(zones) do
                local action = layerSaved and layerSaved[zone]
                if layerSaved == nil and defaults then action = defaults[zone] end
                -- ("none": cleared by the player, kept so defaults don't come back)
                if action == "none" or ValidAction(action) then out.actions[mode][layer][zone] = action end
            end
        end
    end
    return out
end

function T.IsZone(mode, zone)
    for _, z in ipairs(T.ZONES[mode] or {}) do if z == zone then return true end end
    return false
end

function T.IsLayer(layer)
    for _, l in ipairs(T.LAYERS) do if l == layer then return true end end
    return false
end

-- The zone under a finger at x, y (the snippet below does the same)
function T.ZoneAt(mode, x, y)
    if mode == "split" then
        return y > T.EDGE and "top" or (y < -T.EDGE and "bot" or "mid")
    end
    return (y > 0 and "t" or "b") .. (x < -T.EDGE and "l" or (x > T.EDGE and "r" or "c"))
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
  gpc-stick     the touchpad's stick index
  gpc-lt/rt     the triggers' button indexes in GetGamePadState().buttons
  gpc-keydown   1: act on the press (ActionButtonUseKeyDown), 0: on the release
  gpc-m-<layer>-<zone>  that zone's macro text
It acts once per click (both halves of the pad can report the same press, so
a held flag debounces: the restricted environment has no clock). A layer with
nothing on that zone falls back to Base. ]]
T.SNIPPET = [[
    self:SetAttribute("type", nil)
    local keydown = self:GetAttribute("gpc-keydown") ~= 0
    if down then
        if self:GetAttribute("gpc-held") then
            return false
        end
        self:SetAttribute("gpc-held", true)
        self:SetAttribute("useOnKeyDown", nil)
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
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[self:GetAttribute("gpc-stick")]
    local x, y = stick and stick.x or 0, stick and stick.y or 0
    local edge = 1 / 3
    local zone
    if self:GetAttribute("gpc-mode") == "split" then
        zone = (y > edge and "top") or (y < -edge and "bot") or "mid"
    else
        zone = (y > 0 and "t" or "b") .. ((x < -edge and "l") or (x > edge and "r") or "c")
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
    end
end

return T
