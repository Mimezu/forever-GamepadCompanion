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

-- A moment's feel / sound volume (1 = full, the default)
function Vol.Feel(key) return Clamp(key and Vol.DB().feel[key] or 1) end
function Vol.Sound(key) return Clamp(key and Vol.DB().sound[key] or 1) end
function Vol.SetFeel(key, v) v = Clamp(v); Vol.DB().feel[key] = v < 1 and v or nil end
function Vol.SetSound(key, v) v = Clamp(v); Vol.DB().sound[key] = v < 1 and v or nil end

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
