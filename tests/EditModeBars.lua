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
hooksecurefunc = function() error("Edit Mode is listened to, never hooked") end

-- Companion's API: settings per layout, bars as frames at known spots
local ns = {}
assert(loadfile(root .. "/Model.lua"))("GamepadCompanion", ns)
local M = ns.Model
local settings = M.Normalize({ enabled = true })
local state = { mode = "standard", available = true }
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
        return { GetLeft = function() return b[1] end, GetBottom = function() return b[2] end,
            GetWidth = function() return b[3] end, GetHeight = function() return b[4] end,
            GetEffectiveScale = function() return 1 end }
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

-- A fight ends it
EB.Select("base")
EB.events.scripts.OnEvent(EB.events, "PLAYER_REGEN_DISABLED")
assert(not EB.active and not editing, "a fight ends it")
callbacks["EditMode.Enter"]()

-- Exit: boxes and dialog gone, bars back to normal
callbacks["EditMode.Exit"]()
assert(not EB.active and not editing and not subscriber, "off")
for _, q in pairs(EB.proxies) do assert(not q.shown, "boxes hidden") end

-- My bar layout off: Edit Mode shows nothing of ours
settings.enabled = false
callbacks["EditMode.Enter"]()
assert(not EB.active, "off while My bar layout is off")
print("PASS: EditModeBars: listened to, never hooked; boxes over each bar, pick, drag (snap), dialog, arrows, a click elsewhere, a fight, exit")
