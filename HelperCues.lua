-- Helper cues: game moments sent to the outside helper (helper\, through
-- HelperLink.lua's corner pixels) for what the game can't drive itself:
-- the adaptive triggers, true haptics (USB audio channels 3-4) and the pad's
-- speaker (channels 1-2). Only while the link is on; each group can be
-- switched off. Every moment's touch is its HD feel (the old USB clips are gone).
local _, ns = ...
local K, H, L = ns.HelperLink, ns.Haptics, ns.HapticsLab
local C = {}
ns.HelperCues = C

local min, max, floor = math.min, math.max, math.floor
local function Now() return GetTime and GetTime() or 0 end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

-- (the triggers: TriggerStack.lua, on the stack)
C.GROUPS = {
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
    { "spell", "Abilities" }, { "gather", "Abilities" }, { "craft", "Abilities" }, { "instant", "Attacks" },
    { "tension", "Abilities" }, { "gcd", "Abilities" }, { "combo", "Abilities" }, { "comboFull", "Abilities" },
    { "full", "Abilities" }, { "oom", "Abilities" },
    { "jump", "Moving" }, { "landing", "Moving" }, { "footsteps", "Moving" }, { "wading", "Moving" },
    { "riding", "Moving" }, { "splash", "Moving" }, { "underwater", "Moving" }, { "mount", "Moving" },
    { "dismount", "Moving" }, { "taxi", "Moving" },
    { "eat", "Care" }, { "drink", "Care" }, { "bandage", "Care" }, { "potion", "Care" }, { "rested", "Care" },
    { "rain", "Weather" }, { "thunder", "Weather" }, { "snow", "Weather" }, { "sand", "Weather" },
    { "embers", "Weather" },
    { "levelUp", "Progress" }, { "loot", "Progress" }, { "money", "Progress" }, { "questAccepted", "Progress" },
    { "questDone", "Progress" }, { "skillUp", "Progress" }, { "death", "Defense" }, { "alive", "Defense" },
    { "whisper", "Social" }, { "readyCheck", "Social" }, { "invite", "Social" }, { "summon", "Social" },
    { "uiError", "Interface" }, { "haloOpen", "Interface" }, { "wheelTick", "Interface" }, { "haloUse", "Interface" },
    { "haloClose", "Interface" },
    -- light-only moments (Lights.lua keys; the others share Rumble's and the engine's), 69-75
    { "critTaken", "Defense" }, { "avoid", "Defense" }, { "combat", "Defense" }, { "cast", "Abilities" },
    { "release", "Abilities" }, { "interrupted", "Abilities" }, { "halo", "Interface" },
    -- a cast's other ends (they went with no number, 0), 76-77
    { "cancelled", "Abilities" }, { "pushback", "Abilities" },
    -- Gathering's actions, moments of their own under it (m[3]: the parent), 78-82
    { "gather:herbalism", "Abilities", "gather" }, { "gather:mining", "Abilities", "gather" },
    { "gather:skinning", "Abilities", "gather" }, { "gather:fishing", "Abilities", "gather" },
    { "gather:opening", "Abilities", "gather" },
}
C.MOMENT_N = {}
for n, m in ipairs(C.MOMENTS) do C.MOMENT_N[m[1]] = n end
-- Light-only moments: no cue goes with their number (no sound row for them). A cast's cue goes
-- as its kind's moment (Spell casting, Gathering, Crafting: 22-24), not as "cast" (72)
C.LIGHT_ONLY = { critTaken = true, avoid = true, combat = true, cast = true, halo = true }
function C.CueKey(key)
    if key ~= "cast" then return key end
    local V = ns.Rumble
    local kind = V and V.castKind
    -- (gathering: the action's own moment, "gather:mining")
    local action = kind == "gather" and V.GatherKey and V.GatherKey(V.castAction)
    if action then return action end
    return kind and C.MOMENT_N[kind] and kind or "spell"
end

function C.Settings()
    local db = H.DB()
    if type(db.link) ~= "table" then db.link = {} end
    local s = db.link
    if type(s.cues) ~= "table" then s.cues = {} end
    -- (the old USB clips' switch: gone, the HD feels cover those moments)
    s.cues.clips = nil
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
-- Triggers: the stack's (TriggerStack.lua). Here the game's states and
-- timings it follows, pushed about 10 times a second
---------------------------------------------------------------------------
local cast = {}
local low, shooting, attacking = false, false, false
local swingAt, shotAt          -- the last swing and shot (the swing and shot timers)

local function State()
    local p
    if cast.start then
        local span = cast.finish - cast.start
        p = span > 0 and min(1, max(0, (Now() - cast.start) / span)) or 1
    end
    return { cast = cast.start ~= nil, progress = p, autoShot = shooting, autoAttack = attacking, lowHp = low,
        swingAt = swingAt, shotAt = shotAt }
end

local function UpdateTriggers()
    local TS = ns.TriggerStack
    if TS then TS.Update(State()) end
end
C.UpdateTriggers = UpdateTriggers
local UpdateR2, UpdateL2 = UpdateTriggers, UpdateTriggers

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 0.1 then return end
    acc = 0
    UpdateTriggers()
end)

---------------------------------------------------------------------------
-- Clips and sounds, cued by Rumble's and the Beta events (wrapped)
---------------------------------------------------------------------------
-- each moment's sound unless chosen (built-in names)
C.DEFAULT_SOUND = { loot = "coin", questDone = "chime", uiError = "error", whisper = "click", readyCheck = "chime" }


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
    local s = db.link.sounds
    -- (a sound picked for "Casting", 72, never a cue's now: Spell casting's, unless it has one)
    if s.cast ~= nil then
        if s.spell == nil then s.spell = s.cast end
        s.cast = nil
    end
    return s
end

-- (a sub-moment, a spell's "spell:instant:Frost Nova": saved by its owner,
-- SpellOverrides; its parent's sound until it has its own)
local function Sub(key)
    if not ns.SubMoment then return nil end
    return ns.SubMoment(key)
end

function C.MomentSound(key)
    local parent, name, O = Sub(key)
    if O then
        local v = O.Field(name, "sound")
        if v == false then return nil end
        if type(v) == "number" then return v end
        return C.MomentSound(parent)
    end
    local v = SoundDB()[key]
    if v == false then return nil end
    if type(v) == "number" then return v end
    -- (a gathering action, "gather:mining": Gathering's until it has its own)
    local Parent = ns.Rumble and ns.Rumble.GatherOf
    if Parent and Parent(key) then return C.MomentSound("gather") end
    local name = C.DEFAULT_SOUND[key]
    return name and K.SOUNDS[name] or nil
end

-- id: a sound, false: none, nil: its default
function C.SetMomentSound(key, id)
    if id ~= nil and id ~= false and type(id) ~= "number" then return end
    local _, name, O = Sub(key)
    if O then return O.SetField(name, "sound", id) end
    SoundDB()[key] = id
end

function C.IsSoundDefault(key)
    local _, name, O = Sub(key)
    if O then return O.Field(name, "sound") == nil end
    return SoundDB()[key] == nil
end

-- The sound `key` plays now: the spell playing it's own, else its own
local function Spelled(key, name)
    local O = ns.SpellOverrides
    return O and O.Now(key, "sound", name) or key
end
C.Spelled = Spelled

-- The feel a moment plays now (a library key), or nil
local function IsRumbleEvent(key)
    local V = ns.Rumble
    for _, e in ipairs(V and V.EVENTS or {}) do if e.key == key then return true end end
    return false
end
function C.MomentFeel(key)
    local V = ns.Rumble
    local action = V and V.GatherOf and V.GatherOf(key)
    if action then
        local pattern = V.ActionPattern(action)
        return pattern and L.FeelFor(pattern) or nil
    end
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
    local V = ns.Rumble
    local action = V and V.GatherOf and V.GatherOf(key)
    if action then
        L.RegisterInRumble()
        V.SetActionFeel(action, L.PatternFor(feelKey))
        return true
    end
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

-- A moment's light (Lights.lua: a light id), or nil where the moment has no light
function C.MomentLight(key)
    local LT = ns.Lights
    if not (LT and LT.EVENT and LT.EVENT[key]) then return nil end
    local s = LT.Settings(key)
    return s.on ~= false and s.light or nil
end

-- HD: "auto" (HD while the link is on) or "off" (the Setup tab's WoW Helper card)
function C.HDMode() return C.Settings().hdFeels == false and "off" or "auto" end
function C.SetHDMode(v)
    C.Settings().hdFeels = v ~= "off"
    -- (the strip's light row carries it: WoW Helper lets the game's rumble through)
    if K and K.MarkDirty then K.MarkDirty() end
end

-- A gesture slot as WoW Helper recorded it: { name, mode, desc, path } (nil
-- without data). Older data gives the name alone (a string).
-- WoW Helper's proposals: WowHelperData.proposals[momentKey] = { kind =
-- "feel" | "sound" | "light", id, name }: a pick made there, applied only
-- once accepted here. A dismissed one stays quiet until WoW Helper proposes
-- another id (H.DB().proposalsDismissed[key] = id).
function C.Proposal(kind, key)
    local d = Data()
    local p = d and type(d.proposals) == "table" and d.proposals[key]
    if type(p) ~= "table" or p.kind ~= kind or p.id == nil then return nil end
    local dismissed = H.DB().proposalsDismissed
    if type(dismissed) == "table" and dismissed[key] == tostring(p.id) then return nil end
    return { kind = p.kind, id = p.id, name = type(p.name) == "string" and p.name or tostring(p.id) }
end
function C.DismissProposal(key, id)
    local db = H.DB()
    if type(db.proposalsDismissed) ~= "table" then db.proposalsDismissed = {} end
    db.proposalsDismissed[key] = tostring(id)
end

-- WoW Helper's gestureInfo[slot]: { name, mode, motion (a few words), arm,
-- ready, plane, path = { x1, y1, x2, y2, ... } } in -1..1, y up. The path
-- comes back as points in 0..1, y down (a box's own space).
local function Path(flat)
    if type(flat) ~= "table" or #flat < 4 then return nil end
    local pts = {}
    for i = 1, #flat - 1, 2 do
        local x, y = tonumber(flat[i]), tonumber(flat[i + 1])
        if x and y then pts[#pts + 1] = { (x + 1) / 2, (1 - y) / 2 } end
    end
    return #pts >= 2 and pts or nil
end
C.GesturePath = Path
local function Str(v) return type(v) == "string" and v ~= "" and v or nil end
function C.Gesture(slot)
    local d = Data()
    if not d then return nil end
    local info = type(d.gestureInfo) == "table" and d.gestureInfo[slot]
    if type(info) == "table" and Str(info.name) then
        return { name = info.name, mode = Str(info.mode), desc = Str(info.motion), arm = Str(info.arm),
            ready = info.ready ~= false, plane = Str(info.plane), path = Path(info.path) }
    end
    -- (older data: the name alone)
    local g = type(d.gestures) == "table" and d.gestures[slot]
    if type(g) == "string" then return { name = g, ready = true } end
    return nil
end
-- Whether WoW Helper recognises gestures now (nil: it doesn't say)
function C.GesturesEnabled()
    local d = Data()
    if d and type(d.gesturesEnabled) == "boolean" then return d.gesturesEnabled end
    return nil
end
function C.GestureName(slot)
    local g = C.Gesture(slot)
    return g and g.name or nil
end

-- HD at Rumble's strength
local function Strength()
    local ok, s = pcall(function() return ns.Rumble.Settings().intensity end)
    -- (and the Feel channel: Hush, Resting 30 %… Hush.lua)
    return (ok and s or 0.8) * (ns.FeelScale and ns.FeelScale() or 1)
end
local function HdGain(gain) return floor(max(0, min(1, Strength() * (gain or 1))) * 7 + 0.5) end

-- One cue for a moment: its HD feel and its sound together, with its number.
-- Volumes (Volume.lua): gain = the sound's volume when there is a sound,
-- else the feel's; intensity = the feel's strength (4 = as designed).
function C.Moment(key, feelKey, opts)
    opts = opts or {}
    if not (K and K.Enabled()) then return false end
    local Vol = ns.Volume
    local sound = (opts.open or opts.try or On("sounds")) and not opts.noSound and C.MomentSound(key) or nil
    local soundGain
    if sound then
        if Vol then soundGain = Vol.Gain(Vol.SoundLevel(key)) else soundGain = 7 end
    end
    if not soundGain then sound = nil end
    -- (a quieter instance of the moment: its sound as much quieter)
    if sound and opts.gain and opts.gain < 1 then soundGain = max(0, floor(soundGain * opts.gain + 0.5)) end
    if not K.V2() then
        if opts.build then return nil end
        if sound and sound <= 255 then return K.PlaySound(sound, soundGain) end
        return false
    end
    local feel = max(0, min(1, Strength() * (opts.gain or 1) * (Vol and Vol.Feel(key) or 1)))
    local touch = (opts.open or On("hdFeels")) and feel > 0 and feelKey and L.HdId(feelKey) or nil
    if not (touch or sound or opts.open) then return opts.build and nil or false end
    local gain, intensity
    if sound then
        gain, intensity = soundGain, Vol and Vol.Intensity(feel) or 4
    else
        gain, intensity = HdGain(opts.gain), 4
        if Vol then gain = Vol.Gain(feel) or 0 end
    end
    -- (a cast swelling with its progress: the caller's intensity)
    if opts.intensity then intensity = max(0, min(7, floor(opts.intensity + 0.5))) end
    -- (a spell's own cue goes with no number: under its parent's, WoW Helper
    -- took the spell's sound for the parent's and dropped a pick pending on it)
    local item = { moment = C.MOMENT_N[key] or 0, touch = touch, sound = sound, gain = gain, intensity = intensity, open = opts.open }
    if opts.build then return item end
    return K.Cue(item)
end

-- The cue a moment would send now (nil: none), not sent: a swing marker
-- carries it for WoW Helper to time
function C.MomentItem(key, feelKey, opts)
    opts = opts or {}
    opts.build = true
    return C.Moment(key, feelKey, opts)
end

-- Try a moment's feel as play does: the game's rumble (the caller plays it) and, while the link
-- carries HD, WoW Helper's HD version on top, as one cue with the moment's number and volume.
-- sent: the cue already went (a simulation fires the moment). Returns what played, in few words.
function C.TryHD(key, feelKey, sent)
    if not feelKey then return nil end
    if not (K and K.Enabled()) then return "rumble (link off)" end
    if not K.V2() then return "rumble (HD link off)" end
    if C.HDMode() == "off" then return "rumble (HD off)" end
    if not sent then C.Moment(key, feelKey, { noSound = true }) end
    if Data() and not C.HasHD(feelKey) then return "rumble + HD draft" end
    return "rumble + HD"
end

-- Try a moment's sound: on the pad's speaker through WoW Helper, at its volume, as play sends it
-- (sounds switched off or not). Returns what played, or nil and why.
function C.TrySound(key)
    local id = C.MomentSound(key)
    if not id then return nil, "no sound" end
    if not (K and K.Enabled()) then return nil, "Link is off: Setup" end
    if ns.Volume and not ns.Volume.Gain(ns.Volume.SoundLevel(key)) then return nil, "volume 0%" end
    if not C.Moment(key, nil, { try = true }) then return nil, "not sent" end
    return C.SoundName(id)
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
function C.Sound(name, gain) if On("sounds") then K.PlaySound(name, gain) end end

---------------------------------------------------------------------------
-- At load: WoW Helper's own feels join the library (yours, with the rumble
-- of the feel they came from), and its proposals (use) apply once, only
-- where the moment still plays what it did when proposed
---------------------------------------------------------------------------
-- A moment's name as the game shows it
function C.MomentLabel(key)
    local label = key
    if ns.Lights and ns.Lights.EVENT and ns.Lights.EVENT[key] then label = ns.Lights.EVENT[key].label or label end
    if L.EVENT and L.EVENT[key] then label = L.EVENT[key].label end
    for _, e in ipairs(ns.Rumble and ns.Rumble.EVENTS or {}) do if e.key == key then label = e.label end end
    for _, e in ipairs(ns.Rumble and ns.Rumble.CAST_KINDS or {}) do if e.key == key then label = e.label end end
    local V = ns.Rumble
    local action = V and V.GatherOf and V.GatherOf(key)
    if action then label = V.GatherAction(action).label end
    return label
end

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
    -- (WoW Helper's picks reach the game as proposals only (C.Proposal): nothing applied here)
    if L.RegisterInRumble then L.RegisterInRumble() end
    return 0
end

-- The export (for WoW Helper): every moment with its number, group, feel and
-- sound, and the data addon's stamp once the game has loaded it
local function ExportMoments(export)
    if type(export) ~= "table" then return export end
    local moments = {}
    for n, m in ipairs(C.MOMENTS) do
        local key = m[1]
        local label = C.MomentLabel(key)
        if C.LIGHT_ONLY[key] then label = label .. " (light)" end
        -- (lightOnly: WoW Helper offers no feel or sound for it)
        -- (parent: a moment under another, "gather:mining" under "gather")
        moments[key] = { n = n, group = m[2], parent = m[3], label = label, lightOnly = C.LIGHT_ONLY[key] or nil, feel = C.MomentFeel(key) or false,
            sound = C.MomentSound(key) or false, light = C.MomentLight(key) or false,
            feelVol = ns.Volume and ns.Volume.Feel(key) or 1, soundVol = ns.Volume and ns.Volume.SoundLevel(key) or 1 }
    end
    export.moments = moments
    local d = Data()
    export.helperData = d and d.at or false
    return export
end
C.ExportMoments = ExportMoments

---------------------------------------------------------------------------
-- Looping moments (a cast, Hearthstone, eating, drinking, low health): the
-- rumble loops on its own, so their HD cue goes again each cycle while the
-- loop lasts, timed from the loop's start (no drift), a cast's swelling with
-- its progress (intensity 4 to 6: the middle no fainter than designed);
-- stopped as the loop ends
---------------------------------------------------------------------------
C.LOOP_MIN = 0.6
local loopCue
local loopFrame = CreateFrame("Frame")
loopFrame:Hide()
C.loopFrame = loopFrame

-- A cycle: the feel's own length; whole cycles, at least LOOP_MIN apart
function C.LoopPeriod(feelKey)
    local f = feelKey and H.Feel(feelKey)
    local len = f and H.Length(f) or 0
    if not len or len <= 0 then len = 1 end
    if len < C.LOOP_MIN then len = len * math.ceil(C.LOOP_MIN / len) end
    return len
end

-- A cast's HD intensity, 4 (as designed) at its start to 6 at its end (nil: not a cast)
function C.LoopIntensity(key)
    if key ~= "cast" then return nil end
    local V = ns.Rumble
    local p = V and V.CastProgress and V.CastProgress()
    if not p then return nil end
    return 4 + 2 * p
end

-- loop: Rumble's V.looping; sent: cues already sent for it (1: its first, at the fire)
local function LoopStart(loop, sent)
    -- (WoW Helper plays this loop's strikes itself: nothing from here)
    if loop and loop.helperTimed then loopCue = { loop = loop, timed = true }; loopFrame:Show(); return end
    local feel = loop and loop.pattern and L.FeelFor(loop.pattern)
    if not feel then loopCue = nil; loopFrame:Hide(); return end
    loopCue = { loop = loop, key = loop.key, feel = feel, start = GetTime(), period = C.LoopPeriod(feel), sent = sent }
    loopFrame:Show()
end

function C.LoopBegan(loop) LoopStart(loop, 1) end

function C.LoopStop()
    loopCue = nil
    loopFrame:Hide()
end

function C.LoopCue() return loopCue end

loopFrame:SetScript("OnUpdate", function()
    local V = ns.Rumble
    local cur = V and V.looping
    if not cur then return C.LoopStop() end
    -- (the loop under it picked up again: its cue at once, then each cycle)
    if not loopCue or loopCue.loop ~= cur then
        LoopStart(cur, 0)
        if not loopCue then return end
    end
    if loopCue.timed then return end
    local due = floor((GetTime() - loopCue.start) / loopCue.period) + 1
    if due > loopCue.sent then
        loopCue.sent = due
        C.Moment(C.CueKey(loopCue.key), loopCue.feel, { noSound = true, intensity = C.LoopIntensity(loopCue.key) })
    end
end)

local function Wrap()
    local V = ns.Rumble
    if V and not V.cuesWrapped then
        V.cuesWrapped = true
        local fire, endLoop = V.Fire, V.EndLoop
        V.Fire = function(key, ...)
            fire(key, ...)
            -- (the swing and shot timers start again)
            if key == "autoAttack" then swingAt = Now() elseif key == "shot" then shotAt = Now() end
            -- (WoW Helper times this blow's cue itself: the marker carried it)
            if V.cueTimed then return end
            local okA, active = pcall(V.Active)
            local pattern = okA and active and V.EventPattern(key)
            C.Moment(Spelled(C.CueKey(key)), pattern and L.FeelFor(pattern) or nil, { intensity = C.LoopIntensity(key) })
            -- (a looping moment: its HD cue again each cycle while it lasts)
            if V.looping and V.looping.key == key then C.LoopBegan(V.looping) end
            if key == "lowHp" then low = true; UpdateL2() end
        end
        V.EndLoop = function(key, ...)
            endLoop(key, ...)
            -- (none left: the HD cycles stop now; another under it: picked up)
            if not V.looping then C.LoopStop() end
            if key == "lowHp" then low = false; UpdateL2() end
        end
    end
    if L and not L.cuesWrapped then
        L.cuesWrapped = true
        local fire = L.Fire
        L.Fire = function(key, ...)
            fire(key, ...)
            local V = ns.Rumble
            if V and V.cueTimed then return end
            local e = L.EVENT and L.EVENT[key]
            -- (a landing under a real jump: its HD cue and sound fade
            -- with it, as the rumble does)
            local land = (key == "landing" or key == "splash") and L.landCue or nil
            if e then
                local s = L.EventSettings(key)
                local opts = land and land.fade < 1 and { gain = land.fade, intensity = 1 + 3 * land.fade } or nil
                C.Moment(key, H.Engine() and s.on and s.feel or nil, opts)
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
for _, ev in ipairs({ "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    "ADDON_LOADED", "PLAYER_DEAD" }) do
    pcall(frame.RegisterEvent, frame, ev)
end

local function CastTimes(channel)
    local info = channel and UnitChannelInfo or UnitCastingInfo
    if not info then return nil end
    local s, e = select(4, info("player"))
    if not (s and e) or secret(s) or secret(e) then return nil end
    return s / 1000, e / 1000
end

frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
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
    if event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_LEAVE_COMBAT" then
        attacking = event == "PLAYER_ENTER_COMBAT"
        return UpdateTriggers()
    end
    if event == "PLAYER_DEAD" then
        cast.start, low, shooting, attacking = nil, false, false, false
        UpdateR2(); UpdateL2()
        return
    end
    if unit and unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
        local s, e = CastTimes(channel)
        if s then cast.start, cast.finish, cast.channel = s, e, channel end
        cast.spell = ns.SpellOverrides and ns.SpellOverrides.NameOf(spellID) or nil
        UpdateR2()
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        local s, e = CastTimes(false)
        if s and cast.start then cast.start, cast.finish = s, e end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if cast.start and not cast.channel then
            cast.start = nil
            UpdateR2()
            -- (Spell released: its sound, the spell's own first)
            C.Moment(Spelled("release", cast.spell), nil)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        -- (a channel run to its end: released)
        local ran = event == "UNIT_SPELLCAST_CHANNEL_STOP" and cast.start and cast.channel and cast.finish
            and Now() >= cast.finish - 0.3
        cast.start = nil
        UpdateR2()
        if ran then C.Moment(Spelled("release", cast.spell), nil) end
    elseif event == "UNIT_SPELLCAST_STOP" then
        -- (a cast's end: released or not, the trigger free again shortly)
        C_Timer.After(0.15, function()
            if cast.start and not cast.channel and not UnitCastingInfo("player") then cast.start = nil; UpdateR2() end
        end)
    end
end)

-- After a setting changes: the triggers as they should be now
function C.Refresh()
    UpdateTriggers()
end
