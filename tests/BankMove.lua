-- The bank's Square: which frames are slots, PAD3 bound only while the bank is
-- open and out of combat, the move, and the hint under the bank.
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
hooksecurefunc = function() end
GAMEPAD_FACE_LEFT = "PAD3"
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
local items = { ["6:3"] = true, ["0:1"] = true }   -- bank tab 6 slot 3, backpack slot 1
C_Container = {
    GetContainerItemInfo = function(bag, slot) return items[bag .. ":" .. slot] and { itemID = 1 } or nil end,
    UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end,
}
-- The pad cursor
local current
SmartNavigation = { GetCurrentButton = function() return current end }
local mouse
GetMouseFoci = function() return { mouse } end
-- Blizzard's legend (display only)
local legendMade, legendText, hint
InputPromptLegends = {
    PromptTemplates = { StandardOneIcon = { name = "StandardOneIcon" } },
    CreateFrameAction = function(id, _, keys, text) return { id = id, keys = keys, text = text } end,
    CreateInputLegend = function(parent, key)
        local l = Frame()
        parent[key] = l
        hint = parent
        l.actions = {}
        function l:AddFrameAction(a) table.insert(self.actions, a) end
        function l:InitializePrompts() legendText = self.actions[1].text end
        function l:ChangePromptTextToFrameAction(id)
            for _, a in ipairs(self.actions) do if a.id == id then legendText = a.text end end
        end
        function l:ApplyDefaultPromptPositioning() end
        legendMade = l
        return l
    end,
}
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

-- Slots
local bankSlot = Frame()
function bankSlot:GetBankTabID() return 6 end
function bankSlot:GetContainerSlotID() return 3 end
local bagSlot = Frame()
function bagSlot:GetBagID() return 0 end
function bagSlot:GetID() return 1 end
local emptyBag = Frame()
function emptyBag:GetBagID() return 2 end
function emptyBag:GetID() return 4 end
local tab = Frame()                       -- a bank tab: has an ID, no bag
function tab:GetID() return 2 end
local bagBar = Frame()                    -- something with a bag of -2 (keyring, not ours)
function bagBar:GetBagID() return -2 end
function bagBar:GetID() return 1 end

eq(B.KEY, "PAD3", "the game's Square")
eq((B.SlotOf(bankSlot)), "bank", "bank slot")
eq(select(2, B.SlotOf(bankSlot)), 6, "its tab")
eq(select(3, B.SlotOf(bankSlot)), 3, "its slot")
eq((B.SlotOf(bagSlot)), "bags", "bag slot")
eq(B.SlotOf(tab), nil, "a tab: not a slot")
eq(B.SlotOf(bagBar), nil, "not a bag of ours")
eq(B.SlotOf(nil), nil, "nothing")
eq(B.SlotOf("x"), nil, "not a frame")

-- Closed: PAD3 is never ours
Fire("PLAYER_LOGIN")
eq(overrides.PAD3, nil, "bank closed: PAD3 left alone")
current = bankSlot
check(not B.Move(), "bank closed: no move")
eq(#used, 0, "nothing used")

-- Open: bound; the hint follows the cursor
BankFrame:Show()
Fire("BANKFRAME_OPENED")
check(B.IsOpen() and B.IsBound(), "bank open: bound")
eq(overrides.PAD3 and overrides.PAD3.action, "CLICK " .. B.BUTTON .. ":LeftButton", "PAD3 clicks ours")
Ticker()
check(legendMade ~= nil and legendMade.shown ~= false, "hint made")
check(hint ~= BankFrame and hint.shown, "legend on our frame, shown")
eq(legendText, "Move to bags", "bank slot: Move to bags")
check(BankFrame.legend == nil, "nothing written into BankFrame")
local point = legendMade.points[1]
check(point and point[2] == BankFrame and point[1] == "TOPLEFT" and point[3] == "BOTTOMLEFT", "under the bank")

-- Square: down moves once (up after it does nothing)
button.scripts.OnClick(button, "LeftButton", true)
button.scripts.OnClick(button, "LeftButton", false)
eq(table.concat(used, ","), "6:3", "bank slot moved to the bags, once")
current = bagSlot
Ticker()
eq(legendText, "Move to bank", "bag slot: Move to bank")
button.scripts.OnClick(button, "LeftButton", false)   -- (a client sending only up)
eq(used[2], "0:1", "bag slot moved to the bank")
-- Not on a slot holding an item: nothing
used = {}
for _, f in ipairs({ tab, emptyBag, bagBar }) do
    current = f
    check(not B.Move(), "no move off a slot")
    Ticker()
    check(not hint.shown, "no hint off a slot")
end
eq(#used, 0, "nothing used off a slot")
-- The mouse when the pad cursor is elsewhere
current, mouse = nil, bankSlot
check(B.Move(), "hovered slot moves")
eq(used[1], "6:3", "the hovered one")
mouse = nil
-- A hidden slot frame (released to its pool) never counts
current = bankSlot; bankSlot.shown = false
check(not B.Move(), "hidden slot: nothing")
bankSlot.shown = true

-- Combat: unbound before lockdown, back after
Fire("PLAYER_REGEN_DISABLED")
eq(overrides.PAD3, nil, "combat: PAD3 back to the game")
combat = true
used = {}
check(not B.Move(), "combat: no move")
Ticker()
check(not hint.shown, "combat: no hint")
eq(#used, 0, "combat: nothing used")
combat = false
Fire("PLAYER_REGEN_ENABLED")
check(overrides.PAD3 ~= nil and B.IsBound(), "after combat: bound again")

-- Blizzard takes PAD3 (its binding sets): Shared puts ours back
overrides.PAD3 = { owner = UIParent, action = "" }
-- (Shared's Check runs on the hook; here, call the claim directly)
B.Bind()
check(overrides.PAD3 and overrides.PAD3.action:find(B.BUTTON, 1, true), "ours again")

-- Closed: unbound, hint gone
BankFrame:Hide()
Fire("BANKFRAME_CLOSED")
check(not B.IsOpen() and not B.IsBound(), "bank closed: unbound")
eq(overrides.PAD3, nil, "PAD3 back to the game")
check(not B.Move(), "closed: no move")
Ticker()
check(not hint.shown, "closed: no hint")
-- (the frame's own hide hook works without the event too)
BankFrame:Show()
for _, fn in ipairs(BankFrame.hooks.OnShow or {}) do fn(BankFrame) end
check(B.IsBound(), "OnShow hook binds")
BankFrame:Hide()
for _, fn in ipairs(BankFrame.hooks.OnHide or {}) do fn(BankFrame) end
check(not B.IsBound() and overrides.PAD3 == nil, "OnHide hook unbinds")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
