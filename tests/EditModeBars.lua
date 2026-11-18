-- EditModeBars: Companion's bars in Blizzard Edit Mode. Boxes over each bar of the layout in
-- use, picking one (Blizzard's let go), dragging (offsets, the grid's snap), the dialog's
-- Scale / prompt / Reset, arrows, Exit.
-- lua5.1 tests/EditModeBars.lua <addon folder>
local root = arg[1] or "."

local methods = {}
local function frame(kind)
    return setmetatable({ kind = kind, scripts = {}, shown = false, points = {} }, { __index = function(_, key)
        return methods[key] or function() end
    end })
end
function methods:SetScript(k, f) self.scripts[k] = f end
function methods:GetScript(k) return self.scripts[k] end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetShown(v) self.shown = v and true or false end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetText(t) self.text = t end
function methods:SetChecked(v) self.checked = v end
function methods:GetChecked() return self.checked end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:GetLeft() return rawget(self, "left") or (self.points[1] and self.points[1][4]) end
function methods:GetBottom() return rawget(self, "bottom") or (self.points[1] and self.points[1][5]) end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:CreateFontString() return frame("FontString") end
function methods:CreateTexture() return frame("Texture") end
function methods:GetWidth() return rawget(self, "width") or 1600 end
function methods:GetHeight() return rawget(self, "height") or 900 end
function methods:GetEffectiveScale() return 1 end
function methods:IsMouseOver() return rawget(self, "over") == true end
function methods:SetFrameStrata(s) self.strata = s end
function methods:SetDontSavePosition(v) self.dontSave = v end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }

CreateFrame = function(kind, name, parent, template)
    if template == "EditModeSystemSelectionTemplate" then error("no Blizzard Edit Mode template") end
    if template == "DialogBorderTranslucentTemplate" then error("no such template here") end
    local f = frame(kind)
    f.parent, f.template = parent, template
    if name then _G[name] = f end
    return f
end
UIParent = frame("Frame")
UnitClass = function() return "Paladin", "PALADIN" end
local combat = false
InCombatLockdown = function() return combat end
local shift = false
IsShiftKeyDown = function() return shift end

-- Edit Mode as the client has it: callbacks, the manager, its grid
local callbacks = {}
EventRegistry = { RegisterCallback = function(_, event, fn, owner) callbacks[event] = function() fn(owner) end end }
local cleared = 0
EditModeManagerFrame = { snapEnabled = false, Grid = { gridSpacing = 20 },
    IsSnapEnabled = function(self) return self.snapEnabled end,
    ClearSelectedSystem = function() cleared = cleared + 1 end,
    SelectSystem = function() end }
local hooks = 0
hooksecurefunc = function() hooks = hooks + 1 end

-- Companion's API: settings per layout, bars as frames at known spots
local ns = {}
assert(loadfile(root .. "/Model.lua"))("GamepadCompanion", ns)
local M = ns.Model
local settings = M.Normalize({ enabled = true })
local state = { mode = "standard", available = true, nativeEnabled = true }
local hidden = {}
local page = { GetEffectiveScale = function() return 1.5 end }
local editing, subscriber
local bars = {
    base = { 600, 100, 400, 60 }, lt = { 200, 300, 300, 60 }, rt = { 1100, 300, 300, 60 },
    both = { 600, 200, 400, 60 }, stance = { 600, 40, 200, 30 }, classLeft = { 500, 100, 60, 60 },
}
GamepadCompanionAPI = {
    GetMode = function() return state.mode end,
    GetSettings = function() return M.Copy(settings) end,
    GetState = function() return M.Copy(state) end,
    SetEditing = function(v) editing = v end,
    Subscribe = function(owner, fn) subscriber = fn end,
    Unsubscribe = function() subscriber = nil end,
    SetBarOption = function(layer, key, value, mode) M.Layout(settings, mode)[layer][key] = value; return true end,
    SetClassPrompts = function(v) settings.classPrompts = v end,
    ResetBar = function(layer, mode) M.Layout(settings, mode)[layer] = M.Entry(); return true end,
    GetBarFrame = function(layer)
        local b = bars[layer]
        if not b then return nil end
        local scale = layer == "classLeft" and 1.5 or 1
        return { GetLeft = function() return b[1] / scale end, GetBottom = function() return b[2] / scale end,
            GetWidth = function() return b[3] / scale end, GetHeight = function() return b[4] / scale end,
            GetEffectiveScale = function() return scale end, GetParent = function() return page end,
            IsVisible = function() return not hidden[layer] end }
    end,
}
assert(loadfile(root .. "/EditModeBars.lua"))("GamepadCompanion", ns)
local EB = ns.EditModeBars

