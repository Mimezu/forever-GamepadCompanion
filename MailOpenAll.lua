-- The mailbox's Open All in gamepad mode. Blizzard hides the Open All button
-- in gamepad mode (InboxMixin:InitializeGamepad) and the pad's □ calls the
-- hidden button's OnClick: the first item is taken and a 0.15 s timer set, but
-- the stepper is the button's OnUpdate, which a hidden frame never runs. So it
-- stops after one item, stuck "opening".
--
-- This drives their own stepper while the button is hidden: their OnUpdate,
-- with their pacing, skips (COD, GM mail, failed items) and stop at full bags.
-- It stands down when the button is shown (their OnUpdate runs: nothing
-- doubles) or when nothing is opening. It waits out combat, stops when the
-- mailbox closes, and says why when the bags are full.
local _, ns = ...
local M = {}
ns.MailOpenAll = M

M.FULL = "Bags full"

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

local function Button() return _G.OpenAllMail end

local function FreeSlots()
    return C_Container and tonumber((Call(C_Container.CalculateTotalNumberOfFreeBagSlots))) or 1
end

-- True while Blizzard's Open All is opening on a hidden button (ours to drive)
function M.Stalled()
    local b = Button()
    if type(b) ~= "table" or b.timeUntilNextRetrieval == nil then return false end
    return not Call(b.IsVisible, b)
end

local driving = false
function M.IsDriving() return driving end

-- One frame of their stepper; returns true when it ran
function M.Step(dt)
    local b = Button()
    if not M.Stalled() then
        if driving then
            driving = false
            -- (their stepper stops quietly at full bags: a few words why)
            if FreeSlots() == 0 and UIErrorsFrame then
                Call(UIErrorsFrame.AddMessage, UIErrorsFrame, M.FULL, 1, 0.1, 0.1)
            end
        end
        return false
    end
    if InCombat() then return false end   -- (waits: resumes after combat)
    driving = true
    Call(b:GetScript("OnUpdate"), b, dt)
    return true
end

-- The mailbox closed: their OnHide never fires on a hidden button
function M.Stop()
    local b = Button()
    if M.Stalled() then Call(b.StopOpening, b) end
    driving = false
end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, dt) M.Step(dt) end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "MAIL_SHOW", "MAIL_CLOSED" }) do pcall(events.RegisterEvent, events, event) end
events:SetScript("OnEvent", function(_, event)
    if event == "MAIL_SHOW" then
        driver:Show()
    else
        M.Stop()
        driver:Hide()
    end
end)
