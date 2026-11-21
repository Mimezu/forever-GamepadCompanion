-- Combo points a finisher spends (a cat's Ferocious Bite, Rip, Savage Roar; a rogue's too):
-- read as the spell is sent, before the server takes them. Scale() is the finisher's strength:
-- one point faint, five full.
local _, ns = ...
local CP = {}
ns.Combo = CP

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end

-- (the points now: on your target, else the player's power 4)
function CP.Now()
    local n
    if type(GetComboPoints) == "function" then
        local ok, v = pcall(GetComboPoints, "player", "target")
        if ok and not secret(v) then n = v end
    end
    if type(n) ~= "number" and type(UnitPower) == "function" then
        local ok, v = pcall(UnitPower, "player", 4)
        if ok and not secret(v) then n = v end
    end
    return type(n) == "number" and n or 0
end

local sent = { n = 0, at = -math.huge }       -- (as the last spell was sent)
local seen = { n = 0, at = -math.huge }       -- (the last points held before they went to 0)
CP.SENT_FRESH, CP.SEEN_FRESH = 1.5, 0.6
CP.MIN, CP.MAX = 0.35, 5

-- A spell sent: the points it may spend
function CP.Sent() sent.n, sent.at = CP.Now(), Now() end
-- The points changed: the last held before a spend
function CP.Changed()
    local n = CP.Now()
    if n > 0 then seen.n, seen.at = n, Now() end
end

-- The points the finisher just cast spent (0: none known)
function CP.Spent()
    local now = Now()
    if now - sent.at <= CP.SENT_FRESH and sent.n > 0 then return sent.n end
    local n = CP.Now()
    if n > 0 then return n end
    if now - seen.at <= CP.SEEN_FRESH then return seen.n end
    return 0
end

-- A finisher's strength by its points: 1 point CP.MIN .. 5 points 1 (none known: full)
function CP.Scale()
    local n = CP.Spent()
    if n <= 0 then return 1 end
    n = math.min(CP.MAX, n)
    return CP.MIN + (1 - CP.MIN) * (n - 1) / (CP.MAX - 1)
end

local frame = CreateFrame("Frame")
CP.frame = frame
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SENT", "player")
pcall(frame.RegisterUnitEvent, frame, "UNIT_POWER_UPDATE", "player")
frame:SetScript("OnEvent", function(_, event, unit, kind)
    if unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_SENT" then CP.Sent()
    elseif kind == "COMBO_POINTS" then CP.Changed() end
end)
