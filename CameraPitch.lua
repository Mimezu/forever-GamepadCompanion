-- Keep the chosen vertical framing across Forever's native input modes.
-- The gamepad UI installs temporary CVars, which ordinary SetCVar cannot
-- override. Run after the transition handlers have installed that layer.
local watcher = CreateFrame("Frame")
local pending = false

local function ApplyPitch()
    pending = false
    if not C_CVar or not C_CVar.SetCVar then return end
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
