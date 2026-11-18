-- Run from GamepadCompanion: luajit tests/OptionsStyles.lua .
-- The Gamepad Companion window: side tabs, the Bars page, Help.
local root = arg[1] or "."
local ns = {}
local combat, now = false, 100
local created, registered, calls = {}, {}, {}
local methods = {}
local function new(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, shown = true, points = {},
        attributes = {}, enabled = true }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
    created[#created + 1] = f
    if name then _G[name] = f end
    return f
end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:GetScript(key) return self.scripts[key] end
function methods:SetTexture(t) self.texture = t end
function methods:SetAlpha(a) self.alpha = a end
function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:CreateFontString() return new("FontString", nil, self) end
function methods:CreateTexture() return new("Texture", nil, self) end
function methods:SetPoint(point, a, b, c, d)
    if type(a) == "number" then self.points[#self.points + 1] = { point, self.parent, point, a, b }
    else self.points[#self.points + 1] = { point, a, b, c, d } end
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
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
function methods:SetEnabled(v)
    local was = self.enabled; self.enabled = v and true or false
    if was ~= self.enabled and self.scripts[self.enabled and "OnEnable" or "OnDisable"] then
        self.scripts[self.enabled and "OnEnable" or "OnDisable"](self)
    end
end
function methods:SetChecked(v) self.checked = v and true or false end
function methods:GetChecked() return self.checked end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:HasFocus() return self.focus == true end
local focused
function methods:SetFocus()
    -- Like the client: focusing one box takes focus from the other.
    if focused and focused ~= self then focused:ClearFocus() end
    focused = self
    self.focus = true
    if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function methods:ClearFocus()
    local was = self.focus; self.focus = false
    if was and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function methods:SetScale(s) self.scale = s end
function methods:SetTextColor(r, g, b) self.color = { r, g, b } end
function CreateFrame(kind, name, parent) return new(kind, name, parent) end
UIParent = new("Frame", "UIParent")
function UIParent:GetWidth() return 1920 end
function UIParent:GetHeight() return 1080 end
UISpecialFrames = {}
GameTooltip = new("Frame", "GameTooltip")
InCombatLockdown = function() return combat end
GetTime = function() return now end
IsShiftKeyDown = function() return false end
UnitClass = function() return "Hunter", "HUNTER" end
C_Texture = { GetAtlasInfo = function(atlas)
    if atlas:find("arrow") then return nil end
    return { file = 1, width = 300, height = 50, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
end }
NineSliceUtil = { ApplyLayoutByName = function(frame, layout) frame.nineslice = layout end }
FrameGambitAPI = { RegisterCinematicWindow = function(frame) registered[frame] = true; return true end }
SlashCmdList = {}

-- Provider stub with real settings normalization.
assert(loadfile(root .. "/Model.lua"))("GamepadCompanion", ns)
local M = ns.Model
local settings = M.Normalize({ compact = { bars = { y = -50, scale = 0.9 } } })
local state = { available = true, enabled = true, nativeEnabled = true, gameplay = true, mode = "compact", compact = true }
local editing = false
GamepadCompanionAPI = {
    GetSettings = function() return M.Copy(settings) end,
    GetState = function() return M.Copy(state) end,
    GetCapabilities = function() return { layout = true, activeZoom = true } end,
    Subscribe = function() end, Unsubscribe = function() end,
    SetEditing = function(v) editing = v end,
    SetSpread = function(v) state.spread = v; return true end,
    SetBarOption = function(layer, key, value, mode)
        calls[#calls + 1] = { layer, key, value, mode }
        M.Layout(settings, mode)[layer][key] = value
        return true
    end,
    SetEnabled = function(v) settings.enabled = v; return true end,
    SetClassPrompts = function(v) settings.classPrompts = v; return true end,
    ResetBar = function() return true end, ResetMode = function(m) local n = M.Normalize(); if m == "compact" then settings.compact = n.compact else settings.bars = n.bars end; return true end, CopyLayout = function() return true end,
    SetOptionsStyle = function(v) settings.optionsStyle = v; return true end,
}
local api = GamepadCompanionAPI
assert(loadfile(root .. "/OptionsSkin.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Window.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Focus.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/EditModeBars.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Options.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/HelpPage.lua"))("GamepadCompanion", ns)

local function find(label, kind)
    for _, f in ipairs(created) do
        local text = type(rawget(f, "label")) == "table" and f.label.text
        if text == label and (not kind or f.kind == kind) and f:IsVisible() then return f end
    end
end
local function click(label)
    local button = assert(find(label), "Missing visible button: " .. label)
    assert(button.enabled, "button disabled: " .. label)
    if button.scripts.PreClick then button.scripts.PreClick(button) end
    button.scripts.OnClick(button)
    if button.scripts.PostClick then button.scripts.PostClick(button) end
end
local function visibleEdits()
    local list = {}
    for _, f in ipairs(created) do if f.kind == "EditBox" and f:IsVisible() then list[#list + 1] = f end end
    return list
end

local function statusText() return GamepadCompanionOptions.status.text or "" end

-- One window, pages on side tabs; Frame Gambit registration; bars shown while open
api.ToggleOptions()
local window = GamepadCompanionOptions
assert(window:IsShown() and editing, "opens and shows the bars")
assert(registered[window], "the window opts into Cinematic suite windows")
assert(window.chrome.kind == "legacy", "one Forever look")
local _, tabs = ns.ShellWindow()
assert(tabs.bars and tabs.tools and tabs.help, "Bars, Tools and Help tabs")
assert(ns.Shell.Current() == "bars", "first page without the Controller page loaded")
assert(tabs.bars.selected.shown and not tabs.tools.selected.shown, "the open page's tab is lit")
tabs.tools.scripts.OnClick(tabs.tools)
assert(ns.Shell.Current() == "tools" and find("Spread view: Off") and not find("Pet menu"), "Tools page")
-- Skin: v2 by default; Blizzard and back, at once
do
    local S = ns.OptionsSkin
    assert(S.Skin() == "v2", "v2 by default")
    local blizzard = find("Blizzard")
    for _, f in ipairs(created) do
        if type(rawget(f, "label")) == "table" and f.label.text == "Blizzard" and rawget(f, "segment") then blizzard = f end
    end
    blizzard.scripts.OnClick(blizzard)
    assert(S.Skin() == "blizzard" and GamepadCompanionHapticsDB.skin == "blizzard", "Blizzard")
    S.SetSkin("gilded")
    assert(S.Skin() == "gilded" and GamepadCompanionHapticsDB.skin == "gilded", "Gilded")
    S.SetSkin("v2")
    assert(S.Skin() == "v2" and GamepadCompanionHapticsDB.skin == nil, "back to v2")
    print("PASS: skin switch: v2 by default, Blizzard and back")
    -- Popups: a ×, Escape, the pad's B, a click elsewhere; other keys pass on
    local p = CreateFrame("Frame", "GamepadCompanionTestPopup", UIParent)
    S.Popup(p, "GamepadCompanionTestPopup", { outside = true })
    local over = false
    p.IsMouseOver = function() return over end
    local function closes(how, fn) p:Show(); fn(); assert(not p:IsShown(), how) end
    p:Show(); p.scripts.OnKeyDown(p, "W"); assert(p:IsShown(), "other keys leave it open")
    closes("Escape", function() p.scripts.OnKeyDown(p, "ESCAPE") end)
    closes("pad B", function() p.scripts.OnGamePadButtonDown(p, "PAD2") end)
    closes("the ×", function() p.closeButton.scripts.OnClick(p.closeButton) end)
    closes("a click elsewhere", function() p.scripts.OnEvent(p, "GLOBAL_MOUSE_DOWN") end)
    over = true
    p:Show(); p.scripts.OnEvent(p, "GLOBAL_MOUSE_DOWN"); assert(p:IsShown(), "a click inside keeps it")
    p:Hide()
    print("PASS: popups close: ×, Escape, pad B, a click elsewhere")
    -- a popup first opened in combat never holds the keyboard; after the fight, it takes Escape again
    local fighting = true
    local realLockdown = rawget(_G, "InCombatLockdown")
    InCombatLockdown = function() return fighting end
    local q = CreateFrame("Frame", "GamepadCompanionTestPopup2", UIParent)
    S.Popup(q, "GamepadCompanionTestPopup2")
    q:Show()
    assert(q.gpcKeys == false, "in combat: no keys taken")
    fighting = false
    q.scripts.OnEvent(q, "PLAYER_REGEN_ENABLED")
    assert(q.gpcKeys == true and q.gpcPassing == true, "after the fight: keys, passing on")
    fighting = true
    q.gpcPassing = false
    q.scripts.OnEvent(q, "PLAYER_REGEN_DISABLED")
    assert(q.gpcKeys == false, "a fight while open: keys that don't pass on are let go")
    q:Hide()
    InCombatLockdown = realLockdown
    print("PASS: popups never hold the keyboard in combat")
    -- Size: 90% by default, 100% saved, back
    assert(S.UIScale() == 0.9, "90% by default")
    S.SetUIScale(1)
    assert(S.UIScale() == 1 and GamepadCompanionHapticsDB.uiScale == 1, "100%")
    S.SetUIScale(0.9)
    assert(S.UIScale() == 0.9 and GamepadCompanionHapticsDB.uiScale == nil, "back to 90%")
    print("PASS: size: 90% by default, 100% and back")
    -- Tab glyphs: one set; the open page's bright, the rest dim
    assert(rawget(tabs.tools.icon, "gpcGlyph") and tabs.tools.icon.texture:find("Media\\tab%-tools"), "Tools' glyph")
    assert(tabs.tools.icon.alpha == 1 and tabs.bars.icon.alpha < 1, "the open page's glyph bright, the rest dim")
    print("PASS: tab glyphs: one set, open bright, rest dim")
    -- Joined choices: the highlight, hover and underline inset alike inside each cell
    local seg
    for _, f in ipairs(created) do if rawget(f, "segment") then seg = f; break end end
    local IN = S.SEGMENT_INSET
    local function inset(t)
        local p1, p2 = t.points[1], t.points[2]
        return p1[1] == "TOPLEFT" and p1[4] == IN and p1[5] == -IN and p2[1] == "BOTTOMRIGHT" and p2[4] == -IN and p2[5] == IN
    end
    assert(seg and inset(seg.selection) and inset(seg.hover), "highlight and hover inside the cell, same inset")
    local u1, u2 = seg.underline.points[1], seg.underline.points[2]
    assert(u1[1] == "BOTTOMLEFT" and u1[5] == IN and u2[1] == "BOTTOMRIGHT" and u2[5] == IN, "the underline at the cell's foot, inside")
    print("PASS: joined choices: the highlight inside its cell")
end
tabs.bars.scripts.OnClick(tabs.bars)
assert(find("Edit in Edit Mode") and not find("Action bars") and not find("Pet menu"), "Bars page: Edit Mode carries the bars")
print("PASS: one window, side tabs, Cinematic registration, bars shown while open")

-- My bar layout: the page's switch mirrors the setting
local enable
for _, f in ipairs(created) do if f.kind == "CheckButton" and f:IsVisible() then enable = f end end
assert(enable and enable.checked == true)
enable.checked = false
enable.scripts.OnClick(enable)
assert(settings.enabled == false and enable.checked == false)
enable.checked = true
enable.scripts.OnClick(enable)
assert(settings.enabled == true)
print("PASS: My bar layout toggles and mirrors the setting")

-- Bars: Edit Mode from the click; the layout in use and its Copy follow Blizzard's setting
local em = find("Edit in Edit Mode")
assert(em.attributes.type == "macro" and em.attributes.macrotext == "/editmode", "Edit Mode from the click")
local function shownText(fragment)
    for _, f in ipairs(created) do
        if f.kind == "FontString" and f.text and f.text:find(fragment, 1, true) and f:IsVisible() then return true end
    end
end
assert(shownText("Compact  ·  set in Edit Mode") and find("Copy from Standard"), "compact in use")
state.mode, state.compact = "standard", false
api.RefreshOptions()
assert(shownText("Standard  ·  set in Edit Mode") and find("Copy from Compact"), "standard in use")
state.mode, state.compact = "compact", true
api.RefreshOptions()
for _, gone in ipairs({ "Move up", "1", "50", "Reset Action bars" }) do assert(not find(gone), "gone: " .. gone) end
-- Reset layout: done, then Undo puts every bar back (B2)
settings.compact.bars.x, settings.compact.stance.y = 33, -12
find("Reset layout").scripts.OnClick(find("Reset layout"))
assert(settings.compact.bars.x == 0 and settings.compact.stance.y == 0, "reset")
local undo
for _, f in ipairs(created) do
    if f.kind == "Button" and type(rawget(f, "label")) == "table" and f.label.text == "Undo" and f:IsVisible() then undo = f end
end
assert(undo, "Undo offered")
undo.scripts.OnClick(undo)
assert(settings.compact.bars.x == 33 and settings.compact.stance.y == -12, "Undo: every bar back")
-- off: the page says what Edit Mode will show
settings.enabled = false
api.RefreshOptions()
assert(shownText("Off · Blizzard's bars"), "off: said")
settings.enabled = true
api.RefreshOptions()
assert(#visibleEdits() == 0, "no typed values: Edit Mode has them")
print("PASS: Bars: Edit Mode from the click, the layout in use, Copy and Reset layout; no preview, arrows or values")

-- Help is a page; its topics name the commands
api.ToggleHelp()
assert(window:IsShown() and ns.Shell.Current() == "help")
click("Commands")
local copy
for _, f in ipairs(created) do
    if f.kind == "FontString" and f.text and f.text:find("/gpc pad", 1, true) and f:IsVisible() then copy = f end
end
assert(copy, "commands topic")
-- every topic shows; Start here ticks from the live state; Go there opens the page
local HP = ns.HelpPage
for i = 1, #HP.TOPICS do HP.ShowTopic(i) end
HP.ShowTopic(1)
assert(HP.start:IsShown() and HP.start.tiles[1].state.text == "Not yet" and not HP.start.tiles[1].tick:IsShown(), "Start here: no pad yet")
for i, t in ipairs(HP.TOPICS) do if t.key == "bars" then HP.ShowTopic(i) end end
assert(HP.go:IsShown(), "Go there")
HP.go.scripts.OnClick(HP.go)
assert(ns.Shell.Current() == "bars", "Go there: the Bars page")
ns.Shell.Open("help")
-- the footer says what it knows: WoW Helper read, not read or off; No pad
local sw = ns.Shell.Window()
ns.Shell.RefreshLink()
assert(sw.link.text.text == "WoW Helper · off" and not sw.noPad:IsShown(), "off; a client that can't tell: no No pad")
C_GamePad = { GetActiveDeviceID = function() return -1 end }
ns.Shell.RefreshLink()
assert(sw.noPad:IsShown(), "No pad")
assert(ns.HelpPage.NeedsStart(), "/gpc: Start here while the pad isn't there")
C_GamePad = nil
ns.Shell.RefreshLink()
-- Fix it: four problems, their checks now, Go there; the tour on Start here
for i, t in ipairs(HP.TOPICS) do if t.fix then HP.ShowTopic(i) end end
assert(HP.fix:IsShown() and #HP.fixRows == 4, "Fix it: four rows")
assert(HP.fixRows[2].checks.text:find("Link on", 1, true) and HP.fixRows[2].checks.text:find("✗", 1, true), "WoW Helper not read: Link on unticked")
HP.ShowTopic(1)
assert(HP.tour:IsShown() and not HP.fix:IsShown(), "Start here: Play the tour")
-- Start here's 4th tile: Feel it, three moments
assert(#HP.start.tiles == 4 and HP.start.tiles[4].state.text == "Crit · Loot · Level up", "Feel it")
api.ToggleHelp()
assert(not window:IsShown() and not editing, "closing ends editing")
-- Saved styles still normalize (the setting stays for older saves)
assert(M.Normalize({ optionsStyle = "Z" }).optionsStyle == "A")
print("PASS: help page, close lifecycle")
