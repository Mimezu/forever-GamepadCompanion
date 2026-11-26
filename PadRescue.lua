-- The pad stuck by another addon's taint (docs/PAD-HANDBACK-TAINT.md): jump and Interact
-- refused till /reload, and nothing of ours can clean a Blizzard field. Two things here.
--
-- The way out in one press. While it's stuck (Keys.PadStuckBy, Keys.Blocked: Keys.lua calls
-- R.Stuck), a quiet line at the bottom left (Passage.lua, owner "pad") says so, and Cross held
-- R.HOLD s reloads. The pad itself is read (GetDeviceMappedState, Sh.PadDown): no binding, no
-- input taken, so it works however tainted the game's own pad handling is. Out of combat only;
-- a Cross already down when the line comes up counts once it's let go.
--
-- The first taint caught in the act. The game names whichever addon's value the execution read
-- last, so the name can lie: Auctionator's LibStub.lua defines the LibStub global, and any
-- addon's code right after a LibStub(...) call writes as "Auctionator" (the 2026-11-20 taint log:
-- GatherMate2's HBD, Details' frames, BugSack's LibDBIcon, all "tainted by Auctionator").
-- Post-hooks on the writers of the hand-back's slots (the focus manager, the binding groups, the
-- binding stack) read the slots (Keys.PadSlots) after each call; the first slot newly tainted is
-- traced (errors: TAINT FIRST, TAINT STACK) with the call, its argument and the Lua stack of the
-- caller: the addon file that really drove Blizzard's code. Once a session; reads only.
-- Pure: R.Hold, R.New (tests/PadRescue.lua)
local _, ns = ...
local R = {}
ns.PadRescue = R

R.HOLD = 1.0
R.KEY = "PAD1"   -- Cross

-- The hold: state ({ since, wait }), the time, Cross down -> how far (0..1), reload now
function R.Hold(state, now, down)
    if not down then
        state.since, state.wait = nil, nil
        return 0, false
    end
    if state.wait then return 0, false end
    state.since = state.since or now
    local frac = (now - state.since) / R.HOLD
    if frac >= 1 then
        state.since, state.wait = nil, true
        return 1, true
    end
    return frac, false
end

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
local function Now() return GetTime and GetTime() or 0 end

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
local stuckBy, hold, up = nil, {}, false
local function Spec(frac)
    local C = ns.ControllerModel
    local glyph = C and C.Glyph and C.Glyph("Shp_Cross", 12) or "Cross"
    return { icon = "Interface\\Icons\\Spell_Nature_TimeStop", title = "Pad stuck", clock = "",
        frac = frac, sub = glyph .. "  Hold to reload", subLit = frac > 0 }
end
-- Keys says it's stuck (addon: the one the game blames)
function R.Stuck(addon)
    if stuckBy then return end
    stuckBy = tostring(addon or "?")
    -- (Cross down now: wait for its release)
    local buttons = Sh and Sh.PadButtons and Sh.PadButtons()
    if Sh and Sh.PadDown and Sh.PadDown(buttons, R.KEY) then hold.wait = true end
end
function R.StuckBy() return stuckBy end
local P = ns.Passage
local function Step()
    if not stuckBy or not P then return end
    if Combat() then
        if up then P.Hide("pad"); up = false end
        hold.since = nil
        return
    end
    local buttons = Sh.PadButtons()
    local frac, fire = R.Hold(hold, Now(), Sh.PadDown(buttons, R.KEY) == true)
    if not up then P.Show("pad", Spec(frac)); up = true else P.Update("pad", Spec(frac)) end
    if fire then
        Trace(("RELOAD: Cross held (pad stuck by %s)"):format(stuckBy))
        if type(ReloadUI) == "function" then ReloadUI() end
    end
end
R.Step = Step

local driver = CreateFrame("Frame")
local since = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    if not stuckBy then return end
    since = since + elapsed
    if since < 0.03 then return end
    since = 0
    Step()
end)
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:SetScript("OnEvent", function()
    Arm()
    -- (a write no hook saw: the time it was found, once a second out of combat)
    if C_Timer and C_Timer.NewTicker and not R.ticker then
        R.ticker = C_Timer.NewTicker(1, function() if not Combat() then Look("the 1 s check") end end)
    end
end)
