-- Haptics (Beta): one mixer for the controller's motors and light bar.
--
-- Every voice is a feel sampled each frame (not 0.1 s steps): an envelope
-- (attack, hold, decay, curve) or keyframes per side, with grain (amplitude
-- modulation, its rate sweeping), noise, sparks, pan and a kick. Voices mix
-- (max, screen or sum) and duck each other; the output goes through a
-- per-side calibration curve (floor, ceiling, gamma), a battery factor and an
-- optional overdrive spike, then to C_GamePad.SetVibration on change only
-- (plus a keep-alive). The light bar is a second channel: the strongest light
-- voice wins. Rumble.lua routes through it while the Beta engine is on.
-- docs/HAPTICS.md has the why.
local _, ns = ...
local H = {}
ns.Haptics = H
if GamepadCompanionAPI then GamepadCompanionAPI.Haptics = H end

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

local function clamp(v) return v < 0 and 0 or v > 1 and 1 or v end
local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Settings: GamepadCompanionHapticsDB (account: the pad is the same pad)
---------------------------------------------------------------------------
H.DEFAULTS = {
    engine = false,        -- Beta engine: Rumble through the mixer, beta events, light bar
    mix = "screen",        -- max | screen | sum
    rate = 10,             -- sends per second at most (0: every frame). Feels are still read every
                           --   frame: a vibration starting goes out at once, changes and stops wait
                           --   for the next send, so each pulse lasts a send's interval at least (in
                           --   game: 10/s felt much stronger than every frame)
    keepAlive = 0.1,       -- resend an unchanged level after (s; 0: never)
    kick = 0,              -- overdrive: a rise starts with this long at full (s)
    minPulse = 0.05,       -- a pulse from rest lasts at least this long (s): in game, under ~45 ms is
                           --   felt only sometimes, 50 ms always
    battery = true,        -- softer on a low battery
    light = false,         -- light bar effects
    triggers = "off",      -- off | mirror (grips also on LTrigger / RTrigger) | only
    floor = { 0, 0 },      -- calibration per side (left, right): first felt (in game: 5% on both)
    ceil = { 1, 1 },       --   no stronger past this
    gamma = { 1, 1 },      --   curve between them
}

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end
H.Copy = Copy

