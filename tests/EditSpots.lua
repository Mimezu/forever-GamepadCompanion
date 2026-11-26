-- Edit Mode spots: each frame its own box; a click on boxes on top of each other brings the
-- next one under the cursor to the front (so any can be picked and dragged); right-click home;
-- arrows and the d-pad nudge the picked one; the passages each on a spot of their own.
-- lua5.1 tests/EditSpots.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Frames: a point (BOTTOMLEFT on UIParent, or all points on another), a size, a level, shown
local Frame = {}
Frame.__index = function(t, k)
    local v = rawget(Frame, k)
    if v ~= nil then return v end
    if type(k) == "string" and k:match("^Create") then return function() return setmetatable({ scripts = {} }, Frame) end end
    return function() end
end
function Frame:SetPoint(p, rel, rp, x, y) self.at = { p, rel, rp, x or 0, y or 0 } end
function Frame:ClearAllPoints() self.at = nil end
function Frame:SetAllPoints(other) self.over = other end
function Frame:SetSize(w, h) self.w, self.h = w, h end
local function Root(f) while rawget(f, "over") do f = rawget(f, "over") end return f end
function Frame:GetLeft() local at = rawget(Root(self), "at"); return at and at[4] end
function Frame:GetBottom() local at = rawget(Root(self), "at"); return at and at[5] end
function Frame:GetWidth() return rawget(Root(self), "w") end
function Frame:GetHeight() return rawget(Root(self), "h") end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(v) self.shown = v and true or false end
function Frame:IsShown() return rawget(self, "shown") == true end
function Frame:SetFrameLevel(n) self.level = n end
function Frame:GetFrameLevel() return rawget(self, "level") or 0 end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:SetText(t) self.text = t end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:GetEffectiveScale() return 1 end
function Frame:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
local function New() return setmetatable({ scripts = {} }, Frame) end
CreateFrame = function() return New() end
UIParent = New()
local cursor = { 0, 0 }
GetCursorPosition = function() return cursor[1], cursor[2] end
InCombatLockdown = function() return false end
IsShiftKeyDown = function() return false end

local ns = {}
assert(loadfile(root .. "/EditSpots.lua"))("GamepadCompanion", ns)
local S = ns.EditSpots

