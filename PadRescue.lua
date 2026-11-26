-- The pad stuck by another addon's taint (docs/PAD-HANDBACK-TAINT.md): jump and Interact
-- refused till /reload, and nothing of ours can clean a Blizzard field. Two things here.
--
-- The way out in one press. While it's stuck (Keys.PadStuckBy, Keys.Blocked: Keys.lua calls
-- R.Stuck), a quiet line at the bottom left (Passage.lua, owner "pad") says so, and Cross runs
-- /reload: a secure macro button (R.BUTTON), bound on Cross with priority, acting on release.
-- ReloadUI from our own code is refused (a timer, a pad pick: ADDON_ACTION_BLOCKED, Profiles.lua);
-- a binding's press is the hardware event it needs, and the macro runs it securely. Bound once
-- out of combat (a fight first: at its end), taken back when Blizzard's own sets rebind Cross
-- (Sh.Claim), never cleared: the reload clears it. While stuck Cross does nothing else anyway.
--
-- The first taint caught in the act. The game names whichever addon's value the execution read
-- last, so the name can lie: Auctionator's LibStub.lua defines the LibStub global, and any
-- addon's code right after a LibStub(...) call writes as "Auctionator" (the 2026-11-20 taint log:
-- GatherMate2's HBD, Details' frames, BugSack's LibDBIcon, all "tainted by Auctionator").
-- Post-hooks on the writers of the hand-back's slots (the focus manager, the binding groups, the
-- binding stack) read the slots (Keys.PadSlots) after each call; the first slot newly tainted is
-- traced (errors: TAINT FIRST, TAINT STACK) with the call, its argument and the Lua stack of the
-- caller: the addon file that really drove Blizzard's code. Once a session; reads only.
-- Pure: R.New (tests/PadRescue.lua)
local _, ns = ...
local R = {}
ns.PadRescue = R

