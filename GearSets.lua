-- Equipment sets: the character window's set list works with the pad the way
-- it does with the mouse.
--
-- Blizzard's bug (PaperDollFrame.lua, Camelot, 1.60.1 build 71037): when the
-- gamepad UI turns on, PaperDollEquipmentManagerPaneMixin:InitializeGamepad
-- hides Equip and Save and re-anchors the set list to CharacterFrame.InsetRight,
-- a frame Forever's character window no longer has. The list is left with one
-- point and a height, so no width: the sets are there but drawn 0 px wide, and
-- nothing can be picked, saved or renamed. Leaving the gamepad UI
-- (UninitializeGamepad) re-anchors it the same broken way.
--
-- Fix: whenever the pane shows (and each frame while shown, for a switch of
-- mode with it open), if the list isn't on its two XML anchors, put it back
-- (PaperDollFrame.xml: TOPLEFT 5,-8 and BOTTOMRIGHT -20,105 of the pane, the
-- scroll bar beside it), and show Equip and Save again. Picking a set with the
-- cursor selects it (Blizzard's OnSmartNavSelect); Cross on a set keeps
-- Blizzard's pad menu (Equip, Save, Bind, Change name and icon, Delete).
--
-- Taint rule: only C methods on Blizzard's frames (ClearAllPoints, SetPoint,
-- Show); no Blizzard Lua called, no field of ours written on their frames.
-- SmartNavigation:RefreshButtonGroups is one of the calls opened to addons
-- (SecureHelper), made out of combat only.
local _, ns = ...
local G = {}
ns.GearSets = G

local function InCombat() return InCombatLockdown and InCombatLockdown() end

function G.Pane()
    local doll = PaperDollFrame
    return doll and doll.EquipmentManagerPane
end

-- The list sits on its two XML anchors, inside the pane
function G.Broken(pane)
    local box = pane and pane.ScrollBox
    if not (box and box.GetNumPoints) then return false end
    if box:GetNumPoints() ~= 2 then return true end
    local _, to = box:GetPoint(1)
    return to ~= pane
end

-- Puts the list and its buttons back; true when something was changed
function G.Fix(pane)
    pane = pane or G.Pane()
    if not pane then return false end
    local changed = false
    if G.Broken(pane) then
        local box, bar = pane.ScrollBox, pane.ScrollBar
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", pane, "TOPLEFT", 5, -8)
        box:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -20, 105)
        if bar and bar.ClearAllPoints then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", box, "TOPRIGHT", -5, -12)
            bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 0, 0)
        end
        changed = true
    end
    for _, key in ipairs({ "EquipSet", "SaveSet" }) do
        local button = pane[key]
        if button and button.IsShown and not button:IsShown() then
            button:Show()
            changed = true
        end
    end
    -- the cursor learns the buttons now in reach
    if changed and pane:IsShown() and not InCombat() then
        local nav = SmartNavigation
        if nav and type(nav.RefreshButtonGroups) == "function" then pcall(nav.RefreshButtonGroups, nav) end
    end
    return changed
end

local hooked
function G.Install()
    local pane = G.Pane()
    if hooked or not (pane and pane.HookScript) then return hooked end
    hooked = true
    pane:HookScript("OnShow", function(self) G.Fix(self) end)
    pane:HookScript("OnUpdate", function(self)
        if G.Broken(self) or (self.SaveSet and not self.SaveSet:IsShown()) then G.Fix(self) end
    end)
    if pane:IsShown() then G.Fix(pane) end
    return true
end

if CreateFrame then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self)
        if G.Install() then self:UnregisterAllEvents() end
    end)
end
