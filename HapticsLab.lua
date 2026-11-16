-- Haptics Lab (Beta): the feel library, the probes, the beta events and the
-- light bar effects, on the mixer in Haptics.lua. The Beta tab (BetaPage.lua)
-- shows them. Probe answers are kept in GamepadCompanionHapticsDB.probes so
-- they can be read back later (and a report copied from the tab).
local _, ns = ...
local H = ns.Haptics
local L = {}
ns.HapticsLab = L

local min, max, floor, sin, pi = math.min, math.max, math.floor, math.sin, math.pi
local function Now() return GetTime and GetTime() or 0 end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local ICONS = "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_"

---------------------------------------------------------------------------
-- The library: rhythms of pulses. Through the game the pad is a drum (probes,
-- 2026-11-16, docs/HAPTICS.md): a pulse of 50 ms or more is always felt,
-- shorter ones only sometimes; fast on / off stays countable; a strength
-- changing while it runs is smoothed away. So every feel is pulses, each
-- with its own time, length (50 ms or more), strength and side. Subtle =
-- 50 ms and soft.
---------------------------------------------------------------------------
L.GROUPS = { "Taps", "Doubles", "Rolls", "Impacts", "Motion", "Life", "Signals", "Extremes" }

-- One pulse: t and length in seconds, strength 0-1, side -1 left .. 1 right
local function P(t, len, s, side) return { t, len, s, side or 0 } end

