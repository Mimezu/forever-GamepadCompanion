-- Volumes: how loud each moment is, and the sounds as a whole. A moment's
-- Feel volume (its vibration: the game's motors and WoW Helper's HD feel)
-- and Sound volume (the pad's speaker), 0-100%, full by default; the Sounds
-- master scales every sound (the Vibration master is Moments › Feel ›
-- Strength). Saved in GamepadCompanionHapticsDB.volume.
--
-- To WoW Helper (protocol v2), one cue per moment: gain = the sound's volume
-- when the cue has a sound, else the touch's; intensity = the HD feel's
-- strength (4 = as designed, (i + 1) / 5).
local _, ns = ...
local H = ns.Haptics
local Vol = {}
ns.Volume = Vol

local floor, max, min = math.floor, math.max, math.min
local function Clamp(v) return max(0, min(1, tonumber(v) or 1)) end

function Vol.DB()
    local db = H.DB()
    if type(db.volume) ~= "table" then db.volume = {} end
    local v = db.volume
    if type(v.feel) ~= "table" then v.feel = {} end
    if type(v.sound) ~= "table" then v.sound = {} end
    if v.sounds == nil then v.sounds = 1 end
    return v
end

-- Defaults under full: moments that share a strong feel with a bigger one
Vol.FEEL_DEFAULT = { mount = 0.5, dismount = 0.5 }

-- A moment's feel / sound volume (its default unless set; full for most)
-- (an action, "gather:mining", "craft:cooking": its kind's volumes until it has its own)
local function Parent(key)
    local V = ns.Rumble
    if not (V and V.ActionOf) then return nil end
    local _, kind = V.ActionOf(key)
    return kind
end
function Vol.FeelDefault(key)
    local parent = Parent(key)
    if parent then return Vol.Feel(parent) end
    return Vol.FEEL_DEFAULT[key] or 1
end
function Vol.SoundDefault(key)
    local parent = Parent(key)
    if parent then return Vol.Sound(parent) end
    -- (a profile made with Profiles' FRESH: its softer frequent sounds)
    local P = ns.Profiles
    return P and P.FreshOf and P.FreshOf("soundVolumes", key) or 1
end
function Vol.Feel(key)
    -- (a spell's own, "spell:instant:Frost Nova": its own volume over its
    -- parent's, as Vol.Sound reads it from its owner)
    local parent, name, O
    if key and ns.SubMoment then parent, name, O = ns.SubMoment(key) end
    if O then return Clamp((O.Field(name, "volume") or 1) * Vol.Feel(parent)) end
    local v = key and Vol.DB().feel[key]
    if v == nil then v = key and Vol.FeelDefault(key) or 1 end
    return Clamp(v)
end
-- (a sub-moment, a spell's: saved by its owner, SpellOverrides)
local function Sub(key)
    if not ns.SubMoment then return nil end
    local _, name, O = ns.SubMoment(key)
    return name, O
end
function Vol.Sound(key)
    local name, O = Sub(key)
    if O then return Clamp(O.Field(name, "soundVolume") or 1) end
    local v = key and Vol.DB().sound[key]
    if v == nil then return Vol.SoundDefault(key) end
    return Clamp(v)
end
-- (only what differs from the default is saved)
function Vol.SetFeel(key, v)
    v = Clamp(v)
    if math.abs(v - Vol.FeelDefault(key)) < 1e-6 then v = nil end
    Vol.DB().feel[key] = v
end
function Vol.SetSound(key, v)
    v = Clamp(v)
    local name, O = Sub(key)
    if O then return O.SetField(name, "soundVolume", v < 1 and v or nil) end
    Vol.DB().sound[key] = math.abs(v - Vol.SoundDefault(key)) >= 1e-6 and v or nil
end

-- Every sound
function Vol.Sounds() return Clamp(Vol.DB().sounds) end
function Vol.SetSounds(v) Vol.DB().sounds = Clamp(v) end

-- A moment's sound, all told (0-1)
function Vol.SoundLevel(key) return Vol.Sounds() * Vol.Sound(key) end

-- 0-1 -> the strip's 3-bit gain, (g + 1) / 8; nil when silent
function Vol.Gain(v)
    v = Clamp(v)
    if v <= 0 then return nil end
    return max(0, min(7, floor(v * 8 + 0.5) - 1))
end

-- 0-1 (1 = as designed) -> an HD feel's intensity, (i + 1) / 5
function Vol.Intensity(v)
    v = Clamp(v)
    return max(0, min(7, floor(v * 5 + 0.5) - 1))
end

-- The Steppers' format and step
Vol.STEP = 0.1
function Vol.Pct(v) return floor(Clamp(v) * 100 + 0.5) .. "%" end
