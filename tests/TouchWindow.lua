-- The Touchpad window, driven like a player: mode, grid, layers, tiles,
-- windows, a dropped spell, typed macro text, swipes and the options button.
-- lua5.1 tests/TouchWindow.lua <addon folder>
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

local ns = {}
for _, file in ipairs({ "TouchModel.lua", "Touchpad.lua", "OptionsSkin.lua", "TouchWindow.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local T, Touch = ns.TouchModel, ns.Touch
for _, f in ipairs(created) do
    if f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "GamepadCompanion") end
end
local click = _G.GamepadCompanionTouchClick

-- Helpers ------------------------------------------------------------------------
local function find(label)
    for _, f in ipairs(created) do
        local text = type(rawget(f, "label")) == "table" and f.label.text
        if text == label and f:IsVisible() then return f end
    end
end
local function press(label)
    local b = assert(find(label), "missing button: " .. label)
    check(b:IsEnabled(), "enabled: " .. label)
    b.scripts.OnClick(b)
    return b
end

-- Open ---------------------------------------------------------------------------
Touch.Command("")
local window, ui = ns.TouchWindow()
check(window and window:IsShown(), "/gpc touch opens the window")
eq(ui.status.text, "Off", "status: off")
eq(ui.cols.text, "3 columns", "default 3 columns")
eq(ui.rows.text, "2 rows", "default 2 rows")
check(find("Character") and find("Bags"), "default tiles show their windows")
eq(ui.binder.title.text, "Top left · Base", "top left selected")

-- On
ui.enable:SetChecked(true); ui.enable.scripts.OnClick(ui.enable)
eq(Touch.Settings().enabled, true, "check box turns zones on")
eq(GetBindingAction("PADBACK"), "CLICK", "touchpad bound")
eq(ui.status.text, "On", "status: on")

-- Grid
press("-")   -- first "-" is fewer columns
eq(ui.cols.text, "2 columns", "fewer columns")
eq(click:GetAttribute("gpc-cols"), 2, "secure grid follows")
ui.rowsPlus.scripts.OnClick(ui.rowsPlus)
eq(ui.rows.text, "3 rows", "more rows")
check(not ui.rowsPlus:IsEnabled(), "3 rows is the limit for the whole pad")
eq(ui.binder.title.text, "Top left · Base", "labels follow the grid")

-- Select a zone and give it a window
ui.tiles.r3c2.scripts.OnClick(ui.tiles.r3c2)
eq(ui.binder.title.text, "Bottom right · Base", "tile selects its zone")
press("World Map")
eq(Touch.Settings().actions.chord.base.r3c2, "window:map", "window button sets the zone")
eq(ui.tiles.r3c2.label.text, "World Map", "tile shows the window")
press("Bags")
check(ui.currentText.text:find("not found", 1, true), "a window this client has no button for is flagged")
press("World Map")

-- A layer: empty zones show Base's, dimmed
press("L2")
eq(ui.binder.title.text, "Bottom right · L2", "L2 layer selected")
eq(ui.currentText.text, "World Map  (Base)", "empty layer zone shows Base's")
check(not ui.clear:IsEnabled(), "nothing to clear on an inherited zone")

-- Drop a spell from the cursor onto a tile
cursor = 133
ui.tiles.r1c1.scripts.OnReceiveDrag(ui.tiles.r1c1)
eq(Touch.Settings().actions.chord.lt.r1c1, "spell:133", "dropped spell on L2 top left")
eq(cursor, nil, "cursor emptied")
eq(ui.tiles.r1c1.label.text, "Fireball", "tile shows the spell")
eq(click:GetAttribute("gpc-m-lt-r1c1"), "/cast Fireball", "secure macro set")

-- Typed macro on a swipe
ui.swipes["swipe-up"].scripts.OnClick(ui.swipes["swipe-up"])
eq(ui.binder.title.text, "Swipe up · L2", "swipe tile selected")
ui.macro:SetText("/sit")
press("Save macro")
eq(Touch.Settings().actions.chord.lt["swipe-up"], "text:/sit", "macro text saved on the swipe")
eq(click:GetAttribute("gpc-swipe"), 1, "swipes act on release")
press("Clear")
eq(Touch.Settings().actions.chord.lt["swipe-up"], "none", "clear")
eq(click:GetAttribute("gpc-swipe"), 0, "no swipes left")

-- Split mode
press("Right half")
eq(Touch.Settings().mode, "split", "right half mode")
check(ui.native:IsShown(), "Blizzard half shown")
eq(ui.cols.text, "1 column", "split grid 1 column")
eq(ui.modeNote.text, "Left half: Blizzard's focus", "split note")
press("Whole pad")

-- In combat: saved now, applied after
combat = true
press("Base")
ui.tiles.r1c1.scripts.OnClick(ui.tiles.r1c1)
press("Bags")
eq(Touch.Settings().actions.chord.base.r1c1, "window:bags", "combat: setting saved")
check(ui.status.text == "Applies after combat", "combat: status says it waits (" .. tostring(ui.status.text) .. ")")
combat = false

-- Touch + click: two slots per zone
press("Touch + click")
eq(Touch.Settings().input, "dual", "input dual")
check(ui.slots.touch:IsShown() and ui.slots.click:IsShown(), "slots shown")
check(ui.tapTime:IsShown(), "tap time shown")
eq(ui.tapTime.text, "350 ms", "tap time default")
ui.tapPlus.scripts.OnClick(ui.tapPlus)
eq(Touch.Settings().tapMs, 400, "longer tap")
eq(ui.tapTime.text, "400 ms", "tap time shown after change")
ui.tiles.r1c1.scripts.OnClick(ui.tiles.r1c1)
press("Touch")
press("Character")
eq(Touch.Settings().touchActions.base.r1c1, "window:character", "touch slot set")
eq(Touch.Settings().actions.chord.base.r1c1, "window:bags", "click slot unchanged")
eq(ui.tiles.r1c1.label.text, "Character", "tile shows the touch action")
check(ui.tiles.r1c1.small:IsShown(), "tile shows the click action small")
press("Click")
eq(ui.tiles.r1c1.label.text, "Bags", "click slot: tile shows the click action")
ui.swipes["swipe-up"].scripts.OnClick(ui.swipes["swipe-up"])
check(not ui.slots.touch:IsEnabled(), "swipes have no touch slot")
ui.tiles.r1c1.scripts.OnClick(ui.tiles.r1c1)
press("Right half")
check(not ui.inputs.dual:IsEnabled(), "touch + click: whole pad only")
check(not ui.slots.touch:IsShown(), "no slots in right half")
press("Whole pad")
press("Click")

-- Chat commands refresh the window
Touch.Command("grid 4 1")
eq(ui.cols.text, "4 columns", "chat grid refreshes the window")

-- Close; the options window's button opens it again
press("Close")
check(not window:IsShown(), "closed")
API.ToggleTouchpad()
check(window:IsShown(), "opens again")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
