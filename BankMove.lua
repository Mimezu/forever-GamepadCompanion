-- At the bank, Square (the game's PAD3) sends the slot under the pad cursor
-- across: a bank slot to the bags, a bag slot to the bank, as a right-click
-- does (C_Container.UseContainerItem). PAD3 is ours only while the bank is open
-- and out of combat. (Blizzard's own □ on a bag slot is that right-click too,
-- but only for items it can Use / Equip / Open / Read: ours also sends cloth,
-- reagents and the rest.)
--
-- The bank gets the bag window's legend bar: Blizzard's own legend widget
-- (InputPromptLegends) on a frame of ours, placed under the bank as theirs is
-- under the bags: ✕ Select · □ Send to bags · ○ Close. While the bank is open,
-- the bag bar's □ reads "Send to bank" (set after their refresh, through a
-- secure hook and widget calls: nothing written into Blizzard's tables).
local _, ns = ...
local Sh = ns.Shared
local B = {}
ns.BankMove = B

B.KEY = _G.GAMEPAD_FACE_LEFT or "PAD3"
B.SELECT_KEY = _G.GAMEPAD_FACE_BOTTOM or "PAD1"
B.CLOSE_KEY = _G.GAMEPAD_FACE_RIGHT or "PAD2"
B.BUTTON = "GamepadCompanionBankMove"
B.LABEL = { bank = "Send to bags", bags = "Send to bank" }

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
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

-- Sends the focused stack across; false when there is none
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

-- The bag bar's □ -----------------------------------------------------------------
-- Blizzard's bag footers (PromptedBindingFooter): their legend's PAD3 prompt.

local function BagFrames()
    local list = { _G.ContainerFrameCombinedBags }
    for i = 1, (_G.NUM_CONTAINER_FRAMES or 13) do list[#list + 1] = _G["ContainerFrame" .. i] end
    return list
end

-- (the legend keeps a prompt per template + keys + divider: "StandardOneIconPAD3SLASH";
-- Blizzard re-labels it on every focus change, per item: Use, Equip, Open...)
local function PromptKey()
    return "StandardOneIcon" .. B.KEY .. (_G.GAMEPAD_PROMPT_DIVIDER_SLASH or "SLASH")
end

local function BagPrompt(footer)
    local legend = type(footer) == "table" and footer.inputLegend
    if type(legend) ~= "table" then return nil end
    local frames = type(legend.promptFrames) == "table" and legend.promptFrames
    local prompt = frames and frames[PromptKey()]
    if not prompt and type(legend.promptMap) == "table" then   -- (older clients)
        prompt = legend.promptMap[tostring(footer.debugName) .. B.KEY]
    end
    return prompt, legend
end

local originals = setmetatable({}, { __mode = "k" })   -- prompt -> Blizzard's text we covered

local function SetPrompt(prompt, legend, text)
    Call(prompt.SetPromptText, prompt, text)
    Call(legend.ApplyDefaultPromptPositioning, legend)
end

local function PromptText(prompt)
    local desc = prompt.ControlDescText
    local fs = type(desc) == "table" and desc.FontString
    return fs and Call(fs.GetText, fs)
end

-- After Blizzard's refresh: "Send to bank" while the bank is open
local function Relabel(footer)
    local prompt, legend = BagPrompt(footer)
    if not (prompt and legend) then return end
    local text = PromptText(prompt)
    if open then
        if text ~= B.LABEL.bags then originals[prompt] = text end
        if Call(prompt.IsShown, prompt) and text ~= B.LABEL.bags then SetPrompt(prompt, legend, B.LABEL.bags) end
    elseif originals[prompt] then
        if text == B.LABEL.bags then SetPrompt(prompt, legend, originals[prompt]) end
        originals[prompt] = nil
    end
end
B.Relabel = Relabel

local hookedFooters = setmetatable({}, { __mode = "k" })
local function HookBagBars()
    for _, frame in ipairs(BagFrames()) do
        local footer = type(frame) == "table" and frame.gamepadFooter
        if type(footer) == "table" and not hookedFooters[footer] and type(footer.RefreshInputLegend) == "function" then
            hookedFooters[footer] = true
            -- (Refresh's closures call self:RefreshInputLegend(): a hook there runs after each)
            hooksecurefunc(footer, "RefreshInputLegend", Relabel)
        end
        if type(footer) == "table" then Relabel(footer) end
    end
end

-- The bank's bar -------------------------------------------------------------------

local holder = CreateFrame("Frame", nil, UIParent)
holder:Hide()
local bar   -- Blizzard's legend, or false when this client has none

local function Text(name, fallback)
    local t = _G[name]
    return type(t) == "string" and t ~= "" and t or fallback
end

local prompts = {}   -- id -> the bank bar's prompt frame
local sendLit

-- Built as Blizzard's footer builds its legend: one prompt per key, in their
-- key order, their template and divider, then their layout
local function Bar()
    if bar ~= nil then return bar or nil end
    bar = false
    local L = _G.InputPromptLegends
    if not (L and L.CreateInputLegend) then return nil end
    local ok, made = pcall(function()
        local l = L.CreateInputLegend(holder, "legend")
        local divider = _G.GAMEPAD_PROMPT_DIVIDER_SLASH or "SLASH"
        for _, a in ipairs({
            { "select", B.SELECT_KEY, Text("ACTION_LABEL_SELECT", "Select") },
            { "send", B.KEY, B.LABEL.bank },
            { "close", B.CLOSE_KEY, Text("FRAME_ACTION_CLOSE", "Close") },
        }) do
            local prompt = l:GetOrCreatePromptFrameUsingTemplateAndInputs("StandardOneIcon", { a[2] }, divider)
            prompt:SetPromptText(a[3])
            prompt:EnablePrompt()
            prompt:Show()
            prompts[a[1]] = prompt
        end
        l:ApplyDefaultPromptPositioning()
        return l
    end)
    if ok and made then bar = made end
    return bar or nil
end

-- Where Blizzard put the bag bar under the bags: the same under the bank
local function Place(l, bank)
    local point, relPoint, x, y = "TOPLEFT", "BOTTOMLEFT", 0, 0
    for _, frame in ipairs(BagFrames()) do
        local footer = type(frame) == "table" and frame.gamepadFooter
        local legend = type(footer) == "table" and footer.inputLegend
        if type(legend) == "table" and legend.GetPoint then
            local p, rel, rp, px, py = Call(legend.GetPoint, legend, 1)
            if p and rel == frame then point, relPoint, x, y = p, rp, px or 0, py or 0; break end
        end
    end
    l:ClearAllPoints()
    l:SetPoint(point, bank, relPoint, x, y)
end

local function GamepadUI()
    local util = _G.InputUtil
    if util and util.IsGamepadUIEnabled then return Call(util.IsGamepadUIEnabled) and true or false end
    return true
end

-- The bank bar for what's focused now; returns what □ does ("bank" / "bags") or nil
function B.Hint()
    local bank = _G.BankFrame
    if not (open and bank and GamepadUI()) then holder:Hide(); return nil end
    local l = Bar()
    if l then
        Place(l, bank)
        local lit = (not InCombat() and B.Target() or nil) == "bank"
        local send = prompts.send
        if send and lit ~= sendLit then
            if lit then Call(send.EnablePrompt, send) else Call(send.DisablePrompt, send) end
            sendLit = lit
        end
        holder:Show()
    end
    return not InCombat() and (B.Target()) or nil
end

local wait = 0
local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - (elapsed or 0)
    if wait > 0 then return end
    wait = 0.1
    B.Hint()
end)

-- Events -------------------------------------------------------------------------

function B.Refresh()
    local frame = _G.BankFrame
    open = frame and Call(frame.IsShown, frame) and true or false
    B.Bind()
    ticker:SetShown(open)
    B.Hint()
    HookBagBars()
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
        return
    end
    -- (the bank frame shows after the event: a frame later)
    if C_Timer and C_Timer.After then C_Timer.After(0, B.Refresh) else B.Refresh() end
end)
