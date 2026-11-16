-- Helper cues: game moments sent to the outside helper (helper\, through
-- HelperLink.lua's corner pixels) for what the game can't drive itself:
-- the adaptive triggers, true haptics (USB audio channels 3-4) and the pad's
-- speaker (channels 1-2). Only while the link is on; each group can be
-- switched off. Rhythm and contrast as everywhere: clips faint by default.
local _, ns = ...
local K, H, L = ns.HelperLink, ns.Haptics, ns.HapticsLab
local C = {}
ns.HelperCues = C

local min, max, floor = math.min, math.max, math.floor
local function Now() return GetTime and GetTime() or 0 end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

C.GROUPS = {
    { key = "castTrigger", label = "Cast: R2 tightens", tip = "Resistance rising with the cast, free on release" },
    { key = "shotTrigger", label = "Auto shot: R2 clicks", tip = "A weapon click while shooting" },
    { key = "lowTrigger", label = "Low health: L2 shakes", tip = "A vibration in L2 while low" },
    { key = "clips", label = "True haptics", tip = "USB only: crits, landings, swings, releases" },
    { key = "sounds", label = "Speaker sounds", tip = "Loot, quests, errors, whispers" },
    { key = "hdFeels", label = "HD feels", tip = "Each event's feel, as the helper's HD version", off = true },
}

function C.Settings()
    local db = H.DB()
    if type(db.link) ~= "table" then db.link = {} end
    local s = db.link
    if type(s.cues) ~= "table" then s.cues = {} end
    for _, g in ipairs(C.GROUPS) do
        if s.cues[g.key] == nil then s.cues[g.key] = not g.off end
    end
    return s.cues
end

local function On(group)
    return K and K.Enabled() and C.Settings()[group] == true
end

---------------------------------------------------------------------------
-- Triggers
---------------------------------------------------------------------------
local cast = {}
local low, shooting = false, false

-- R2's state from what is going on (a cast over a shot)
local function UpdateR2()
    if not K then return end
    if cast.start and On("castTrigger") then
        local span = cast.finish - cast.start
        local p = span > 0 and min(1, max(0, (Now() - cast.start) / span)) or 1
        -- resistance from a quarter of the way down, firmer as the cast fills
        return K.SetTrigger("R2", "resist", 3, 0, 2 + floor(p * 11))
    end
    if shooting and On("shotTrigger") then return K.SetTrigger("R2", "weapon", 4, 8, 7) end
    K.SetTrigger("R2", "off", 0, 0, 0)
end

local function UpdateL2()
    if not K then return end
    if low and On("lowTrigger") then return K.SetTrigger("L2", "vibrate", 0, 5, 3) end
    K.SetTrigger("L2", "off", 0, 0, 0)
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 0.1 then return end
    acc = 0
    if cast.start then UpdateR2() end
end)

---------------------------------------------------------------------------
-- Clips and sounds, cued by Rumble's and the Beta events (wrapped)
---------------------------------------------------------------------------
local CLIP = { crit = { "thump", 3 }, critRanged = { "thump", 3 }, critted = { "thump", 5 }, levelUp = { "rumble_rise", 6 },
    interrupted = { "thump", 4 } }
local LAB_CLIP = { kill = { "release_hit", 4 }, hitTaken = { "micro_tap", 2 } }
local LAB_SOUND = { loot = { "coin", 2 }, questDone = { "chime", 3 }, uiError = { "error", 2 }, whisper = { "click", 3 },
    readyCheck = { "chime", 4 } }

function C.Clip(name, gain) if On("clips") then K.Play(name, gain) end end

-- An event's feel in HD (protocol v2): its stable id, at Rumble's strength
local function Strength()
    local ok, s = pcall(function() return ns.Rumble.Settings().intensity end)
    return ok and s or 0.8
