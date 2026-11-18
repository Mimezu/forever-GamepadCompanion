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
CreateFrame = function(kind, _, parent) return Frame(kind, parent) end
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

local current, stepped = "moments", 0
local window = Frame("Frame")
window.status = Frame("Frame")
local ns = {
    OptionsSkin = { TopPopup = function() return nil end, Text = function() return Frame("FontString") end, GREY = {} },
    Shell = { Current = function() return current end, PageFrames = function() return page, header end,
        Step = function(dir) stepped = stepped + dir end, Window = function() return window end },
}
assert(loadfile(root .. "/Focus.lua"))("GamepadCompanion", ns)
local F = ns.Focus

-- what can take the focus
local list = F.Controls()
local has = {}
for _, c in ipairs(list) do has[c] = true end
assert(has[plate1] and has[plate2] and has[row1.try] and has[seg], "visible buttons, the header's too")
assert(not has[hidden] and not has[secure], "hidden and secure frames: never focused")

-- the first press: the top left; the d-pad: the nearest that way
F.Attach(window)
window.scripts.OnShow(window)
assert(window.pad == true and window.propagate == true, "open, out of combat: the pad's buttons, passing on")
F.Press(window, "PADDDOWN")
assert(F.state.focus == seg and F.state.active, "first press: the top left (the header)")
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
-- the shoulders: the tabs; the triggers: the page's own
F.Press(window, "PADRSHOULDER")
assert(stepped == 1, "R1: the next tab")
local trig
F.SetTrigger("moments", function(dir) trig = dir end)
F.Press(window, "PADLTRIGGER")
assert(trig == -1, "L2: the page's own step")
-- something else passes on
assert(F.Press(window, "PADSOCIAL") == false, "other buttons: not ours")
-- combat: nothing taken, nothing handled
fighting = true
local before = F.state.focus
assert(F.Press(window, "PADDDOWN") == false and F.state.focus == before, "in combat: a press is the game's")
fighting = false
-- the window gone: the ring and legend too
window:Hide()
assert(window.pad == false and not F.state.active, "closed: the pad let go")
io.write("PASS: the pad's focus ring: nearest each way, A, X / Y, the tabs, never in combat" .. string.char(10))
