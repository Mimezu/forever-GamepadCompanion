-- Fishing: a pole in your hands turns R2 into the line. R2 casts; while the line is out, R2
-- catches (Interact, on the bobber); the pole off, R2 is yours again. An override binding on R2
-- alone: it fires while R2 is also the gamepad's Ctrl (checked in game), so the game's own
-- settings for R2 are never touched. R2's binding changes out of combat, and never while R2 is
-- held (read from the pad): the cast's own press ends before R2 turns into Catch.
--
-- Felt (HapticsLab events, so each is a moment WoW Helper's full feels can override):
--   the cast        Rumble's Fishing throw (gather:fishing), WoW Helper adds R2's own buzz
--   Bobber lands    a soft plop, F.LAND_AT after the cast; WoW Helper adds the game's splash
--   Nibbles         faint, now and then while you wait: a stand-in, never the bite (no
--                   moment number: 96 and up are WoW Helper's markers)
--   Fish hooked     never fired here: the game tells addons nothing when a fish bites (its
--                   events, the bobber's soft target and its cursor all stay the same). WoW
--                   Helper hears the bite's splash and plays it, with R2's reel resistance
--   Catch           the loot window of a fishing catch (IsFishingLoot)
--
-- The swap (pole <-> the weapons you held) is MimezuFishing's, a Quick use action (quick:fish).
local _, ns = ...
local Sh = ns.Shared
local lib = _G.MimezuFishing
local F = {}
ns.Fishing = F

-- Fishing, every rank
F.SPELLS = { [7620] = true, [7731] = true, [7732] = true, [18248] = true }
F.KEY = "PADRTRIGGER"
F.BUTTON = "GamepadCompanionFishing"
-- The bobber lands this long after the cast starts (s; a guess from the throw's animation)
F.LAND_AT = 1.1
-- Nibbles: none in the first seconds on the water, then now and then, a few at most
F.NIBBLE_FROM, F.NIBBLE_GAP, F.NIBBLE_MAX, F.NIBBLE_CHANCE = 3, { 3, 8 }, 3, 0.55
-- Interact's reach while the line is out: the bobber lands 10-20 yards off (the game's is 10)
F.REACH = 30
-- (R2's modifier, GamePadEmulateCtrl: 0.68.0-0.69.1 turned it off while fishing; a record of that
-- left behind is put back once at login. Fishing no longer touches it)

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function Now() return GetTime and GetTime() or 0 end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Note(text)
    if text and UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(text, 1, 0.82, 0, 1, 2) end
end

function F.Settings()
    local char = Sh.CharDB()
    if type(char.fishing) ~= "table" then char.fishing = {} end
    local s = char.fishing
    if s.r2 == nil then s.r2 = true end
    return s
end

---------------------------------------------------------------------------
-- R2: the cast button, then Interact while the line is out
---------------------------------------------------------------------------
local button = CreateFrame("Button", F.BUTTON, UIParent, "SecureActionButtonTemplate")
button:SetSize(1, 1)
button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
button:RegisterForClicks("AnyDown", "AnyUp")
button:SetAttribute("type", "macro")
local owner = CreateFrame("Frame", "GamepadCompanionFishingBinds")

local bound = {}             -- F.KEY -> what it runs now (Sh.Claim keeps it on top)
local line                   -- the line out: { start, n } (nil: none)
local mode = false           -- R2 fishes
local pending = false

function F.CastMacro()
    local name = Call(C_Spell and C_Spell.GetSpellName, lib.SPELL) or Call(GetSpellInfo, lib.SPELL) or "Fishing"
    return "/cast " .. name
end

-- What R2 runs: nil (yours), "cast" or "catch"
function F.Want(enabled, poleOn, lineOut)
    if not (enabled and poleOn) then return nil end
    return lineOut and "catch" or "cast"
end

-- R2's modifiers off while it fishes (each kept, to put back)
---------------------------------------------------------------------------
-- The one game setting fishing changes, Interact's reach, is account-wide, so
-- what it was is kept account-wide too (GamepadCompanionHapticsDB.fishingCVars,
-- cvar -> the value to put back: a table Core never rebuilds, no profile moves),
-- and put back when the line comes in, on every logout and /reload, and at
-- login before anything else. (R2's modifier: no longer changed; a record of it
-- from 0.68.0-0.69.1 is put back once at login.)
---------------------------------------------------------------------------
local function Record()
    if type(GamepadCompanionHapticsDB) ~= "table" then GamepadCompanionHapticsDB = {} end
    local h = GamepadCompanionHapticsDB
    if type(h.fishingCVars) ~= "table" then h.fishingCVars = {} end
    -- (a record 0.69.x kept in GamepadCompanionDB: carried over once, then dropped)
    local old = type(GamepadCompanionDB) == "table" and GamepadCompanionDB.fishingCVars
    if type(old) == "table" then
        for k, v in pairs(old) do if h.fishingCVars[k] == nil then h.fishingCVars[k] = v end end
        GamepadCompanionDB.fishingCVars = nil
    end
    return h.fishingCVars
end

-- Change a setting, its old value kept (the first one: never a value fishing set)
local function Change(cvar, value)
    local rec = Record()
    local now = Call(GetCVar, cvar)
    if now == nil or tostring(now) == tostring(value) then return end
    if rec[cvar] == nil then rec[cvar] = tostring(now) end
    Call(SetCVar, cvar, value)
end

-- Put settings back (nil: all of them). A setting changed since by you stays yours.
local function Restore(which)
    local rec = Record()
    for cvar, old in pairs(rec) do
        if which == nil or which[cvar] then
            local now = Call(GetCVar, cvar)
            local ours = (cvar == "SoftTargetInteractRange") and tonumber(now) == F.REACH or now == "NONE"
            if ours then Call(SetCVar, cvar, old) end
            rec[cvar] = nil
        end
    end
end
F.Restore = Restore



-- Interact's reach, longer while the line is out
local REACH = { SoftTargetInteractRange = true }
local function Reach(out)
    if out then
        local now = tonumber((Call(GetCVar, "SoftTargetInteractRange")))
        if now and now < F.REACH then Change("SoftTargetInteractRange", F.REACH) end
    else
        Restore(REACH)
    end
end

-- 0.68.0 kept them per character: into the account's record, once (then healed with it)
local function Adopt()
    local s = F.Settings()
    local rec = Record()
    if type(s.mods) == "table" then
        for cvar, value in pairs(s.mods) do if rec[cvar] == nil then rec[cvar] = value end end
    end
    if s.reach and rec.SoftTargetInteractRange == nil then rec.SoftTargetInteractRange = tostring(s.reach) end
    s.mods, s.reach = nil, nil
end

-- R2 down now, read from the pad itself (nil: no pad to read)
function F.R2Held()
    local P = C_GamePad
    if not P then return nil end
    local id = Call(P.GetActiveDeviceID)
    local state = id and Call(P.GetDeviceMappedState, id)
    local index = Call(P.ButtonBindingToIndex, F.KEY)
    if type(state) ~= "table" or type(state.buttons) ~= "table" or type(index) ~= "number" then return nil end
    return state.buttons[index + 1] and true or false
end

-- What R2 runs now (nil: yours)
local current
local listeners = {}

-- R2 catches now (bound to Interact: the line out, a pole in hand)
function F.Catching() return current == "catch" end

-- Called whenever what R2 runs changes (BobberPrompt.lua: the bobber's prompt)
function F.OnChange(fn) listeners[#listeners + 1] = fn end
local waiter = CreateFrame("Frame")
waiter:Hide()

function F.Apply()
    if InCombat() then pending = true; return false end
    pending = false
    local s = F.Settings()
    local want = F.Want(s.r2, lib.PoleEquipped(), line ~= nil)
    -- (nothing to change: the binding stays as it is, R2 held or not)
    if want == current then waiter:Hide(); return true end
    -- (never mid-press: R2 held, the change waits for its release)
    if F.R2Held() then
        waiter:Show()
        return false
    end
    waiter:Hide()
    current = want
    ClearOverrideBindings(owner)
    wipe(bound)
    if want then
        if want == "catch" then
            SetOverrideBinding(owner, true, F.KEY, "INTERACTTARGET")
            bound[F.KEY] = "INTERACTTARGET"
        else
            button:SetAttribute("macrotext", F.CastMacro())
            SetOverrideBindingClick(owner, true, F.KEY, F.BUTTON, "LeftButton")
            bound[F.KEY] = "CLICK " .. F.BUTTON .. ":LeftButton"
        end
    end
    local was = mode
    mode = want ~= nil
    if mode ~= was then Note(mode and "R2 casts" or "R2 is back") end
    for _, fn in ipairs(listeners) do pcall(fn) end
    return true
end

-- (R2 released: the change that waited)
waiter:SetScript("OnUpdate", function()
    if InCombat() then waiter:Hide(); pending = true; return end
    if not F.R2Held() then F.Apply() end
end)

Sh.Claim(bound, function()
    if InCombat() then pending = true; return end
    current = false     -- (rebind what it should be)
    F.Apply()
end)

---------------------------------------------------------------------------
-- The line out: the bobber landing, nibbles while you wait
---------------------------------------------------------------------------
local function Fire(key, gain)
    local L = ns.HapticsLab
    if L and L.Fire then pcall(L.Fire, key, gain) end
end

-- The nibbles' times for one wait (s after the cast), from rand() in [0, 1)
function F.NibbleTimes(rand, wait)
    local times, t = {}, F.LAND_AT + F.NIBBLE_FROM
    wait = wait or 20
    while #times < F.NIBBLE_MAX do
        t = t + F.NIBBLE_GAP[1] + (F.NIBBLE_GAP[2] - F.NIBBLE_GAP[1]) * rand()
        if t >= wait - 1 then break end
        if rand() < F.NIBBLE_CHANCE then times[#times + 1] = t end
    end
    return times
end

local function LineOut(spellID)
    local n = (line and line.n or 0) + 1
    local start = Now()
    local _, _, _, s, e = Call(UnitChannelInfo, "player")
    local wait = (type(s) == "number" and type(e) == "number") and (e - s) / 1000 or 20
    line = { start = start, n = n }
    F.Apply()
    Reach(true)
    local function Still() return line and line.n == n end
    C_Timer.After(F.LAND_AT, function() if Still() then Fire("fishLand") end end)
    for _, t in ipairs(F.NibbleTimes(math.random, wait)) do
        C_Timer.After(t, function() if Still() then Fire("fishNibble", 0.6 + 0.4 * math.random()) end end)
    end
end

local lastLine = -math.huge
local function LineIn()
    if not line then return end
    line = nil
    lastLine = Now()
    F.Apply()
    Reach(false)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "LOOT_OPENED" }) do
    pcall(events.RegisterEvent, events, ev)
end
for _, ev in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    if not pcall(events.RegisterUnitEvent, events, ev, "player") then pcall(events.RegisterEvent, events, ev) end
end
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
        lib.Attach(Sh.CharDB())
        lib.Remember()
        -- (the game's settings as they were before any fishing, whatever happened since; then
        -- fishing again only if a pole is in hand)
        Adopt()
        Restore()         -- (the reach; and R2's modifier, once, from an older record)
        F.Apply()
    elseif event == "PLAYER_LOGOUT" then
        -- (logout, /reload: never leave R2's modifier or the reach changed; login decides again)
        Restore()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        lib.Remember()
        if not InCombat() then F.Apply() else pending = true end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then F.Apply() end
    elseif event == "LOOT_OPENED" then
        -- (the catch: the line out or just in, its loot a fishing one)
        if (line or Now() - lastLine < 3) and Call(IsFishingLoot) then Fire("fishCatch") end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        if unit == "player" and F.SPELLS[spellID] then LineOut(spellID) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if unit == "player" and line then LineIn() end
    end
end)
