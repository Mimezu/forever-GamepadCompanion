-- Flight list: at a flight master, a list beside the game's flight map of
-- every place you can fly to from here, chosen with the pad (docs/FLIGHT-LIST.md).
-- The map stays Blizzard's (TaxiFrame); it only reflects the chosen row: a
-- gold ring on that place, the route there drawn stop by stop.
--
-- The pad: the panel takes the d-pad, L1 / R1, A, B and Y as pad buttons, one
-- press at a time, on its own frame (each handled press stops there, every
-- other one passes on), out of combat only, as the Companion window does
-- (Focus.lua). No binding of anyone's is changed.
--
-- Taint: nothing of ours is written into Blizzard's frames or tables. The map
-- is read (its node buttons' places), never drawn on: the ring and the route
-- are our own regions on our own frame over it. TakeTaxiNode and
-- CloseTaxiMap are plain calls, from a press or a click.
local _, ns = ...
local Sh = ns.Shared
local FL = {}
ns.FlightList = FL

---------------------------------------------------------------------------
-- Pure (tests/FlightList.lua)
---------------------------------------------------------------------------
FL.VIEWS = { zones = "near", near = "zones" }   -- Y: one to the other

-- Zone levels (Classic): { lowest, highest }; false: a hub, no range
FL.ZONES = {
    ["Durotar"] = { 1, 10 }, ["Mulgore"] = { 1, 10 }, ["Tirisfal Glades"] = { 1, 10 },
    ["Elwynn Forest"] = { 1, 10 }, ["Dun Morogh"] = { 1, 10 }, ["Teldrassil"] = { 1, 10 },
    ["The Barrens"] = { 10, 25 }, ["Silverpine Forest"] = { 10, 20 }, ["Westfall"] = { 10, 20 },
    ["Loch Modan"] = { 10, 20 }, ["Darkshore"] = { 10, 20 },
    ["Redridge Mountains"] = { 15, 25 }, ["Stonetalon Mountains"] = { 15, 27 }, ["Ashenvale"] = { 18, 30 },
    ["Duskwood"] = { 18, 30 }, ["Wetlands"] = { 20, 30 }, ["Hillsbrad Foothills"] = { 20, 30 },
    ["Thousand Needles"] = { 25, 35 }, ["Desolace"] = { 30, 40 }, ["Arathi Highlands"] = { 30, 40 },
    ["Stranglethorn Vale"] = { 30, 45 }, ["Dustwallow Marsh"] = { 35, 45 }, ["Badlands"] = { 35, 45 },
    ["Swamp of Sorrows"] = { 35, 45 }, ["The Hinterlands"] = { 40, 50 }, ["Feralas"] = { 40, 50 },
    ["Tanaris"] = { 40, 50 }, ["Searing Gorge"] = { 43, 50 }, ["Azshara"] = { 45, 55 },
    ["Blasted Lands"] = { 45, 55 }, ["Felwood"] = { 48, 55 }, ["Un'Goro Crater"] = { 48, 55 },
    ["Burning Steppes"] = { 50, 58 }, ["Western Plaguelands"] = { 51, 58 },
    ["Eastern Plaguelands"] = { 53, 60 }, ["Winterspring"] = { 55, 60 }, ["Silithus"] = { 55, 60 },
    ["Moonglade"] = false,
}
-- The map's short zone names, and the quest log's cities: the zone they mean
FL.ZONE_NAME = {
    ["Elwynn"] = "Elwynn Forest", ["Redridge"] = "Redridge Mountains", ["Stranglethorn"] = "Stranglethorn Vale",
    ["Hillsbrad"] = "Hillsbrad Foothills", ["Arathi"] = "Arathi Highlands", ["Tirisfal"] = "Tirisfal Glades",
    ["Silverpine"] = "Silverpine Forest", ["Stonetalon"] = "Stonetalon Mountains", ["Dustwallow"] = "Dustwallow Marsh",
    ["Hinterlands"] = "The Hinterlands", ["Barrens"] = "The Barrens", ["Un'Goro"] = "Un'Goro Crater",
    ["Orgrimmar"] = "Durotar", ["Thunder Bluff"] = "Mulgore", ["Undercity"] = "Tirisfal Glades",
    ["Stormwind City"] = "Elwynn Forest", ["Stormwind"] = "Elwynn Forest", ["Ironforge"] = "Dun Morogh",
    ["Darnassus"] = "Teldrassil",
}
-- Capitals, by place: never dimmed, a fair fit at any level
FL.CITIES = { ["Orgrimmar"] = true, ["Thunder Bluff"] = true, ["Undercity"] = true,
    ["Stormwind"] = true, ["Ironforge"] = true, ["Darnassus"] = true }

function FL.ZoneName(zone)
    if not zone then return nil end
    return FL.ZONE_NAME[zone] or zone
end

-- A zone's colour for level L (quest colours): red, orange, yellow, green, grey; nil: no range
function FL.Tier(L, range)
    if type(range) ~= "table" or not tonumber(L) then return nil end
    local lo, hi = range[1], range[2]
    if L < lo - 3 then return "red" elseif L < lo then return "orange"
    elseif L <= hi then return "yellow" elseif L < hi + 6 then return "green" end
    return "grey"
end

local FIT = { yellow = 25, orange = 15, green = 10, red = 0, grey = 0 }
function FL.Fit(L, range, city)
    local tier = FL.Tier(L, range)
    local fit = tier and FIT[tier] or 8
    if city then fit = math.max(fit, 8) end
    return fit
end

-- "Ironforge, Dun Morogh" -> "Ironforge", "Dun Morogh"; no comma: name, nil
function FL.SplitName(name)
    name = tostring(name or "")
    local place, zone = name:match("^(.-),%s*(.+)$")
    if place and place ~= "" then return place, zone end
    return name, nil
end

-- The map's nodes through api = { count, name(i), type(i), cost(i), pos(i) -> x, y,
-- hops(i) }: here (the CURRENT node, or nil) and the places you can fly to
-- (REACHABLE only), each { index, name, place, zone, cost, x, y, hops, dist }
function FL.Read(api)
    local here, list = nil, {}
    local n = tonumber(api.count) or 0
    for i = 1, n do
        local kind = api.type(i)
        if kind == "CURRENT" or kind == "REACHABLE" then
            local name = api.name(i) or ""
            local place, zone = FL.SplitName(name)
            local x, y = api.pos(i)
            local node = { index = i, name = name, place = place, zone = zone, x = tonumber(x) or 0, y = tonumber(y) or 0 }
            if kind == "CURRENT" then here = node
            else
                node.cost = tonumber(api.cost(i)) or 0
                node.hops = math.max(1, tonumber(api.hops and api.hops(i)) or 1)
                list[#list + 1] = node
            end
        end
    end
    for _, node in ipairs(list) do
        if here then
            local dx, dy = node.x - here.x, node.y - here.y
            node.dist = math.sqrt(dx * dx + dy * dy)
        else
            node.dist = 0
        end
    end
    return here, list
end

local function ByName(a, b)
    local pa, pb = a.place:lower(), b.place:lower()
    if pa ~= pb then return pa < pb end
    return (a.zone or ""):lower() < (b.zone or ""):lower()
end

-- In place: "near" (nearest first) or "name" (A-Z); ties by name, then index
function FL.Sort(list, mode)
    table.sort(list, function(a, b)
        if mode ~= "name" and a.dist ~= b.dist then return a.dist < b.dist end
        if a.place:lower() ~= b.place:lower() or (a.zone or "") ~= (b.zone or "") then return ByName(a, b) end
        return a.index < b.index
    end)
    return list
end

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
-- Copper as coins: "1|T..Gold..|t  20|T..Silver..|t"; zero parts left out; 0: ""
function FL.Coins(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local parts = {}
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then parts[#parts + 1] = g .. COIN:format("Gold") end
    if s > 0 then parts[#parts + 1] = s .. COIN:format("Silver") end
    if c > 0 then parts[#parts + 1] = c .. COIN:format("Copper") end
    return table.concat(parts, "  ")
end

FL.DOTS = 5   -- dots of each kind on a row, at most

-- Each quest to the one flight path nearest it. quests = { { ready, zone (its log header's), at } },
-- paths = { { name, zone, at } } (the places you can fly to), centres[zone] = at;
-- at = { cont, x, y } in the world's yards (C_Map.GetWorldPosFromMapPos), nil when unknown.
-- A quest with a point (where to go, or whom to turn it in to): the nearest path on its continent;
-- none there: no dot. Without a point: its zone's path nearest the zone's centre, else the zone's
-- first. Neither: no dot. (q.path: where it went, for the probe)
-- Two points on one continent: the same world id (cont) and, when both are known, the same
-- continent map (map: climbed from the point's own map by its parents), so a point is never
-- matched by its yards alone
function FL.SameContinent(a, b)
    if not (a and b) or a.cont ~= b.cont then return false end
    if a.map and b.map then return a.map == b.map end
    return true
end

-- -> per path name { open, ready, quests (the quests themselves) }
function FL.Tally(quests, paths, centres)
    local counts = {}
    local function Nearest(at, zone)
        if not at then return nil end
        local best, bd
        for _, p in ipairs(paths or {}) do
            if FL.SameContinent(p.at, at) and (not zone or p.zone == zone) then
                local dx, dy = p.at.x - at.x, p.at.y - at.y
                local d = dx * dx + dy * dy
                if not bd or d < bd then best, bd = p.name, d end
            end
        end
        return best
    end
    local function First(zone)
        for _, p in ipairs(paths or {}) do if p.zone == zone then return p.name end end
    end
    for _, q in ipairs(quests or {}) do
        -- (a point elsewhere, the other continent say: no dot. Its log zone is where it was given:
        -- a breadcrumb to Stranglethorn sat under Desolace and landed on Shadowprey Village)
        local name
        if q.at then name = Nearest(q.at)
        elseif q.zone then name = Nearest((centres or {})[q.zone], q.zone) or First(q.zone) end
        q.path = name
        if name then
            local c = counts[name] or { open = 0, ready = 0, quests = {} }
            counts[name] = c
            if q.ready then c.ready = c.ready + 1 else c.open = c.open + 1 end
            c.quests[#c.quests + 1] = q
        end
    end
    return counts
end

-- L2 / R2 while the list shows: override bindings to our own buttons (as Fishing.lua's pole)
FL.TRIGGER_BUTTONS = { PADLTRIGGER = "GamepadCompanionFlightTurnIns", PADRTRIGGER = "GamepadCompanionFlightQuests" }
FL.TRIGGER_JUMPS = { PADLTRIGGER = "ready", PADRTRIGGER = "open" }   -- L2: turn-ins, R2: quests to do
-- key -> the binding's action, while on; nothing while off
function FL.Binds(on)
    local t = {}
    if on then for key, name in pairs(FL.TRIGGER_BUTTONS) do t[key] = "CLICK " .. name .. ":LeftButton" end end
    return t
end

-- The probe: each quest's log zone, point and path, in a line ("title: zone | how c:x,y -> path")
FL.PROBE_MAX = 40
function FL.Probe(quests)
    local out = {}
    for i, q in ipairs(quests or {}) do
        if i > FL.PROBE_MAX then break end
        local at = q.at and ("%d/%s:%d,%d"):format(q.at.cont, tostring(q.at.map), q.at.x, q.at.y) or "-"
        out[#out + 1] = ("%s: %s | %s %s -> %s"):format(tostring(q.title), tostring(q.zone), tostring(q.how or "-"), at, tostring(q.path or "no dot"))
    end
    return out
end

-- The quest note beside the chosen row: its quests, the ones to turn in first (the log's order
-- kept), at most max lines; -> lines { title, level, ready }, how many more
FL.NOTE_LINES = 8
function FL.NoteLines(quests, max)
    max = max or FL.NOTE_LINES
    local lines = {}
    for pass = 1, 2 do
        for _, q in ipairs(quests or {}) do
            if (q.ready and true or false) == (pass == 1) then
                lines[#lines + 1] = { title = q.title or "?", level = tonumber(q.level), ready = q.ready and true or false }
            end
        end
    end
    local more = math.max(0, #lines - max)
    for i = #lines, max + 1, -1 do lines[i] = nil end
    return lines, more
end

-- One row on: wrap = true goes round the ends, else stops there
function FL.Step(sel, n, delta, wrap)
    if n < 1 then return nil end
    sel = (tonumber(sel) or 1) + delta
    if wrap then return (sel - 1) % n + 1 end
    return math.max(1, math.min(n, sel))
end

-- The rows: zone groups ("zones") or one list ("near"), and the row to start on.
-- ctx = { view, zone (yours), level, money, last (a node's name), quests (per zone) and places (per flight path) = FL.Tally,
-- ranges = FL.ZONES }. Rows: { kind = "header", g } or { kind = "flight", node, g };
-- g = { zone, range, tier, open, ready, score, dim }.
-- A group's score: turn-ins, open quests, the level's fit, the last place flown to, near;
-- your own zone first; groups you can't pay for last.
function FL.Arrange(nodes, ctx)
    ctx = ctx or {}
    local ranges, places, L, money = ctx.ranges or FL.ZONES, ctx.places or {}, ctx.level, ctx.money
    local flights = {}
    for i, node in ipairs(nodes or {}) do flights[i] = node end
    FL.Sort(flights, "near")
    local groups, byZone, lastZone = {}, {}, nil
    for _, node in ipairs(flights) do
        local z = FL.ZoneName(node.zone) or node.place
        local g = byZone[z]
        if not g then
            g = { zone = z, nodes = {}, minDist = node.dist or 0, afford = false, city = false, order = #groups + 1 }
            byZone[z] = g
            groups[#groups + 1] = g
        end
        g.nodes[#g.nodes + 1] = node
        g.minDist = math.min(g.minDist, node.dist or 0)
        if not money or (node.cost or 0) <= money then g.afford = true end
        if FL.CITIES[node.place] then g.city = true end
        if ctx.last and node.name == ctx.last then lastZone = z end
    end
    for _, g in ipairs(groups) do
        local r = ranges[g.zone]
        g.range = type(r) == "table" and r or nil
        g.open, g.ready = 0, 0
        for _, node in ipairs(g.nodes) do
            local q = places[node.name] or {}
            g.open, g.ready = g.open + (q.open or 0), g.ready + (q.ready or 0)
        end
        g.tier = FL.Tier(L, g.range)
        g.dim = g.tier == "grey" and not g.city
        g.score = 30 * g.ready + 10 * math.min(g.open, 5) + FL.Fit(L, g.range, g.city)
            + (g.zone == lastZone and 5 or 0) - 20 * g.minDist - (g.afford and 0 or 1000)
    end
    local rows = {}
    local function Flight(node, g)
        local q = places[node.name] or {}
        return { kind = "flight", node = node, g = g, open = q.open or 0, ready = q.ready or 0, quests = q.quests or {} }
    end
    if ctx.view == "near" then
        for _, node in ipairs(flights) do rows[#rows + 1] = Flight(node, byZone[FL.ZoneName(node.zone) or node.place]) end
        return rows, #rows > 0 and 1 or nil
    end
    local here = FL.ZoneName(ctx.zone)
    table.sort(groups, function(a, b)
        if (a.zone == here) ~= (b.zone == here) then return a.zone == here end
        if a.score ~= b.score then return a.score > b.score end
        if a.minDist ~= b.minDist then return a.minDist < b.minDist end
        if a.zone ~= b.zone then return a.zone < b.zone end
        return a.order < b.order
    end)
    for _, g in ipairs(groups) do
        rows[#rows + 1] = { kind = "header", g = g }
        for _, node in ipairs(g.nodes) do rows[#rows + 1] = Flight(node, g) end
    end
    -- (the first flight: the nearest in your zone, else in the best zone)
    return rows, #rows > 1 and 2 or nil
end

-- The flight rows' indices
local function Flights(rows)
    local out = {}
    for i, r in ipairs(rows) do if r.kind == "flight" then out[#out + 1] = i end end
    return out
end

-- delta flights on from sel, past the headers (wrap: round the ends)
function FL.Next(rows, sel, delta, wrap)
    local f = Flights(rows)
    if #f == 0 then return nil end
    local pos = 0
    for p, i in ipairs(f) do if i == sel then pos = p end end
    if pos == 0 and delta < 0 then pos = #f + 1 end
    if pos == 0 or pos == #f + 1 then
        -- (from no flight: the first or the last)
        return f[delta < 0 and math.max(1, #f + 1 + delta) or math.min(#f, delta)]
    end
    return f[FL.Step(pos, #f, delta, wrap)]
end

-- The first flight of group g (rows in order: its nearest)
local function FirstOf(rows, g)
    for i, r in ipairs(rows) do if r.kind == "flight" and r.g == g then return i end end
end

-- The groups in the rows' order
local function Groups(rows)
    local out, seen = {}, {}
    for _, r in ipairs(rows) do
        if r.g and not seen[r.g] then seen[r.g] = true; out[#out + 1] = r.g end
    end
    return out
end

-- The first flight of the zone before / after sel's (dir -1 / 1), round the ends
function FL.Zone(rows, sel, dir)
    local gs = Groups(rows)
    if #gs == 0 then return nil end
    local cur = rows[sel] and rows[sel].g
    local pos = 0
    for p, g in ipairs(gs) do if g == cur then pos = p end end
    return FirstOf(rows, gs[(pos - 1 + dir) % #gs + 1])
end

-- L2 / R2: the flight path with the most key ("ready" turn-ins, "open" quests to do) near it;
-- again, the next one, round. nil when none has any
-- The rows with some key, most first; and sel's place among them (0: not one)
local function Candidates(rows, sel, key)
    local cands = {}
    for i, r in ipairs(rows) do if r.kind == "flight" and (r[key] or 0) > 0 then cands[#cands + 1] = i end end
    table.sort(cands, function(a, b)
        local ra, rb = rows[a], rows[b]
        if ra[key] ~= rb[key] then return ra[key] > rb[key] end
        local sa, sb = ra.g and ra.g.score or 0, rb.g and rb.g.score or 0
        if sa ~= sb then return sa > sb end
        return a < b
    end)
    local pos = 0
    for p, i in ipairs(cands) do if i == sel then pos = p end end
    return cands, pos
end

function FL.Jump(rows, sel, key)
    local cands, pos = Candidates(rows, sel, key)
    if #cands == 0 then return nil end
    return cands[pos % #cands + 1]
end

-- Where sel is in L2's / R2's round: its place, of how many (0, n: not on one)
function FL.Round(rows, sel, key)
    local cands, pos = Candidates(rows, sel, key)
    return pos, #cands
end

-- A trigger's hint: its ringed dot, its word, and "2/3" while on its round
function FL.Hint(mark, word, pos, n)
    if pos and pos > 0 and n and n > 1 then return mark .. word .. "  " .. pos .. "/" .. n end
    return mark .. word
end

-- Every row's count of key, added
function FL.Total(rows, key)
    local n = 0
    for _, r in ipairs(rows) do if r.kind == "flight" then n = n + (r[key] or 0) end end
    return n
end

-- The row of the place named name, or nil
function FL.Find(rows, name)
    if not name then return nil end
    for i, r in ipairs(rows) do if r.kind == "flight" and r.node.name == name then return i end end
end

-- The first row shown (offset) so row sel fits in view px, with its zone's header when it is
-- the zone's first; height(row) in px; never a gap at the end
function FL.Scroll(offset, sel, rows, view, height)
    local n = #rows
    offset = tonumber(offset) or 0
    if not sel or n == 0 then return 0 end
    local top = sel
    if sel > 1 and rows[sel - 1].kind == "header" then top = sel - 1 end
    if top <= offset then offset = top - 1 end
    local function Span(a, b)
        local s = 0
        for i = a, b do s = s + height(rows[i]) end
        return s
    end
    while offset < sel - 1 and Span(offset + 1, sel) > view do offset = offset + 1 end
    -- the lowest offset that still fills the view to the end
    local last, acc = n, 0
    while last > 0 and acc + height(rows[last]) <= view do acc = acc + height(rows[last]); last = last - 1 end
    return math.max(0, math.min(offset, last))
end

-- The scroll thumb: top and length in a track of height px; nil when all fit
function FL.Thumb(offset, visible, n, height)
    if n <= visible or n < 1 then return nil end
    local len = math.max(16, height * visible / n)
    return (height - len) * offset / (n - visible), len
end

-- A node's point on the map, from its BOTTOMLEFT (the game's own placing)
function FL.NodePoint(x, y, w, h)
    return x * w, (1 - y) * h
end

-- Smooth start and end, t in 0..1
function FL.Ease(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

-- Settings (per character, as the bag grid) ----------------------------------
function FL.Enabled() return Sh.CharDB().flightList ~= false end

-- Shown: on, in the gamepad UI only, while the flight map is open
-- The quest note: on by default (Setup: Quest note)
function FL.NoteOn() return Sh.CharDB().flightNote ~= false end

function FL.Wanted(enabled, gamepadUI, mapShown)
    return enabled and gamepadUI == true and mapShown and true or false
end
-- "zones" (default) or "near"; (an older "name": near)
function FL.View()
    local v = Sh.CharDB().flightSort
    return (v == "near" or v == "name") and "near" or "zones"
end
function FL.LastFrom(here)
    local t = Sh.CharDB().flightLast
    return here and type(t) == "table" and t[here] or nil
end
function FL.Remember(here, dest)
    if not (here and dest) then return end
    local db = Sh.CharDB()
    if type(db.flightLast) ~= "table" then db.flightLast = {} end
    db.flightLast[here] = dest
end

-- Game wiring ------------------------------------------------------------------
if not CreateFrame then return end

local function Pass(ok, ...) if ok then return ... end end
-- (every return passed on: a game call can return more than five)
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return Pass(pcall(fn, ...))
end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and Call(C_Texture.GetAtlasInfo, name) ~= nil
end

local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local INK = { 0.20, 0.12, 0.04 }
local FADED = { 0.42, 0.31, 0.18 }
local DEAR = { 0.62, 0.10, 0.04 }   -- a cost you can't pay
local GOLD = { 1.00, 0.82, 0.38 }
local HEAD_H, FOOT_H, WIDTH = 62, 66, 260
local ROW_H = { zones = 25, near = 34 }   -- a flight's row: a line, or two (with its zone)
local ZONE_H = 20                          -- a zone's row
-- a zone's colour on parchment (the quest colours, inked)
local TIERS = {
    red = { 0.66, 0.08, 0.04 }, orange = { 0.72, 0.36, 0.04 }, yellow = { 0.52, 0.40, 0.00 },
    green = { 0.14, 0.42, 0.08 }, grey = { 0.45, 0.42, 0.38 },
}
local READY_DOT = { 1.00, 0.78, 0.18 }   -- a quest to turn in: gold
local OPEN_DOT = { 0.42, 0.25, 0.08 }    -- a quest to do: brown
local RING = "ChallengeMode-AffixRing-Sm"
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local GLOW = "Interface\\TaxiFrame\\UI-Taxi-Icon-Highlight"
local POINTER = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local HERE_ICON = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green"

local state = { here = nil, nodes = {}, rows = {}, sel = nil, offset = 0, viewH = 400, view = "zones", places = {} }

local function RowHeight(row) return row.kind == "header" and ZONE_H or ROW_H[state.view] end

local function Text(parent, font, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- The panel: the map's own chrome, parchment inside ---------------------------
local panel
do
    local ok, made = pcall(CreateFrame, "Frame", "GamepadCompanionFlightList", UIParent, "BasicFrameTemplateWithInset")
    panel = ok and made or CreateFrame("Frame", "GamepadCompanionFlightList", UIParent)
end
panel:Hide()
panel:SetSize(WIDTH, 608)
panel:EnableMouse(true)
if panel.TitleText then panel.TitleText:SetText("Fly to") end
if panel.CloseButton then panel.CloseButton:SetScript("OnClick", function() Call(CloseTaxiMap) end) end

local inner = CreateFrame("Frame", nil, panel)
if panel.InsetBg then
    inner:SetPoint("TOPLEFT", panel.InsetBg, "TOPLEFT")
    inner:SetPoint("BOTTOMRIGHT", panel.InsetBg, "BOTTOMRIGHT")
else
    inner:SetPoint("TOPLEFT", 8, -26)
    inner:SetPoint("BOTTOMRIGHT", -6, 6)
end

local paper = inner:CreateTexture(nil, "BACKGROUND", nil, 1)
paper:SetAllPoints()
if HasAtlas("QuestBG-Parchment") then paper:SetAtlas("QuestBG-Parchment")
else paper:SetColorTexture(0.85, 0.76, 0.58, 1) end

-- where you are: not a row
local head = CreateFrame("Frame", nil, inner)
head:SetPoint("TOPLEFT")
head:SetPoint("TOPRIGHT")
head:SetHeight(HEAD_H)
head.icon = head:CreateTexture(nil, "ARTWORK")
head.icon:SetTexture(HERE_ICON)
head.icon:SetSize(22, 22)
head.icon:SetPoint("LEFT", 12, 2)
head.place = Text(head, TITLE_FONT, 17, INK)
head.place:SetPoint("TOPLEFT", head.icon, "TOPRIGHT", 8, 4)
head.place:SetPoint("RIGHT", -12, 0)
head.zone = Text(head, BODY_FONT, 10, FADED)
head.zone:SetPoint("TOPLEFT", head.place, "BOTTOMLEFT", 0, -3)
head.zone:SetPoint("RIGHT", -12, 0)
local rule = head:CreateTexture(nil, "ARTWORK")
rule:SetHeight(1)
rule:SetPoint("BOTTOMLEFT", 12, 4)
rule:SetPoint("BOTTOMRIGHT", -12, 4)
rule:SetColorTexture(INK[1], INK[2], INK[3], 0.35)

local body = CreateFrame("Frame", nil, inner)
body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
body:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 0, FOOT_H)
body:SetClipsChildren(true)

local empty = Text(body, BODY_FONT, 12, FADED, "CENTER")
empty:SetPoint("TOP", 0, -24)
empty:SetText("No flights")

-- the scroll thumb: a thin ink line at the right edge
local track = CreateFrame("Frame", nil, body)
track:SetPoint("TOPRIGHT", -4, -2)
track:SetPoint("BOTTOMRIGHT", -4, 2)
track:SetWidth(2)
local thumb = track:CreateTexture(nil, "ARTWORK")
thumb:SetWidth(2)
thumb:SetColorTexture(INK[1], INK[2], INK[3], 0.35)

-- Rows -------------------------------------------------------------------------
-- (one widget per shown slot: a flight's row or a zone's, as the row asks)
local slots = {}
local Select, Fly, LegendText   -- (below)

-- a dot: gold, a quest to turn in; brown, a quest to do; each in a thin ink ring (gold alone
-- vanished on the parchment)
local function Dot(parent, color)
    local ring = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetTexture(DISC)
    ring:SetSize(9, 9)
    ring:SetVertexColor(0.16, 0.09, 0.02, 1)
    local t = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    t:SetTexture(DISC)
    t:SetSize(6, 6)
    t:SetVertexColor(color[1], color[2], color[3], 1)
    t:SetPoint("CENTER", ring, "CENTER")
    t:Hide(); ring:Hide()
    return { dot = t, ring = ring }
end

local function Slot(i)
    if slots[i] then return slots[i] end
    local r = CreateFrame("Button", nil, body)
    r:RegisterForClicks("LeftButtonUp")
    -- the chosen row: a strong amber band fading to the right, a dark ink bar, a pointer
    r.band = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.band:SetAllPoints()
    r.band:SetColorTexture(1, 1, 1, 1)
    local faded = r.band.SetGradient and CreateColor and pcall(r.band.SetGradient, r.band, "HORIZONTAL",
        CreateColor(0.93, 0.62, 0.18, 0.85), CreateColor(0.93, 0.62, 0.18, 0.20))
    if not faded then r.band:SetVertexColor(0.93, 0.62, 0.18, 0.6) end
    r.edge = r:CreateTexture(nil, "ARTWORK")
    r.edge:SetWidth(3)
    r.edge:SetPoint("TOPLEFT", 0, -2)
    r.edge:SetPoint("BOTTOMLEFT", 0, 2)
    r.edge:SetColorTexture(0.30, 0.16, 0.04, 1)
    r.pointer = r:CreateTexture(nil, "OVERLAY")
    r.pointer:SetTexture(POINTER)
    r.pointer:SetSize(10, 10)
    r.pointer:SetVertexColor(0.30, 0.16, 0.04, 1)
    r.place = Text(r, BODY_FONT, 12, INK)
    r.cost = Text(r, BODY_FONT, 11, INK, "RIGHT")
    r.zone = Text(r, BODY_FONT, 10, FADED)
    r.zone:SetPoint("TOPLEFT", r.place, "BOTTOMLEFT", 0, -2)
    r.zone:SetPoint("RIGHT", r, "RIGHT", -60, 0)
    -- the quests near this flight path: a gold dot each to turn in, a brown dot each to do
    r.dots = {}
    for d = 1, 2 * FL.DOTS do r.dots[d] = Dot(r, d <= FL.DOTS and READY_DOT or OPEN_DOT) end
    -- a zone's row: its name and levels, a hairline
    r.head = CreateFrame("Frame", nil, r)
    r.head:SetAllPoints()
    r.head.name = Text(r.head, TITLE_FONT, 13, INK)
    r.head.name:SetPoint("BOTTOMLEFT", 6, 4)
    r.head.range = Text(r.head, BODY_FONT, 10, INK)
    r.head.range:SetPoint("BOTTOMLEFT", r.head.name, "BOTTOMRIGHT", 6, 1)
    r.head.line = r.head:CreateTexture(nil, "ARTWORK")
    r.head.line:SetHeight(1)
    r.head.line:SetPoint("BOTTOMLEFT", 4, 1)
    r.head.line:SetPoint("BOTTOMRIGHT", -2, 1)
    r.head.line:SetColorTexture(0.55, 0.36, 0.10, 0.45)
    r:SetScript("OnEnter", function(self) if self.at then Select(self.at) end end)
    r:SetScript("OnClick", function(self) if self.at then Select(self.at); Fly() end end)
    slots[i] = r
    return r
end

local function HideDots(r) for _, d in ipairs(r.dots) do d.dot:Hide(); d.ring:Hide() end end
local function PlaceDot(d, r, x, y)
    d.ring:ClearAllPoints()
    d.ring:SetPoint("CENTER", r, "TOPRIGHT", x, y)
    d.ring:Show(); d.dot:Show()
end

-- the dots right to left from x (px from the row's right edge), y from its top; their width
local function DrawDots(r, row, x, y)
    HideDots(r)
    local ready, open = math.min(FL.DOTS, row.ready or 0), math.min(FL.DOTS, row.open or 0)
    local n = 0
    for k = open, 1, -1 do
        PlaceDot(r.dots[FL.DOTS + k], r, x - 4 - n * 9, y)
        n = n + 1
    end
    if ready > 0 and open > 0 then n = n + 0.5 end
    for k = ready, 1, -1 do
        PlaceDot(r.dots[k], r, x - 4 - n * 9, y)
        n = n + 1
    end
    return n * 9
end

local function DrawFlight(r, row, at)
    local node, two = row.node, state.view == "near"
    r.head:Hide()
    r:EnableMouse(true)
    r.cost:SetText(FL.Coins(node.cost))
    local c = node.cost > (Call(GetMoney) or 0) and DEAR or INK
    r.cost:SetTextColor(c[1], c[2], c[3])
    r.cost:ClearAllPoints()
    r.cost:Show()
    r.place:ClearAllPoints()
    local top = two and -5 or -7
    r.place:SetPoint("TOPLEFT", 14, top)
    -- one line (zones): place, dots, cost; two (nearest): the zone under the place, the dots under the cost
    r.cost:SetPoint("TOPRIGHT", -2, top)
    local costW = (r.cost:GetStringWidth() or 40)
    if two then
        DrawDots(r, row, -2, -24)
        r.place:SetPoint("TOPRIGHT", r, "TOPRIGHT", -costW - 10, top)
    else
        local w = DrawDots(r, row, -costW - 10, -12)
        r.place:SetPoint("TOPRIGHT", r, "TOPRIGHT", -costW - 14 - w, top)
    end
    r.place:SetText(node.place)
    r.place:SetAlpha(row.g and row.g.dim and 0.6 or 1)
    r.zone:SetShown(two)
    r.zone:SetText(node.zone or "")
    local on = at == state.sel
    r.band:SetShown(on)
    r.edge:SetShown(on)
    r.pointer:ClearAllPoints()
    r.pointer:SetPoint("LEFT", r, "LEFT", 3, 0)
    r.pointer:SetShown(on)
end

local function DrawZone(r, row)
    local g, h = row.g, r.head
    r:EnableMouse(false)
    r.band:Hide(); r.edge:Hide(); r.pointer:Hide(); r.place:SetText(""); r.zone:Hide(); r.cost:Hide()
    HideDots(r)
    local c = TIERS[g.tier] or INK
    h.name:SetText(g.zone)
    h.name:SetTextColor(c[1], c[2], c[3])
    h.range:SetText(g.range and (g.range[1] .. "-" .. g.range[2]) or "")
    h.range:SetTextColor(c[1], c[2], c[3])
    h:Show()
end

-- The quest note: the catch card's paper (FishingToast.lua), floating right of the panel, level
-- with the chosen row; its quests, a dot each. Never takes the mouse.
local NOTE_W, NOTE_M, NOTE_LINE = 214, 12, 16
local note
local function Note()
    if note ~= nil then return note or nil end
    note = false
    local toast = ns.FishingToast
    if not (toast and toast.Paper and toast.Kicker) then return nil end
    local f = CreateFrame("Frame", nil, panel)
    f:SetWidth(NOTE_W)
    f:SetFrameLevel((panel:GetFrameLevel() or 1) + 30)
    f:EnableMouse(false)
    f:SetClampedToScreen(true)
    toast.Paper(f)
    toast.Kicker(f, NOTE_M, -15)
    f.lines = {}
    for i = 1, FL.NOTE_LINES do
        local l = {}
        l.ready = Dot(f, READY_DOT)
        l.open = Dot(f, OPEN_DOT)
        l.title = Text(f, BODY_FONT, 11, INK)
        l.level = Text(f, BODY_FONT, 10, FADED, "RIGHT")
        local y = -30 - (i - 1) * NOTE_LINE
        for _, d in ipairs({ l.ready, l.open }) do d.ring:SetPoint("CENTER", f, "TOPLEFT", NOTE_M + 4, y - 6) end
        l.title:SetPoint("TOPLEFT", f, "TOPLEFT", NOTE_M + 13, y)
        l.level:SetPoint("TOPRIGHT", f, "TOPRIGHT", -NOTE_M, y)
        f.lines[i] = l
    end
    f.more = Text(f, BODY_FONT, 10, FADED)
    f:Hide()
    note = f
    return f
end

local function StringWidth(fs)
    local v = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return tonumber(v) or 0
end

local function DrawNote(slot, row)
    local f = Note()
    if not f then return end
    if not (slot and row and FL.NoteOn() and #(row.quests or {}) > 0) then f:Hide(); return end
    local lines, more = FL.NoteLines(row.quests)
    if ns.FishingToast.SetKicker then ns.FishingToast.SetKicker(f, row.node.place:upper(), NOTE_W - NOTE_M) end
    local room = NOTE_W - (NOTE_M + 13) - NOTE_M
    for i, l in ipairs(f.lines) do
        local q = lines[i]
        for _, d in ipairs({ l.ready, l.open }) do d.dot:Hide(); d.ring:Hide() end
        l.title:SetShown(q ~= nil)
        l.level:SetShown(false)
        if q then
            local d = q.ready and l.ready or l.open
            d.dot:Show(); d.ring:Show()
            l.title:SetWidth(0)
            l.title:SetText(q.title)
            -- (the level only where it fits)
            l.level:SetText(q.level and tostring(q.level) or "")
            local lw = q.level and StringWidth(l.level) + 6 or 0
            local tw = StringWidth(l.title)
            l.level:SetShown(q.level ~= nil and tw + lw <= room)
            l.title:SetWidth(math.min(tw, room - (l.level:IsShown() and lw or 0)))
        end
    end
    local h = 30 + #lines * NOTE_LINE + 6
    f.more:ClearAllPoints()
    f.more:SetPoint("TOPLEFT", f, "TOPLEFT", NOTE_M + 13, -30 - #lines * NOTE_LINE)
    f.more:SetText(more > 0 and ("+" .. more .. " more") or "")
    f.more:SetShown(more > 0)
    if more > 0 then h = h + 14 end
    f:SetHeight(h)
    -- level with the row, past the panel's right edge
    local dx = 8
    local pr, sr = panel.GetRight and panel:GetRight(), slot.GetRight and slot:GetRight()
    if type(pr) == "number" and type(sr) == "number" then dx = pr - sr + 8 end
    f:ClearAllPoints()
    f:SetPoint("LEFT", slot, "RIGHT", dx, 0)
    f:Show()
end

local function Draw()
    local rowsList, n = state.rows, #state.rows
    local here = state.here
    head.place:SetText(here and here.place or "")
    head.zone:SetText(here and here.zone or "")
    empty:SetShown(n == 0)
    state.offset = FL.Scroll(state.offset, state.sel, rowsList, state.viewH, RowHeight)
    local y, shown, i = 0, 0, 0
    while true do
        local at = state.offset + i + 1
        local row = rowsList[at]
        if not row or y + RowHeight(row) > state.viewH then break end
        i = i + 1
        local r = Slot(i)
        r.at = row.kind == "flight" and at or nil
        r:SetHeight(RowHeight(row))
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 6, -y)
        r:SetPoint("TOPRIGHT", -10, -y)
        if row.kind == "flight" then DrawFlight(r, row, at) else DrawZone(r, row) end
        r:Show()
        y = y + RowHeight(row)
        shown = shown + 1
    end
    for k = i + 1, #slots do slots[k].at = nil; slots[k]:Hide() end
    local chosen
    for k = 1, i do if slots[k].at and slots[k].at == state.sel then chosen = slots[k] end end
    DrawNote(chosen, chosen and rowsList[state.sel])
    local top, len = FL.Thumb(state.offset, shown, n, track:GetHeight() or 0)
    thumb:SetShown(top ~= nil)
    if top then
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -top)
        thumb:SetHeight(len)
    end
end

-- On the map: the ring and the route ---------------------------------------
local mapFrame     -- over TaxiRouteMap, ours: the ring
local routeFrame   -- at the map's own level: the route, under its node icons
local marker, lines, dots = nil, {}, {}
local glide = { fromX = nil, fromY = nil, toX = nil, toY = nil, t = 1 }

local function Map() return _G.TaxiRouteMap end

-- A node's point from the map's BOTTOMLEFT: where Blizzard placed its button
-- (it nudges overlapping ones apart), else from the node's own position
local function Point(index)
    local map = Map()
    local button = _G["TaxiButton" .. index]
    if button and button.GetPoint then
        local _, _, rp, x, y = Call(button.GetPoint, button, 1)
        if rp == "BOTTOMLEFT" and x and y then return x, y end
    end
    local nx, ny = Call(TaxiNodePosition, index)
    if not (nx and map) then return nil end
    return FL.NodePoint(nx, ny, map:GetWidth() or 0, map:GetHeight() or 0)
end

local function BuildMap()
    if mapFrame or not Map() then return mapFrame end
    local map = Map()
    mapFrame = CreateFrame("Frame", nil, map)
    mapFrame:SetAllPoints(map)
    mapFrame:SetFrameLevel((map:GetFrameLevel() or 1) + 20)
    mapFrame:EnableMouse(false)
    routeFrame = CreateFrame("Frame", nil, map)
    routeFrame:SetAllPoints(map)
    routeFrame:SetFrameLevel(map:GetFrameLevel() or 1)
    routeFrame:EnableMouse(false)

    marker = CreateFrame("Frame", nil, mapFrame)
    marker:SetSize(40, 40)
    marker:SetFrameLevel(mapFrame:GetFrameLevel() + 2)
    marker:EnableMouse(false)
    -- a warm glow inside, the gold ring
    marker.glow = marker:CreateTexture(nil, "ARTWORK")
    marker.glow:SetTexture(GLOW)
    marker.glow:SetSize(46, 46)
    marker.glow:SetPoint("CENTER")
    marker.glow:SetBlendMode("ADD")
    marker.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    marker.ring = marker:CreateTexture(nil, "OVERLAY")
    marker.ring:SetSize(34, 34)
    marker.ring:SetPoint("CENTER")
    if HasAtlas(RING) then
        marker.ring:SetAtlas(RING)
    else
        marker.ring:SetTexture(GLOW)
        marker.ring:SetBlendMode("ADD")
        marker.ring:SetVertexColor(1, 0.9, 0.6, 1)
    end
    -- breathing, slowly
    local breathe = marker:CreateAnimationGroup()
    breathe:SetLooping("BOUNCE")
    local grow = breathe:CreateAnimation("Scale")
    if grow.SetScaleFrom then grow:SetScaleFrom(1, 1); grow:SetScaleTo(1.12, 1.12)
    else grow:SetScale(1.12, 1.12) end
    grow:SetDuration(1.4)
    grow:SetSmoothing("IN_OUT")
    breathe:Play()
    marker.breathe = breathe

    -- (moving: the ring glides to the new place)
    marker:SetScript("OnUpdate", function(self, elapsed)
        if glide.t >= 1 then return end
        glide.t = math.min(1, glide.t + (elapsed or 0) / 0.16)
        local e = FL.Ease(glide.t)
        local x = glide.fromX + (glide.toX - glide.fromX) * e
        local y = glide.fromY + (glide.toY - glide.fromY) * e
        self:ClearAllPoints()
        self:SetPoint("CENTER", mapFrame, "BOTTOMLEFT", x, y)
    end)
    return mapFrame
end

-- the route: a dark under-line for the map's light parts, gold on it
local function Line(i)
    if lines[i] then return lines[i] end
    if not routeFrame.CreateLine then return {} end
    local under = routeFrame:CreateLine(nil, "ARTWORK", nil, 1)
    under:SetThickness(5)
    under:SetColorTexture(0.08, 0.05, 0.02, 0.55)
    local gold = routeFrame:CreateLine(nil, "ARTWORK", nil, 2)
    gold:SetThickness(2.5)
    gold:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.95)
    lines[i] = { under, gold }
    return lines[i]
end

local function Dot(i)
    if dots[i] then return dots[i] end
    local d = routeFrame:CreateTexture(nil, "ARTWORK", nil, 3)
    d:SetTexture(DISC)
    d:SetSize(7, 7)
    d:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    dots[i] = d
    return d
end

local function ClearRoute(from)
    for i = from, #lines do lines[i][1]:Hide(); lines[i][2]:Hide() end
    for i = from, #dots do dots[i]:Hide() end
end

local function DrawMap(instant)
    if not BuildMap() then return end
    local row = state.sel and state.rows[state.sel]
    local node = row and row.node
    if not node then marker:Hide(); ClearRoute(1); return end
    local x, y = Point(node.index)
    if not x then marker:Hide(); ClearRoute(1); return end
    -- the ring glides from where it was
    if instant or not marker:IsShown() or not glide.toX then
        glide.fromX, glide.fromY, glide.t = x, y, 1
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", mapFrame, "BOTTOMLEFT", x, y)
    else
        local e = FL.Ease(glide.t)
        glide.fromX = glide.fromX + (glide.toX - glide.fromX) * e
        glide.fromY = glide.fromY + (glide.toY - glide.fromY) * e
        glide.t = 0
    end
    glide.toX, glide.toY = x, y
    marker:Show()
    -- the route, stop by stop
    local n = tonumber(Call(GetNumRoutes, node.index)) or 0
    local drawn = 0
    for r = 1, n do
        local a, b = Call(TaxiGetNodeSlot, node.index, r, true), Call(TaxiGetNodeSlot, node.index, r, false)
        local ax, ay = Point(a or 0)
        local bx, by = Point(b or 0)
        if ax and bx then
            drawn = drawn + 1
            for _, l in ipairs(Line(drawn)) do
                l:SetStartPoint("BOTTOMLEFT", routeFrame, ax, ay)
                l:SetEndPoint("BOTTOMLEFT", routeFrame, bx, by)
                l:Show()
            end
            local d = Dot(drawn)
            d:ClearAllPoints()
            d:SetPoint("CENTER", routeFrame, "BOTTOMLEFT", bx, by)
            d:SetShown(r < n)   -- (a stop; the end has the ring)
        end
    end
    ClearRoute(drawn + 1)
end

-- Choosing and flying ---------------------------------------------------------
local function Node() local row = state.sel and state.rows[state.sel]; return row and row.node end

function Select(at)
    local row = at and state.rows[at]
    if not row or row.kind ~= "flight" or at == state.sel then return end
    state.sel = at
    Draw()
    DrawMap(false)
    if LegendText then LegendText() end
end

function Fly()
    local node = Node()
    if not node or InCombat() then return end
    FL.Remember(state.here and state.here.name, node.name)
    Call(TakeTaxiNode, node.index)
end

local function Move(delta, wrap) Select(FL.Next(state.rows, state.sel, delta, wrap)) end

-- The rows again (another view), the chosen place kept
local function Arrange(keep)
    local rows, start = FL.Arrange(state.nodes, {
        view = state.view, zone = state.here and state.here.zone or Call(GetZoneText),
        level = Call(UnitLevel, "player"), money = Call(GetMoney),
        last = FL.LastFrom(state.here and state.here.name), places = state.places,
    })
    state.rows = rows
    state.sel = keep and FL.Find(rows, keep.name) or start
    state.offset = 0
end

-- The legend (Blizzard's glyphs, as the bank's bar): two lines -----------------
local legends, prompts = nil, {}
-- a ringed dot in text: the ink ring, the dot drawn back over its middle
local function Mark(c)
    return ("|T%s:11:11:0:0:64:64:0:64:0:64:41:23:5|t|T%s:7:7:-9:0:64:64:0:64:0:64:%d:%d:%d|t")
        :format(DISC, DISC, c[1] * 255, c[2] * 255, c[3] * 255)
end
local MARKS = { PADLTRIGGER = { READY_DOT, "Turn-ins", "ready" }, PADRTRIGGER = { OPEN_DOT, "Quests", "open" } }
local function MakeLegend(name, list)
    local L = _G.InputPromptLegends
    local l = L.CreateInputLegend(inner, name)
    local divider = _G.GAMEPAD_PROMPT_DIVIDER_SLASH or "SLASH"
    for _, a in ipairs(list) do
        local prompt = l:GetOrCreatePromptFrameUsingTemplateAndInputs("StandardOneIcon", { a[1] }, divider)
        prompt:SetPromptText(a[2])
        prompt:EnablePrompt()
        prompt:Show()
        prompts[a[1]] = prompt
    end
    return l
end
local function Legends()
    if legends ~= nil then return legends or nil end
    legends = false
    local L = _G.InputPromptLegends
    if not (L and L.CreateInputLegend) then return nil end
    local ok, a, b = pcall(function()
        return MakeLegend("legend", {
            { "PAD1", "Fly" },
            { "PAD2", type(_G.FRAME_ACTION_CLOSE) == "string" and _G.FRAME_ACTION_CLOSE or "Close" },
            { "PAD4", "Nearest" },
        }), MakeLegend("legend2", {
            { "PAD3", "Again" },
            { "PADLTRIGGER", Mark(READY_DOT) .. "Turn-ins" },
            { "PADRTRIGGER", Mark(OPEN_DOT) .. "Quests" },
        })
    end)
    if ok and a and b then legends = { a, b } end
    return legends or nil
end

-- (gamepad mode only: unknown counts as off)
local function GamepadUI()
    local util = _G.InputUtil
    return util and util.IsGamepadUIEnabled and Call(util.IsGamepadUIEnabled) == true or false
end

-- Y names the other view; X, L2, R2 lit only when they can do something
function LegendText()
    local ls = Legends()
    if not ls then return end
    local function Lit(key, on)
        local p = prompts[key]
        if p then if on then Call(p.EnablePrompt, p) else Call(p.DisablePrompt, p) end end
    end
    if prompts.PAD4 then Call(prompts.PAD4.SetPromptText, prompts.PAD4, state.view == "near" and "Zones" or "Nearest") end
    Lit("PAD3", FL.Find(state.rows, FL.LastFrom(state.here and state.here.name)) ~= nil)
    for key, m in pairs(MARKS) do
        local p = prompts[key]
        if p then
            local pos, n = FL.Round(state.rows, state.sel, m[3])
            Call(p.SetPromptText, p, FL.Hint(Mark(m[1]), m[2], pos, n))
        end
        Lit(key, FL.Total(state.rows, m[3]) > 0)
    end
    for i, l in ipairs(ls) do
        l:Show()
        Call(l.ApplyDefaultPromptPositioning, l)
        l:ClearAllPoints()
        l:SetPoint("BOTTOM", inner, "BOTTOM", 0, i == 1 and 32 or 6)
    end
end

-- The pad -------------------------------------------------------------------------
local hold = { key = nil, wait = 0 }
local REPEAT = { PADDUP = -1, PADDDOWN = 1 }

-- a page: as many flights as fit
local function Page() return math.max(1, math.floor(state.viewH / ROW_H[state.view]) - 1) end

local function Zone(dir)
    if #state.rows == 0 then return end
    if state.view == "near" then Select(FL.Next(state.rows, nil, dir > 0 and -1 or 1, false)); return end
    Select(FL.Zone(state.rows, state.sel, dir))
end

local ACTIONS = {
    PADDUP = function() Move(-1, true) end,
    PADDDOWN = function() Move(1, true) end,
    PADLSHOULDER = function() Move(-Page(), false) end,
    PADRSHOULDER = function() Move(Page(), false) end,
    PADDLEFT = function() Zone(-1) end,
    PADDRIGHT = function() Zone(1) end,
    PAD1 = function() Fly() end,
    PAD2 = function() Call(CloseTaxiMap) end,
    PAD3 = function() Select(FL.Find(state.rows, FL.LastFrom(state.here and state.here.name))) end,
    PAD4 = function()
        local keep = Node()
        state.view = FL.VIEWS[state.view]
        Sh.CharDB().flightSort = state.view
        Arrange(keep)
        Draw()
        DrawMap(true)
        LegendText()
    end,
}
FL.ACTIONS = ACTIONS

-- L2 / R2 -----------------------------------------------------------------------------
-- While the list shows, L2 and R2 are ours: override bindings on our own secure frame, to two
-- buttons that jump (L2: turn-ins, R2: quests to do). As Fishing.lua does with the pole: they
-- change only when both triggers have been up FL.GRACE (Sh.Settler: never mid-press, the
-- stuck-L2 lesson), out of combat; in a fight the state driver drops them at once. The list
-- gone, L2 / R2 go back to the bars.
FL.GRACE = 0.25
local function Now() return GetTime and GetTime() or 0 end
local function Jump(key)
    if key and panel:IsShown() and not InCombat() then Select(FL.Jump(state.rows, state.sel, key)) end
end
for key, name in pairs(FL.TRIGGER_BUTTONS) do
    local b = CreateFrame("Button", name, UIParent)
    b:RegisterForClicks("AnyDown")
    b:SetScript("OnClick", function() Jump(FL.TRIGGER_JUMPS[key]) end)
end
local binds = CreateFrame("Frame", "GamepadCompanionFlightBinds", UIParent, "SecureHandlerStateTemplate")
binds:SetAttribute("_onstate-fight", [[ if newstate == "on" then self:ClearBindings() end self:CallMethod("Fight", newstate) ]])
local bound, bindsOn, bindsPending = {}, false, false
local function Wipe(t) for k in pairs(t) do t[k] = nil end end
local function TriggerHeld() local lt, rt = Sh.Held(); return lt or rt end
local settle = Sh.Settler(TriggerHeld, function() return FL.GRACE end, Now)
local bindWaiter = CreateFrame("Frame")
bindWaiter:Hide()

-- L2 / R2 to what they should be now (the list shown: ours; else the bars'); true when done
function FL.Bind()
    if InCombat() then bindsPending = true; return false end
    bindsPending = false
    local want = panel:IsShown() and true or false
    if want == bindsOn then bindWaiter:Hide(); return true end
    if not settle.Settled() then bindWaiter:Show(); return false end
    settle.Reset()
    bindWaiter:Hide()
    ClearOverrideBindings(binds)
    Wipe(bound)
    for key, action in pairs(FL.Binds(want)) do
        SetOverrideBindingClick(binds, true, key, FL.TRIGGER_BUTTONS[key], "LeftButton")
        bound[key] = action
    end
    bindsOn = want
    return true
end

-- (a trigger held: the change that waited)
bindWaiter:SetScript("OnUpdate", function()
    if InCombat() then bindWaiter:Hide(); bindsPending = true; return end
    if settle.Settled() then FL.Bind() end
end)
-- (a fight: the driver dropped them; after it, decided again)
function binds:Fight(newstate)
    if newstate == "on" then bindsOn = false; Wipe(bound) end
    bindsPending = true
    if not InCombat() then FL.Bind() end
end
if RegisterStateDriver then RegisterStateDriver(binds, "fight", "[combat] on; off") end
-- (Blizzard's sets took a trigger: ours again)
if Sh.Claim then
    Sh.Claim(bound, function()
        if InCombat() then bindsPending = true; return end
        bindsOn = false
        FL.Bind()
    end)
end

local function Take(on)
    if on and InCombat() then on = false end
    if on then Call(panel.SetPropagateKeyboardInput, panel, true) end
    Call(panel.EnableGamePadButton, panel, on)
end

panel:SetScript("OnGamePadButtonDown", function(self, button)
    if InCombat() then return end
    local act = ACTIONS[button]
    if not act then return end
    -- (this press stops here; from the next frame on, presses pass again)
    Call(self.SetPropagateKeyboardInput, self, false)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() if not InCombat() then Call(self.SetPropagateKeyboardInput, self, true) end end)
    end
    act()
    -- held up / down: on after a breath, stopping at the ends (no wrap)
    if REPEAT[button] then hold.key, hold.wait = button, 0.38 else hold.key = nil end
end)

panel:SetScript("OnUpdate", function(_, elapsed)
    if InCombat() then hold.key = nil; return end
    if not hold.key then return end
    local down = Sh.PadDown(Sh.PadButtons(), hold.key)
    if not down then hold.key = nil; return end
    hold.wait = hold.wait - (elapsed or 0)
    if hold.wait > 0 then return end
    hold.wait = 0.075
    Move(REPEAT[hold.key], false)
end)

-- Open / close ---------------------------------------------------------------------
local openedAt = 0

local function Api()
    return {
        count = Call(NumTaxiNodes) or 0,
        name = function(i) return Call(TaxiNodeName, i) end,
        type = function(i) return Call(TaxiNodeGetType, i) end,
        cost = function(i) return Call(TaxiNodeCost, i) end,
        pos = function(i) return Call(TaxiNodePosition, i) end,
        hops = function(i) return Call(GetNumRoutes, i) end,
    }
end

local function Layout(taxi)
    if panel:GetParent() ~= taxi then panel:SetParent(taxi) end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", taxi, "TOPRIGHT", -2, 0)
    panel:SetHeight(taxi:GetHeight() or 608)
    panel:SetFrameLevel((taxi:GetFrameLevel() or 1) + 5)
    local tall = inner:GetHeight() or 0
    if tall < 1 then tall = (panel:GetHeight() or 608) - 30 end
    state.viewH = math.max(3 * ROW_H.near, tall - HEAD_H - FOOT_H - 2)
end

-- The quests, from the game's own quest log (C_QuestLog, as OpenMap reads them): each one's zone
-- (its log header), ready or not, and its points on the zones' maps (GetQuestsOnMap: where to
-- go, or the one to turn it in to); the flight paths on the same maps (C_TaxiMap)
local zoneMaps   -- zone name -> uiMapID (the world's zones, once)
local function ZoneMaps()
    if zoneMaps then return zoneMaps end
    zoneMaps = {}
    local kind = _G.Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    local list = C_Map and Call(C_Map.GetMapChildrenInfo, 947, kind, true)
    for _, info in ipairs(type(list) == "table" and list or {}) do
        if type(info.name) == "string" and info.mapID and not zoneMaps[info.name] then zoneMaps[info.name] = info.mapID end
    end
    return zoneMaps
end

local function XY(pos)
    if type(pos) ~= "table" then return nil end
    if pos.x and pos.y then return pos.x, pos.y end
    if pos.GetXY then return Call(pos.GetXY, pos) end
end

-- A map point in the world's yards: { cont, x, y } (nil: unknown)
-- A map's continent map: its parents climbed to the first continent (nil: none known)
local CONTINENT = _G.Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
local continentOf = {}
local function ContinentOf(mapID)
    if type(mapID) ~= "number" then return nil end
    if continentOf[mapID] ~= nil then return continentOf[mapID] or nil end
    local id, found = mapID, false
    for _ = 1, 8 do
        local info = C_Map and Call(C_Map.GetMapInfo, id)
        if type(info) ~= "table" then break end
        if info.mapType == CONTINENT then found = id; break end
        if not info.parentMapID or info.parentMapID == 0 then break end
        id = info.parentMapID
    end
    continentOf[mapID] = found
    return found or nil
end

-- A map point in the world's yards: { cont, map (its continent map), x, y } (nil: unknown)
local function WorldOf(mapID, x, y)
    if not (mapID and x and y and C_Map and CreateVector2D) then return nil end
    local cont, pos = Call(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    local wx, wy = XY(pos)
    if type(cont) ~= "number" or type(wx) ~= "number" or type(wy) ~= "number" then return nil end
    return { cont = cont, map = ContinentOf(mapID), x = wx, y = wy }
end

-- The flight paths you can fly to, where they stand (C_TaxiMap on the continents' maps, as
-- OpenMap reads them); and each zone's centre
local CONTINENTS = { 1414, 1415 }   -- Kalimdor, the Eastern Kingdoms
local function Paths(nodes)
    local byName, out, seen = {}, {}, {}
    for _, node in ipairs(nodes) do
        byName[node.name] = node
        if not byName[node.place] then byName[node.place] = node end
    end
    local function Zone(node) return FL.ZoneName(node.zone) or node.place end
    for _, cont in ipairs(CONTINENTS) do
        local list = _G.C_TaxiMap and Call(C_TaxiMap.GetTaxiNodesForMap, cont)
        for _, info in ipairs(type(list) == "table" and list or {}) do
            local node = type(info.name) == "string" and (byName[info.name] or byName[(FL.SplitName(info.name))])
            if node and not seen[node.name] then
                local x, y = XY(info.position)
                seen[node.name] = true
                out[#out + 1] = { name = node.name, zone = Zone(node), at = WorldOf(cont, x, y) }
            end
        end
    end
    for _, node in ipairs(nodes) do
        if not seen[node.name] then out[#out + 1] = { name = node.name, zone = Zone(node) } end
    end
    local centres, maps = {}, ZoneMaps()
    for _, p in ipairs(out) do
        if centres[p.zone] == nil then centres[p.zone] = WorldOf(maps[p.zone], 0.5, 0.5) or false end
    end
    for z, c in pairs(centres) do if not c then centres[z] = nil end end
    return out, centres
end

FL.PathsOf = Paths   -- (FlightCard.lua: the route's lengths)

-- The quests in the log (C_QuestLog), each with its zone (its log header) and its point: its own
-- mark on its map (GetQuestsOnMap: where to go, or whom to turn it in to), else its next waypoint
-- (GetNextWaypoint: the objective in another zone); as OpenMap on the gamepad finds them
local function QuestList()
    local Q = _G.C_QuestLog
    if not Q then return {} end
    local cache = {}
    local function OnMap(mapID)
        if type(mapID) ~= "number" or mapID <= 0 then return {} end
        if not cache[mapID] then
            local list = Call(Q.GetQuestsOnMap, mapID)
            cache[mapID] = type(list) == "table" and list or {}
        end
        return cache[mapID]
    end
    local here = C_Map and Call(C_Map.GetBestMapForUnit, "player")
    -- -> at, how ("map <id>", "waypoint <id>", "none")
    local function At(id)
        for _, mapID in ipairs({ Call(_G.GetQuestUiMapID, id, true) or 0, Call(_G.GetQuestUiMapID, id, false) or 0, here or 0 }) do
            for _, poi in ipairs(OnMap(mapID)) do
                if poi.questID == id and poi.x and poi.y and not poi.isQuestStart then
                    local at = WorldOf(mapID, poi.x, poi.y)
                    if at then return at, "map " .. mapID end
                end
            end
        end
        local wMap, wx, wy = Call(Q.GetNextWaypoint, id)
        local at = WorldOf(wMap, wx, wy)
        return at, at and ("waypoint " .. tostring(wMap)) or "none"
    end
    local list, zone = {}, nil
    for i = 1, Call(Q.GetNumQuestLogEntries) or 0 do
        local info = Call(Q.GetInfo, i)
        if type(info) == "table" then
            if info.isHeader then
                zone = FL.ZoneName(info.title)
            elseif info.questID and not info.isHidden then
                local id = info.questID
                local ready = (Call(Q.ReadyForTurnIn, id) or Call(Q.IsComplete, id)) and true or false
                local at, how = At(id)
                list[#list + 1] = { ready = ready, zone = zone, at = at, how = how, title = info.title, level = info.level }
            end
        end
    end
    return list
end

-- Each flight path's quests: { [name] = { open, ready } }
local function Quests(nodes)
    local paths, centres = Paths(nodes)
    local list = QuestList()
    local counts = FL.Tally(list, paths, centres)
    Sh.CharDB().flightProbe = FL.Probe(list)
    return counts
end

function FL.Open()
    local taxi = _G.TaxiFrame
    if not FL.Wanted(FL.Enabled(), GamepadUI(), taxi and taxi:IsShown()) then return FL.Close() end
    Layout(taxi)
    state.here, state.nodes = FL.Read(Api())
    state.view = FL.View()
    state.places = Quests(state.nodes)
    Arrange(nil)
    openedAt = GetTime and GetTime() or 0
    panel:Show()
    -- (out of combat: Blizzard's cursor kept off our rows; the d-pad is ours)
    if not InCombat() and type(SmartNavigation_MarkFrameIgnored) == "function" then
        pcall(SmartNavigation_MarkFrameIgnored, panel)
    end
    Take(true)
    FL.Bind()
    Draw()
    DrawMap(true)
    LegendText()
end

function FL.Close()
    Take(false)
    hold.key = nil
    panel:Hide()
    FL.Bind()
    if marker then marker:Hide() end
    if mapFrame then ClearRoute(1) end
end

function FL.SetNote(on)
    Sh.CharDB().flightNote = on and true or false
    if panel:IsShown() then Draw() end
end

function FL.SetEnabled(on)
    Sh.CharDB().flightList = on and true or false
    if on then FL.Open() else FL.Close() end
end

-- The map's own hover (mouse or Blizzard's cursor) chooses the row too
if type(hooksecurefunc) == "function" and type(_G.TaxiNodeOnButtonEnter) == "function" then
    hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
        if not panel:IsShown() or (GetTime and GetTime() - openedAt < 0.4) then return end
        local index = button and button.GetID and button:GetID()
        for i, row in ipairs(state.rows) do if row.node and row.node.index == index then Select(i); return end end
    end)
end

local hooked = false
local function Hook()
    local taxi = _G.TaxiFrame
    if hooked or not (taxi and taxi.HookScript) then return end
    hooked = true
    taxi:HookScript("OnShow", function() if C_Timer and C_Timer.After then C_Timer.After(0, FL.Open) else FL.Open() end end)
    taxi:HookScript("OnHide", FL.Close)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_MONEY" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    Hook()
    if event == "PLAYER_REGEN_DISABLED" then Take(false); hold.key = nil
    elseif event == "PLAYER_REGEN_ENABLED" then
        if panel:IsShown() then Take(true) end
        if bindsPending then FL.Bind() end
    elseif event == "TAXIMAP_CLOSED" then FL.Close()
    elseif event == "PLAYER_MONEY" then if panel:IsShown() then Draw() end
    elseif event == "TAXIMAP_OPENED" and not panel:IsShown() then
        if C_Timer and C_Timer.After then C_Timer.After(0, FL.Open) else FL.Open() end
    end
end)
