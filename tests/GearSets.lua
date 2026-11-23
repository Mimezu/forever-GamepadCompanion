-- Equipment sets: Blizzard's gamepad setup leaves the set list 0 px wide and
-- hides Equip and Save; GearSets puts the list back on its XML anchors and
-- shows the buttons, on show and while shown; the mouse layout left alone.
-- lua5.1 tests/GearSets.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

local function Region()
    local f = { shown = true, scripts = {}, points = {}, cleared = 0 }
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetPoint(p, to, rp, x, y) self.points[#self.points + 1] = { p, to, rp, x, y } end
    function f:ClearAllPoints() self.points = {}; self.cleared = self.cleared + 1 end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) local p = self.points[i]; if p then return p[1], p[2], p[3], p[4], p[5] end end
    function f:SetHeight(h) self.h = h end
    function f:HookScript(k, fn)
        local old = self.scripts[k]
        self.scripts[k] = function(...) if old then old(...) end; fn(...) end
    end
    function f:RegisterEvent() end
    function f:UnregisterAllEvents() end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    return f
end

local combat, refreshed = false, 0
InCombatLockdown = function() return combat end
SmartNavigation = { RefreshButtonGroups = function() refreshed = refreshed + 1 end }
local loader
CreateFrame = function() loader = Region(); return loader end

local pane = Region()
pane.shown = false
pane.ScrollBox, pane.ScrollBar, pane.EquipSet, pane.SaveSet = Region(), Region(), Region(), Region()
-- the XML layout
pane.ScrollBox:SetPoint("TOPLEFT", pane, "TOPLEFT", 5, -8)
pane.ScrollBox:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -20, 105)
PaperDollFrame = { EquipmentManagerPane = pane }

local ns = {}
assert(loadfile(root .. "/GearSets.lua"))("GamepadCompanion", ns)
local G = ns.GearSets

-- Blizzard's InitializeGamepad (Camelot): Equip and Save hidden, the list on a frame that isn't there
local function BlizzardGamepadInit()
    pane.EquipSet:Hide(); pane.SaveSet:Hide()
    pane.ScrollBox:ClearAllPoints()
    pane.ScrollBox:SetPoint("TOPLEFT", nil, "TOPLEFT", 4, -5)
    pane.ScrollBox:SetHeight(352)
end

-- the mouse layout: left alone
eq(G.Broken(pane), false, "the XML layout: fine")
loader.scripts.OnEvent(loader, "PLAYER_LOGIN")
check(pane.scripts.OnShow ~= nil and pane.scripts.OnUpdate ~= nil, "hooked on the pane at login")
pane:Show(); pane.scripts.OnShow(pane)
eq(pane.ScrollBox.cleared, 0, "mouse mode: the list not touched")
eq(refreshed, 0, "nothing changed: the cursor not refreshed")

-- the gamepad UI on: the list comes back with its width, the buttons with it
BlizzardGamepadInit()
eq(G.Broken(pane), true, "one point and a height: no width")
pane.scripts.OnUpdate(pane, 0.016)
eq(G.Broken(pane), false, "two anchors again")
local p1, to1, _, x1, y1 = pane.ScrollBox:GetPoint(1)
eq(p1, "TOPLEFT", "top left first")
check(to1 == pane and x1 == 5 and y1 == -8, "top left on the pane, 5,-8")
local p2, to2, _, x2, y2 = pane.ScrollBox:GetPoint(2)
check(p2 == "BOTTOMRIGHT" and to2 == pane and x2 == -20 and y2 == 105, "bottom right on the pane, -20,105")
eq(pane.ScrollBar:GetNumPoints(), 2, "the scroll bar beside it")
eq(select(2, pane.ScrollBar:GetPoint(1)), pane.ScrollBox, "on the list")
eq(pane.EquipSet:IsShown(), true, "Equip shown")
eq(pane.SaveSet:IsShown(), true, "Save shown")
eq(refreshed, 1, "the cursor learns the buttons")
local cleared = pane.ScrollBox.cleared
pane.scripts.OnUpdate(pane, 0.016)
eq(pane.ScrollBox.cleared, cleared, "fixed once: each frame after only looks")
eq(refreshed, 1, "no refresh while nothing changes")

-- in combat: laid out all the same, the cursor left alone
combat = true
BlizzardGamepadInit()
pane.scripts.OnShow(pane)
eq(G.Broken(pane), false, "in combat: the list back too")
eq(refreshed, 1, "in combat: no call into SmartNavigation")
combat = false

-- a hidden pane: fixed, the cursor not asked
pane:Hide()
BlizzardGamepadInit()
eq(G.Fix(pane), true, "hidden: fixed")
eq(refreshed, 1, "hidden: no refresh")

-- no character window: nothing
PaperDollFrame = nil
eq(G.Fix(), false, "no pane: nothing")

io.write(("GearSets: %d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
