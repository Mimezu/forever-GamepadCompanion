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
GetTime = function() return 100 end
GetCVar = function(n) return cvars[n] end
SetCVar = function(n, v) cvars[n] = tostring(v) end
function print() end
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
function hooksecurefunc() end
C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end }
local wraps = {}   -- frame name -> the wrapped OnClick body
function SecureHandlerWrapScript(frame, _, _, body) if frame.name then wraps[frame.name] = body end end
-- As the game: each owner has one priority override per key, the newest set
-- runs (overrides[key]); an owner cleared uncovers the one set before it
local stacks = {}   -- key -> the owners' entries, oldest first
local function Push(key, entry)
    local list = stacks[key] or {}
    stacks[key] = list
    for i = #list, 1, -1 do if list[i].owner == entry.owner then table.remove(list, i) end end
    list[#list + 1] = entry
    overrides[key] = entry
end
-- (the game's gamepad functions live in a set of their own, binding context 9: another
-- command put over one leaves it there; only clearing the key removes it. Login probe, 2026-11-22)
local PAD_SET = { TOGGLEUIFOCUS = true, OPENRADIAL = true }
local padSet = {}   -- key -> { owner, action }
-- (and a key held down keeps the gamepad function its press ran, for good, whatever is
-- done to its owner's binding meanwhile: Create, L2 let go first, 2026-11-22)
local function Latched(key) return padSet[key] and HELD_KEYS and HELD_KEYS[key] end
C_KeyBindings = { GetBindingByKey = function(key, context)
    if context == 9 and padSet[key] then return padSet[key].action end
    return overrides[key] and overrides[key].action or nil
end }
function ClearOverrideBindings(owner)
    for key, b in pairs(padSet) do
        if b.owner == owner then if Latched(key) then b.owner = "latched" else padSet[key] = nil end end
    end
    for key, list in pairs(stacks) do
        for i = #list, 1, -1 do if list[i].owner == owner then table.remove(list, i) end end
        if overrides[key] and overrides[key].owner == owner then overrides[key] = list[#list] end
    end
    for k, b in pairs(overrides) do if b.owner == owner then overrides[k] = nil end end
end
function SetOverrideBindingClick(owner, _, key) Push(key, { owner = owner, action = "CLICK" }) end
-- (nil: that owner's override on key gone, the one set before it uncovered)
local function Drop(owner, key)
    local list = stacks[key] or {}
    for i = #list, 1, -1 do if list[i].owner == owner then table.remove(list, i) end end
    if overrides[key] and overrides[key].owner == owner then overrides[key] = list[#list] end
end
function SetOverrideBinding(owner, _, key, action)
    if action == nil then
        if padSet[key] and padSet[key].owner == owner then
            if Latched(key) then padSet[key].owner = "latched" else padSet[key] = nil end
        end
        return Drop(owner, key)
    end
    if PAD_SET[action] then padSet[key] = { owner = owner, action = action }
    elseif Latched(key) then padSet[key].owner = "latched" end
    Push(key, { owner = owner, action = action })
end
function GetBindingAction(key) return overrides[key] and overrides[key].action or "" end
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
HELD_KEYS = pressed
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
local bindings = { PADLSTICK = "TOGGLEAUTORUN" }
local overridesRead = GetBindingAction
-- (checkOverride, as the game: an override on the key wins over its own binding)
GetBindingAction = function(key, override)
    if override and overrides[key] then return overrides[key].action end
    return bindings[key] or overridesRead(key)
end
-- As the game: binding indexes are 0-based, the state's buttons 1-based
local ButtonIndex = { PADRSHOULDER = 9, PADLTRIGGER = 10, PADRTRIGGER = 11, PAD1 = 0, PADDUP = 12, PADBACK = 18, PADSOCIAL = 16 }
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
-- Bindings keep the clicked button's name
function SetOverrideBindingClick(owner, _, key, name, button)
    Push(key, { owner = owner, action = "CLICK " .. name .. ":" .. (button or "LeftButton") })
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
    "SpreadOverview.lua", "SpellRanks.lua", "OptionsSkin.lua", "Window.lua", "Picker.lua", "ControllerWindow.lua" }) do
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
eq(table.concat(keys, ","), "spells:Holy,quick,items,macros,halo,windows,text", "bar slot: every kind")
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
eq(table.concat(keys, ","), "spells:Holy,quick,items,macros,halo,windows,gamepad,text", "button: every kind")
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
-- Focus UI on a button: its key runs Blizzard's binding (in combat too)
check(Keys.Set("PADSYSTEM", "base", "bind:focus"), "PS: Focus UI")
eq(overrides.PADSYSTEM and overrides.PADSYSTEM.action, "TOGGLEUIFOCUS", "PS bound to Blizzard's Focus UI")
Keys.Set("PADSYSTEM", "base", nil)
eq(overrides.PADSYSTEM, nil, "cleared")
eq(select(2, ns.SlotMacros.Ensure("bind:focus")), "Not on bar slots", "no bar slot macro for it")
check(Keys.Set("PADSYSTEM", "base", "bind:radial"), "PS: Radial")
eq(overrides.PADSYSTEM and overrides.PADSYSTEM.action, "OPENRADIAL", "PS bound to Blizzard's Radial")
check(Keys.Set("PADSYSTEM", "base", "bind:focus"), "PS: Focus UI again")
-- L2 / R2 on the small buttons: one static binding per key, the layer read at the press (the touchpad's way)
local keySnippet = assert(loadstring("local self, button, down = ...\n" .. assert(wraps.GamepadCompanionKeys, "keys snippet wrapped")))
setfenv(keySnippet, { GetGamePadState = function() return C_GamePad.GetDeviceMappedState() end })
local kb = _G.GamepadCompanionKeys
-- A press of key with L2 / R2 held (released before the button's own release
-- with early): the macro that ran, as SecureActionButton_OnClick runs it
local function PressKey(key, lt, rt, early)
    local name = overrides[key] and overrides[key].action:match("^CLICK GamepadCompanionKeys:(%w+)$")
    if not name then return nil end
    pressed.PADLTRIGGER, pressed.PADRTRIGGER = lt or false, rt or false
    local ran
    for _, down in ipairs({ true, false }) do
        if not down and early then pressed.PADLTRIGGER, pressed.PADRTRIGGER = false, false end
        local id = keySnippet(kb, name, down)
        if id and down == (cvars.ActionButtonUseKeyDown == "1") then ran = kb:GetAttribute("*macrotext-" .. id) end
    end
    pressed.PADLTRIGGER, pressed.PADRTRIGGER = nil, nil
    return ran
end
local changes = 0
local clear, set, setClick = ClearOverrideBindings, SetOverrideBinding, SetOverrideBindingClick
-- (the keys' own bindings; the touchpad's are its own)
local keyOwner = _G.GamepadCompanionKeyBinds
local function Count(owner) if owner == keyOwner then changes = changes + 1 end end
ClearOverrideBindings = function(owner, ...) Count(owner); return clear(owner, ...) end
SetOverrideBinding = function(owner, ...) Count(owner); return set(owner, ...) end
SetOverrideBindingClick = function(owner, ...) Count(owner); return setClick(owner, ...) end
-- The triggers as the watcher reads them: the pad itself (pressed, through
-- C_GamePad.GetDeviceMappedState), never the game's key state. IsKeyDown says
-- L2 is down the whole time here (as it did with L2 up, 2026-11-21): it must
-- change nothing
local keyDown = { PADLTRIGGER = true }
IsKeyDown = function(key) return keyDown[key] or false end
local bindingKey = GetBindingKey
GetBindingKey = function(command, ...)
    if command == "GAMEPADLEFTMOD" then return "PADLTRIGGER" end
    if command == "GAMEPADRIGHTMOD" then return "PADRTRIGGER" end
    return bindingKey(command, ...)
end
local layerOwner = _G.GamepadCompanionKeyLayers
-- Options is Blizzard's Radial (a Blizzard function runs only from its binding): kept;
-- L2 + Options runs out of combat, by the watcher putting the secure click on it while L2 is held
bindings.PADFORWARD = "OPENRADIAL"
check(Keys.Set("PADFORWARD", "lt", "text:/randompet"), "L2 + Options: Random pet")
eq(overrides.PADFORWARD, nil, "Options stays Blizzard's Radial")
local runs, why = Keys.Runs("PADFORWARD", "lt")
check(runs == true and why == "out of combat", "L2 + Options: out of combat")
ui.buttons.options.scripts.OnClick(ui.buttons.options)
ui.layers.lt.scripts.OnClick(ui.layers.lt)
eq(ui.kind.text, "Typed macro · out of combat", "card: a short note")
ui.layers.base.scripts.OnClick(ui.layers.base)
pressed.PADLTRIGGER = true; Keys.Watch()
eq(overrides.PADFORWARD and overrides.PADFORWARD.action, "CLICK GamepadCompanionKeys:p6", "L2 held: Options on the click")
eq(PressKey("PADFORWARD", true), "/randompet", "L2 + Options: Random pet")
pressed.PADLTRIGGER = nil; Keys.Watch()
eq(overrides.PADFORWARD, nil, "L2 released: Radial again")
changes = 0
pressed.PADRTRIGGER = true; Keys.Watch()
local layerChanged = overrides.PADFORWARD ~= nil
pressed.PADRTRIGGER = nil; Keys.Watch()
check(not layerChanged, "R2 held, nothing on R2: Options untouched (Blizzard's R2 bar left alone)")
combat = true; pressed.PADLTRIGGER = true; Keys.Watch()
eq(overrides.PADFORWARD, nil, "in combat: Options stays Radial")
combat = false; pressed.PADLTRIGGER = nil
-- A Base of ours: every layer runs, picked by the triggers at the press
check(Keys.Set("PADFORWARD", "base", "text:/sit"), "Options: a macro")
eq(overrides.PADFORWARD and overrides.PADFORWARD.action, "CLICK GamepadCompanionKeys:p6", "Options on the secure click")
check(Keys.Runs("PADFORWARD", "lt"), "L2 + Options runs now")
eq(PressKey("PADFORWARD"), "/sit", "plain: Base")
eq(PressKey("PADFORWARD", true), "/randompet", "L2: its action")
eq(PressKey("PADFORWARD", false, true), "/sit", "R2, empty: falls back to Base")
eq(PressKey("PADFORWARD", true, true), "/sit", "L2 R2, empty: Base")
Keys.Set("PADFORWARD", "both", "text:/cheer")
eq(PressKey("PADFORWARD", true, true), "/cheer", "L2 R2: its action")
-- Acting on the release: the layer of the press, though L2 let go first
cvars.ActionButtonUseKeyDown = "0"
eq(PressKey("PADFORWARD", true, false, true), "/randompet", "on the release: the press's layer")
cvars.ActionButtonUseKeyDown = "1"
-- A Blizzard function on a layer: the click runs nothing (no fallback to Base);
-- out of combat the watcher puts its binding on the key while R2 is held
Keys.Set("PADFORWARD", "rt", "bind:focus")
runs, why = Keys.Runs("PADFORWARD", "rt")
check(runs == true and why == "out of combat", "R2 + Options: Focus UI, out of combat")
eq(PressKey("PADFORWARD", false, true), nil, "R2 + Options from the click: nothing")
pressed.PADRTRIGGER = true; Keys.Watch()
eq(overrides.PADFORWARD and overrides.PADFORWARD.action, "TOGGLEUIFOCUS", "R2 held: Focus UI on Options")
pressed.PADRTRIGGER = nil; Keys.Watch()
check(not (overrides.PADFORWARD and overrides.PADFORWARD.owner == layerOwner), "R2 released: the watcher's binding off")
-- Create: the game's World Map; L2 + Create = Focus UI (the player's setup, 2026-11-21).
-- The game's key state says L2 is down (IsKeyDown above) while the pad says it is up:
-- Create stays the map. Only the pad's L2 puts Focus UI on it, and a release takes it off
bindings.PADSOCIAL = "TOGGLEWORLDMAP"
-- (what Create runs: an override of ours, else the game's binding)
local function CreateRuns() return overrides.PADSOCIAL and overrides.PADSOCIAL.action or bindings.PADSOCIAL end
check(Keys.Set("PADSOCIAL", "lt", "bind:focus"), "L2 + Create: Focus UI")
eq(overrides.PADSOCIAL, nil, "Create stays the game's World Map")
Keys.Watch()
eq(CreateRuns(), "TOGGLEWORLDMAP", "L2 up on the pad (down for IsKeyDown): Create is the map")
pressed.PADLTRIGGER = true; Keys.Watch()
eq(CreateRuns(), "TOGGLEUIFOCUS", "L2 held on the pad: Focus UI on Create")
-- (the release, seen by Blizzard's modifier handler before the next tick: off at once)
pressed.PADLTRIGGER = nil
for _, fn in ipairs(hooks.OnCrossBarModifierChanged or {}) do fn("left", false) end
eq(CreateRuns(), "TOGGLEWORLDMAP", "L2 released: the map again, before the watcher's tick")
-- (no pad to read: nothing of a layer stays bound)
pressed.PADLTRIGGER = true; Keys.Watch()
local padState = C_GamePad.GetDeviceMappedState
C_GamePad.GetDeviceMappedState = function() return nil end
Keys.Watch()
eq(CreateRuns(), "TOGGLEWORLDMAP", "the pad can't be read: Focus UI off Create")
C_GamePad.GetDeviceMappedState = padState
-- (another pad while L2 is held: off until it is read)
Keys.Watch()
eq(CreateRuns(), "TOGGLEUIFOCUS", "L2 held again")
Fire("GAME_PAD_ACTIVE_CHANGED")
eq(CreateRuns(), "TOGGLEWORLDMAP", "pad changed: Focus UI off Create")
pressed.PADLTRIGGER = nil; Keys.Watch()
Keys.Set("PADSOCIAL", "lt", nil)
bindings.PADSOCIAL = nil
-- The player's setup (2026-11-21): Create = Quests & Map (the secure click), L2 + Create =
-- Focus UI; Options = Radial, L2 + Options = Focus UI. Blizzard, from its FrameXML: a focused
-- window's footer binds Options on UIParent (InputFunctionBinding) and its core set takes it
-- back when the window closes (InputBindingManager.ReloadBindings)
local manager = GamepadMode.FrameControlsManager
local CLICK_CREATE = "CLICK GamepadCompanionKeys:p5"
local function Create() return GetBindingAction("PADSOCIAL", true) end
check(Keys.Set("PADSOCIAL", "base", "window:questlog"), "Create: Quests & Map")
check(Keys.Set("PADSOCIAL", "lt", "bind:focus"), "L2 + Create: Focus UI")
check(Keys.Set("PADFORWARD", "base", "bind:radial") and Keys.Set("PADFORWARD", "lt", "bind:focus"), "Options: Radial, L2 + Options: Focus UI")
eq(Create(), CLICK_CREATE, "Create: the map")
pressed.PADLTRIGGER = true; Keys.Watch()
eq(Create(), "TOGGLEUIFOCUS", "L2 + Create: Focus UI")
-- the map takes the pad's focus: its footer binds Options; Companion puts Radial back on top
-- next frame, the held layer's Focus UI still above Create
manager:SetUIFocusState(true)
SetOverrideBindingClick(UIParent, true, "PADFORWARD", "InputFunctionBindingButton_PADFORWARD", "LeftButton")
for _, fn in ipairs(hooks.SetOverrideBindingClick or {}) do fn(UIParent, true, "PADFORWARD", "InputFunctionBindingButton_PADFORWARD") end
RunTimers()
eq(GetBindingAction("PADFORWARD", true), "TOGGLEUIFOCUS", "the map focused, L2 still held: L2 + Options is Focus UI, above Blizzard's footer")
eq(Create(), "TOGGLEUIFOCUS", "L2 still held: Focus UI stays above Base on Create")
pressed.PADLTRIGGER = nil; Keys.Watch()
eq(Create(), CLICK_CREATE, "L2 up with the map focused: Create is the map")
-- (the held layer's function above Base on the layer owner, taken off on release; Base itself
-- never rewritten: the map's click put back over Focus UI left Focus UI in the game's gamepad
-- set, 2026-11-22. Halo's ring under it never broke)
for key, list in pairs(stacks) do
    for _, entry in ipairs(list) do check(entry.owner ~= layerOwner, "L2 up: no layer binding left: " .. key) end
end
local baseWrites = 0
local setNow = SetOverrideBinding
SetOverrideBinding = function(o, p, key, ...)
    if o == keyOwner and key == "PADSOCIAL" then baseWrites = baseWrites + 1 end
    return setNow(o, p, key, ...)
end
pressed.PADLTRIGGER = true; Keys.Watch()
eq(Create(), "TOGGLEUIFOCUS", "L2 held: Focus UI above Base")
eq(stacks.PADSOCIAL[#stacks.PADSOCIAL].owner, layerOwner, "L2 held: on the layer owner")
pressed.PADLTRIGGER = nil; Keys.Watch()
eq(Create(), CLICK_CREATE, "L2 up: Base uncovered")
eq(#(stacks.PADSOCIAL or {}), 1, "L2 up: Base alone")
eq(baseWrites, 0, "Base never rewritten by L2")
SetOverrideBinding = setNow
-- (the game keeps SetOverrideBindingClick's entries apart from commands: a Focus UI command
-- swapped for Create's click stayed and ran under it, 2026-11-21. Every key of ours is bound as a
-- command string, the click too, so a layer's command replaces it and gives it back)
local clicks = 0
local setClickNow = SetOverrideBindingClick
SetOverrideBindingClick = function(owner, ...)
    if owner == keyOwner then clicks = clicks + 1 end
    return setClickNow(owner, ...)
end
pressed.PADLTRIGGER = true; Keys.Watch()
eq(Create(), "TOGGLEUIFOCUS", "L2 held: Focus UI")
pressed.PADLTRIGGER = nil; Keys.Watch()
eq(Create(), CLICK_CREATE, "L2 up: the map")
Keys.Apply(true)
eq(Create(), CLICK_CREATE, "bound again: the map")
eq(clicks, 0, "never a click entry on the keys' owner")
pressed.PADLTRIGGER = true; Keys.Watch()
pressed.PADLTRIGGER = nil; Keys.Watch()
eq(C_KeyBindings.GetBindingByKey("PADSOCIAL", 9), CLICK_CREATE, "L2 up: no Focus UI left in the gamepad set under the map")
-- (one left there anyway: the heal clears it)
padSet.PADSOCIAL = { owner = keyOwner, action = "TOGGLEUIFOCUS" }
check(Keys.Heal(), "Focus UI under the map: healed")
eq(C_KeyBindings.GetBindingByKey("PADSOCIAL", 9), CLICK_CREATE, "healed: the map alone")
check(not Keys.Heal(), "then nothing to heal")
-- L2 + Create, L2 let go a moment before Create: Create is left alone while held, Base back once up
pressed.PADLTRIGGER = true; Keys.Watch()
pressed.PADSOCIAL = true
pressed.PADLTRIGGER = nil; Keys.Watch()
eq(Create(), "TOGGLEUIFOCUS", "L2 up, Create still held: untouched till it is up")
pressed.PADSOCIAL = nil; Keys.Watch()
eq(Create(), CLICK_CREATE, "Create up: the map")
eq(C_KeyBindings.GetBindingByKey("PADSOCIAL", 9), CLICK_CREATE, "no Focus UI kept under the map")
-- (Create held first, then L2: Focus UI waits for Create to be up)
pressed.PADSOCIAL = true
pressed.PADLTRIGGER = true; Keys.Watch()
eq(Create(), CLICK_CREATE, "Create held, then L2: Create untouched")
pressed.PADSOCIAL = nil; Keys.Watch()
eq(Create(), "TOGGLEUIFOCUS", "Create up, L2 held: Focus UI")
pressed.PADLTRIGGER = nil; Keys.Watch()
eq(Create(), CLICK_CREATE, "L2 up: the map")
-- (a leftover the rebind can't clear: healed once, not every tick)
padSet.PADSOCIAL = { owner = "latched", action = "TOGGLEUIFOCUS" }
check(Keys.Heal(), "a stuck Focus UI: one try")
check(not Keys.Heal(), "then left (no rebind 4 times a second)")
padSet.PADSOCIAL = nil
check(not Keys.Heal(), "gone: nothing to heal")
-- L2 + Create opens a window: Blizzard binds its keys on UIParent while Create is still down.
-- No rebind then (it took Focus UI off Create mid-press, and the game kept it: 2026-11-22)
pressed.PADLTRIGGER = true; Keys.Watch()
pressed.PADSOCIAL = true
SetOverrideBindingClick(UIParent, true, "PADDUP", "SomeFooterButton", "LeftButton")
for _, fn in ipairs(hooks.SetOverrideBindingClick or {}) do fn(UIParent, true, "PADDUP", "SomeFooterButton") end
RunTimers()
Keys.Apply(true)
for _ = 1, 3 do Keys.Heal() end
eq(Create(), "TOGGLEUIFOCUS", "Create held: Focus UI untouched by any rebind")
pressed.PADSOCIAL = nil
pressed.PADLTRIGGER = nil; Keys.Watch()
Keys.Apply(true)
eq(Create(), CLICK_CREATE, "both up: the map")
eq(C_KeyBindings.GetBindingByKey("PADSOCIAL", 9), CLICK_CREATE, "both up: no Focus UI left under the map")
SetOverrideBinding(UIParent, true, "PADDUP", nil)
SetOverrideBindingClick = setClickNow
eq(GetBindingAction("PADFORWARD", true), "OPENRADIAL", "L2 up: Options is Radial, back on top of the footer's binding")
-- the map closes while focused: Blizzard's core set binds Options again, and Create is left
-- with Focus UI by another owner. The moment the focus ends, Create is put right
local other = {}
Push("PADSOCIAL", { owner = other, action = "TOGGLEUIFOCUS" })
SetOverrideBinding(UIParent, true, "PADFORWARD", "OPENRADIAL")
for _, fn in ipairs(hooks.SetOverrideBinding or {}) do fn(UIParent, true, "PADFORWARD", "OPENRADIAL") end
eq(Create(), "TOGGLEUIFOCUS", "(left behind)")
manager:SetUIFocusState(false)
for _, fn in ipairs(hooks.SetUIFocusState or {}) do fn(manager, false) end
RunTimers()
eq(Create(), CLICK_CREATE, "focus ended: Create is the map, whatever was left on it")
-- the same leftover out of any window: the watcher's check puts it right within a quarter second
Push("PADSOCIAL", { owner = other, action = "TOGGLEUIFOCUS" })
check(Keys.Heal(), "a leftover found")
eq(Create(), CLICK_CREATE, "healed: the map")
check(not Keys.Heal(), "nothing to heal")
-- a leftover of ours on a key the game owns (Mute, L2 = Focus UI, no Base): cleared; another
-- addon's binding there is not ours to touch
bindings.PAD5 = "FRAMEGAMBIT_TOGGLE_CINEMATIC_CAMERA"
check(Keys.Set("PAD5", "lt", "bind:focus"), "L2 + Mute: Focus UI")
Push("PAD5", { owner = layerOwner, action = "TOGGLEUIFOCUS" })
check(Keys.Heal(), "Mute: a leftover of ours")
eq(GetBindingAction("PAD5", true), "FRAMEGAMBIT_TOGGLE_CINEMATIC_CAMERA", "Mute: the game's own again")
Push("PAD5", { owner = other, action = "SOMETHING_ELSE" })
check(not Keys.Heal(), "another addon's binding on Mute: left alone")
-- In game a Blizzard function on Base (Options: Radial) reads back empty: not a key to heal
-- (it was: 4 heals a second, every key rebound each time, 2026-11-21)
check(Keys.Set("PADFORWARD", "base", "bind:radial"), "Options: Radial")
local engineRead = GetBindingAction
GetBindingAction = function(key, override) if key == "PADFORWARD" then return "" end return engineRead(key, override) end
check(not Keys.Heal(), "Radial reading empty: nothing to heal")
check(not Keys.Heal(), "and again: still nothing (no churn)")
GetBindingAction = engineRead
ClearOverrideBindings(other)
ClearOverrideBindings(UIParent)
for _, l in ipairs({ "base", "lt" }) do Keys.Set("PADSOCIAL", l, nil); Keys.Set("PADFORWARD", l, nil) end
Keys.Set("PAD5", "lt", nil)
bindings.PAD5 = nil
Keys.Apply(true)
-- Nothing rebinds while a trigger is held: presses, macro and spell changes
changes = 0
pressed.PADRTRIGGER = true
PressKey("PADFORWARD", false, true)
Fire("SPELLS_CHANGED"); Fire("UPDATE_MACROS"); Fire("PLAYER_ENTERING_WORLD")
eq(changes, 0, "no binding changes while R2 is held")
pressed.PADRTRIGGER = nil
-- A key the game leaves free (Mute): its layers run with an empty Base
check(Keys.Set("PAD5", "lt", "text:/wave"), "L2 + Mute")
eq(overrides.PAD5 and overrides.PAD5.action, "CLICK GamepadCompanionKeys:p8", "Mute on the secure click")
eq(PressKey("PAD5"), nil, "plain Mute: nothing")
eq(PressKey("PAD5", true), "/wave", "L2 + Mute")
-- Base back to Blizzard: Options is Radial again
for _, l in ipairs({ "base", "lt", "rt", "both" }) do Keys.Set("PADFORWARD", l, nil) end
Keys.Set("PAD5", "lt", nil)
eq(overrides.PADFORWARD, nil, "Options: Blizzard's again")
eq(overrides.PAD5, nil, "Mute: unbound")
-- No layer action anywhere: the watcher reads no pad
local reads, mapped = 0, C_GamePad.GetDeviceMappedState
C_GamePad.GetDeviceMappedState = function(...) reads = reads + 1; return mapped(...) end
pressed.PADLTRIGGER = true; Keys.Watch(); pressed.PADLTRIGGER = nil; Keys.Watch()
eq(reads, 0, "no layer action: the watcher reads nothing")
C_GamePad.GetDeviceMappedState = mapped
ClearOverrideBindings, SetOverrideBinding, SetOverrideBindingClick = clear, set, setClick
bindings.PADFORWARD = nil
IsKeyDown, GetBindingKey = nil, bindingKey
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

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
