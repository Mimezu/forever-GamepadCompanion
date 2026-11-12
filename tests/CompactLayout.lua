-- Run from GamepadCompanion: luajit tests/CompactLayout.lua .
-- Compact/standard layouts, class-action buttons, v1 migration and the options window.
local root = arg[1] or "."
local ns, combat, writes, timers, hooks = {}, false, 0, {}, {}
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.00001, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function frame(parent, relative, x, y)
    local f = { parent = parent, scale = 1, alpha = 1, width = 40, height = 30,
        points = relative and { { "CENTER", relative, "CENTER", x or 0, y or 0 } } or {} }
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i or 1]) end
    function f:ClearAllPoints() assert(not combat, "geometry write in combat"); writes = writes + 1; self.points = {} end
    function f:SetPoint(...) assert(not combat, "geometry write in combat"); writes = writes + 1; self.points[#self.points + 1] = { ... } end
    function f:GetScale() return self.scale end
    function f:SetScale(v) assert(not combat, "geometry write in combat"); writes = writes + 1; self.scale = v end
    function f:GetHeight() return self.height end
    function f:GetParent() return self.parent end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(v) self.alpha = v end
    function f:IsShown() return self.shown ~= false end
    function f:Show() assert(not combat, "Show in combat"); self.shown = true end
    function f:Hide() assert(not combat, "Hide in combat"); self.shown = false end
    function f:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:SetScript(kind, callback) self[kind] = callback end
    function f:RegisterEvent() end
    return f
end
-- Parent-space displacement of a CENTER anchor, the way the client renders it.
local function offset(f)
    local p = f.points[1]
    return p[4] * f.scale, p[5] * f.scale
end
function CreateFrame() return frame() end
function InCombatLockdown() return combat end
function hooksecurefunc(target, method, hook)
    local original = target[method]
    target[method] = function(...) original(...); hook(...) end
    hooks[#hooks + 1] = method
end
GamepadMode = {}
local gamepadUI = true
InputUtil = { IsGamepadUIEnabled = function() return gamepadUI end }
GamepadSharedUtility = { InputBindingManager = { IsOnlyCoreBindingSetActive = function() return true end } }
SlashCmdList = {}
IsKeyDown = function() return false end
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end,
    NewTicker = function() return { Cancel = function() end } end }
UIParent = frame()
function UIParent:GetWidth() return 1920 end
function UIParent:GetHeight() return 1080 end
local page = frame(UIParent)
page.TopCenteredAnchor = frame(page, page, 0, 58)
page.BottomCenteredAnchor = frame(page, page, 0, -58)
page.actionBars = {}
for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar", "stanceBar" }) do
    page.actionBars[key] = frame(page.TopCenteredAnchor, page.TopCenteredAnchor)
end
local compact = false
function page:ShouldUseCompactLayout() return compact end
function page:GetActiveBar() return self.active end
function page:GetCurrentPage() return 1 end
page.active = page.actionBars.topBar
-- Native class-action button: re-anchors to its XML offset on every press.
local left = frame(page, page.BottomCenteredAnchor, -138, -50)
left.anchorInfo = { x = -138, y = -50 }
-- Its radial flyout (FlyoutButtonMixin): open while attached to this button.
function left:IsPopupOpen() return self.popup ~= nil and self.popup.attached == self end
function left:GetPopup() return self.popup end
function left:ApplyExtraButtonStylesForState(state)
    local push = state == "PUSHED" and -2 or 0
    if self:IsPopupOpen() then
        -- 70532: anchored to the open flyout's centre, no offset.
        self.points = { { "CENTER", self.popup, "CENTER", push, push } }
    else
        self.points = { { "CENTER", page.BottomCenteredAnchor, "CENTER", self.anchorInfo.x + push, self.anchorInfo.y + push } }
    end
end
function left:SetParent(parent) self.parent = parent end
page.LeftClassAction = left
page.LeftInputPrompt = frame(page, page.BottomCenteredAnchor, -138, -80)
GamepadMainActionBarFrame = { PageUnit = page }

-- A version 1 save: standard values are kept, compact starts neutral.
GamepadCompanionDB = { version = 1, enabled = true, bars = {
    base = { x = 0, y = -80, scale = 1, zoom = 1 }, lt = { x = 80, y = -32, scale = 1, zoom = 1 },
    rt = { x = -80, y = -32, scale = 1, zoom = 1 }, both = { x = 0, y = 12, scale = 1, zoom = 1 },
    stance = { x = -80, y = -32, scale = 1, zoom = 1 } } }
assert(loadfile(root .. "/Model.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Core.lua"))("GamepadCompanion", ns)
local api, bars = GamepadCompanionAPI, page.actionBars
ns.EventFrame.OnEvent(nil, "ADDON_LOADED", "GamepadCompanion")
for _, callback in ipairs(timers) do callback() end
local settings = api.GetSettings()
assert(settings.version == 2 and settings.bars.lt.x == 80 and settings.bars.stance.x == -80)
assert(settings.compact.bars.y == 0 and settings.compact.stance.x == 0 and settings.classPrompts == true)
assert(settings.bars.classLeft.x == 0, "old saves gain neutral class buttons")
print("PASS: version 1 save migrates; standard kept, compact and class buttons neutral")

-- Standard mode applies per-layer offsets.
ns.Refresh()
assert(api.GetState().mode == "standard" and api.GetMode() == "standard")
near(bars.leftBar.points[1][4], 80); near(bars.rightBar.points[1][4], -80)
-- Compact mode: every trigger bar shares one entry; standard offsets are released.
compact = true
ns.Refresh()
assert(api.GetState().compact and api.GetState().mode == "compact")
for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar", "stanceBar" }) do
    near(bars[key].points[1][4], 0, key .. " x"); near(bars[key].points[1][5], 0, key .. " y")
end
assert(api.SetBarOption("bars", "y", 24, "compact"))
assert(api.SetBarOption("bars", "scale", 1.2, "compact"))
for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar" }) do
    near(bars[key].points[1][5], 24, key .. " compact y"); near(bars[key].scale, 1.2, key .. " compact scale")
end
near(bars.stanceBar.points[1][5], 0, "stance has its own compact entry")
assert(not api.SetBarOption("lt", "x", 5, "compact"), "compact has no per-trigger entries")
assert(not api.SetBarOption("bars", "x", 5), "standard has no shared bar entry")
-- Editing standard while compact is live changes nothing on screen.
local before = writes
assert(api.SetBarOption("lt", "x", 90, "standard"))
assert(writes == before and api.GetSettings().bars.lt.x == 90)
compact = false
ns.Refresh()
near(bars.leftBar.points[1][4], 90); near(bars.leftBar.scale, 1)
compact = true
ns.Refresh()
near(bars.leftBar.points[1][4], 0); near(bars.leftBar.points[1][5], 24)
print("PASS: compact mode shares one bar layout, keeps standard intact, follows Blizzard's option live")

-- Class-action button: offsets are parent pixels and scale keeps its spot.
assert(api.SetBarOption("classLeft", "x", 40, "compact"))
assert(api.SetBarOption("classLeft", "y", 20, "compact"))
assert(api.SetBarOption("classLeft", "scale", 1.5, "compact"))
local x, y = offset(left)
near(x, -98, "class x"); near(y, -30, "class y"); near(left.scale, 1.5)
local px, py = offset(page.LeftInputPrompt)
near(px, -98, "prompt follows x"); near(py, -30 - 30 * 1.5, "prompt keeps scaled gap")
assert(api.GetBarFrame("classLeft") == left)
-- A press outside combat: Blizzard re-anchors, the hook restores immediately.
left:ApplyExtraButtonStylesForState("PUSHED")
x, y = offset(left)
near(x, -100, "pushed x keeps Blizzard's push offset"); near(y, -32)
left:ApplyExtraButtonStylesForState("NORMAL")
x, y = offset(left)
near(x, -98); near(y, -30)
-- In combat the hook writes nothing; Blizzard's spot stays until combat ends.
combat = true
before = writes
left:ApplyExtraButtonStylesForState("NORMAL")
ns.Refresh()
assert(writes == before)
near(left.points[1][4], -138)
combat = false
ns.EventFrame.OnEvent(nil, "PLAYER_REGEN_ENABLED")
ns.Refresh()
x, y = offset(left)
near(x, -98); near(y, -30)
-- The radial flyout reparents the button while open: the button keeps its screen spot.
-- Same effective scale as the page: the offset is untouched, and the SetParent hook applies it at once.
local flyout = frame(UIParent)
left:SetParent(flyout)
x, y = offset(left)
near(x, -98, "flyout parent, same scale x"); near(y, -30, "flyout parent, same scale y")
-- Blizzard restyles on release while the flyout is open: our offset comes back straight away.
left:ApplyExtraButtonStylesForState("NORMAL")
x, y = offset(left)
near(x, -98, "release inside the flyout keeps the offset"); near(y, -30)
-- A parent with a different scale: Blizzard's number is unchanged, ours is converted to keep its screen size.
flyout.scale = 0.5
left:ApplyExtraButtonStylesForState("NORMAL")
x, y = offset(left)
near(x, -138 + 40 * 2, "flyout at half scale: our offset keeps its screen size"); near(y, -50 + 20 * 2)
left:SetParent(page)
x, y = offset(left)
near(x, -98, "back on the page"); near(y, -30)
left:ApplyExtraButtonStylesForState("NORMAL")
x, y = offset(left)
near(x, -98, "and after Blizzard's restyle"); near(y, -30)
-- 70532: while the flyout is open, Blizzard anchors the button to the flyout's centre with no
-- offset (the flyout was centred on the button where we put it). Our offset is not added a
-- second time, our scale stays, and the prompt stays put.
flyout.scale = 1
left.popup, flyout.attached = flyout, left
left:SetParent(flyout)
x, y = offset(left)
near(x, -98, "attach: our placement is kept"); near(y, -30)
left:ApplyExtraButtonStylesForState("NORMAL")
assert(left.points[1][2] == flyout, "Blizzard's anchor to the open flyout is kept")
near(left.points[1][4], 0, "centred on the open flyout: no offset added"); near(left.points[1][5], 0)
near(left.scale, 1.5, "our scale stays while the flyout is open")
px, py = offset(page.LeftInputPrompt)
near(px, -98, "prompt untouched while the flyout is open"); near(py, -75)
left:ApplyExtraButtonStylesForState("PUSHED")
near(left.points[1][4], -2 / 1.5, "pushed on the flyout: only Blizzard's push, at screen size")
-- Closing: Blizzard reparents first, then detaches and restyles natively; our offset comes back.
left:SetParent(page)
near(left.points[1][4], -2 / 1.5, "reparented while still attached: nothing added")
flyout.attached = nil
left:ApplyExtraButtonStylesForState("NORMAL")
x, y = offset(left)
near(x, -98, "offset back after the flyout closed"); near(y, -30)
px, py = offset(page.LeftInputPrompt)
near(px, -98); near(py, -75)
-- No writes in combat, even with a flyout parent.
combat = true
before = writes
left:SetParent(flyout)
ns.Refresh()
assert(writes == before)
left:SetParent(page)
combat = false
ns.EventFrame.OnEvent(nil, "PLAYER_REGEN_ENABLED")
ns.Refresh()
x, y = offset(left)
near(x, -98); near(y, -30)
-- Prompt visibility.
assert(api.SetClassPrompts(false))
assert(page.LeftInputPrompt.alpha == 0)
assert(api.SetClassPrompts(true))
assert(page.LeftInputPrompt.alpha == 1)
api.SetClassPrompts(false)
api.SetEnabled(false)
assert(page.LeftInputPrompt.alpha == 1, "disable restores the prompt")
near(left.points[1][4], -138); near(left.scale, 1)
near(page.LeftInputPrompt.points[1][5], -80)
api.SetEnabled(true)
assert(page.LeftInputPrompt.alpha == 0)
api.SetClassPrompts(true)
print("PASS: class button offset/scale, prompt follow, press hook, combat deferral, flyout guard (70338 parent, 70532 anchor), prompt hide/restore")

-- Copy and reset between layouts.
assert(api.SetBarOption("base", "y", -80, "standard"))
assert(api.CopyLayout("standard", "compact"))
settings = api.GetSettings()
assert(settings.compact.bars.y == -80 and settings.compact.stance.x == -80 and settings.compact.classLeft.x == 0)
assert(api.ResetMode("compact"))
settings = api.GetSettings()
assert(settings.compact.bars.y == 0 and settings.bars.lt.x == 90, "reset one layout keeps the other")
assert(not api.CopyLayout("compact", "compact"))
assert(api.ResetBar("lt", "standard") and api.GetSettings().bars.lt.x == 0)
print("PASS: copy between layouts, per-layout reset")

-- Spread view in compact mode shows all four bars, then hands visibility back.
for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar" }) do
    bars[key].shown = bars[key] == page.active
end
compact = true
api.SetEditing(true)
assert(api.SetSpread(true))
for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar" }) do
    assert(bars[key].shown, key .. " revealed in compact spread")
    assert(bars[key].points[1][2] == UIParent, key .. " spread out")
end
-- Blizzard re-hides inactive bars when the active bar changes.
page.active = bars.leftBar
bars.topBar.shown, bars.rightBar.shown = false, false
ns.Refresh()
assert(bars.topBar.shown and bars.rightBar.shown, "re-hidden bars are revealed again")
-- No visibility writes in combat.
combat = true
bars.bottomBar.shown = false
ns.Refresh()
assert(not bars.bottomBar.shown)
combat = false
ns.Refresh()
assert(bars.bottomBar.shown)
api.SetSpread(false)
assert(bars.leftBar.shown, "the active bar stays shown")
for _, key in ipairs({ "topBar", "rightBar", "bottomBar" }) do
    assert(not bars[key].shown, key .. " hidden again after spread")
end
-- Standard mode never touches visibility.
compact = false
bars.rightBar.shown = false
api.SetSpread(true)
assert(not bars.rightBar.shown, "standard spread leaves Blizzard's visibility alone")
api.SetSpread(false)
api.SetEditing(false)
page.active = bars.topBar
compact = true
ns.Refresh()
print("PASS: compact spread reveals all four bars, re-reveals after native hides, defers in combat, restores on exit")

-- Options window: tabs per mode, class tabs per class, Blizzard settings button.
local buttons, opened = {}, nil
local methods = {}
local function uiFrame()
    return setmetatable({ scripts = {}, shown = true }, { __index = function(_, key)
        return methods[key] or function() end
    end })
end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:GetScript(key) return self.scripts[key] end
function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:SetText(text) self.text = text end
local texts = {}
function methods:CreateFontString() local f = uiFrame(); texts[#texts + 1] = f; return f end
-- Any text in the window (the status line) containing the fragment.
local function said(fragment)
    for _, f in ipairs(texts) do
        if type(rawget(f, "text")) == "string" and f.text:find(fragment, 1, true) then return true end
    end
    return false
end
function methods:CreateTexture() return uiFrame() end
function methods:IsEnabled() return true end
function methods:IsShown() return self.shown end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:GetWidth() return 560 end
function methods:GetHeight() return 560 end
function methods:SetAttribute(key, value)
    local attributes = rawget(self, "attributes") or {}
    self.attributes = attributes
    attributes[key] = value
end
function methods:SetEnabled(v) self.enabled = v end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide()
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
CreateFrame = function(kind, name)
    local f = uiFrame()
    if name then _G[name] = f end
    if kind == "Button" then buttons[#buttons + 1] = f end
    return f
end
UISpecialFrames = {}
UnitClass = function() return "Paladin", "PALADIN" end
GAMEPAD_LABEL, GAMEPAD_TOGGLE_COMPACT_ACTION_BAR = "Gamepad", "Compact Action Bar"
Settings = { GetCategory = function(name) assert(name == "Gamepad"); return { GetID = function() return 42 end } end }
C_SettingsUtil = { OpenSettingsPanel = function(id, element) opened = { id, element } end }
SettingsPanel = uiFrame()
C_Texture = { GetAtlasInfo = function() return {
    file = 123, width = 300, height = 50, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1,
} end }
assert(loadfile(root .. "/OptionsSkin.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Window.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Options.lua"))("GamepadCompanion", ns)
api.ToggleOptions()
local function find(label)
    for _, button in ipairs(buttons) do
        if type(rawget(button, "label")) == "table" and button.label.text == label and button.shown ~= false then return button end
    end
end
local function click(label)
    local button = assert(find(label), "Missing button: " .. label)
    button.scripts.OnClick(button)
end
local function visible(label)
    for _, button in ipairs(buttons) do
        if type(rawget(button, "label")) == "table" and button.label.text == label and button.shown then return true end
    end
end
-- Compact / Standard: the mode not in use runs Blizzard's /editmode from the
-- click (the setting lives in Edit Mode since 70338); the mode in use runs
-- nothing. The window then follows the setting the user changed there.
local function switch(label, value)
    local button = assert(find(label), "Missing button: " .. label)
    local attributes = rawget(button, "attributes")
    assert(attributes and attributes.type == "macro" and rawget(button.scripts, "OnClick") == nil)
    assert(attributes.macrotext == "/editmode", attributes.macrotext)
    compact = value == "1"
    ns.Refresh()
    button.scripts.PostClick(button)
    assert(rawget(button, "attributes").type == "", "the mode in use runs no macro")
end
assert(find("Compact  ·  in use") and find("Standard"), "mode buttons mark the live layout")
assert(visible("Action bars") and visible("Stance") and visible("Aura menu"))
assert(not visible("L2"), "compact has no per-trigger tabs")
switch("Standard", "0")
assert(find("Standard  ·  in use") and find("Compact"), "the clicked layout is now in use")
assert(visible("L2") and visible("L2 + R2") and not visible("Action bars") and visible("Aura menu"))
click("Aura menu")
assert(find("Reset Aura menu"))
combat = true
api.RefreshOptions()
assert(find("Compact").enabled == false, "no layout switch during combat")
combat = false
api.RefreshOptions()
assert(find("Compact").enabled == true)
switch("Compact", "1")
assert(find("Compact  ·  in use") and visible("Action bars"))
-- In the gamepad interface the Settings panel is not opened from addon code (it would
-- taint the gamepad window manager); the window says where to find the options.
local printed = {}
local realPrint = print
print = function(message) printed[#printed + 1] = tostring(message) end
click("Gamepad options")
assert(not opened and GamepadCompanionOptions:IsShown(), "gamepad UI: no settings call, window stays")
assert(said("Game menu > Options > Gamepad"), "gamepad UI: the note is shown in the window")
SlashCmdList.GAMEPADCOMPANION("gamepad")
assert(not opened and #printed == 1 and printed[1]:find("Game menu > Options > Gamepad", 1, true),
    "gamepad UI: /gpc gamepad prints the note instead")
print = realPrint
-- With the mouse and keyboard interface the panel opens as before.
gamepadUI = false
click("Gamepad options")
assert(opened and opened[1] == 42 and opened[2] == nil, "keyboard UI: opens Options > Gamepad (compact moved to Edit Mode)")
assert(not GamepadCompanionOptions:IsShown())
SettingsPanel.scripts.OnHide()
assert(GamepadCompanionOptions:IsShown(), "window returns after Blizzard settings close")
-- Edit Mode opens Blizzard's editor from the hardware click; no addon call.
local editMode = assert(find("Edit Mode"), "Missing button: Edit Mode")
assert(editMode.attributes.type == "macro" and editMode.attributes.macrotext == "/editmode")
assert(rawget(editMode.scripts, "OnClick") == nil)
combat = true
opened = nil
click("Gamepad options")
assert(not opened and GamepadCompanionOptions:IsShown(), "no settings call in combat")
combat = false
UnitClass = function() return "Mage", "MAGE" end
print("PASS: options show compact/standard tabs, class tabs, gamepad settings shortcut and Blizzard Edit Mode button")