-- n pulses from t0, gap apart, strength and side going from a to b
local function Row(n, t0, gap, len, s0, s1, side0, side1)
    local list = {}
    for i = 0, n - 1 do
        local k = n > 1 and i / (n - 1) or 0
        list[#list + 1] = P(t0 + i * gap, len, s0 + (s1 - s0) * k, (side0 or 0) + ((side1 or side0 or 0) - (side0 or 0)) * k)
    end
    return list
end

-- n pulses whose gaps go from gap0 to gap1 (speeding up or slowing down)
local function Accel(n, gap0, gap1, len, s0, s1, side)
    local list, t = {}, 0
    for i = 0, n - 1 do
        local k = n > 1 and i / (n - 1) or 0
        list[#list + 1] = P(t, len, s0 + (s1 - s0) * k, side)
        t = t + gap0 + (gap1 - gap0) * k
    end
    return list
end

local function Join(...)
    local list = {}
    for _, part in ipairs({ ... }) do for _, p in ipairs(part) do list[#list + 1] = p end end
    return list
end

local function Pulses(list, extra)
    local f = extra or {}
    f.pulses = list
    return f
end

local LIB = {
    -- Taps: one pulse, 50 ms or more; soft is subtle
    { "dust", "Dust", "Taps", "micro", Pulses({ P(0, 0.05, 0.15) }) },
    { "pin", "Pin", "Taps", "micro", Pulses({ P(0, 0.05, 0.25) }) },
    { "graze", "Graze", "Taps", "tick", Pulses({ P(0, 0.05, 0.35) }) },
    { "tap", "Tap", "Taps", "tick", Pulses({ P(0, 0.06, 0.6) }) },
    { "knock", "Knock", "Taps", "impact", Pulses({ P(0, 0.07, 1) }, { duck = { amount = 0.7, time = 0.12 } }) },
    { "feather", "Feather", "Taps", "micro", Pulses({ P(0, 0.06, 0.25, 0.4) }) },
    { "clickL", "Click left", "Taps", "click", Pulses({ P(0, 0.05, 0.5, -1) }) },
    { "clickR", "Click right", "Taps", "click", Pulses({ P(0, 0.05, 0.5, 1) }) },
    { "flick", "Flick", "Taps", "click", Pulses({ P(0, 0.05, 0.8), P(0.1, 0.05, 0.2) }) },
    -- Doubles: two or three
    { "notch", "Notch", "Doubles", "double", Pulses({ P(0, 0.05, 0.5), P(0.11, 0.05, 0.5) }) },
    { "nudge", "Nudge", "Doubles", "double", Pulses({ P(0, 0.05, 0.25), P(0.12, 0.05, 0.25) }) },
    { "ticktock", "Tick-tock", "Doubles", "click", Pulses({ P(0, 0.05, 0.4, -1), P(0.25, 0.05, 0.4, 1) }) },
    { "echo", "Echo", "Doubles", "fade", Pulses({ P(0, 0.06, 0.7), P(0.16, 0.05, 0.3), P(0.3, 0.05, 0.12) }) },
    { "triple", "Triple", "Doubles", "triple", Pulses(Row(3, 0, 0.1, 0.05, 0.4, 0.4)) },
    { "deny", "Deny", "Doubles", "hex", Pulses({ P(0, 0.08, 0.7, -1), P(0.16, 0.08, 0.7, -1) }) },
    -- Rolls: many, evenly or speeding up
    { "ratchet", "Ratchet", "Rolls", "gears", Pulses(Row(8, 0, 0.12, 0.05, 0.4, 0.4)) },
    { "dial", "Dial", "Rolls", "click", Pulses(Row(6, 0, 0.2, 0.05, 0.25, 0.25)) },
    { "cogs", "Cogs", "Rolls", "whirl", Pulses((function()
        local list = {}
        for i = 0, 7 do list[#list + 1] = P(i * 0.15, 0.05, 0.4, i % 2 == 0 and -1 or 1) end
        return list
    end)()) },
    { "windup", "Wind-up", "Rolls", "draw", Pulses(Join(Accel(10, 0.35, 0.08, 0.05, 0.15, 0.6), { P(2.0, 0.1, 1) })) },
    { "winddown", "Wind-down", "Rolls", "fade", Pulses(Join({ P(0, 0.1, 1) }, (function()
        local list = {}
        for _, p in ipairs(Accel(9, 0.08, 0.35, 0.05, 0.6, 0.12)) do list[#list + 1] = P(p[1] + 0.2, p[2], p[3], p[4]) end
        return list
    end)())) },
    { "speedup", "Speeding up", "Rolls", "charge", Pulses(Accel(10, 0.3, 0.09, 0.05, 0.4, 0.4)) },
    { "rain", "Rain", "Rolls", "frost", Pulses({ P(0, 0.05, 0.2, -0.6), P(0.17, 0.05, 0.12, 0.7), P(0.41, 0.05, 0.25, 0.1),
        P(0.58, 0.05, 0.15, -0.9), P(0.86, 0.05, 0.2, 0.5), P(1.02, 0.05, 0.1, -0.2), P(1.27, 0.05, 0.22, 0.9) },
        { loop = true, length = 1.45 }) },
    { "crackle", "Crackle", "Rolls", "kindle", Pulses({ P(0, 0.05, 0.5, -0.3), P(0.09, 0.05, 0.3, 0.4), P(0.24, 0.05, 0.6, 0),
        P(0.31, 0.05, 0.25, -0.8), P(0.47, 0.05, 0.45, 0.6), P(0.6, 0.05, 0.3, -0.2), P(0.69, 0.05, 0.55, 0.3) }) },
    -- Impacts: a hit and what follows it
    { "thud", "Thud", "Impacts", "slam", Pulses({ P(0, 0.09, 1, -0.6), P(0.15, 0.05, 0.25, -0.6) },
        { duck = { amount = 0.6, time = 0.15 } }) },
    { "boom", "Boom", "Impacts", "burst", Pulses({ P(0, 0.12, 1), P(0.2, 0.06, 0.45), P(0.36, 0.05, 0.2), P(0.55, 0.05, 0.1) },
        { duck = { amount = 0.8, time = 0.3 } }) },
    { "shockwave", "Shockwave", "Impacts", "slam", Pulses({ P(0, 0.08, 1), P(0.14, 0.05, 0.5, -1), P(0.14, 0.05, 0.5, 1),
        P(0.28, 0.05, 0.2, -1), P(0.28, 0.05, 0.2, 1) }) },
    { "dive", "Dive", "Impacts", "fade", Pulses(Row(5, 0, 0.13, 0.06, 0.8, 0.1)) },
    { "swell", "Swell", "Impacts", "rise", Pulses(Row(5, 0, 0.15, 0.06, 0.12, 0.85)) },
    { "splash", "Splash", "Impacts", "bubble", Pulses({ P(0, 0.07, 0.9), P(0.13, 0.05, 0.25, -0.8), P(0.21, 0.05, 0.2, 0.7),
        P(0.33, 0.05, 0.15, -0.3), P(0.47, 0.05, 0.1, 0.5) }) },
    { "gravel", "Gravel", "Impacts", "pickaxe", Pulses({ P(0, 0.05, 0.5, -0.4), P(0.1, 0.05, 0.35, 0.3), P(0.17, 0.06, 0.45, -0.1),
        P(0.3, 0.05, 0.3, 0.5), P(0.38, 0.05, 0.5, -0.6), P(0.5, 0.05, 0.3, 0.2), P(0.6, 0.06, 0.4, -0.3) }) },
    { "tremor", "Tremor", "Impacts", "shadow", Pulses({ P(0, 0.06, 0.2, -0.5), P(0.22, 0.05, 0.15, 0.4), P(0.38, 0.06, 0.25, -0.1),
        P(0.62, 0.05, 0.15, 0.6), P(0.8, 0.06, 0.2, -0.4), P(1.05, 0.05, 0.12, 0.2) }) },
    -- Motion: pulses moving across the pad
    { "passLR", "Pass left-right", "Motion", "sweep", Pulses(Row(4, 0, 0.1, 0.06, 0.6, 0.6, -1, 1)) },
    { "passRL", "Pass right-left", "Motion", "sweep", Pulses(Row(4, 0, 0.1, 0.06, 0.6, 0.6, 1, -1)) },
    { "arrow", "Arrow", "Motion", "string", Pulses(Join(Row(3, 0, 0.07, 0.05, 0.5, 0.7, -1, 0.3), { P(0.24, 0.07, 0.9, 1) })) },
    { "whoosh", "Whoosh", "Motion", "toss", Pulses(Row(5, 0, 0.09, 0.05, 0.15, 0.5, -1, 1)) },
    { "orbit", "Orbit", "Motion", "whirl", Pulses({ P(0, 0.06, 0.35, -1), P(0.2, 0.06, 0.35, 0), P(0.4, 0.06, 0.35, 1),
        P(0.6, 0.06, 0.35, 0) }, { loop = true, length = 0.8 }) },
    { "pingpong", "Ping-pong", "Motion", "arcane", Pulses((function()
        local list = {}
        for i = 0, 5 do list[#list + 1] = P(i * 0.18, 0.06, 0.5, i % 2 == 0 and -1 or 1) end
        return list
    end)()) },
    -- Life: rhythms that loop
    { "heart60", "Heart 60", "Life", "heart", Pulses({ P(0, 0.06, 0.8, -0.3), P(0.2, 0.055, 0.45, -0.3) },
        { loop = true, length = 1 }) },
    { "heart120", "Heart 120", "Life", "heart", Pulses({ P(0, 0.06, 0.8, -0.3), P(0.15, 0.055, 0.45, -0.3) },
        { loop = true, length = 0.5 }) },
    { "gallop", "Gallop", "Life", "charge", Pulses({ P(0, 0.05, 0.5, -0.3), P(0.12, 0.05, 0.35, 0), P(0.24, 0.06, 0.6, 0.3) },
        { loop = true, length = 0.6 }) },
    { "steps", "Footsteps", "Life", "tick", Pulses({ P(0, 0.05, 0.3, -1), P(0.45, 0.05, 0.3, 1) }, { loop = true, length = 0.9 }) },
    { "purr", "Purr", "Life", "purr", Pulses({ P(0, 0.05, 0.15), P(0.25, 0.05, 0.1) }, { loop = true, length = 0.5 }) },
    { "breath", "Breath", "Life", "mend", Pulses({ P(0, 0.06, 0.08), P(0.4, 0.06, 0.12), P(0.8, 0.06, 0.08),
        P(1.8, 0.06, 0.06), P(2.2, 0.06, 0.04) }, { loop = true, length = 3.2 }) },
    -- Signals: short and meaningful
    { "coin", "Coin", "Signals", "click", Pulses({ P(0, 0.05, 0.4, 1), P(0.1, 0.05, 0.7, 1) }) },
    { "chime", "Chime", "Signals", "radiance", Pulses(Row(3, 0, 0.14, 0.05, 0.25, 0.7, 1, 1)) },
    { "ready", "Ready", "Signals", "micro", Pulses({ P(0, 0.05, 0.4, 1) }) },
    { "alert", "Alert", "Signals", "hex", Pulses(Row(3, 0, 0.12, 0.06, 0.7, 0.7)) },
    { "whisper", "Whisper", "Signals", "micro", Pulses({ P(0, 0.05, 0.05) }) },
    { "murmur", "Murmur", "Signals", "purr", Pulses({ P(0, 0.05, 0.1), P(0.15, 0.05, 0.08) }) },
    -- Extremes: the limits
    { "max", "Full both", "Extremes", "impact", Pulses({ P(0, 0.5, 1) }) },
    { "maxL", "Full left", "Extremes", "bash", Pulses({ P(0, 0.5, 1, -1) }) },
    { "maxR", "Full right", "Extremes", "stab", Pulses({ P(0, 0.5, 1, 1) }) },
    { "ladder", "Ladder", "Extremes", "rise", Pulses(Row(10, 0, 0.25, 0.08, 0.1, 1)) },
    { "closest", "Closest pulses", "Extremes", "static", Pulses(Row(16, 0, 0.09, 0.05, 0.5, 0.5)) },
}
for _, e in ipairs(LIB) do
    local feel = e[5]
    feel.label, feel.group, feel.icon = e[2], e[3], ICONS .. e[4]
    H.AddLibrary(e[1], feel)
end

---------------------------------------------------------------------------
-- Beta feels in Rumble's pattern grid (while the Beta engine is on)
---------------------------------------------------------------------------
function L.RegisterInRumble()
    local V = ns.Rumble
    if not (V and V.AddFeel) then return end
    for _, feel in ipairs(H.AllFeels()) do V.AddFeel("x_" .. feel.key, feel) end
end

---------------------------------------------------------------------------
-- Probes: what the pad and the client really do. Each step plays raw (no
-- mixer, no calibration), timed per frame, then asks.
---------------------------------------------------------------------------
local seq = CreateFrame("Frame")
seq:Hide()
local seqList, seqStart, seqIndex, seqDone

local ramp   -- (the calibration ramp, below: one at a time)
L.measure = {}   -- (tap lengths of the run playing: Taps fills it)

-- The motors and light back to the mixer
local function Release()
    H.hold = false
    if L.ApplyBaseLight then L.ApplyBaseLight() end
end

local function Run(list, onDone)
    if ramp:IsShown() then ramp:Hide() end
    H.Stop()
    H.hold = true
    wipe(L.measure)
    seqList, seqStart, seqIndex, seqDone = list, Now(), 1, onDone
    seq:Show()
end
L.Run = Run

function L.Halt()
    seq:Hide()
    seqList, seqDone = nil, nil
    H.Silence()
    H.LedClear()
    Release()
end

seq:SetScript("OnUpdate", function()
    if not seqList then return seq:Hide() end
    local t = Now() - seqStart
    while seqList[seqIndex] and seqList[seqIndex][1] <= t do
        seqList[seqIndex][2](t)
        seqIndex = seqIndex + 1
    end
    if not seqList[seqIndex] then
        seq:Hide()
        local done = seqDone
        seqList, seqDone = nil, nil
        H.Silence()
        Release()
        if done then done() end
    end
end)

local function both(v) return function() H.Send("Low", v); H.Send("High", v) end end
local function stop() H.Silence() end
local function one(kind, v) return function() H.Send(kind, v) end end

-- A square wave on a motor: hz, for seconds, at v
local function Square(list, at, kind, hz, seconds, v)
    local half = 0.5 / hz
    local n = floor(seconds / half)
    for i = 0, n - 1 do
        list[#list + 1] = { at + i * half, one(kind, i % 2 == 0 and v or 0) }
    end
    list[#list + 1] = { at + n * half, stop }
end

-- Taps: n of them, 0.7 s apart, each ms long at v. Their real lengths are
-- measured (sent and stopped on frames: at 100 fps a 16 ms tap lasts 10 or
-- 20 ms), kept with the answer.
local measure = L.measure
-- kick: the first kick ms at full, then v (overdrive)
local function Taps(ms, v, n, kick)
    return function()
        local list = {}
        for i = 0, (n or 5) - 1 do
            local at = i * 0.7
            list[#list + 1] = { at, function()
                measure.on = Now()
                H.Send("Low", kick and 1 or v or 1)
                H.Send("High", kick and 1 or v or 1)
            end }
            if kick then list[#list + 1] = { at + kick / 1000, both(v or 1) } end
            list[#list + 1] = { at + ms / 1000, function()
                measure[#measure + 1] = (Now() - (measure.on or Now())) * 1000
                stop()
            end }
        end
        return list
    end
end

-- The last run's tap lengths, "10-20 ms" (nil: none measured)
function L.Measured()
    if #measure == 0 then return nil end
    local lo, hi = math.huge, 0
    for _, d in ipairs(measure) do lo, hi = min(lo, d), max(hi, d) end
    lo, hi = floor(lo + 0.5), floor(hi + 0.5)
    return lo == hi and (lo .. " ms") or (lo .. "-" .. hi .. " ms")
end

local OUT_OF_5 = { "5", "3-4", "1-2", "0" }

local function Light(r, g, b)
    return function() return { { 0, function() H.LedSend(r, g, b) end }, { 1.2, function() H.LedClear() end } } end
end

L.PROBES = {
    { key = "tap2", label = "Shortest tap", how = "Play, count the taps. Then Cap 60 fps and again", ask = "5 taps: how many felt?", answers = OUT_OF_5, steps = {
        { "16 ms", Taps(16) }, { "20 ms", Taps(20) }, { "25 ms", Taps(25) }, { "33 ms", Taps(33) },
        { "40 ms", Taps(40) }, { "50 ms", Taps(50) }, { "75 ms", Taps(75) } } },
    { key = "subtle", label = "Soft short taps", how = "Play, count the taps", ask = "5 taps: how many felt?", answers = OUT_OF_5, steps = {
        { "50 ms at 60%", Taps(50, 0.6) }, { "50 ms at 35%", Taps(50, 0.35) },
        { "33 ms at 60%", Taps(33, 0.6) }, { "33 ms at 35%", Taps(33, 0.35) },
        { "75 ms at 35%", Taps(75, 0.35) }, { "75 ms at 20%", Taps(75, 0.2) } } },
    { key = "hold", label = "Hold, sent once", how = "Sent once, then nothing for 3 s", ask = "How long?", answers = { "All 3 s", "Faded", "Nothing" }, steps = {
        { "60%, 3 s", function() return { { 0, both(0.6) }, { 3, stop } } end },
        { "100%, 3 s", function() return { { 0, both(1) }, { 3, stop } } end } } },
    { key = "rate2", label = "Update rate", how = "Left grip switched on and off, faster each step", ask = "Feels like?",
        answers = { "Separate pulses", "Rough buzz", "Steady, no flicker", "Nothing" },
        steps = (function()
            local list = {}
            for _, hz in ipairs({ 5, 10, 20, 30, 45, 60 }) do
                list[#list + 1] = { hz .. " Hz, left", function()
                    local l = {}
                    Square(l, 0, "Low", hz, 1.5, 1)
                    return l
                end }
            end
            return list
        end)() },
    { key = "ends", label = "Stopping", how = "On for 0.5 s, then stopped", ask = "Tail?", answers = { "Clean", "Tail" }, steps = {
        { "Set to 0", function() return { { 0, both(1) }, { 0.5, both(0) }, { 1, stop } } end },
        { "Stop call", function() return { { 0, both(1) }, { 0.5, stop } } end } } },
    { key = "channels", label = "Each channel", how = "One channel for 1 s. Felt nothing: Nothing", ask = "Where?",
        answers = { "Left grip", "Right grip", "Nothing" }, steps = {
        { "Low", function() return { { 0, one("Low", 1) }, { 1, stop } } end },
        { "High", function() return { { 0, one("High", 1) }, { 1, stop } } end } } },
    { key = "low", label = "Weak levels", how = "One weak level", ask = "Felt?", answers = { "Felt", "Not felt" }, steps = (function()
        local list = {}
        for _, side in ipairs({ "Low", "High" }) do
            for _, v in ipairs({ 0.05, 0.1, 0.2, 0.35, 0.5 }) do
                list[#list + 1] = { side .. " " .. floor(v * 100) .. "%", function()
                    return { { 0, one(side, v) }, { 0.6, stop } }
                end }
            end
        end
        return list
    end)() },
    { key = "top", label = "Top end", how = "Three steps: 60, 80, 100%", ask = "Stronger each time?", answers = { "Yes", "Top same", "No" }, steps = {
        { "60, 80, 100%", function() return { { 0, both(0.6) }, { 0.5, stop }, { 0.9, both(0.8) }, { 1.4, stop },
            { 1.8, both(1) }, { 2.3, stop } } end } } },
    -- (2026-11-16: a 40 ms tap at 40% was mostly missed, the same with 15 ms
    -- at full first was felt: does a kick save short soft taps?)
    { key = "kick2", label = "Overdrive", how = "Play, count the taps. Kicked: 15 ms at full first",
        ask = "5 taps: how many felt?", answers = OUT_OF_5, steps = {
        { "25 ms at 40%", Taps(25, 0.4) }, { "25 ms kicked", Taps(25, 0.4, 5, 15) },
        { "33 ms at 40%", Taps(33, 0.4) }, { "33 ms kicked", Taps(33, 0.4, 5, 15) },
        { "40 ms at 25%", Taps(40, 0.25) }, { "40 ms kicked", Taps(40, 0.25, 5, 15) },
        { "33 ms, 8 ms kick", Taps(33, 0.25, 5, 8) } } },
    -- (switching on and off is felt as countable pulses even at 60 Hz: does
    -- a level going up and down, never off, feel like a texture?)
    { key = "wobble", label = "Wobble", how = "Left grip, 30% to 100% and back, never off",
        ask = "Feels like?", answers = { "Countable pulses", "Rough texture", "Steady", "Nothing" },
        steps = (function()
            local list = {}
            for _, hz in ipairs({ 3, 6, 10, 15, 25 }) do
                list[#list + 1] = { hz .. " Hz", function()
                    local l, step = {}, 0.01
                    for t = 0, 2, step do
                        local v = 0.3 + 0.7 * (0.5 - 0.5 * math.cos(2 * pi * hz * t))
                        l[#l + 1] = { t, one("Low", v) }
                    end
                    l[#l + 1] = { 2.01, stop }
                    return l
                end }
            end
            return list
        end)() },
    { key = "sides", label = "Left vs right", how = "Left grip, then right grip, same level", ask = "Which is stronger?", answers = { "Left", "Same", "Right" }, steps = {
        { "Both 50%", function() return { { 0, one("Low", 0.5) }, { 0.6, stop }, { 1, one("High", 0.5) },
            { 1.6, stop } } end },
        { "Both 100%", function() return { { 0, one("Low", 1) }, { 0.6, stop }, { 1, one("High", 1) },
            { 1.6, stop } } end } } },
    { key = "light", label = "Light bar", how = "Watch the light bar", ask = "Seen?", answers = { "Yes", "No" }, steps = {
        { "Red", Light(1, 0, 0) }, { "Green", Light(0, 1, 0) }, { "Blue", Light(0, 0, 1) } } },
}

-- An answer to a probe's step (saved with the date)
local function FPS()
    return GetFramerate and floor((GetFramerate() or 0) + 0.5) or 0
end

-- An answer to a probe's step (saved with the date), and a log line with the
-- frame rate and the taps' real lengths, so runs at 60 and 100 fps compare
function L.Answer(probe, step, answer)
    local db = H.DB().probes
    db[probe.key] = db[probe.key] or {}
    local p = db[probe.key]
    p[step] = answer
    p.at = date and date("%Y-%m-%d %H:%M") or ""
    db.log = db.log or {}
    local real = p.lengths and p.lengths[step]
    local s = probe.steps[step]
    table.insert(db.log, string.format("%s %s: %s = %s%s @%d fps", p.at, probe.label, s and s[1] or step, answer,
        real and (" (real " .. real .. ")") or "", FPS()))
    while #db.log > 300 do table.remove(db.log, 1) end
end

-- 60 fps for the probes: the game's frame cap set, then put back
function L.FpsCap(on)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if not (get and set) then return false end
    local db = H.DB()
    if on then
        if db.savedMaxFPS == nil then db.savedMaxFPS = get("maxFPS") or "0" end
        pcall(set, "maxFPS", "60")
    elseif db.savedMaxFPS ~= nil then
        pcall(set, "maxFPS", db.savedMaxFPS)
        db.savedMaxFPS = nil
    end
    return true
end

function L.FpsCapped() return H.DB().savedMaxFPS ~= nil end

-- The real tap lengths of a probe's step (after it played)
function L.KeepMeasured(probe, step)
    local m = L.Measured()
    if not m then return end
    local db = H.DB().probes
    db[probe.key] = db[probe.key] or {}
    db[probe.key].lengths = db[probe.key].lengths or {}
    db[probe.key].lengths[step] = m
end

function L.Answers(probe)
    return H.DB().probes[probe.key] or {}
end

-- Facts read without asking: the CVar, battery, pad style
function L.Facts()
    local cvar = call(C_CVar and C_CVar.GetCVar or GetCVar, "GamePadVibrationStrength")
    local power = C_GamePad and call(C_GamePad.GetPowerLevel)
    local state = C_GamePad and call(C_GamePad.GetDeviceMappedState, call(C_GamePad.GetActiveDeviceID))
    return {
        { "Vibration CVar", cvar ~= nil and tostring(cvar) or "?" },
        { "Battery", power ~= nil and tostring(power) or "?" },
        { "Pad style", type(state) == "table" and tostring(state.labelStyle) or "?" },
        { "Frame rate", GetFramerate and string.format("%.0f fps (faster steps blur)", GetFramerate() or 0) or "?" },
        { "SetVibration", tostring(C_GamePad ~= nil and C_GamePad.SetVibration ~= nil) },
        { "SetLedColor", tostring(C_GamePad ~= nil and C_GamePad.SetLedColor ~= nil) },
    }
end

-- Everything known, as text to paste back
function L.Report()
    local lines = { "GPC haptics probes " .. (date and date("%Y-%m-%d") or "") }
    for _, f in ipairs(L.Facts()) do lines[#lines + 1] = f[1] .. ": " .. f[2] end
    local db = H.DB()
    lines[#lines + 1] = string.format("Calibration: floor %.2f / %.2f, ceiling %.2f / %.2f, gamma %.2f / %.2f",
        db.floor[1], db.floor[2], db.ceil[1], db.ceil[2], db.gamma[1], db.gamma[2])
    for _, p in ipairs(L.PROBES) do
        local a = L.Answers(p)
        local parts = {}
        for i, step in ipairs(p.steps) do
            local real = a.lengths and a.lengths[i]
            parts[#parts + 1] = step[1] .. "=" .. (a[i] or "-") .. (real and (" (" .. real .. ")") or "")
        end
        lines[#lines + 1] = p.label .. ": " .. table.concat(parts, ", ")
    end
    local parts = {}
    for _, t in ipairs(L.TRIGGER_TESTS) do
        local a = L.TriggerAnswers(t.key)
        parts[#parts + 1] = string.format("%s=L2 %s / R2 %s", t.label, a.L2 or "-", a.R2 or "-")
    end
    lines[#lines + 1] = "Trigger test: " .. table.concat(parts, ", ")
    local db2 = H.DB()
    if db2.landings and #db2.landings > 0 then
        lines[#lines + 1] = "Last landings (s in the air): " .. table.concat(db2.landings, ", ")
    end
    for key, cal in pairs(db2.stepSync or {}) do
        lines[#lines + 1] = string.format("Steps %s: %.2f/s at %.1f yd/s, first after %.2f s (%d taps)", key,
            cal.rate or 0, cal.speed or 0, cal.offset or 0, cal.taps or 0)
    end
    local log = H.DB().probes.log
    if log and #log > 0 then
        lines[#lines + 1] = "Log:"
        for _, line in ipairs(log) do lines[#lines + 1] = line end
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Calibration: a side's level rising slowly; the player says when felt and
-- when it stops getting stronger
---------------------------------------------------------------------------
ramp = CreateFrame("Frame")
ramp:Hide()
L.ramp = { side = 1, start = 0, seconds = 8, level = 0 }

function L.StartRamp(side, from, seconds)
    if seq:IsShown() then seq:Hide(); seqList, seqDone = nil, nil end
    H.Stop()
    H.hold = true
    local r = L.ramp
    r.side, r.start, r.seconds, r.from, r.level = side, Now(), seconds or 8, from or 0, from or 0
    ramp:Show()
end

function L.StopRamp()
    ramp:Hide()
    H.Silence()
    Release()
    return L.ramp.level
end

function L.Ramping() return ramp:IsShown() end

ramp:SetScript("OnUpdate", function()
    local r = L.ramp
    local t = (Now() - r.start) / r.seconds
    if t >= 1 then
        L.StopRamp()
        if L.onRampEnd then L.onRampEnd() end
        return
    end
    r.level = r.from + (1 - r.from) * t
    H.Send(r.side == 1 and "Low" or "High", r.level)
    H.Send(r.side == 1 and "High" or "Low", 0)
end)

---------------------------------------------------------------------------
-- The triggers: L2 / R2 depth (0-1), and the trigger test: each squeeze of
-- L2 or R2 plays the next variation on that side, the player marks each
-- (in the trigger, in the grip, nothing). Answers in probes.triggerTest.
---------------------------------------------------------------------------
function L.TriggerAxes()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return nil end
    local okId, id = pcall(C_GamePad.GetActiveDeviceID)
    local ok, state = pcall(C_GamePad.GetDeviceMappedState, okId and id or nil)
    if not (ok and type(state) == "table" and type(state.axes) == "table") then return nil end
    local li, ri
    if C_GamePad.AxisIndexToConfigName then
        for i = 1, #state.axes do
            local okN, name = pcall(C_GamePad.AxisIndexToConfigName, i - 1)
            if okN and name == "LTrigger" then li = i elseif okN and name == "RTrigger" then ri = i end
        end
    end
    li, ri = li or 5, ri or 6
    local l, r = state.axes[li], state.axes[ri]
    if type(l) ~= "number" or type(r) ~= "number" then return nil end
    -- (some pads rest at -1)
    if l < 0 or r < 0 then l, r = (l + 1) / 2, (r + 1) / 2 end
    return max(0, min(1, l)), max(0, min(1, r))
end

-- Each variation: where it plays (trigger, grip, both) and its level t
-- seconds in (depth: how far the trigger is pressed; nil: done)
L.TRIGGER_TESTS = {
    { key = "full", label = "Trigger, full, 0.5 s", on = "trigger", fn = function(t) return t < 0.5 and 1 or nil end },
    { key = "held", label = "Trigger, while you hold", on = "trigger",
        fn = function(_, depth, held) return held and max(0.15, depth) or nil end },
    { key = "tap", label = "Trigger, one tap", on = "trigger", fn = function(t) return t < 0.06 and 1 or nil end },
    { key = "pulses", label = "Trigger, pulses", on = "trigger",
        fn = function(t) if t >= 1.25 then return nil end return (t % 0.25) < 0.1 and 1 or 0 end },
    { key = "soft", label = "Trigger, soft 30%", on = "trigger", fn = function(t) return t < 0.6 and 0.3 or nil end },
    { key = "grip", label = "Grip only (check)", on = "grip", fn = function(t) return t < 0.3 and 0.6 or nil end },
    { key = "both", label = "Trigger and grip", on = "both", fn = function(t) return t < 0.5 and 1 or nil end },
}
L.TRIGGER_ANSWERS = { "?", "Trigger", "Grip", "Nothing" }

local tt = { on = false, index = { 0, 0 }, down = { false, false }, active = {}, depth = { 0, 0 } }
L.trigger = tt
local ttFrame = CreateFrame("Frame")
ttFrame:Hide()

local CHANNELS = { { trigger = "LTrigger", grip = "Low" }, { trigger = "RTrigger", grip = "High" } }

local function TriggerQuiet()
    for _, c in ipairs(CHANNELS) do H.Send(c.trigger, 0); H.Send(c.grip, 0) end
    H.Silence()
end

function L.TriggerTest(on)
    if on then
        L.Halt()
        if ramp:IsShown() then L.StopRamp() end
        H.Stop()
        H.hold = true
        tt.on, tt.index, tt.down, tt.active = true, { 0, 0 }, { false, false }, {}
        ttFrame:Show()
    else
        ttFrame:Hide()
        tt.on, tt.active = false, {}
        TriggerQuiet()
        Release()
    end
end

function L.TriggerAnswer(key, side, answer)
    local db = H.DB().probes
    db.triggerTest = db.triggerTest or {}
    db.triggerTest[key] = db.triggerTest[key] or {}
    db.triggerTest[key][side == 1 and "L2" or "R2"] = answer
end

function L.TriggerAnswers(key)
    local db = H.DB().probes
    return db.triggerTest and db.triggerTest[key] or {}
end

ttFrame:SetScript("OnUpdate", function()
    local l, r = L.TriggerAxes()
    if not l then tt.noAxes = true; return end
    tt.noAxes = false
    tt.depth[1], tt.depth[2] = l, r
    local now = Now()
    for side = 1, 2 do
        local depth = tt.depth[side]
        local held = depth > 0.15
        -- A new squeeze: the next variation on this side
        if not tt.down[side] and depth > 0.5 then
            tt.down[side] = true
            tt.index[side] = tt.index[side] % #L.TRIGGER_TESTS + 1
            tt.active[side] = { test = L.TRIGGER_TESTS[tt.index[side]], start = now }
            if L.onTrigger then L.onTrigger(side, tt.index[side]) end
        elseif tt.down[side] and depth < 0.2 then
            tt.down[side] = false
        end
        local a = tt.active[side]
        local c = CHANNELS[side]
        if a then
            local v = a.test.fn(now - a.start, depth, held and tt.down[side])
            local on = a.test.on
            local trig = (on == "trigger" or on == "both") and (v or 0) or 0
            local grip = (on == "grip" or on == "both") and (v or 0) or 0
            H.Send(c.trigger, trig)
            H.Send(c.grip, grip)
            if v == nil then tt.active[side] = nil end
        end
    end
end)

---------------------------------------------------------------------------
-- Beta events: more of the game felt (played on the mixer at Rumble's
-- strength, while the Beta engine is on)
---------------------------------------------------------------------------
L.EVENT_GROUPS = { "Combat", "Resources", "Moving", "World", "Social", "Living" }
L.EVENTS = {
    { key = "hitTaken", group = "Combat", label = "Hit taken", feel = "thud", on = true },
    { key = "avoid", group = "Combat", label = "Dodge, parry, block", feel = "flick", on = true },
    { key = "kill", group = "Combat", label = "Target killed", feel = "boom", on = true },
    { key = "targetCast", group = "Combat", label = "Enemy casts at you", feel = "tremor", on = false },
    { key = "aggro", group = "Combat", label = "Aggro", feel = "swell", on = false },
    { key = "control", group = "Combat", label = "Lost control", feel = "gravel", on = true },
    { key = "combo", group = "Resources", label = "Combo point", feel = "pin", on = true },
    { key = "comboFull", group = "Resources", label = "Combo points full", feel = "knock", on = true },
    { key = "full", group = "Resources", label = "Rage or energy full", feel = "ready", on = false },
    { key = "oom", group = "Resources", label = "Low mana", feel = "dive", on = true },
    { key = "gcd", group = "Resources", label = "Global cooldown ready", feel = "ready", on = false },
    { key = "uiError", group = "Resources", label = "Error", feel = "deny", on = true },
    { key = "landing", group = "Moving", label = "Landing", feel = "thud", on = true, scaled = true },
    { key = "splash", group = "Moving", label = "Into water", feel = "splash", on = true },
    { key = "mount", group = "Moving", label = "Mount", feel = "swell", on = true },
    { key = "dismount", group = "Moving", label = "Dismount", feel = "thud", on = true },
    { key = "taxi", group = "Moving", label = "Flight path", feel = "whoosh", on = true },
    { key = "footsteps", group = "Moving", label = "Footsteps", feel = "steps", on = false, live = true },
    { key = "riding", group = "Moving", label = "Riding", feel = "gallop", on = false, live = true },
    { key = "loot", group = "World", label = "Loot", feel = "coin", on = true },
    { key = "money", group = "World", label = "Money", feel = "coin", on = false },
    { key = "questAccepted", group = "World", label = "Quest accepted", feel = "notch", on = true },
    { key = "questDone", group = "World", label = "Quest done", feel = "chime", on = true },
    { key = "skillUp", group = "World", label = "Skill up", feel = "pin", on = true },
    { key = "death", group = "World", label = "Death", feel = "dive", on = true },
    { key = "alive", group = "World", label = "Back to life", feel = "swell", on = true },
    { key = "rested", group = "World", label = "Rested", feel = "breath", on = false },
    { key = "whisper", group = "Social", label = "Whisper", feel = "notch", on = true },
    { key = "readyCheck", group = "Social", label = "Ready check", feel = "ratchet", on = true },
    { key = "invite", group = "Social", label = "Invites, duels", feel = "chime", on = true },
    { key = "summon", group = "Social", label = "Summon", feel = "swell", on = true },
    { key = "heartbeat", group = "Living", label = "Heartbeat", feel = "heart60", on = false, live = true },
    { key = "tension", group = "Living", label = "Cast tension", feel = "windup", on = false, live = true },
}
local EVENT = {}
for _, e in ipairs(L.EVENTS) do EVENT[e.key] = e end
L.EVENT = EVENT

function L.EventSettings(key)
    local db = H.DB().events
    local e = EVENT[key]
    local s = db[key]
    if type(s) ~= "table" then
        s = { on = e.on, feel = e.feel }
        db[key] = s
    end
    if not H.Feel(s.feel) then s.feel = e.feel end
    return s
end

local function Strength()
    local V = ns.Rumble
    local ok, s = pcall(function() return V.Settings() end)
    return ok and s and s.intensity or 0.8
end

local lastFire = {}
-- An event: its feel, if on (gain: 0-1 more or less of it)
function L.Fire(key, gain, feel)
    if not H.Engine() then return end
    -- (Rumble off, or Improved Forever: Vibration has the motors: quiet too)
    local V = ns.Rumble
    local okOn, on = pcall(function() return V.Settings().enabled and not V.Other() end)
    if okOn and not on then return end
    local s = L.EventSettings(key)
    if not s.on then return end
    local now = Now()
    if lastFire[key] and now - lastFire[key] < 0.12 then return end
    lastFire[key] = now
    H.Play(feel or s.feel, { voice = "ev_" .. key, gain = Strength() * (gain or 1) })
    if L.onFire then L.onFire(key) end
end

-- Try: as the game would (a live one for a few seconds)
function L.Try(key)
    local s = L.EventSettings(key)
    local e = EVENT[key]
    local feel = H.Feel(s.feel)
    if not feel then return end
    local opts = { voice = "ev_" .. key, gain = Strength() }
    if e.live then
        opts.loop = true
        H.Play(feel, opts)
        C_Timer.After(4, function() H.Stop("ev_" .. key) end)
    else
        H.Play(feel, opts)
    end
end

---------------------------------------------------------------------------
-- Light bar effects
---------------------------------------------------------------------------
L.LIGHTS = {
    { key = "class", label = "Class colour", on = true },
    { key = "school", label = "Cast colour", on = true },
    { key = "lowHp", label = "Low health pulse", on = true },
    { key = "levelUp", label = "Level up", on = true },
    { key = "hit", label = "Hit flash", on = false },
    { key = "kill", label = "Kill flash", on = true },
    { key = "whisper", label = "Whisper flash", on = true },
}
function L.LightOn(key)
    local db = H.DB()
    if not (db.engine and db.light) then return false end
    local v = db.lights[key]
    if v == nil then
        for _, l in ipairs(L.LIGHTS) do if l.key == key then v = l.on end end
    end
    return v == true
end

local SCHOOL = {
    fire = { 1, 0.35, 0 }, frostSpells = { 0.3, 0.6, 1 }, arcaneSpells = { 0.8, 0.4, 1 },
    shadowSpells = { 0.5, 0, 0.8 }, holy = { 1, 0.9, 0.5 }, healing = { 0.3, 1, 0.4 }, nature = { 0.4, 1, 0.2 },
    shots = { 1, 0.8, 0.3 }, travel = { 0.5, 0.8, 1 }, summon = { 0.6, 0, 1 },
}

function L.ApplyBaseLight()
    if L.LightOn("class") then
        local class = UnitClass and select(2, UnitClass("player"))
        local c = class and (RAID_CLASS_COLORS or {})[class]
        local r, g, b = c and c.r or 1, c and c.g or 1, c and c.b or 1
        H.Light("class", function() return r * 0.5, g * 0.5, b * 0.5 end, 0)
    else
        H.LightStop("class")
    end
end

local cast = {}

local function CastLight()
    if not L.LightOn("school") then return end
    local V = ns.Rumble
    local action = V and V.castAction
    local c = SCHOOL[action] or (V and V.castKind ~= "spell" and { 1, 0.7, 0.3 }) or { 1, 1, 1 }
    H.Light("school", function(now)
        if not cast.start then return nil end
        local span = cast.finish - cast.start
        local p = span > 0 and min(1, max(0, (now - cast.start) / span)) or 1
        local k = 0.2 + 0.8 * p
        return c[1] * k, c[2] * k, c[3] * k
    end, 3)
end

---------------------------------------------------------------------------
-- Live voices: heartbeat, footsteps, riding, cast tension
---------------------------------------------------------------------------
local live = { heart = false, hp = nil, moving = false, mounted = false, speed = 0 }

-- A beat every interval seconds (the interval may change as it goes): the
-- seconds since the last beat, and how many beats so far. Pulses are timed in
-- seconds from there, never shorter than PULSE (the pad loses shorter ones).
local PULSE = 0.055
local function Beat(v, now, interval)
    if not v.beatAt or now - v.beatAt >= interval then
        v.beatAt = now
        v.beats = (v.beats or 0) + 1
    end
    return now - v.beatAt, v.beats
end

-- Lub-dub, faster and stronger as health drops
local function Heartbeat(now, v)
    if not live.heart then return nil end
    local danger = live.hp and max(0, min(1, 1 - live.hp / 0.5)) or 0.6
    local period = 60 / (70 + 110 * danger)
    local d = Beat(v, now, period)
    local a = 0.35 + 0.55 * danger
    local dub = max(0.13, 0.25 * period)
    if d < PULSE + 0.005 then return a, a * 0.7 end
    if d >= dub and d < dub + PULSE then return a * 0.65, a * 0.45 end
    return 0, 0
end

-- A step on each side in turn, quicker with speed
-- Footsteps in time with the run: the run's cycle starts when you start
-- moving (PLAYER_STARTED_MOVING), steps come at a rate that grows with speed.
-- Rate and offset per race and sex, walking and running apart, from a sync
-- (squeeze R2 on each footfall, L.StepSync); a guess until then.
local function Model()
    local race = select(3, UnitRace("player")) or 0
    local sex = UnitSex("player") or 0
    return race .. "-" .. sex
end

-- Walking (about 2.5 yd/s) and running (7) are two animations: each its own
-- step rate and timing
local function Band(speed) return speed < 4 and "walk" or "run" end
L.Band = Band
local GUESS = { walk = { rate = 1.8, speed = 2.5, offset = 0.15 }, run = { rate = 2.4, speed = 7, offset = 0.1 } }

-- A gait's sync for this character, or nil
function L.StepCal(band)
    local db = H.DB()
    db.stepSync = db.stepSync or {}
    return db.stepSync[Model() .. "-" .. band]
end

-- Steps per second at a speed, and the first step's time after the start
function L.StepTiming(speed)
    local band = Band(speed)
    local cal = L.StepCal(band)
    local nudge = H.DB().stepNudge or 0
    local synced = cal and cal.rate and cal.speed and cal.speed > 0
    if not synced then cal = GUESS[band] end
    return cal.rate * speed / cal.speed, (cal.offset or 0) + nudge, synced and true or false
end

local function Steps(now, v)
    if not (live.moving and not live.mounted) then return nil end
    local rate, offset = L.StepTiming(max(0.5, live.speed))
    -- (walk to run or back: the other animation starts its cycle now)
    local band = Band(max(0.5, live.speed))
    if v.band and v.band ~= band then live.moveStart, v.phase = now, nil end
    v.band = band
    if not v.phase then
        -- (from the start of the run, though the voice starts a moment later)
        v.phase = ((now - (live.moveStart or now)) - offset) * rate
    else
        v.phase = v.phase + (now - v.at) * rate
    end
    v.at = now
    if v.phase < 0 then return 0, 0 end
    local n = floor(v.phase)
    if (v.phase - n) / rate < PULSE then
        local left = n % 2 == 0
        return left and 0.3 or 0, left and 0 or 0.3
    end
    return 0, 0
end

-- Three hooves, left to right, a stride quicker with speed
local function Gallop(now, v)
    if not (live.moving and live.mounted) then return nil end
    local d = Beat(v, now, max(0.36, 1 / max(0.8, live.speed / 9)))
    if d < PULSE then return 0.35, 0.2 end
    if d >= 0.11 and d < 0.11 + PULSE then return 0.25, 0.3 end
    if d >= 0.22 and d < 0.22 + PULSE then return 0.45, 0.35 end
    return 0, 0
end

-- A cast: ticks closer and stronger toward its end
local function Tension(now)
    if not cast.start then return nil end
    local span = cast.finish - cast.start
    local p = span > 0 and min(1, max(0, (now - cast.start) / span)) or 1
    local d = Beat(cast, now, 0.4 - 0.29 * p)
    local a = 0.1 + 0.6 * p * p
    if d < PULSE then return a, a end
    return 0, 0
end

local function LiveOn(key)
    return H.Engine() and L.EventSettings(key).on
end

local function StartLive(key, fn)
    if not LiveOn(key) then return end
    -- (a feel other than the default: played looped instead of the live one)
    local s = L.EventSettings(key)
    if s.feel ~= EVENT[key].feel then
        if not H.Playing("live_" .. key) then
            H.Play(s.feel, { voice = "live_" .. key, loop = true, gain = Strength() })
        end
        return
    end
    if not H.Playing("live_" .. key) then H.Fn("live_" .. key, fn, { gain = Strength() }) end
end

---------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local function Listen(...)
    for i = 1, select("#", ...) do
        pcall(frame.RegisterEvent, frame, (select(i, ...)))
    end
end
local function ListenUnit(event, ...)
    if not pcall(frame.RegisterUnitEvent, frame, event, ...) then pcall(frame.RegisterEvent, frame, event) end
end

ListenUnit("UNIT_COMBAT", "player", "target")
ListenUnit("UNIT_HEALTH", "player", "target")
ListenUnit("UNIT_POWER_UPDATE", "player")
ListenUnit("UNIT_SPELLCAST_START", "player", "target")
ListenUnit("UNIT_SPELLCAST_CHANNEL_START", "player", "target")
ListenUnit("UNIT_SPELLCAST_STOP", "player")
ListenUnit("UNIT_SPELLCAST_CHANNEL_STOP", "player")
ListenUnit("UNIT_SPELLCAST_DELAYED", "player")
ListenUnit("UNIT_THREAT_SITUATION_UPDATE", "player")
Listen("PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING")
Listen("PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "UI_ERROR_MESSAGE", "CHAT_MSG_LOOT", "PLAYER_MONEY",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN", "CHAT_MSG_SKILL", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE",
    "PLAYER_UPDATE_RESTING", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "READY_CHECK", "PARTY_INVITE_REQUEST",
    "DUEL_REQUESTED", "CONFIRM_SUMMON", "LOSS_OF_CONTROL_ADDED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    "ADDON_LOADED")

local AVOID = { DODGE = true, PARRY = true, BLOCK = true, MISS = true, RESIST = true, ABSORB = true, EVADE = true,
    IMMUNE = true, DEFLECT = true }
local targetDead, combo, powerFull, oomLow, money, resting, threat = nil, 0, false, false, nil, nil, 0
local gcdEnd = 0

local function LootPrefixes()
    local list = {}
    for _, name in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
        "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }) do
        local fmt = _G[name]
        if type(fmt) == "string" then
            local prefix = fmt:match("^(.-)%%")
            if prefix and #prefix > 2 then list[#list + 1] = prefix end
        end
    end
    return list
end
local lootPrefixes

local function HealthFraction(unit)
    local hp, mx = call(UnitHealth, unit), call(UnitHealthMax, unit)
    if hp == nil or mx == nil or secret(hp) or secret(mx) or mx <= 0 then return nil end
    return hp / mx
end

local function CastTimes(channel)
    local info = channel and UnitChannelInfo or UnitCastingInfo
    if not info then return nil end
    local s, e = select(4, info("player"))
    if not (s and e) or secret(s) or secret(e) then return nil end
    return s / 1000, e / 1000
end

local function CastBegan(channel)
    local s, e = CastTimes(channel)
    if not s then return end
    cast.start, cast.finish, cast.beatAt, cast.beats = s, e, nil, nil
    if LiveOn("tension") and not channel then
        local st = L.EventSettings("tension")
        if st.feel == "windup" then
            H.Fn("live_tension", Tension, { gain = Strength() })
        else
            H.Play(st.feel, { voice = "live_tension", gain = Strength() })
        end
    end
    CastLight()
end

local function CastOver()
    cast.start = nil
    H.Stop("live_tension")
    H.LightStop("school")
end

local handlers = {}
handlers.UNIT_COMBAT = function(unit, action, flag, amount)
    if secret(action) then return end
    if unit == "player" then
        if action == "WOUND" then
            local gain = 1
            if not secret(amount) and type(amount) == "number" then
                local mx = call(UnitHealthMax, "player")
                if mx and not secret(mx) and mx > 0 then gain = 0.4 + 0.6 * min(1, amount / (mx * 0.15)) end
            end
            L.Fire("hitTaken", gain)
            if L.LightOn("hit") then H.Flash("hit", 1, 0, 0, 0.4, 4) end
        elseif AVOID[action] then
            L.Fire("avoid")
        end
    end
end
handlers.UNIT_HEALTH = function(unit)
    if unit == "target" then
        local dead = call(UnitIsDead, "target")
        if secret(dead) then return end
        if dead and targetDead == false and call(UnitCanAttack, "player", "target") then
            L.Fire("kill")
            if L.LightOn("kill") then H.Flash("kill", 1, 1, 1, 0.6, 6) end
        end
        targetDead = dead and true or false
    elseif unit == "player" then
        live.hp = HealthFraction("player") or live.hp
    end
end
handlers.PLAYER_TARGET_CHANGED = function()
    local dead = call(UnitIsDead, "target")
    targetDead = (not secret(dead) and call(UnitExists, "target")) and (dead and true or false) or nil
end
handlers.UNIT_POWER_UPDATE = function(_, kind)
    if kind == "COMBO_POINTS" then
        local n = call(GetComboPoints, "player", "target") or call(UnitPower, "player", 4)
        if n == nil or secret(n) then return end
        if n > combo then
            local mx = call(UnitPowerMax, "player", 4) or 5
            if not secret(mx) and n >= mx then L.Fire("comboFull") else L.Fire("combo") end
        end
        combo = n
        return
    end
    local POWER = { MANA = 0, RAGE = 1, ENERGY = 3 }
    local kindIndex = POWER[kind]
    if not kindIndex then return end
    local cur, mx = call(UnitPower, "player", kindIndex), call(UnitPowerMax, "player", kindIndex)
    if cur == nil or mx == nil or secret(cur) or secret(mx) or mx <= 0 then return end
    if kind == "MANA" then
        local low = cur / mx < 0.15
        if low and not oomLow then L.Fire("oom") end
        oomLow = low
    elseif kind == "RAGE" or kind == "ENERGY" then
        local full = cur >= mx
        if full and not powerFull then L.Fire("full") end
        powerFull = full
    end
end
handlers.SPELL_UPDATE_COOLDOWN = function()
    if not LiveOn("gcd") then return end
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = call(C_Spell.GetSpellCooldown, 61304)
        if type(info) == "table" then start, duration = info.startTime, info.duration end
    elseif GetSpellCooldown then
        start, duration = call(GetSpellCooldown, 61304)
    end
    if not start or secret(start) or secret(duration) or duration <= 0 then return end
    local ends = start + duration
    if ends <= gcdEnd + 0.01 then return end
    gcdEnd = ends
    C_Timer.After(max(0, ends - Now()), function() if gcdEnd == ends then L.Fire("gcd") end end)
end
handlers.UI_ERROR_MESSAGE = function() L.Fire("uiError") end
handlers.CHAT_MSG_LOOT = function(msg)
    if secret(msg) or type(msg) ~= "string" then return end
    lootPrefixes = lootPrefixes or LootPrefixes()
    for _, prefix in ipairs(lootPrefixes) do
        if msg:sub(1, #prefix) == prefix then return L.Fire("loot") end
    end
end
handlers.PLAYER_MONEY = function()
    local m = call(GetMoney)
    if m and money and m > money then L.Fire("money") end
    money = m
end
handlers.QUEST_ACCEPTED = function() L.Fire("questAccepted") end
handlers.QUEST_TURNED_IN = function() L.Fire("questDone") end
handlers.CHAT_MSG_SKILL = function() L.Fire("skillUp") end
handlers.PLAYER_DEAD = function() L.Fire("death"); live.heart = false end
handlers.PLAYER_UNGHOST = function() L.Fire("alive") end
handlers.PLAYER_ALIVE = function() if not call(UnitIsGhost, "player") then L.Fire("alive") end end
handlers.PLAYER_UPDATE_RESTING = function()
    local r = call(IsResting)
    if r and resting == false then L.Fire("rested") end
    resting = r and true or false
end
handlers.CHAT_MSG_WHISPER = function()
    L.Fire("whisper")
    if L.LightOn("whisper") then H.Flash("whisper", 0.9, 0.4, 1, 0.8, 4) end
end
handlers.CHAT_MSG_BN_WHISPER = handlers.CHAT_MSG_WHISPER
handlers.READY_CHECK = function() L.Fire("readyCheck") end
handlers.PARTY_INVITE_REQUEST = function() L.Fire("invite") end
handlers.DUEL_REQUESTED = handlers.PARTY_INVITE_REQUEST
handlers.CONFIRM_SUMMON = function() L.Fire("summon") end
handlers.LOSS_OF_CONTROL_ADDED = function() L.Fire("control") end
handlers.UNIT_THREAT_SITUATION_UPDATE = function()
    local s = call(UnitThreatSituation, "player")
    if s == nil or secret(s) then return end
    if s >= 2 and threat < 2 then L.Fire("aggro") end
    threat = s
end
handlers.PLAYER_LEVEL_UP = function()
    if L.LightOn("levelUp") then H.Flash("levelUp", 1, 0.8, 0.2, 2, 8) end
end
handlers.UNIT_SPELLCAST_START = function(unit)
    if unit == "player" then return CastBegan(false) end
    if unit == "target" and call(UnitCanAttack, "player", "target") then
        local onMe = call(UnitIsUnit, "targettarget", "player")
        if not secret(onMe) and onMe then L.Fire("targetCast") end
    end
end
handlers.UNIT_SPELLCAST_CHANNEL_START = function(unit)
    if unit == "player" then return CastBegan(true) end
    handlers.UNIT_SPELLCAST_START(unit)
end
handlers.UNIT_SPELLCAST_DELAYED = function()
    local s, e = CastTimes(false)
    if s and cast.start then cast.start, cast.finish = s, e end
end
handlers.UNIT_SPELLCAST_STOP = function(unit) if unit == "player" then CastOver() end end
handlers.UNIT_SPELLCAST_CHANNEL_STOP = handlers.UNIT_SPELLCAST_STOP
handlers.PLAYER_STARTED_MOVING = function()
    live.moveStart = Now()
    H.Stop("live_footsteps")
    if L.sync and L.sync.waiting then L.sync.waiting, L.sync.start = false, live.moveStart end
end
handlers.PLAYER_STOPPED_MOVING = function()
    H.Stop("live_footsteps")
    if L.sync and L.sync.start then L.StepSyncEnd() end
end
handlers.PLAYER_ENTERING_WORLD = function()
    money = call(GetMoney)
    local r = call(IsResting)
    resting = r and true or false
    live.hp = HealthFraction("player")
    L.ApplyBaseLight()
end
handlers.ADDON_LOADED = function(name)
    if name ~= "GamepadCompanion" then return end
    H.DB()
    L.RegisterInRumble()
end

frame:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if fn then fn(...) end
end)

-- Ten times a second: falling, water, mount, taxi, moving, low health
local was = { falling = false, fallStart = 0, swimming = false, mounted = nil, taxi = nil }
local function Poll()
    if not H.Engine() then
        H.Stop("live_heartbeat"); H.Stop("live_footsteps"); H.Stop("live_riding")
        return
    end
    local now = Now()
    local falling = call(IsFalling) and true or false
    local flying = call(IsFlying) and true or false
    local swimming = call(IsSwimming) and true or false
    local taxi = call(UnitOnTaxi, "player") and true or false
    local mounted = call(IsMounted) and true or false
    if swimming and not was.swimming and was.mounted ~= nil then L.Fire("splash") end
    if was.mounted ~= nil and mounted ~= was.mounted and not taxi then
        L.Fire(mounted and "mount" or "dismount")
    end
    if was.taxi ~= nil and taxi ~= was.taxi then L.Fire("taxi") end
    was.swimming, was.mounted, was.taxi = swimming, mounted, taxi
    -- Moving
    local speed = call(GetUnitSpeed, "player") or 0
    if secret(speed) then speed = 0 end
    live.speed = speed
    live.mounted = mounted
    live.moving = speed > 0 and not falling and not swimming and not flying and not taxi
    if live.moving and not mounted then StartLive("footsteps", Steps) else H.Stop("live_footsteps") end
    if live.moving and mounted then StartLive("riding", Gallop) else H.Stop("live_riding") end
    -- Heartbeat: under half health when it can be read, else the game's warning
    local hp = HealthFraction("player")
    if hp then live.hp = hp end
    local warning = _G.LowHealthFrame
    local warned = warning and warning.IsShown and warning:IsShown()
    live.heart = (hp and hp < 0.5) or (not hp and warned) or false
    if call(UnitIsDeadOrGhost, "player") then live.heart = false end
    if live.heart then StartLive("heartbeat", Heartbeat) else H.Stop("live_heartbeat") end
    -- Low health light: a red pulse
    if L.LightOn("lowHp") and live.heart then
        H.Light("lowHp", function(t)
            if not live.heart then return nil end
            local k = 0.5 + 0.5 * sin(t * 2 * pi * 1.4)
            return 0.2 + 0.8 * k, 0, 0
        end, 4)
    end
end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.1, Poll) end
L.Poll = Poll

---------------------------------------------------------------------------
-- Landing, scaled by the time in the air (checked every frame, so it lands
-- with the feet): a hop, a soft short pulse; a fall, stronger and longer,
-- with echoes; a big drop, a deep boom. Last air times kept for the report.
---------------------------------------------------------------------------
-- How hard a landing is (0 a plain jump .. 1 a big fall) from its air time
function L.LandingWeight(t)
    return max(0, min(1, (t - 0.55) / 1.8))
end

-- The default landing (Thud) shaped by its weight
function L.LandingFeel(k)
    local main = 0.25 + 0.75 * k
    local list = { { 0, 0.055 + 0.08 * k, main, -0.2 } }
    for i = 1, floor(k * 3 + 0.3) do
        list[#list + 1] = { 0.06 + 0.08 * k + 0.1 * i, 0.05, main * 0.45 ^ i, i % 2 == 0 and -0.5 or 0.5 }
    end
    if k >= 0.8 then list[#list + 1] = { 0, 0.2, 1, 0 } end
    return { pulses = list, duck = { amount = 0.4 + 0.5 * k, time = 0.15 } }
end

local air = CreateFrame("Frame")
L.airFrame = air
local airState = { falling = false, since = 0 }
air:SetScript("OnUpdate", function()
    if not H.Engine() then airState.falling = false; return end
    local falling = call(IsFalling) and true or false
    local now = Now()
    if falling and not airState.falling then airState.since = now end
    if airState.falling and not falling then
        local blocked = call(IsSwimming) or call(IsFlying) or call(UnitOnTaxi, "player")
        local t = now - airState.since
        if not blocked and t > 0.25 then
            local db = H.DB()
            db.landings = db.landings or {}
            table.insert(db.landings, 1, floor(t * 100 + 0.5) / 100)
            while #db.landings > 12 do table.remove(db.landings) end
            local k = L.LandingWeight(t)
            local s = L.EventSettings("landing")
            if s.feel == EVENT.landing.feel then L.Fire("landing", 1, L.LandingFeel(k))
            else L.Fire("landing", 0.25 + 0.75 * k) end
            -- (the run starts again on landing: footsteps from here)
            if live.moving then live.moveStart = now; H.Stop("live_footsteps") end
        end
    end
    airState.falling = falling
end)

---------------------------------------------------------------------------
-- Footstep sync: start running and squeeze R2 (or L2) on each footfall; the
-- squeezes give the step rate and the first step's time after the start
---------------------------------------------------------------------------
local syncFrame = CreateFrame("Frame")
syncFrame:Hide()

function L.StepSync(band)
    band = band or "run"
    L.sync = { band = band, waiting = true, taps = {}, speeds = {}, down = false, began = Now() }
    syncFrame:Show()
    if L.onSync then
        L.onSync(band == "walk" and "Stand still, walk on (Walk key), then move: squeeze R2 on each footfall"
            or "Stand still, then run: squeeze R2 on each footfall")
    end
end

function L.StepSyncCancel()
    syncFrame:Hide()
    L.sync = nil
    if L.onSync then L.onSync("") end
end

local function Median(list)
    local c = {}
    for i, v in ipairs(list) do c[i] = v end
    table.sort(c)
    if #c == 0 then return nil end
    return c[floor((#c + 1) / 2)]
end

-- The taps (seconds after the start) to a rate and an offset: steps may be
-- missed, so each gap counts as the nearest whole number of steps; then a
-- straight line through them
function L.FitSteps(taps)
    if #taps < 4 then return nil end
    local gaps = {}
    for i = 2, #taps do gaps[#gaps + 1] = taps[i] - taps[i - 1] end
    local period = Median(gaps)
    if not period or period <= 0.1 then return nil end
    local idx, n = { 0 }, 0
    for i = 2, #taps do
        n = n + max(1, floor((taps[i] - taps[i - 1]) / period + 0.5))
        idx[i] = n
    end
    local sx, sy, sxx, sxy, m = 0, 0, 0, 0, #taps
    for i = 1, m do
        sx, sy = sx + idx[i], sy + taps[i]
        sxx, sxy = sxx + idx[i] * idx[i], sxy + idx[i] * taps[i]
    end
    local den = m * sxx - sx * sx
    if den == 0 then return nil end
    local b = (m * sxy - sx * sy) / den
    local a = (sy - b * sx) / m
    if b <= 0.1 then return nil end
    -- (the first step after the start: the line's start, a whole step on if before it)
    while a < 0 do a = a + b end
    while a > b do a = a - b end
    return 1 / b, a
end

function L.StepSyncEnd()
    local s = L.sync
    syncFrame:Hide()
    L.sync = nil
    if not s then return end
    local rate, offset = L.FitSteps(s.taps)
    if not rate then
        if L.onSync then L.onSync("|cffff7a5cToo few squeezes: try again (6 or more)|r") end
        return
    end
    local speed = Median(s.speeds) or (s.band == "walk" and 2.5 or 7)
    if s.band and Band(speed) ~= s.band then
        if L.onSync then
            L.onSync("|cffff7a5c" .. (s.band == "walk" and "You were running: turn walk on and again"
                or "You were walking: turn walk off and again") .. "|r")
        end
        return
    end
    local db = H.DB()
    db.stepSync = db.stepSync or {}
    db.stepSync[Model() .. "-" .. Band(speed)] = { rate = rate, offset = offset, speed = speed, taps = #s.taps }
    db.stepNudge = 0
    local msg = string.format("Synced (%s): %.2f steps/s, first after %.2f s", Band(speed), rate, offset)
    if L.onSync then L.onSync(msg) end
    print("|cff80c0ffGamepad Companion:|r " .. msg)
end

syncFrame:SetScript("OnUpdate", function()
    local s = L.sync
    if not s then return syncFrame:Hide() end
    local now = Now()
    if s.waiting then
        if now - s.began > 30 then L.StepSyncCancel() end
        return
    end
    local l, r = L.TriggerAxes()
    local depth = max(l or 0, r or 0)
    if not s.down and depth > 0.5 then
        s.down = true
        s.taps[#s.taps + 1] = now - s.start
        local speed = call(GetUnitSpeed, "player")
        if speed and not secret(speed) and speed > 0 then s.speeds[#s.speeds + 1] = speed end
        if L.onSync then L.onSync(#s.taps .. " steps") end
        if #s.taps >= 12 then L.StepSyncEnd() end
    elseif s.down and depth < 0.2 then
        s.down = false
    end
    if now - s.start > 15 then L.StepSyncEnd() end
end)

-- The Beta engine on or off
function L.SetEngine(on)
    local db = H.DB()
    db.engine = on == true
    H.Stop()
    H.LightStop()
    if db.engine then
        L.ApplyBaseLight()
        L.RegisterInRumble()
    end
    local V = ns.Rumble
    if V and V.Stop then V.Stop() end
end
