-- Fishing: a pole in your hands turns R2 into the line. R2 casts; while the line is out, R2
-- catches (Interact, on the bobber); the pole off, R2 is yours again. Bindings change out of
-- combat only (the pole goes on and off out of combat anyway).
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
-- The game's modifiers that can sit on R2 (R2 as Ctrl: no key of its own)
F.MODS = { "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }

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
-- The game's settings fishing changes (R2's modifier, Interact's reach) are
-- account-wide, so what they were is kept account-wide too
-- (GamepadCompanionDB.fishingCVars, cvar -> the value to put back), and put
-- back: when the pole comes off, the line comes in, R2 fishing is turned off,
-- on every logout and /reload, and at login before anything else (a record
-- left by a crash, or by 0.68.0's per-character one, heals there). Fishing
-- mode is entered again only while a pole is in hand. Never stashed elsewhere.
---------------------------------------------------------------------------
local function Record()
    if type(GamepadCompanionDB) ~= "table" then GamepadCompanionDB = {} end
    local db = GamepadCompanionDB
    if type(db.fishingCVars) ~= "table" then db.fishingCVars = {} end
    return db.fishingCVars
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

local MODS = {}
for _, cvar in ipairs(F.MODS) do MODS[cvar] = true end

-- R2's modifiers off while it fishes
local function FreeR2()
    for _, cvar in ipairs(F.MODS) do
        if Call(GetCVar, cvar) == F.KEY then Change(cvar, "NONE") end
    end
end
local function RestoreR2() Restore(MODS) end

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

-- 0.68.0 kept them per character: into the account's record, once
local function Adopt()
    local s = F.Settings()
    local rec = Record()
    if type(s.mods) == "table" then
        for cvar, value in pairs(s.mods) do if rec[cvar] == nil then rec[cvar] = value end end
    end
    if s.reach and rec.SoftTargetInteractRange == nil then rec.SoftTargetInteractRange = tostring(s.reach) end
    s.mods, s.reach = nil, nil
end

function F.Apply()
    if InCombat() then pending = true; return false end
    pending = false
    local s = F.Settings()
    local want = F.Want(s.r2, lib.PoleEquipped(), line ~= nil)
    ClearOverrideBindings(owner)
    wipe(bound)
    if want then
        FreeR2()
        if want == "catch" then
            SetOverrideBinding(owner, true, F.KEY, "INTERACTTARGET")
            bound[F.KEY] = "INTERACTTARGET"
        else
            button:SetAttribute("macrotext", F.CastMacro())
            SetOverrideBindingClick(owner, true, F.KEY, F.BUTTON, "LeftButton")
            bound[F.KEY] = "CLICK " .. F.BUTTON .. ":LeftButton"
        end
    else
        RestoreR2()
    end
    local was = mode
    mode = want ~= nil
    if mode ~= was then Note(mode and "R2 casts" or "R2 is back") end
    return true
end

function F.Mode() return mode end
function F.Line() return line end

Sh.Claim(bound, function()
    if InCombat() then pending = true; return end
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
        Restore()
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
