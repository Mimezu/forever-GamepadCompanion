-- Keep the chosen vertical framing across Forever's native input modes.
-- The gamepad UI installs temporary CVars, which ordinary SetCVar cannot
-- override. Run after the transition handlers have installed that layer.
local watcher = CreateFrame("Frame")
local pending = false

-- reapply: switch "keep character centered" on and off, so the game frames
-- the camera again even when the settings already read right (after Alt+Z).
-- (Not the experimental dynamic pitch: turning it on can ask for confirmation.)
local function ApplyPitch(reapply)
    pending = false
    if not C_CVar or not C_CVar.SetCVar then return end
    if reapply == true then C_CVar.SetCVar("CameraKeepCharacterCentered", "1") end
    C_CVar.SetCVar("CameraKeepCharacterCentered", "0")
    C_CVar.SetCVar("test_cameraDynamicPitch", "1")
    if C_CVar.SetTempCVar and InputUtil and InputUtil.IsGamepadUIEnabled
        and InputUtil.IsGamepadUIEnabled() then
        C_CVar.SetTempCVar("CameraKeepCharacterCentered", "0")
        C_CVar.SetTempCVar("test_cameraDynamicPitch", "1")
    end
    if CameraZoomIn then CameraZoomIn(0) end
end

watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
watcher:SetScript("OnEvent", function()
    if pending then return end
    pending = true
    C_Timer.After(0, ApplyPitch)
end)

-- The interface coming back (Alt+Z, screenshot keys) drops the framing:
-- the character ends up centered. Frame it again, next frame and once more
-- a moment later in case the game reframes after drawing the interface.
if UIParent and UIParent.HookScript then
    UIParent:HookScript("OnShow", function()
        C_Timer.After(0, function() ApplyPitch(true) end)
        C_Timer.After(0.2, function() ApplyPitch(true) end)
    end)
end
