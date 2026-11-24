-- NodeSense: names the minimap's node dots for WoW Helper's node compass, so its arrows can say
-- what each node is (Mithril, Iron, an herb) and dim the ones you aren't after or can't gather.
-- With a mouse the minimap's tooltip names a dot; with a pad nothing hovers it. But the Forever
-- client has Minimap:UpdateMouseoverAtPoint (made for the gamepad soft cursor) and
-- C_TooltipInfo.GetMinimapMouseover: a hidden sweep "hovers" a grid over the minimap, a few
-- dozen points a frame, reads the names under each point, and groups the hits into dots. Only
-- the live dots, never a database (the user's rule). The dots go to the helper in the node row
-- (HelperLink.lua, docs: the helper's NODE-COMPASS.md): up to 6, each with its place on the
-- minimap, its kind, wanted (the kind you look for: /gpc ore mithril) and gatherable (your
-- skill). Experimental: the point's units aren't documented, so the sweep tries each likely
-- reading (S.READINGS) and keeps the one that finds dots; where two readings both find them (a
-- mirror), the way the dots slide as you walk picks the right one. Every step is written to
-- GamepadCompanionTraceDB.nodes; /gpc nodes prints it.
-- Pure: S.Kind, S.Cluster, S.Pick, S.Expected, S.Agree (tests/NodeSense.lua)
local _, ns = ...
local Sh = ns.Shared
local S = {}
ns.NodeSense = S

local floor, sqrt, cos, sin = math.floor, math.sqrt, math.cos, math.sin

---------------------------------------------------------------------------
-- What a name is (pure)
---------------------------------------------------------------------------
-- Ores: the name (lowercase, "ooze covered " dropped), the row's kind, the skill it needs, the
-- word for /gpc ore
S.ORES = {
    { "copper vein", 1, 1, "copper" }, { "tin vein", 2, 65, "tin" }, { "silver vein", 3, 75, "silver" },
    { "iron deposit", 4, 125, "iron" }, { "gold vein", 5, 155, "gold" }, { "mithril deposit", 6, 175, "mithril" },
    { "truesilver deposit", 7, 230, "truesilver" }, { "dark iron deposit", 8, 230, "darkiron" },
    { "small thorium vein", 9, 245, "thorium" }, { "rich thorium vein", 10, 275, "richthorium" },
    { "incendicite mineral vein", 11, 65, "incendicite" }, { "lesser bloodstone deposit", 12, 75, "bloodstone" },
    { "indurium mineral vein", 13, 150, "indurium" },
}
-- Herbs (classic): the name and the skill; all kind 32 on the row, wanted by their own word
S.HERBS = {
    { "peacebloom", 1 }, { "silverleaf", 1 }, { "earthroot", 15 }, { "mageroyal", 50 }, { "briarthorn", 70 },
    { "stranglekelp", 85 }, { "bruiseweed", 100 }, { "wild steelbloom", 115 }, { "grave moss", 120 },
    { "kingsblood", 125 }, { "liferoot", 150 }, { "fadeleaf", 160 }, { "goldthorn", 170 },
    { "khadgar's whisker", 185 }, { "wintersbite", 195 }, { "firebloom", 205 }, { "purple lotus", 210 },
    { "arthas' tears", 220 }, { "sungrass", 230 }, { "blindweed", 235 }, { "ghost mushroom", 245 },
    { "gromsblood", 250 }, { "golden sansam", 260 }, { "dreamfoil", 270 }, { "mountain silversage", 280 },
    { "plaguebloom", 285 }, { "icecap", 290 }, { "black lotus", 300 },
}
S.HERB, S.TREASURE = 32, 48

local function Word(name) return (name:gsub("[%s'%-]", "")) end

-- A tooltip line's node: { kind, skill, word, name }, or nil (a player's name, a quest mark).
-- tracking: 1 minerals, 2 herbs, 3 treasure (NodeCompass.Tracking)
function S.Kind(line, tracking)
    if type(line) ~= "string" or line == "" then return nil end
    local low = line:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    low = low:gsub("^ooze covered ", "")
    if tracking == 1 then
        for _, o in ipairs(S.ORES) do
            if low == o[1] then return { kind = o[2], skill = o[3], word = o[4], name = line } end
        end
        -- (an ore the list doesn't know: named, gold arrow)
        if low:find(" vein$") or low:find(" deposit$") then return { kind = 0, skill = 0, word = Word(low), name = line } end
    elseif tracking == 2 then
        for _, h in ipairs(S.HERBS) do
            if low == h[1] then return { kind = S.HERB, skill = h[2], word = Word(h[1]), name = line } end
        end
    elseif tracking == 3 then
        return { kind = S.TREASURE, skill = 0, word = "treasure", name = line }
    end
    return nil
end

-- Hits { x, y (radius units, x right, y up), node } -> dots { x, y, node, n }: hits of one name
-- within reach (radius units) grouped, their centre the mean
S.REACH = 0.09
function S.Cluster(hits, reach)
    reach = reach or S.REACH
    local dots = {}
    for _, h in ipairs(hits) do
        local into
        for _, d in ipairs(dots) do
            if d.node.name == h.node.name then
                local dx, dy = d.x - h.x, d.y - h.y
                if dx * dx + dy * dy <= reach * reach then into = d; break end
            end
        end
        if into then
            into.sx, into.sy, into.n = into.sx + h.x, into.sy + h.y, into.n + 1
            into.x, into.y = into.sx / into.n, into.sy / into.n
        else
            dots[#dots + 1] = { x = h.x, y = h.y, sx = h.x, sy = h.y, n = 1, node = h.node }
        end
    end
    return dots
end

-- Is node wanted: want nil / "any" all; else its word (or "herb" any herb, "ore" any ore)
function S.Wanted(node, want)
    if want == nil or want == "" or want == "any" then return true end
    if want == node.word then return true end
    if want == "herb" and node.kind == S.HERB then return true end
    if want == "ore" and node.kind and node.kind < S.HERB then return true end
    return false
end

-- Up to n dots for the row: wanted first, then the nearest
function S.Pick(dots, want, n)
    local list = {}
    for _, d in ipairs(dots) do list[#list + 1] = d end
    table.sort(list, function(a, b)
        local wa, wb = S.Wanted(a.node, want), S.Wanted(b.node, want)
        if wa ~= wb then return wa end
        return a.x * a.x + a.y * a.y < b.x * b.x + b.y * b.y
    end)
    local out = {}
    for i = 1, math.min(n or 6, #list) do out[i] = list[i] end
    return out
end

-- Where a still dot should slide on the minimap (radius units, x right, y up) as the player
-- moves dE yards east and dN north: the other way, scaled, turned with a rotating minimap
-- (facing: radians, 0 north, counter-clockwise)
function S.Expected(dE, dN, yardsAcross, rotates, facing)
    local k = 2 / math.max(1, yardsAcross or 1)
    local x, y = -dE * k, -dN * k
    if rotates and facing then
        local a = -facing
        x, y = x * cos(a) - y * sin(a), x * sin(a) + y * cos(a)
    end
    return x, y
end

-- How well a seen slide (sx, sy) agrees with the expected (ex, ey): cosine, -1..1, nil when
-- either is too small to tell
function S.Agree(sx, sy, ex, ey)
    local ls, le = sqrt(sx * sx + sy * sy), sqrt(ex * ex + ey * ey)
    if ls < 0.02 or le < 0.02 then return nil end
    return (sx * ex + sy * ey) / (ls * le)
end

-- The readings of UpdateMouseoverAtPoint's point tried, for a point u (radius units, x right, y
-- up) on a minimap: cx, cy its centre and w, h its size (its own units), es its effective scale,
-- ui UIParent's
S.READINGS = {
    { "screen", function(ux, uy, m) return (m.cx + ux * m.w / 2) * m.es / m.ui, (m.cy + uy * m.h / 2) * m.es / m.ui end },
    { "cursor", function(ux, uy, m) return (m.cx + ux * m.w / 2) * m.es, (m.cy + uy * m.h / 2) * m.es end },
    { "local", function(ux, uy, m) return m.w / 2 + ux * m.w / 2, m.h / 2 + uy * m.h / 2 end },
    { "local-top", function(ux, uy, m) return m.w / 2 + ux * m.w / 2, m.h / 2 - uy * m.h / 2 end },
    { "centre", function(ux, uy, m) return ux * m.w / 2, uy * m.h / 2 end },
    { "unit", function(ux, uy) return 0.5 + ux / 2, 0.5 + uy / 2 end },
    { "unit-top", function(ux, uy) return 0.5 + ux / 2, 0.5 - uy / 2 end },
}

-- The grid of a sweep: points in the disc, step apart (radius units), a little past the rim
function S.Grid(step)
    local pts = {}
    local n = floor(1.05 / step)
    for j = -n, n do
        for i = -n, n do
            local x, y = i * step, j * step
            if x * x + y * y <= 1.05 * 1.05 then pts[#pts + 1] = { x, y } end
        end
    end
    return pts
end

function S.Want() return Sh and Sh.CharDB and Sh.CharDB().nodeWant or nil end
function S.SetWant(w) Sh.CharDB().nodeWant = (w ~= nil and w ~= "" and w ~= "any") and w or nil end
function S.Enabled() return not (Sh and Sh.CharDB and Sh.CharDB().nodeSense == false) end

---------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------
if not CreateFrame then return end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function Now() return Call(GetTime) or 0 end
local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- The trace: GamepadCompanionTraceDB.nodes, the last 120 lines
local lastLine
local function Trace(line)
    if type(GamepadCompanionTraceDB) ~= "table" then GamepadCompanionTraceDB = {} end
    local t = GamepadCompanionTraceDB
    t.nodes = type(t.nodes) == "table" and t.nodes or {}
    if line == lastLine then return end
    lastLine = line
    t.nodes[#t.nodes + 1] = ("%.2f %s"):format(Now(), line)
    while #t.nodes > 120 do table.remove(t.nodes, 1) end
end
S.Trace = Trace

-- The skill of a gathering profession (Mining, Herbalism), or nil
local function Skill(names)
    local function Is(name)
        if type(name) ~= "string" then return false end
        for _, n in ipairs(names) do if name:lower() == n then return true end end
        return false
    end
    local info = C_SkillInfo
    if info and info.GetNumSkillLines and info.GetSkillLineInfo then
        for i = 1, tonumber((Call(info.GetNumSkillLines))) or 0 do
            local line = Call(info.GetSkillLineInfo, i)
            if type(line) == "table" and not line.isHeader and Is(line.name) then return tonumber(line.rank or line.skillRank) end
        end
    end
    if GetProfessions and GetProfessionInfo then
        local list = { Call(GetProfessions) }
        for k = 1, 6 do
            if list[k] then
                local name, _, rank = Call(GetProfessionInfo, list[k])
                if Is(name) then return tonumber(rank) end
            end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, tonumber((Call(GetNumSkillLines))) or 0 do
            local name, header, _, rank = Call(GetSkillLineInfo, i)
            if not header and Is(name) then return tonumber(rank) end
        end
    end
end
local skills, skillsAt = {}, -math.huge
local function SkillFor(tracking)
    if Now() - skillsAt > 10 then
        skillsAt = Now()
        skills[1] = Skill({ "mining" })
        skills[2] = Skill({ "herbalism" })
    end
    return skills[tracking]
end

-- The minimap's measure (its own units) for the readings, or nil
local function Measure()
    local mm = Minimap
    if not (mm and mm:IsVisible()) then return nil end
    local cx, cy = Call(mm.GetCenter, mm)
    local w, h = Call(mm.GetWidth, mm), Call(mm.GetHeight, mm)
    if not (cx and cy and w and h) or Secret(cx) or w <= 0 then return nil end
    return { cx = cx, cy = cy, w = w, h = h, es = Call(mm.GetEffectiveScale, mm) or 1, ui = Call(UIParent.GetEffectiveScale, UIParent) or 1 }
end

-- The names under a point (one reading), or nil: the call refused
local function Probe(px, py)
    local ok = pcall(Minimap.UpdateMouseoverAtPoint, Minimap, px, py)
    if not ok then return nil end
    local data = Call(C_TooltipInfo.GetMinimapMouseover)
    local out = {}
    if type(data) == "table" and type(data.lines) == "table" then
        for _, l in ipairs(data.lines) do
            local t = type(l) == "table" and l.leftText
            if type(t) == "string" and not Secret(t) and t ~= "" then
                -- (one line may hold several names, one per line break)
                for name in (t .. "\n"):gmatch("(.-)\n") do if name ~= "" then out[#out + 1] = name end end
            end
        end
    end
    return out
end

-- The state: the reading in use (an index into S.READINGS, nil: not known yet), the sweep under
-- way, the last dots, the readings' scores
S.STEP = 0.07             -- grid step, radius units (about 450 points)
S.PER_FRAME = 40          -- probes a frame
S.EVERY = 1.0             -- s between sweeps
S.SEARCH_EVERY = 12       -- s between searches for the reading while none is known
local store
local function Store()
    if not store then
        if type(GamepadCompanionHapticsDB) ~= "table" then GamepadCompanionHapticsDB = {} end
        local db = GamepadCompanionHapticsDB
        db.nodeSense = type(db.nodeSense) == "table" and db.nodeSense or {}
        store = db.nodeSense
    end
    return store
end
S.dots = {}
local sweep          -- { readings = { i, ... }, pts, at (next point), hits = { [i] = {} }, t0 }
local nextAt, searchAt = 0, 0
local grid
local soft = false
local blocked = false
local last = {}      -- reading -> { dots, x, y (world), facing } of its last sweep
local score = {}     -- reading -> agreement sum

local function SetSoft(on)
    if soft == on then return end
    soft = on
    if Minimap and Minimap.SetUsingSoftCursor then pcall(Minimap.SetUsingSoftCursor, Minimap, on) end
end

local function World()
    local y, x = Call(UnitPosition, "player")   -- (world y west, x north)
    if type(x) ~= "number" or Secret(x) then return nil end
    return -y, x                                  -- east, north
end

-- A sweep done: each reading's dots; the reading chosen; the row's dots
local function Finish(s, m)
    local tracking = s.tracking
    local results = {}
    for _, r in ipairs(s.readings) do results[r] = S.Cluster(s.hits[r]) end
    local known = Store().reading
    if not known then
        -- the readings that found dots; one: it; several: the slide as you walk decides
        local found = {}
        for _, r in ipairs(s.readings) do if #results[r] > 0 then found[#found + 1] = r end end
        local words = {}
        for _, r in ipairs(s.readings) do words[#words + 1] = S.READINGS[r][1] .. " " .. #results[r] end
        Trace("search: " .. table.concat(words, ", "))
        local e, n = World()
        local facing = Call(GetPlayerFacing)
        for _, r in ipairs(found) do
            local before = last[r]
            if before and e and before.e then
                local ex, ey = S.Expected(e - before.e, n - before.n, s.yards, s.rotates, facing)
                for _, d in ipairs(results[r]) do
                    for _, b in ipairs(before.dots) do
                        if b.node.name == d.node.name then
                            local a = S.Agree(d.x - b.x, d.y - b.y, ex, ey)
                            if a then score[r] = (score[r] or 0) + a end
                        end
                    end
                end
            end
            last[r] = { dots = results[r], e = e, n = n }
        end
        local pick
        if #found == 1 then pick = found[1]
        elseif #found > 1 then
            local best, second
            for _, r in ipairs(found) do
                local v = score[r] or 0
                if not best or v > (score[best] or 0) then second = best; best = r
                elseif not second or v > (score[second] or 0) then second = r end
            end
            if best and (score[best] or 0) >= 2 and (score[best] or 0) - (score[second] or 0) >= 2 then pick = best end
        end
        if pick then
            Store().reading = pick
            Trace("reading: " .. S.READINGS[pick][1])
        else
            return
        end
    end
    local r = Store().reading
    local dots = results[r] or {}
    local skill = SkillFor(tracking)
    local want = S.Want()
    for _, d in ipairs(dots) do
        d.wanted = S.Wanted(d.node, want)
        d.gatherable = skill == nil or (d.node.skill or 0) <= skill
    end
    S.dots = S.Pick(dots, want, 6)
    local words = {}
    for _, d in ipairs(S.dots) do words[#words + 1] = ("%s %.2f,%.2f%s%s"):format(d.node.name, d.x, d.y, d.wanted and "" or " -", d.gatherable and "" or " x") end
    Trace("dots: " .. (#words > 0 and table.concat(words, "; ") or "none"))
    if ns.HelperLink and ns.HelperLink.SetNodes then ns.HelperLink.SetNodes(S.Row()) end
end

-- The node row's dots: { { dx, dy (radius/127 units, right, down), kind, wanted, gatherable } }
function S.Row()
    if #S.dots == 0 then return {} end
    local out = {}
    for i, d in ipairs(S.dots) do
        local function Clamp(v) return math.max(-127, math.min(127, v)) end
        out[i] = { dx = Clamp(floor(d.x * 127 + 0.5)), dy = Clamp(floor(-d.y * 127 + 0.5)), kind = d.node.kind,
            wanted = d.wanted ~= false, gatherable = d.gatherable ~= false }
    end
    return out
end

-- Each frame: a slice of the sweep (out of combat, the minimap not under the real mouse)
local function Step()
    local NC = ns.NodeCompass
    local tracking = NC and NC.tracking or 0
    if tracking == 0 or blocked or not S.Enabled() or InCombat() then
        if sweep then sweep = nil end
        SetSoft(false)
        if #S.dots > 0 then S.dots = {}; if ns.HelperLink and ns.HelperLink.SetNodes then ns.HelperLink.SetNodes(nil) end end
        return
    end
    if not (Minimap and Minimap.UpdateMouseoverAtPoint and C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover) then
        blocked = true
        Trace("no API: UpdateMouseoverAtPoint " .. tostring(Minimap and Minimap.UpdateMouseoverAtPoint ~= nil)
            .. ", GetMinimapMouseover " .. tostring(C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover ~= nil))
        return
    end
    if Minimap:IsMouseOver() then SetSoft(false); return end
    local m = Measure()
    if not m then return end
    local now = Now()
    if not sweep then
        local known = Store().reading
        if known and now < nextAt then return end
        if not known and now < searchAt then return end
        grid = grid or S.Grid(S.STEP)
        local readings = {}
        if known then readings[1] = known else for i = 1, #S.READINGS do readings[i] = i end end
        local NCm = NC.Row and NC.Row()
        sweep = { readings = readings, at = 1, hits = {}, tracking = tracking, t0 = now,
            yards = NCm and NCm.yards or (NC.Yards and NC.Yards(Minimap)) or 400, rotates = GetCVar("rotateMinimap") == "1" }
        for _, r in ipairs(readings) do sweep.hits[r] = {} end
    end
    SetSoft(true)
    local s = sweep
    local total = #grid * #s.readings
    local budget = S.PER_FRAME
    while budget > 0 and s.at <= total do
        local r = s.readings[floor((s.at - 1) / #grid) + 1]
        local p = grid[(s.at - 1) % #grid + 1]
        local px, py = S.READINGS[r][2](p[1], p[2], m)
        local names = Probe(px, py)
        if names == nil then
            blocked = true
            SetSoft(false)
            sweep = nil
            Trace("blocked: UpdateMouseoverAtPoint refused")
            return
        end
        for _, name in ipairs(names) do
            local node = S.Kind(name, tracking)
            if node then s.hits[r][#s.hits[r] + 1] = { x = p[1], y = p[2], node = node } end
        end
        s.at, budget = s.at + 1, budget - 1
    end
    SetSoft(false)
    if s.at > total then
        sweep = nil
        nextAt = now + S.EVERY
        local any = false
        for _, r in ipairs(s.readings) do if #s.hits[r] > 0 then any = true end end
        Finish(s, m)
        -- (searching: again soon while some reading finds dots, the slide to tell; else later)
        if not Store().reading then searchAt = now + (any and S.EVERY or S.SEARCH_EVERY) end
    end
end
S.Step = Step

-- The reading forgotten (a client update, a wrong guess): searched again
function S.Forget()
    Store().reading = nil
    score, last = {}, {}
    blocked = false
    searchAt = 0
    Trace("reading forgotten")
end

-- /gpc nodes [forget | <ore or herb word> | any]: the trace, the reading, the setting
function S.Command(rest)
    rest = (rest or ""):lower()
    local function Say(t) print("|cff80c0ffGamepad Companion:|r " .. t) end
    if rest == "forget" then S.Forget(); Say("node reading: searching again"); return end
    if rest == "off" then Sh.CharDB().nodeSense = false; Say("node names off"); return end
    if rest == "on" then Sh.CharDB().nodeSense = nil; Say("node names on"); return end
    if rest ~= "" then
        S.SetWant(rest)
        Say("looking for: " .. (S.Want() or "any"))
        return
    end
    local r = Store().reading
    Say(("node names %s · reading %s · looking for %s"):format(S.Enabled() and "on" or "off",
        r and S.READINGS[r] and S.READINGS[r][1] or (blocked and "blocked" or "searching"), S.Want() or "any"))
    local t = type(GamepadCompanionTraceDB) == "table" and GamepadCompanionTraceDB.nodes or {}
    for i = math.max(1, #t - 12), #t do print(t[i]) end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function() Step() end)