-- Enter: every bar of Standard (and the paladin's Aura menu) boxed over its bar
assert(callbacks["EditMode.Enter"] and callbacks["EditMode.Exit"], "Edit Mode callbacks")
callbacks["EditMode.Enter"]()
assert(EB.active and editing and subscriber, "on: bars shown, live")
local layers = EB.Layers("standard")
assert(#layers == 6 and layers[6] == "classLeft", "standard: 5 bars and the Aura menu")
assert(EB.Name("classLeft") == "Aura menu" and EB.Name("lt") == "L2", "names")
for _, layer in ipairs(layers) do
    local p = EB.proxies[layer]
    assert(p and p.shown and p.points[1][4] == bars[layer][1] and p.width == bars[layer][3], "boxed: " .. layer)
    assert(p:GetSystemName() == EB.Name(layer), "named for Blizzard's label")
end
assert(#EB.Layers("compact") == 3 and EB.Layers("compact")[1] == "bars", "compact: the stack, stance, the menu")

-- Pick: Blizzard's frames let go, the dialog shows its values
local p = EB.proxies.lt
p.selection.scripts.OnMouseDown()
assert(EB.Selected() == "lt" and cleared == 1, "picked; Blizzard's cleared")
local d = GamepadCompanionEditModeDialog
assert(d and d.shown and d.title.text == "L2" and d.scaleValue.text == "1.00" and not d.prompt.shown, "dialog")

-- Drag: 30 right, 20 down on screen = the offset; Snap rounds to the grid
p:OnDragStart()
p.left, p.bottom = 230, 280
p:OnDragStop()
assert(settings.bars.lt.x == 30 and settings.bars.lt.y == -20, "dragged: " .. settings.bars.lt.x .. " " .. settings.bars.lt.y)
p.left, p.bottom = nil, nil
EditModeManagerFrame.snapEnabled = true
p:OnDragStart()
p.left, p.bottom = 207, 293                      -- grid lines at 800 ± 20k: 207 -> 200, 293 -> 290
p:OnDragStop()
assert(settings.bars.lt.x == 30 and settings.bars.lt.y == -30, "snapped: " .. settings.bars.lt.x .. " " .. settings.bars.lt.y)
EditModeManagerFrame.snapEnabled = false

-- Dialog: scale steps, arrows nudge (Shift: 1), Reset
d.plus.scripts.OnClick()
assert(math.abs(settings.bars.lt.scale - 1.05) < 1e-9, "scale +")
shift = true
d.minus.scripts.OnClick()
assert(math.abs(settings.bars.lt.scale - 1.04) < 1e-9, "scale - fine")
d.scripts.OnKeyDown(d, "LEFT")
assert(settings.bars.lt.x == 29, "arrow, fine")
shift = false
d.scripts.OnGamePadButtonDown(d, "PADDUP")
assert(settings.bars.lt.y == -20, "d-pad up 10")
d.reset.scripts.OnClick()
assert(settings.bars.lt.x == 0 and settings.bars.lt.scale == 1, "reset")

-- The class button: its prompt
EB.proxies.classLeft.selection.scripts.OnMouseDown()
assert(d.prompt.shown and d.title.text == "Aura menu")
d.prompt.checked = false
d.prompt.scripts.OnClick(d.prompt)
assert(settings.classPrompts == false, "prompt off")

-- A click on our box keeps it; anywhere else (a Blizzard frame) lets it go
EB.proxies.classLeft.over = true
EB.events.scripts.OnEvent(EB.events, "GLOBAL_MOUSE_DOWN")
assert(EB.Selected() == "classLeft", "a click on ours keeps it")
EB.proxies.classLeft.over = false
EB.events.scripts.OnEvent(EB.events, "GLOBAL_MOUSE_DOWN")
assert(EB.Selected() == nil and not d.shown, "a click elsewhere lets it go")
assert(EB.proxies.lt.selection.label.text == "" and EB.proxies.lt.selection.edges[1], "our own box")

-- Combat: no drag
combat = true
EB.proxies.base:OnDragStart()
assert(not rawget(EB.proxies.base, "moving"), "no drag in combat")
combat = false

-- The dialog never covers the bar: above, below, beside, a corner; dragged: kept
local function overlaps(x, y, dw, dh, r)
    return x < r.left + r.width and x + dw > r.left and y < r.bottom + r.height and y + dh > r.bottom
end
local sw, sh = 1600, 900
for _, r in ipairs({ { left = 600, bottom = 20, width = 400, height = 60 },      -- low on screen: above
    { left = 600, bottom = 800, width = 400, height = 60 },                         -- high: below
    { left = 100, bottom = 50, width = 300, height = 820 },                         -- tall: beside, right
    { left = 1250, bottom = 50, width = 300, height = 820 },                        -- tall, right edge: left
    { left = 0, bottom = 0, width = 1600, height = 900 } }) do                      -- everything: a corner
    local x, y = EB.DialogSpot(r, 250, 150, sw, sh)
    assert(x >= 0 and y >= 0 and x + 250 <= sw and y + 150 <= sh, "on screen")
    if r.width < sw then assert(not overlaps(x, y, 250, 150, r), "never over the bar: " .. r.left .. "," .. r.bottom) end
end
local ax, ay = EB.DialogSpot({ left = 600, bottom = 20, width = 400, height = 60 }, 250, 150, sw, sh)
assert(ax == 675 and ay == 90, "above, centred: " .. ax .. "," .. ay)
-- every bar of the layout: the dialog clear of it
for _, layer in ipairs(EB.Layers("standard")) do
    EB.Select(layer)
    local pt = d.points[1]
    local r = EB.Rect(layer)
    assert(pt[2] == UIParent and not overlaps(pt[4], pt[5], d.width, d.height, r), "clear of " .. layer)
end
-- dragged by the user: that spot from now on; the close button lets go
d.left, d.bottom = 40, 600
d.scripts.OnDragStop(d)
EB.Select("base")
assert(d.points[1][4] == 40 and d.points[1][5] == 600, "the user's spot kept")
d.left, d.bottom = nil, nil
EB.dialogSpot = nil
d.close.scripts.OnClick()
assert(EB.Selected() == nil and not d.shown, "close lets go")

-- B1: our boxes over Blizzard's block selection (MEDIUM, level 1000) where they overlap
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5 }
local blizzard = { strata = "MEDIUM", level = 1000 }
for layer, q in pairs(EB.proxies) do
    assert(STRATA[q.strata] > STRATA[blizzard.strata], "over Blizzard's selection: " .. layer)
end
assert(STRATA[d.strata or "DIALOG"] >= STRATA.HIGH and d.dontSave == true, "dialog above, its spot not saved (B14)")

-- B4: a class button (page scale 1.5) dragged 30 px on screen moves 20 page units
EB.Select("classLeft")
local cl = EB.proxies.classLeft
local x0, y0 = settings.bars.classLeft.x, settings.bars.classLeft.y
cl:OnDragStart()
cl.left, cl.bottom = cl.points[1][4] + 30, cl.points[1][5]
cl:OnDragStop()
cl.left, cl.bottom = nil, nil
assert(settings.bars.classLeft.x == x0 + 20 and settings.bars.classLeft.y == y0,
    "class button in page units: " .. settings.bars.classLeft.x)

-- Reset, then Undo (5 s); after the 5 s, Reset again
EB.Select("rt")
EB.MoveBy("rt", 40, 0)
d.reset.scripts.OnClick()
assert(settings.bars.rt.x == 0 and d.reset.text == "Undo", "reset, Undo offered")
d.reset.scripts.OnClick()
assert(settings.bars.rt.x == 40 and d.reset.text == "Reset", "undone")
d.reset.scripts.OnClick()
timers[#timers]()
assert(d.reset.text == "Reset" and settings.bars.rt.x == 0, "Undo gone after its seconds")

-- B17: the dialog stays under the pointer while dragged
local before = d.points[1]
d.scripts.OnDragStart(d)
EB.Place()
assert(d.points[1] == before, "no re-anchor mid-drag")
d.left, d.bottom = 300, 400
d.scripts.OnDragStop(d)
d.left, d.bottom = nil, nil
EB.dialogSpot = nil

-- B16: a bar filling the middle: a corner clear of it; Escape lets the bar go first
local fx, fy = EB.DialogSpot({ left = 260, bottom = 160, width = 1080, height = 580 }, 250, 150, 1600, 900)
assert(not (fx < 1340 and fx + 250 > 260 and fy < 740 and fy + 150 > 160), "corner clear of the bar")
d.scripts.OnKeyDown(d, "ESCAPE")
assert(EB.Selected() == nil and not d.shown, "Escape: our pick first")

-- B6: a fight mid-drag: Exit stops the drag, Enter starts clean
EB.Select("lt")
EB.proxies.lt:OnDragStart()
EB.events.scripts.OnEvent(EB.events, "PLAYER_REGEN_DISABLED")
assert(not EB.active and not EB.dragging and not rawget(EB.proxies.lt, "moving"), "drag ended by the fight")
-- B5: the fight over, Edit Mode still open: back
EditModeManagerFrame.IsEditModeActive = function() return true end
EB.events.scripts.OnEvent(EB.events, "PLAYER_REGEN_ENABLED")
assert(EB.active, "back after the fight")

-- B7: a hidden bar has no box; the keyboard UI shows none
hidden.stance = true
EB.Place()
assert(not EB.proxies.stance.shown, "hidden bar: no box")
hidden.stance = nil
callbacks["EditMode.Exit"]()
state.nativeEnabled = false
callbacks["EditMode.Enter"]()
assert(not EB.active, "keyboard UI: nothing of ours")
state.nativeEnabled = true
callbacks["EditMode.Enter"]()

-- A fight ends it
EB.Select("base")
EB.events.scripts.OnEvent(EB.events, "PLAYER_REGEN_DISABLED")
assert(not EB.active and not editing, "a fight ends it")
callbacks["EditMode.Enter"]()

-- Exit: boxes and dialog gone, bars back to normal
callbacks["EditMode.Exit"]()
assert(not EB.active and not editing and not subscriber, "off")
for _, q in pairs(EB.proxies) do assert(not q.shown, "boxes hidden") end

-- B3: /gpc bars nudge, without Edit Mode: the dialog, a bar to pick, arrows; Close ends it
assert(EB.Fallback())
assert(d.shown and EB.Selected() == "base" and d.prev.shown and d.arrows[1].shown, "fallback dialog")
d.next.scripts.OnClick()
assert(EB.Selected() == "lt", "next bar")
local lx = settings.bars.lt.x
d.arrows[4].scripts.OnClick()
assert(settings.bars.lt.x == lx + 10, "arrow nudges")
d.close.scripts.OnClick()
assert(not d.shown and not EB.fallback and not subscriber, "closed")

-- My bar layout off: Edit Mode shows nothing of ours; nudge says why
settings.enabled = false
callbacks["EditMode.Enter"]()
assert(not EB.active, "off while My bar layout is off")
assert(select(2, EB.Fallback()) == "My bar layout is off")
assert(hooks == 0, "Edit Mode listened to, never hooked")
print("PASS: EditModeBars: listened to, never hooked; boxes over each bar, pick, drag (snap), dialog, arrows, a click elsewhere, a fight, exit")
