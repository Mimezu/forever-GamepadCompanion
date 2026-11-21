-- Beast forms (a druid's shapes, a shaman's Ghost Wolf): what changes with the body.
-- The shift itself is the form spell's own feel (Druid.lua, Shaman.lua); here: a cat's
-- claws and a bear's paws as the swings, no feet of yours in a beast form (a travel
-- form and Ghost Wolf ride: Riding), and a soft return to your own shape.
-- Timing needs nothing: a form is part of the model key (Timing.Model) and its swings
-- the kind "form" (Rumble's V.WeaponKind).
local _, ns = ...
local F = {}
ns.Forms = F

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return GetTime and GetTime() or 0 end

-- By GetShapeshiftFormID: swing (its swings' pattern), beast (four legs: no footsteps of
-- yours), rides (Riding plays while it runs)
F.FORMS = {
    [1] = { name = "cat", swing = "swClaw", beast = true },
    [5] = { name = "bear", swing = "swPaw", beast = true },
    [8] = { name = "direBear", swing = "swPaw", beast = true },
    [3] = { name = "travel", beast = true, rides = true },
    [4] = { name = "aquatic", beast = true },
    [16] = { name = "ghostWolf", beast = true, rides = true },
    [31] = { name = "moonkin" },
    [2] = { name = "tree" },
}

function F.Id()
    local fn = GetShapeshiftFormID
    if type(fn) ~= "function" then return nil end
    local ok, id = pcall(fn)
    if not ok or secret(id) then return nil end
    return id
end
function F.Current() local id = F.Id(); return id and F.FORMS[id] or nil end

-- (Rumble's V.SwingPattern asks first)
local V = ns.Rumble
if V then
    function V.FormSwing()
        local f = F.Current()
        return f and f.swing or nil
    end
end

-- Footsteps: beast (no steps of yours), rides (Riding)
function F.Beast()
    local f = F.Current()
    if not f then return false, false end
    return f.beast == true, f.rides == true
end

-- Back to your own shape (cancelled, or the form dropped): its feel, unless a form spell
-- just made the change (that spell's own feel says it)
F.SHIFT_QUIET = 0.5
local last, shiftCastAt = nil, -math.huge
function F.ShiftCast() shiftCastAt = Now() end
function F.Changed()
    local id = F.Id()
    if id == nil then return end
    local was = last
    last = id
    if was == nil or was == id or id ~= 0 or not F.FORMS[was] then return end
    local at = Now()
    -- (a shift from one form to another passes through your own shape: a moment later, still
    -- yours and no form spell cast: back to yourself)
    local function back()
        if last ~= 0 or math.abs(shiftCastAt - at) < F.SHIFT_QUIET then return end
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
        local R = ns.Rumble
        if R and R.FireAs then
            R.instantMove = "unshift"
            R.FireAs(nil, "instant")
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(F.SETTLE, back) else back() end
end
F.SETTLE = 0.25

local frame = CreateFrame("Frame")
F.frame = frame
pcall(frame.RegisterEvent, frame, "UPDATE_SHAPESHIFT_FORM")
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
-- (a form spell: its entry says shift = true)
local function IsShift(spellID)
    local R = ns.Rumble
    local e = R and R.ClassSpellOf and not secret(spellID) and spellID and R.ClassSpellOf(spellID)
    return e and e.shift == true
end
frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_ENTERING_WORLD" then last = F.Id()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and IsShift(spellID) then F.ShiftCast() end
    else F.Changed() end
end)
