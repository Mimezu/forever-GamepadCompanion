-- Run from GamepadCompanion: lua tests/ShoulderLayout.lua .
local root = arg[1] or "."
local ns, combat, writes, timers = {}, false, 0, {}
local tickers, geometryReads = {}, 0
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.00001, (label or "value") .. ": " .. actual .. " ~= " .. expected)
end
local function frame(parent, relative, x, y, point)
    local f = { parent = parent, scale = 1, width = 40, height = 30,
        points = relative and { { point or "CENTER", relative, "CENTER", x or 0, y or 0 } } or {} }
    function f:GetNumPoints() geometryReads = geometryReads + 1; return #self.points end
    function f:GetPoint(i) return unpack(self.points[i or 1]) end
    function f:ClearAllPoints()
        assert(not combat, "geometry write in combat")
        writes = writes + 1
        self.points = {}
    end
    function f:SetPoint(...)
        assert(not combat, "geometry write in combat")
        if self.reject then error("rejected anchor") end
        writes = writes + 1
        self.points[#self.points + 1] = { ... }
    end
    function f:GetScale() return self.scale end
    function f:GetHeight() return self.height end
    function f:SetScale(value)
        assert(not combat, "geometry write in combat")
        writes = writes + 1
        self.scale = value
    end
    function f:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:Center()
        if #self.points == 0 then return 0, 0 end
        local p, scale = self.points[1], self:GetEffectiveScale()
        local rx, ry = p[2]:Center()
        if p[3] == "TOP" then ry = ry + p[2].height * p[2]:GetEffectiveScale() / 2 end
        local x, y = rx + p[4] * scale, ry + p[5] * scale
        if p[1] == "BOTTOM" then y = y + self.height * scale / 2 end
        if p[1] == "BOTTOMRIGHT" then x, y = x - self.width * scale / 2, y + self.height * scale / 2 end
        if p[1] == "BOTTOMLEFT" then x, y = x + self.width * scale / 2, y + self.height * scale / 2 end
        return x, y
    end
    function f:SetScript(kind, callback) self[kind] = callback end
    function f:RegisterEvent() end
    return f
end
function CreateFrame() return frame() end
function InCombatLockdown() return combat end
GamepadMode = {}
InputUtil = { IsGamepadUIEnabled = function() return true end }
GamepadSharedUtility = { InputBindingManager = { IsOnlyCoreBindingSetActive = function() return true end } }
SlashCmdList = {}
C_Timer = {
    After = function(_, callback) timers[#timers + 1] = callback end,
    NewTicker = function(interval, callback)
        local ticker = { interval = interval, callback = callback }
        function ticker:Cancel() self.cancelled = true end
        tickers[#tickers + 1] = ticker
        return ticker
    end,
}
local ui = frame()
UIParent = ui
function ui:GetWidth() return 1920 end
function ui:GetHeight() return 1080 end
ui.scale = 0.8
local page = frame(ui)
page.TopCenteredAnchor = frame(page, page, 0, 58)
page.TopCenteredAnchor.height = 50
page.PageTracker = frame(page, page.TopCenteredAnchor, 0, 20, "BOTTOM")
page.PageTracker.height = 40
page.PageTracker.points[1][3] = "TOP"
page.actionBars = {}
for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar", "friendlyTargetingBar", "hostileTargetingBar", "shortcutsBar" }) do
    page.actionBars[key] = frame(page.TopCenteredAnchor, page.TopCenteredAnchor)
end
for _, side in ipairs({ "Left", "Right" }) do
    local left = side == "Left"
    local background = frame(page, page.TopCenteredAnchor, left and -108 or 108, 42, left and "BOTTOMRIGHT" or "BOTTOMLEFT")
    page[side .. "ShoulderBackground"] = background
    page[side .. "ShoulderIcon"] = frame(page, background)
    page[side .. "ShoulderHighlight"] = frame(page, background)
end
function page:GetActiveBar() return self.active end
function page:GetCurrentPage() return 1 end
page.active = page.actionBars.topBar
GamepadMainActionBarFrame = { PageUnit = page }
assert(loadfile(root .. "/Model.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Core.lua"))("GamepadCompanion", ns)
local api, bars = GamepadCompanionAPI, page.actionBars
ns.EventFrame.OnEvent(nil, "ADDON_LOADED", "GamepadCompanion")
for _, callback in ipairs(timers) do callback() end
assert(writes == 0, "neutral settings must not touch native geometry")
local held = { PADLSHOULDER = true, PADRSHOULDER = false }
IsKeyDown = function(key) return held[key] end
ns.Refresh()
assert(api.GetState().leftShoulderHeld == true and api.GetState().rightShoulderHeld == false)
assert(api.GetState().bothShouldersHeld == false)
held.PADRSHOULDER = true
ns.Refresh()
assert(api.GetState().bothShouldersHeld == true)
held.PADLSHOULDER = nil
ns.Refresh()
assert(api.GetState().leftShoulderHeld == nil and api.GetState().bothShouldersHeld == nil)

local function sameCenter(a, b)
    local ax, ay = a:Center()
    local bx, by = b:Center()
    near(ax, bx, "center x"); near(ay, by, "center y")
end
local appliedConfig
local function checkGroup(multiplier)
    if not combat then appliedConfig = api.GetSettings().bars.base end
    local anchorX, anchorY = page.TopCenteredAnchor:Center()
    local stableScale = ui.scale * appliedConfig.scale
    local stableX, stableY = anchorX + appliedConfig.x * stableScale, anchorY + appliedConfig.y * stableScale
    local px, py = page.PageTracker:Center()
    local baseX, baseY = stableX, stableY
    near(px, baseX, "page tracker centered above Base")
    near(py - baseY, 65 * page.PageTracker:GetEffectiveScale(), "page tracker spacing")
    near(page.PageTracker:GetScale(), appliedConfig.scale, "page tracker scale")
    for _, key in ipairs({ "friendlyTargetingBar", "hostileTargetingBar", "shortcutsBar" }) do
        sameCenter(bars[key], bars.topBar)
        near(bars[key]:GetScale(), multiplier, key .. " scale")
    end
    for _, side in ipairs({ "Left", "Right" }) do
        local bg = page[side .. "ShoulderBackground"]
        local bx, by = bg:Center()
        local tx, ty = stableX, stableY
        local s = bg:GetEffectiveScale()
        near(bx - tx, (side == "Left" and -128 or 128) * s, "shoulder spacing x")
        near(by - ty, 57 * s, "shoulder spacing y")
        for _, part in ipairs({ "Background", "Icon", "Highlight" }) do
            local region = page[side .. "Shoulder" .. part]
            sameCenter(region, bg)
            near(region:GetScale(), appliedConfig.scale, "artwork scale")
        end
    end
end

api.SetBarOption("base", "y", -150)
api.SetBarOption("base", "x", 25)
api.SetBarOption("base", "scale", 1.4)
checkGroup(1.4)
local settled = writes
for _ = 1, 20 do ns.Refresh() end
assert(writes == settled, "steady state must not drift or rewrite geometry")
-- Active zoom was removed in 0.4.0 (Blizzard's Expand setting does it natively):
-- selecting a bar never changes Companion geometry.
assert(not api.SetBarOption("base", "zoom", 1.2), "zoom is no longer a setting")
assert(api.GetSettings().bars.base.zoom == nil)
for _, key in ipairs({ "friendlyTargetingBar", "hostileTargetingBar", "shortcutsBar" }) do
    page.active = bars[key]
    ns.Refresh()
    checkGroup(1.4)
    assert(api.GetState().nativeOverride and api.GetState().activeLayer == nil, "keep override state distinct")
end
page.active = bars.leftBar
ns.Refresh()
checkGroup(1.4)
api.SetBarOption("lt", "x", -70)
checkGroup(1.4)

-- Hidden shoulder bars are prepared before combat. Switching to one in combat
-- must already match Base; edits are deferred without any protected writes.
combat = true
page.active = bars.hostileTargetingBar
settled = writes
api.SetBarOption("base", "y", -200)
ns.Refresh()
assert(writes == settled and api.GetState().pendingLayout)
checkGroup(1.4)
combat = false
ns.EventFrame.OnEvent(nil, "PLAYER_REGEN_ENABLED")
ns.Refresh()
checkGroup(1.4)

-- Native layout/atlas repaints become the new baseline and restore exactly.
local bg = page.LeftShoulderBackground
bg.points = { { "BOTTOMRIGHT", page.TopCenteredAnchor, "CENTER", -120, 45 } }
bg.scale = 0.9
ns.Refresh()
near(bg:GetScale(), 0.9 * 1.4)
assert(bg.points[1][2] == page.TopCenteredAnchor)
api.ResetBar("base")
assert(page.PageTracker.points[1][2] == page.TopCenteredAnchor)
assert(page.PageTracker.points[1][3] == "TOP")
near(page.PageTracker.points[1][5], 20)
near(page.PageTracker:GetScale(), 1)
assert(bg.points[1][2] == page.TopCenteredAnchor)
near(bg.points[1][4], -120); near(bg:GetScale(), 0.9)
for _, key in ipairs({ "topBar", "friendlyTargetingBar", "hostileTargetingBar", "shortcutsBar" }) do
    near(bars[key]:GetScale(), 1)
    assert(bars[key].points[1][2] == page.TopCenteredAnchor)
    near(bars[key].points[1][5], 0)
end

-- A partial rejected write is retained for recovery, not retried every tick.
bars.friendlyTargetingBar.reject = true
api.SetBarOption("base", "y", -100)
assert(api.GetState().layoutError)
settled = writes
ns.Refresh()
assert(writes == settled)
bars.friendlyTargetingBar.reject = nil
api.SetEnabled(false)
assert(page.PageTracker.points[1][2] == page.TopCenteredAnchor)
near(page.PageTracker:GetScale(), 1)
assert(not api.GetState().layoutError and not api.GetState().pendingLayout)
assert(bars.friendlyTargetingBar.points[1][2] == page.TopCenteredAnchor)
near(bg:GetScale(), 0.9)
api.SetEnabled(true)
assert(bars.hostileTargetingBar.points[1][2] == bars.topBar)
api.ResetAll()
near(bars.leftBar.points[1][4], 0)
assert(page.RightShoulderBackground.points[1][2] == page.TopCenteredAnchor)
-- Blizzard's square/circle button groups have asymmetric visible bounds.
page.LeftShoulderBackground.points = { { "BOTTOMRIGHT", page.TopCenteredAnchor, "CENTER", -108, 42 } }
page.LeftShoulderBackground.scale = 1
local base = bars.topBar
function base:GetCenter()
    local x, y = self:Center()
    return x / self:GetEffectiveScale(), y / self:GetEffectiveScale()
end
base.actionButtons = {}
for index = 1, 8 do
    local button = {}
    function button:GetEffectiveScale() return base:GetEffectiveScale() end
    function button:GetLeft() return base:GetCenter() + (index <= 4 and -138 or 88) end
    function button:GetRight() return base:GetCenter() + (index <= 4 and -100 or 128) end
    base.actionButtons[index] = button
end
for _, uiScale in ipairs({ 0.65, 1 }) do
    ui.scale = uiScale
    for _, size in ipairs({ 0.75, 1.4 }) do
        api.SetBarOption("base", "scale", size)
        api.SetBarOption("base", "x", 35)
        ns.Refresh()
        local bx = base:Center()
        local expected = bx - 5 * base:GetEffectiveScale()
        local px = page.PageTracker:Center()
        local lx = page.LeftShoulderBackground:Center()
        local rx = page.RightShoulderBackground:Center()
        near(px, expected, "page numbers follow visible button center")
        near((lx + rx) / 2, expected, "shoulder pair follows visible button center")
        local fixed = {}
        for _, visual in ipairs({ page.PageTracker, page.LeftShoulderBackground, page.RightShoulderBackground }) do
            local x, y = visual:Center()
            fixed[#fixed + 1] = { visual, x, y, visual:GetScale() }
        end
        for _, key in ipairs({ "topBar", "leftBar", "hostileTargetingBar", "rightBar", "shortcutsBar" }) do
            page.active = bars[key]
            -- Native action styles can change their visible bounds by page.
            base.actionButtons[1].GetLeft = function() return base:GetCenter() - 180 end
            ns.Refresh()
            for _, saved in ipairs(fixed) do
                local x, y = saved[1]:Center()
                near(x, saved[2], "fixed visual screen x")
                near(y, saved[3], "fixed visual screen y")
                near(saved[1]:GetScale(), saved[4], "fixed visual size")
            end
        end
    end
end
api.ResetAll()
assert(page.PageTracker.points[1][2] == page.TopCenteredAnchor)
print("PASS: shoulder movement, scale, overrides, combat, repaint, reset, disable, and rejected-write recovery")
api.SetBarOption("base", "x", 45)
api.SetBarOption("lt", "y", -85)
local before = {}
for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar" }) do
    local f = bars[key]
    before[key] = { f:Center() }
end
api.SetEditing(true)
assert(api.GetState().editing)
assert(api.SetSpread(true))
local previousY
for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar" }) do
    local f = bars[key]
    assert(f.points[1][2] == UIParent)
    local _, y = f:Center()
    assert(not previousY or previousY - y >= 149)
    previousY = y
end
assert(api.GetSettings().bars.base.x == 45 and api.GetSettings().bars.lt.y == -85)
api.SetSpread(false)
assert(api.GetState().editing and not api.GetState().spread)
for key, position in pairs(before) do
    local x, y = bars[key]:Center()
    near(x, position[1]); near(y, position[2])
end
api.SetSpread(true)
combat = true
local count = writes
api.SetEditing(false)
assert(writes == count and api.GetState().pendingLayout)
assert(not api.GetState().editing and not api.GetState().spread)
combat = false
ns.Refresh()
for key, position in pairs(before) do
    local x, y = bars[key]:Center()
    near(x, position[1]); near(y, position[2])
end
print("PASS: temporary spread, unchanged saved settings, close and combat-deferred restoration")

-- The merged Edit Mode module must coexist with the real bar settings owner.
local coreEventFrame = ns.EventFrame
local editModeDatabase = { characters = { test = { [1] = { name = "[GP] Saved", kind = 1 } } } }
GamepadCompanionEditModeDB = editModeDatabase
assert(loadfile(root .. "/EditMode.lua"))("GamepadCompanion", ns)
assert(ns.EventFrame == coreEventFrame and ns.EditModeEventFrame ~= coreEventFrame)
assert(api.EditMode == ns.EditMode)
assert(api.SetBarOption("base", "x", 75))
assert(api.ResetBar("base"))
assert(api.ResetAll())
assert(api.SetEnabled(false))
assert(GamepadCompanionEditModeDB == editModeDatabase)
assert(GamepadCompanionEditModeDB.characters.test[1].name == "[GP] Saved")
local command
api.EditMode.Command = function(message) command = message end
SlashCmdList.GAMEPADCOMPANION("edit convert My Controller")
assert(command == "convert My Controller")
assert(GamepadCompanionDB.enabled == false)
SlashCmdList.GAMEPADCOMPANION("on")
assert(GamepadCompanionDB.enabled == true)
print("PASS: merged module preserves Core lifecycle, routes /gpc edit, and retains layout choices through bar save/reset/disable")

-- The shared stance frame changes actions with forms and anchors with routing.
local stance = frame(page.TopCenteredAnchor, page.TopCenteredAnchor)
bars.stanceBar = stance
assert(api.GetBarFrame("stance") == stance)
assert(api.GetSettings().bars.stance.scale == 1, "old saves gain neutral stance settings")
api.SetBarOption("stance", "x", 80)
api.SetBarOption("stance", "y", -60)
api.SetBarOption("stance", "scale", 1.3)
page.active = stance
ns.Refresh()
assert(api.GetState().activeSpecialBar == "stance" and api.GetState().nativeOverride)
assert(api.GetState().activeLayer == nil)
near(stance.scale, 1.3)
near(stance.points[1][4], 80); near(stance.points[1][5], -60)
local stable = writes
for _ = 1, 20 do ns.Refresh() end
assert(writes == stable, "stance layout must not drift")
local otherAnchor = frame(page, page, -150, 0)
stance.parent = otherAnchor
stance.points = { { "CENTER", otherAnchor, "CENTER", 0, 0 } }
ns.Refresh()
assert(stance.parent == otherAnchor and stance.points[1][2] == otherAnchor)
near(stance.points[1][4], 80); near(stance.points[1][5], -60)
page.active = bars.leftBar
ns.Refresh()
near(stance.scale, 1.3)
assert(api.GetState().activeSpecialBar == nil)
combat = true
stable = writes
api.SetBarOption("stance", "x", 120)
page.active = stance
ns.Refresh()
assert(writes == stable and api.GetState().pendingLayout, "stance edits must defer in combat")
combat = false
ns.Refresh()
near(stance.points[1][4], 120); near(stance.scale, 1.3)
assert(GamepadCompanionDB.bars.stance.x == 120)
api.SetEnabled(false)
near(stance.points[1][4], 0); near(stance.points[1][5], 0); near(stance.scale, 1)
assert(stance.points[1][2] == otherAnchor, "disable restores Blizzard's latest anchor")
api.SetEnabled(true)
near(stance.points[1][4], 120)
api.ResetBar("stance")
near(stance.points[1][4], 0); near(stance.scale, 1)
assert(api.GetSettings().bars.stance.x == 0)
print("PASS: stance layout, selection, native reparent, no drift, combat deferral, save, disable and reset")

local function activeTicker()
    local active
    for _, ticker in ipairs(tickers) do
        if not ticker.cancelled then assert(not active, 'only one state ticker'); active = ticker end
    end
    return active
end
api.ResetAll()
assert(not activeTicker(), 'default bars with no consumer must not poll')
local spreadReads = 0
ns.UpdateSpreadOverview = function() spreadReads = spreadReads + 1 end
api.Subscribe('polling-test', function() end)
assert(activeTicker().interval == .1, 'live consumer wakes input checks')
ns.Refresh()
local beforeReads, beforeSpread = geometryReads, spreadReads
for i = 1, 20 do activeTicker().callback() end
assert(geometryReads == beforeReads and spreadReads == beforeSpread, 'input-only polling skips geometry and form discovery')
api.SetBarOption('base', 'x', 25)
beforeReads, beforeSpread = geometryReads, spreadReads
for i = 1, 4 do activeTicker().callback() end
assert(geometryReads == beforeReads and spreadReads == beforeSpread, 'unchanged input does not rebuild layout')
activeTicker().callback()
assert(geometryReads > beforeReads and spreadReads == beforeSpread, 'half-second layout audit only')
local _, relative, relativePoint, _, y = bars.topBar:GetPoint(1)
bars.topBar.points = { { 'CENTER', relative, relativePoint, 100, y } }
for i = 1, 5 do activeTicker().callback() end
near(bars.topBar.points[1][4], 125, 'native repaint recovered by slow audit')
api.Unsubscribe('polling-test')
assert(activeTicker().interval == .5, 'layout without consumers uses slow recovery')
combat = true; ns.Refresh()
assert(not activeTicker(), 'no futile geometry polling in combat')
combat = false; ns.Refresh()
assert(activeTicker().interval == .5, 'postcombat refresh resumes recovery')
api.SetEnabled(false)
assert(not activeTicker(), 'disabled provider sleeps after restoring geometry')
api.ResetAll()
assert(not activeTicker(), 'reset removes final polling requirement')
print('PASS: demand-driven state timer, separate geometry audit, no closed-editor form scan, native repaint recovery and combat sleep')
