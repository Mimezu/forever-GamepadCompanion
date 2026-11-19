-- The bank's Square: which frames are slots, PAD3 bound only while the bank is
-- open and out of combat, sending both ways, the bank's legend bar (as the
-- bag bar), and the bag bar's □ reading "Send to bank" while the bank is open.
-- lua5.1 tests/BankMove.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs ---------------------------------------------------------------------
local frames, overrides, used, combat, timers = {}, {}, {}, false, {}
local function Frame(name)
    local f = { scripts = {}, events = {}, shown = true, hooks = {}, points = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:HookScript(k, fn) self.hooks[k] = self.hooks[k] or {}; table.insert(self.hooks[k], fn) end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:RegisterForClicks() end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) table.insert(self.points, { ... }) end
    function f:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
CreateFrame = function(_, name) return Frame(name) end
UIParent = Frame()
InCombatLockdown = function() return combat end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local l = timers; timers = {}; for _, fn in ipairs(l) do fn() end end
ClearOverrideBindings = function(owner)
    assert(not combat, "ClearOverrideBindings in combat")
    for key, o in pairs(overrides) do if o.owner == owner then overrides[key] = nil end end
end
SetOverrideBindingClick = function(owner, _, key, name, mouse)
    assert(not combat, "SetOverrideBindingClick in combat")
    overrides[key] = { owner = owner, action = "CLICK " .. name .. ":" .. mouse }
