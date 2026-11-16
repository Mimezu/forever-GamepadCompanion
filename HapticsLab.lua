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
-- The library: a vocabulary the old 0.1 s steps could not play
---------------------------------------------------------------------------
L.GROUPS = { "Taps", "Grain", "Texture", "Detents", "Shapes", "Motion", "Life", "Signals", "Extremes" }

local function heartKeys(period, a, b)
    return { { 0, a, "out" }, { 0.07, 0 }, { 0.2 * period, 0, "hold" }, { 0.2 * period, b, "out" },
        { 0.2 * period + 0.07, 0 }, { period, 0 } }
end

local LIB = {
    -- Taps. In game (probes, 2026-11-16): under ~45 ms a tap is felt only
    -- some of the time; 50 ms always, even at 20%. So subtle = 50 ms, soft.
    { "pin", "Pin", "Taps", "micro", { hold = 0.05, peak = 0.25 } },
    { "tap", "Tap", "Taps", "tick", { hold = 0.05, peak = 0.6 } },
    { "knock", "Knock", "Taps", "impact", { hold = 0.06, decay = 0.08, peak = 1, kick = 0.03,
        duck = { amount = 0.7, time = 0.12 } } },
    { "flick", "Flick", "Taps", "click", { decay = 0.12, curve = 2.5, peak = 1 } },
    { "clickL", "Click left", "Taps", "click", { hold = 0.05, peak = 0.5, pan = -1 } },
    { "clickR", "Click right", "Taps", "click", { hold = 0.05, peak = 0.5, pan = 1 } },
    { "dust", "Dust", "Taps", "micro", { hold = 0.05, peak = 0.15 } },
    { "graze", "Graze", "Taps", "tick", { hold = 0.05, peak = 0.35 } },
    { "feather", "Feather", "Taps", "micro", { hold = 0.06, peak = 0.25, pan = 0.4 } },
    -- Grain: the strength flickering fast (amplitude modulation)
    { "purr8", "Purr 8 Hz", "Grain", "purr", { attack = 0.05, hold = 0.6, decay = 0.15, peak = 0.6,
        grain = { rate = 8, depth = 0.8 } } },
    { "engine15", "Engine 15 Hz", "Grain", "gears", { attack = 0.05, hold = 0.6, decay = 0.15, peak = 0.6,
        grain = { rate = 15, depth = 0.7, wave = "square" } } },
    { "buzz30", "Buzz 30 Hz", "Grain", "static", { attack = 0.05, hold = 0.6, decay = 0.15, peak = 0.6,
        grain = { rate = 30, depth = 0.6, wave = "square" } } },
    { "flutter45", "Flutter 45 Hz", "Grain", "shimmer", { attack = 0.05, hold = 0.6, decay = 0.15, peak = 0.6,
        grain = { rate = 45, depth = 0.9, wave = "square" } } },
    { "windup", "Wind-up", "Grain", "draw", { attack = 1.6, curve = 2, hold = 0.1, decay = 0.08, peak = 0.9,
        grain = { rate = 3, rateTo = 30, depth = 0.9, wave = "square", duty = 0.35 } } },
    { "winddown", "Wind-down", "Grain", "fade", { hold = 0.1, decay = 1.6, peak = 0.9,
        grain = { rate = 30, rateTo = 3, depth = 0.9, wave = "square", duty = 0.35 } } },
    -- Texture: noise and sparks
    { "gravel", "Gravel", "Texture", "pickaxe", { hold = 0.6, decay = 0.1, peak = 0.7, noise = 0.9 } },
    { "crackle", "Crackle", "Texture", "kindle", { hold = 1, decay = 0.1, peak = 0.7, sparks = 14, bed = 0.1 } },
    { "rain", "Rain", "Texture", "frost", { hold = 1.5, peak = 0.5, sparks = 6, bed = 0, loop = true } },
    { "sand", "Sand", "Texture", "sizzle", { hold = 0.8, decay = 0.1, peak = 0.35, noise = 0.6,
        grain = { rate = 22, depth = 0.3 } } },
    { "tremor", "Tremor", "Texture", "shadow", { attack = 0.2, hold = 1, decay = 0.3, peak = 0.25, noise = 0.7,
        grain = { rate = 6, depth = 0.4 } } },
    { "staticx", "Static", "Texture", "zap", { hold = 0.6, decay = 0.05, peak = 0.6, sparks = 25, bed = 0.2 } },
    -- Detents: even ticks
    -- (in game: on / off faster than ~5 Hz is a buzz, so ticks stay at 5 Hz or
    -- under, each on for 50 ms or more)
    { "ratchet", "Ratchet", "Detents", "gears", { hold = 0.8, peak = 0.5, grain = { rate = 5, depth = 1,
        wave = "square", duty = 0.3 } } },
    { "dial", "Dial", "Detents", "click", { hold = 1, peak = 0.35, grain = { rate = 4, depth = 1, wave = "square",
        duty = 0.25 } } },
    { "cogs", "Cogs", "Detents", "whirl", { hold = 1.2, peak = 0.5, grain = { rate = 4, depth = 1, wave = "square",
        duty = 0.25, alternate = true } } },
    { "speedup", "Speeding ticks", "Detents", "charge", { hold = 1.5, peak = 0.5, grain = { rate = 1.5, rateTo = 5,
        depth = 1, wave = "square", duty = 0.35 } } },
    -- Shapes: curves instead of steps
    { "swell", "Swell", "Shapes", "rise", { attack = 1.2, curve = 2, hold = 0.1, decay = 0.25, peak = 0.9 } },
    { "dive", "Dive", "Shapes", "fade", { decay = 1.2, curve = 3, peak = 1 } },
    { "thud", "Thud", "Shapes", "slam", { hold = 0.05, decay = 0.35, curve = 2.5, peak = 1, pan = -0.6,
        duck = { amount = 0.6, time = 0.15 } } },
    { "boom", "Boom", "Shapes", "burst", { kick = 0.04, hold = 0.1, decay = 1.5, curve = 2.5, peak = 1,
        grain = { rate = 9, depth = 0.3 }, duck = { amount = 0.8, time = 0.3 } } },
    { "ripple", "Ripple", "Shapes", "sweep", { hold = 0.05, decay = 0.9, peak = 0.9,
        grain = { rate = 7, rateTo = 2, depth = 0.7 } } },
    { "breath", "Breath", "Shapes", "mend", { attack = 1.4, curve = 1.5, decay = 1.6, peak = 0.3, loop = true } },
    -- Motion: across the pad
    { "passLR", "Pass left-right", "Motion", "sweep", { hold = 0.5, peak = 0.8, pan = -1, panTo = 1 } },
    { "passRL", "Pass right-left", "Motion", "sweep", { hold = 0.5, peak = 0.8, pan = 1, panTo = -1 } },
    { "arrow", "Arrow", "Motion", "string", { hold = 0.25, decay = 0.1, peak = 0.9, pan = -1, panTo = 1, kick = 0.02 } },
    { "whoosh", "Whoosh", "Motion", "toss", { attack = 0.3, curve = 2, decay = 0.4, peak = 0.7, pan = -1, panTo = 1,
        noise = 0.4 } },
    { "orbit", "Orbit", "Motion", "whirl", { hold = 2, peak = 0.5, panRate = 1.5, loop = true } },
    { "pingpong", "Ping-pong", "Motion", "arcane", { hold = 1, peak = 0.7, grain = { rate = 6, depth = 1,
        wave = "square", alternate = true } } },
    -- Life: rhythms
    { "heart60", "Heart 60", "Life", "heart", { loop = true, keys = { left = heartKeys(1, 0.9, 0.6),
        right = heartKeys(1, 0.6, 0.4) } } },
    { "heart120", "Heart 120", "Life", "heart", { loop = true, keys = { left = heartKeys(0.5, 0.9, 0.6),
        right = heartKeys(0.5, 0.6, 0.4) } } },
    { "gallop", "Gallop", "Life", "charge", { loop = true, keys = { left = { { 0, 0.7, "out" }, { 0.05, 0 },
        { 0.12, 0, "hold" }, { 0.12, 0.5, "out" }, { 0.17, 0 }, { 0.24, 0, "hold" }, { 0.24, 0.8, "out" },
        { 0.29, 0 }, { 0.6, 0 } } } } },
    { "steps", "Footsteps", "Life", "tick", { loop = true, keys = {
        left = { { 0, 0.4, "out" }, { 0.05, 0 }, { 0.9, 0 } },
        right = { { 0, 0 }, { 0.45, 0, "hold" }, { 0.45, 0.4, "out" }, { 0.5, 0 }, { 0.9, 0 } } } } },
    { "splash", "Splash", "Life", "bubble", { kick = 0.03, hold = 0.05, decay = 0.7, peak = 0.9, noise = 0.8 } },
    -- Signals: short and meaningful
    { "coin", "Coin", "Signals", "click", { keys = { left = { { 0, 0 }, { 0.16, 0 } },
        right = { { 0, 0.6, "hold" }, { 0.04, 0, "hold" }, { 0.1, 0, "hold" }, { 0.1, 0.85, "hold" }, { 0.15, 0 } } } } },
    { "chime", "Chime", "Signals", "radiance", { keys = { left = { { 0, 0 }, { 0.4, 0 } },
        right = { { 0, 0.3, "hold" }, { 0.05, 0, "hold" }, { 0.14, 0, "hold" }, { 0.14, 0.55, "hold" },
            { 0.19, 0, "hold" }, { 0.28, 0, "hold" }, { 0.28, 0.85, "hold" }, { 0.34, 0 } } } } },
    { "deny", "Deny", "Signals", "hex", { keys = { left = { { 0, 0.7, "hold" }, { 0.08, 0, "hold" }, { 0.16, 0, "hold" },
        { 0.16, 0.7, "hold" }, { 0.24, 0 } }, right = { { 0, 0 }, { 0.24, 0 } } } } },
    { "ready", "Ready", "Signals", "micro", { hold = 0.05, peak = 0.4, pan = 1 } },
    { "notch", "Notch", "Signals", "double", { keys = { left = { { 0, 0.5, "hold" }, { 0.03, 0, "hold" },
        { 0.09, 0, "hold" }, { 0.09, 0.5, "hold" }, { 0.12, 0 } } } } },
    { "whisper", "Whisper", "Signals", "micro", { hold = 0.2, peak = 0.03 } },
    { "murmur", "Murmur", "Signals", "purr", { hold = 0.4, peak = 0.1 } },
    -- Extremes: the limits
    { "max", "Full both", "Extremes", "impact", { hold = 0.5, peak = 1 } },
    { "maxL", "Full left", "Extremes", "bash", { hold = 0.5, peak = 1, pan = -1 } },
    { "maxR", "Full right", "Extremes", "stab", { hold = 0.5, peak = 1, pan = 1 } },
    { "ladder", "Ladder", "Extremes", "rise", { keys = { left = (function()
        local k = {}
        for i = 0, 9 do k[#k + 1] = { i * 0.25, (i + 1) / 10, "hold" } end
        k[#k + 1] = { 2.5, 0 }
        return k
    end)() } } },
    { "sweep60", "1 to 60 Hz", "Extremes", "static", { hold = 4, peak = 0.8, grain = { rate = 1, rateTo = 60,
        depth = 1, wave = "square" } } },
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
local function Taps(ms, v, n)
    return function()
        local list = {}
        for i = 0, (n or 5) - 1 do
            local at = i * 0.7
            list[#list + 1] = { at, function()
                measure.on = Now()
                H.Send("Low", v or 1)
                H.Send("High", v or 1)
            end }
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
    { key = "kick", label = "Overdrive", how = "Two taps: A, then B", ask = "Which was sharper?", answers = { "B sharper", "Same", "A sharper" }, steps = {
        { "A plain, B kicked", function() return { { 0, both(0.4) }, { 0.04, stop },
            { 0.8, both(1) }, { 0.815, both(0.4) }, { 0.84, stop } } end } } },
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
function L.Fire(key, gain)
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
    H.Play(s.feel, { voice = "ev_" .. key, gain = Strength() * (gain or 1) })
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

local function Heartbeat(now, v)
    if not live.heart then return nil end
    v.phase = (v.phase or 0) + (now - (v.at or now)) * (v.bpm or 80) / 60
    v.at = now
    local danger = live.hp and max(0, min(1, 1 - live.hp / 0.5)) or 0.6
    v.bpm = 70 + 110 * danger
    local p = v.phase % 1
    local a = 0.35 + 0.55 * danger
    if p < 0.07 then return a, a * 0.7 end
    if p >= 0.2 and p < 0.26 then return a * 0.65, a * 0.45 end
    return 0, 0
end

local function Steps(now, v)
    if not (live.moving and not live.mounted) then return nil end
    local rate = 2.4 * max(0.5, live.speed / 7)
    v.phase = (v.phase or 0) + (now - (v.at or now)) * rate
    v.at = now
    local p = v.phase % 1
    local left = floor(v.phase) % 2 == 0
    if p < 0.12 then return left and 0.3 or 0, left and 0 or 0.3 end
    return 0, 0
end

local function Gallop(now, v)
    if not (live.moving and live.mounted) then return nil end
    local rate = max(0.8, live.speed / 9)
    v.phase = (v.phase or 0) + (now - (v.at or now)) * rate
    v.at = now
    local p = v.phase % 1
    if p < 0.06 then return 0.35, 0.2 end
    if p >= 0.14 and p < 0.19 then return 0.25, 0.3 end
    if p >= 0.28 and p < 0.34 then return 0.45, 0.35 end
    return 0, 0
end

local function Tension(now)
    if not cast.start then return nil end
    local span = cast.finish - cast.start
    local p = span > 0 and min(1, max(0, (now - cast.start) / span)) or 1
    local rate = 4 + 24 * p
    cast.phase = (cast.phase or 0) + (now - (cast.at or now)) * rate
    cast.at = now
    local on = cast.phase % 1 < 0.35
    local a = 0.06 + 0.4 * p * p
    return on and a or a * 0.2, on and a or a * 0.2
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
    cast.start, cast.finish, cast.phase, cast.at = s, e, 0, nil
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
    if falling and not was.falling then was.fallStart = now end
    if was.falling and not falling and not swimming and not flying and not taxi then
        local t = now - was.fallStart
        if t > 0.35 then L.Fire("landing", min(1, 0.3 + t / 1.5)) end
    end
    if swimming and not was.swimming and was.mounted ~= nil then L.Fire("splash") end
    if was.mounted ~= nil and mounted ~= was.mounted and not taxi then
        L.Fire(mounted and "mount" or "dismount")
    end
    if was.taxi ~= nil and taxi ~= was.taxi then L.Fire("taxi") end
    was.falling, was.swimming, was.mounted, was.taxi = falling, swimming, mounted, taxi
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
