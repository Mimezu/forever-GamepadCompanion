-- Bag grid: in the gamepad UI the combined bag is a plain 10-column item grid
-- without the gamepad bag buttons; the line under the items is no cursor
-- stop; no wrap; the bag gets focus back after loot; nothing in combat;
-- /gpc nav records cursor moves. (Ported from Gear Glance 2.4.2's tests.)
-- lua5.1 tests/BagGrid.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs ---------------------------------------------------------------------
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush()
    while #timers > 0 do
        local run = timers; timers = {}
        for _, fn in ipairs(run) do fn() end
    end
end
local function Region(kind)
    local f = { kind = kind, shown = true, scripts = {}, points = {} }
    function f:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:HookScript(k, fn)
        local old = self.scripts[k]
        self.scripts[k] = function(...) if old then old(...) end; fn(...) end
    end
    function f:RegisterEvent() end
    function f:IsForbidden() return false end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:ClearAllPoints() self.points = {} end
    function f:GetParent() return self.parent end
    function f:GetWidth() return self.w or 37 end
    function f:GetHeight() return self.h or 37 end
    function f:SetHeight(v) self.h = v end
    function f:GetTop() return self.top end
    function f:GetBottom() return self.bottom end
    return f
end
local loginFrame
CreateFrame = function()
    local f = Region("Frame")
    loginFrame = loginFrame or f   -- the first frame BagGrid makes: its events
    return f
end
hooksecurefunc = function(target, name, fn)
    if type(target) == "string" then target, name, fn = _G, target, name end
    local original = target[name]
    target[name] = function(...) local r = { original(...) }; fn(...); return unpack(r) end
end
local combat = false
InCombatLockdown = function() return combat end
local navIgnored, wrapping = {}, {}
function SmartNavigation_MarkFrameIgnored(frame) navIgnored[frame] = true end
SmartNavigation = { SetWrapping = function(_, frame, on) wrapping[frame] = on end }
local printed = {}
print = function(text) printed[#printed + 1] = text end
GetTime = function() return 1 end
ITEM_SPACING_X, ITEM_SPACING_Y = 5, 5

local gamepad = false
InputUtil = { IsGamepadUIEnabled = function() return gamepad end }

-- The combined bag: 8 backpack items, a gamepad bag button in a holder, the
-- tracked-currency line under the items, the search box above them
local combined = Region("Frame")
combined.h = 300
combined.MoneyFrame = Region("Frame")
combined.UpdateFrameSize = function(self) self.h = 300 end
combined.UpdateItemLayout = function() end
combined.SmartNavPanelInfoAdded = function() end
combined.GetPaddingHeight = function() return 63 end
combined.CalculateExtraHeight = function() return 30 end
local items = {}
for slot = 1, 8 do
    local item = Region("Button")
    item.bottom = 20
    item.GetBagID = function() return 0 end
    item.GetID = function() return slot end
    items[slot] = item
end
combined.EnumerateValidItems = function()
    local i = 0
    return function() i = i + 1; if items[i] then return i, items[i] end end
end
local holder = Region("Frame"); holder.parent = combined
local bagButtons = { [0] = Region("Button") }
bagButtons[0].parent = holder
GamepadBagBar = { GetBagButton = function(_, id) return bagButtons[id] end }
local tracker = Region("Frame"); tracker.top, tracker.parent = 10, combined
local search = Region("EditBox"); search.top, search.parent = 400, combined
combined.GetChildren = function() return tracker, search end
ContainerFrameCombinedBags = combined
LootFrame = Region("Frame")
local focusCalls = {}
GamepadMode = { FrameControlsManager = {
    isUIFocused = false,
    FrameHidden = function() focusCalls[#focusCalls + 1] = "hidden" end,
    FrameShown = function(self, f) focusCalls[#focusCalls + 1] = "shown"; self.isUIFocused, self.focusedFrame = true, f end,
} }

GamepadCompanionCharDB = {}
local ns = {}
assert(loadfile(root .. "/Shared.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/BagGrid.lua"))("GamepadCompanion", ns)
local B = ns.BagGrid
check(B.Enabled(), "on by default")
loginFrame.scripts.OnEvent(loginFrame, "PLAYER_LOGIN")

-- Keyboard UI: untouched
combined:UpdateFrameSize(); combined:UpdateItemLayout()
check(bagButtons[0].shown and combined.h == 300, "keyboard UI: Blizzard's layout untouched")

-- Gamepad UI
gamepad = true
combined:UpdateFrameSize(); combined:UpdateItemLayout()
check(not bagButtons[0].shown, "bag buttons inside the bag hidden")
eq(combined.h, 130, "sized for the item rows alone (37 + 63 + 30)")
combined:UpdateItemLayout()
eq(combined.h, 130, "a second layout keeps that height")
check(navIgnored[tracker] and not navIgnored[search], "the line under the items is no cursor stop")
combined:SmartNavPanelInfoAdded()
check(wrapping[combined] == false, "no wrap from the last column to the first")
local function PointOf(slot) local p = items[slot].points; return p[#p] end
check(PointOf(8)[1] == "BOTTOMRIGHT" and PointOf(8)[2] == combined.MoneyFrame and PointOf(8)[4] == 0 and PointOf(8)[5] == 4,
    "slot 8 at the bottom right")
check(PointOf(1)[4] == -7 * 42 and PointOf(1)[5] == 4, "slot 1 seven cells to the left, same row")

-- 12 items: two rows, the 11th starts row 2
for slot = 9, 12 do
    local item = Region("Button"); item.bottom = 20
    item.GetBagID = function() return 0 end
    item.GetID = function() return slot end
    items[slot] = item
end
combined:UpdateItemLayout()
eq(combined.h, 37 * 2 + 5 + 63 + 30, "two rows")
check(PointOf(2)[4] == 0 and PointOf(2)[5] == 4 + 42, "slot 2 starts row 2 at the right")
for slot = 9, 12 do items[slot] = nil end

-- A collapsed bag's items come back
items[3]:Hide()
combined:UpdateItemLayout()
check(items[3].shown, "collapsed items shown again")

-- Off: Blizzard's gamepad layout
B.SetEnabled(false)
eq(GamepadCompanionCharDB.bagGrid, false, "off saved per character")
bagButtons[0]:Show()
combined:UpdateFrameSize(); combined:UpdateItemLayout()
check(bagButtons[0].shown and combined.h == 300, "off: Blizzard's gamepad layout")
wrapping[combined] = nil; combined:SmartNavPanelInfoAdded()
check(wrapping[combined] == nil, "off: wrapping left to Blizzard")
B.SetEnabled(true)
combined:UpdateFrameSize(); combined:UpdateItemLayout()
combined:UpdateFrameSize()
eq(combined.h, 130, "Blizzard sizing the frame again gets the item height back")

-- Loot window closed, focus went back to the character: the bag gets it back
local manager = GamepadMode.FrameControlsManager
manager.isUIFocused, manager.focusedFrame = false, combined
LootFrame:Show(); LootFrame:Hide(); flush()
check(focusCalls[1] == "hidden" and focusCalls[2] == "shown" and manager.focusedFrame == combined, "bag focused again after loot")
focusCalls = {}
LootFrame:Show(); LootFrame:Hide(); flush()
eq(#focusCalls, 0, "bag already focused: nothing")
manager.isUIFocused, manager.focusedFrame = true, Region("Frame")
LootFrame:Show(); LootFrame:Hide(); flush()
eq(#focusCalls, 0, "another window has focus: left alone")
manager.isUIFocused, manager.focusedFrame = false, nil
combined:Hide()
LootFrame:Show(); LootFrame:Hide(); flush()
eq(#focusCalls, 0, "bag closed: nothing")
combined:Show()

-- In combat nothing is moved, marked or called
local fight = Region("Frame"); fight.top, fight.parent = 5, combined
combined.GetChildren = function() return tracker, search, fight end
combat = true
combined:UpdateFrameSize(); combined:UpdateItemLayout()
wrapping[combined] = nil; combined:SmartNavPanelInfoAdded()
check(combined.h == 300 and not navIgnored[fight] and wrapping[combined] == nil, "combat: no layout, no marks, no wrap call")
LootFrame:Show(); LootFrame:Hide(); flush()
eq(#focusCalls, 0, "combat: no refocus")
combat = false

-- /gpc nav: the recorder logs a move off the grid, and the report says so
for slot = 1, 8 do
    local x = 1000 - (8 - slot) * 42   -- slot 8 rightmost
    items[slot].GetCenter = function() return x, 100 end
    items[slot].GetScaledRect = function() return x - 18, 82, 37, 37 end
end
combined.GetScaledRect = function() return 0, 0, 1200, 300 end
SmartNavigation.currentButton = items[1]
SmartNavigation.currentDirections = nil
B.Watch()
SmartNavigation.currentDirections = { { x = 1, y = 0 } }
SmartNavigation.currentButton = tracker   -- RIGHT from slot 1 landed on the currency line
B.Watch()
local log = GamepadCompanionCharDB.navLog
local last = log[#log]
check(last and last.kind == "move" and last.dir == "RIGHT", "a move is recorded")
check(last and last.ok == nil and last.grid and last.grid:find("slot 2"), "it says the grid's slot 2 was expected")
printed = {}
B.Report(false)
check(printed[1] and printed[1]:find("1 off grid"), "report counts it")
B.Report(true)
eq(#GamepadCompanionCharDB.navLog, 0, "clear")

io.write(("BagGrid: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
