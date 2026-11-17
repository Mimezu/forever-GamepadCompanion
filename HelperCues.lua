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
    { key = "sounds", label = "Speaker sounds", tip = "Each moment's sound" },
}

---------------------------------------------------------------------------
-- Moments, numbered for the strip (protocol v2 bits 80-86) so WoW Helper
-- knows what played. APPEND ONLY: a number is never moved or reused.
-- { key, group } in the Rumble tab's order; the key is the saved key.
---------------------------------------------------------------------------
C.MOMENTS = {
    { "autoAttack", "Attacks" }, { "hit", "Attacks" }, { "crit", "Attacks" }, { "critRanged", "Attacks" },
    { "shot", "Attacks" }, { "miss", "Attacks" }, { "targetDodge", "Attacks" }, { "targetParry", "Attacks" },
    { "targetBlock", "Attacks" }, { "kill", "Attacks" },
    { "hitTaken", "Defense" }, { "critted", "Defense" }, { "dodge", "Defense" }, { "parry", "Defense" },
    { "block", "Defense" }, { "missedYou", "Defense" }, { "lowHp", "Defense" }, { "heartbeat", "Defense" },
    { "control", "Defense" }, { "targetCast", "Defense" }, { "aggro", "Defense" },
    { "spell", "Abilities" }, { "gather", "Abilities" }, { "craft", "Abilities" }, { "instant", "Abilities" },
    { "tension", "Abilities" }, { "gcd", "Abilities" }, { "combo", "Abilities" }, { "comboFull", "Abilities" },
    { "full", "Abilities" }, { "oom", "Abilities" },
    { "jump", "Moving" }, { "landing", "Moving" }, { "footsteps", "Moving" }, { "wading", "Moving" },
    { "riding", "Moving" }, { "splash", "Moving" }, { "underwater", "Moving" }, { "mount", "Moving" },
    { "dismount", "Moving" }, { "taxi", "Moving" },
    { "eat", "Care" }, { "drink", "Care" }, { "bandage", "Care" }, { "potion", "Care" }, { "rested", "Care" },
    { "rain", "Weather" }, { "thunder", "Weather" }, { "snow", "Weather" }, { "sand", "Weather" },
    { "embers", "Weather" },
    { "levelUp", "Progress" }, { "loot", "Progress" }, { "money", "Progress" }, { "questAccepted", "Progress" },
    { "questDone", "Progress" }, { "skillUp", "Progress" }, { "death", "Progress" }, { "alive", "Progress" },
    { "whisper", "Social" }, { "readyCheck", "Social" }, { "invite", "Social" }, { "summon", "Social" },
    { "uiError", "Social" }, { "haloOpen", "Social" }, { "wheelTick", "Social" }, { "haloUse", "Social" },
    { "haloClose", "Social" },
    -- light-only moments (Lights.lua keys; the others share Rumble's and the engine's), 69-75
    { "critTaken", "Defense" }, { "avoid", "Defense" }, { "combat", "Defense" }, { "cast", "Abilities" },
    { "release", "Abilities" }, { "interrupted", "Abilities" }, { "halo", "Social" },
}
C.MOMENT_N = {}
for n, m in ipairs(C.MOMENTS) do C.MOMENT_N[m[1]] = n end

function C.Settings()
    local db = H.DB()
    if type(db.link) ~= "table" then db.link = {} end
    local s = db.link
    if type(s.cues) ~= "table" then s.cues = {} end
    for _, g in ipairs(C.GROUPS) do
        if s.cues[g.key] == nil then s.cues[g.key] = not g.off end
    end
    -- HD: automatic while the link is on (was a switch, off)
    if s.cues.hdv ~= 2 then s.cues.hdFeels, s.cues.hdv = true, 2 end
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
-- each moment's sound unless chosen (built-in names)
C.DEFAULT_SOUND = { loot = "coin", questDone = "chime", uiError = "error", whisper = "click", readyCheck = "chime" }

function C.Clip(name, gain) if On("clips") then K.Play(name, gain) end end

---------------------------------------------------------------------------
-- WoW Helper's data addon (WowHelperData: written by the helper, read at
-- load): its sounds, the feels with an HD version, its own feels, proposals
---------------------------------------------------------------------------
local function Data() return type(WowHelperData) == "table" and WowHelperData or nil end
C.HelperData = Data

