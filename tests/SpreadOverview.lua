local root = arg[1] or "."
local ns, frames = {}, {}
local methods = {}
local function object()
    return setmetatable({ shown = true, scripts = {} }, { __index = methods })
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width or 1920 end
function methods:GetHeight() return self.height or 1080 end
function methods:CreateFontString() return object() end
function methods:CreateTexture() return object() end
function methods:CreateMaskTexture() return object() end
function methods:SetAtlas(value) self.atlas = value end
function methods:AddMaskTexture(value) self.mask = value end
function methods:SetFrameStrata(value) self.strata = value end
function methods:SetText(value) self.text = value end
function methods:SetTexture(value) self.texture = value end
function methods:SetPoint(...) self.point = {...} end
function methods:SetScale(value) self.scale = value end
function methods:SetScript(key, value) self.scripts[key] = value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = value end
for _, name in ipairs({"SetFontObject", "SetJustifyH", "SetWidth", "RegisterForDrag", "RegisterForClicks", "SetAllPoints",
    "SetColorTexture", "ClearAllPoints", "SetTextColor"}) do methods[name] = function() end end
CreateFrame = function(_, _, parent)
    local f = object(); f.parent = parent; frames[#frames + 1] = f; return f
end
UIParent = object()
local active, form, stealth = 281, 1, false
Constants = { GamepadActionBarConstants = {
    NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT = 3,
    NUM_PAGEABLE_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT_STANDARD_PAGE = 32,
    NUM_RESERVED_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT = 4,
    NUM_GAMEPAD_STANCE_ACTION_BARS = 5, NUM_SLOTS_PER_GAMEPAD_ACTION_BAR = 8,
} }
local invalid
C_GamepadUI = {
    GetFirstGamepadActionStorageSlotIndex = function() return 181 end,
    GetFirstGamepadActionBarStorageSlotIndexForActiveStance = function() return active end,
    IsValidGamepadActionStorageSlotIndex = function(slot) return slot >= 181 and slot <= 304 and slot ~= invalid end,
}
C_ActionBar = { HasBonusActionBar = function() return form ~= 0 end }
UnitGUID = function() return "druid-one" end
GetNumShapeshiftForms = function() return 2 end
GetShapeshiftFormInfo = function(index) return 1, index == form, true, index == 1 and 5487 or 768 end
C_Spell = { GetSpellInfo = function(id) return { name = id == 5487 and "Bear Form" or "Cat Form" } end }
IsStealthed = function() return stealth end
GetActionTexture = function(slot) return slot == 281 and 12345 or nil end
InputDeviceIconSetManager = { GetActiveInputDeviceIconSet = function() return "Shapes" end }
local native = {}
GamepadCompanionAPI = { GetBarFrame = function(layer) native[layer] = native[layer] or {}; return native[layer] end }
assert(loadfile(root .. "/Model.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/SpreadOverview.lua"))("GamepadCompanion", ns)
local groups = ns.DiscoverFormStorage()
assert(#groups == 5 and groups[1].first == 265 and groups[5].first == 297)
invalid = 284
groups = ns.DiscoverFormStorage()
assert(#groups == 4 and groups[3].index == 4, "exclude incomplete groups without renumbering storage")
invalid = nil
ns.UpdateSpreadOverview({ enabled = true, spread = true, page = 1 })
local overview = frames[1]
assert(overview.shown and overview.point[4] < 0, "form overview must be on the left")
local formRows = {}
for _, f in ipairs(frames) do if f.buttons then formRows[#formRows + 1] = f end end
assert(#formRows == 5 and #formRows[1].buttons == 8)
assert(overview.strata == "LOW" and frames[2].strata == "LOW", "spellbook must cover overview and captions")
assert(formRows[1].buttons[1].background.atlas == "gamepad-actionbar-squareslot-generic-dpadleft-normal")
assert(formRows[1].buttons[5].background.atlas == "gamepad-actionbar-circleslot-ps-square-normal")
assert(formRows[1].buttons[5].mask.atlas == "CircleMask")
assert(formRows[3].label.text == "Bear Form  (active)")
assert(formRows[3].buttons[1].icon.texture == 12345)
assert(frames[2].text.text == "Bar 1 — Base (no trigger)")
assert(GamepadCompanionFormNames["druid-one"][281] == "Bear Form")
-- Cinematic may load after the overview. Register exactly once and expose
-- all five independent LOW-strata roots to its normal exemption resolver.
local registrations, scene = 0
FrameGambitAPI = { RegisterSceneProvider = function(definition)
    registrations, scene = registrations + 1, definition
    return true
end }
ns.UpdateSpreadOverview({ enabled = true, spread = true, page = 1 })
ns.UpdateSpreadOverview({ enabled = true, spread = true, page = 1 })
assert(registrations == 1 and scene.cinematicKeep and scene.role == "action_bar_editor")
local exempt = scene.resolve()
assert(#exempt == 5 and exempt[1] == overview and exempt[2] == frames[2])
assert(overview.strata == "LOW", "Cinematic integration must preserve spellbook stacking")
-- Explicit drops into inactive/active form slots, occupied-slot replacement,
-- rejected writes, and drag-out must preserve actions and never write in combat.
local storage, cursor, combat, rejected = {}, nil, false, false
InCombatLockdown = function() return combat end
GetActionInfo = function(slot) local a = storage[slot]; if a then return a.kind, a.id end end
GetCursorInfo = function() if cursor then return cursor.kind, cursor.id, nil, cursor.kind == "spell" and cursor.id end end
ClearCursor = function() cursor = nil end
C_Spell.PickupSpell = function(id) cursor = { kind = "spell", id = id } end
PickupItem = function(id) cursor = { kind = "item", id = id } end
PickupMacro = function(id) cursor = { kind = "macro", id = id } end
PickupAction = function(slot) assert(not combat); cursor, storage[slot] = storage[slot], nil end
PlaceAction = function(slot)
    assert(not combat)
    if storage[slot] or (rejected and cursor.id == 99) then return end
    storage[slot], cursor = cursor, nil
end
local target = formRows[1].buttons[1]
cursor = { kind = "spell", id = 99 }
target.scripts.OnReceiveDrag(target)
assert(storage[265].id == 99 and not cursor, "drop must write actual inactive form storage")
cursor = { kind = "macro", id = 121 }
target.scripts.OnClick(target)
assert(storage[265].kind == "macro" and cursor.id == 99, "replaced action remains on cursor")
cursor, rejected = { kind = "spell", id = 99 }, true
target.scripts.OnReceiveDrag(target)
assert(storage[265].id == 121 and cursor.id == 99, "failed replacement restores original and incoming cursor")
combat = true
target.scripts.OnReceiveDrag(target)
assert(storage[265].id == 121 and cursor.id == 99)
cursor = nil
target.scripts.OnDragStart(target)
assert(storage[265].id == 121 and not cursor)
combat = false
target.scripts.OnDragStart(target)
assert(not storage[265] and cursor.id == 121)
cursor = { kind = "flyout", id = 2 }
target.scripts.OnReceiveDrag(target)
assert(not storage[265] and cursor.kind == "flyout", "unsupported cursor must be preserved")
form, active = 2, 265
ns.UpdateSpreadOverview({ enabled = true, spread = true, page = 2 })
assert(formRows[1].label.text == "Cat Form  (active)" and formRows[3].label.text == "Bear Form")
stealth, active = true, 273
ns.UpdateSpreadOverview({ enabled = true, spread = true, page = 2 })
assert(formRows[2].label.text == "Cat Form (stealth)  (active)")
form = 0
ns.UpdateSpreadOverview({ enabled = true, spread = true, page = 2 })
assert(not formRows[2].label.text:find("active", 1, true), "do not mark stale stance storage as active")
ns.UpdateSpreadOverview({ enabled = true, spread = false })
assert(not overview.shown and not frames[2].shown)
assert(#scene.resolve() == 5, "hidden editor roots stay exempt from dormant blackout leases")
UnitGUID = function() return "druid-two" end
ns.UpdateSpreadOverview({ enabled = true, spread = true, page = 1 })
assert(formRows[3].label.text:find("not identified", 1, true), "form names must be character-specific")
assert(loadfile(root .. "/SpreadOverview.lua"))("GamepadCompanion", ns)
UnitGUID = function() return "druid-one" end
ns.UpdateSpreadOverview({ enabled = true, spread = false })
assert(GamepadCompanionFormNames["druid-one"][281] == "Bear Form", "observations must survive reload")
C_GamepadUI = nil
assert(#ns.DiscoverFormStorage() == 0, "unavailable API must not fabricate form slots")
print("PASS: five form groups, native artwork, panel layering, drag/drop, replacement rollback, combat blocking, captions, form/stealth identification, isolation, reload and close")
