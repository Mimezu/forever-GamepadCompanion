-- Weather from the game's own report (C_Weather): the kinds it names, the trace kept of what it
-- said, and each weather felt and sent to WoW Helper (a sand gust, a thunder roll, a rain tap:
-- while its HD drives the pad the game's rumble is not felt, so a cue missing is weather missing).
-- lua5.1 tests/Weather.lua <addon folder>
local root = arg[1] or "."
local T = dofile(root .. "/tests/support/ClassHarness.lua")
local L, H, V, ns = T.L, T.H, T.V, T.ns
local C = ns.HelperCues
local check, eq = T.check, T.eq
math.randomseed(7)

-- The game: outdoors in Tanaris, standing still, alive
GetRealZoneText = function() return "Tanaris" end
IsIndoors = function() return false end
IsSwimming = function() return false end
IsFalling = function() return false end
IsFlying = function() return false end
IsMounted = function() return false end
UnitOnTaxi = function() return false end
GetUnitSpeed = function() return 0 end
if type(Enum) ~= "table" then Enum = {} end
Enum.WeatherType = { None = 0, Rain = 1, Snow = 2, Sandstorm = 3 }
local sky = { 0, 0 }
C_Weather = { GetCurrentWeather = function() return sky[1], sky[2] end }
H.DB().engine = true
V.Settings().enabled = true
for _, k in ipairs(L.WEATHER_KEYS) do L.EventSettings(k).on = true; L.EventDefault(k) end

-- Kinds: what each name the client may use means --------------------------------------------
do
    local kind, thunders = L.WeatherKind("Rain")
    check(kind == "rain" and not thunders, "Rain: rain")
    eq(L.WeatherKind("Snow"), "snow", "Snow")
    eq(L.WeatherKind("Sandstorm"), "sand", "Sandstorm: sand")
    eq(L.WeatherKind("Storm"), "sand", "retail's Storm reads as sand")
    kind, thunders = L.WeatherKind("Thunders")
    check(kind == "rain" and thunders, "Thunders: rain that thunders")
    eq(L.WeatherKind("BlackRain"), "rain", "BlackRain: rain")
    eq(L.WeatherKind("BlackSnow"), "snow", "BlackSnow: snow")
    eq(L.WeatherKind("3"), "sand", "a bare 3 (no Enum): sand")
    eq(L.WeatherKind("1"), "rain", "a bare 1: rain")
    eq(L.WeatherKind("None"), nil, "None: nothing")
    eq(L.WeatherKind(nil), nil, "nil: nothing")
end

-- Reading: both return shapes, with and without the Enum; the trace kept -----------------------
do
    H.DB().weatherLog = nil
    sky = { 3, 0.5 }
    local w = L.ReadWeather()
    check(w and w.kind == "sand" and w.name == "Sandstorm" and w.intensity == 0.5, "a sandstorm, named by the Enum")
    eq(w.raw, "3, 0.5", "raw kept as the game gave it")
    local brings, i = L.Sky()
    check(brings.sand and not brings.rain and not brings.thunder and not brings.embers, "the sky brings sand only")
    eq(i, 0.5, "its intensity")
    -- (a table return)
    C_Weather.GetCurrentWeather = function() return { weatherType = 1, intensity = 0.9 } end
    w = L.ReadWeather()
    check(w.kind == "rain" and w.intensity == 0.9, "a table: rain 0.9")
    brings = L.Sky()
    check(brings.rain and brings.thunder, "heavy rain thunders")
    -- (a thundering type thunders however light)
    C_Weather.GetCurrentWeather = function() return "Thunders", 0.2 end
    w = L.ReadWeather()
    check(w.kind == "rain" and w.thunders, "Thunders by name")
    check(L.Sky().thunder, "and thunders though light")
    -- (no Enum: the number alone)
    local E = Enum.WeatherType
    Enum.WeatherType = nil
    C_Weather.GetCurrentWeather = function() return 2, 0.4 end
    w = L.ReadWeather()
    check(w.kind == "snow" and w.name == "2", "a bare 2 without the Enum: snow")
    Enum.WeatherType = E
    -- the trace: one entry per change, zone and raw, the latest first in Weather seen
    local log = H.DB().weatherLog
    check(type(log) == "table" and #log == 4, "four changes logged (got " .. tostring(log and #log) .. ")")
    check(log[1].zone == "Tanaris" and log[1].raw == "3, 0.5", "the first: Tanaris 3, 0.5")
    L.ReadWeather(); L.ReadWeather()
    eq(#H.DB().weatherLog, 4, "the same report again: not logged twice")
    local seen = L.WeatherSeen(2)
    check(seen:find("^Tanaris 2, 0.4") and seen:find("Thunders, 0.2") and not seen:find("3, 0.5"), "Weather seen: the last two, latest first (" .. seen .. ")")
    for n = 1, 20 do
        C_Weather.GetCurrentWeather = function() return 1, n / 20 end
        L.ReadWeather()
    end
    eq(#H.DB().weatherLog, L.WEATHER_LOG_MAX, "the trace keeps the last " .. L.WEATHER_LOG_MAX)
    C_Weather.GetCurrentWeather = function() return sky[1], sky[2] end
    H.DB().weatherLog = nil
    L.ReadWeather()
    eq(L.WeatherSeen(), "Tanaris 3, 0.5", "Weather seen without a time stamp: zone and raw")
end

-- A function voice keeps its own state, a `level` among it (the taps' strength): the mixer once
-- read that as a held level and dropped the voice on its first frame, so a rain tap lasted one
-- frame and the rhythm started over each time (no denser when heavier, no second drop)
do
    local calls = 0
    H.Fn("fn_level", function(now, v)
        calls = calls + 1
        v.level, v.next = 0.5, now + 1
        return 0.3, 0.3
    end)
    for _ = 1, 3 do T.Advance(0.05); H.Mix(T.Now()) end
    check(H.Playing("fn_level") and calls == 3, "a function voice with a level field of its own plays on")
    H.Stop("fn_level")
    H.Set("held", 0.4, 0.4)
    local l, r = H.Mix(T.Now())
    check(H.Playing("held") and l > 0.3, "a held level still plays")
    H.Set("held", 0, 0)
    check(not H.Playing("held"), "and frees at 0")
end

-- Each weather to WoW Helper: its cues, as Poll and the mixer run -------------------------------
local cues = {}
check(type(L.onWeather) == "function", "HelperCues hooks the weather")
local moment = C.Moment
C.Moment = function(key, feel, opts)
    cues[#cues + 1] = { key = key, feel = feel, intensity = opts and opts.intensity, noSound = opts and opts.noSound }
    return true
end
if ns.HelperLink then
    ns.HelperLink.Enabled = function() return true end
    ns.HelperLink.V2 = function() return true end
end
local motors = { frames = 0, loud = 0 }
-- The game for `seconds`: Poll each 0.1 s, the mixer each 0.05 s, every weather voice sampled
local function play(seconds)
    for _ = 1, math.floor(seconds / 0.05) do
        T.Advance(0.05)
        local now = T.Now()
        if math.floor(now * 20) % 2 == 0 then L.Poll() end
        local l, r = H.Mix(now)
        motors.frames = motors.frames + 1
        if (l or 0) + (r or 0) > 0 then motors.loud = motors.loud + 1 end
    end
end
local function count(key)
    local n, lo, hi = 0, 99, 0
    for _, c in ipairs(cues) do
        if c.key == key then
            n = n + 1
            lo, hi = math.min(lo, c.intensity or 0), math.max(hi, c.intensity or 0)
        end
    end
    return n, lo, hi
end

-- A sandstorm: gusts now and then, each one cue, each felt on the motors
do
    sky = { 3, 0.5 }; L.ReadWeather()
    L.Poll()
    check(H.Playing("live_sand"), "a sandstorm: the sand voice plays")
    check(not H.Playing("live_rain") and not H.Playing("live_thunder"), "and nothing else")
    cues, motors = {}, { frames = 0, loud = 0 }
    play(60)
    local n, lo, hi = count("sand")
    check(n >= 3 and n <= 9, "gusts now and then in a minute: " .. n)
    check(lo >= 3 and hi <= 5, "each as designed about (intensity " .. lo .. "-" .. hi .. ")")
    for _, c in ipairs(cues) do
        check(c.feel == "sandgust" and c.noSound, "a gust's cue: the Sand gust feel, no sound")
    end
    -- (a gust: 5-7 grains of a pulse each, so about 0.3-0.4 s of motor per gust)
    local perGust = motors.loud * 0.05 / n
    check(perGust > 0.2 and perGust < 0.6, "each gust moves the motors for a while (" .. string.format("%.2f", perGust) .. " s)")
    -- heavier: gusts closer together
    sky = { 3, 1 }; L.ReadWeather()
    cues = {}
    play(120)
    local heavy = count("sand")
    sky = { 3, 0 }; L.ReadWeather()
    cues = {}
    play(120)
    local light = count("sand")
    check(heavy > light, "a heavy storm gusts more often than a light one (" .. heavy .. " vs " .. light .. ")")
end

-- Indoors, under water or dead: the storm is not felt; out again: it is
do
    sky = { 3, 0.5 }; L.ReadWeather()
    IsIndoors = function() return true end
    L.Poll()
    check(not H.Playing("live_sand"), "indoors: no sand")
    IsIndoors = function() return false end
    L.Poll()
    check(H.Playing("live_sand"), "outdoors again: sand")
    UnitIsDeadOrGhost = function() return true end
    L.Poll()
    check(not H.Playing("live_sand"), "dead: no sand")
    UnitIsDeadOrGhost = function() return false end
    -- Poll each 0.1 s leaves a playing voice alone (no restart)
    L.Poll()
    local voices = H.ActiveVoices()
    local before
    for _, v in ipairs(voices) do if v.id == "live_sand" then before = v end end
    check(before, "sand plays")
    cues = {}
    play(1)
    local n = 0
    for _ = 1, 50 do L.Poll() end
    eq(#cues, n, "fifty polls start no gust of their own")
end

-- Heavy rain: taps to WoW Helper, denser when heavier; thunder rolls, each one cue, far or near
do
    sky = { 1, 0.9 }; L.ReadWeather()
    L.Poll()
    check(H.Playing("live_rain") and H.Playing("live_thunder") and not H.Playing("live_sand"), "heavy rain: rain and thunder, the sand gone")
    cues = {}
    play(180)
    local rolls, lo, hi = count("thunder")
    check(rolls >= 2 and rolls <= 9, "thunder rolls now and then in three minutes: " .. rolls)
    check(lo >= 2 and hi <= 4, "far and near rolls (intensity " .. lo .. "-" .. hi .. ")")
    for _, c in ipairs(cues) do
        if c.key == "thunder" then check(c.feel == "thunder", "a roll's cue: the Thunder feel") end
    end
    local heavy = count("rain")
    check(heavy > 100, "heavy rain: many taps in three minutes (" .. heavy .. ")")
    sky = { 1, 0.1 }; L.ReadWeather()
    cues = {}
    play(180)
    local light = count("rain")
    check(light > 20 and light < heavy, "light rain: fewer (" .. light .. " vs " .. heavy .. ")")
    check(count("thunder") == 0, "light rain: no thunder")
    check(not H.Playing("live_thunder"), "its voice gone")
end

-- Snow: flakes far apart, each a cue; clear: nothing plays, nothing is sent
do
    sky = { 2, 0.5 }; L.ReadWeather()
    L.Poll()
    check(H.Playing("live_snow") and not H.Playing("live_rain"), "snow")
    cues = {}
    play(60)
    local flakes = count("snow")
    check(flakes >= 10 and flakes <= 45, "flakes in a minute: " .. flakes)
    sky = { 0, 0 }; L.ReadWeather()
    L.Poll()
    for _, k in ipairs(L.WEATHER_KEYS) do check(not H.Playing("live_" .. k), "clear: no " .. k) end
    cues = {}
    play(30)
    eq(#cues, 0, "clear: nothing sent")
end

-- The weather switched off in Rumble: nothing felt, nothing sent, while the storm goes on
do
    sky = { 3, 0.8 }; L.ReadWeather()
    L.EventSettings("sand").on = false
    L.Poll()
    check(not H.Playing("live_sand"), "Sand off: quiet in the storm")
    cues = {}
    play(30)
    eq(#cues, 0, "and nothing sent")
    L.EventSettings("sand").on = true
    L.Poll()
    check(H.Playing("live_sand"), "on again: the storm")
end

C.Moment = moment
C_Weather = nil
if T.failures > 0 then
    io.write(T.failures .. " of " .. T.checks .. " checks failed" .. "\n")
    os.exit(1)
end
io.write("PASS: weather: " .. T.checks .. " checks (kinds, the trace, sand gusts, thunder rolls, rain and snow taps as HD cues)\n")
