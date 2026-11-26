-- The Controller page: storage slots, fixed buttons, layers, pages, drops,
-- bindings, touchpad zones and held triggers, with stubbed game calls.
-- lua5.1 tests/Controller.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Frames ------------------------------------------------------------------------
local created, methods = {}, {}
local function new(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, shown = true, points = {},
        attributes = {}, enabled = true, events = {} }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
    created[#created + 1] = f
    if name then _G[name] = f end
    return f
end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:GetScript(key) return self.scripts[key] end
function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:CreateFontString() return new("FontString", nil, self) end
function methods:CreateTexture() return new("Texture", nil, self) end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:GetSize() return self:GetWidth(), self:GetHeight() end
function methods:IsShown() return self.shown end
function methods:Show()
    local was = self.shown; self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local was = self.shown; self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsVisible()
    local f = self
    while f do if not f.shown then return false end; f = f.parent end
    return true
end
function methods:IsEnabled() return self.enabled end
function methods:SetEnabled(v) self.enabled = v and true or false end
function methods:SetChecked(v) self.checked = v and true or false end
function methods:GetChecked() return self.checked end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:GetName() return self.name end
function methods:HasFocus() return false end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:SetTextColor(r, g, b) self.color = { r, g, b } end
function methods:SetTexture(t) self.texture = t end
function methods:SetAtlas(a) self.texture = a end
function CreateFrame(kind, name, parent) return new(kind, name, parent) end
UIParent = new("Frame", "UIParent")
function UIParent:GetWidth() return 1920 end
function UIParent:GetHeight() return 1080 end
UISpecialFrames, SlashCmdList = {}, {}
GameTooltip = new("Frame", "GameTooltip")

-- Game -------------------------------------------------------------------------
local combat, cursor = false, nil
local cvars = { ActionButtonUseKeyDown = "1", GamePadEmulateCtrl = "PADLSHOULDER", GamePadTouchCursorEnable = "0" }
local overrides = {}
InCombatLockdown = function() return combat end
NOW = 100
GetTime = function() return NOW end
GetCVar = function(n) return cvars[n] end
SetCVar = function(n, v) cvars[n] = tostring(v) end
function print() end
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
function hooksecurefunc() end
C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end }
local wraps = {}   -- frame name -> the wrapped OnClick body
function SecureHandlerWrapScript(frame, _, _, body) if frame.name then wraps[frame.name] = body end end
-- The game's override bindings, as proven in game (Forever 1.60, clean probe 2026-11-25). A
-- key's overrides are records, one per owner holding the key; on a pad key ("PAD...") a record
-- can hold a gamepad function (PAD_SET) as well as a command:
--   1. a record let go (nil or "") hands its function to the next fresh binding of the key,
--      any owner;
--   2. a record holding a function keeps running it after a click or command is written over
--      it in place;
--   3. the newest record on a key wins; a rewrite in place brings a record back on top;
--   4. plain commands and click bindings behave normally; off pad keys nothing sticks.
local PAD_SET = { TOGGLEUIFOCUS = true, OPENRADIAL = true, TOGGLEPINGSYSTEM = true }
local stacks = {}      -- key -> live records { owner, action, fn, at }
local letGo = {}       -- key -> functions let go there, oldest first
local writes = 0
local bindLog = {}     -- every write: { key, action (nil: let go), owner }
local function Pad(key) return type(key) == "string" and key:find("^PAD") ~= nil end
local function Top(key)
    local top
    for _, r in ipairs(stacks[key] or {}) do if not top or r.at > top.at then top = r end end
    overrides[key] = top
end
local function Find(key, owner)
    for i, r in ipairs(stacks[key] or {}) do if r.owner == owner then return r, i end end
