-- Timing: feels in step with the game (docs/TIMING.md). One place for the
-- offsets (the blow's impact after a swing's news, per model, form, kind of
-- weapon and hand), the one R2 / L2 sync every feature shares (footsteps,
-- mining, hits), and the link lead (WoW Helper's addon-to-pad latency,
-- taken off whatever is scheduled ahead). Values are kept in game time;
-- the lead is applied only when scheduling.
local _, ns = ...
local H = ns.Haptics
local T = {}
ns.Timing = T

local min, max, floor, abs = math.min, math.max, math.floor, math.abs
local function Now() return GetTime and GetTime() or 0 end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

---------------------------------------------------------------------------
-- Offsets: seconds from a swing's news (UNIT_COMBAT) to its impact. The
-- attack animation doesn't scale with weapon speed, unless the swing comes
-- round sooner than the animation lasts: then it plays faster, the impact
-- in proportion (T.Impact). Defaults per kind of weapon; a model's factor
-- (1 until measured); learned values (WoW Helper's slot); yours on top.
---------------------------------------------------------------------------
-- (measured by WoW Helper, 2026-11-17: a two-hander's impact heard 0.165 s
-- after the swing's news (24 hits, IQR 0.14-0.19), not the 0.35 guessed;
-- the other kinds scaled alike, x0.47)
T.KINDS = {
    { key = "dagger", label = "Dagger", delay = 0.095, anim = 1.0 },
    { key = "oneHand", label = "One-hand", delay = 0.12, anim = 1.2 },
    { key = "twoHand", label = "Two-hand", delay = 0.165, anim = 1.5 },
    { key = "polearm", label = "Polearm", delay = 0.15, anim = 1.5 },
    { key = "staff", label = "Staff", delay = 0.14, anim = 1.4 },
    { key = "fist", label = "Fist", delay = 0.095, anim = 1.0 },
    { key = "unarmed", label = "Unarmed", delay = 0.095, anim = 1.0 },
    { key = "form", label = "Form", delay = 0.095, anim = 1.0 },
    { key = "ranged", label = "Ranged", delay = 0, anim = 1.0 },
}
local KIND = {}
for _, k in ipairs(T.KINDS) do KIND[k.key] = k end
T.KIND = KIND
-- (a model's animations against the default, by "race id-sex": none
-- measured yet; WoW Helper's learned values take over per key)
T.MODEL_FACTOR = {}

-- (the guesses before WoW Helper measured them: a saved value equal to one
-- is that guess, kept by touching the control, not a choice; it goes, once,
-- so the measured default and the learned values can apply)
T.OLD_GUESS = { dagger = 0.2, oneHand = 0.25, twoHand = 0.35, polearm = 0.32, staff = 0.3, fist = 0.2, unarmed = 0.2,
    form = 0.2 }

function T.Store()
    local db = H.DB()
    if type(db.timing) ~= "table" then db.timing = {} end
    local t = db.timing
    t.set = t.set or {}
    t.learned = t.learned or {}
    t.log = t.log or {}
    if (t.guesses or 1) < 2 then
        for key, v in pairs(t.set) do
            local kind = type(key) == "string" and key:match("|([%a]+)|")
            if kind and T.OLD_GUESS[kind] and type(v) == "number" and abs(v - T.OLD_GUESS[kind]) < 1e-6 then t.set[key] = nil end
        end
        t.guesses = 2
    end
    -- (timing is WoW Helper's now, one place (the design audit, D3/D4): the
    -- values once synced or set here go, once, so what it learns applies)
    if t.guesses < 3 then
        for k in pairs(t.set) do t.set[k] = nil end
        db.stepSync = nil
        t.guesses = 3
    end
    return t
end

-- A timing default as WoW Helper publishes it (one table for both programs:
-- WowHelperData.timingDefaults: mining { first, period, crack }, run and walk
-- { rate, offset, speed }); nil without WoW Helper (the addon's own fallback)
function T.Default(name)
    local d = _G.WowHelperData
    local t = type(d) == "table" and type(d.timingDefaults) == "table" and d.timingDefaults[name]
    return type(t) == "table" and t or nil
end

-- The model: race id and sex ("1-2"), the shapeshift form when one ("1-2-f5")
function T.Model()
    local race = UnitRace and select(3, UnitRace("player")) or 0
    local sex = UnitSex and UnitSex("player") or 0
    local model = tostring(race) .. "-" .. tostring(sex)
    local form = type(GetShapeshiftFormID) == "function" and GetShapeshiftFormID() or nil
    if form and not secret(form) and form ~= 0 then model = model .. "-f" .. tostring(form) end
    return model
end

function T.Key(kind, hand) return T.Model() .. "|" .. kind .. "|" .. (hand or "main") end

function T.Label(kind) return KIND[kind] and KIND[kind].label or tostring(kind) end

-- An offset (seconds, game time) and where it comes from: "set", "learned", "guess"
function T.Offset(kind, hand)
    local store = T.Store()
    local key = T.Key(kind, hand)
    if type(store.set[key]) == "number" then return store.set[key], "set" end
    -- (WoW Helper's keys are race-sex|kind|hand, no form)
    local l = store.learned[key] or store.learned[(key:gsub("%-f%d+|", "|", 1))]
    if type(l) == "table" and type(l.v) == "number" then return l.v, "learned", l.hits end
    local k = KIND[kind] or KIND.oneHand
    local model = T.Model():match("^(%d+%-%d+)") or ""
    -- (the default: WoW Helper's published table (one, night review H10), else the copy here)
    local hits = T.Default("hits")
    local delay = hits and tonumber(hits[kind]) or k.delay
    return delay * (T.MODEL_FACTOR[model] or 1), "guess"
end

function T.Set(kind, hand, seconds)
    T.Store().set[T.Key(kind, hand)] = max(-0.5, min(1, seconds))
end

function T.Clear(kind, hand) T.Store().set[T.Key(kind, hand)] = nil end

-- WoW Helper's slot (it may hear the game's hit sounds one day): needs a
-- shared clock before it can be trusted
function T.Learn(key, seconds, hits)
    T.Store().learned[key] = { v = seconds, hits = hits, at = date and date("%Y-%m-%d %H:%M") or "" }
end

-- WoW Helper's data addon (WowHelperData, written by the helper, read at
-- load): its confident hit delays (hitOffsets) and the link's latency
-- Each load mirrors WowHelperData exactly: what it learned replaces what was
-- read before (a Reset in WoW Helper drops a key; it goes here too, and is
-- no longer sent back to it as the addon's delay)
function T.LoadHelper()
    local store = T.Store()
    store.learned, store.strikes = {}, {}
    local d = _G.WowHelperData
    if type(d) ~= "table" then
        store.linkLatency, store.link, store.padDelay = nil, nil, nil
        return 0
    end
    local n = 0
    if type(d.hitOffsets) == "table" then
        for key, v in pairs(d.hitOffsets) do
            if type(key) == "string" and type(v) == "table" and type(v.delay) == "number" then
                T.Learn(key, v.delay, tonumber(v.hits))
                n = n + 1
            end
        end
    end
    if type(d.strikeTiming) == "table" then
        local strikes = store.strikes
        for key, v in pairs(d.strikeTiming) do
            if type(key) == "string" and type(v) == "table" and type(v.first) == "number" and type(v.period) == "number" then
                strikes[key] = { first = v.first, period = v.period, strikes = tonumber(v.strikes) }
                n = n + 1
            end
        end
    end
    -- (absent: cleared, as the link and the pad delay are: a stale Bluetooth
    -- latency mustn't outlive a switch to USB)
    T.SetLinkLatency(type(d.linkLatency) == "number" and d.linkLatency or nil)
    -- the pad's link (USB, Bluetooth) and its pad delay, as WoW Helper found them
    T.Store().link = (d.link == "usb" or d.link == "bt") and d.link or nil
    T.Store().padDelay = (type(d.padDelay) == "number" and d.padDelay > 0) and min(0.2, d.padDelay) or nil
    return n
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name) if name == "GamepadCompanion" then T.LoadHelper() end end)

-- The impact after the news: the offset, in proportion when the swing comes
-- round sooner than the animation (interval: the live swing time)
-- WoW Helper's learned strikes for a gathering action (this race and sex),
-- { first, period, strikes } or nil
function T.LearnedStrikes(action)
    local strikes = T.Store().strikes
    if type(strikes) ~= "table" then return nil end
    local base = T.Model():match("^(%d+%-%d+)") or ""
    local s = strikes[base .. "|" .. action]
    if type(s) == "table" and type(s.first) == "number" and type(s.period) == "number" and s.period > 0.2 then return s end
    return nil
end

function T.Impact(kind, hand, interval)
    local off = T.Offset(kind, hand)
    local anim = (KIND[kind] or KIND.oneHand).anim
    if interval and interval > 0 and interval < anim then off = off * interval / anim end
    return off
end

---------------------------------------------------------------------------
-- The link lead: with WoW Helper on, its measured addon-to-pad latency is
-- taken off whatever the addon schedules ahead (WoW Helper reports it:
-- T.SetLinkLatency). Feels sent at once can't go out early.
---------------------------------------------------------------------------
-- WoW Helper's link to the pad: "usb", "bt" or nil (not read yet)
function T.Link() return T.Store().link end

function T.SetLinkLatency(seconds)
    T.Store().linkLatency = (type(seconds) == "number" and seconds > 0) and min(0.5, seconds) or nil
end

-- (the game's own vibration lands a little after SetVibration: up to a
-- frame, ~16 ms, and Bluetooth, ~12 ms; WoW Helper's: the strip drawn and
-- read, its air and actuator, until it publishes what it measured: the
-- whole link once it has cues, else its pad delay for the link, USB or BT)
-- (over USB, as WoW Helper found the pad: no Bluetooth part, a frame and the poll)
T.MOTOR_LEAD, T.LINK_DEFAULT, T.MOTOR_LEAD_USB = 0.03, 0.03, 0.018
local function MotorLead()
    if T.Store().link == "usb" then return min(T.MOTOR_LEAD, T.MOTOR_LEAD_USB) end
    return T.MOTOR_LEAD
end
function T.Lead()
    local K = ns.HelperLink
    if K and K.Enabled and K.Enabled() then
        local s = T.Store()
        return max(MotorLead(), s.linkLatency or s.padDelay or T.LINK_DEFAULT)
    end
    return MotorLead()
end

-- fn after delay seconds (game time), less the lead; at once when that's 0
-- or less
function T.After(delay, fn)
    local d = (delay or 0) - T.Lead()
    if d <= 0 or not (C_Timer and C_Timer.After) then return fn() end
    C_Timer.After(d, fn)
end

---------------------------------------------------------------------------
-- The one sync: a single watcher of R2 / L2 for whichever feature syncs
-- (footsteps, mining, hits): opts = { name, onTap(now), onUpdate(now),
-- onStop(cancelled) }. One at a time: starting one stops the other.
---------------------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:Hide()
T.watcher = watcher
local active, down = nil, false

function T.StartSync(opts)
    if active then T.StopSync(nil, true) end
    active, down = opts, false
    watcher:Show()
end

-- Stop (name: only if that one is running); cancelled: told to it
function T.StopSync(name, cancelled)
    if not active or (name and active.name ~= name) then return end
    local was = active
    active = nil
    watcher:Hide()
    if was.onStop then was.onStop(cancelled and true or false) end
end

function T.Syncing(name)
    if not active then return nil end
    if name then return active.name == name and active or nil end
    return active
end

-- A squeeze (the watcher's; tests call it)
function T.Tap(now)
    if active and active.onTap then active.onTap(now or Now()) end
end

watcher:SetScript("OnUpdate", function()
    if not active then return watcher:Hide() end
    local now = Now()
    if active.onUpdate then active.onUpdate(now) end
    if not active then return end
    local L = ns.HapticsLab
    local l, r
    if L and L.TriggerAxes then l, r = L.TriggerAxes() end
    local depth = max(l or 0, r or 0)
    if not down and depth > 0.5 then
        down = true
        T.Tap(now)
    elseif down and depth < 0.2 then
        down = false
    end
end)

---------------------------------------------------------------------------
-- Fitting squeezes to news: each tap paired with the nearest news within
-- half an interval, before or after it (the news may come late too: a
-- signed delay); the median, unless they spread too wide
---------------------------------------------------------------------------
T.SPREAD = 0.12

function T.PairTaps(anchors, taps, interval)
    local half = (interval or 1) / 2
    local delays = {}
    for _, t in ipairs(taps) do
        local best
        for _, a in ipairs(anchors) do
            local d = t - a
            if abs(d) <= half and (not best or abs(d) < abs(best)) then best = d end
        end
        if best then delays[#delays + 1] = best end
    end
    return delays
end

local function Median(list)
    local c = {}
    for i, v in ipairs(list) do c[i] = v end
    table.sort(c)
    if #c == 0 then return nil end
    if #c % 2 == 1 then return c[(#c + 1) / 2] end
    return (c[#c / 2] + c[#c / 2 + 1]) / 2
end
T.Median = Median

-- The delay from paired squeezes, or nil and why ("few", "uneven"): the
-- closest 70% (at least need) around the median, their median, unless even
-- those spread wider than T.SPREAD (a hand's squeezes wander; one stray
-- squeeze must not spoil the rest)
function T.FitDelay(delays, need)
    need = need or 5
    if #delays < need then return nil, "few" end
    local m = Median(delays)
    local byDev = {}
    for i, d in ipairs(delays) do byDev[i] = d end
    table.sort(byDev, function(x, y) return abs(x - m) < abs(y - m) end)
    local keep = {}
    for i = 1, max(need, math.ceil(#delays * 0.7)) do keep[i] = byDev[i] end
    local m2 = Median(keep)
    local dev = {}
    for i, d in ipairs(keep) do dev[i] = abs(d - m2) end
    if Median(dev) > T.SPREAD then return nil, "uneven" end
    return m2
end

-- The raw pairs, kept for a look (the news against the sound you heard)
function T.Log(line)
    local log = T.Store().log
    log[#log + 1] = line
    while #log > 60 do table.remove(log, 1) end
end

-- (Rumble loads first: its list of kinds is this one)
if ns.Rumble then ns.Rumble.HIT_KINDS = T.KINDS end
