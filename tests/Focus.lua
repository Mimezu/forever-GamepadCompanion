-- The pad's focus ring: the nearest control each way, A clicks, X / Y the
-- row's Try / Default, the shoulders the tabs; nothing in combat.
-- lua5.1 tests/Focus.lua .
local root = arg[1] or "."

-- a small frame world: frames with a centre, children, scripts
local fighting = false
InCombatLockdown = function() return fighting end
local queued = {}
C_Timer = { After = function(_, fn) queued[#queued + 1] = fn end }
local methods = {}
methods.__index = function(t, k) return methods[k] end
local function Frame(kind, parent, x, y)
    local f = setmetatable({ kind = kind or "Frame", parent = parent, children = {}, shown = true, scripts = {},
        cx = x, cy = y, enabled = true, alpha = 1 }, methods)
    if parent then parent.children[#parent.children + 1] = f end
    return f
end
function methods:IsObjectType(t) return self.kind == t end
function methods:IsShown() return self.shown end
function methods:IsVisible() local f = self while f do if not f.shown then return false end f = f.parent end return true end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsMouseEnabled() return true end
function methods:IsEnabled() return self.enabled end
function methods:IsProtected() return self.protected == true end
function methods:GetAlpha() return self.alpha end
function methods:GetChildren() return unpack(self.children) end
function methods:GetCenter() return self.cx, self.cy end
function methods:GetEffectiveScale() return 1 end
function methods:GetParent() return self.parent end
function methods:Click() self.clicked = (self.clicked or 0) + 1; if self.scripts.OnClick then self.scripts.OnClick(self) end end
function methods:SetScript(k, fn) self.scripts[k] = fn end
function methods:HookScript(k, fn) local p = self.scripts[k]; self.scripts[k] = function(...) if p then p(...) end; fn(...) end end
function methods:SetPropagateKeyboardInput(v) self.propagate = v end
function methods:EnableGamePadButton(v) self.pad = v end
function methods:RegisterEvent() end
function methods:CreateTexture() return setmetatable({}, { __index = function() return function() end end }) end
function methods:SetFrameStrata() end
function methods:SetText(v) self.text = v end
function methods:SetShown(v) self.shown = v and true or false end
function methods:SetAlpha(v) self.alpha = v end
function methods:EnableMouse() end
function methods:ClearAllPoints() end
function methods:SetPoint() end
local lastFrame
CreateFrame = function(kind, _, parent) lastFrame = Frame(kind, parent); return lastFrame end
cursor = { 0, 0 }
GetCursorPosition = function() return cursor[1], cursor[2] end
UIParent = Frame("Frame")

-- the page: two rows (a plate and Try each), a header segment
local page, header = Frame("Frame"), Frame("Frame")
local row1 = Frame("Frame", page, 300, 400)
local plate1 = Frame("Button", row1, 300, 400)
row1.try = Frame("Button", row1, 500, 400)
row1.default = Frame("Button", row1, 560, 400)
local row2 = Frame("Frame", page, 300, 350)
local plate2 = Frame("Button", row2, 300, 350)
row2.gpcTry = function() row2.tried = true end
local seg = Frame("Button", header, 200, 480)
local hidden = Frame("Button", page, 300, 300); hidden.shown = false
local secure = Frame("Button", page, 320, 320); secure.protected = true
local action = Frame("Button", page, 340, 330)
action.attrs = { type = "macro", macrotext = "/editmode" }
function methods:GetAttribute(k) return self.attrs and self.attrs[k] end

local current, stepped = "moments", 0
local popup
local padThere, now = true, 100
GetTime = function() return now end
local tabTop, tabBottom = Frame("Button"), Frame("Button")
local window = Frame("Frame")
window.status = Frame("Frame")
local ns = {
    OptionsSkin = { TopPopup = function() return popup end, Text = function() return Frame("FontString") end, GREY = {} },
    Shell = { Current = function() return current end, PageFrames = function() return page, header end,
        Step = function(dir) stepped = stepped + dir end, Window = function() return window end,
        TabEnds = function() return tabTop, tabBottom end, PadPresent = function() return padThere end },
}
assert(loadfile(root .. "/Focus.lua"))("GamepadCompanion", ns)
local F = ns.Focus

-- what can take the focus
local list = F.Controls()
local has = {}
for _, c in ipairs(list) do has[c] = true end
assert(has[plate1] and has[plate2] and has[row1.try] and has[seg], "visible buttons, the header's too")
assert(not has[hidden] and not has[secure] and not has[action], "hidden, secure and action buttons (a type attribute): never focused")

-- open with a pad there: the ring, legend and tab glyphs at once, on the first control
F.Attach(window)
window.events = lastFrame.scripts
window.scripts.OnShow(window)
assert(window.pad == true and window.propagate == true, "open, out of combat: the pad's buttons, passing on")
for _, fn in ipairs(queued) do fn() end; queued = {}
assert(F.state.active and F.state.focus == seg, "open: the ring on the first control (the header)")
assert(window.padLegend.shown and window.padTabUp.shown and window.padTabDown.shown, "open: the legend and L1 / R1 glyphs")
-- buttons the window doesn't use: the game's (the stick clicks, Start)
for _, b in ipairs({ "PADLSTICK", "PADRSTICK", "PADFORWARD", "PADSOCIAL" }) do
    assert(F.Press(window, b) == false and window.propagate == true, b .. ": passes on")
end
assert(F.state.active, "the ring stays")
F.Press(window, "PADDDOWN")
assert(F.state.focus == plate1, "down: the first row's plate")
assert(window.propagate == false, "a handled press stops here")
for _, fn in ipairs(queued) do fn() end; queued = {}
assert(window.propagate == true, "the next presses pass again")
F.Press(window, "PADDRIGHT")
assert(F.state.focus == row1.try, "right: its Try")
F.Press(window, "PADDDOWN")
assert(F.state.focus == plate2, "down: the next row")
-- A clicks; X: the row's Try (a hook or its Try button); Y: Default
F.Press(window, "PAD1")
assert(plate2.clicked == 1, "A: a click")
F.Press(window, "PAD3")
assert(row2.tried, "X: the row's own Try")
F.Set(plate1)
F.Press(window, "PAD3")
F.Press(window, "PAD4")
assert(row1.try.clicked == 1 and row1.default.clicked == 1, "X / Y: its Try and Default buttons")
-- the shoulders: never taken; the tab steps on release, not with the touchpad (Focus UI chord)
assert(F.Press(window, "PADRSHOULDER") == false and stepped == 0, "R1 down: the game's")
F.Release("PADRSHOULDER")
assert(stepped == 1, "R1 released: the next tab")
assert(F.state.focus == nil, "the old page's focus let go")
for _, fn in ipairs(queued) do fn() end; queued = {}
assert(F.state.focus == seg, "the new page: its first control")
F.Press(window, "PADLSHOULDER"); F.Press(window, "PADBACK"); F.Release("PADLSHOULDER")
assert(stepped == 1, "L1 + touchpad: the Focus UI chord, no tab step")
-- the triggers: only where the page has a step
current = "setup"
assert(F.Press(window, "PADLTRIGGER") == false, "L2 on a page without a step: the game's")
current = "moments"
local trig
F.SetTrigger("moments", function(dir) trig = dir end)
assert(F.Press(window, "PADLTRIGGER") == true and trig == -1, "L2 on Moments: its groups")
-- the mouse moved: the ring sleeps; the next A only wakes it (no unseen click)
F.Press(window, "PADDDOWN")
assert(F.state.focus == seg, "down from nothing: the first control")
cursor = { 500, 500 }
assert(F.Press(window, "PAD1") == true and F.state.active and not seg.clicked, "the mouse moved: A wakes the ring, no click")
F.Press(window, "PAD1")
assert(seg.clicked == 1, "awake: A clicks")
-- a fight: the window lets go of the pad; after it, takes it again (not engaged)
F.Press(window, "PADDDOWN")
window.events.OnEvent(nil, "PLAYER_REGEN_DISABLED")
fighting = true
assert(window.pad == false and not F.state.active, "a fight: the pad let go")
assert(F.Press(window, "PADDDOWN") == false, "in combat: a press is the game's")
fighting = false
window.events.OnEvent(nil, "PLAYER_REGEN_ENABLED")
assert(window.pad == true and not F.state.active, "after the fight: the pad's buttons again, the ring not engaged")
-- the window gone: the ring and legend too
window:Hide()
assert(window.pad == false and not F.state.active, "closed: the pad let go")

-- opened by a mouse click: the ring asleep; L1 / R1 still step at once, and wake it
window.events.OnEvent(nil, "GLOBAL_MOUSE_DOWN")
now = now + 0.1
window:Show()
window.scripts.OnShow(window)
for _, fn in ipairs(queued) do fn() end; queued = {}
assert(not F.state.active and not window.padTabUp.shown, "opened by a click: the ring asleep")
local before = stepped
assert(F.Press(window, "PADLSHOULDER") == false, "L1 down: the game's")
F.Release("PADLSHOULDER")
assert(stepped == before - 1 and F.state.active, "L1 released, no d-pad first: the previous tab, the ring awake")
for _, fn in ipairs(queued) do fn() end; queued = {}
assert(F.state.focus == seg, "the new page: its first control")
-- no pad there: the window opens asleep too
window:Hide(); now = now + 5; padThere = false
window:Show(); window.scripts.OnShow(window)
assert(not F.state.active, "no pad: asleep")
padThere = true
assert(F.Press(window, "PADDDOWN") == true and F.state.active and F.state.focus == seg, "the first d-pad press: the first control")

-- the tab strip's L1 / R1 glyphs: shown while the pad is in use
assert(window.padTabUp and window.padTabUp.shown and window.padTabDown.shown, "pad in use: L1 / R1 by the tabs")
assert(window.padLegend.shown and window.status.alpha == 0, "pad in use: the legend over the status")
F.SetActive(false)
assert(not window.padTabUp.shown and not window.padTabDown.shown, "not in use: the glyphs hidden")
F.SetActive(true)

-- a value row (a stepper): one stop, left / right change it, its - / + out of the ring
local value = 5
local stepper = Frame("Frame", page, 300, 250)
local minus, plus = Frame("Button", stepper, 260, 250), Frame("Button", stepper, 380, 250)
stepper.gpcNudge = function(dir) value = value + dir end
has = {}
for _, c in ipairs(F.Controls()) do has[c] = true end
assert(has[stepper] and not has[minus] and not has[plus], "a value row: one stop, its buttons the mouse's")
F.Set(plate2)
F.Press(window, "PADDDOWN")
assert(F.state.focus == stepper, "down: the value row")
F.Press(window, "PADDRIGHT"); F.Press(window, "PADDRIGHT")
assert(value == 7 and F.state.focus == stepper, "right: up a step, the focus stays")
F.Press(window, "PADDLEFT")
assert(value == 6, "left: down a step")
assert(F.Press(window, "PAD1") == true and value == 6, "A on a value row: nothing, no error")
F.Press(window, "PADDUP")
assert(F.state.focus == plate2, "up: off the row")
stepper.enabled = false
has = {}
for _, c in ipairs(F.Controls()) do has[c] = true end
assert(not has[stepper], "a disabled value row: skipped")
stepper.enabled = nil

-- B: the popup first, else the window
popup = Frame("Frame")
local inPopup = Frame("Button", popup, 100, 100)
assert(F.Controls()[1] == inPopup and #F.Controls() == 1, "a popup open: only its controls")
F.Press(window, "PAD2")
assert(popup.shown == false and window.shown ~= false, "B: the popup closes, the window stays")
popup = nil
F.Press(window, "PAD2")
assert(window.shown == false and not F.state.active, "B again: the window closes")

-- combat: every pad button passes on to the game, nothing handled
window:Show(); window.scripts.OnShow(window)
F.Press(window, "PADDDOWN")
fighting = true
for _, b in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD1", "PAD2", "PAD3", "PAD4", "PADLTRIGGER", "PADLSTICK" }) do
    local before = window.propagate
    assert(F.Press(window, b) == false, b .. " in combat: the game's")
    assert(window.propagate == before, b .. " in combat: propagation untouched")
end
local steps = stepped
F.Press(window, "PADRSHOULDER"); F.Release("PADRSHOULDER")
assert(stepped == steps and window.shown ~= false, "in combat: no tab step, no close")
fighting = false

io.write("PASS: the pad's focus ring: the pad from the window's open, L1 / R1 at once, never action buttons, shoulders on release, never in combat" .. string.char(10))
