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
function SecureHandlerWrapScript() end
function ClearOverrideBindings(owner) for k, b in pairs(overrides) do if b.owner == owner then overrides[k] = nil end end end
function SetOverrideBindingClick(owner, _, key) overrides[key] = { owner = owner, action = "CLICK" } end
function SetOverrideBinding(owner, _, key, action) overrides[key] = { owner = owner, action = action } end
function GetBindingAction(key) return overrides[key] and overrides[key].action or "" end
C_GamePad = {
    GetActiveDeviceID = function() return 1 end,
    ButtonBindingToIndex = function() return 0 end,
    GetDeviceMappedState = function() return { labelStyle = "Shapes", sticks = { [4] = { x = 0, y = 0 } }, buttons = {} } end,
    GetDeviceRawState = function() return { vendorID = 1356, productID = 3302 } end,
    GetConfig = function() end, SetConfig = function() end, DeleteConfig = function() end, ApplyConfigs = function() end,
}
InputUtil = { IsGamepadUIEnabled = function() return true end }
GamepadMode = { FrameControlsManager = { isUIFocused = false } }
GamepadSharedUtility = { InputBindingManager = { IsOnlyCoreBindingSetActive = function() return true end } }
C_Texture = { GetAtlasInfo = function() return { file = 1, width = 64, height = 64, leftTexCoord = 0, rightTexCoord = 1,
    topTexCoord = 0, bottomTexCoord = 1 } end }
C_Spell = { GetSpellName = function(id) return id == 133 and "Fireball" or nil end, GetSpellTexture = function() return 135812 end }
GetMacroInfo = function() end
GetCursorInfo = function() if cursor then return "spell", 1, "spell", cursor end end
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
GetActionInfo = function(i) local a = actions[i]; if a then return a.kind, a.id end end
GetActionTexture = function(i) return actions[i] and actions[i].texture end
GetActionText = function(i) return actions[i] and actions[i].kind == "macro" and actions[i].name or nil end
PickupAction = function(i)
    local a = actions[i]
    actions[i] = nil
    cursor = a and a.id or nil
end
PlaceAction = function(i)
    if cursor then actions[i] = { kind = "spell", id = cursor, texture = 135812 }; cursor = nil end
end
PickupSpell = function(id) cursor = id end
C_Spell.PickupSpell = PickupSpell
GetBindingKey = function(command) if command == "OPENRADIAL" then return "PADRSHOULDER" end end
local bindings = { PADLSTICK = "TOGGLEAUTORUN" }
local overridesRead = GetBindingAction
GetBindingAction = function(key) return bindings[key] or overridesRead(key) end
local ButtonIndex = { PADLTRIGGER = 1, PADRTRIGGER = 2, PAD1 = 3, PADDUP = 4, PADBACK = 5 }
C_GamePad.ButtonBindingToIndex = function(key) return ButtonIndex[key] end
C_GamePad.GetDeviceMappedState = function()
    local buttons = {}
    for key, index in pairs(ButtonIndex) do buttons[index] = pressed[key] or false end
    return { labelStyle = "Shapes", sticks = { [4] = { x = 0, y = 0 } }, buttons = buttons }
end

local hooks = {}
function hooksecurefunc(name, fn) hooks[name] = hooks[name] or {}; table.insert(hooks[name], fn) end
-- Bindings keep the clicked button's name
function SetOverrideBindingClick(owner, _, key, name, button)
    overrides[key] = { owner = owner, action = "CLICK " .. name .. ":" .. (button or "LeftButton") }
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
GetNumMacros = function() return 1, 0 end
GetMacroInfo = function(x) if x == 1 or x == "Mount" then return "Mount", 3, "/cast Summon Charger" end end
Halo = { db = { rings = { { id = 1, name = "Utility", slices = {} }, { id = 2, name = "Alt only", owner = "alt" } } },
    RingActiveHere = function(ring) return ring.owner == nil end, RingIcon = function() return 4 end }
GAMEPAD_MOD_LEFT, GAMEPAD_MOD_RIGHT, GAMEPAD_MOD_LEFT_AND_RIGHT = "SHIFT", "CTRL", "CTRL-SHIFT"
-- Per character: this character has no profile yet; the account has touch settings
GamepadCompanionCharDB = nil
GamepadCompanionTouchDB = { enabled = false, split = { device = "pad" }, actions = { chord = { base = { r1c1 = "window:bags" } } } }

local ns = {}
for _, file in ipairs({ "Model.lua", "TouchModel.lua", "Shared.lua", "Touchpad.lua", "Keys.lua", "ControllerModel.lua",
    "SpreadOverview.lua", "OptionsSkin.lua", "Picker.lua", "ControllerWindow.lua" }) do
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
eq(C.LayerOf(true, true), "both", "both triggers")
eq(C.Fixed("base", 8).name, "Jump", "base cross is jump")
eq(C.Fixed("lt", 8), nil, "L2 cross is a slot")
eq(C.CommandName("OPENRADIAL"), "Radial", "command names")
eq(C.CommandName("CLICK GamepadCompanionTouchClick:LeftButton"), "Touchpad zones", "our touchpad binding")
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
check(window and window:IsShown(), "opens")
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

