-- Battery: the controller's charge in a small gauge, top centre by default
-- (drag it anywhere; it hides with the interface). The game gives four steps
-- (C_GamePad.GetPowerLevel: critical, low, medium, high) and "wired"; the
-- exact percentage is the pad's own, only the outside helper could read it.
-- On by default; /gpc battery shows or hides it.
local _, ns = ...
local B = {}
ns.Battery = B

local SEGMENTS = 4
local W_SEG, H_SEG, GAP = 9, 10, 2

-- Enum.GamePadPowerLevel when the client has it, else its usual values
local function Levels()
    local E = type(Enum) == "table" and Enum.GamePadPowerLevel
    return {
        critical = E and E.Critical or 0, low = E and E.Low or 1, medium = E and E.Medium or 2,
        high = E and E.High or 3, wired = E and E.Wired or 4,
    }
end

-- What to draw for a power level: segments lit, colour, name
function B.Look(level)
    local L = Levels()
    if level == L.wired then return SEGMENTS, { 0.35, 0.8, 1 }, "Wired" end
    if level == L.high then return 4, { 0.35, 0.9, 0.35 }, "High" end
    if level == L.medium then return 3, { 0.85, 0.85, 0.3 }, "Medium" end
    if level == L.low then return 2, { 1, 0.55, 0.15 }, "Low" end
    if level == L.critical then return 1, { 1, 0.15, 0.1 }, "Critical" end
    return nil
end

local function Level()
    if not (C_GamePad and C_GamePad.GetPowerLevel) then return nil end
    local ok, level = pcall(C_GamePad.GetPowerLevel)
    if ok then return level end
end

local function Settings()
    local db = ns.Haptics and ns.Haptics.DB()
    if not db then return {} end
    if type(db.battery_bar) ~= "table" then db.battery_bar = { shown = true } end
    return db.battery_bar
end

local frame
local function Build()
    frame = CreateFrame("Frame", "GamepadCompanionBattery", UIParent)
    local w = 8 + SEGMENTS * (W_SEG + GAP) - GAP + 6
    frame:SetSize(w + 4, H_SEG + 8)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        Settings().pos = { point, rel, x, y }
    end)
    local pos = Settings().pos
    if type(pos) == "table" and pos[1] then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else frame:SetPoint("TOP", UIParent, "TOP", 0, -6) end
    -- the battery's body: a thin rim, a dark inside, and a nub on the right
    local rim = frame:CreateTexture(nil, "BACKGROUND")
    rim:SetPoint("TOPLEFT", 0, 0)
    rim:SetSize(w, H_SEG + 8)
    rim:SetColorTexture(0.85, 0.78, 0.6, 0.55)
    local inside = frame:CreateTexture(nil, "BORDER")
    inside:SetPoint("TOPLEFT", 1, -1)
    inside:SetSize(w - 2, H_SEG + 6)
    inside:SetColorTexture(0.05, 0.05, 0.05, 0.75)
    local nub = frame:CreateTexture(nil, "BACKGROUND")
    nub:SetPoint("LEFT", rim, "RIGHT", 0, 0)
    nub:SetSize(3, 7)
    nub:SetColorTexture(0.85, 0.78, 0.6, 0.55)
    frame.segs = {}
    for i = 1, SEGMENTS do
        local s = frame:CreateTexture(nil, "ARTWORK")
        s:SetPoint("TOPLEFT", 4 + (i - 1) * (W_SEG + GAP), -4)
        s:SetSize(W_SEG, H_SEG)
        frame.segs[i] = s
    end
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Controller: " .. (self.name or "?"), 1, 0.82, 0)
        GameTooltip:AddLine("Drag to move · /gpc battery", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- critical: a slow blink
    local acc = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        if self.name ~= "Critical" then return end
        acc = acc + (elapsed or 0)
        self.segs[1]:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * math.cos(acc * math.pi * 1.5)))
    end)
    frame:Hide()
end

function B.Update()
    if not frame then Build() end
    local lit, color, name = B.Look(Level())
    frame.name = name
    if not (Settings().shown and lit) then return frame:Hide() end
    for i, s in ipairs(frame.segs) do
        if i <= lit then s:SetColorTexture(color[1], color[2], color[3], 0.95)
        else s:SetColorTexture(1, 1, 1, 0.08) end
        s:SetAlpha(1)
    end
    frame:Show()
end

function B.Toggle()
    local s = Settings()
    s.shown = not s.shown
    B.Update()
    return s.shown
end

local events = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "GAME_PAD_POWER_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED",
    "GAME_PAD_ACTIVE_CHANGED" }) do
    pcall(events.RegisterEvent, events, ev)
end
events:SetScript("OnEvent", function() B.Update() end)
-- (and now and then: not every client says when it changes)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(30, function() if frame then B.Update() end end) end

if GamepadCompanionAPI then GamepadCompanionAPI.ToggleBattery = function() return B.Toggle() end end
