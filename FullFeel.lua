-- Full feels (Migration\full-feel-plan-2026-11-18.md, steps 5 and 6). No mode switch: a
-- moment's active full feel decides. WoW Helper publishes a plain version only for moments
-- with an active full feel (HD vibration, sound, light on one timeline); the addon keeps
-- when, and plays the plain version as a backup: WowHelperData.plain[momentKey] = { name,
-- hd = true, rumble = { { t, left, right }, ... } (at most 16 points, seconds, 0-1),
-- light = { r, g, b, t } }. A moment without one plays exactly as before.
--
-- Nothing is written: events, lightEvents, link.sounds, spells and the profiles are read,
-- never rewritten. (0.55's feelMode setting is left as it is and ignored.)
local _, ns = ...
local F = {}
ns.FullFeel = F

F.MAX_POINTS = 16


-- WoW Helper can play HD now: a PlayStation pad (HD, speaker, lights and triggers are
-- DualSense only) and the link on. An Xbox pad: the game's rumble at full.
function F.PlayStation()
    local G = C_GamePad
    if not (G and G.GetDeviceMappedState) then return false end
    local ok, state = pcall(G.GetDeviceMappedState, G.GetActiveDeviceID and G.GetActiveDeviceID() or nil)
    return ok and type(state) == "table" and state.labelStyle == "Shapes" or false
end
function F.HelperPlaysHD()
    local K = ns.HelperLink
    return F.PlayStation() and K ~= nil and K.Enabled ~= nil and K.Enabled() and true or false
end

-- A moment's plain entry as WoW Helper wrote it (nil: none, it plays as before). A moment
-- under another ("gather:mining") has its parent's until it has its own.
function F.Entry(key)
    local d = WowHelperData
    local plain = type(d) == "table" and type(d.plain) == "table" and d.plain
    if not (plain and type(key) == "string") then return nil end
    local e = plain[key]
    if type(e) == "table" then return e end
    local V = ns.Rumble
    if V and V.GatherOf and V.GatherOf(key) then return F.Entry("gather") end
    return nil
end

-- The entry that plays now: whenever there is one
function F.Plain(key) return F.Entry(key) end

-- A full feel's name (nil: none for this moment)
function F.Name(key)
    local e = F.Entry(key)
    return e and type(e.name) == "string" and e.name ~= "" and e.name or nil
end

local function Clamp(v) return math.max(0, math.min(1, tonumber(v) or 0)) end

-- An entry's rumble, checked: points { t, left, right } in time order (at most 16), or nil
function F.Points(e)
    local list = type(e) == "table" and type(e.rumble) == "table" and e.rumble
    if not list then return nil end
    local out, last = {}, -1
    for i = 1, math.min(#list, F.MAX_POINTS) do
        local p = list[i]
        local t = type(p) == "table" and tonumber(p[1])
        if not t or t < last or t > 30 then return nil end
        last = t
        out[#out + 1] = { t, Clamp(p[2]), Clamp(p[3]) }
    end
    return #out > 0 and out or nil
end

-- The rumble at `t` s into the points (straight lines between them, from silence at 0
-- when the first is later), or nil once past the last
function F.Sample(points, t)
    local last = points[#points]
    if t > last[1] then return nil end
    local prev = { 0, 0, 0 }
    for _, p in ipairs(points) do
        if t <= p[1] then
            local span = p[1] - prev[1]
            local k = span > 0 and (t - prev[1]) / span or 1
            return prev[2] + (p[2] - prev[2]) * k, prev[3] + (p[3] - prev[3]) * k
        end
        prev = p
    end
    return last[2], last[3]
end

-- The plain rumble a moment plays now: its points and its scale (faint under HD, only while
-- WoW Helper can play it: F.HelperPlaysHD), or nil (no plain rumble for it)
function F.Rumble(key)
    local e = F.Plain(key)
    local points = e and F.Points(e)
    if not points then return nil end
    -- (always at full: while WoW Helper drives the pad, the DualSense plays only its HD and
    -- this is not felt; with WoW Helper closed it is the backup, felt in full. Tested in game
    -- 2026-11-19)
    return points, 1
end

-- A shape for Rumble's shaper: the points once from `start` (loop: over and over), scaled
function F.Shape(points, scale, start, loop)
    local length = points[#points][1]
    return function(now)
        local t = now - start
        if loop and length > 0 then t = t % length end
        local l, r = F.Sample(points, t)
        if not l then return nil end
        return l * scale, r * scale
    end
end

-- The plain bar colour a moment plays now: r, g, b (0-1) and seconds, or nil
function F.Light(key)
    local e = F.Plain(key)
    local l = e and type(e.light) == "table" and e.light
    if not l then return nil end
    local t = tonumber(l[4]) or 0.8
    if t <= 0 then return nil end
    return Clamp(l[1]), Clamp(l[2]), Clamp(l[3]), math.min(t, 10)
end
