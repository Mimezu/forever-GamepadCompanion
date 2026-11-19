-- Autorun turns too: GamePadTurnWithCamera "when moving" (0) gets a temporary
-- "always" (2) only while autorun is on; the user's value is never written,
-- and theirs wins when they change the dropdown mid-autorun.
-- lua5.1 tests/AutorunTurn.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs: a stored value and a temporary layer over it, as C_CVar
local stored, temp, sets, frame = "0", nil, 0, nil
local function Fire(event, ...) frame.scripts.OnEvent(frame, event, ...) end
C_CVar = {
    GetCVar = function(name) assert(name == "GamePadTurnWithCamera"); return temp or stored end,
    SetCVar = function(name, value) stored = tostring(value); sets = sets + 1; Fire("CVAR_UPDATE", name, tostring(value)) end,
    SetTempCVar = function(name, value) temp = tostring(value); Fire("CVAR_UPDATE", name, tostring(value)) end,
    RemoveTempCVar = function(name) temp = nil; Fire("CVAR_UPDATE", name, stored) end,
}
local hooks = {}
for _, n in ipairs({ "ToggleAutoRun", "StartAutoRun", "StopAutoRun", "MoveForwardStart", "MoveBackwardStart" }) do
    _G[n] = function() end
end
hooksecurefunc = function(name, fn) hooks[name] = fn end
local function Press(name) _G[name](); if hooks[name] then hooks[name]() end end
CreateFrame = function()
    frame = { scripts = {}, events = {} }
    function frame:RegisterEvent(e) self.events[e] = true end
    function frame:SetScript(k, fn) self.scripts[k] = fn end
    return frame
end
GamepadCompanionCharDB = {}
local ns = {}
assert(loadfile(root .. "/Shared.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/AutorunTurn.lua"))("GamepadCompanion", ns)
local A = ns.AutorunTurn
local function Effective() return temp or stored end

eq(A.CVAR, "GamePadTurnWithCamera", "the dropdown's CVar")
check(A.Enabled(), "on by default")
check(frame.events.CVAR_UPDATE and frame.events.PLAYER_STOPPED_MOVING, "follows the setting and stops")

-- When moving: autorun raises it, stopping restores it
Press("ToggleAutoRun")
check(A.IsAutorun() and A.IsRaised(), "autorun on: raised")
eq(Effective(), "2", "turns during autorun")
eq(stored, "0", "the user's value untouched")
eq(sets, 0, "never written with SetCVar")
Press("ToggleAutoRun")
check(not A.IsAutorun() and not A.IsRaised(), "autorun off: lowered")
eq(Effective(), "0", "back to when moving")

-- Each way autorun ends
for _, stop in ipairs({
    { "StopAutoRun", function() Press("StopAutoRun") end },
    { "forward key", function() Press("MoveForwardStart") end },
    { "back key", function() Press("MoveBackwardStart") end },
    { "stopped", function() Fire("PLAYER_STOPPED_MOVING") end },
    { "death", function() Fire("PLAYER_DEAD") end },
    { "loading screen", function() Fire("PLAYER_LEAVING_WORLD") end },
    { "logout", function() Fire("PLAYER_LOGOUT") end },
}) do
    Press("StartAutoRun")
    eq(Effective(), "2", "raised before " .. stop[1])
    stop[2]()
    eq(Effective(), "0", stop[1] .. ": restored")
    check(not A.IsAutorun(), stop[1] .. ": autorun over")
end

-- The user changes the dropdown mid-autorun: theirs wins
Press("StartAutoRun")
C_CVar.SetCVar("GamePadTurnWithCamera", "1")
check(not A.IsRaised(), "changed to or-in-combat: ours off")
eq(Effective(), "1", "their new choice applies")
Press("StopAutoRun")
eq(Effective(), "1", "and stays after autorun")
-- back to when moving while autorun is on: raised again
Press("StartAutoRun")
check(not A.IsRaised(), "other choice: nothing done")
C_CVar.SetCVar("GamePadTurnWithCamera", "0")
check(A.IsRaised() and Effective() == "2", "changed back to when moving mid-autorun: raised")
eq(stored, "0", "their stored choice: when moving")
Press("StopAutoRun")
eq(Effective(), "0", "restored to their new choice")

-- Any other choice: nothing done
for _, v in ipairs({ "1", "3", "2" }) do
    stored = v
    Press("StartAutoRun")
    check(not A.IsRaised() and Effective() == v, "choice " .. v .. ": left alone")
    Press("StopAutoRun")
end
stored = "0"

-- The toggle off: nothing done; off mid-autorun lowers at once
A.SetEnabled(false)
check(GamepadCompanionCharDB.autorunTurns == false, "toggle saved")
Press("StartAutoRun")
check(not A.IsRaised(), "toggle off: nothing")
A.SetEnabled(true)
check(A.IsRaised(), "toggle on mid-autorun: raised")
A.SetEnabled(false)
check(not A.IsRaised() and Effective() == "0", "toggle off mid-autorun: restored")
Press("StopAutoRun")
A.SetEnabled(true)

-- Our own temp changes are not taken for the user's
Press("StartAutoRun")
check(A.IsRaised(), "raised (our CVAR_UPDATE ignored)")
Press("StopAutoRun")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
