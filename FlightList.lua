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

-- Each quest to its flight path: quests = { { ready, zone (its log header's), points =
-- { { zone, x, y } } } }, places[zone] = { { name, x, y } } on that zone's map.
-- A quest goes to the flight path nearest its first point in a zone with flights; no such point:
-- its log zone only. -> per zone { open, ready }, per flight path (name) { open, ready }
function FL.Tally(quests, places)
    local zones, paths = {}, {}
    local function Add(t, key, ready)
        local c = t[key] or { open = 0, ready = 0 }
        t[key] = c
        if ready then c.ready = c.ready + 1 else c.open = c.open + 1 end
    end
    for _, q in ipairs(quests or {}) do
        local zone, near = q.zone, nil
        for _, pt in ipairs(q.points or {}) do
            local best, bd = nil, nil
            for _, n in ipairs((places or {})[pt.zone] or {}) do
                local dx, dy = n.x - pt.x, n.y - pt.y
                local d = dx * dx + dy * dy
                if not bd or d < bd then best, bd = n.name, d end
            end
            if best then zone, near = pt.zone, best; break end
        end
        if zone then Add(zones, zone, q.ready) end
        if near then Add(paths, near, q.ready) end
    end
    return zones, paths
end

-- L2 / R2 read from the pad: t = { lt, rt, at } (what they were, the last press's time);
-- a press is a trigger going down, a quarter second after the last one.
-- -> "ready" (L2), "open" (R2) or nil
function FL.Press(t, lt, rt, now)
    if lt == nil and rt == nil then return nil end
    local key = (lt and not t.lt and "ready") or (rt and not t.rt and "open") or nil
    t.lt, t.rt = lt and true or false, rt and true or false
    return FL.Tap(t, key, now)
end

-- A press of key, unless one came a quarter second ago (the button and the pad's state both see it)
function FL.Tap(t, key, now)
    if not key or (now or 0) - (t.at or -1) < 0.25 then return nil end
    t.at = now or 0
    return key
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
    local ranges, quests, L, money = ctx.ranges or FL.ZONES, ctx.quests or {}, ctx.level, ctx.money
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
        local q = quests[g.zone] or {}
        g.open, g.ready = q.open or 0, q.ready or 0
        g.tier = FL.Tier(L, g.range)
        g.dim = g.tier == "grey" and not g.city
        g.score = 30 * g.ready + 10 * math.min(g.open, 5) + FL.Fit(L, g.range, g.city)
            + (g.zone == lastZone and 5 or 0) - 20 * g.minDist - (g.afford and 0 or 1000)
    end
    local rows = {}
    local function Flight(node, g)
        local q = (ctx.places or {})[node.name] or {}
        return { kind = "flight", node = node, g = g, open = q.open or 0, ready = q.ready or 0 }
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
-- again, the next one, round. No path known for any: the zone with the most, its first flight.
-- nil when none has any
function FL.Jump(rows, sel, key)
    local cands = {}
    for i, r in ipairs(rows) do if r.kind == "flight" and (r[key] or 0) > 0 then cands[#cands + 1] = i end end
    if #cands > 0 then
        table.sort(cands, function(a, b)
            local ra, rb = rows[a], rows[b]
            if ra[key] ~= rb[key] then return ra[key] > rb[key] end
            local sa, sb = ra.g and ra.g.score or 0, rb.g and rb.g.score or 0
            if sa ~= sb then return sa > sb end
            return a < b
        end)
        local pos = 0
        for p, i in ipairs(cands) do if i == sel then pos = p end end
        return cands[pos % #cands + 1]
    end
    local gs = {}
    for _, g in ipairs(Groups(rows)) do if (g[key] or 0) > 0 then gs[#gs + 1] = g end end
    if #gs == 0 then return nil end
    for i, g in ipairs(gs) do g.rank = i end
    table.sort(gs, function(a, b)
        if a[key] ~= b[key] then return a[key] > b[key] end
        if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
        return a.rank < b.rank
    end)
    local cur = rows[sel] and rows[sel].g
    local pos = 0
    for p, g in ipairs(gs) do if g == cur then pos = p end end
    return FirstOf(rows, gs[pos % #gs + 1])
end

-- Every zone's count of key, added
function FL.Total(rows, key)
    local n = 0
    for _, g in ipairs(Groups(rows)) do n = n + (g[key] or 0) end
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

local state = { here = nil, nodes = {}, rows = {}, sel = nil, offset = 0, viewH = 400, view = "zones", quests = {} }

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
local Select, Fly   -- (below)

-- a dot: gold, a quest to turn in; brown, a quest to do
local function Dot(parent, color, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(DISC)
    t:SetSize(size, size)
    t:SetVertexColor(color[1], color[2], color[3], 1)
    return t
end

local function Badge(parent, color)
    return Dot(parent, color, 8), Text(parent, BODY_FONT, 11, INK, "LEFT")
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
    for d = 1, 2 * FL.DOTS do r.dots[d] = Dot(r, d <= FL.DOTS and READY_DOT or OPEN_DOT, 6) end
    -- a zone's row: its name and levels, its quests, a hairline
    r.head = CreateFrame("Frame", nil, r)
    r.head:SetAllPoints()
    r.head.name = Text(r.head, TITLE_FONT, 13, INK)
    r.head.name:SetPoint("BOTTOMLEFT", 6, 4)
    r.head.range = Text(r.head, BODY_FONT, 10, INK)
    r.head.range:SetPoint("BOTTOMLEFT", r.head.name, "BOTTOMRIGHT", 6, 1)
    r.head.readyIcon, r.head.ready = Badge(r.head, READY_DOT)
    r.head.openIcon, r.head.open = Badge(r.head, OPEN_DOT)
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

-- the zone's totals, right to left: turn-ins nearest the edge, then quests to do
local function Badges(h, g)
    local right = -2
    for _, b in ipairs({ { h.readyIcon, h.ready, g.ready }, { h.openIcon, h.open, g.open } }) do
        local icon, num, count = b[1], b[2], b[3] or 0
        icon:SetShown(count > 0)
        num:SetShown(count > 0)
        if count > 0 then
            num:SetText(count)
            num:ClearAllPoints()
            num:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", right, 5)
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT", num, "LEFT", -2, 0)
            right = right - (num:GetStringWidth() or 8) - 16
        end
    end
end

local function HideDots(r) for _, d in ipairs(r.dots) do d:Hide() end end

-- the dots right to left from x (px from the row's right edge), y from its top; their width
local function DrawDots(r, row, x, y)
    HideDots(r)
    local ready, open = math.min(FL.DOTS, row.ready or 0), math.min(FL.DOTS, row.open or 0)
    local n = 0
    for k = open, 1, -1 do
        local d = r.dots[FL.DOTS + k]
        d:ClearAllPoints()
        d:SetPoint("CENTER", r, "TOPRIGHT", x - 3 - n * 7, y)
        d:Show()
        n = n + 1
    end
    if ready > 0 and open > 0 then n = n + 0.5 end
    for k = ready, 1, -1 do
        local d = r.dots[k]
        d:ClearAllPoints()
        d:SetPoint("CENTER", r, "TOPRIGHT", x - 3 - n * 7, y)
        d:Show()
        n = n + 1
    end
    return n * 7
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
    Badges(h, g)
    h:Show()
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
        level = Call(UnitLevel, "player"), money = Call(GetMoney), quests = state.quests,
        last = FL.LastFrom(state.here and state.here.name), places = state.places,
    })
    state.rows = rows
    state.sel = keep and FL.Find(rows, keep.name) or start
    state.offset = 0
end

-- The legend (Blizzard's glyphs, as the bank's bar): two lines -----------------
local legends, prompts = nil, {}
local function Mark(c)
    return ("|T%s:9:9:0:0:64:64:0:64:0:64:%d:%d:%d|t "):format(DISC, c[1] * 255, c[2] * 255, c[3] * 255)
end
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
local function LegendText()
    local ls = Legends()
    if not ls then return end
    local function Lit(key, on)
        local p = prompts[key]
        if p then if on then Call(p.EnablePrompt, p) else Call(p.DisablePrompt, p) end end
    end
    if prompts.PAD4 then Call(prompts.PAD4.SetPromptText, prompts.PAD4, state.view == "near" and "Zones" or "Nearest") end
    Lit("PAD3", FL.Find(state.rows, FL.LastFrom(state.here and state.here.name)) ~= nil)
    Lit("PADLTRIGGER", FL.Total(state.rows, "ready") > 0)
    Lit("PADRTRIGGER", FL.Total(state.rows, "open") > 0)
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

-- L2 / R2: only read, never taken or rebound (the game still gets the press: L2 its bar,
-- R2 its Ctrl). Two ways in, one press: the pad's state (each frame) and the button's own press
local trig = { lt = false, rt = false, at = -1 }
local function Now() return GetTime and GetTime() or 0 end
local function Jump(key) if key then Select(FL.Jump(state.rows, state.sel, key)) end end
local function Triggers()
    local lt, rt = Sh.Held()
    Jump(FL.Press(trig, lt, rt, Now()))
end
FL.TRIGGERS = { PADLTRIGGER = "ready", PADRTRIGGER = "open" }

local function Take(on)
    if on and InCombat() then on = false end
    if on then Call(panel.SetPropagateKeyboardInput, panel, true) end
    Call(panel.EnableGamePadButton, panel, on)
end

panel:SetScript("OnGamePadButtonDown", function(self, button)
    if InCombat() then return end
    -- (a trigger: read, passed on to the game as it is)
    if FL.TRIGGERS[button] then Jump(FL.Tap(trig, FL.TRIGGERS[button], Now())); return end
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
    Triggers()
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

local function Quests(nodes)
    local Q = _G.C_QuestLog
    if not Q then return {}, {} end
    local list, byId = {}, {}
    local function Ready(id)
        return (Call(Q.ReadyForTurnIn, id) or Call(Q.IsComplete, id)) and true or false
    end
    local function Add(id, zone)
        local q = { id = id, ready = Ready(id), zone = zone, points = {} }
        list[#list + 1] = q
        byId[id] = q
        return q
    end
    -- the log: each quest under its zone's header
    local n = Call(Q.GetNumQuestLogEntries) or 0
    local zone
    for i = 1, n do
        local info = Call(Q.GetInfo, i)
        if type(info) == "table" then
            if info.isHeader then
                zone = FL.ZoneName(info.title)
                if FL.ZONES[zone] == nil then zone = nil end
            elseif info.questID and not info.isHidden and not byId[info.questID] then
                Add(info.questID, zone)
            end
        end
    end
    -- the zones with flights: their quests' points and their flight paths
    local maps, places, seen = ZoneMaps(), {}, {}
    for _, node in ipairs(nodes) do
        local z = FL.ZoneName(node.zone) or node.place
        local id = maps[z] or maps[node.zone or ""]
        if not seen[z] and id then
            seen[z] = true
            places[z] = {}
            local taxi = _G.C_TaxiMap and Call(C_TaxiMap.GetTaxiNodesForMap, id)
            for _, info in ipairs(type(taxi) == "table" and taxi or {}) do
                local place = FL.SplitName(info.name)
                local x, y = XY(info.position)
                for _, other in ipairs(nodes) do
                    if other.place == place and x then places[z][#places[z] + 1] = { name = other.name, x = x, y = y } end
                end
            end
            local pois = Call(Q.GetQuestsOnMap, id)
            for _, poi in ipairs(type(pois) == "table" and pois or {}) do
                local qid = poi.questID
                if qid and poi.x and poi.y and not poi.isMapIndicatorQuest then
                    local q = byId[qid]
                    if not q and (not Q.IsOnQuest or Call(Q.IsOnQuest, qid)) then q = Add(qid, nil) end
                    if q then q.points[#q.points + 1] = { zone = z, x = poi.x, y = poi.y } end
                end
            end
        end
    end
    return FL.Tally(list, places)
end

function FL.Open()
    local taxi = _G.TaxiFrame
    if not FL.Wanted(FL.Enabled(), GamepadUI(), taxi and taxi:IsShown()) then return FL.Close() end
    Layout(taxi)
    state.here, state.nodes = FL.Read(Api())
    state.view = FL.View()
    state.quests, state.places = Quests(state.nodes)
    Arrange(nil)
    trig.lt, trig.rt = Sh.Held()
    trig.lt, trig.rt = trig.lt or false, trig.rt or false
    openedAt = GetTime and GetTime() or 0
    panel:Show()
    -- (out of combat: Blizzard's cursor kept off our rows; the d-pad is ours)
    if not InCombat() and type(SmartNavigation_MarkFrameIgnored) == "function" then
        pcall(SmartNavigation_MarkFrameIgnored, panel)
    end
    Take(true)
    Draw()
    DrawMap(true)
    LegendText()
end

function FL.Close()
    Take(false)
    hold.key = nil
    panel:Hide()
    if marker then marker:Hide() end
    if mapFrame then ClearRoute(1) end
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
    elseif event == "PLAYER_REGEN_ENABLED" then if panel:IsShown() then Take(true) end
    elseif event == "TAXIMAP_CLOSED" then FL.Close()
    elseif event == "PLAYER_MONEY" then if panel:IsShown() then Draw() end
    elseif event == "TAXIMAP_OPENED" and not panel:IsShown() then
        if C_Timer and C_Timer.After then C_Timer.After(0, FL.Open) else FL.Open() end
    end
end)