end
function C.Feel(feelKey, gain)
    if not (On("hdFeels") and K.V2() and feelKey) then return end
    local id = L.HdId(feelKey)
    if id then K.PlayFeel(id, floor(max(0, min(1, Strength() * (gain or 1))) * 7 + 0.5)) end
end
function C.Sound(name, gain) if On("sounds") then K.Play(name, gain) end end

local function Wrap()
    local V = ns.Rumble
    if V and not V.cuesWrapped then
        V.cuesWrapped = true
        local fire, endLoop = V.Fire, V.EndLoop
        V.Fire = function(key, ...)
            fire(key, ...)
            local okA, active = pcall(V.Active)
            local pattern = okA and active and V.EventPattern(key)
            if pattern then C.Feel(L.FeelFor(pattern)) end
            local c = CLIP[key]
            if c then C.Clip(c[1], c[2]) end
            if key == "autoAttack" then
                local pattern = V.EventPattern and V.EventPattern("autoAttack")
                local heavy = pattern == "swSword2" or pattern == "swAxe2" or pattern == "swMace2" or pattern == "swPolearm"
                C.Clip(heavy and "swing_heavy" or "swing_light", heavy and 3 or 1)
            end
            if key == "lowHp" then low = true; UpdateL2() end
        end
        V.EndLoop = function(key, ...)
            endLoop(key, ...)
            if key == "lowHp" then low = false; UpdateL2() end
        end
    end
    if L and not L.cuesWrapped then
        L.cuesWrapped = true
        local fire = L.Fire
        L.Fire = function(key, ...)
            fire(key, ...)
            local e = L.EVENT and L.EVENT[key]
            if e and H.Engine() and L.EventSettings(key).on then C.Feel(L.EventSettings(key).feel) end
            local c = LAB_CLIP[key]
            if c then C.Clip(c[1], c[2]) end
            local s = LAB_SOUND[key]
            if s then C.Sound(s[1], s[2]) end
            if key == "landing" and L.lastLanding then
                local k = L.lastLanding.k or 0
                C.Clip(k > 0.5 and "landing_hard" or "landing_soft", 1 + floor(k * 6))
            end
        end
    end
end
Wrap()

---------------------------------------------------------------------------
-- Casts and shots
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED" }) do
    if not pcall(frame.RegisterUnitEvent, frame, ev, "player") then pcall(frame.RegisterEvent, frame, ev) end
end
for _, ev in ipairs({ "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "ADDON_LOADED", "PLAYER_DEAD" }) do
    pcall(frame.RegisterEvent, frame, ev)
end

local function CastTimes(channel)
    local info = channel and UnitChannelInfo or UnitCastingInfo
    if not info then return nil end
    local s, e = select(4, info("player"))
    if not (s and e) or secret(s) or secret(e) then return nil end
    return s / 1000, e / 1000
end

frame:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == "GamepadCompanion" then Wrap() end
        return
    end
    if event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
        shooting = event == "START_AUTOREPEAT_SPELL"
        return UpdateR2()
    end
    if event == "PLAYER_DEAD" then
        cast.start, low, shooting = nil, false, false
        UpdateR2(); UpdateL2()
        return
    end
    if unit and unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
        local s, e = CastTimes(channel)
        if s then cast.start, cast.finish, cast.channel = s, e, channel end
        UpdateR2()
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        local s, e = CastTimes(false)
        if s and cast.start then cast.start, cast.finish = s, e end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if cast.start and not cast.channel then
            cast.start = nil
            UpdateR2()
            C.Clip("release_hit", 4)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        cast.start = nil
        UpdateR2()
    elseif event == "UNIT_SPELLCAST_STOP" then
        -- (a cast's end: released or not, the trigger free again shortly)
        C_Timer.After(0.15, function()
            if cast.start and not cast.channel and not UnitCastingInfo("player") then cast.start = nil; UpdateR2() end
        end)
    end
end)

-- After a setting changes: the triggers as they should be now
function C.Refresh()
    UpdateR2()
    UpdateL2()
end