-- The picker on a bar slot: spells, items, macros only
local picker, pui
ui.slots[2].scripts.OnClick(ui.slots[2])
ui.choose.scripts.OnClick(ui.choose)
picker, pui = ns.PickerWindow()
check(picker and picker:IsShown(), "choose opens the picker")
local keys = {}
for _, cat in ipairs(pui.categories) do keys[#keys + 1] = cat.key end
eq(table.concat(keys, ","), "spells:Holy,items,macros", "bar slot: spells, items, macros")
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

-- Buttons: Blizzard's defaults, then Companion's bindings per layer
ui.buttons.l1.scripts.OnClick(ui.buttons.l1)
eq(ui.name.text, "Enemy targets", "L1: Blizzard's default")
eq(ui.kind.text, "Blizzard", "marked Blizzard")
check(not ui.clear:IsEnabled(), "nothing of ours to clear")
ui.buttons.l3.scripts.OnClick(ui.buttons.l3)
ui.choose.scripts.OnClick(ui.choose)
keys = {}
for _, cat in ipairs(pui.categories) do keys[#keys + 1] = cat.key end
eq(table.concat(keys, ","), "spells:Holy,items,macros,halo,windows,text", "button: every kind")
pui.cats.halo.scripts.OnClick(pui.cats.halo)
eq(pui.tiles[1].entry.name, "Utility", "Halo rings of this character")
check(not pui.tiles[2]:IsShown(), "another character's ring left out")
pui.tiles[1].scripts.OnClick(pui.tiles[1])
eq(Keys.Get("PADLSTICK", "base"), "halo:1", "L3 runs the ring")
eq(GamepadCompanionCharDB.keys.PADLSTICK.base, "halo:1", "saved per character")
eq(overrides.PADLSTICK and overrides.PADLSTICK.action, "CLICK GamepadCompanionKeys:k1", "L3 bound")
eq(_G.GamepadCompanionKeys:GetAttribute("*macrotext-k1"), "/click HaloButton t1 LeftButton true", "ring macro")
eq(ui.name.text, "Utility", "card shows the ring")
check((ui.buttons.l3.text.text or ""):find("Utility", 1, true), "label on the art")
-- L2 + L3: a typed macro
ui.layers.lt.scripts.OnClick(ui.layers.lt)
eq(ui.rows[1].name.text, "Utility", "every layer: base")
ui.choose.scripts.OnClick(ui.choose)
pui.cats.text.scripts.OnClick(pui.cats.text)
check(pui.textPane:IsShown(), "typed macro pane")
pui.macro:SetText("/wave")
pui.useMacro.scripts.OnClick(pui.useMacro)
eq(Keys.Get("PADLSTICK", "lt"), "text:/wave", "L2 + L3 macro")
eq(overrides["SHIFT-PADLSTICK"] and overrides["SHIFT-PADLSTICK"].action, "CLICK GamepadCompanionKeys:k2", "Shift = L2")
-- Blizzard takes the key back: put back next frame
overrides.PADLSTICK = { owner = UIParent, action = "TOGGLEAUTORUN" }
for _, fn in ipairs(hooks.SetOverrideBinding or {}) do fn(UIParent, true, "PADLSTICK", "TOGGLEAUTORUN") end
RunTimers()
eq(overrides.PADLSTICK.action, "CLICK GamepadCompanionKeys:k1", "binding put back")
-- Clear, in combat it waits
combat = true
ui.clear.scripts.OnClick(ui.clear)
eq(Keys.Get("PADLSTICK", "lt"), nil, "cleared")
check(overrides["SHIFT-PADLSTICK"] ~= nil, "binding waits for combat to end")
combat = false
Fire("PLAYER_REGEN_ENABLED")
eq(overrides["SHIFT-PADLSTICK"], nil, "binding gone after combat")
ui.layers.base.scripts.OnClick(ui.layers.base)
ui.buttons.ps.scripts.OnClick(ui.buttons.ps)
eq(ui.name.text, "Empty", "PS unbound")
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
for i = 1, 24 do local t = pui.tiles[i]; if t and t.entry and t.entry.action == "window:map" then map = t end end
map.scripts.OnClick(map)
eq(Touch.Settings().actions.chord.base.r2c3, "window:map", "window from the picker")
eq(ui.name.text, "World Map", "card shows the binding")
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
eq(Touch.Runs("halo:1"), "/click HaloButton t1 LeftButton true", "ring macro for zones")
tp.swipes["swipe-up"].scripts.OnClick(tp.swipes["swipe-up"])
eq(tp.zoneTitle.text, "Swipe up · L2", "swipe picked")
check(not tp.slots.touch:IsEnabled(), "swipes: click slot only")
tp.modes.split.scripts.OnClick(tp.modes.split)
check(not tp.inputs.dual:IsEnabled(), "right half: no touch + click")
tp.modes.chord.scripts.OnClick(tp.modes.chord)
ui.layers.base.scripts.OnClick(ui.layers.base)
API.ToggleTouchpad()
check(not window:IsShown(), "touchpad toggle closes")
API.ToggleController()

-- Held triggers and pressed buttons
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
check(not window:IsShown(), "toggle closes")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
