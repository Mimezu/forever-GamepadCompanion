-- Battery: the controller's charge, drawn as a small battery in Gamepad
-- Companion's minimap icon (Access.lua): click it to open the window, drag it
-- round the minimap. The game gives four steps (C_GamePad.GetPowerLevel:
-- critical, low, medium, high) and "wired"; the exact percentage is the
-- pad's own, only the outside helper could read it. With no reading, the
-- icon shows its usual art.
local _, ns = ...
local B = {}
ns.Battery = B

local SEGMENTS = 4
local W_SEG, H_SEG, GAP = 3, 6, 1

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

function B.Level()
    if not (C_GamePad and C_GamePad.GetPowerLevel) then return nil end
    local ok, level = pcall(C_GamePad.GetPowerLevel)
    if ok then return level end
end

-- The battery drawn into a button (the minimap icon); its own art (art)
-- shows instead when there is no reading
local gauge
function B.Attach(button, art)
    local g = CreateFrame("Frame", nil, button)
    local w = 4 + SEGMENTS * (W_SEG + GAP) - GAP
    g:SetSize(w + 2, H_SEG + 4)
    g:SetPoint("CENTER", 0, 1)
    g:SetFrameLevel((button:GetFrameLevel() or 0) + 1)
    local rim = g:CreateTexture(nil, "BACKGROUND")
    rim:SetPoint("TOPLEFT", 0, 0)
    rim:SetSize(w, H_SEG + 4)
    rim:SetColorTexture(0.85, 0.78, 0.6, 0.9)
    local inside = g:CreateTexture(nil, "BORDER")
    inside:SetPoint("TOPLEFT", 1, -1)
    inside:SetSize(w - 2, H_SEG + 2)
    inside:SetColorTexture(0.05, 0.05, 0.05, 1)
    local nub = g:CreateTexture(nil, "BACKGROUND")
    nub:SetPoint("LEFT", rim, "RIGHT", 0, 0)
    nub:SetSize(2, 4)
    nub:SetColorTexture(0.85, 0.78, 0.6, 0.9)
    g.segs = {}
    for i = 1, SEGMENTS do
        local s = g:CreateTexture(nil, "ARTWORK")
        s:SetPoint("TOPLEFT", 2 + (i - 1) * (W_SEG + GAP), -2)
        s:SetSize(W_SEG, H_SEG)
        g.segs[i] = s
    end
    g.art = art
    -- critical: a slow blink
    local acc = 0
    g:SetScript("OnUpdate", function(self, elapsed)
        if self.name ~= "Critical" then return end
        acc = acc + (elapsed or 0)
        self.segs[1]:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * math.cos(acc * math.pi * 1.5)))
    end)
    gauge = g
    B.Update()
    return g
end

-- The battery's name now ("High"...), for the icon's tooltip
function B.Name() return gauge and gauge.name end

function B.Update()
    if not gauge then return end
    local lit, color, name = B.Look(B.Level())
    gauge.name = name
    if not lit then
        gauge:Hide()
        if gauge.art then gauge.art:Show() end
        return
    end
    if gauge.art then gauge.art:Hide() end
    for i, s in ipairs(gauge.segs) do
        if i <= lit then s:SetColorTexture(color[1], color[2], color[3], 1)
        else s:SetColorTexture(1, 1, 1, 0.1) end
        s:SetAlpha(1)
    end
    gauge:Show()
end

local events = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "GAME_PAD_POWER_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED",
    "GAME_PAD_ACTIVE_CHANGED" }) do
    pcall(events.RegisterEvent, events, ev)
end
events:SetScript("OnEvent", function() B.Update() end)
-- (and now and then: not every client says when it changes)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(30, function() B.Update() end) end
