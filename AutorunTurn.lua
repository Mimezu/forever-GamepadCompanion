-- Autorun turns too. Options › Gamepad › Camera › Turn Player with Camera
-- (CVar GamePadTurnWithCamera: 0 when moving, 1 or in combat, 3 or casting,
-- 2 always). On "when moving" (0) the game doesn't count autorun as moving, so
-- the camera can't steer an autorun. While autorun is on we lay a temporary
-- value over it (SetTempCVar "2": during autorun the player always moves, so
-- "always" is "when moving"); the moment autorun stops it comes off
-- (RemoveTempCVar). A temp value is never saved: the user's choice stays
-- theirs, even through a crash. Any other choice: nothing is done.
--
-- Autorun: no API on this client says it's on. Blizzard's TOGGLEAUTORUN /
-- STARTAUTORUN / STOPAUTORUN bindings (keyboard and the pad's) call the global
-- ToggleAutoRun / StartAutoRun / StopAutoRun: secure post-hooks follow them.
-- Moving by key (forward, back) stops it, as do stopping (a mount's cast
-- stops you too), death, a loading screen, logout. (Not a dismount: autorun
-- goes on through it.)
local _, ns = ...
local Sh = ns.Shared
local A = {}
ns.AutorunTurn = A

A.CVAR = "GamePadTurnWithCamera"
A.MOVING = "0"     -- the choice autorun misses
A.ALWAYS = "2"     -- laid over it during autorun

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

local auto, raised, applying = false, false, false

function A.Enabled() return Sh.CharDB().autorunTurns ~= false end
function A.SetEnabled(on)
    Sh.CharDB().autorunTurns = on and true or false
    A.Update()
end
function A.IsAutorun() return auto end
function A.IsRaised() return raised end

local function UserValue() return tostring(Call(C_CVar and C_CVar.GetCVar, A.CVAR) or "") end

local function Raise()
    if raised then return end
    applying = true
    Call(C_CVar.SetTempCVar, A.CVAR, A.ALWAYS)
    applying = false
    raised = true
end

local function Lower()
    if not raised then return end
    applying = true
    Call(C_CVar.RemoveTempCVar, A.CVAR)
    applying = false
    raised = false
end

-- Raised only while autorun is on, the toggle is on and the user's choice is "when moving"
function A.Update()
    if not (C_CVar and C_CVar.SetTempCVar and C_CVar.RemoveTempCVar) then return end
    if auto and A.Enabled() then
        if not raised and UserValue() == A.MOVING then Raise() end
    else
        Lower()
    end
end

local function SetAuto(on)
    auto = on and true or false
    A.Update()
end

for name, fn in pairs({
    ToggleAutoRun = function() SetAuto(not auto) end,
    StartAutoRun = function() SetAuto(true) end,
    StopAutoRun = function() SetAuto(false) end,
    -- (a movement key stops autorun)
    MoveForwardStart = function() SetAuto(false) end,
    MoveBackwardStart = function() SetAuto(false) end,
}) do
    if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "CVAR_UPDATE", "PLAYER_STOPPED_MOVING", "PLAYER_DEAD", "PLAYER_ENTERING_WORLD",
    "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, name, value)
    if event == "CVAR_UPDATE" then
        if applying or type(name) ~= "string" or name:lower() ~= A.CVAR:lower() then return end
        -- The user changed the dropdown mid-autorun: theirs wins. Anything but
        -- "when moving" needs nothing from us.
        if raised then
            if tostring(value) ~= A.MOVING then Lower() end
        else
            A.Update()   -- (now "when moving" during an autorun: raise)
        end
        return
    end
    -- (stopped, dead, a loading screen, logout: autorun is over)
    SetAuto(false)
end)
