-- Open All in gamepad mode: Blizzard's stepper on a hidden button, driven by
-- ours. Skips COD and GM mail, stops at full bags (and says so), stops when the
-- mailbox closes, waits out combat, and never doubles a visible button's run.
-- lua5.1 tests/MailOpenAll.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs ---------------------------------------------------------------------
local frames, combat, free, messages, taken, openingAll = {}, false, 10, {}, {}, false
local function Frame(name)
    local f = { scripts = {}, events = {}, shown = true }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
CreateFrame = function(_, name) return Frame(name) end
InCombatLockdown = function() return combat end
UIErrorsFrame = { AddMessage = function(_, text) messages[#messages + 1] = text end }
C_Container = { CalculateTotalNumberOfFreeBagSlots = function() return free end }

-- The inbox: { money, cod, gm, items = n }
local inbox
local function Reset()
    inbox = {
        { money = 50 }, { items = 2 }, { cod = 100, items = 1 }, { gm = true, items = 1 }, { money = 5, items = 1 }, {},
    }
    taken = {}
end
local function TakeMoney(i) taken[#taken + 1] = "m" .. i; inbox[i].money = 0 end
local function TakeItem(i) taken[#taken + 1] = "i" .. i; inbox[i].items = inbox[i].items - 1; free = free - 1 end

-- Blizzard's Open All button (its stepper, as the client's MailFrame.lua: one
-- retrieval each 0.15 s; money first, then items; COD and GM mail skipped;
-- stops when the bags are full or nothing is left)
local DELAY = 0.15
local b = Frame("OpenAllMail")
local blizzardTicks = 0
function b:StopOpening() self.mailIndex, self.timeUntilNextRetrieval = 1, nil; openingAll = false end
function b:Next()
    if free == 0 then self:StopOpening(); return end
    while self.mailIndex <= #inbox do
        local m = inbox[self.mailIndex]
        if not (m.cod or m.gm) then
            if (m.money or 0) > 0 then TakeMoney(self.mailIndex); self.timeUntilNextRetrieval = DELAY; return end
            if (m.items or 0) > 0 then TakeItem(self.mailIndex); self.timeUntilNextRetrieval = DELAY; return end
        end
        self.mailIndex = self.mailIndex + 1
    end
    self:StopOpening()
end
function b:StartOpening() self.mailIndex = 1; openingAll = true; self:Next() end
b:SetScript("OnClick", function(self) self:StartOpening() end)
b:SetScript("OnUpdate", function(self, dt)
    blizzardTicks = blizzardTicks + 1
    if self.timeUntilNextRetrieval then
        self.timeUntilNextRetrieval = self.timeUntilNextRetrieval - dt
        if self.timeUntilNextRetrieval <= 0 then self.timeUntilNextRetrieval = nil; self:Next() end
    end
end)

local ns = {}
assert(loadfile(root .. "/MailOpenAll.lua"))("GamepadCompanion", ns)
local M = ns.MailOpenAll
local events, driver
for _, f in ipairs(frames) do
    if f.events.MAIL_SHOW then events = f end
    if f.scripts.OnUpdate and f ~= b then driver = f end
end
local function Fire(e) events.scripts.OnEvent(events, e) end
-- The game's frame loop: OnUpdate on shown frames only
local function Frames(n)
    for _ = 1, n do
        if b.shown then b.scripts.OnUpdate(b, 0.05) end
        if driver.shown then driver.scripts.OnUpdate(driver, 0.05) end
    end
end

-- Gamepad mode: the button hidden; □ calls its OnClick
Reset()
b:Hide()
Fire("MAIL_SHOW")
check(driver.shown, "mailbox open: driver on")
b.scripts.OnClick(b)
eq(table.concat(taken, ","), "m1", "□: the first item, as Blizzard's")
check(M.Stalled(), "stalled on a hidden button")
Frames(200)
eq(table.concat(taken, ","), "m1,i2,i2,m5,i5", "every mail opened, in order")
check(not (taken[6]), "COD and GM mail skipped")
check(not M.Stalled() and not openingAll, "done: stopped, opening-all off")
eq(#messages, 0, "bags not full: nothing said")
-- (pacing: one retrieval per 0.15 s, Blizzard's own timer)
Reset(); b.scripts.OnClick(b)
Frames(2)
eq(#taken, 1, "no second item before 0.15 s")
Frames(1)
eq(#taken, 2, "second item at 0.15 s")
Frames(200)

-- Full bags: stop, and a few words
Reset(); free = 2
b.scripts.OnClick(b)
Frames(200)
eq(table.concat(taken, ","), "m1,i2,i2", "stops when the bags fill")
check(not M.Stalled(), "stopped")
eq(messages[1], "Bags full", "says why")
messages = {}; free = 10

-- The mailbox closes mid-run: stopped, nothing more taken
Reset(); b.scripts.OnClick(b)
Frames(3)
local n = #taken
Fire("MAIL_CLOSED")
check(not driver.shown and not M.Stalled() and not openingAll, "closed: stopped")
Frames(50)
eq(#taken, n, "closed: nothing more taken")
Fire("MAIL_SHOW")

-- Combat: waits, then goes on
Reset(); b.scripts.OnClick(b)
combat = true
Frames(50)
eq(#taken, 1, "combat: nothing taken")
combat = false
Frames(200)
eq(#taken, 5, "after combat: the rest")

-- Mouse mode (the button shown): Blizzard's own OnUpdate runs, ours stands down
Reset(); b:Show()
b.scripts.OnClick(b)
blizzardTicks = 0
Frames(200)
eq(#taken, 5, "shown button: all opened once")
eq(blizzardTicks, 200, "Blizzard's own stepper ran every frame")
check(not M.IsDriving(), "ours never drove: nothing doubled")
-- (and a frame where both could run: ours does nothing)
Reset(); b.scripts.OnClick(b)
local before = #taken
check(not M.Step(1), "visible button: no step of ours")
eq(#taken, before, "nothing taken by ours")
Frames(200)
b:Hide()

-- Nothing opening: nothing driven
Reset()
check(not M.Step(1) and #taken == 0, "idle: nothing")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