end
GetBindingAction = function(key) return overrides[key] and overrides[key].action or "" end
-- (as the game: the hook runs after the original, the original's result kept)
hooksecurefunc = function(t, key, fn)
    if type(t) ~= "table" then return end
    local original = t[key]
    t[key] = function(...) local r = original(...); fn(...); return r end
end
GAMEPAD_FACE_LEFT, GAMEPAD_FACE_BOTTOM, GAMEPAD_FACE_RIGHT = "PAD3", "PAD1", "PAD2"
GAMEPAD_PROMPT_DIVIDER_SLASH = "SLASH"
ACTION_LABEL_SELECT, FRAME_ACTION_CLOSE = "Select", "Close"
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
local items = { ["6:3"] = true, ["0:1"] = true, ["3:7"] = true, ["5:2"] = true, ["7:1"] = true, ["1:4"] = true }
C_Container = {
    GetContainerItemInfo = function(bag, slot) return items[bag .. ":" .. slot] and { itemID = 1 } or nil end,
    UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end,
}
local current, mouse
SmartNavigation = { GetCurrentButton = function() return current end }
GetMouseFoci = function() return { mouse } end

-- Blizzard's legend widget (our bank bar uses it)
-- (as the live client: InputPrompts / InputLegendPromptGroup, branch forever)
local function Prompt(text)
    local p = Frame()
    p.ControlDescText = { FontString = { text = text } }
    function p.ControlDescText.FontString:GetText() return self.text end
    function p:SetPromptText(t) self.ControlDescText.FontString.text = t end
    function p:EnablePrompt() self.lit = true end
    function p:DisablePrompt() self.lit = false end
    return p
end
local function Legend()
    local l = Frame()
    l.promptFrames, l.promptFramesAddOrder, l.positioned = {}, {}, 0
    function l:GetOrCreatePromptFrameUsingTemplateAndInputs(template, keys, divider)
        local key = template .. table.concat(keys) .. (divider or "")
        if not self.promptFrames[key] then
            local p = Prompt("")
            p.keys, p.divider, p.template = keys, divider, template
            self.promptFrames[key] = p
            table.insert(self.promptFramesAddOrder, key)
        end
        return self.promptFrames[key]
    end
    function l:ApplyDefaultPromptPositioning() self.positioned = self.positioned + 1 end
    return l
end
local bankBar, bankHolder
InputPromptLegends = {
    PromptTemplates = { StandardOneIcon = { name = "StandardOneIcon" } },
    CreateInputLegend = function(parent, key)
        local l = Legend()
        parent[key] = l
        bankHolder = parent
        bankBar = l
        return l
    end,
}
InputUtil = { IsGamepadUIEnabled = function() return true end }

-- Blizzard's bag window with its footer: Select / Use / More / Close, centred
local bags = Frame("ContainerFrameCombinedBags")
local bagLegend = Legend()
local usePrompt = bagLegend:GetOrCreatePromptFrameUsingTemplateAndInputs("StandardOneIcon", { "PAD3" }, "SLASH")
usePrompt:SetPromptText("Use")
bagLegend:SetPoint("TOP", bags, "BOTTOM", 0, -4)
local footer = { debugName = "ContainerFrameCombinedBagsFooter", inputLegend = bagLegend }
-- (Blizzard's refresh on every focus change: the □ label for the focused item)
local itemLabel = "Use"
function footer:RefreshInputLegend()
    local p = self.inputLegend:GetOrCreatePromptFrameUsingTemplateAndInputs("StandardOneIcon", { "PAD3" }, "SLASH")
    p:SetPromptText(itemLabel)
    p:Show()
    self.inputLegend:ApplyDefaultPromptPositioning()
end
-- (SmartNavigation's SelectedButtonUpdated: a closure over Refresh, which calls
-- self:RefreshInputLegend(), as the live footer)
function footer:Refresh() self:RefreshInputLegend() end
local onFocusChange = function() footer.Refresh(footer) end
bags.gamepadFooter = footer

BankFrame = Frame("BankFrame")
BankFrame.shown = false

local ns = {}
assert(loadfile(root .. "/Shared.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/BankMove.lua"))("GamepadCompanion", ns)
local B = ns.BankMove
local events
for _, f in ipairs(frames) do if f.events.BANKFRAME_OPENED then events = f end end
local function Fire(event) events.scripts.OnEvent(events, event); RunTimers() end
local function Ticker() for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 1) end end end
local button = _G[B.BUTTON]
local function Press() button.scripts.OnClick(button, "LeftButton", true); button.scripts.OnClick(button, "LeftButton", false) end

-- Slots
local function BagSlot(bag, slot)
    local f = Frame()
    function f:GetBagID() return bag end
    function f:GetID() return slot end
    return f
end
local function BankSlot(tab, slot)
    local f = Frame()
    function f:GetBankTabID() return tab end
    function f:GetContainerSlotID() return slot end
    return f
end
local bankSlot, bagSlot = BankSlot(6, 3), BagSlot(0, 1)
local tabButton = Frame(); function tabButton:GetID() return 2 end
local keyring = BagSlot(-2, 1)

eq(B.KEY, "PAD3", "the game's Square")
eq((B.SlotOf(bankSlot)), "bank", "bank slot")
eq(select(2, B.SlotOf(bankSlot)), 6, "its tab")
eq(select(3, B.SlotOf(bankSlot)), 3, "its slot")
eq((B.SlotOf(bagSlot)), "bags", "backpack slot")
eq((B.SlotOf(BagSlot(3, 7))), "bags", "a separate bag")
eq((B.SlotOf(BagSlot(5, 2))), "bags", "the reagent bag")
eq(B.SlotOf(tabButton), nil, "a tab: not a slot")
eq(B.SlotOf(keyring), nil, "not a bag of ours")
eq(B.SlotOf(nil), nil, "nothing")
eq(B.SlotOf("x"), nil, "not a frame")

-- Closed: PAD3 never ours, Blizzard's label untouched
Fire("PLAYER_LOGIN")
eq(overrides.PAD3, nil, "bank closed: PAD3 left alone")
current = bankSlot
check(not B.Move(), "bank closed: no move")
eq(#used, 0, "nothing used")
footer:RefreshInputLegend()
eq(usePrompt.ControlDescText.FontString.text, "Use", "bank closed: Use")

-- Open: bound, the bank bar, the bag bar's □ relabelled
local footerKeys = {}
for k in pairs(footer) do footerKeys[k] = true end
BankFrame:Show()
Fire("BANKFRAME_OPENED")
check(B.IsOpen() and B.IsBound(), "bank open: bound")
eq(overrides.PAD3 and overrides.PAD3.action, "CLICK " .. B.BUTTON .. ":LeftButton", "PAD3 clicks ours")
Ticker()
check(bankBar ~= nil and bankHolder.shown, "bank bar shown")
check(bankHolder ~= BankFrame and BankFrame.legend == nil, "on a frame of ours: nothing written into BankFrame")
local labels, keys, dividers = {}, {}, true
for _, key in ipairs(bankBar.promptFramesAddOrder) do
    local a = bankBar.promptFrames[key]
    labels[#labels + 1] = a.ControlDescText.FontString.text; keys[#keys + 1] = a.keys[1]
    dividers = dividers and a.divider == "SLASH" and a.template == "StandardOneIcon"
end
check(bankBar.positioned > 0, "bank bar laid out by Blizzard's layout")
eq(table.concat(labels, " · "), "Select · Send to bags · Close", "bank bar: as the bag bar's wording")
eq(table.concat(keys, ","), "PAD1,PAD3,PAD2", "Blizzard's key order")
check(dividers, "Blizzard's divider style")
local p = bankBar.points[1]
check(p and p[1] == "TOP" and p[2] == BankFrame and p[3] == "BOTTOM" and p[4] == 0 and p[5] == -4,
    "placed under the bank as the bag bar is under the bags")
eq(bankBar.promptFrames.StandardOneIconPAD3SLASH.lit, true, "bank slot: Send to bags lit")
eq(usePrompt.ControlDescText.FontString.text, "Send to bank", "bag bar: Use reads Send to bank")
footer:RefreshInputLegend()   -- (Blizzard refreshes: its label, then our hook)
eq(usePrompt.ControlDescText.FontString.text, "Send to bank", "after Blizzard's refresh: still Send to bank")
check(bagLegend.positioned > 0, "their bar laid out again for the longer label")
for k in pairs(footer) do check(footerKeys[k] or k == "RefreshInputLegend", "nothing of ours in Blizzard's footer: " .. k) end

-- Every focus change: Blizzard writes the focused item's label (Use, Equip,
-- Open...); it ends as Send to bank
for _, label in ipairs({ "Equip", "Use", "Open", "Read", "Equip" }) do
    itemLabel = label
    onFocusChange()
    eq(usePrompt.ControlDescText.FontString.text, "Send to bank", "focus on a " .. label .. " item: Send to bank")
end

-- Both ways, as the focus moves between the windows
used = {}
for _, step in ipairs({
    { bankSlot, true, "6:3" }, { bagSlot, false, "0:1" }, { BagSlot(3, 7), false, "3:7" },
    { BankSlot(7, 1), true, "7:1" }, { BagSlot(5, 2), false, "5:2" }, { BagSlot(1, 4), false, "1:4" },
}) do
    current = step[1]
    Ticker()
    eq(bankBar.promptFrames.StandardOneIconPAD3SLASH.lit, step[2], "bank bar's □ follows the focus: " .. step[3])
    Press()
    eq(used[#used], step[3], "Square sends " .. step[3])
end
eq(#used, 6, "one move a press, both ways (cloth too: 1:4)")
-- (a client sending only up)
current = bagSlot; used = {}
button.scripts.OnClick(button, "LeftButton", false)
eq(used[1], "0:1", "up only: moved once")
-- Off a slot holding an item: nothing
used = {}
for _, f in ipairs({ tabButton, BagSlot(2, 4), keyring }) do
    current = f
    check(not B.Move(), "no move off a slot")
end
eq(#used, 0, "nothing used off a slot")
-- The mouse when the pad cursor is elsewhere; a hidden slot never counts
current, mouse = nil, bankSlot
check(B.Move(), "hovered slot moves")
mouse = nil
current = bankSlot; bankSlot.shown = false
check(not B.Move(), "hidden slot: nothing")
bankSlot.shown = true

-- Combat: unbound before lockdown, back after; the bar stays, □ off
Fire("PLAYER_REGEN_DISABLED")
eq(overrides.PAD3, nil, "combat: PAD3 back to the game")
combat = true
used = {}
check(not B.Move(), "combat: no move")
Ticker()
eq(bankBar.promptFrames.StandardOneIconPAD3SLASH.lit, false, "combat: Send to bags off")
footer:RefreshInputLegend()   -- (their refresh in combat: only widget calls of ours)
eq(#used, 0, "combat: nothing used")
combat = false
Fire("PLAYER_REGEN_ENABLED")
check(overrides.PAD3 ~= nil and B.IsBound(), "after combat: bound again")

-- Blizzard takes PAD3: ours put back
overrides.PAD3 = { owner = UIParent, action = "" }
B.Bind()
check(overrides.PAD3 and overrides.PAD3.action:find(B.BUTTON, 1, true), "ours again")

-- Closed: unbound, bars back as Blizzard's
BankFrame:Hide()
Fire("BANKFRAME_CLOSED")
check(not B.IsOpen() and not B.IsBound(), "bank closed: unbound")
eq(overrides.PAD3, nil, "PAD3 back to the game")
check(not bankHolder.shown, "bank bar gone")
eq(usePrompt.ControlDescText.FontString.text, "Equip", "bag bar: Blizzard's label again (Equip, the focused item's)")
itemLabel = "Use"
onFocusChange()
eq(usePrompt.ControlDescText.FontString.text, "Use", "their refresh: Use")
-- (the frame's own show / hide hooks work without the events)
BankFrame:Show()
for _, fn in ipairs(BankFrame.hooks.OnShow or {}) do fn(BankFrame) end
check(B.IsBound() and usePrompt.ControlDescText.FontString.text == "Send to bank", "OnShow hook: bound, relabelled")
BankFrame:Hide()
for _, fn in ipairs(BankFrame.hooks.OnHide or {}) do fn(BankFrame) end
check(not B.IsBound() and overrides.PAD3 == nil and usePrompt.ControlDescText.FontString.text == "Use", "OnHide hook: all back")

-- Keyboard UI: no bar
InputUtil.IsGamepadUIEnabled = function() return false end
BankFrame:Show(); B.Refresh(); Ticker()
check(not bankHolder.shown, "keyboard UI: no bank bar")
BankFrame:Hide(); B.Refresh()

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
