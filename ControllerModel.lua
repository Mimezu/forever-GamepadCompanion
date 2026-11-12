-- The Controller page's data: where each DualSense button sits on the line art,
-- which gamepad bar slot it is on each layer, and the storage slot behind it.
-- Pure logic, no frames.
local _, ns = ...
local C = {}
ns.ControllerModel = C

C.TEXTURE = "Interface\\AddOns\\GamepadCompanion\\art\\DualSense"
-- The art fills the top 1024 x 680 of a 1024 x 1024 texture (art/make_dualsense.py)
C.ART_W, C.ART_H, C.TEX_SIZE = 1024, 680, 1024

C.LAYERS = { "base", "lt", "rt", "both" }
C.LAYER_LABELS = { base = "Base", lt = "L2", rt = "R2", both = "L2 + R2" }
-- Blizzard's bars: top (no trigger), left (L2), right (R2), bottom (both)
C.BAR_INDEX = { base = 1, lt = 2, rt = 3, both = 4 }
C.PAGES = 3
C.SLOTS_PER_BAR = 8
-- Slot sizes on the art: d-pad squares, face circles
C.SQUARE, C.CIRCLE = 72, 78

-- A Blizzard gamepad glyph as text
function C.Glyph(name, size)
    size = size or 16
    return ("|A:Gamepad_%s_%d:%d:%d|a"):format(name, size > 20 and 64 or 32, size, size)
end
C.LAYER_GLYPHS = { base = nil, lt = { "Shp_LTrigger" }, rt = { "Shp_RTrigger" }, both = { "Shp_LTrigger", "Shp_RTrigger" } }

-- Bar slots in Blizzard's order (Bindings.xml: 1-4 the d-pad left, up,
-- right, down; 5-8 the face buttons left, up, right, down). x, y on the art.
C.SLOTS = {
    { slot = 1, key = "PADDLEFT", name = "Left", glyph = "Shp_Left", x = 124, y = 272, shape = "square" },
    { slot = 2, key = "PADDUP", name = "Up", glyph = "Shp_Up", x = 198, y = 198, shape = "square" },
    { slot = 3, key = "PADDRIGHT", name = "Right", glyph = "Shp_Right", x = 272, y = 272, shape = "square" },
    { slot = 4, key = "PADDDOWN", name = "Down", glyph = "Shp_Down", x = 198, y = 346, shape = "square" },
    { slot = 5, key = "PAD3", name = "Square", glyph = "Shp_Square", x = 750, y = 272, shape = "circle" },
    { slot = 6, key = "PAD4", name = "Triangle", glyph = "Shp_Triangle", x = 826, y = 196, shape = "circle" },
    { slot = 7, key = "PAD2", name = "Circle", glyph = "Shp_Circle", x = 902, y = 272, shape = "circle" },
    { slot = 8, key = "PAD1", name = "Cross", glyph = "Shp_Cross", x = 826, y = 348, shape = "circle" },
}

-- The base bar's face buttons are Blizzard's own (MainActionBarFrame.lua)
C.FIXED = {
    [5] = { name = "Interact", icon = "Interface\\Cursor\\Interact" },
    [6] = { name = "Target menu", icon = "Interface\\Cursor\\Inspect" },
    [7] = { name = "Back", atlas = "128-redbutton-exit" },
    [8] = { name = "Jump", atlas = "gamepad-ability-icon-jump" },
}

-- The other buttons. role: "layer" (L2 / R2 pick a bar), "touchpad",
-- or "binding" (whatever the game binds there). w, h: the hit box on the art.
C.BUTTONS = {
    { id = "l2", key = "PADLTRIGGER", name = "L2", glyph = "Shp_LTrigger", role = "layer", layer = "lt", x = 212, y = 44, w = 130, h = 56 },
    { id = "r2", key = "PADRTRIGGER", name = "R2", glyph = "Shp_RTrigger", role = "layer", layer = "rt", x = 812, y = 44, w = 130, h = 56 },
    { id = "l1", key = "PADLSHOULDER", name = "L1", glyph = "Shp_LShoulder", role = "binding", x = 212, y = 83, w = 164, h = 42 },
    { id = "r1", key = "PADRSHOULDER", name = "R1", glyph = "Shp_RShoulder", role = "binding", x = 812, y = 83, w = 164, h = 42 },
    { id = "create", key = "PADSOCIAL", name = "Create", glyph = "Shp_Share", role = "binding", x = 308, y = 124, w = 40, h = 52 },
    { id = "options", key = "PADFORWARD", name = "Options", glyph = "Shp_Menu", role = "binding", x = 716, y = 124, w = 40, h = 52 },
    { id = "touchpad", key = "PADBACK", name = "Touchpad", glyph = "Shp_TouchpadL", role = "touchpad", x = 512, y = 192, w = 320, h = 176 },
    { id = "l3", key = "PADLSTICK", name = "L3", glyph = "Shp_LStickIn", role = "binding", x = 382, y = 392, w = 124, h = 124 },
    { id = "r3", key = "PADRSTICK", name = "R3", glyph = "Shp_RStickIn", role = "binding", x = 642, y = 392, w = 124, h = 124 },
    { id = "ps", key = "PADSYSTEM", name = "PS", glyph = "Shp_System", role = "binding", x = 512, y = 372, w = 40, h = 40 },
    { id = "mute", key = "PAD5", name = "Mute", glyph = "Shp_MicMute", role = "binding", x = 512, y = 421, w = 52, h = 22 },
}
C.BUTTON_BY_ID = {}
for _, b in ipairs(C.BUTTONS) do C.BUTTON_BY_ID[b.id] = b end
C.TOUCHPAD_RECT = { x0 = 360, y0 = 112, x1 = 664, y1 = 272 }