-- The pure part
local a, b, c = { rect = { 0, 0, 100, 50 }, level = 1 }, { rect = { 50, 0, 150, 50 }, level = 3 }, { rect = { 200, 0, 300, 50 }, level = 2 }
local under = S.Under({ a, b, c }, 75, 25)
eq(#under, 2, "two under the cursor")
check(under[1] == b and under[2] == a, "the front one first")
eq(#S.Under({ a, b, c }, 250, 25), 1, "one under it")
eq(#S.Under({ a, b, c }, 500, 25), 0, "none")
check(S.Next({ b, a }, b) == a, "the next one under")
check(S.Next({ b, a }, a) == b, "round again")
check(S.Next({ b, a }, c) == b, "not among them: the front one")

-- Three frames, two on top of each other
local saved = {}
local function Spot(name, x, y)
    local f = New()
    f:SetSize(200, 50)
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    f:Show()
    local home = { x, y }
    return S.Add({ name = name, label = name, frame = f,
        get = function() local s = saved[name]; if s then return s[1], s[2] end; return home[1], home[2] end,
        set = function(nx, ny) saved[name] = (nx and ny) and { nx, ny } or nil end })
end
local lure, meal, flight = Spot("Fishing", 36, 210), Spot("Meal", 60, 220), Spot("Flight", 36, 500)
S.EditMode(true)
check(lure.box:IsShown() and meal.box:IsShown() and flight.box:IsShown(), "Edit Mode: a box over each")
local function Click(spot, button)
    spot.box.scripts.OnMouseDown(spot.box, button or "LeftButton")
    spot.box.scripts.OnMouseUp(spot.box, button or "LeftButton")
end
-- the cursor where Fishing and Meal overlap
cursor = { 100, 240 }
local function Front()
    local u = {}
    for _, s in ipairs({ lure, meal, flight }) do u[#u + 1] = { rect = { s.frame:GetLeft(), s.frame:GetBottom(), s.frame:GetLeft() + 200, s.frame:GetBottom() + 50 }, level = s.box:GetFrameLevel(), s = s } end
    local list = S.Under(u, cursor[1], cursor[2])
    return list[1] and list[1].s
end
Click(meal)
eq(S.Selected(), "Meal", "a click picks the one in front")
check(Front() == meal, "it's in front")
meal.box.scripts.OnEnter(meal.box)
eq(meal.box.hint.text, "Click: the one under", "two under the cursor: the hint")
eq(meal.box.label.text, "Meal", "its name on it")
Click(meal)
eq(S.Selected(), "Fishing", "a click again: the one under comes forward, picked")
check(Front() == lure, "now in front")
Click(lure)
eq(S.Selected(), "Meal", "and round again")
-- dragged: it moves, saved, never cycles
local box = meal.box
box.scripts.OnMouseDown(box, "LeftButton")
box.scripts.OnDragStart(box)
check(rawget(meal.frame, "moving"), "dragged: the frame moves")
meal.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 400, 300)
box.scripts.OnDragStop(box)
box.scripts.OnMouseUp(box, "LeftButton")
eq(saved.Meal and (saved.Meal[1] .. "," .. saved.Meal[2]), "400,300", "its spot saved")
eq(S.Selected(), "Meal", "a drag never moves the pick on")
-- the arrows nudge the picked one (10, Shift 1)
S.Press(UIParent, "RIGHT")
eq(saved.Meal[1], 410, "right: 10 px")
IsShiftKeyDown = function() return true end
S.Press(UIParent, "PADDUP")
eq(saved.Meal[2], 301, "d-pad up with Shift: 1 px")
IsShiftKeyDown = function() return false end
eq(meal.frame:GetLeft() .. "," .. meal.frame:GetBottom(), "410,301", "the frame follows")
S.Press(UIParent, "A")
eq(saved.Meal[1], 410, "another key: nothing")
S.Press(UIParent, "ESCAPE")
eq(S.Selected(), nil, "Escape: let go")
-- right-click: home
Click(meal, "RightButton")
eq(saved.Meal, nil, "right-click: home")
eq(meal.frame:GetLeft() .. "," .. meal.frame:GetBottom(), "60,220", "back at its home")
-- a frame not shown: no box
flight.frame:Hide(); S.Refresh()
check(not flight.box:IsShown(), "a frame hidden: no box")
S.EditMode(false)
check(not (lure.box:IsShown() or meal.box:IsShown()), "Edit Mode over: no boxes")
eq(S.Selected(), nil, "and nothing picked")

-- The passages, each its own spot and sample in Edit Mode
local char = {}
ns.Shared = { CharDB = function() return char end }
GetTime = function() return 100 end
assert(loadfile(root .. "/Passage.lua"))("GamepadCompanion", ns)
local P = ns.Passage
local mx, my = P.Spot("meal", nil)
local fx, fy = P.Spot("flight", nil)
check(my ~= fy, "the meal's and the flight's homes apart")
check(my ~= 210 and fy ~= 210, "and apart from the lure float's")
P.EditMode(true)
S.EditMode(true)
local names = {}
for _, s in ipairs(S.spots) do if s.box:IsShown() then names[#names + 1] = s.label end end
table.sort(names)
eq(table.concat(names, ", "), "Fishing, Flight, Meal, Meal & fire, Pad stuck", "Edit Mode: a box for each passage too")
local mealSpot
for _, s in ipairs(S.spots) do if s.name == "passage-meal" then mealSpot = s end end
mealSpot.set(120, 400)
eq(char.passage.meal[1] .. "," .. char.passage.meal[2], "120,400", "the meal's spot saved for the character")
eq(select(2, P.Spot("flight", char.passage)), fy, "the flight's left where it was")
mealSpot.set(nil, nil)
eq(char.passage.meal, nil, "home again")
P.EditMode(false)
S.EditMode(false)

io.write(("EditSpots: %d checks, %d failures\n"):format(checks, failures))
if failures > 0 then os.exit(1) end
