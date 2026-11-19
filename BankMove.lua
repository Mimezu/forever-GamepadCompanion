-- At the bank, Square (the game's PAD3) moves the slot under the pad cursor:
-- a bank slot to the bags, a bag slot to the bank, as a right-click does
-- (C_Container.UseContainerItem). PAD3 is ours only while the bank is open and
-- out of combat; a hint under the bank shows it in Blizzard's own legend
-- (InputPromptLegends, display only, on a frame of ours).
local _, ns = ...
local Sh = ns.Shared
local B = {}
ns.BankMove = B

B.KEY = _G.GAMEPAD_FACE_LEFT or "PAD3"
B.BUTTON = "GamepadCompanionBankMove"
B.LABEL = { bank = "Move to bags", bags = "Move to bank" }

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- Slots -------------------------------------------------------------------------

-- "bank" or "bags", bag, slot for a container slot frame; nil for anything else
function B.SlotOf(frame)
    if type(frame) ~= "table" then return nil end
    if type(frame.GetBankTabID) == "function" and type(frame.GetContainerSlotID) == "function" then
        local bag, slot = Call(frame.GetBankTabID, frame), Call(frame.GetContainerSlotID, frame)
        if type(bag) == "number" and type(slot) == "number" then return "bank", bag, slot end
        return nil
    end
    if type(frame.GetBagID) == "function" and type(frame.GetID) == "function" then
        local bag, slot = Call(frame.GetBagID, frame), Call(frame.GetID, frame)
        local last = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or ((_G.NUM_BAG_SLOTS or 4) + 1)
        if type(bag) == "number" and type(slot) == "number" and bag >= 0 and bag <= last and slot >= 1 then
            return "bags", bag, slot
        end
    end
    return nil
end

-- The slot frame the pad cursor is on, else the one under the mouse
function B.Focused()
    local nav = _G.SmartNavigation
    local frame = nav and Call(nav.GetCurrentButton, nav)
    if B.SlotOf(frame) and Call(frame.IsVisible, frame) then return frame end
    local foci = GetMouseFoci and Call(GetMouseFoci)
    frame = type(foci) == "table" and foci[1] or nil
    if B.SlotOf(frame) and Call(frame.IsVisible, frame) then return frame end
    return nil
end

-- "bank" / "bags", bag, slot of the focused slot holding an item; nil otherwise
function B.Target()
    local kind, bag, slot = B.SlotOf(B.Focused())
    if not kind then return nil end
    if not (C_Container and Call(C_Container.GetContainerItemInfo, bag, slot)) then return nil end
    return kind, bag, slot
end

-- Open / bound -------------------------------------------------------------------

local open, bound = false, false
local owner = CreateFrame("Frame")
local claim = {}   -- key -> our action while bound (Shared keeps it on top)
local ACTION = "CLICK " .. B.BUTTON .. ":LeftButton"

function B.IsOpen() return open end
function B.IsBound() return bound end

local Hint

function B.Bind()
    if InCombat() then return false end
    ClearOverrideBindings(owner)
    claim[B.KEY] = nil
    bound = false
    if open then
        SetOverrideBindingClick(owner, true, B.KEY, B.BUTTON, "LeftButton")
        claim[B.KEY] = ACTION
        bound = true
    end
    return true
end
Sh.Claim(claim, function() B.Bind() end)

-- Moves the focused stack; false when there is none
function B.Move()
    if not open or InCombat() then return false end
    local _, bag, slot = B.Target()
    if not bag then return false end
    Call(C_Container.UseContainerItem, bag, slot)
    return true
end

local button = CreateFrame("Button", B.BUTTON, UIParent)
button:RegisterForClicks("AnyDown", "AnyUp")
-- (once a press: on the way down, or on the way up when the game sends only that)
local pressed = false
button:SetScript("OnClick", function(_, _, down)
    if down then pressed = true; B.Move()
    elseif pressed then pressed = false
    else B.Move() end
end)

-- Hint ---------------------------------------------------------------------------

local hint = CreateFrame("Frame", nil, UIParent)
hint:Hide()
local legend, shown

local function Legend()
    if legend ~= nil then return legend or nil end
    legend = false
    local L = _G.InputPromptLegends
    if not (L and L.CreateInputLegend and L.CreateFrameAction and L.PromptTemplates) then return nil end
    local ok, made = pcall(function()
        local l = L.CreateInputLegend(hint, "legend")
        local one = L.PromptTemplates.StandardOneIcon
        l:AddFrameAction(L.CreateFrameAction("bank", one, { B.KEY }, B.LABEL.bank))
        l:AddFrameAction(L.CreateFrameAction("bags", one, { B.KEY }, B.LABEL.bags))
        l:InitializePrompts()
        return l
    end)
    if ok and made then legend = made end
    return legend or nil
end

-- Shows the hint for what Square does now, or hides it
function Hint()
    local kind = open and not InCombat() and B.Target() or nil
    local bank = _G.BankFrame
    if not kind or not bank then hint:Hide(); shown = nil; return nil end
    local l = Legend()
    if not l then return kind end
    if shown ~= kind then
        pcall(l.ChangePromptTextToFrameAction, l, kind)
        pcall(l.ApplyDefaultPromptPositioning, l)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", bank, "BOTTOMLEFT", 0, 0)
        shown = kind
    end
    hint:Show()
    return kind
end
B.Hint = Hint

local wait = 0
local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - (elapsed or 0)
    if wait > 0 then return end
    wait = 0.1
    Hint()
end)

-- Events -------------------------------------------------------------------------

function B.Refresh()
    local frame = _G.BankFrame
    open = frame and Call(frame.IsShown, frame) and true or false
    B.Bind()
    ticker:SetShown(open)
    Hint()
end

local hooked = false
local function Hook()
    local frame = _G.BankFrame
    if hooked or not (frame and frame.HookScript) then return end
    hooked = true
    frame:HookScript("OnShow", B.Refresh)
    frame:HookScript("OnHide", B.Refresh)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    Hook()
    if event == "PLAYER_REGEN_DISABLED" then
        -- (the last moment before combat locks bindings: PAD3 back to the game)
        ClearOverrideBindings(owner)
        claim[B.KEY] = nil
        bound = false
        hint:Hide(); shown = nil
        return
    end
    -- (the bank frame shows after the event: a frame later)
    if C_Timer and C_Timer.After then C_Timer.After(0, B.Refresh) else B.Refresh() end
end)