local checked   -- (the table last filled in: the mixer asks every frame)
function H.DB()
    if type(GamepadCompanionHapticsDB) ~= "table" then GamepadCompanionHapticsDB = {} end
    local db = GamepadCompanionHapticsDB
    if checked == db then return db end
    checked = db
    for k, v in pairs(H.DEFAULTS) do
        if db[k] == nil or type(db[k]) ~= type(v) then db[k] = Copy(v) end
    end
    for _, k in ipairs({ "feels", "probes", "events", "lights" }) do
        if type(db[k]) ~= "table" then db[k] = {} end
    end
    -- (0.13.3: the probes' answers become the defaults, once)
    if (db.version or 0) < 2 then
        if db.minPulse == 0 then db.minPulse = 0.05 end
        if db.floor[2] == 0.5 then db.floor[2] = 0 end
        db.version = 2
    end
    if db.version < 3 then
        if db.rate == 0 then db.rate = 10 end
        db.version = 3
    end
    return db
end

function H.Engine() return H.DB().engine == true end

-- Rumble's own patterns go through the mixer (off beside Improved Forever)
function H.Routing()
    if not H.Engine() then return false end
    local V = ns.Rumble
    return not (V and V.Other and V.Other())
end

---------------------------------------------------------------------------
-- Feels: sampling
---------------------------------------------------------------------------
-- feel = {
--   label, loop,
--   attack, hold, decay, peak, curve      (envelope; curve: 1 straight, >1 slow start / fast end)
--   keys = { left = { {t, v, ease}, ... }, right = {...} }   (instead of the envelope)
--   grain = { rate, rateTo, depth, wave, duty, alternate }   (Hz; wave: sine square saw ramp tri)
--   noise (0-1), sparks (per second), bed (level between sparks)
--   pan, panTo, panRate, panDepth (-1 left .. 1 right)
--   kick (s at full first), duck = { amount, time }
-- }
local EASE = {
    hold = function() return 0 end,
    linear = function(x) return x end,
    ["in"] = function(x) return x * x end,
    out = function(x) return 1 - (1 - x) * (1 - x) end,
    smooth = function(x) return x * x * (3 - 2 * x) end,
}
H.EASES = { "linear", "smooth", "in", "out", "hold" }

local function Keys(list, t)
    if not list or #list == 0 then return 0 end
    if t <= list[1][1] then return list[1][2] end
    for i = 2, #list do
        local b = list[i]
        if t < b[1] then
            local a = list[i - 1]
            local span = b[1] - a[1]
            local x = span > 0 and (t - a[1]) / span or 1
            local ease = EASE[a[3] or "linear"] or EASE.linear
            return a[2] + (b[2] - a[2]) * ease(x)
        end
    end
    return list[#list][2]
end
H.KeyAt = Keys

function H.Length(feel)
    -- Pulses: to the end of the last one, or the cycle's set length
    if feel.pulses then
        local len = 0
        for _, p in ipairs(feel.pulses) do len = max(len, (p[1] or 0) + (p[2] or 0)) end
        return max(0.02, len, feel.length or 0)
    end
    if feel.keys then
        local len = 0
        for _, side in pairs(feel.keys) do
            if #side > 0 then len = max(len, side[#side][1]) end
        end
        return max(0.02, len)
    end
    return max(0.02, (feel.attack or 0) + (feel.hold or 0) + (feel.decay or 0))
end

function H.Envelope(feel, t)
    local a, h, d = feel.attack or 0, feel.hold or 0, feel.decay or 0
    local peak, curve = feel.peak or 1, feel.curve or 1
    if t < 0 then return 0 end
    if t < a then return peak * (t / a) ^ curve end
    t = t - a
    if t < h then return peak end
    t = t - h
    if t < d then return peak * (1 - t / d) ^ curve end
    return 0
end

local function Wave(phase, wave, duty)
    local p = phase % 1
    if wave == "square" then return p < (duty or 0.5) and 1 or 0 end
    if wave == "saw" then return 1 - p end
    if wave == "ramp" then return p end
    if wave == "tri" then return 1 - abs(2 * p - 1) end
    return 0.5 - 0.5 * cos(2 * pi * p)
end
H.Wave = Wave

-- Deterministic 0..1 noise (the same t gives the same value: frames may sample twice)
local function Hash(n, seed)
    local x = sin(n * 12.9898 + seed * 78.233) * 43758.5453
    return x - floor(x)
end
H.Hash = Hash

-- The feel's two sides at t seconds in; nil once done (never, looped)
function H.Sample(feel, t, seed)
    seed = seed or 1
    local len = H.Length(feel)
    if t >= len then
        if not feel.loop then return nil end
        t = t % len
    end
    -- Pulses (what the pad keeps, through the game): each { t, length,
    -- strength, side -1 left .. 1 right }; overlapping ones: the stronger
    if feel.pulses then
        local l, r = 0, 0
        for _, p in ipairs(feel.pulses) do
            if t >= p[1] and t < p[1] + p[2] then
                local s, pan = p[3] or 1, p[4] or 0
                l, r = max(l, s * min(1, 1 - pan)), max(r, s * min(1, 1 + pan))
            end
        end
        return clamp(l), clamp(r)
    end
    local l, r
    if feel.keys then
        l = Keys(feel.keys.left, t)
        r = Keys(feel.keys.right or feel.keys.left, t)
    else
        l = H.Envelope(feel, t)
        r = l
    end
    if feel.kick and t < feel.kick then l, r = max(l, 1), max(r, 1) end
    local g = feel.grain
    if g and (g.depth or 0) > 0 and (g.rate or 0) > 0 then
        local to = (g.rateTo or 0) > 0 and g.rateTo or g.rate
        local phase = g.rate * t + (to - g.rate) * t * t / (2 * len)
        local m = 1 - g.depth + g.depth * Wave(phase, g.wave, g.duty)
        if g.alternate then
            local rest = 1 - g.depth
            if floor(phase) % 2 == 1 then l, r = l * rest, r * m else l, r = l * m, r * rest end
        else
            l, r = l * m, r * m
        end
    end
    if (feel.noise or 0) > 0 then
        local b = floor(t * 30)
        l = l * (1 - feel.noise * Hash(b, seed))
        r = r * (1 - feel.noise * Hash(b, seed + 7))
    end
    if (feel.sparks or 0) > 0 then
        local slot = 1 / feel.sparks
        local b = floor(t / slot)
        local at = Hash(b, seed + 3) * max(0, slot - 0.04)
        local d = t - b * slot - at
        local hit = d >= 0 and d < 0.04
        local bed = feel.bed or 0
        local side = Hash(b, seed + 5)
        l = l * ((hit and side < 0.65) and 1 or bed)
        r = r * ((hit and side > 0.35) and 1 or bed)
    end
    local p = feel.pan or 0
    if feel.panTo then p = p + (feel.panTo - p) * min(1, t / len) end
    if (feel.panRate or 0) > 0 then p = p + (feel.panDepth or 1) * sin(2 * pi * feel.panRate * t) end
    p = max(-1, min(1, p))
    l, r = l * min(1, 1 - p), r * min(1, 1 + p)
    return clamp(l), clamp(r)
end

---------------------------------------------------------------------------
-- Output: calibration, battery, the motors
---------------------------------------------------------------------------
-- A 0-1 level on one side (1 left, 2 right) to what the motor is sent
function H.Calibrated(side, v)
    if v <= 0.004 then return 0 end
    local db = H.DB()
    local f, c, g = db.floor[side] or 0, db.ceil[side] or 1, db.gamma[side] or 1
    return clamp(f + (c - f) * clamp(v) ^ g)
end

-- Enum.GamePadPowerLevel: Critical 0, Low 1, Medium 2, High 3, Wired 4
local BATTERY = { [0] = 0.4, [1] = 0.7 }
local battery = { at = -math.huge, factor = 1 }
function H.BatteryFactor()
    if not H.DB().battery then return 1 end
    if not (C_GamePad and C_GamePad.GetPowerLevel) then return 1 end
    local now = Now()
    if now - battery.at > 2 then
        local ok, level = pcall(C_GamePad.GetPowerLevel)
        battery.at, battery.factor = now, ok and BATTERY[level] or 1
    end
    return battery.factor
end

local function Send(kind, v)
    if C_GamePad and C_GamePad.SetVibration then pcall(C_GamePad.SetVibration, kind, v) end
end
local function Silence()
    if C_GamePad and C_GamePad.StopVibration then pcall(C_GamePad.StopVibration) end
end
H.Send, H.Silence = Send, Silence

---------------------------------------------------------------------------
-- The mixer
---------------------------------------------------------------------------
local voices, ducks, counter = {}, {}, 0
local driver = CreateFrame("Frame")
driver:Hide()
H.driver = driver

local out = { l = 0, r = 0, lt = 0, rt = 0, sentL = -1, sentR = -1, sentLT = -1, sentRT = -1, sentAt = 0,
    quiet = true, last = 0, riseL = -1, riseR = -1, sends = 0 }
H.out = out

-- (live view: the last HISTORY outputs, and sends per second)
local HISTORY = 240
local history, head = {}, 0
for i = 1, HISTORY do history[i] = { 0, 0 } end
local sendTimes = {}

local function Wake() driver:Show() end

-- A feel on a voice (the same voice: replaced). opts: voice, gain, left,
-- right, stretch, loop, onDone, target ("grips" | "triggers"), raw (no
-- calibration, a probe's). Returns the voice's id.
function H.Play(feel, opts)
    if type(feel) == "string" then feel = H.Feel(feel) end
    if not feel then return nil end
    opts = opts or {}
    counter = counter + 1
    local id = opts.voice or ("v" .. counter)
    local now = Now()
    voices[id] = {
        -- (start: its first frame, so a feel shorter than a frame is still sampled)
        id = id, feel = feel, start = nil, gain = opts.gain or 1, left = opts.left or 1, right = opts.right or 1,
        stretch = opts.stretch or 1, loop = opts.loop == nil and feel.loop or opts.loop, seed = counter * 7 + 1,
        onDone = opts.onDone, target = opts.target or feel.target, raw = opts.raw,
    }
    local duck = opts.duck or feel.duck
    if duck and (duck.amount or 0) > 0 then
        ducks[#ducks + 1] = { owner = id, start = now, amount = duck.amount, time = duck.time or 0.2 }
    end
    Wake()
    return id
end

-- A held level on a voice (Rumble's own steps); 0, 0 frees it
function H.Set(id, l, r, target)
    if (l or 0) <= 0 and (r or 0) <= 0 then
        voices[id] = nil
    else
        local v = voices[id]
        if v and v.level then v.l, v.r, v.target = l, r, target
        else voices[id] = { id = id, level = true, l = l, r = r, target = target, gain = 1, left = 1, right = 1 } end
    end
    Wake()
end

-- A function on a voice: fn(now, voice) gives left, right (nil: done)
function H.Fn(id, fn, opts)
    opts = opts or {}
    voices[id] = { id = id, fn = fn, start = Now(), gain = opts.gain or 1, left = 1, right = 1, target = opts.target,
        onDone = opts.onDone }
    Wake()
    return id
end

-- A voice stops (nil: all of them, and the motors at once)
function H.Stop(id)
    if id == nil then
        wipe(voices)
        wipe(ducks)
        out.l, out.r, out.lt, out.rt = 0, 0, 0, 0
        Silence()
        out.quiet = true
        out.sentL, out.sentR, out.sentLT, out.sentRT = -1, -1, -1, -1
        return
    end
    voices[id] = nil
end

function H.Playing(id) return voices[id] ~= nil end

local MIX = {
    max = function(a, b) return a > b and a or b end,
    screen = function(a, b) return 1 - (1 - a) * (1 - b) end,
    sum = function(a, b) return min(1, a + b) end,
}

local function DuckFactor(id, now)
    local f = 1
    for i = #ducks, 1, -1 do
        local d = ducks[i]
        local age = now - d.start
        if age > d.time + 0.15 then
            table.remove(ducks, i)
        elseif d.owner ~= id then
            local left = age < d.time and 1 or (1 - (age - d.time) / 0.15)
            f = f * (1 - d.amount * left)
        end
    end
    return f
end

-- One voice's sides now (nil: done)
local function VoiceLevel(v, now)
    if v.level then return v.l, v.r end
    if v.fn then return v.fn(now, v) end
    v.start = v.start or now
    local t = (now - v.start) / (v.stretch or 1)
    -- (a looping feel played once: one time through)
    if not v.loop and t >= H.Length(v.feel) then return nil end
    if v.loop and not v.feel.loop then
        local len = H.Length(v.feel)
        t = t % (len + (v.feel.gap or 0.12))
        if t >= len then return 0, 0 end
    end
    return H.Sample(v.feel, t, v.seed)
end

-- The mix now: grips (l, r), triggers (lt, rt), and whether a raw voice plays
function H.Mix(now)
    local db = H.DB()
    local mix = MIX[db.mix] or MIX.screen
    local l, r, lt, rt, raw, any = 0, 0, 0, 0, false, false
    local done
    for id, v in pairs(voices) do
        local a, b = VoiceLevel(v, now)
        if a == nil then
            done = done or {}
            done[#done + 1] = v
        else
            any = true
            local f = (v.gain or 1) * DuckFactor(id, now)
            a, b = clamp(a * f * (v.left or 1)), clamp(b * f * (v.right or 1))
            if v.raw then raw = true end
            if v.target == "triggers" then lt, rt = mix(lt, a), mix(rt, b)
            else l, r = mix(l, a), mix(r, b) end
        end
    end
    if done then
        for _, v in ipairs(done) do
            if voices[v.id] == v then voices[v.id] = nil end
            if v.onDone then v.onDone(v) end
        end
    end
    return l, r, lt, rt, raw, any
end

driver:SetScript("OnUpdate", function()
    local now = Now()
    local db = H.DB()
    out.last = now
    -- (a probe or the calibration ramp has the motors and the light)
    if H.hold then return end
    local l, r, lt, rt, raw, any = H.Mix(now)
    -- Calibration (not for a probe's raw levels), the battery
    if not raw then
        local battery = H.BatteryFactor()
        l, r = H.Calibrated(1, l * battery), H.Calibrated(2, r * battery)
        lt, rt = clamp(lt * battery), clamp(rt * battery)
        -- Shortest pulse: a side that rose from rest stays up at least db.minPulse
        -- (taps under ~50 ms were felt only some of the time)
        if (db.minPulse or 0) > 0 then
            if l > 0 and out.l <= 0 then out.pulseL = now end
            if r > 0 and out.r <= 0 then out.pulseR = now end
            if l > 0 then out.lastL = l elseif out.l > 0 and now - (out.pulseL or 0) < db.minPulse then l = out.lastL or out.l end
            if r > 0 then out.lastR = r elseif out.r > 0 and now - (out.pulseR or 0) < db.minPulse then r = out.lastR or out.r end
        end
        -- Overdrive: a side starting from rest begins at full for db.kick s
        if (db.kick or 0) > 0 then
            if l > 0 and out.l <= 0 then out.riseL = now end
            if r > 0 and out.r <= 0 then out.riseR = now end
            if l > 0 and now - out.riseL < db.kick then l = 1 end
            if r > 0 and now - out.riseR < db.kick then r = 1 end
        end
        if db.triggers == "mirror" then lt, rt = max(lt, l), max(rt, r)
        elseif db.triggers == "only" then lt, rt, l, r = max(lt, l), max(rt, r), 0, 0 end
    end
    out.l, out.r, out.lt, out.rt = l, r, lt, rt
    head = head % HISTORY + 1
    history[head][1], history[head][2] = l, r
    -- Sends limited to db.rate a second; a side starting from rest is never
    -- held back (a short pulse between two sends would be lost)
    local gated = (db.rate or 0) > 0 and now - out.sentAt < 1 / db.rate
    if l <= 0 and r <= 0 and lt <= 0 and rt <= 0 then
        -- (the stop waits for the next send: the pulse lasts that long)
        if not out.quiet and gated then
            H.LightTick(now)
            return
        end
        if not out.quiet then
            Silence()
            out.quiet = true
            out.sentL, out.sentR, out.sentLT, out.sentRT = -1, -1, -1, -1
        end
        if not any and not H.LightsBusy() then driver:Hide() end
        H.LightTick(now)
        return
    end
    out.quiet = false
    local rising = (l > 0 and out.sentL <= 0) or (r > 0 and out.sentR <= 0)
        or (lt > 0 and out.sentLT <= 0) or (rt > 0 and out.sentRT <= 0)
    if gated and not rising then
        H.LightTick(now)
        return
    end
    local keep = (db.keepAlive or 0) > 0 and now - out.sentAt >= db.keepAlive
    local step = 1 / 255
    if keep or abs(l - out.sentL) > step or abs(r - out.sentR) > step then
        Send("Low", l)
        Send("High", r)
        out.sentL, out.sentR = l, r
        out.sentAt = now
        out.sends = out.sends + 1
        sendTimes[#sendTimes + 1] = now
    end
    if keep or abs(lt - out.sentLT) > step or abs(rt - out.sentRT) > step then
        if lt > 0 or out.sentLT > 0 then Send("LTrigger", lt) end
        if rt > 0 or out.sentRT > 0 then Send("RTrigger", rt) end
        out.sentLT, out.sentRT = lt, rt
    end
    H.LightTick(now)
end)

-- The live view: history (oldest first) and sends in the last second
function H.History()
    local list = {}
    for i = 1, HISTORY do
        local h = history[(head + i - 1) % HISTORY + 1]
        list[i] = h
    end
    return list
end

function H.SendRate()
    local now = Now()
    while sendTimes[1] and now - sendTimes[1] > 1 do table.remove(sendTimes, 1) end
    return #sendTimes
end

---------------------------------------------------------------------------
-- The light bar
---------------------------------------------------------------------------
local lights = {}
local led = { r = -1, g = -1, b = -1, set = false, at = 0 }

local function LedSend(r, g, b)
    if not (C_GamePad and C_GamePad.SetLedColor) then return false end
    local color = CreateColor and CreateColor(r, g, b, 1)
    if color and pcall(C_GamePad.SetLedColor, color) then return true end
    return pcall(C_GamePad.SetLedColor, r, g, b)
end

local function LedClear()
    if C_GamePad and C_GamePad.ClearLedColor then pcall(C_GamePad.ClearLedColor) end
end
-- (outside the mixer: what it last sent no longer holds)
function H.LedSend(r, g, b)
    led.r, led.g, led.b, led.set = -1, -1, -1, true
    return LedSend(r, g, b)
end
function H.LedClear()
    led.r, led.g, led.b, led.set = -1, -1, -1, false
    LedClear()
end

-- A light voice: fn(now, voice) gives r, g, b (0-1) or nil when done; the
-- highest prio playing wins
function H.Light(id, fn, prio)
    lights[id] = { id = id, fn = fn, prio = prio or 1, start = Now() }
    Wake()
end

function H.LightStop(id)
    if id == nil then wipe(lights) else lights[id] = nil end
    Wake()
end

-- A colour flashing up and fading out over seconds
function H.Flash(id, r, g, b, seconds, prio)
    seconds = seconds or 0.8
    H.Light(id, function(now, v)
        local t = (now - v.start) / seconds
        if t >= 1 then return nil end
        local k = (1 - t) ^ 1.5
        return r * k, g * k, b * k
    end, prio or 5)
end

function H.LightsBusy()
    return next(lights) ~= nil or led.set
end

function H.LightTick(now)
    if now - led.at < 1 / 30 then return end
    led.at = now
    local best, br, bg, bb
    for id, v in pairs(lights) do
        local r, g, b = v.fn(now, v)
        if r == nil then
            lights[id] = nil
        elseif not best or v.prio > best.prio then
            best, br, bg, bb = v, r, g, b
        end
    end
    if not best then
        if led.set then
            LedClear()
            led.set, led.r, led.g, led.b = false, -1, -1, -1
        end
        return
    end
    br, bg, bb = clamp(br), clamp(bg), clamp(bb)
    local step = 2 / 255
    if abs(br - led.r) > step or abs(bg - led.g) > step or abs(bb - led.b) > step then
        LedSend(br, bg, bb)
        led.r, led.g, led.b, led.set = br, bg, bb, true
    end
end

---------------------------------------------------------------------------
-- Feels by key: the library (HapticsLab.lua) and the player's own
---------------------------------------------------------------------------
H.LIBRARY = {}
local LIB = {}

function H.AddLibrary(key, feel)
    feel.key = key
    if not LIB[key] then H.LIBRARY[#H.LIBRARY + 1] = feel end
    LIB[key] = feel
end

function H.Feel(key)
    if not key then return nil end
    local own = H.DB().feels[key]
    if type(own) == "table" then return own end
    return LIB[key]
end

-- Every feel: the library, then the player's own (sorted by name)
function H.AllFeels()
    local list = {}
    for _, f in ipairs(H.LIBRARY) do list[#list + 1] = f end
    local own = {}
    for key, f in pairs(H.DB().feels) do
        if type(f) == "table" then f.key = key; own[#own + 1] = f end
    end
    table.sort(own, function(a, b) return (a.label or a.key) < (b.label or b.key) end)
    for _, f in ipairs(own) do list[#list + 1] = f end
    return list
end

function H.IsOwn(key) return type(H.DB().feels[key]) == "table" end

-- A new key for the player's own feel
function H.NewKey()
    local feels, n = H.DB().feels, 1
    while feels["own" .. n] do n = n + 1 end
    return "own" .. n
end

---------------------------------------------------------------------------
-- Sharing: a feel as a line of text, and back (no code is run)
---------------------------------------------------------------------------
local function Encode(v)
    local kind = type(v)
    if kind == "number" then
        local s = string.format("%.4g", v)
        return s
    elseif kind == "boolean" then
        return v and "T" or "F"
    elseif kind == "string" then
        return "'" .. v:gsub("[%c'\\|]", "") .. "'"
    elseif kind == "table" then
        local parts = {}
        local n = #v
        for i = 1, n do parts[#parts + 1] = Encode(v[i]) end
        local keys = {}
        for k in pairs(v) do
            if type(k) == "string" and k ~= "key" then keys[#keys + 1] = k end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            if k:match("^[%a_][%w_]*$") then parts[#parts + 1] = k .. "=" .. Encode(v[k]) end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "F"
end

function H.Export(feel) return "GPCF1:" .. Encode(feel) end

local function Decoder(s)
    local pos = 1
    local Value
    local function skip() pos = s:find("[^%s]", pos) or #s + 1 end
    local function table_()
        pos = pos + 1
        local t, n = {}, 0
        while true do
            skip()
            local c = s:sub(pos, pos)
            if c == "}" then pos = pos + 1; return t end
            if c == "" then error("unclosed") end
            local name = s:match("^([%a_][%w_]*)=", pos)
            if name then
                pos = pos + #name + 1
                t[name] = Value()
            else
                n = n + 1
                t[n] = Value()
            end
            skip()
            if s:sub(pos, pos) == "," then pos = pos + 1 end
        end
    end
    Value = function()
        skip()
        local c = s:sub(pos, pos)
        if c == "{" then return table_() end
        if c == "'" then
            local close = s:find("'", pos + 1, true)
            if not close then error("unclosed string") end
            local v = s:sub(pos + 1, close - 1)
            pos = close + 1
            return v
        end
        if c == "T" then pos = pos + 1; return true end
        if c == "F" then pos = pos + 1; return false end
        local num = s:match("^-?[%d%.]+[eE]?[-+]?%d*", pos)
        if num and tonumber(num) then pos = pos + #num; return tonumber(num) end
        error("bad value at " .. pos)
    end
    return Value
end

-- A feel from text (nil, why: not one)
function H.Import(text)
    if type(text) ~= "string" then return nil, "empty" end
    local body = text:match("GPCF1:(%b{})")
    if not body then return nil, "not a feel" end
    local ok, feel = pcall(function() return Decoder(body)() end)
    if not ok or type(feel) ~= "table" then return nil, "unreadable" end
    return H.Clean(feel)
end

-- Only known fields, in range (an imported or recorded feel)
local NUM = { attack = { 0, 10 }, hold = { 0, 10 }, decay = { 0, 10 }, peak = { 0, 1 }, curve = { 0.2, 5 },
    noise = { 0, 1 }, sparks = { 0, 60 }, bed = { 0, 1 }, pan = { -1, 1 }, panTo = { -1, 1 }, panRate = { 0, 20 },
    panDepth = { 0, 1 }, kick = { 0, 0.2 }, gap = { 0, 5 }, length = { 0, 30 } }
local WAVES = { sine = true, square = true, saw = true, ramp = true, tri = true }
function H.Clean(src)
    local f = { label = type(src.label) == "string" and src.label:sub(1, 24) or "Imported", loop = src.loop == true }
    for k, range in pairs(NUM) do
        local v = tonumber(src[k])
        if v then f[k] = max(range[1], min(range[2], v)) end
    end
    if type(src.grain) == "table" then
        local g = src.grain
        f.grain = { rate = max(0, min(80, tonumber(g.rate) or 0)), depth = clamp(tonumber(g.depth) or 0),
            wave = WAVES[g.wave] and g.wave or "sine", duty = clamp(tonumber(g.duty) or 0.5),
            alternate = g.alternate == true }
        if tonumber(g.rateTo) then f.grain.rateTo = max(0, min(80, tonumber(g.rateTo))) end
    end
    if type(src.duck) == "table" then
        f.duck = { amount = clamp(tonumber(src.duck.amount) or 0), time = max(0, min(2, tonumber(src.duck.time) or 0.2)) }
    end
    if type(src.pulses) == "table" then
        local list = {}
        for i = 1, min(#src.pulses, 200) do
            local p = src.pulses[i]
            if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) then
                list[#list + 1] = { max(0, min(30, tonumber(p[1]))), max(0.02, min(5, tonumber(p[2]))),
                    clamp(tonumber(p[3]) or 1), max(-1, min(1, tonumber(p[4]) or 0)) }
            end
        end
        if #list == 0 then return nil, "no pulses" end
        table.sort(list, function(a, b) return a[1] < b[1] end)
        f.pulses = list
    elseif type(src.keys) == "table" then
        f.keys = {}
        for _, side in ipairs({ "left", "right" }) do
            local list = src.keys[side]
            if type(list) == "table" then
                local clean = {}
                for i = 1, min(#list, 400) do
                    local k = list[i]
                    if type(k) == "table" and tonumber(k[1]) and tonumber(k[2]) then
                        clean[#clean + 1] = { max(0, min(30, tonumber(k[1]))), clamp(tonumber(k[2])),
                            EASE[k[3]] and k[3] or nil, i }
                    end
                end
                -- (stable: two keys at one moment make a step, in their order)
                table.sort(clean, function(a, b)
                    if a[1] ~= b[1] then return a[1] < b[1] end
                    return a[4] < b[4]
                end)
                for _, k in ipairs(clean) do k[4] = nil end
                f.keys[side] = clean
            end
        end
        if not f.keys.left then return nil, "no keys" end
    elseif not (f.attack or f.hold or f.decay) then
        return nil, "no shape"
    end
    return f
end

---------------------------------------------------------------------------
-- Recording: a stream of samples to keyframes (Ramer-Douglas-Peucker)
---------------------------------------------------------------------------
function H.Simplify(points, tolerance)
    tolerance = tolerance or 0.03
    if #points <= 2 then return points end
    local keep = { [1] = true, [#points] = true }
    local function walk(a, b)
        local pa, pb = points[a], points[b]
        local worst, index = 0, nil
        local span = pb[1] - pa[1]
        for i = a + 1, b - 1 do
            local p = points[i]
            local x = span > 0 and (p[1] - pa[1]) / span or 0
            local d = abs(p[2] - (pa[2] + (pb[2] - pa[2]) * x))
            if d > worst then worst, index = d, i end
        end
        if index and worst > tolerance then
            keep[index] = true
            walk(a, index)
            walk(index, b)
        end
    end
    walk(1, #points)
    local list = {}
    for i = 1, #points do if keep[i] then list[#list + 1] = { points[i][1], points[i][2] } end end
    return list
end