-- Names for the gamepad commands the game binds to these buttons
C.COMMAND_NAMES = {
    GAMEPADLEFTMOD = "L2 bar", GAMEPADRIGHTMOD = "R2 bar",
    GAMEPADLEFTTARGETMODIFIER = "Target bar", GAMEPADRIGHTTARGETMODIFIER = "Target bar",
    OPENRADIAL = "Radial", TOGGLEUIFOCUS = "Focus UI", TOGGLEPINGSYSTEM = "Ping",
    TOGGLEGAMEMENU = "Game menu", TOGGLESOCIAL = "Social", TOGGLEWORLDMAP = "World Map",
    TARGETNEARESTENEMY = "Target enemy", TARGETNEARESTFRIEND = "Target friend",
    TOGGLEAUTORUN = "Auto-run", JUMP = "Jump", INTERACTTARGET = "Interact",
    TOGGLECHARACTER0 = "Character", OPENALLBAGS = "Bags", TOGGLEBACKPACK = "Bags",
    CAMERAZOOMIN = "Zoom in", CAMERAZOOMOUT = "Zoom out", TOGGLEMUSIC = "Music",
}
-- Commands looked up by key too, for bindings GetBindingAction doesn't report
C.LOOKUP_COMMANDS = {
    "GAMEPADLEFTMOD", "GAMEPADRIGHTMOD", "GAMEPADLEFTTARGETMODIFIER", "GAMEPADRIGHTTARGETMODIFIER",
    "OPENRADIAL", "TOGGLEUIFOCUS", "TOGGLEPINGSYSTEM", "TOGGLEGAMEMENU",
}

function C.IsLayer(layer) return C.BAR_INDEX[layer] ~= nil end

-- The slot id on Blizzard's page unit (1-32): the bar's 8 in a row
function C.PageUnitSlot(layer, slot)
    local bar = C.BAR_INDEX[layer]
    if not bar or type(slot) ~= "number" or slot < 1 or slot > C.SLOTS_PER_BAR then return nil end
    return (bar - 1) * C.SLOTS_PER_BAR + slot
end

-- Blizzard's own buttons (no action): the base bar's face buttons
function C.Fixed(layer, slot)
    if layer ~= "base" then return nil end
    return C.FIXED[slot]
end

-- k: { first, perPage, reserved, pages } from the client
-- (ActionBindingUtil.lua's GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID)
function C.StorageSlot(page, layer, slot, k)
    if type(k) ~= "table" or type(k.first) ~= "number" then return nil end
    local id = C.PageUnitSlot(layer, slot)
    if not id or type(page) ~= "number" or page < 1 or page > (k.pages or C.PAGES) then return nil end
    local reserved, firstReserved = k.reserved or 4, 5
    if id >= firstReserved and id < firstReserved + reserved then return nil end
    local storage = k.first + k.perPage * (page - 1) + (id - 1) - reserved * (page - 1)
    if id >= firstReserved then storage = storage - reserved end
    return storage
end

-- The client's numbers, or nil
function C.Constants()
    local c = Constants and Constants.GamepadActionBarConstants
    local api = C_GamepadUI
    if type(c) ~= "table" or type(api) ~= "table" or type(api.GetFirstGamepadActionStorageSlotIndex) ~= "function" then
        return nil
    end
    local ok, first = pcall(api.GetFirstGamepadActionStorageSlotIndex)
    if not ok or type(first) ~= "number" then return nil end
    return {
        first = first,
        perPage = c.NUM_PAGEABLE_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT_STANDARD_PAGE or 32,
        reserved = c.NUM_RESERVED_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT or 4,
        pages = c.NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT or C.PAGES,
    }
end

-- "L2 + Square", as glyphs
function C.Combo(layer, glyph, size)
    local parts = {}
    for _, g in ipairs(C.LAYER_GLYPHS[layer] or {}) do parts[#parts + 1] = C.Glyph(g, size) end
    if glyph then parts[#parts + 1] = C.Glyph(glyph, size) end
    return table.concat(parts, " ")
end

-- The layer the held triggers show
function C.LayerOf(lt, rt)
    return (lt and rt and "both") or (lt and "lt") or (rt and "rt") or "base"
end

-- A display name for a binding command
function C.CommandName(command)
    if type(command) ~= "string" or command == "" then return nil end
    if C.COMMAND_NAMES[command] then return C.COMMAND_NAMES[command] end
    local global = _G["BINDING_NAME_" .. command]
    if type(global) == "string" and global ~= "" then return global end
    if command:match("^CLICK GamepadCompanionTouch") then return "Touchpad zones" end
    local frame = command:match("^CLICK ([^:]+)")
    if frame then
        frame = frame:gsub("Button$", ""):gsub("(%l)(%u)", "%1 %2")
        return frame ~= "" and frame or "Click"
    end
    local spell = command:match("^SPELL (.+)$")
    if spell then return spell end
    local macro = command:match("^MACRO (.+)$")
    if macro then return macro end
    return (command:gsub("_", " "):lower():gsub("^%l", string.upper))
end

-- Art point -> frame offset (TOPLEFT), at scale
function C.ToFrame(x, y, scale)
    return x * scale, -y * scale
end