end
local function Bind(owner, key, action)
    local list = stacks[key] or {}
    stacks[key] = list
    local r = Find(key, owner)
    if not r then
        r = { owner = owner }
        list[#list + 1] = r
        if Pad(key) and letGo[key] and #letGo[key] > 0 then r.fn = table.remove(letGo[key], 1) end
    end
    writes = writes + 1
    r.at, r.action = writes, action
    if PAD_SET[action] then r.fn = action elseif not Pad(key) then r.fn = nil end
    bindLog[#bindLog + 1] = { key = key, action = action, owner = owner }
    Top(key)
end
local function Release(owner, key)
    local r, i = Find(key, owner)
    if not r then return end
    table.remove(stacks[key], i)
    if r.fn and Pad(key) then letGo[key] = letGo[key] or {}; table.insert(letGo[key], r.fn) end
    bindLog[#bindLog + 1] = { key = key, owner = owner }
    Top(key)
end
function SetOverrideBinding(owner, _, key, action)
    if action == nil or action == "" then Release(owner, key) else Bind(owner, key, action) end
end
function SetOverrideBindingClick(owner, _, key, name, button)
    Bind(owner, key, "CLICK " .. tostring(name) .. ":" .. (button or "LeftButton"))
end
function ClearOverrideBindings(owner) for key in pairs(stacks) do Release(owner, key) end end
-- What key runs: the newest record's function, else its command (nil: the key's own binding)
local function Running(key)
    local r = overrides[key]
    if not r then return nil end
    return r.fn or r.action
end
-- Records of ours live on key
local function Ours(key)
    local n = 0
    for _, r in ipairs(stacks[key] or {}) do
        local name = type(r.owner) == "table" and r.owner.name or ""
        if name:find("^GamepadCompanion") then n = n + 1 end
    end
    return n
end
C_KeyBindings = { GetBindingByKey = function(key) return Running(key) end }
-- (checkOverride, as the game: the newest override's command, a gamepad function read back
-- empty; without it the key's own binding only)
local bindings = {}
function GetBindingAction(key, override)
    local r = override and overrides[key]
    if r then return PAD_SET[r.action] and "" or r.action end
    return bindings[key] or ""
end
C_GamePad = {
    GetActiveDeviceID = function() return 1 end,
    ButtonBindingToIndex = function() return 0 end,
    GetDeviceMappedState = function() return { labelStyle = "Shapes", sticks = { [4] = { x = 0, y = 0 } }, buttons = {} } end,
    GetDeviceRawState = function() return { vendorID = 1356, productID = 3302 } end,
    GetConfig = function() end, SetConfig = function() end, DeleteConfig = function() end, ApplyConfigs = function() end,
}
InputUtil = { IsGamepadUIEnabled = function() return true end }
-- (the focus manager as Blizzard's: a window focused or closed; Keys hooks both)
GamepadMode = { FrameControlsManager = { isUIFocused = false,
    SetUIFocusState = function(self, on) self.isUIFocused = on end, FrameHidden = function() end },
    OnCrossBarModifierChanged = function() end }
GamepadSharedUtility = { InputBindingManager = { IsOnlyCoreBindingSetActive = function() return true end } }
C_Texture = { GetAtlasInfo = function() return { file = 1, width = 64, height = 64, leftTexCoord = 0, rightTexCoord = 1,
    topTexCoord = 0, bottomTexCoord = 1 } end }
C_Spell = { GetSpellName = function(id) return id == 133 and "Fireball" or nil end, GetSpellTexture = function() return 135812 end }
GetMacroInfo = function() end
GetCursorInfo = function()
    if type(cursor) == "table" then return "macro", cursor.id end
    if cursor then return "spell", 1, "spell", cursor end
end
ClearCursor = function() cursor = nil end
CharacterMicroButton = { Click = function() end }
WorldMapMicroButton = { Click = function() end }
local settings = { optionsStyle = "A" }
GamepadCompanionAPI = { GetSettings = function() return settings end }
local API = GamepadCompanionAPI

function methods:CreateMaskTexture() return new("MaskTexture", nil, self) end
function methods:GetFrameLevel() return 1 end

-- Action bars --------------------------------------------------------------------
local actions = {}   -- storage -> { kind, id, texture, name }
local pressed = {}   -- key -> true
local activePage = 2
Constants = { GamepadActionBarConstants = { NUM_PAGEABLE_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT_STANDARD_PAGE = 32,
    NUM_RESERVED_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT = 4, NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT = 3,
    NUM_GAMEPAD_STANCE_ACTION_BARS = 5, NUM_SLOTS_PER_GAMEPAD_ACTION_BAR = 8 } }
C_GamepadUI = { GetFirstGamepadActionStorageSlotIndex = function() return 100 end,
    IsValidGamepadActionStorageSlotIndex = function(i) return i >= 100 and i < 224 end }
GamepadMainActionBarFrame = { PageUnit = { GetCurrentPage = function() return activePage end } }
GetActionInfo = function(i) local a = actions[i]; if a then return a.kind, a.id, a.subType end end
GetActionTexture = function(i) return actions[i] and actions[i].texture end
GetActionText = function(i) return actions[i] and actions[i].kind == "macro" and actions[i].name or nil end
PickupAction = function(i)
    local a = actions[i]
    actions[i] = nil
    cursor = a and (a.kind == "macro" and { id = a.id } or a.id) or nil
end
PlaceAction = function(i)
    if type(cursor) == "table" then actions[i] = { kind = "macro", id = cursor.id, texture = 134400 }; cursor = nil
    elseif cursor then actions[i] = { kind = "spell", id = cursor, texture = 135812 }; cursor = nil end
end
PickupSpell = function(id) cursor = id end
C_Spell.PickupSpell = PickupSpell
GetBindingKey = function(command) if command == "OPENRADIAL" then return "PADRSHOULDER" end end
bindings.PADLSTICK = "TOGGLEAUTORUN"
-- As the game: binding indexes are 0-based, the state's buttons 1-based
local ButtonIndex = { PADRSHOULDER = 9, PADLTRIGGER = 10, PADRTRIGGER = 11, PAD1 = 0, PADDUP = 12, PADBACK = 18, PADSOCIAL = 16, PAD5 = 4 }
C_GamePad.ButtonBindingToIndex = function(key) return ButtonIndex[key] end
C_GamePad.GetDeviceMappedState = function()
    local buttons = {}
    for i = 1, 20 do buttons[i] = false end
    for key, index in pairs(ButtonIndex) do buttons[index + 1] = pressed[key] or false end
    return { labelStyle = "Shapes", sticks = { [4] = { x = 0, y = 0 } }, buttons = buttons }
end

local hooks = {}
-- (a global's hook, or a table's: hooksecurefunc(GamepadMode, "OnCrossBarModifierChanged", fn))
function hooksecurefunc(a, b, c)
    local name, fn = a, b
    if c then name, fn = b, c end
    hooks[name] = hooks[name] or {}; table.insert(hooks[name], fn)
end
local timers = {}
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
-- Spellbook, bags, macros, Halo
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Holy", iconID = 9, itemIndexOffset = 0, numSpellBookItems = 3 } end,
    GetSpellBookItemInfo = function(slot)
        if slot == 1 then return { spellID = 133, actionID = 133, name = "Fireball", iconID = 7, itemType = 1 } end
        if slot == 2 then return { spellID = 5, actionID = 5, name = "Passive", iconID = 7, itemType = 1, isPassive = true } end
        if slot == 3 then return { spellID = 635, actionID = 635, name = "Holy Light", iconID = 8, itemType = 1 } end
    end,
}
C_Spell.GetSpellName = function(id) return ({ [133] = "Fireball", [635] = "Holy Light" })[id] end
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 6948, iconFileID = 2 } end
        if bag == 0 and slot == 2 then return { itemID = 2589, iconFileID = 3 } end
    end }
C_Item = { GetItemSpell = function(id) return id == 6948 and "Hearthstone" or nil end,
    GetItemNameByID = function(id) return ({ [6948] = "Hearthstone", [2589] = "Linen Cloth" })[id] end,
    PickupItem = function(id) cursor = id end }
-- Macros: one account macro; the character's from 121 (as the game)
local charMacros = {}   -- { name, icon, body }
local function MacroAt(x)
    if x == 1 or x == "Mount" then return { name = "Mount", icon = 3, body = "/cast Summon Charger" }, 1 end
    for i, m in ipairs(charMacros) do if x == 120 + i or x == m.name then return m, 120 + i end end
end
GetNumMacros = function() return 1, #charMacros end
GetMacroInfo = function(x) local m = MacroAt(x); if m then return m.name, m.icon, m.body end end
GetMacroIndexByName = function(name) local _, i = MacroAt(name); return i or 0 end
GetMacroBody = function(x) local m = MacroAt(x); return m and m.body end
CreateMacro = function(name, icon, body, perCharacter)
    assert(perCharacter, "a character macro")
    charMacros[#charMacros + 1] = { name = name, icon = icon, body = body }
    return 120 + #charMacros
end
EditMacro = function(x, name, icon, body)
    local m = MacroAt(x); m.name, m.icon, m.body = name or m.name, icon or m.icon, body or m.body
end
-- (as the game: slots holding a later macro follow its new index)
DeleteMacro = function(x)
    local _, i = MacroAt(x)
    if not (i and i > 120) then return end
    table.remove(charMacros, i - 120)
    for _, a in pairs(actions) do if a.kind == "macro" and a.id > i then a.id = a.id - 1 end end
end
PickupMacro = function(x) local _, i = MacroAt(x); if i then cursor = { id = i } end end
Halo = { db = { rings = { { id = 1, name = "Utility", slices = {} }, { id = 2, name = "Alt only", owner = "alt" } } },
    RingActiveHere = function(ring) return ring.owner == nil end, RingIcon = function() return 4 end }
GAMEPAD_MOD_LEFT, GAMEPAD_MOD_RIGHT, GAMEPAD_MOD_LEFT_AND_RIGHT = "SHIFT", "CTRL", "CTRL-SHIFT"
-- Per character: this character has no profile yet; the account has touch settings
GamepadCompanionCharDB = nil
GamepadCompanionTouchDB = { enabled = false, split = { device = "pad" }, actions = { chord = { base = { r1c1 = "window:bags" } } } }

local ns = {}
for _, file in ipairs({ "Model.lua", "TouchModel.lua", "Shared.lua", "SlotMacros.lua", "Touchpad.lua", "Keys.lua", "Gestures.lua", "ControllerModel.lua",
    "SpreadOverview.lua", "SpellRanks.lua", "OptionsSkin.lua", "Window.lua", "Picker.lua", "ControllerWindow.lua", "HelperLink.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local C, Touch, Keys = ns.ControllerModel, ns.Touch, ns.Keys
for _, f in ipairs(created) do
    if f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end
local function Fire(event)
    for _, f in ipairs(created) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
    end
end

-- Profile: per character, seeded from the account; the controller's own state shared
check(type(GamepadCompanionCharDB) == "table" and GamepadCompanionCharDB.touch ~= nil, "character profile made")
eq(GamepadCompanionCharDB.touch.actions.chord.base.r1c1, "window:bags", "seeded from the account settings")
check(GamepadCompanionCharDB.touch ~= GamepadCompanionTouchDB, "a copy, not the account table")
eq(Touch.Settings().split.device, "pad", "controller state from the account")
check(type(GamepadCompanionCharDB.keys) == "table", "button bindings in the profile")

-- Model --------------------------------------------------------------------------
local k = { first = 100, perPage = 32, reserved = 4, pages = 3 }
eq(C.StorageSlot(1, "base", 1, k), 100, "page 1 base left")
eq(C.StorageSlot(1, "base", 4, k), 103, "page 1 base down")
eq(C.StorageSlot(1, "base", 5, k), nil, "base face buttons have no storage")
eq(C.StorageSlot(1, "lt", 1, k), 104, "L2 bar follows the reserved four")
eq(C.StorageSlot(2, "base", 1, k), 128, "page 2 starts 28 on")
eq(C.StorageSlot(3, "both", 8, k), 183, "last slot")
eq(C.StorageSlot(4, "base", 1, k), nil, "no page 4")
eq(C.PageUnitSlot("rt", 3), 19, "R2 right is page unit slot 19")
-- The pad's state, the one source for held buttons (Shared.lua): 0-based binding indexes
eq(ns.Shared.LayerOf(true, true), "both", "both triggers")
eq(ns.Shared.LayerOf(false, true), "rt", "R2 alone")
eq(ns.Shared.PadDown({ false, true }, "PAD1"), false, "cross up (binding index 0 is buttons[1])")
pressed.PAD1 = true
eq(ns.Shared.PadDown(ns.Shared.PadButtons(), "PAD1"), true, "cross down")
pressed.PAD1 = nil
eq(ns.Shared.PadDown(nil, "PAD1"), nil, "no state: unknown")
eq(ns.Shared.PadDown({ true }, "PADPADDLE4"), nil, "a button the pad hasn't: unknown")
eq(C.Fixed("base", 8).name, "Jump", "base cross is jump")
eq(C.Fixed("lt", 8), nil, "L2 cross is a slot")
eq(C.CommandName("OPENRADIAL"), "Radial", "command names")
eq(C.CommandName("CLICK GamepadCompanionTouchClick:LeftButton"), "Touchpad zones", "our touchpad binding")
eq(C.CommandName("CLICK InputFunctionBindingButton_PADLSHOULDER:LeftButton"), "Modifier", "Forever's L1 function binding: a short name")
eq(C.CommandName("CLICK InputFunctionBindingButton_PADRSHOULDER:LeftButton"), "Modifier", "R1 too")
eq(C.CommandName("CLICK InputFunctionBindingButton_PADFORWARD:LeftButton"), "Game menu", "another key's: Blizzard's name for it")
eq(C.GlyphAtlas("Shp_RTrigger", 16), "Gamepad_Shp_RTrigger_32", "the glyph's atlas")
eq(C.Glyph("Shp_RTrigger", 16), "|A:Gamepad_Shp_RTrigger_32:16:16|a", "the glyph's markup")
local combo = C.Combo("both", "Shp_Cross")
check(combo:find("Shp_LTrigger", 1, true) and combo:find("Shp_RTrigger", 1, true) and combo:find("Shp_Cross", 1, true),
    "combo glyphs")
local seen = {}
for _, b in ipairs(C.BUTTONS) do check(not seen[b.key], "one hot spot per key: " .. b.key); seen[b.key] = true end
for _, s in ipairs(C.SLOTS) do check(not seen[s.key], "slot keys apart from hot spots: " .. s.key); seen[s.key] = true end

-- Open ---------------------------------------------------------------------------
actions[128] = { kind = "spell", id = 133, texture = 111 }                 -- page 2 base left
actions[132] = { kind = "macro", id = 5, texture = 222, name = "Mount" }    -- page 2 L2 left
API.ToggleController()
local window, ui = ns.ControllerWindow()
check(window and window:IsShown() and GamepadCompanionOptions:IsShown(), "opens on the Controller page")
check(ui.pages[2].selected, "opens on the active page")
eq(ui.pages[2].label.text, "2 •", "active page marked")
check(ui.layers.base.selected, "base layer")
eq(ui.slots[1].storage, 128, "left slot reads page 2 storage")
eq(ui.slots[1].icon.texture, 111, "left slot shows its icon")
check(ui.slots[8].fixed and ui.slots[8].icon.texture == "gamepad-ability-icon-jump", "cross shows jump")
eq(ui.name.text, "Fireball", "card: the selected slot's action")
eq(ui.kind.text, "Spell", "card: kind")
eq(ui.rows[2].name.text, "Mount", "card: the L2 row shows the macro")
eq(ui.rows[4].name.text, "Empty", "card: empty layer")

-- Layers
ui.layers.lt.scripts.OnClick(ui.layers.lt)
check(ui.layers.lt.selected, "L2 tab")
eq(ui.slots[1].icon.texture, 222, "L2 left shows the macro")
check(not ui.slots[8].fixed, "L2 cross is a slot")
eq(ui.slots[8].storage, 139, "L2 cross storage")
ui.rows[1].scripts.OnClick(ui.rows[1])
check(ui.layers.base.selected, "a layer row picks its layer")

-- Pages
ui.pages[1].scripts.OnClick(ui.pages[1])
eq(ui.slots[1].storage, 100, "page 1")
check(not ui.slots[1].icon:IsShown(), "empty slot: no icon")
check(ui.slots[1].background:IsShown(), "empty slot: native empty art")
ui.pages[2].scripts.OnClick(ui.pages[2])

-- Drop, pick up, clear
ui.slots[2].scripts.OnClick(ui.slots[2])
eq(ui.name.text, "Empty", "up slot is empty")
cursor = 133
ui.slots[2].scripts.OnReceiveDrag(ui.slots[2])
eq(actions[129] and actions[129].id, 133, "drop places the spell")
eq(cursor, nil, "cursor emptied")
eq(ui.name.text, "Fireball", "card follows the drop")
ui.clear.scripts.OnClick(ui.clear)
eq(actions[129], nil, "clear empties the slot")
eq(cursor, nil, "clear leaves nothing on the cursor")
combat = true
ui.slots[1].scripts.OnClick(ui.slots[1])
check(not ui.clear:IsEnabled() and not ui.pickup:IsEnabled(), "no editing in combat")
eq(ui.status.text, "Not in combat", "combat note")
combat = false
ui.slots[1].scripts.OnClick(ui.slots[1])
ui.pickup.scripts.OnClick(ui.pickup)
eq(cursor, 133, "pick up puts the action on the cursor")
eq(actions[128], nil, "slot emptied")
ui.slots[1].scripts.OnClick(ui.slots[1])
eq(actions[128] and actions[128].id, 133, "clicking with an action drops it")

-- The picker on a bar slot: every kind but Blizzard bindings (they need a key)
do
    local open, asked = ns.Picker.Open, {}
    ns.Picker.Open = function(req) asked[#asked + 1] = req.accepts; return open(req) end
    for _, pick in ipairs({ function() ui.slots[2].scripts.OnClick(ui.slots[2]) end,
        function() ui.buttons.l3.scripts.OnClick(ui.buttons.l3) end }) do
        pick(); ui.choose.scripts.OnClick(ui.choose); ns.PickerWindow():Hide()
    end
    ns.Picker.Open = open
    check(#asked == 2 and asked[1] == ns.TouchModel.SLOT_ACCEPTS and asked[2] == ns.TouchModel.ACCEPTS,
        "slot: no bindings; button: every kind")
    check(not ns.TouchModel.SLOT_ACCEPTS.bind and ns.TouchModel.SLOT_ACCEPTS.window, "slot set: all but bind")
    for _, file in ipairs({ "ControllerWindow.lua", "GesturesPage.lua", "Touchpad.lua", "Keys.lua" }) do
        local f = assert(io.open(root .. "/" .. file)); local src = f:read("*a"); f:close()
        check(not src:find("accepts%s*=%s*{") and not src:find("ACCEPTS%s*=%s*{"), file .. ": no accept list of its own")
    end
end
local picker, pui
ui.slots[2].scripts.OnClick(ui.slots[2])
ui.choose.scripts.OnClick(ui.choose)
picker, pui = ns.PickerWindow()
check(picker and picker:IsShown(), "choose opens the picker")
local keys = {}
for _, cat in ipairs(pui.categories) do keys[#keys + 1] = cat.key end
eq(table.concat(keys, ","), "spells:Holy,quick,items,macros,halo,windows,markers,text", "bar slot: every kind")
eq(pui.tiles[1].entry.name, "Fireball", "first spell")
eq(#pui.categories[1].list, 2, "passive spells left out")
pui.cats.items.scripts.OnClick(pui.cats.items)
eq(pui.tiles[1].entry.name, "Hearthstone", "usable items only")
check(not pui.tiles[2]:IsShown(), "cloth left out")
pui.search:SetText("holy")
pui.search.scripts.OnTextChanged(pui.search)
eq(pui.tiles[1].entry.name, "Holy Light", "search looks in every category")
pui.tiles[1].scripts.OnClick(pui.tiles[1])
check(not picker:IsShown(), "picking closes the picker")
eq(actions[129] and actions[129].id, 635, "picked spell placed on the slot")
eq(cursor, nil, "cursor left empty")
eq(ui.name.text, "Holy Light", "card shows it")

-- A slot given a window, Quick use, a typed macro: a character macro of ours
do
    local M, T = ns.SlotMacros, ns.TouchModel
    Fire("PLAYER_ENTERING_WORLD"); RunTimers()   -- (the bars are in)
    local function Pick(action)
        ui.choose.scripts.OnClick(ui.choose)
        for _, cat in ipairs(pui.categories) do
            for _, e in ipairs(cat.list or {}) do
                if e.action == action then pui.cats[cat.key].scripts.OnClick(pui.cats[cat.key]) end
            end
        end
        for _, tile in ipairs(pui.tiles) do
            if tile:IsShown() and tile.entry and tile.entry.action == action then tile.scripts.OnClick(tile); return true end
        end
        return false
    end
    ui.slots[3].scripts.OnClick(ui.slots[3])
    eq(ui.slots[3].storage, 130, "page 2 base right")
    check(Pick("window:bags"), "a window from the picker")
    eq(#charMacros, 1, "one macro made")
    eq(charMacros[1].name, "gpc:w:bags", "named for the action")
    eq(charMacros[1].body, T.MacroText("window:bags", ns.Shared.lookup), "the touchpad's body")
    eq(actions[130] and actions[130].kind, "macro", "the macro on the slot")
    eq(actions[130] and actions[130].id, 121, "our macro")
    eq(ui.kind.text, "Window", "card: the action's kind, not Macro")
    eq(ui.name.text, (Touch.ActionLook("window:bags")), "card: the action's name")
    check(ui.clear:IsEnabled(), "ours to clear")
    eq(cursor, nil, "cursor left empty")
    check(Pick("window:bags"), "the same again")
    eq(#charMacros, 1, "reused, not made twice")
    -- (the picker's macros: not ours)
    ui.choose.scripts.OnClick(ui.choose)
    for _, cat in ipairs(pui.categories) do
        if cat.key == "macros" then
            for _, e in ipairs(cat.list) do check(e.name ~= "gpc:w:bags", "our macro hidden from Macros") end
        end
    end
    picker:Hide()
    -- (our macro on the cursor: the action)
    cursor = { id = 121 }
    eq(Touch.TakeCursor(), "window:bags", "our macro off the cursor: the action")
    cursor = nil

    -- Quick use: the body follows the pick
    local food = "item:1114"
    ns.Shared.lookup.quick = function(key) return key == "food" and ("/use " .. food) or nil end
    ui.slots[4].scripts.OnClick(ui.slots[4])
    check(Pick("quick:food"), "Quick use · Food")
    eq(charMacros[2] and charMacros[2].name, "gpc:q:food", "quick macro named")
    eq(charMacros[2] and charMacros[2].body, "/use item:1114", "the pick's body")
    eq(charMacros[2] and charMacros[2].icon, 134400, "an item macro: the item's icon")
    eq(ui.kind.text, "Quick use", "card: Quick use")
    food = "item:3771"
    M.Apply()
    eq(charMacros[2] and charMacros[2].body, "/use item:3771", "body updated with the pick")
    eq(M.SlotAction(131), "quick:food", "slot reads back as the action")

    -- A long typed macro: a hashed name, 16 letters at most
    local long = T.SlotMacroName("text:/say a long typed macro here")
    check(long and #long <= 16 and long:find("^gpc:t:") ~= nil, "long action: short name")
    eq(T.SlotMacroName("text:/say a long typed macro here"), long, "the same name each time")
    check(T.SlotMacroName("text:/say another one") ~= long, "another action: another name")
    eq(T.SlotMacroName("spell:133"), nil, "a spell goes on as it is")

    -- Full: a few words, the slot unchanged
    Constants.MacroConsts = { MAX_CHARACTER_MACROS = 2 }   -- (Forever: 30)
    ui.slots[2].scripts.OnClick(ui.slots[2])
    check(Pick("window:spellbook"), "picked")
    eq(#charMacros, 2, "no macro made")
    eq(actions[129] and actions[129].id, 635, "slot unchanged")
    eq(ui.status.text, "Macros full", "said so")
    Constants.MacroConsts = nil

    -- A macro of the same name we didn't make: never touched
    charMacros[3] = { name = "gpc:w:map", icon = 1, body = "/mine" }
    eq(select(2, M.Ensure("window:map")), "Name taken", "someone else's name")
    eq(charMacros[3].body, "/mine", "left alone")

    -- Cleanup: a slot moved off our macro deletes it; others stay
    ui.slots[3].scripts.OnClick(ui.slots[3])
    ui.clear.scripts.OnClick(ui.clear)
    RunTimers()
    eq(GetMacroIndexByName("gpc:w:bags"), 0, "unused: deleted")
    check(GetMacroIndexByName("gpc:q:food") > 0, "still on a slot: kept")
    check(GetMacroIndexByName("gpc:w:map") > 0, "not ours: kept")
    check(not M.Owns("gpc:w:bags"), "forgotten")
    eq(M.SlotAction(131), "quick:food", "the other slot still runs its action")
    -- An item macro reports the item, not the macro (subType "item"): read by name, kept
    actions[131] = { kind = "macro", id = 3771, subType = "item", name = "gpc:q:food", texture = 134400 }
    eq(M.SlotAction(131), "quick:food", "item macro: read by its name")
    M.SweepSoon(); RunTimers()
    check(GetMacroIndexByName("gpc:q:food") > 0, "item macro on a slot: kept")
    -- (its name unreadable: nothing deleted)
    actions[131].name = nil
    M.SweepSoon(); RunTimers()
    check(GetMacroIndexByName("gpc:q:food") > 0, "unreadable macro slot: nothing deleted")
    actions[131] = nil
    M.SweepSoon(); RunTimers()
    eq(GetMacroIndexByName("gpc:q:food"), 0, "the last one too")
    check(GetMacroIndexByName("gpc:w:map") > 0, "not ours: still kept")
    charMacros = {}
end

-- Buttons: Blizzard's defaults, then Companion's bindings per layer
ui.buttons.l1.scripts.OnClick(ui.buttons.l1)
eq(ui.name.text, "Enemy targets", "L1: Blizzard's default")
eq(ui.kind.text, "Blizzard", "marked Blizzard")
check(not ui.clear:IsEnabled(), "nothing of ours to clear")
ui.buttons.l3.scripts.OnClick(ui.buttons.l3)
ui.choose.scripts.OnClick(ui.choose)
keys = {}
for _, cat in ipairs(pui.categories) do keys[#keys + 1] = cat.key end
eq(table.concat(keys, ","), "spells:Holy,quick,items,macros,halo,windows,markers,gamepad,text", "button: every kind")
do
    local names = {}
    for _, cat in ipairs(pui.categories) do
        if cat.key == "gamepad" then for _, e in ipairs(cat.list) do names[#names + 1] = e.name .. "=" .. e.action end end
    end
    eq(table.concat(names, ","), "Focus UI=bind:focus,Radial=bind:radial,Ping wheel=bind:ping", "Gamepad: Focus UI, Radial, Ping wheel")
end
pui.cats.halo.scripts.OnClick(pui.cats.halo)
eq(pui.tiles[1].entry.name, "Utility", "Halo rings of this character")
check(not pui.tiles[2]:IsShown(), "another character's ring left out")
pui.tiles[1].scripts.OnClick(pui.tiles[1])
eq(Keys.Get("PADLSTICK", "base"), "halo:1", "L3 runs the ring")
eq(GamepadCompanionCharDB.keys.PADLSTICK.base, "halo:1", "saved per character")
eq(overrides.PADLSTICK and overrides.PADLSTICK.action, "CLICK GamepadCompanionKeys:p3", "L3 bound")
eq(_G.GamepadCompanionKeys:GetAttribute("*macrotext-k1"), "/click HaloButton t1 true", "ring macro")
eq(ui.name.text, "Halo: Utility", "card shows the ring as Halo: name")
check((ui.buttons.l3.text.text or ""):find("Utility", 1, true), "label on the art")
-- L2 + L3: a typed macro
ui.layers.lt.scripts.OnClick(ui.layers.lt)
eq(ui.rows[1].name.text, "Halo: Utility", "every layer: base")
ui.choose.scripts.OnClick(ui.choose)
pui.cats.text.scripts.OnClick(pui.cats.text)
check(pui.textPane:IsShown(), "typed macro pane")
pui.macro:SetText("/wave")
pui.useMacro.scripts.OnClick(pui.useMacro)
eq(Keys.Get("PADLSTICK", "lt"), "text:/wave", "L2 + L3 macro")
eq(_G.GamepadCompanionKeys:GetAttribute("gpc-p3-lt"), "k2", "L2 + L3: on the same click, read at the press")
eq(overrides["SHIFT-PADLSTICK"], nil, "no Shift binding (Forever's bar keeps L2)")
-- Blizzard takes the key back: put back next frame
overrides.PADLSTICK = { owner = UIParent, action = "TOGGLEAUTORUN" }
for _, fn in ipairs(hooks.SetOverrideBinding or {}) do fn(UIParent, true, "PADLSTICK", "TOGGLEAUTORUN") end
RunTimers()
eq(overrides.PADLSTICK.action, "CLICK GamepadCompanionKeys:p3", "binding put back")
-- Clear, in combat it waits
combat = true
ui.clear.scripts.OnClick(ui.clear)
eq(Keys.Get("PADLSTICK", "lt"), nil, "cleared")
eq(_G.GamepadCompanionKeys:GetAttribute("gpc-p3-lt"), "k2", "the change waits for combat to end")
combat = false
Fire("PLAYER_REGEN_ENABLED")
eq(_G.GamepadCompanionKeys:GetAttribute("gpc-p3-lt"), nil, "gone after combat")
ui.layers.base.scripts.OnClick(ui.layers.base)
ui.buttons.ps.scripts.OnClick(ui.buttons.ps)
eq(ui.name.text, "Empty", "PS unbound")
-- Bindings: one click per key of ours, written only when the settings change; a Blizzard
-- function natively only on a key that has nothing else; the rest through WoW Helper's chords
local kb = _G.GamepadCompanionKeys
local keySnippet = assert(loadstring("local self, button, down = ...\n" .. assert(wraps.GamepadCompanionKeys, "keys snippet wrapped")))
setfenv(keySnippet, { GetGamePadState = function() return C_GamePad.GetDeviceMappedState() end })
local HL = ns.HelperLink
local holds = {}         -- each K.Hold(n), in order
local hold = HL.Hold
HL.Hold = function(n) holds[#holds + 1] = n; return hold(n) end
local function Holds() local s = table.concat(holds, ","); holds = {}; return s end
local CHORD = Keys.CHORD
local function Click(key) return Running(key) and Running(key):match("^CLICK GamepadCompanionKeys:(%w+)$") end
-- One half of a press of key, as the game runs our click: the pick (nil: no click of ours)
local function Half(key, down)
    local name = Click(key)
    if not name then return nil end
    local id = keySnippet(kb, name, down)
    kb.scripts.PostClick(kb, name, down)
    return id
end
-- A press of key with L2 / R2 held (released before the key with early): the macro that ran
-- and the pick, on the half the game's key-down setting says
local function PressKey(key, lt, rt, early)
    pressed.PADLTRIGGER, pressed.PADRTRIGGER = lt or false, rt or false
    local downId = Half(key, true)
    if early then pressed.PADLTRIGGER, pressed.PADRTRIGGER = false, false end
    local upId = Half(key, false)
    pressed.PADLTRIGGER, pressed.PADRTRIGGER = nil, nil
    local id = cvars.ActionButtonUseKeyDown == "1" and downId or upId
    return id and kb:GetAttribute("*macrotext-" .. id) or nil, id
end
-- Writes since mark, on pad keys of ours / on chords
local OUR_KEY = {}
for _, key in ipairs(Keys.KEYS) do OUR_KEY[key] = true end
local function WritesSince(mark, test)
    local n = 0
    for i = mark + 1, #bindLog do if test(bindLog[i]) then n = n + 1 end end
    return n
end
local function OnPadKeys(w) return OUR_KEY[w.key] end
local function OnChords(w) return w.key:find("^" .. CHORD:gsub("%-", "%%-") .. "%d$") ~= nil end
local function Reset(key) for _, l in ipairs({ "base", "lt", "rt", "both" }) do Keys.Set(key, l, nil) end end
-- (the link on, WoW Helper reading the hold cells)
GamepadCompanionHapticsDB = GamepadCompanionHapticsDB or {}
GamepadCompanionHapticsDB.link = GamepadCompanionHapticsDB.link or {}
GamepadCompanionHapticsDB.link.on = true
WowHelperData = { holdCells = 1 }

-- WoW Helper's chords 1-3: the gamepad functions, bound once on their own owner
do
    eq(Running(CHORD .. "1"), "TOGGLEUIFOCUS", "chord 1: Focus UI")
    eq(Running(CHORD .. "2"), "OPENRADIAL", "chord 2: Radial")
    eq(Running(CHORD .. "3"), "TOGGLEPINGSYSTEM", "chord 3: Ping wheel")
    eq(overrides[CHORD .. "1"].owner, _G.GamepadCompanionHelperChords, "on the chords' owner")
    local n = 0
    for _, w in ipairs(bindLog) do if w.key == CHORD .. "1" or w.key == CHORD .. "2" or w.key == CHORD .. "3" then n = n + 1 end end
    eq(n, 3, "each bound once")
    local mark = #bindLog
    Fire("PLAYER_LOGIN"); Fire("PLAYER_REGEN_ENABLED"); Keys.Apply()
    check(Keys.BindHelperChords(), "bound")
    eq(WritesSince(mark, function(w) return w.key:find("^" .. CHORD:gsub("%-", "%%-") .. "[123]$") end), 0, "never again")
end

-- Focus UI alone on PS's Base: bound on the key itself, no click, nothing asked of WoW Helper
bindings.PADSYSTEM = "FRAMEGAMBIT_CLEAN_SCREENSHOT"
do
    check(Keys.Set("PADSYSTEM", "base", "bind:focus"), "PS: Focus UI")
    eq(Running("PADSYSTEM"), "TOGGLEUIFOCUS", "PS runs Focus UI natively")
    eq(overrides.PADSYSTEM.owner, _G.GamepadCompanionKeyNative, "on the native owner")
    eq(Click("PADSYSTEM"), nil, "no click of ours")
    eq(kb:GetAttribute("gpc-p7-base"), nil, "no pick")
    check(Keys.Runs("PADSYSTEM", "base") == true, "runs")
    local data = WowHelperData
    WowHelperData = {}
    check(Keys.Runs("PADSYSTEM", "base") == true, "runs without WoW Helper")
    WowHelperData = data
    check(Keys.Set("PADSYSTEM", "base", "bind:radial"), "PS: Radial")
    eq(Running("PADSYSTEM"), "OPENRADIAL", "PS runs Radial")
    eq(Ours("PADSYSTEM"), 1, "in place: one record")
    -- (given back: the Radial's record never let go; our click over it, Base the game's own
    -- screenshot through a chord, the layers nothing)
    local mark = #bindLog
    Keys.Set("PADSYSTEM", "base", nil)
    eq(Running("PADSYSTEM"), "CLICK GamepadCompanionKeys:p7", "PS given back: our click still")
    for i = mark + 1, #bindLog do check(not (bindLog[i].key == "PADSYSTEM" and bindLog[i].action == nil), "nothing let go on PS") end
    local pick = kb:GetAttribute("gpc-p7-base")
    local n = tonumber((pick or ""):match("^h(%d)$"))
    check(n and n >= 4, "Base: a game chord")
    eq(Running(CHORD .. tostring(n)), "FRAMEGAMBIT_CLEAN_SCREENSHOT", "that chord: the screenshot")
    eq(kb:GetAttribute("gpc-p7-lt"), "none", "L2: nothing")
    Holds()
    local _, id = PressKey("PADSYSTEM", true)
    check(not id, "L2 + PS: nothing")
    eq(Holds(), "", "L2 + PS: nothing held")
    -- (another owner binding PS fresh, a window's set: never handed the Radial)
    local other = new("Frame", "SomeWindowBinds")
    SetOverrideBinding(other, true, "PADSYSTEM", "TOGGLEWORLDMAP")
    eq(Running("PADSYSTEM"), "TOGGLEWORLDMAP", "another owner's binding: its own, no Radial")
    SetOverrideBinding(other, true, "PADSYSTEM", nil)
    check(Keys.Set("PADSYSTEM", "base", "text:/wave"), "PS: a macro")
    eq(Running("PADSYSTEM"), "CLICK GamepadCompanionKeys:p7", "PS runs our click, no Radial over it")
    eq((PressKey("PADSYSTEM")), "/wave", "PS: the macro")
    -- (no WoW Helper: the card's note on the given-back Base)
    Reset("PADSYSTEM")
    local data = WowHelperData
    WowHelperData = {}
    local runs, why = Keys.Runs("PADSYSTEM", "base")
    check(runs == false and why == "needs WoW Helper", "Base's game command without WoW Helper: a note")
    ui.buttons.ps.scripts.OnClick(ui.buttons.ps)
    check((ui.kind.text or ""):find("needs WoW Helper", 1, true) ~= nil, "card: the note")
    WowHelperData = data
    runs, why = Keys.Runs("PADSYSTEM", "base")
    check(runs == false and why == nil, "with WoW Helper: no note")
end

-- Options, the player's setup: Base Radial, L2 Focus UI, R2 Check minimap. One click on the key,
-- never a function: Base holds chord 2, L2 chord 1, R2 the Check minimap macro
local CLICK_OPTIONS = "CLICK GamepadCompanionKeys:p6"
bindings.PADFORWARD = "OPENRADIAL"
do
    local mark = #bindLog
    check(Keys.Set("PADFORWARD", "lt", "bind:focus"), "L2 + Options: Focus UI")
    check(Keys.Set("PADFORWARD", "rt", "window:checkminimap"), "R2 + Options: Check minimap")
    check(Keys.Set("PADFORWARD", "base", "bind:radial"), "Options: Radial")
    eq(Running("PADFORWARD"), CLICK_OPTIONS, "Options: our click")
    eq(overrides.PADFORWARD.owner, _G.GamepadCompanionKeyBinds, "on the click owner")
    for i = mark + 1, #bindLog do
        local w = bindLog[i]
        check(not (w.key == "PADFORWARD" and PAD_SET[w.action]), "no function ever bound on Options")
    end
    eq(WritesSince(mark, function(w) return w.key == "PADFORWARD" end), 1, "Options written once")
    eq(kb:GetAttribute("gpc-p6-base"), "h2", "Base: chord 2 (Radial)")
    eq(kb:GetAttribute("gpc-p6-lt"), "h1", "L2: chord 1 (Focus UI)")
    local rt = kb:GetAttribute("gpc-p6-rt")
    check(type(rt) == "string" and rt:find("^k%d+$") ~= nil, "R2: a macro")
    eq(kb:GetAttribute("*macrotext-" .. rt), ns.TouchModel.MacroText("window:checkminimap", ns.Shared.lookup), "R2: Check minimap's macro")
    -- presses: Radial held while Options is, Focus UI on L2, the macro on R2
    Holds()
    local ran, id = PressKey("PADFORWARD")
    check(ran == nil and id == "h2", "Options: chord 2")
    eq(Holds(), "2,0", "Options: held from press to release")
    ran, id = PressKey("PADFORWARD", true)
    check(ran == nil and id == "h1", "L2 + Options: chord 1")
    eq(Holds(), "1,0", "L2 + Options: Focus UI held, let go")
    ran = PressKey("PADFORWARD", false, true)
    eq(ran, kb:GetAttribute("*macrotext-" .. rt), "R2 + Options: Check minimap")
    eq(Holds(), "", "R2 + Options: nothing held")
    ran = PressKey("PADFORWARD", true, true)
    eq(Holds(), "2,0", "L2 + R2, empty: Base's Radial")
    -- (acting on the release: the press's pick, L2 let go first)
    cvars.ActionButtonUseKeyDown = "0"
    ran, id = PressKey("PADFORWARD", true, false, true)
    eq(id, "h1", "on the release: the press's layer")
    cvars.ActionButtonUseKeyDown = "1"
    Holds()
    -- L2 / R2 pressed and let go, presses, macro and spell changes: nothing written
    mark = #bindLog
    for _ = 1, 3 do
        pressed.PADLTRIGGER = true; Fire("PLAYER_ENTERING_WORLD")
        pressed.PADRTRIGGER = true; PressKey("PADFORWARD", true, true)
        pressed.PADLTRIGGER = nil; Fire("SPELLS_CHANGED")
        pressed.PADRTRIGGER = nil; Fire("UPDATE_MACROS")
    end
    eq(WritesSince(mark, OnPadKeys), 0, "L2 / R2 cycles: no pad key written")
    eq(Running("PADFORWARD"), CLICK_OPTIONS, "Options: the same click")
    -- Runs: a helper action only with WoW Helper reading the hold cells
    check(Keys.Runs("PADFORWARD", "base") == true and Keys.Runs("PADFORWARD", "lt") == true, "with WoW Helper: runs")
    local data = WowHelperData
    WowHelperData = {}
    local runs, why = Keys.Runs("PADFORWARD", "lt")
    check(runs == false and why == "needs WoW Helper", "L2 + Options without WoW Helper: a note")
    runs, why = Keys.Runs("PADFORWARD", "base")
    check(runs == false and why == "needs WoW Helper", "Options' Radial on a click: the same")
    check(Keys.Runs("PADFORWARD", "rt") == true, "the macro runs anyway")
    ui.buttons.options.scripts.OnClick(ui.buttons.options)
    ui.layers.lt.scripts.OnClick(ui.layers.lt)
    check((ui.kind.text or ""):find("needs WoW Helper", 1, true) ~= nil, "card: the note")
    ui.layers.base.scripts.OnClick(ui.layers.base)
    WowHelperData = data
    -- a window's footer covers Options (Blizzard, on UIParent): our click back on top, in place
    SetOverrideBindingClick(UIParent, true, "PADFORWARD", "InputFunctionBindingButton_PADFORWARD", "LeftButton")
    for _, fn in ipairs(hooks.SetOverrideBindingClick or {}) do fn(UIParent, true, "PADFORWARD", "InputFunctionBindingButton_PADFORWARD") end
    RunTimers()
    eq(Running("PADFORWARD"), CLICK_OPTIONS, "covered: back on top")
    eq(Ours("PADFORWARD"), 1, "in place: one record of ours")
    ClearOverrideBindings(UIParent)
    Reset("PADFORWARD")
    eq(Running("PADFORWARD"), nil, "Options given back: the game's Radial")
end

-- A key never bound (Mute): combos first, then a Blizzard function on Base: never a function
-- on the key. Then Focus UI alone (native), a combo added (our click above it) and taken away
do
    local mark = #bindLog
    check(Keys.Set("PAD5", "rt", "bind:ping") and Keys.Set("PAD5", "base", "bind:radial"), "R2 + Mute: Ping wheel; Mute: Radial")
    eq(Running("PAD5"), "CLICK GamepadCompanionKeys:p8", "Mute: our click")
    eq(kb:GetAttribute("gpc-p8-base"), "h2", "Base: chord 2")
    eq(kb:GetAttribute("gpc-p8-rt"), "h3", "R2: chord 3 (Ping wheel)")
    for i = mark + 1, #bindLog do
        local w = bindLog[i]
        check(not (w.key == "PAD5" and PAD_SET[w.action]), "no function bound on Mute with a combo")
    end
    Reset("PAD5")
    check(Keys.Set("PAD5", "base", "bind:focus"), "Mute: Focus UI")
    eq(Running("PAD5"), "TOGGLEUIFOCUS", "alone: native")
    check(Keys.Set("PAD5", "lt", "bind:radial"), "L2 + Mute: Radial")
    eq(Running("PAD5"), "CLICK GamepadCompanionKeys:p8", "a combo: our click above it")
    eq(kb:GetAttribute("gpc-p8-base"), "h1", "Base: chord 1")
    eq(kb:GetAttribute("gpc-p8-lt"), "h2", "L2: chord 2")
    check(Keys.Set("PAD5", "lt", nil), "the combo gone")
    eq(Running("PAD5"), "TOGGLEUIFOCUS", "native again, on top")
    eq(Ours("PAD5"), 2, "both records kept, none let go")
    Reset("PAD5")
    eq(Ours("PAD5"), 2, "given back: both records kept")
    eq(Running("PAD5"), "CLICK GamepadCompanionKeys:p8", "our click on top")
end

-- Base empty with combos: the key's own game command through a chord 4-9
local CLICK_CREATE = "CLICK GamepadCompanionKeys:p5"
bindings.PADSOCIAL = "TOGGLEWORLDMAP"
do
    check(Keys.Set("PADSOCIAL", "lt", "bind:focus"), "L2 + Create: Focus UI")
    eq(Running("PADSOCIAL"), CLICK_CREATE, "Create: our click")
    local base = kb:GetAttribute("gpc-p5-base")
    local n = tonumber((base or ""):match("^h(%d)$"))
    check(n and n >= 4 and n <= 9, "Base: a game chord (" .. tostring(base) .. ")")
    eq(Running(CHORD .. tostring(n)), "TOGGLEWORLDMAP", "that chord: the map")
    eq(overrides[CHORD .. tostring(n)].owner, _G.GamepadCompanionGameChords, "on the game chords' owner")
    Holds()
    local _, id = PressKey("PADSOCIAL")
    eq(id, base, "Create: the map's chord")
    eq(Holds(), n .. ",0", "held while Create is")
    -- PS: its screenshot on another chord
    check(Keys.Set("PADSYSTEM", "lt", "bind:focus"), "L2 + PS: Focus UI")
    local ps = kb:GetAttribute("gpc-p7-base")
    local m = tonumber((ps or ""):match("^h(%d)$"))
    check(m and m >= 4 and m <= 9 and m ~= n, "PS: a chord of its own")
    eq(Running(CHORD .. tostring(m)), "FRAMEGAMBIT_CLEAN_SCREENSHOT", "that chord: the screenshot")
    -- Options' own Radial: chord 2, no game chord for it
    check(Keys.Set("PADFORWARD", "lt", "text:/wave"), "L2 + Options: a macro")
    eq(kb:GetAttribute("gpc-p6-base"), "h2", "Options' own Radial: chord 2")
    -- Mute has no game command: nothing on its Base
    check(Keys.Set("PAD5", "lt", "text:/wave"), "L2 + Mute")
    eq(kb:GetAttribute("gpc-p8-base"), "none", "Mute: nothing on Base")
    eq((PressKey("PAD5")), nil, "plain Mute: nothing")
    eq((PressKey("PAD5", true)), "/wave", "L2 + Mute")
    -- the chords rewritten only when the set changes
    local mark = #bindLog
    Keys.Apply(); Fire("PLAYER_ENTERING_WORLD")
    eq(WritesSince(mark, OnChords), 0, "the same set: no chord written")
    Keys.Set("PADSOCIAL", "lt", nil)
    eq(Running("PADSOCIAL"), nil, "Create given back: the map")
    bindings.PAD5 = "CLICK HaloButton:p3"
    Reset("PAD5")
    check(Keys.Set("PAD5", "lt", "text:/wave"), "Mute is Halo's ring now")
    eq(WritesSince(mark, OnChords), 1, "a new command: one chord written")
    local h = tonumber(kb:GetAttribute("gpc-p8-base"):match("^h(%d)$"))
    eq(Running(CHORD .. h), "CLICK HaloButton:p3", "Mute's ring on its chord")
    check(h == n or Running(CHORD .. n) == "TOGGLEWORLDMAP", "the map's chord reused in place or kept")
    -- two keys held: the last press wins, its release lets go
    Holds()
    check(Half("PAD5", true) and Half("PADSYSTEM", true), "Mute down, then PS down")
    Half("PAD5", false)
    Half("PADSYSTEM", false)
    eq(Holds(), h .. "," .. m .. ",0", "Mute's chord, then PS's; Mute's release nothing, PS's lets go")
    Half("PADSYSTEM", true); Half("PAD5", true)
    Half("PAD5", false); Half("PADSYSTEM", false)
    eq(Holds(), m .. "," .. h .. ",0", "the other way round: the last press's release lets go")
    -- a macro pressed while a chord is held leaves it held
    pressed.PADLTRIGGER = true
    Half("PADSYSTEM", false)
    Half("PADFORWARD", true); Half("PADFORWARD", false)
    pressed.PADLTRIGGER = nil
    eq(Holds(), "", "no hold, no release: a macro key changes nothing")
    Reset("PADSYSTEM"); Reset("PADFORWARD"); Reset("PAD5")
    bindings.PAD5 = nil
end

-- In combat: nothing written, after it is
do
    combat = true
    local mark = #bindLog
    check(Keys.Set("PAD5", "base", "text:/wave"), "Mute: a macro in combat")
    eq(WritesSince(mark, OnPadKeys), 0, "nothing written in combat")
    check(Keys.IsPending(), "waits")
    combat = false
    Fire("PLAYER_REGEN_ENABLED")
    eq(Running("PAD5"), "CLICK GamepadCompanionKeys:p8", "after combat: bound")
    check(not Keys.IsPending(), "done")
    Reset("PAD5")
end

-- L3: Radial, a macro, Radial again: the native record held under the click, back on top
do
    Reset("PADLSTICK")
    check(Keys.Set("PADLSTICK", "base", "bind:radial"), "L3: Radial")
    eq(Running("PADLSTICK"), "OPENRADIAL", "L3 runs Radial")
    check(Keys.Set("PADLSTICK", "base", "text:/wave"), "L3: a macro")
    eq(Running("PADLSTICK"), "CLICK GamepadCompanionKeys:p3", "L3 runs the macro, no Radial over it")
    check(Keys.Set("PADLSTICK", "base", "bind:radial"), "L3: Radial again")
    eq(Running("PADLSTICK"), "OPENRADIAL", "L3 runs Radial again")
    Reset("PADLSTICK")
    eq(Running("PADLSTICK"), "CLICK GamepadCompanionKeys:p3", "L3 given back: our click over the Radial")
    local n = tonumber(kb:GetAttribute("gpc-p3-base"):match("^h(%d)$"))
    eq(Running(CHORD .. n), "TOGGLEAUTORUN", "Base: its own auto-run through a chord")
end
-- keys that never carried a function: given back for real
for _, key in ipairs({ "PADRSTICK", "PADSOCIAL", "PADFORWARD" }) do eq(Ours(key), 0, "given back: " .. key) end

-- The key's own command: its keybinding, never a window's override on top
do
    bindings.PADSOCIAL = "TOGGLEWORLDMAP"
    local footer = new("Frame", "SomeFooter")
    SetOverrideBindingClick(footer, true, "PADSOCIAL", "FooterButton", "LeftButton")
    check(Keys.Set("PADSOCIAL", "lt", "text:/wave"), "L2 + Create, a window's footer on Create")
    local n = tonumber(kb:GetAttribute("gpc-p5-base"):match("^h(%d)$"))
    eq(Running(CHORD .. n), "TOGGLEWORLDMAP", "Base: the map, not the footer")
    for _, fn in ipairs(hooks.SetOverrideBindingClick or {}) do fn(UIParent, true, "PADSOCIAL", "FooterButton") end
    SetOverrideBindingClick(UIParent, true, "PADSOCIAL", "FooterButton2", "LeftButton")
    for _, fn in ipairs(hooks.SetOverrideBindingClick or {}) do fn(UIParent, true, "PADSOCIAL", "FooterButton2") end
    RunTimers()
    eq(Running("PADSOCIAL"), "CLICK GamepadCompanionKeys:p5", "covered: ours back on top")
    eq(Running(CHORD .. n), "TOGGLEWORLDMAP", "the cover not taken for Create's command")
    ClearOverrideBindings(footer); ClearOverrideBindings(UIParent)
    Reset("PADSOCIAL")
    -- (Options with no keybinding: Blizzard's core set default)
    bindings.PADFORWARD = nil
    check(Keys.Set("PADFORWARD", "lt", "text:/wave"), "L2 + Options")
    n = tonumber(kb:GetAttribute("gpc-p6-base"):match("^h(%d)$"))
    eq(Running(CHORD .. n), "TOGGLEGAMEMENU", "Options: the core set's game menu")
    Reset("PADFORWARD")
end

-- A hold whose release never comes (a window ate it): the pad read up lets go; so do a new
-- pad and a loading screen
do
    local watch = _G.GamepadCompanionKeyHold
    bindings.PADSOCIAL = "TOGGLEWORLDMAP"
    check(Keys.Set("PADSOCIAL", "lt", "bind:focus"), "L2 + Create: Focus UI")
    Holds()
    pressed.PADSOCIAL = true
    Half("PADSOCIAL", true)
    check(watch.scripts.OnUpdate ~= nil, "held: the pad watched")
    watch.scripts.OnUpdate(watch, 0.06)
    eq(Holds(), tostring(tonumber(kb:GetAttribute("gpc-p5-base"):match("%d"))), "held while the pad says down")
    pressed.PADSOCIAL = nil
    watch.scripts.OnUpdate(watch, 0.01)
    eq(Holds(), "", "under the poll: not yet read")
    watch.scripts.OnUpdate(watch, 0.05)
    eq(Holds(), "0", "the pad reads Create up: let go")
    check(watch.scripts.OnUpdate == nil, "not watched after")
    Half("PADSOCIAL", false)
    eq(Holds(), "", "the late release: nothing more")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GAME_PAD_ACTIVE_CHANGED" }) do
        pressed.PADSOCIAL = true
        Half("PADSOCIAL", true)
        Holds()
        Fire(event)
        eq(Holds(), "0", event .. ": let go")
        pressed.PADSOCIAL = nil
        Half("PADSOCIAL", false)
    end
    Reset("PADSOCIAL")
end

-- The game's pad hand-back blocked by another addon's taint: written down
do
    local errors = function() return GamepadCompanionTraceDB and GamepadCompanionTraceDB.errors or {} end
    local n3 = #errors()
    Keys.Blocked("Auctionator", "SetPreferredGamepadInteractTarget()")
    check(#errors() > n3 and errors()[n3 + 1]:find("BLOCKED SetPreferredGamepadInteractTarget%(%) by Auctionator") ~= nil, "hand-back blocked: written down")
    local n4 = #errors()
    Keys.Blocked("Someone", "CastSpellByName()")
    eq(#errors(), n4, "another blocked call: not ours to say")
end
ui.buttons.l2.scripts.OnClick(ui.buttons.l2)
check(ui.layers.lt.selected, "L2 on the art picks the L2 bar")
check(ui.showLayer:IsShown(), "card: show layer")
ui.showLayer.scripts.OnClick(ui.showLayer)
check(ui.layers.base.selected, "back to base")

-- Touchpad: settings and bindings in the card
API.ToggleTouchpad()
check(window:IsShown() and ui.tp:IsShown(), "/gpc touch opens this page on the touchpad")
local tp = ui.tpw
tp.enable:SetChecked(true); tp.enable.scripts.OnClick(tp.enable)
eq(Touch.Settings().enabled, true, "zones on from the card")
local shown = 0
for _, c in pairs(ui.zones) do if c:IsShown() then shown = shown + 1 end end
eq(shown, 6, "3 x 2 zones on the pad")
ui.zones.r2c3.scripts.OnClick(ui.zones.r2c3)
eq(tp.zoneTitle.text, "Bottom right · Base", "zone picked on the art")
ui.choose.scripts.OnClick(ui.choose)
pui.cats.windows.scripts.OnClick(pui.cats.windows)
local map
for i = 1, 24 do local t = pui.tiles[i]; if t and t.entry and t.entry.action == "window:questlog" then map = t end end
map.scripts.OnClick(map)
eq(Touch.Settings().actions.chord.base.r2c3, "window:questlog", "window from the picker")
eq(ui.name.text, "Quests & Map", "card shows the binding")
ui.layers.lt.scripts.OnClick(ui.layers.lt)
eq(ui.kind.text, "Window · Base", "L2: Base's, inherited")
check(not ui.clear:IsEnabled(), "inherited: nothing to clear")
cursor = 133
ui.zones.r1c1.scripts.OnReceiveDrag(ui.zones.r1c1)
eq(Touch.Settings().actions.chord.lt.r1c1, "spell:133", "spell dropped on the art zone")
eq(cursor, nil, "cursor emptied")
tp.colsMinus.scripts.OnClick(tp.colsMinus)
eq(tp.cols.text, "2 columns", "fewer columns")
tp.inputs.dual.scripts.OnClick(tp.inputs.dual)
check(tp.slots.touch:IsShown(), "touch and click slots")
tp.slots.touch.scripts.OnClick(tp.slots.touch)
ui.choose.scripts.OnClick(ui.choose)
pui.cats.halo.scripts.OnClick(pui.cats.halo)
pui.tiles[1].scripts.OnClick(pui.tiles[1])
eq(Touch.Settings().touchActions.lt.r1c1, "halo:1", "touch slot: a Halo ring")
eq(Touch.Runs("halo:1"), "/click HaloButton t1 true", "ring macro for zones")
tp.swipes["swipe-up"].scripts.OnClick(tp.swipes["swipe-up"])
eq(tp.zoneTitle.text, "Swipe up · L2", "swipe picked")
check(not tp.slots.touch:IsEnabled(), "swipes: click slot only")
tp.modes.split.scripts.OnClick(tp.modes.split)
check(not tp.inputs.dual:IsEnabled(), "right half: no touch + click")
tp.modes.chord.scripts.OnClick(tp.modes.chord)
ui.layers.base.scripts.OnClick(ui.layers.base)
API.ToggleTouchpad()
check(not GamepadCompanionOptions:IsShown(), "touchpad toggle closes")
API.ToggleController()

-- Held triggers and pressed buttons
pressed.PADLTRIGGER = true
window.scripts.OnUpdate(window, 1)
check(ui.layers.lt.selected and not ui.layers.rt.selected, "holding L2 shows L2")
pressed.PADLTRIGGER, pressed.PADRTRIGGER = nil, true
window.scripts.OnUpdate(window, 1)
check(ui.layers.rt.selected and not ui.layers.lt.selected, "holding R2 shows R2")
pressed.PADRTRIGGER, pressed.PADRSHOULDER = nil, true
window.scripts.OnUpdate(window, 1)
check(ui.layers.base.selected, "R1 is no trigger")
pressed.PADRSHOULDER = nil
pressed.PADLTRIGGER, pressed.PADRTRIGGER, pressed.PAD1 = true, true, true
window.scripts.OnUpdate(window, 1)
check(ui.layers.both.selected, "holding both triggers shows L2 + R2")
check(ui.slots[8].pressed:IsShown(), "pressed cross lights up")
pressed.PADLTRIGGER, pressed.PADRTRIGGER, pressed.PAD1 = nil, nil, nil
window.scripts.OnUpdate(window, 1)
check(ui.layers.base.selected, "release: back to the chosen layer")
check(not ui.slots[8].pressed:IsShown(), "released")

-- Page change in game
activePage = 3
window.scripts.OnUpdate(window, 1)
eq(ui.pages[3].label.text, "3 •", "active page follows the game")

-- Close
API.ToggleController()
check(not GamepadCompanionOptions:IsShown(), "toggle closes")

-- Gestures: WoW Helper's Ctrl+Shift+Alt+F<slot>, each slot an action
do
    local G = ns.Gestures
    check(type(GamepadCompanionCharDB.gestures) == "table", "gestures in the profile")
    check(G.Set(3, "text:/dance") and overrides["ALT-CTRL-SHIFT-F3"]
        and overrides["ALT-CTRL-SHIFT-F3"].action == "CLICK GamepadCompanionGestures:g3", "slot 3 bound")
    local gb = _G.GamepadCompanionGestures
    check(gb.attributes and gb.attributes["*macrotext-g3"] == "/dance", "slot 3 runs /dance")
    check(GamepadCompanionCharDB.gestures[3] == "text:/dance", "saved")
    check(G.Set(13, "text:/wave") == false and G.Set(1, "bogus") == false, "bad slot or action refused")
    combat = true
    G.Set(5, "text:/wave")
    check(G.IsPending() and overrides["ALT-CTRL-SHIFT-F5"] == nil, "in combat: after it")
    combat = false
    for _, f in ipairs(created) do
        if f.events.PLAYER_REGEN_ENABLED and f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_REGEN_ENABLED") end
    end
    check(not G.IsPending() and overrides["ALT-CTRL-SHIFT-F5"] ~= nil, "applied after combat")
    G.Set(3, nil)
    check(overrides["ALT-CTRL-SHIFT-F3"] == nil and gb.attributes["*macrotext-g3"] == nil, "cleared")
    check(G.Normalize({ [2] = "text:/cheer", [20] = "text:/x", [4] = 7 })[2] == "text:/cheer"
        and G.Normalize({ [20] = "text:/x" })[20] == nil, "normalize")
    G.Set(5, nil)
    -- (a slot's Focus UI: bound on its key, never held through WoW Helper)
    Holds()
    check(G.Set(4, "bind:focus"), "slot 4: Focus UI")
    eq(overrides["ALT-CTRL-SHIFT-F4"] and overrides["ALT-CTRL-SHIFT-F4"].action, "TOGGLEUIFOCUS", "slot 4 bound to Focus UI")
    eq(gb.attributes["*macrotext-g4"], nil, "no macro for it")
    if gb.scripts.PostClick then gb.scripts.PostClick(gb, "g4", true) end
    eq(Holds(), "", "slot 4: nothing held through WoW Helper")
    G.Set(4, nil)
end

-- L1 / R1: Blizzard's target bars, locked (no action of ours on any layer)
check(not ns.Keys.Allowed("PADLSHOULDER") and not ns.Keys.Allowed("PADRSHOULDER"), "L1 / R1 locked")
check(not ns.Keys.Set("PADRSHOULDER", "base", "text:/wave"), "R1 takes nothing")
check(ns.Keys.Normalize({ PADLSHOULDER = { base = "text:/wave" } }).PADLSHOULDER == nil, "a saved L1 action drops at load")

-- Rank: a spell slot's rank control under Choose; Choose places the highest
do
    local book, name, subtext, known = C_SpellBook, C_Spell.GetSpellName, C_Spell.GetSpellSubtext, IsSpellKnown
    local FROST = { [168] = 1, [7300] = 2, [7301] = 3 }
    C_Spell.GetSpellName = function(id) return FROST[id] and "Frost Armor" or name(id) end
    C_Spell.GetSpellSubtext = function(id) return FROST[id] and ("Rank " .. FROST[id]) or "" end
    IsSpellKnown = function(id) return FROST[id] ~= nil end
    C_SpellBook = { GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { name = "Frost", itemIndexOffset = 0, numSpellBookItems = 3 } end,
        GetSpellBookItemInfo = function(slot)
            local id = ({ 168, 7300, 7301 })[slot]
            return id and { spellID = id, actionID = id, name = "Frost Armor", iconID = 7, itemType = 1 }
        end }
    ns.SpellRanks.Forget()
    ClearCursor()
    if not window:IsVisible() then API.ToggleController() end
    check(window:IsVisible(), "rank: the Controller page open")
    ui.slots[3].scripts.OnClick(ui.slots[3])
    local storage = ui.slots[3].storage
    check(storage ~= nil, "rank: a slot")
    actions[storage] = { kind = "spell", id = 7301, texture = 1 }
    ui.slots[3].scripts.OnClick(ui.slots[3])
    check(ui.rank:IsShown(), "rank: shown for a spell with ranks")
    eq(ui.rank.value.text, "Highest", "rank: Highest by default")
    check(type(rawget(ui.rank, "gpcNudge")) == "function", "rank: one value row for the pad")
    ui.rank.gpcNudge(-1)
    eq(actions[storage].id, 7300, "rank: '<' from Highest is rank 2 (the next down)")
    eq(ui.rank.value.text, "Rank 2", "rank: shows Rank 2")
    check(cursor == nil, "rank: nothing on the cursor")
    ui.rank.minus.scripts.OnClick(ui.rank.minus)
    eq(actions[storage].id, 168, "rank: the arrow steps to rank 1")
    check(not ui.rank.minus.enabled, "rank: no lower than rank 1")
    ui.rank.gpcNudge(1); ui.rank.gpcNudge(1)
    eq(actions[storage].id, 7301, "rank: right to Highest")
    eq(ui.rank.value.text, "Highest", "rank: Highest again")
    check(GamepadCompanionCharDB.spellPins == nil, "rank: nothing in the Controls profile")
    -- Choose: a spell picked goes on at its top rank
    ui.rank.gpcNudge(-1)
    local open, req = ns.Picker.Open, nil
    ns.Picker.Open = function(r) req = r end
    ui.choose.scripts.OnClick(ui.choose)
    ns.Picker.Open = open
    eq(req and req.current, "spell:7300", "Choose: the rank held is current")
    req.onPick("spell:7300")
    eq(actions[storage].id, 7300, "Choose: the same rank again changes nothing")
    req.onPick("spell:168")
    eq(actions[storage].id, 7301, "Choose: a spell picked goes on at its top rank")
    -- Choose: a drop the game refuses leaves the old rank as it was (not moved up)
    actions[storage] = { kind = "spell", id = 168, texture = 1 }
    local place = PlaceAction
    PlaceAction = function(i) if cursor == 7301 then return end; return place(i) end
    req.onPick("spell:7300")
    PlaceAction = place
    eq(actions[storage] and actions[storage].id, 168, "refused drop: rank 1 stays, not moved up")
    check(cursor == nil, "refused drop: nothing on the cursor")
    -- No rank row for a spell without ranks
    actions[storage] = { kind = "spell", id = 133, texture = 1 }
    ui.slots[3].scripts.OnClick(ui.slots[3])
    check(not ui.rank:IsShown(), "rank: hidden for a spell without ranks")
    actions[storage] = nil
    C_SpellBook, C_Spell.GetSpellName, C_Spell.GetSpellSubtext, IsSpellKnown = book, name, subtext, known
    ns.SpellRanks.Forget()
end

-- The pad stuck by another addon's taint on a window's closing (2026-11-24). The game's blocked
-- event brings the stack and the tainted slots into the trace (the first three a session), a
-- frame later too; Cross's style closure tainted is the mark the health check finds with no
-- event at all, said once per addon. All reads: issecurevariable, never a write of ours.
do
    local errors = function() return GamepadCompanionTraceDB.errors end
    local said = {}
    local add = UIErrorsFrame and UIErrorsFrame.AddMessage
    UIErrorsFrame = UIErrorsFrame or {}
    UIErrorsFrame.AddMessage = function(_, text) said[#said + 1] = text end
    local tainted = {}   -- [table][key] = the addon whose taint the slot carries
    issecurevariable = function(t, k) local who = tainted[t] and tainted[t][k]; if who then return false, who end; return true, nil end
    debugstack = function() return "Blizzard_X/A.lua:1\nInterface/AddOns/Auctionator/B.lua:2" end
    local manager = GamepadSharedUtility.InputBindingManager
    local interact, back, jump = {}, {}, {}
    GamepadMainActionBarFrame.PageUnit.actionBars = { topBar = { Right = { ActionButton1 = interact, ActionButton3 = back, ActionButton4 = jump } } }
    manager.bindingSetStack = { { name = "SmartNavigationBindings" } }
    manager.activeBindings = { PAD1 = {} }
    eq(Keys.PadStuckBy(), nil, "a clean pad: not stuck")
    eq(Keys.PadHealth(), nil, "health: nothing to say")
    check(Keys.PadSlots():find("^none tainted; %d+ clean$") ~= nil, "slots: none tainted, the clean ones counted")
    -- (Auctionator's block was said above already: a second addon here)
    local n0 = #errors()
    Keys.Blocked("Spoken", "SetPreferredGamepadInteractTarget()")
    eq(said[#said], "Pad stuck by Spoken · hold Cross to reload", "blocked: said with the addon the game blames")
    eq(#errors(), n0 + 3, "blocked: BLOCKED, STACK, SLOTS written down")
    check(errors()[n0 + 1]:find("BLOCKED SetPreferredGamepadInteractTarget() by Spoken", 1, true) ~= nil, "the block")
    check(errors()[n0 + 2]:find("STACK Blizzard_X/A.lua:1 | Auctionator/B.lua:2", 1, true) ~= nil, "the stack, one line, short paths")
    check(errors()[n0 + 3]:find("SLOTS none tainted", 1, true) ~= nil, "the slots at the call")
    -- the listener's tainted rewrite lands after the refused call: seen a frame later
    tainted[interact] = { ApplyExtraButtonStylesForState = "Spoken" }
    tainted[manager] = { currentCoreBindingActive = "Spoken" }
    tainted[manager.activeBindings] = { PAD1 = "Spoken" }
    RunTimers()
    local plus = errors()[#errors()]
    check(plus:find("SLOTS+1 tainted ", 1, true) ~= nil, "a frame later: the tainted slots")
    check(plus:find("core-active=Spoken", 1, true) and plus:find("interact.closure=Spoken", 1, true)
        and plus:find("active-bindings:1(PAD1=Spoken)", 1, true), "each named with its addon")
    eq(Keys.PadStuckBy(), "Spoken", "stuck: Cross's closure carries Spoken's taint")
    -- (into: each tainted slot by its own label, a binding by its key: PadRescue compares two)
    local into = {}
    Keys.PadSlots(into)
    eq(into["binding PAD1"], "Spoken", "into: the active binding by its key")
    eq(into["core-active"], "Spoken", "into: the manager's field")
    eq(into["interact.closure"], "Spoken", "into: Cross's closure")
    eq(into["back.closure"], nil, "into: a clean slot left out")
    local n = #said
    eq(Keys.PadHealth(), "Spoken", "health finds it")
    eq(#said, n, "not said twice for the same addon")
    tainted[interact].ApplyExtraButtonStylesForState = "Details"
    eq(Keys.PadHealth(), "Details", "another addon's mark")
    eq(said[#said], "Pad stuck by Details · hold Cross to reload", "said for it")
    check(errors()[#errors() - 1]:find("STUCK by Details: Cross's style closure tainted", 1, true) ~= nil, "written down, with the slots after")
    Keys.PadHealth()
    eq(#said, n + 1, "once per addon")
    -- the stacks: three a session (Auctionator's above, Spoken's, this one), then the one BLOCKED line
    Keys.Blocked("Details", "SetPreferredGamepadInteractTarget()")
    RunTimers()
    local n1 = #errors()
    Keys.Blocked("Details", "SetPreferredGamepadInteractTarget()")
    RunTimers()
    eq(#errors(), n1 + 1, "the fourth block: one line")
    check(errors()[#errors()]:find("BLOCKED", 1, true) ~= nil, "the block itself")
    n1 = #errors()
    Keys.Blocked("Details", "SomethingElse()")
    eq(#errors(), n1, "another protected function: not the hand-back, nothing")
    UIErrorsFrame.AddMessage = add
    issecurevariable, debugstack = nil, nil
    GamepadMainActionBarFrame.PageUnit.actionBars, manager.bindingSetStack, manager.activeBindings = nil, nil, nil
end

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
