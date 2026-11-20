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
local function FreeR2(s)
    s.mods = type(s.mods) == "table" and s.mods or {}
    for _, cvar in ipairs(F.MODS) do
        if Call(GetCVar, cvar) == F.KEY then
            s.mods[cvar] = F.KEY
            Call(SetCVar, cvar, "NONE")
        end
    end
end

local function RestoreR2(s)
    if type(s.mods) ~= "table" then return end
    for cvar, value in pairs(s.mods) do
        if Call(GetCVar, cvar) == "NONE" then Call(SetCVar, cvar, value) end
    end
    s.mods = nil
end

-- Interact's reach, longer while the line is out
local function Reach(out)
    local s = F.Settings()
    if out then
        local now = tonumber((Call(GetCVar, "SoftTargetInteractRange")))
        if now and now < F.REACH then
            s.reach = s.reach or now
            Call(SetCVar, "SoftTargetInteractRange", F.REACH)
        end
    elseif s.reach then
        Call(SetCVar, "SoftTargetInteractRange", s.reach)
        s.reach = nil
    end
end

function F.Apply()
    if InCombat() then pending = true; return false end
    pending = false
    local s = F.Settings()
    local want = F.Want(s.r2, lib.PoleEquipped(), line ~= nil)
    ClearOverrideBindings(owner)
    wipe(bound)
    if want then
        FreeR2(s)
        if want == "catch" then
            SetOverrideBinding(owner, true, F.KEY, "INTERACTTARGET")
            bound[F.KEY] = "INTERACTTARGET"
        else
            button:SetAttribute("macrotext", F.CastMacro())
            SetOverrideBindingClick(owner, true, F.KEY, F.BUTTON, "LeftButton")
            bound[F.KEY] = "CLICK " .. F.BUTTON .. ":LeftButton"
        end
    else
        RestoreR2(s)
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
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "LOOT_OPENED" }) do
    pcall(events.RegisterEvent, events, ev)
end
for _, ev in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    if not pcall(events.RegisterUnitEvent, events, ev, "player") then pcall(events.RegisterEvent, events, ev) end
end
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
        lib.Attach(Sh.CharDB())
        lib.Remember()
        Reach(false)      -- (a reload with the line out: the game's reach back)
        F.Apply()
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
