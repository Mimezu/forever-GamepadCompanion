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
L.GROUPS = { "Taps", "Doubles", "Rolls", "Impacts", "Basics", "Combat", "Moves", "Weapons", "Spells", "Crafts", "Motion",
    "Life", "Nature", "Signals", "Extremes" }

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

-- Rhythm and contrast (the player, 2026-11-16): very faint, short micro taps
-- (50 ms, 5-30%) against longer rumbles (0.2-0.5 s, strong), often in one feel
-- (taps leading into a rumble, a rumble trailing off in taps).
local LIB = {
    -- Taps: micro taps, faint; Knock and Flick the contrast
    { "dust", "Dust", "Taps", "micro", Pulses({ P(0, 0.05, 0.06) }) },
    { "pin", "Pin", "Taps", "micro", Pulses({ P(0, 0.05, 0.1) }) },
    { "graze", "Graze", "Taps", "tick", Pulses({ P(0, 0.05, 0.16) }) },
    { "tap", "Tap", "Taps", "tick", Pulses({ P(0, 0.05, 0.3) }) },
    { "feather", "Feather", "Taps", "micro", Pulses({ P(0, 0.05, 0.08, 0.4) }) },
    { "clickL", "Click left", "Taps", "click", Pulses({ P(0, 0.05, 0.18, -1) }) },
    { "clickR", "Click right", "Taps", "click", Pulses({ P(0, 0.05, 0.18, 1) }) },
    { "knock", "Knock", "Taps", "impact", Pulses({ P(0, 0.05, 0.1), P(0.1, 0.18, 0.9) },
        { duck = { amount = 0.7, time = 0.25 } }) },
    { "flick", "Flick", "Taps", "click", Pulses({ P(0, 0.12, 0.55), P(0.2, 0.05, 0.1) }) },
    -- Doubles: two or three, or a rumble and its echoes
    { "notch", "Notch", "Doubles", "double", Pulses({ P(0, 0.05, 0.16), P(0.11, 0.05, 0.16) }) },
    { "nudge", "Nudge", "Doubles", "double", Pulses({ P(0, 0.05, 0.08), P(0.12, 0.05, 0.08) }) },
    { "ticktock", "Tick-tock", "Doubles", "click", Pulses({ P(0, 0.05, 0.14, -1), P(0.25, 0.05, 0.14, 1) }) },
    { "echo", "Echo", "Doubles", "fade", Pulses({ P(0, 0.22, 0.7), P(0.32, 0.05, 0.18), P(0.44, 0.05, 0.1),
        P(0.56, 0.05, 0.06) }) },
    { "triple", "Triple", "Doubles", "triple", Pulses(Row(3, 0, 0.1, 0.05, 0.16, 0.16)) },
    { "deny", "Deny", "Doubles", "hex", Pulses({ P(0, 0.14, 0.6, -1), P(0.22, 0.14, 0.6, -1) }) },
    -- Rolls: faint taps in a row, some ending in a rumble
    { "ratchet", "Ratchet", "Rolls", "gears", Pulses(Row(8, 0, 0.12, 0.05, 0.14, 0.14)) },
    { "dial", "Dial", "Rolls", "click", Pulses(Row(6, 0, 0.2, 0.05, 0.08, 0.08)) },
    { "cogs", "Cogs", "Rolls", "whirl", Pulses((function()
        local list = {}
        for i = 0, 7 do list[#list + 1] = P(i * 0.15, 0.05, 0.12, i % 2 == 0 and -1 or 1) end
        return list
    end)()) },
    { "windup", "Wind-up", "Rolls", "draw", Pulses(Join(Accel(10, 0.33, 0.08, 0.05, 0.05, 0.3), { P(1.95, 0.4, 1) })) },
    { "winddown", "Wind-down", "Rolls", "fade", Pulses(Join({ P(0, 0.4, 1) }, (function()
        local list = {}
        for _, p in ipairs(Accel(8, 0.09, 0.33, 0.05, 0.25, 0.05)) do list[#list + 1] = P(p[1] + 0.52, p[2], p[3], p[4]) end
        return list
    end)())) },
    { "speedup", "Speeding up", "Rolls", "charge", Pulses(Join(Accel(10, 0.3, 0.09, 0.05, 0.08, 0.2), { P(1.75, 0.25, 0.7) })) },
    { "rain", "Rain", "Rolls", "frost", Pulses({ P(0, 0.05, 0.08, -0.6), P(0.17, 0.05, 0.05, 0.7), P(0.41, 0.05, 0.1, 0.1),
        P(0.58, 0.05, 0.06, -0.9), P(0.86, 0.05, 0.09, 0.5), P(1.02, 0.05, 0.05, -0.2), P(1.27, 0.05, 0.1, 0.9) },
        { loop = true, length = 1.45 }) },
    { "crackle", "Crackle", "Rolls", "kindle", Pulses({ P(0, 0.05, 0.14, -0.3), P(0.09, 0.05, 0.08, 0.4), P(0.24, 0.12, 0.5, 0),
        P(0.43, 0.05, 0.1, -0.8), P(0.55, 0.05, 0.16, 0.6), P(0.68, 0.05, 0.08, -0.2), P(0.77, 0.05, 0.14, 0.3) }) },
    -- Impacts: a long hit, faint taps after it
    { "thud", "Thud", "Impacts", "slam", Pulses({ P(0, 0.25, 1, -0.4), P(0.36, 0.05, 0.12, -0.4) },
        { duck = { amount = 0.6, time = 0.3 } }) },
    { "boom", "Boom", "Impacts", "burst", Pulses({ P(0, 0.5, 1), P(0.62, 0.05, 0.22), P(0.74, 0.05, 0.13), P(0.86, 0.05, 0.07) },
        { duck = { amount = 0.8, time = 0.55 } }) },
    { "shockwave", "Shockwave", "Impacts", "slam", Pulses({ P(0, 0.3, 1), P(0.4, 0.05, 0.2, -1), P(0.4, 0.05, 0.2, 1),
        P(0.54, 0.05, 0.1, -1), P(0.54, 0.05, 0.1, 1) }) },
    { "dive", "Dive", "Impacts", "fade", Pulses({ P(0, 0.2, 0.8), P(0.28, 0.12, 0.45), P(0.48, 0.05, 0.2), P(0.62, 0.05, 0.08) }) },
    { "swell", "Swell", "Impacts", "rise", Pulses({ P(0, 0.05, 0.06), P(0.2, 0.05, 0.12), P(0.37, 0.05, 0.2), P(0.52, 0.45, 0.9) }) },
    { "splash", "Splash", "Impacts", "bubble", Pulses({ P(0, 0.18, 0.8), P(0.26, 0.05, 0.12, -0.8), P(0.34, 0.05, 0.1, 0.7),
        P(0.46, 0.05, 0.07, -0.3), P(0.6, 0.05, 0.05, 0.5) }) },
    { "gravel", "Gravel", "Impacts", "pickaxe", Pulses({ P(0, 0.05, 0.2, -0.4), P(0.1, 0.05, 0.1, 0.3), P(0.17, 0.05, 0.16, -0.1),
        P(0.3, 0.05, 0.08, 0.5), P(0.38, 0.05, 0.2, -0.6), P(0.5, 0.05, 0.1, 0.2), P(0.6, 0.05, 0.14, -0.3) }) },
    { "tremor", "Tremor", "Impacts", "shadow", Pulses({ P(0, 0.05, 0.07, -0.5), P(0.22, 0.05, 0.05, 0.4), P(0.38, 0.3, 0.3, -0.1),
        P(0.8, 0.05, 0.06, 0.6), P(1.0, 0.05, 0.04, -0.4) }) },
    -- Motion: faint taps across the pad, some landing in a hit
    { "passLR", "Pass left-right", "Motion", "sweep", Pulses(Row(4, 0, 0.1, 0.05, 0.18, 0.18, -1, 1)) },
    { "passRL", "Pass right-left", "Motion", "sweep", Pulses(Row(4, 0, 0.1, 0.05, 0.18, 0.18, 1, -1)) },
    { "arrow", "Arrow", "Motion", "string", Pulses(Join(Row(3, 0, 0.07, 0.05, 0.08, 0.16, -1, 0.3), { P(0.24, 0.2, 0.9, 1) })) },
    { "whoosh", "Whoosh", "Motion", "toss", Pulses(Row(5, 0, 0.09, 0.05, 0.05, 0.2, -1, 1)) },
    { "orbit", "Orbit", "Motion", "whirl", Pulses({ P(0, 0.05, 0.12, -1), P(0.2, 0.05, 0.12, 0), P(0.4, 0.05, 0.12, 1),
        P(0.6, 0.05, 0.12, 0) }, { loop = true, length = 0.8 }) },
    { "pingpong", "Ping-pong", "Motion", "arcane", Pulses((function()
        local list = {}
        for i = 0, 5 do list[#list + 1] = P(i * 0.18, 0.05, 0.2, i % 2 == 0 and -1 or 1) end
        return list
    end)()) },
    -- Life: rhythms that loop; a longer beat against a faint one
    { "heart60", "Heart 60", "Life", "heart", Pulses({ P(0, 0.12, 0.7, -0.3), P(0.26, 0.05, 0.2, -0.3) },
        { loop = true, length = 1 }) },
    { "heart120", "Heart 120", "Life", "heart", Pulses({ P(0, 0.1, 0.75, -0.3), P(0.18, 0.05, 0.2, -0.3) },
        { loop = true, length = 0.5 }) },
    { "gallop", "Gallop", "Life", "charge", Pulses({ P(0, 0.05, 0.14, -0.3), P(0.12, 0.05, 0.1, 0), P(0.24, 0.09, 0.4, 0.3) },
        { loop = true, length = 0.6 }) },
    { "steps", "Footsteps", "Life", "tick", Pulses({ P(0, 0.05, 0.12, -1), P(0.45, 0.05, 0.12, 1) }, { loop = true, length = 0.9 }) },
    { "purr", "Purr", "Life", "purr", Pulses({ P(0, 0.05, 0.06), P(0.25, 0.05, 0.04) }, { loop = true, length = 0.5 }) },
    { "breath", "Breath", "Life", "mend", Pulses({ P(0, 0.05, 0.04), P(0.4, 0.05, 0.07), P(0.8, 0.05, 0.04),
        P(1.8, 0.05, 0.03), P(2.2, 0.05, 0.02) }, { loop = true, length = 3.2 }) },
    -- Signals: short and meaningful
    { "coin", "Coin", "Signals", "click", Pulses({ P(0, 0.05, 0.1, 1), P(0.1, 0.05, 0.3, 1) }) },
    { "chime", "Chime", "Signals", "radiance", Pulses(Row(3, 0, 0.14, 0.05, 0.08, 0.3, 1, 1)) },
    { "ready", "Ready", "Signals", "micro", Pulses({ P(0, 0.05, 0.14, 1) }) },
    { "alert", "Alert", "Signals", "hex", Pulses(Row(3, 0, 0.3, 0.16, 0.7, 0.7)) },
    { "whisper", "Whisper", "Signals", "micro", Pulses({ P(0, 0.05, 0.03) }) },
    { "murmur", "Murmur", "Signals", "purr", Pulses({ P(0, 0.05, 0.06), P(0.15, 0.05, 0.04) }) },
    -- Combat: blows given and taken, faint for the small ones
    { "strike", "Strike", "Combat", "stab", Pulses({ P(0, 0.05, 0.1) }) },
    { "whiff", "Whiff", "Combat", "toss", Pulses({ P(0, 0.05, 0.05, -0.7), P(0.08, 0.05, 0.04, 0.7) }) },
    { "slip", "Slip", "Combat", "whirl", Pulses({ P(0, 0.05, 0.08, 0.6), P(0.12, 0.05, 0.04, 0.9) }) },
    { "clash", "Clash", "Combat", "latch", Pulses({ P(0, 0.06, 0.35), P(0.1, 0.05, 0.12), P(0.2, 0.05, 0.05) }) },
    { "shieldThud", "Shield thud", "Combat", "bash", Pulses({ P(0, 0.1, 0.3, -0.1), P(0.18, 0.05, 0.06) }) },
    { "sidestep", "Sidestep", "Combat", "sweep", Pulses({ P(0, 0.05, 0.12, -1), P(0.1, 0.05, 0.06, 1) }) },
    { "parryRing", "Parry", "Combat", "judge", Pulses({ P(0, 0.05, 0.15), P(0.06, 0.12, 0.55), P(0.26, 0.05, 0.12),
        P(0.38, 0.05, 0.05) }) },
    { "blockThud", "Block", "Combat", "ward", Pulses({ P(0, 0.16, 0.6, -0.6), P(0.26, 0.05, 0.12, -0.6) },
        { duck = { amount = 0.5, time = 0.2 } }) },
    { "missedYou", "Missed you", "Combat", "toss", Pulses({ P(0, 0.05, 0.04, 1), P(0.1, 0.05, 0.06), P(0.2, 0.05, 0.03, -1) }) },
    -- Nature: weather, water, care
    { "raindrops", "Rain", "Nature", "frost", Pulses({ P(0, 0.05, 0.03, -0.5), P(0.31, 0.05, 0.02, 0.6),
        P(0.52, 0.05, 0.04, 0.1), P(0.97, 0.05, 0.02, -0.8), P(1.24, 0.05, 0.03, 0.4) }, { loop = true, length = 1.6 }) },
    { "thunder", "Thunder", "Nature", "static", Pulses({ P(0, 0.06, 0.3), P(0.14, 0.5, 0.22, -0.2), P(0.72, 0.35, 0.14, 0.3),
        P(1.15, 0.2, 0.07) }) },
    { "snowflakes", "Snow", "Nature", "shimmer", Pulses({ P(0, 0.05, 0.02, -0.4), P(1.4, 0.05, 0.03, 0.5),
        P(2.3, 0.05, 0.02) }, { loop = true, length = 3 }) },
    { "sandgust", "Sand gust", "Nature", "sizzle", Pulses(Row(6, 0, 0.18, 0.05, 0.03, 0.06, -1, 1)) },
    { "embers", "Embers", "Nature", "kindle", Pulses({ P(0, 0.05, 0.05, 0.3), P(0.09, 0.05, 0.03, 0.4), P(0.9, 0.05, 0.06, -0.5),
        P(1.5, 0.05, 0.04) }, { loop = true, length = 2 }) },
    { "bubbles", "Bubbles", "Nature", "bubble", Pulses({ P(0, 0.05, 0.04, -0.2), P(0.3, 0.05, 0.03, 0.1),
        P(1.5, 0.05, 0.05, 0.3) }, { loop = true, length = 2.4 }) },
    { "wrap", "Bandage", "Nature", "sew", Pulses({ P(0, 0.05, 0.05), P(0.2, 0.1, 0.09) }, { loop = true, length = 1 }) },
    { "potion", "Potion", "Nature", "gulp", Pulses({ P(0, 0.05, 0.08), P(0.14, 0.05, 0.1), P(0.3, 0.25, 0.3),
        P(0.65, 0.05, 0.08) }) },
    -- Extremes: the limits
    { "max", "Full both", "Extremes", "impact", Pulses({ P(0, 0.5, 1) }) },
    { "maxL", "Full left", "Extremes", "bash", Pulses({ P(0, 0.5, 1, -1) }) },
    { "maxR", "Full right", "Extremes", "stab", Pulses({ P(0, 0.5, 1, 1) }) },
    { "ladder", "Ladder", "Extremes", "rise", Pulses(Row(10, 0, 0.25, 0.08, 0.1, 1)) },
    { "closest", "Closest pulses", "Extremes", "static", Pulses(Row(16, 0, 0.09, 0.05, 0.3, 0.3)) },
}
for _, e in ipairs(LIB) do
    local feel = e[5]
    feel.label, feel.group, feel.icon = e[2], e[3], ICONS .. e[4]
    H.AddLibrary(e[1], feel)
end

-- Rumble's own patterns in the library too, as "r_" + their key: one palette
-- for every event, each copiable as a base to edit. Grouped: Basics, Moves,
-- Weapons (shots and swings), Spells, Crafts (gathering, crafting, food)
do
    local V = ns.Rumble
    local SPELL, CRAFT = {}, { chew = true, gulp = true }
    for _, a in ipairs(V and V.CAST_ACTIONS or {}) do (a.kind == "spell" and SPELL or CRAFT)[a.pattern] = true end
    for _, p in ipairs(V and V.PATTERNS or {}) do
        if p.feel and not p.beta then
            local f = H.Copy(p.feel)
            f.label, f.icon, f.rumble = p.label, p.icon, p.key
            f.group = (p.swing or p.weapon) and "Weapons" or p.move and "Moves" or SPELL[p.key] and "Spells"
                or CRAFT[p.key] and "Crafts" or "Basics"
            f.loop, f.gap = nil, nil
            H.AddLibrary("r_" .. p.key, f)
        end
    end
end

-- A Rumble pattern key for a library feel (its own for "r_", else a Beta one)
function L.PatternFor(key)
    if not key then return nil end
    if key:sub(1, 2) == "r_" then return key:sub(3) end
    return "x_" .. key
end

-- The library feel for a Rumble pattern key
function L.FeelFor(pattern)
    if not pattern then return nil end
    if pattern:sub(1, 2) == "x_" then return pattern:sub(3) end
    return "r_" .. pattern
end

---------------------------------------------------------------------------
-- Beta feels in Rumble's pattern grid (while the Beta engine is on)
---------------------------------------------------------------------------
function L.RegisterInRumble()
    local V = ns.Rumble
    if not (V and V.AddFeel) then return end
    for _, feel in ipairs(H.AllFeels()) do
        -- (Rumble's own "r_" feels are its patterns already; a copy of yours is not)
        if not feel.rumble or H.IsOwn(feel.key) then V.AddFeel("x_" .. feel.key, feel) end
    end
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
        { "Weather API", (C_Weather and C_Weather.GetCurrentWeather) and ("C_Weather: "
            .. tostring((L.ReadWeather() or {}).raw)) or "none" },
        { "Zone climate", tostring(L.Climate and L.Climate() or "?") },
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
local ART = "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_"
-- (groups shared with Rumble's own events on the Rumble tab)
L.EVENT_GROUPS = { "Attacks", "Defense", "Abilities", "Moving", "Care", "Weather", "Progress", "Social" }
L.EVENTS = {
    -- Attacks: your blows (Rumble adds swings, crits, shots)
    { key = "hit", icon = ART .. "vibe_stab", group = "Attacks", label = "Hit", feel = "strike", on = true,
        tip = "A hit lands on your target" },
    { key = "miss", icon = ART .. "vibe_fade", group = "Attacks", label = "Miss", feel = "whiff", on = true,
        tip = "Your attack misses" },
    { key = "targetDodge", icon = ART .. "vibe_whirl", group = "Attacks", label = "Target dodges", feel = "slip", on = true },
    { key = "targetParry", icon = ART .. "vibe_latch", group = "Attacks", label = "Target parries", feel = "clash", on = true },
    { key = "targetBlock", icon = ART .. "vibe_bash", group = "Attacks", label = "Target blocks", feel = "shieldThud", on = true },
    { key = "kill", icon = ART .. "vibe_judge", group = "Attacks", label = "Target killed", feel = "boom", on = true },
    -- Defense: blows at you
    { key = "hitTaken", icon = ART .. "event_critted", group = "Defense", label = "Hit taken", feel = "thud", on = true,
        tip = "Stronger the bigger the hit" },
    { key = "dodge", icon = ART .. "vibe_sweep", group = "Defense", label = "You dodge", feel = "sidestep", on = true },
    { key = "parry", icon = ART .. "vibe_judge", group = "Defense", label = "You parry", feel = "parryRing", on = true },
    { key = "block", icon = ART .. "vibe_ward", group = "Defense", label = "You block", feel = "blockThud", on = true },
    { key = "missedYou", icon = ART .. "vibe_toss", group = "Defense", label = "Missed you", feel = "missedYou", on = true,
        tip = "A miss, a resist, an absorb" },
    { key = "heartbeat", icon = ART .. "vibe_heart", group = "Defense", label = "Heartbeat", feel = "heart60", on = false,
        live = true, tip = "Under half health: faster as it drops" },
    { key = "control", icon = ART .. "vibe_frost", group = "Defense", label = "Lost control", feel = "gravel", on = true },
    { key = "targetCast", icon = ART .. "event_cast", group = "Defense", label = "Enemy casts at you", feel = "tremor", on = false },
    { key = "aggro", icon = ART .. "vibe_hex", group = "Defense", label = "Aggro", feel = "swell", on = false },
    -- Abilities: casts' pace, resources
    { key = "tension", icon = ART .. "vibe_draw", group = "Abilities", label = "Cast tension", feel = "windup", on = false,
        live = true, tip = "Ticks closer toward the cast's end" },
    { key = "gcd", icon = ART .. "vibe_tick", group = "Abilities", label = "Global cooldown ready", feel = "ready", on = false },
    { key = "combo", icon = ART .. "vibe_micro", group = "Abilities", label = "Combo point", feel = "pin", on = true },
    { key = "comboFull", icon = ART .. "vibe_flurry", group = "Abilities", label = "Combo points full", feel = "knock", on = true },
    { key = "full", icon = ART .. "vibe_rise", group = "Abilities", label = "Rage or energy full", feel = "ready", on = false },
    { key = "oom", icon = ART .. "vibe_fade", group = "Abilities", label = "Low mana", feel = "dive", on = true },
    -- Moving
    { key = "landing", icon = ART .. "vibe_slam", group = "Moving", label = "Landing", feel = "thud", on = true, scaled = true,
        tip = "Softer or harder by the time in the air" },
    { key = "footsteps", icon = ART .. "vibe_tick", group = "Moving", label = "Footsteps", feel = "steps", on = false, live = true },
    { key = "riding", icon = ART .. "vibe_charge", group = "Moving", label = "Riding", feel = "gallop", on = false, live = true },
    { key = "splash", icon = ART .. "vibe_bubble", group = "Moving", label = "Into water", feel = "splash", on = true },
    { key = "underwater", icon = ART .. "vibe_bubble", group = "Moving", label = "Underwater", feel = "bubbles", on = true,
        live = true, tip = "While your breath runs" },
    { key = "mount", icon = ART .. "vibe_charge", group = "Moving", label = "Mount", feel = "swell", on = true },
    { key = "dismount", icon = ART .. "vibe_bash", group = "Moving", label = "Dismount", feel = "thud", on = true },
    { key = "taxi", icon = ART .. "vibe_toss", group = "Moving", label = "Flight path", feel = "whoosh", on = true },
    -- Care: eating and drinking are Rumble's; bandages, potions, rest
    { key = "bandage", icon = ART .. "vibe_sew", group = "Care", label = "Bandage", feel = "wrap", on = true, live = true,
        tip = "While you bandage" },
    { key = "potion", icon = ART .. "event_drink", group = "Care", label = "Potion", feel = "potion", on = true },
    { key = "rested", icon = ART .. "vibe_hearth", group = "Care", label = "Rested", feel = "breath", on = false,
        tip = "Entering an inn or a city" },
    -- Weather: the game's own (C_Weather), outdoors; embers by zone
    { key = "rain", icon = ART .. "vibe_frost", group = "Weather", label = "Rain", feel = "raindrops", on = true, live = true,
        tip = "The game's weather, outdoors: denser when heavier" },
    { key = "thunder", icon = ART .. "vibe_static", group = "Weather", label = "Thunder", feel = "thunder", on = true, live = true,
        tip = "Heavy rain: a far roll now and then" },
    { key = "snow", icon = ART .. "vibe_shimmer", group = "Weather", label = "Snow", feel = "snowflakes", on = true, live = true,
        tip = "The game's weather, outdoors" },
    { key = "sand", icon = ART .. "vibe_sizzle", group = "Weather", label = "Sand", feel = "sandgust", on = true, live = true,
        tip = "Sandstorms, outdoors: a gust now and then" },
    { key = "embers", icon = ART .. "vibe_kindle", group = "Weather", label = "Embers", feel = "embers", on = false, live = true,
        tip = "Burning lands, by zone: no weather" },
    -- Progress
    { key = "loot", icon = ART .. "vibe_click", group = "Progress", label = "Loot", feel = "coin", on = true },
    { key = "money", icon = ART .. "vibe_click", group = "Progress", label = "Money", feel = "coin", on = false },
    { key = "questAccepted", icon = ART .. "vibe_seal", group = "Progress", label = "Quest accepted", feel = "notch", on = true },
    { key = "questDone", icon = ART .. "vibe_radiance", group = "Progress", label = "Quest done", feel = "chime", on = true },
    { key = "skillUp", icon = ART .. "event_levelup", group = "Progress", label = "Skill up", feel = "pin", on = true },
    { key = "death", icon = ART .. "vibe_shadow", group = "Progress", label = "Death", feel = "dive", on = true },
    { key = "alive", icon = ART .. "vibe_mend", group = "Progress", label = "Back to life", feel = "swell", on = true },
    -- Social and the interface
    { key = "whisper", icon = ART .. "vibe_double", group = "Social", label = "Whisper", feel = "notch", on = true },
    { key = "readyCheck", icon = ART .. "vibe_judge", group = "Social", label = "Ready check", feel = "ratchet", on = true },
    { key = "invite", icon = ART .. "vibe_double", group = "Social", label = "Invites, duels", feel = "chime", on = true },
    { key = "summon", icon = ART .. "vibe_ritual", group = "Social", label = "Summon", feel = "swell", on = true },
    { key = "uiError", icon = ART .. "event_interrupted", group = "Social", label = "Error", feel = "deny", on = true,
        tip = "Not enough mana, out of range..." },
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

-- An event back to the feel it ships with
function L.EventDefault(key)
    local e = EVENT[key]
    local s = L.EventSettings(key)
    s.on, s.feel = e.on, e.feel
end

function L.IsEventDefault(key)
    local e = EVENT[key]
    local s = L.EventSettings(key)
    return s.on == e.on and s.feel == e.feel
end

local function Strength()
    local V = ns.Rumble
    local ok, s = pcall(function() return V.Settings() end)
    return ok and s and s.intensity or 0.8
end

local lastFire = {}
-- An event: its feel, if on (gain: 0-1 more or less of it)
function L.Fire(key, gain, feel, absolute, stretch)
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
    H.Play(feel or s.feel, { voice = "ev_" .. key, gain = absolute and (gain or 1) or Strength() * (gain or 1),
        stretch = stretch })
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
-- The library for the outside helper: every feel (Rumble's "r_", the Beta
-- library, yours) and what each event plays, in GamepadCompanionHapticsDB
-- .export, written to disk with the saved settings on logout and /reload.
-- The helper reads it to draft each feel's HD version (docs/HD-HAPTICS.md).
---------------------------------------------------------------------------
local EXPORT_FIELDS = { "label", "group", "rumble", "pulses", "keys", "attack", "hold", "decay", "peak", "curve",
    "grain", "noise", "sparks", "bed", "pan", "panTo", "panRate", "kick", "loop", "length", "gap", "duck" }

function L.Export()
    local feels = {}
    for _, f in ipairs(H.AllFeels()) do
        local e = { own = H.IsOwn(f.key) or nil }
        for _, k in ipairs(EXPORT_FIELDS) do if f[k] ~= nil then e[k] = H.Copy(f[k]) end end
        feels[f.key] = e
    end
    -- what each event plays now (a feel key; Rumble's as library keys)
    local events = {}
    for _, e in ipairs(L.EVENTS) do
        local s = L.EventSettings(e.key)
        events[e.key] = s.on and s.feel or false
    end
    local V = ns.Rumble
    if V and V.EVENTS then
        for _, e in ipairs(V.EVENTS) do
            local choice = V.EventChoice(e.key)
            events[e.key] = (choice == "off" and false) or (choice == "auto" and "auto") or L.FeelFor(choice)
        end
    end
    H.DB().export = { version = 1, at = date and date("%Y-%m-%d %H:%M") or "", feels = feels, events = events }
    return H.DB().export
end

-- The light bar: Lights.lua (loaded after this file)
function L.ApplyBaseLight()
    if ns.Lights then ns.Lights.ApplyBase() end
end

local cast = {}

---------------------------------------------------------------------------
-- Live voices: heartbeat, footsteps, riding, cast tension
---------------------------------------------------------------------------
local live = { heart = false, hp = nil, moving = false, mounted = false, speed = 0, weather = {} }

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
    -- (a longer lub, a faint dub: contrast)
    local a = 0.35 + 0.55 * danger
    local lub = 0.08 + 0.06 * danger
    local dub = max(lub + 0.1, 0.27 * period)
    if d < lub then return a, a * 0.7 end
    if d >= dub and d < dub + PULSE then return 0.2, 0.14 end
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
-- A gait's steps per second at its own speed (synced, or the guess)
function L.StepRate(band)
    local cal = L.StepCal(band) or GUESS[band]
    return cal.rate
end

-- Set by hand: kept with the sync's timing (or the guess's)
function L.SetStepRate(band, rate)
    local db = H.DB()
    db.stepSync = db.stepSync or {}
    local key = Model() .. "-" .. band
    local cal = db.stepSync[key]
    if not cal then
        local g = GUESS[band]
        cal = { rate = g.rate, offset = g.offset, speed = g.speed, taps = 0 }
        db.stepSync[key] = cal
    end
    cal.rate = max(0.5, min(5, rate))
end

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
        return left and 0.12 or 0, left and 0 or 0.12
    end
    return 0, 0
end

-- Three hooves, left to right, a stride quicker with speed
local function Gallop(now, v)
    if not (live.moving and live.mounted) then return nil end
    local d = Beat(v, now, max(0.36, 1 / max(0.8, live.speed / 9)))
    if d < PULSE then return 0.14, 0.08 end
    if d >= 0.11 and d < 0.11 + PULSE then return 0.08, 0.12 end
    if d >= 0.22 and d < 0.22 + 0.09 then return 0.4, 0.3 end
    return 0, 0
end

-- A cast: ticks closer and stronger toward its end
local function Tension(now)
    if not cast.start then return nil end
    local span = cast.finish - cast.start
    local p = span > 0 and min(1, max(0, (now - cast.start) / span)) or 1
    local d = Beat(cast, now, 0.4 - 0.29 * p)
    local a = 0.05 + 0.35 * p * p
    if d < PULSE then return a, a end
    return 0, 0
end

local function LiveOn(key)
    if not H.Engine() then return false end
    -- (Rumble off, or Improved Forever: Vibration has the motors: quiet, as L.Fire)
    local V = ns.Rumble
    local okOn, on = pcall(function() return V.Settings().enabled and not V.Other() end)
    if okOn and not on then return false end
    return L.EventSettings(key).on
end

-- (the feel each live voice was started with: a new pick restarts it)
local liveFeel = {}
-- (weather and water: under everything else)
local AMBIENT = { rain = true, thunder = true, snow = true, sand = true, embers = true, underwater = true }

local function StartLive(key, fn)
    local id = "live_" .. key
    -- (turned off, or Rumble off: stops now, not when the condition ends)
    if not LiveOn(key) then H.Stop(id); return end
    local s = L.EventSettings(key)
    if H.Playing(id) and liveFeel[key] ~= s.feel then H.Stop(id) end
    liveFeel[key] = s.feel
    if H.Playing(id) then return end
    -- (a feel other than the default: played looped instead of the live one)
    if s.feel ~= EVENT[key].feel then
        H.Play(s.feel, { voice = id, loop = true, gain = Strength(), ambient = AMBIENT[key] })
        return
    end
    H.Fn(id, fn, { gain = Strength(), ambient = AMBIENT[key] })
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
ListenUnit("UNIT_SPELLCAST_SUCCEEDED", "player")
Listen("PLAYER_LOGOUT")
Listen("MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "WEATHER_CHANGED", "ZONE_CHANGED_NEW_AREA")
Listen("PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING")
Listen("PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "UI_ERROR_MESSAGE", "CHAT_MSG_LOOT", "PLAYER_MONEY",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN", "CHAT_MSG_SKILL", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE",
    "PLAYER_UPDATE_RESTING", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "READY_CHECK", "PARTY_INVITE_REQUEST",
    "DUEL_REQUESTED", "CONFIRM_SUMMON", "LOSS_OF_CONTROL_ADDED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    "ADDON_LOADED")

-- What a unit's UNIT_COMBAT action means: at you, at your target
local AT_YOU = { DODGE = "dodge", PARRY = "parry", BLOCK = "block", MISS = "missedYou", RESIST = "missedYou",
    ABSORB = "missedYou", EVADE = "missedYou", IMMUNE = "missedYou", DEFLECT = "missedYou" }
local AT_TARGET = { MISS = "miss", DODGE = "targetDodge", PARRY = "targetParry", BLOCK = "targetBlock" }
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

-- Bandages (First Aid's channel) and potions, by their spells' names
local careNames
local function CareNames()
    if careNames then return careNames end
    careNames = { bandage = {}, potion = {} }
    local function add(kind, id)
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id))
        if name then careNames[kind][name] = true end
    end
    for _, id in ipairs({ 746, 1159, 3267, 3268, 7926, 7927, 10838, 10839, 18608, 18610 }) do add("bandage", id) end
    -- healing, mana, rage, rejuvenation, restorative and other potions' spells
    for _, id in ipairs({ 439, 440, 441, 2024, 4042, 17534, 437, 438, 2023, 11903, 17530, 17531, 6612, 6613, 17528,
        22729, 11359, 2379, 6615, 3592, 7242 }) do add("potion", id) end
    return careNames
end

local function SpellNameOf(id)
    if not id or secret(id) then return nil end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id))
    if name and not secret(name) then return name end
end

local function BandageOn()
    if not LiveOn("bandage") then return end
    local s = L.EventSettings("bandage")
    H.Play(s.feel, { voice = "live_bandage", loop = true, gain = Strength() })
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
end

local function CastOver()
    cast.start = nil
    H.Stop("live_tension")
    H.Stop("live_bandage")
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
        elseif AT_YOU[action] then
            L.Fire(AT_YOU[action])
        end
    elseif unit == "target" and call(UnitCanAttack, "player", "target") then
        if action == "WOUND" and not secret(flag) and flag ~= "CRITICAL" then
            L.Fire("hit")
        elseif AT_TARGET[action] then
            L.Fire(AT_TARGET[action])
        end
    end
end
handlers.UNIT_HEALTH = function(unit)
    if unit == "target" then
        local dead = call(UnitIsDead, "target")
        if secret(dead) then return end
        if dead and targetDead == false and call(UnitCanAttack, "player", "target") then
            L.Fire("kill")
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
handlers.UNIT_SPELLCAST_START = function(unit)
    if unit == "player" then return CastBegan(false) end
    if unit == "target" and call(UnitCanAttack, "player", "target") then
        local onMe = call(UnitIsUnit, "targettarget", "player")
        if not secret(onMe) and onMe then L.Fire("targetCast") end
    end
end
handlers.UNIT_SPELLCAST_CHANNEL_START = function(unit, _, spellID)
    if unit == "player" then
        local name = SpellNameOf(spellID)
        if name and CareNames().bandage[name] then BandageOn() end
        return CastBegan(true)
    end
    handlers.UNIT_SPELLCAST_START(unit)
end
handlers.UNIT_SPELLCAST_DELAYED = function()
    local s, e = CastTimes(false)
    if s and cast.start then cast.start, cast.finish = s, e end
end
handlers.UNIT_SPELLCAST_STOP = function(unit) if unit == "player" then CastOver() end end
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    if unit ~= "player" then return end
    local name = SpellNameOf(spellID)
    if name and CareNames().potion[name] then L.Fire("potion") end
end
handlers.WEATHER_CHANGED = function() L.ReadWeather() end
-- (on logout and /reload: the library written out for the helper)
handlers.PLAYER_LOGOUT = function() L.Export() end
handlers.ZONE_CHANGED_NEW_AREA = function() L.ReadWeather() end
handlers.MIRROR_TIMER_START = function(timer) if timer == "BREATH" then live.underwater = true end end
handlers.MIRROR_TIMER_STOP = function(timer) if timer == "BREATH" then live.underwater = false end end
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

---------------------------------------------------------------------------
-- Weather by zone: the game tells addons no weather, so a zone's climate
-- stands in for it, felt outdoors only (not indoors, under water or dead).
-- Each a faint, irregular texture (rhythm and contrast: barely there).
---------------------------------------------------------------------------
-- Classic zones by map ID (C_Map), then by English name
local CLIMATE_IDS = {
    [1429] = "rain", [1431] = "rain", [1433] = "rain", [1437] = "storm", [1434] = "storm", [1435] = "storm",
    [1440] = "rain", [1439] = "rain", [1438] = "rain", [1444] = "storm", [1445] = "storm", [1424] = "rain",
    [1417] = "rain", [1420] = "rain", [1421] = "rain", [1425] = "rain", [1450] = "rain", [1448] = "rain",
    [1449] = "storm", [1447] = "rain", [1430] = "storm",
    [1426] = "snow", [1452] = "snow", [1416] = "snow",
    [1446] = "sand", [1451] = "sand", [1418] = "sand", [1443] = "sand", [1441] = "sand", [1413] = "sand", [1411] = "sand",
    [1428] = "embers", [1427] = "embers", [1419] = "embers",
}
local CLIMATE_NAMES = {
    ["Elwynn Forest"] = "rain", ["Duskwood"] = "rain", ["Redridge Mountains"] = "rain", ["Wetlands"] = "storm",
    ["Stranglethorn Vale"] = "storm", ["Swamp of Sorrows"] = "storm", ["Ashenvale"] = "rain", ["Darkshore"] = "rain",
    ["Teldrassil"] = "rain", ["Feralas"] = "storm", ["Dustwallow Marsh"] = "storm", ["Hillsbrad Foothills"] = "rain",
    ["Arathi Highlands"] = "rain", ["Tirisfal Glades"] = "rain", ["Silverpine Forest"] = "rain",
    ["The Hinterlands"] = "rain", ["Moonglade"] = "rain", ["Felwood"] = "rain", ["Un'Goro Crater"] = "storm",
    ["Azshara"] = "rain", ["Deadwind Pass"] = "storm", ["Dun Morogh"] = "snow", ["Winterspring"] = "snow",
    ["Alterac Mountains"] = "snow", ["Tanaris"] = "sand", ["Silithus"] = "sand", ["Badlands"] = "sand",
    ["Desolace"] = "sand", ["Thousand Needles"] = "sand", ["The Barrens"] = "sand", ["Durotar"] = "sand",
    ["Burning Steppes"] = "embers", ["Searing Gorge"] = "embers", ["Blasted Lands"] = "embers",
}
-- What each climate brings
local CLIMATE_EVENTS = { rain = { rain = true }, storm = { rain = true, thunder = true }, snow = { snow = true },
    sand = { sand = true }, embers = { embers = true } }

-- The game's own weather: C_Weather.GetCurrentWeather() (in the client,
-- unlisted; the wardrobe's outfit conditions use it). Its type (Enum.WeatherType:
-- Rain, Snow, Sandstorm, else clear) and intensity. nil: no such API.
-- Read on WEATHER_CHANGED, on zoning, and every few seconds.
local weatherNow = { at = -math.huge }
L.weatherNow = weatherNow

local function TypeName(t)
    if t == nil or secret(t) then return nil end
    if type(t) == "string" then return t end
    local E = type(Enum) == "table" and Enum.WeatherType
    if E then for name, v in pairs(E) do if v == t then return name end end end
    return tostring(t)
end

function L.ReadWeather()
    if not (C_Weather and C_Weather.GetCurrentWeather) then return nil end
    local ok, a, b = pcall(C_Weather.GetCurrentWeather)
    if not ok then return nil end
    local t, intensity = a, b
    if type(a) == "table" then
        t = a.weatherType or a.type or a.weather or a[1]
        intensity = a.intensity or a.density or a[2]
    end
    if secret(intensity) then intensity = nil end
    weatherNow.raw = tostring(t) .. ", " .. tostring(intensity)
    weatherNow.name = TypeName(t)
    weatherNow.intensity = tonumber(intensity)
    weatherNow.at = GetTime and GetTime() or 0
    local n = weatherNow.name and weatherNow.name:lower() or ""
    weatherNow.kind = n:find("rain") and "rain" or n:find("snow") and "snow" or n:find("sand") and "sand" or nil
    return weatherNow
end

-- What the sky brings now: { rain, thunder, snow, sand, embers = true },
-- and the intensity (0-1)
function L.Sky()
    local api = C_Weather and C_Weather.GetCurrentWeather
    if api then
        local now = GetTime and GetTime() or 0
        if now - weatherNow.at > 3 then L.ReadWeather() end
        local i = weatherNow.intensity
        -- (an intensity given 0-1 or 0-100)
        if i and i > 1 then i = i / 100 end
        i = i and max(0, min(1, i)) or 0.5
        local brings = {}
        if weatherNow.kind == "rain" then
            brings.rain = true
            if i >= 0.6 then brings.thunder = true end
        elseif weatherNow.kind then
            brings[weatherNow.kind] = true
        end
        -- (embers are no weather: burning lands, by zone)
        if L.Climate() == "embers" then brings.embers = true end
        return brings, i, true
    end
    local climate = L.Climate()
    return climate and CLIMATE_EVENTS[climate] or {}, 0.5, false
end

function L.Climate()
    local id = C_Map and C_Map.GetBestMapForUnit and call(C_Map.GetBestMapForUnit, "player")
    if id and not secret(id) and CLIMATE_IDS[id] then return CLIMATE_IDS[id] end
    local zone = call(GetRealZoneText) or call(GetZoneText)
    return zone and not secret(zone) and CLIMATE_NAMES[zone] or nil
end

local random = math.random
-- Sparse taps: one every gap0..gap1 s, lo..hi strong, anywhere left to right
-- (sometimes a second right after it: chance2)
local function Sprinkle(key, gap0, gap1, lo, hi, chance2)
    return function(now, v)
        if not live.weather[key] then return nil end
        if not v.next then v.next = now + random() * gap1 end
        -- (heavier weather: taps closer and a little stronger)
        local k = key == "underwater" and 0.5 or (live.weatherIntensity or 0.5)
        if now >= v.next then
            v.tapEnd, v.level, v.side = now + PULSE, (lo + random() * (hi - lo)) * (0.7 + 0.5 * k), random() * 2 - 1
            v.second = random() < (chance2 or 0) and now + 0.09 + random() * 0.05 or nil
            v.next = now + (gap0 + random() * (gap1 - gap0)) * (1.6 - 0.6 * k)
        end
        if v.second and now >= v.second then v.tapEnd, v.second = now + PULSE, nil end
        if v.tapEnd and now < v.tapEnd then
            local s, p = v.level, v.side
            return s * min(1, 1 - p), s * min(1, 1 + p)
        end
        return 0, 0
    end
end

-- A far thunder roll now and then: a crack, two rolls, a tail
local THUNDER = { { 0, 0.06, 0.2, 0 }, { 0.14, 0.5, 0.15, -0.2 }, { 0.72, 0.35, 0.09, 0.3 }, { 1.15, 0.2, 0.05, 0 } }
local function Thunder(now, v)
    if not live.weather.thunder then return nil end
    if not v.next then v.next = now + 8 + random() * 25 end
    if now >= v.next and not v.roll then v.roll = now; v.scale = 0.6 + random() * 0.5 end
    if v.roll then
        local t = now - v.roll
        if t > 1.4 then v.roll, v.next = nil, now + 18 + random() * 45; return 0, 0 end
        for _, p in ipairs(THUNDER) do
            if t >= p[1] and t < p[1] + p[2] then
                local s = p[3] * v.scale
                return s * min(1, 1 - p[4]), s * min(1, 1 + p[4])
            end
        end
    end
    return 0, 0
end

-- A gust of sand: a handful of faint taps sweeping across, now and then
local function Gust(now, v)
    if not live.weather.sand then return nil end
    if not v.next then v.next = now + 2 + random() * 6 end
    if now >= v.next and not v.gust then v.gust, v.dir = now, random() < 0.5 and -1 or 1 end
    if v.gust then
        local t = now - v.gust
        if t > 1.2 then v.gust, v.next = nil, now + 5 + random() * 7; return 0, 0 end
        local i = floor(t / 0.18)
        if t - i * 0.18 < PULSE then
            local side = v.dir * (-1 + 2 * i / 6)
            local s = 0.03 + 0.03 * math.sin(i / 6 * math.pi)
            return s * min(1, 1 - side), s * min(1, 1 + side)
        end
    end
    return 0, 0
end

local WEATHER_FN = {
    -- (rain, in game: too strong, it hid a jump: half as strong, sparser)
    -- (again too strong in game: fainter and sparser still; the HD version will do it best)
    rain = Sprinkle("rain", 0.25, 0.9, 0.005, 0.014, 0.12),
    snow = Sprinkle("snow", 1.2, 3.5, 0.015, 0.03),
    embers = Sprinkle("embers", 0.5, 1.8, 0.03, 0.07, 0.25),
    thunder = Thunder,
    sand = Gust,
}
local BUBBLES = Sprinkle("underwater", 0.9, 2.2, 0.03, 0.05, 0.3)
L.WEATHER_KEYS = { "rain", "thunder", "snow", "sand", "embers" }

-- Ten times a second: falling, water, mount, taxi, moving, low health
local was = { falling = false, fallStart = 0, swimming = false, mounted = nil, taxi = nil }
local function Poll()
    if not H.Engine() then
        H.Stop("live_heartbeat"); H.Stop("live_footsteps"); H.Stop("live_riding"); H.Stop("live_underwater")
        for _, k in ipairs(L.WEATHER_KEYS) do H.Stop("live_" .. k) end
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
    -- Water: bubbles while the breath runs
    if live.underwater then StartLive("underwater", BUBBLES) else H.Stop("live_underwater") end
    live.weather.underwater = live.underwater
    -- Weather: the zone's climate, outdoors, above water, alive
    local outdoors = not call(IsIndoors) and not swimming and not live.underwater
        and not call(UnitIsDeadOrGhost, "player")
    local brings, intensity = {}, 0.5
    if outdoors then brings, intensity = L.Sky() end
    live.weatherIntensity = intensity
    for _, k in ipairs(L.WEATHER_KEYS) do
        live.weather[k] = brings[k] == true
        if live.weather[k] then StartLive(k, WEATHER_FN[k]) else H.Stop("live_" .. k) end
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
-- How strong a landing of weight k is (0-1): faint for light ones, steep
-- toward heavy ones (contrast: a hop is a faint micro tap)
-- The lightest 30%: barely there (4% to 8%); then steep to full
function L.LandingLevel(k)
    if k < 0.3 then return 0.04 + 0.04 * k / 0.3 end
    return 0.08 + 0.92 * ((k - 0.3) / 0.7) ^ 1.4
end

-- (air times: soft at landMin or less, full at landMax or more; settings)
L.LAND_MIN, L.LAND_MAX = 0.5, 1.2
function L.LandingWeight(t)
    local db = H.DB()
    local lo, hi = db.landMin or L.LAND_MIN, db.landMax or L.LAND_MAX
    if hi <= lo then return t >= hi and 1 or 0 end
    return max(0, min(1, (t - lo) / (hi - lo)))
end

-- The default landing (Thud) shaped by its weight
-- (in game a harder landing barely felt stronger while it stayed short: on
-- this pad length is what is felt, so a heavier landing lasts longer, up to
-- landLong seconds, a setting)
L.LAND_LONG = 0.4
function L.LandingFeel(k)
    local longest = H.DB().landLong or L.LAND_LONG
    local main = L.LandingLevel(k)
    local len = 0.06 + max(0, longest - 0.06) * k
    local list = { { 0, len, main, -0.2 * (1 - k) } }
    -- echoes after it: more, longer and stronger the heavier it is
    local at = len + 0.08
    for i = 1, floor(k * 3 + 0.3) do
        local echo = 0.05 + 0.1 * k / i
        list[#list + 1] = { at, echo, main * 0.5 ^ i, i % 2 == 0 and -0.4 or 0.4 }
        at = at + echo + 0.07
    end
    return { pulses = list, duck = { amount = 0.4 + 0.5 * k, time = 0.1 + len } }
end

local air = CreateFrame("Frame")
L.airFrame = air
local airState = { falling = false, since = 0 }
air:SetScript("OnUpdate", function()
    if not H.Engine() then airState.falling = false; return end
    -- (what the motors were sent after the last landing: its peak and length)
    local sent = L.lastLanding and L.lastLanding.sent
    if sent and not sent.done then
        local now = Now()
        local o = max(H.out.l or 0, H.out.r or 0)
        if o > 0.01 then sent.peak, sent.last = max(sent.peak, o), now end
        if now - sent.last > 0.3 and now - sent.start > 0.3 then
            sent.done = true
            if L.onLand then L.onLand(L.lastLanding.t, L.lastLanding.k, sent) end
        end
    end
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
            L.lastLanding = { t = t, k = k }
            if L.onLand then L.onLand(t, k) end
            local s = L.EventSettings("landing")
            -- (Rumble's strength for a light one, full output for the heaviest:
            -- at 70% strength a full landing felt faint)
            local strength = Strength()
            local gain = (strength + (1 - strength) * k) * L.LandingLevel(k)
            if s.feel == EVENT.landing.feel then
                L.Fire("landing", strength + (1 - strength) * k, L.LandingFeel(k), true)
            else
                -- (another feel: as strong, and stretched as long, as the landing
                -- is heavy: in game a short one felt faint whatever its strength)
                local f = H.Feel(s.feel)
                local longest = H.DB().landLong or L.LAND_LONG
                local want = 0.06 + max(0, longest - 0.06) * k
                -- (a light landing shrinks the feel toward a micro tap; pulses
                -- never under the shortest pulse setting)
                local stretch = f and max(0.4, want / max(0.06, H.Length(f))) or 1
                -- (its strongest pulse at full for a full landing, whatever the
                -- feel's own strength: Flick's 80% went out at 74%)
                local peak = f and H.Peak(f) or 1
                L.Fire("landing", gain / max(0.05, peak), nil, true, stretch)
            end
            local played = H.Feel(s.feel)
            L.lastLanding.feel = s.feel == EVENT.landing.feel and "Thud, shaped" or (played and played.label or s.feel)
            L.lastLanding.sent = { start = now, peak = 0, last = now }
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
