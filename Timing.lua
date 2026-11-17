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
T.KINDS = {
    { key = "dagger", label = "Dagger", delay = 0.2, anim = 1.0 },
    { key = "oneHand", label = "One-hand", delay = 0.25, anim = 1.2 },
    { key = "twoHand", label = "Two-hand", delay = 0.35, anim = 1.5 },
    { key = "polearm", label = "Polearm", delay = 0.32, anim = 1.5 },
    { key = "staff", label = "Staff", delay = 0.3, anim = 1.4 },
    { key = "fist", label = "Fist", delay = 0.2, anim = 1.0 },
    { key = "unarmed", label = "Unarmed", delay = 0.2, anim = 1.0 },
    { key = "form", label = "Form", delay = 0.2, anim = 1.0 },
    { key = "ranged", label = "Ranged", delay = 0, anim = 1.0 },
}
local KIND = {}
for _, k in ipairs(T.KINDS) do KIND[k.key] = k end
T.KIND = KIND
-- (a model's animations against the default, by "race id-sex": none
-- measured yet; WoW Helper's learned values take over per key)
T.MODEL_FACTOR = {}

function T.Store()
    local db = H.DB()
    if type(db.timing) ~= "table" then db.timing = {} end
    local t = db.timing
    t.set = t.set or {}
    t.learned = t.learned or {}
    t.log = t.log or {}
    return t
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
    local l = store.learned[key]
    if type(l) == "table" and type(l.v) == "number" then return l.v, "learned" end
    local k = KIND[kind] or KIND.oneHand
    local model = T.Model():match("^(%d+%-%d+)") or ""
    return k.delay * (T.MODEL_FACTOR[model] or 1), "guess"
end

function T.Set(kind, hand, seconds)
    T.Store().set[T.Key(kind, hand)] = max(-0.5, min(1, seconds))
end

function T.Clear(kind, hand) T.Store().set[T.Key(kind, hand)] = nil end

-- WoW Helper's slot (it may hear the game's hit sounds one day): needs a
-- shared clock before it can be trusted
function T.Learn(key, seconds)
    T.Store().learned[key] = { v = seconds, at = date and date("%Y-%m-%d %H:%M") or "" }
end

-- The impact after the news: the offset, in proportion when the swing comes
-- round sooner than the animation (interval: the live swing time)
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
function T.SetLinkLatency(seconds)
    T.Store().linkLatency = (type(seconds) == "number" and seconds > 0) and min(0.5, seconds) or nil
end

function T.Lead()
    local K = ns.HelperLink
    if not (K and K.Enabled and K.Enabled()) then return 0 end
    return T.Store().linkLatency or 0
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
