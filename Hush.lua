-- Hush and the Feel channel (docs/STACK.md).
--
-- Feel: a kind on the stack with one channel, a strength (× on every feel: the mixer, the plain
-- motors, WoW Helper's HD touch). Its reactions are rows like any other: Hush → 30 %, Resting →
-- 30 %, In an instance → 50 %, In raid → full; Otherwise: full.
-- Hush: one touch for quiet hours: feels at 30 % (the Feel row above), lights at rest and triggers
-- free (every other kind shows Otherwise while Hush holds), no sounds, no moment lights. The
-- footer's chip turns it on and off; it can also come on by itself while resting.
local _, ns = ...
local Hu = {}
ns.Hush = Hu

local St, H = ns.Stack, ns.Haptics
local floor, max, min = math.floor, math.max, math.min

local function DB()
    local db = H.DB()
    if type(db.hush) ~= "table" then db.hush = {} end
    return db.hush
end

local function Store()
    local db = H.DB()
    if type(db.feelStack) ~= "table" then db.feelStack = {} end
    return db.feelStack
end

---------------------------------------------------------------------------
-- The Feel channel
---------------------------------------------------------------------------
Hu.RECOMMENDED = {
    { id = "hush", condition = "hush", on = true, feel = 0.3 },
    { id = "rested", condition = "rested", on = false, feel = 0.3 },
    { id = "instance", condition = "instance", on = false, feel = 0.5 },
    { id = "raid", condition = "raid", on = false, feel = 1 },
}

local scale = 1
function ns.FeelScale() return scale end

Hu.kind = St.Kind("feel", {
    channels = { "feel" },
    recommended = Hu.RECOMMENDED,
    store = Store,
    value = function(row) return tonumber(row.feel) end,
    base = function() return 1 end,
    apply = function(r) scale = max(0, min(1, tonumber(r.feel.value) or 1)) end,
    hush = "rows",   -- (this kind is the mixer: its Hush row says how quiet)
})

---------------------------------------------------------------------------
-- Hush: the chip (on / off), or by itself while resting
---------------------------------------------------------------------------
function Hu.On() return St.Is("hush") end
function Hu.Manual() return DB().on == true end
function Hu.Auto() return DB().resting == true end

local function Resting() return IsResting and IsResting() == true or false end

function Hu.Apply()
    local on = Hu.Manual() or (Hu.Auto() and Resting())
    St.Set("hush", on)
    if Hu.chip then Hu.Paint() end
end

function Hu.Set(on)
    DB().on = on and true or nil
    Hu.Apply()
end
function Hu.Toggle() Hu.Set(not Hu.Manual()) end
function Hu.SetAuto(on)
    DB().resting = on and true or nil
    Hu.Apply()
end

---------------------------------------------------------------------------
-- The footer's chip (beside the WoW Helper one; the footer itself untouched)
---------------------------------------------------------------------------
function Hu.Paint()
    local c = Hu.chip
    local S = ns.OptionsSkin
    local on = Hu.On()
    local dot, text = on and S.YELLOW or S.DIM, on and S.GOLD or S.GREY
    c.dot:SetColorTexture(dot[1], dot[2], dot[3], 1)
    c.text:SetTextColor(text[1], text[2], text[3])
    if S then
        S.Tooltip(c, "Hush", (on and "On" or "Off") .. (Hu.Auto() and " · when resting too" or "") .. " · right-click: when resting")
    end
end

local function Chip(window)
    if Hu.chip or not (window and window.link) then return end
    local S = ns.OptionsSkin
    local c = CreateFrame("Button", nil, window)
    c:SetSize(64, 22)
    c:SetPoint("RIGHT", window.link, "LEFT", -6, 0)
    -- (No pad moves left of the chip; the status gives up the chip's width: L2-3)
    if window.noPad then
        window.noPad:ClearAllPoints()
        window.noPad:SetPoint("RIGHT", c, "LEFT", -8, 0)
    end
    if window.status and window.status.GetWidth then
        window.status:SetWidth(math.max(120, (window.status:GetWidth() or 0) - 70))
    end
    c.dot = c:CreateTexture(nil, "ARTWORK")
    c.dot:SetSize(7, 7)
    c.dot:SetPoint("LEFT", 4, 0)
    c.text = S.Text(c, "Hush", 0, 0, 50, 11, S.GREY)
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c.dot, "RIGHT", 5, 0)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            Hu.SetAuto(not Hu.Auto())
            if ns.Shell then ns.Shell.SetStatus(Hu.Auto() and "Hush when resting" or "Hush: only by hand", true) end
        else
            Hu.Toggle()
            if ns.Shell then ns.Shell.SetStatus(Hu.On() and "Hush" or "Hush off", true) end
        end
        if ns.RumblePage and ns.RumblePage.Refresh then ns.RumblePage.Refresh() end
    end)
    c:SetScript("OnEnter", S.ShowTooltip)
    c:SetScript("OnLeave", S.HideTooltip)
    Hu.chip = c
    Hu.Paint()
end
Hu.Chip = Chip

-- Hush with a word: on, off, resting (when resting too), or a toggle
function Hu.Say(on)
    if ns.Shell then ns.Shell.SetStatus(on and "Hush" or "Hush off", true) end
    if ns.RumblePage and ns.RumblePage.Refresh then ns.RumblePage.Refresh() end
end
function Hu.Command(arg)
    arg = (arg or ""):lower()
    if arg == "on" then Hu.Set(true)
    elseif arg == "off" then Hu.Set(false); Hu.SetAuto(false)
    elseif arg == "resting" then Hu.SetAuto(not Hu.Auto())
    else Hu.Toggle() end
    local words = (Hu.On() and "on" or "off") .. (Hu.Auto() and " · when resting" or "")
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Gamepad Companion|r Hush " .. words) end
    Hu.Say(Hu.On())
    return words
end

-- The key binding (Bindings.xml): Hush on / off
BINDING_NAME_GAMEPADCOMPANION_HUSH = "Hush"
function GamepadCompanion_Hush() Hu.Toggle(); Hu.Say(Hu.On()) end

local frame = CreateFrame("Frame")
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "PLAYER_UPDATE_RESTING")
frame:SetScript("OnEvent", function() Hu.Apply() end)

-- the chip: made beside the WoW Helper chip the first time the window shows (its OnShow
-- refreshes that chip; Window.lua itself is left as it is)
local Shell = ns.Shell
if Shell and Shell.RefreshLink then
    local refresh = Shell.RefreshLink
    Shell.RefreshLink = function(...)
        refresh(...)
        Chip(Shell.Window())
    end
end