-- nil without data; else { at, sounds, hd } (counts)
function C.Data()
    local d = Data()
    if not d then return nil end
    local nh = 0
    for _ in pairs(type(d.hd) == "table" and d.hd or {}) do nh = nh + 1 end
    return { at = d.at or "?", sounds = type(d.sounds) == "table" and #d.sounds or 0, hd = nh }
end

-- Every sound to pick: { id, name, group, level }, the built-in ones first
function C.SoundList()
    local list, seen = {}, {}
    local d = Data()
    for _, e in ipairs(d and type(d.sounds) == "table" and d.sounds or {}) do
        local id = type(e) == "table" and tonumber(e.id)
        if id and not seen[id] then
            seen[id] = true
            list[#list + 1] = { id = id, name = e.name or ("Sound " .. id), group = e.group or "Library", level = e.level }
        end
    end
    local builtin = {}
    for name, id in pairs(K.SOUNDS) do
        if not seen[id] then
            local label = (name:sub(1, 1):upper() .. name:sub(2)):gsub("_", " ")
            builtin[#builtin + 1] = { id = id, name = label, group = "Built in" }
        end
    end
    table.sort(builtin, function(a, b) return a.id < b.id end)
    for i = #builtin, 1, -1 do table.insert(list, 1, builtin[i]) end
    return list
end

function C.SoundName(id)
    if not id then return nil end
    for _, e in ipairs(C.SoundList()) do if e.id == id then return e.name end end
    return "Sound " .. id
end

-- A feel with an HD version in WoW Helper (from its data; its own feels always)
function C.HasHD(feelKey)
    local d = Data()
    if not (d and feelKey) then return false end
    if type(d.hd) == "table" and d.hd[feelKey] then return true end
    return type(d.feels) == "table" and type(d.feels[feelKey]) == "table"
end

---------------------------------------------------------------------------
-- A moment's sound: chosen (an id), none (false), else its default
---------------------------------------------------------------------------
local function SoundDB()
    local db = H.DB()
    if type(db.link) ~= "table" then db.link = {} end
    if type(db.link.sounds) ~= "table" then db.link.sounds = {} end
    return db.link.sounds
end

function C.MomentSound(key)
    local v = SoundDB()[key]
    if v == false then return nil end
    if type(v) == "number" then return v end
    local name = C.DEFAULT_SOUND[key]
    return name and K.SOUNDS[name] or nil
end

-- id: a sound, false: none, nil: its default
function C.SetMomentSound(key, id)
    if id ~= nil and id ~= false and type(id) ~= "number" then return end
    SoundDB()[key] = id
end

function C.IsSoundDefault(key) return SoundDB()[key] == nil end

-- The feel a moment plays now (a library key), or nil
local function IsRumbleEvent(key)
    local V = ns.Rumble
    for _, e in ipairs(V and V.EVENTS or {}) do if e.key == key then return true end end
    return false
end
function C.MomentFeel(key)
    if IsRumbleEvent(key) then
        local choice = ns.Rumble.EventChoice(key)
        if choice == "off" then return nil end
        local pattern = ns.Rumble.EventPattern(key)
        return pattern and L.FeelFor(pattern) or nil
    end
    if L.EVENT and L.EVENT[key] then
        local s = L.EventSettings(key)
        return s.on and s.feel or nil
    end
    return nil
end

-- Set a moment's feel (a library key) as the Rumble tab would
function C.SetMomentFeel(key, feelKey)
    if IsRumbleEvent(key) then
        L.RegisterInRumble()
        ns.Rumble.SetEventPattern(key, L.PatternFor(feelKey))
        return true
    end
    if L.EVENT and L.EVENT[key] then
        local s = L.EventSettings(key)
        s.on, s.feel = true, feelKey
        return true
    end
    return false
end

-- HD: "auto" (HD while the link is on) or "off" (the Setup tab's WoW Helper card)
function C.HDMode() return C.Settings().hdFeels == false and "off" or "auto" end
function C.SetHDMode(v) C.Settings().hdFeels = v ~= "off" end

-- A gesture slot's name, as recorded in WoW Helper (nil without data)
function C.GestureName(slot)
    local d = Data()
    local g = d and type(d.gestures) == "table" and d.gestures[slot]
    return type(g) == "string" and g or nil
end

-- HD at Rumble's strength
local function Strength()
    local ok, s = pcall(function() return ns.Rumble.Settings().intensity end)
    return ok and s or 0.8
end
local function HdGain(gain) return floor(max(0, min(1, Strength() * (gain or 1))) * 7 + 0.5) end

-- One cue for a moment: its HD feel and its sound together, with its number
function C.Moment(key, feelKey, opts)
    opts = opts or {}
    if not (K and K.Enabled()) then return false end
    local sound = (opts.open or On("sounds")) and C.MomentSound(key) or nil
    if not K.V2() then
        if sound and sound <= 255 then return K.Play(sound, 2) end
        return false
    end
    local touch = (opts.open or On("hdFeels")) and feelKey and L.HdId(feelKey) or nil
    return K.Cue({ moment = C.MOMENT_N[key], touch = touch, sound = sound, gain = HdGain(opts.gain), open = opts.open })
end

-- Edit HD: the moment plays and opens in WoW Helper. Returns ok, why.
function C.EditHD(key)
    if not (K and K.Enabled()) then return false, "Link is off" end
    if not K.V2() then return false, "HD link is off" end
    if not Data() then return false, "Needs WoW Helper" end
    return C.Moment(key, C.MomentFeel(key), { open = true }), nil
end

-- A feel alone, in HD
function C.Feel(feelKey, gain)
    if not (On("hdFeels") and K.V2() and feelKey) then return end
    local id = L.HdId(feelKey)
    if id then K.PlayFeel(id, HdGain(gain)) end
end
function C.Sound(name, gain) if On("sounds") then K.Play(name, gain) end end

---------------------------------------------------------------------------
-- At load: WoW Helper's own feels join the library (yours, with the rumble
-- of the feel they came from), and its proposals (use) apply once, only
-- where the moment still plays what it did when proposed
---------------------------------------------------------------------------
function C.Say(text) if print then print("|cff80c0ffGamepad Companion:|r " .. text) end end

function C.LoadHelperData()
    local d = Data()
    if not d then return 0 end
    local db = H.DB()
    if type(db.hdIds) ~= "table" then db.hdIds = { next = 128 } end
    for key, f in pairs(type(d.feels) == "table" and d.feels or {}) do
        local hd = type(f) == "table" and tonumber(f.hd)
        if hd and hd >= 2048 and hd <= 4095 and type(key) == "string" and key:sub(1, 3) == "hx_" then
            db.hdIds[key] = hd
            local own = db.feels[key]
            if type(own) ~= "table" then
                local from = f.from and H.Feel(f.from)
                own = from and H.Copy(from) or { pulses = { { 0, 0.06, 0.4, 0 } } }
                own.key, own.group, own.rumble = nil, nil, nil
                own.icon = own.icon or "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_pulse"
                db.feels[key] = own
            end
            own.label = f.label or own.label or key
            own.helper = true
        end
    end
    local applied = 0
    if type(db.link) ~= "table" then db.link = {} end
    if type(db.link.used) ~= "table" then db.link.used = {} end
    for moment, u in pairs(type(d.use) == "table" and d.use or {}) do
        local stamp = type(u) == "table" and tonumber(u.stamp)
        if stamp and stamp > (db.link.used[moment] or 0) and C.MOMENT_N[moment] then
            db.link.used[moment] = stamp
            local was = C.MomentFeel(moment)
            if u.feel and was == u.base and H.Feel(u.feel) and u.feel ~= was then
                C.SetMomentFeel(moment, u.feel)
                local f, w = H.Feel(u.feel), was and H.Feel(was)
                C.Say(string.format("%s: %s (was %s) · WoW Helper", moment, f.label or u.feel, w and (w.label or was) or "Off"))
                applied = applied + 1
            end
            if u.sound ~= nil and (C.MomentSound(moment) or false) == (u.soundBase or false) then
                C.SetMomentSound(moment, u.sound)
            end
        end
    end
    if L.RegisterInRumble then L.RegisterInRumble() end
    return applied
end

-- The export (for WoW Helper): every moment with its number, group, feel and
-- sound, and the data addon's stamp once the game has loaded it
local function ExportMoments(export)
    if type(export) ~= "table" then return export end
    local moments = {}
    for n, m in ipairs(C.MOMENTS) do
        local key = m[1]
        local label = key
        if L.EVENT and L.EVENT[key] then label = L.EVENT[key].label end
        for _, e in ipairs(ns.Rumble and ns.Rumble.EVENTS or {}) do if e.key == key then label = e.label end end
        for _, e in ipairs(ns.Rumble and ns.Rumble.CAST_KINDS or {}) do if e.key == key then label = e.label end end
        moments[key] = { n = n, group = m[2], label = label, feel = C.MomentFeel(key) or false,
            sound = C.MomentSound(key) or false }
    end
    export.moments = moments
    local d = Data()
    export.helperData = d and d.at or false
    return export
end
C.ExportMoments = ExportMoments

local function Wrap()
    local V = ns.Rumble
    if V and not V.cuesWrapped then
        V.cuesWrapped = true
        local fire, endLoop = V.Fire, V.EndLoop
        V.Fire = function(key, ...)
            fire(key, ...)
            local okA, active = pcall(V.Active)
            local pattern = okA and active and V.EventPattern(key)
            C.Moment(key, pattern and L.FeelFor(pattern) or nil)
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
            if e then
                local s = L.EventSettings(key)
                C.Moment(key, H.Engine() and s.on and s.feel or nil)
            end
            local c = LAB_CLIP[key]
            if c then C.Clip(c[1], c[2]) end
            if key == "landing" and L.lastLanding then
                local k = L.lastLanding.k or 0
                C.Clip(k > 0.5 and "landing_hard" or "landing_soft", 1 + floor(k * 6))
            end
        end
    end
    if L and L.Export and not L.momentsWrapped then
        L.momentsWrapped = true
        local export = L.Export
        L.Export = function(...) return ExportMoments(export(...)) end
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
        if unit == "GamepadCompanion" then
            Wrap()
            pcall(C.LoadHelperData)
        end
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