R.KEY = "PAD1"   -- Cross
R.BUTTON = "GamepadCompanionPadRescue"
R.ACTION = "CLICK " .. R.BUTTON .. ":LeftButton"
-- The slots tainted in now and not in before (label -> addon maps): "label=addon", sorted
function R.New(before, now)
    local out = {}
    for label, who in pairs(now or {}) do
        if (before or {})[label] == nil then out[#out + 1] = ("%s=%s"):format(label, tostring(who)) end
    end
    table.sort(out)
    return out
end

if not CreateFrame then return end

local Keys, Sh = ns.Keys, ns.Shared
local function Trace(line) if Keys and Keys.Trace then Keys.Trace(line, "errors") end end
local function Combat() return InCombatLockdown and InCombatLockdown() end

-- The catcher -------------------------------------------------------------------------------
local baseline, caught, armed = nil, false, false
local lastClean = "arming"
local function Name(x)
    if type(x) ~= "table" then return x == nil and "" or tostring(x) end
    local ok, name = pcall(function() return x.GetName and x:GetName() end)
    if ok and name then return name end
    return tostring(rawget(x, "name") or rawget(x, "debugName") or "a table")
end
local function Look(label, arg)
    if caught or not baseline or not (Keys and Keys.PadSlots) then return end
    local now = {}
    if not pcall(Keys.PadSlots, now) then return end
    local fresh = R.New(baseline, now)
    if #fresh == 0 then lastClean = label; return end
    caught = true
    Trace(("TAINT FIRST %s after %s(%s); clean after %s"):format(table.concat(fresh, " "), label, Name(arg), lastClean))
    local stack = type(debugstack) == "function" and debugstack(2, 40, 0) or "?"
    Trace("TAINT STACK " .. (stack:gsub("Interface/AddOns/", ""):gsub("\n", " | ")))
end
R.Look = Look
-- Hooked once Blizzard's gamepad code is there (login); what was tainted already is the
-- baseline (traced), only a new slot counts
local function Arm()
    if armed or not (Keys and Keys.PadSlots) then return end
    local fcm = GamepadMode and GamepadMode.FrameControlsManager
    local ibm = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    if type(fcm) ~= "table" or type(ibm) ~= "table" then return end
    armed = true
    baseline = {}
    pcall(Keys.PadSlots, baseline)
    local already = R.New({}, baseline)
    if #already > 0 then Trace("TAINT at login " .. table.concat(already, " ")) end
    local function Hook(t, method, isMethod)
        if type(t) == "table" and type(t[method]) == "function" then
            hooksecurefunc(t, method, function(a, b) Look(method, isMethod and b or a) end)
        end
    end
    for _, m in ipairs({ "FrameShown", "FrameHidden", "SetUIFocusState", "SetFallThroughCatcherActive",
        "HandlePopupShown", "HandlePopupHide", "FocusNextFrame", "FocusPreviousFrame" }) do Hook(fcm, m, true) end
    for _, m in ipairs({ "AddBindingSet", "RemoveSet", "AssumeCoreBindingsAreUsable" }) do Hook(ibm, m, true) end
    if type(GamepadMode) == "table" then
        for _, f in ipairs({ "ActivateBindingGroup", "DeactivateBindingGroup" }) do Hook(GamepadMode, f, false) end
    end
end
R.Arm = Arm

-- The way out -------------------------------------------------------------------------------
local stuckBy, up, bound = nil, false, false
local button = CreateFrame("Button", R.BUTTON, UIParent, "SecureActionButtonTemplate")
button:SetSize(1, 1)
button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
button:RegisterForClicks("AnyDown", "AnyUp")
button:SetAttribute("type", "macro")
button:SetAttribute("macrotext", "/reload")
button:SetAttribute("useOnKeyDown", false)   -- (on release: the press itself does nothing)
button:HookScript("PostClick", function(_, _, down)
    if down == false or down == nil then Trace(("RELOAD: Cross (pad stuck by %s)"):format(tostring(stuckBy))) end
end)
local owner = CreateFrame("Frame", "GamepadCompanionPadRescueKey")
-- Cross on the button, out of combat (else at the fight's end)
local function Bind()
    if not stuckBy or Combat() then return false end
    SetOverrideBindingClick(owner, true, R.KEY, R.BUTTON, "LeftButton")
    if not bound then
        bound = true
        Trace(("RESCUE: Cross runs /reload (pad stuck by %s)"):format(stuckBy))
    end
    return true
end
R.Bind = Bind
local claimed = false
local function Spec()
    local C = ns.ControllerModel
    local glyph = C and C.Glyph and C.Glyph("Shp_Cross", 12) or "Cross"
    return { icon = "Interface\\Icons\\Spell_Nature_TimeStop", title = "Pad stuck", clock = "",
        frac = 0, sub = glyph .. "  Reload", subLit = bound }
end
local P = ns.Passage
local function Show(fight)
    if not P then return end
    if fight or Combat() then
        if up then P.Hide("pad"); up = false end
        return
    end
    if not up then P.Show("pad", Spec()); up = true else P.Update("pad", Spec()) end
end
-- Keys says it's stuck (addon: the one the game blames)
function R.Stuck(addon)
    if stuckBy then return end
    stuckBy = tostring(addon or "?")
    if not claimed and Sh and Sh.Claim then
        claimed = true
        Sh.Claim({ [R.KEY] = R.ACTION }, function() Bind() end)
    end
    Bind()
    Show()
end
function R.StuckBy() return stuckBy end
function R.Bound() return bound end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if stuckBy then
            -- (REGEN_DISABLED comes before the lockdown: InCombatLockdown still says no)
            if event == "PLAYER_REGEN_ENABLED" then Bind() end
            Show(event == "PLAYER_REGEN_DISABLED")
        end
        return
    end
    Arm()
    -- (a write no hook saw: the time it was found, once a second out of combat)
    if C_Timer and C_Timer.NewTicker and not R.ticker then
        R.ticker = C_Timer.NewTicker(1, function() if not Combat() then Look("the 1 s check") end end)
    end
end)
