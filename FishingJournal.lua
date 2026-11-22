-- The fishing journal: every catch kept from now on (per character), the
-- outing it belongs to, and the few facts worth saying on a catch's toast
-- (FishingToast.lua). Pure but for the loot window it reads: tests/FishingJournal.lua
local _, ns = ...
local J = {}
ns.FishingJournal = J

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if ok then return a, b, c, d, e, f end
end

---------------------------------------------------------------------------
-- The record (CharDB.fishJournal)
--   total            catches ever (loot windows)
--   kinds[id]        { name, icon, q, n (catches), items (with stacks), first (time) }
--   waters[key]      { n, kinds = { [id] = n } }   key "Zone/Subzone"
--   log              { { t, id, n, w } } the last LOG_MAX items caught
--   outing           { start, last, n, kinds = { [id] = n }, runs = { [id] = catches in a row } }
--   outings          { { start, stop, n } } the last OUTINGS_MAX outings
---------------------------------------------------------------------------
J.LOG_MAX, J.OUTINGS_MAX = 500, 100
J.OUTING_GAP = 15 * 60   -- s without a catch: a new outing

function J.Fresh(db)
    if type(db) ~= "table" then db = {} end
    db.total = tonumber(db.total) or 0
    for _, k in ipairs({ "kinds", "waters", "log", "outings" }) do
        if type(db[k]) ~= "table" then db[k] = {} end
    end
    return db
end

function J.Water(zone, sub)
    zone, sub = zone or "", sub or ""
    if sub == "" or sub == zone then return zone end
    return zone .. "/" .. sub
end

-- The outing a catch at `now` belongs to: the current one, else a new one
-- (the old kept in outings)
local function Outing(db, now)
    local o = db.outing
    if type(o) == "table" and tonumber(o.last) and now - o.last <= J.OUTING_GAP then return o, false end
    if type(o) == "table" and (tonumber(o.n) or 0) > 0 then
        table.insert(db.outings, { start = o.start, stop = o.last, n = o.n })
        while #db.outings > J.OUTINGS_MAX do table.remove(db.outings, 1) end
    end
    o = { start = now, last = now, n = 0, kinds = {}, runs = {} }
    db.outing = o
    return o, true
end

-- One catch: items { { id, name, icon, q, n } } from one loot window, the
-- water (key and the place's name to show) and the time (time()). Returns
-- for each item: { id, name, icon, q, n, ever (catches of it now), first
-- (its first catch's time), total (all catches), firstEver, firstHere, here
-- (of it in this water), hereTotal (catches in this water), outing (of it
-- this outing), outingTotal, run (catches of it in a row), newOuting, place }
function J.Record(db, items, water, now, place)
    db = J.Fresh(db)
    if type(items) ~= "table" or #items == 0 then return {} end
    water = water or ""
    local o, newOuting = Outing(db, now)
    o.last, o.n = now, o.n + 1
    db.total = db.total + 1
    local w = db.waters[water]
    if type(w) ~= "table" then w = { n = 0, kinds = {} }; db.waters[water] = w end
    w.n = w.n + 1
    if type(o.runs) ~= "table" then o.runs = {} end
    local out, seen, runs = {}, {}, {}
    for _, item in ipairs(items) do
        local id = tonumber(item.id)
        if id and not seen[id] then
            seen[id] = true
            local k = db.kinds[id]
            local firstEver = type(k) ~= "table"
            if firstEver then k = { n = 0, items = 0, first = now }; db.kinds[id] = k end
            k.name = item.name or k.name
            k.icon = item.icon or k.icon
            k.q = tonumber(item.q) or k.q
            k.n = k.n + 1
            k.items = k.items + (tonumber(item.n) or 1)
            local firstHere = not w.kinds[id]
            w.kinds[id] = (w.kinds[id] or 0) + 1
            o.kinds[id] = (o.kinds[id] or 0) + 1
            runs[id] = (o.runs[id] or 0) + 1
            table.insert(db.log, { t = now, id = id, n = tonumber(item.n) or 1, w = water })
            out[#out + 1] = { id = id, name = k.name, icon = k.icon, q = k.q or 1, n = tonumber(item.n) or 1,
                ever = k.n, first = k.first, total = db.total, firstEver = firstEver, firstHere = firstHere,
                here = w.kinds[id], hereTotal = w.n, outing = o.kinds[id], outingTotal = o.n, run = runs[id],
                newOuting = newOuting, water = water, place = place or water }
        end
    end
    o.runs = runs
    while #db.log > J.LOG_MAX do table.remove(db.log, 1) end
    return out
end

-- The one item a toast is about: the rarest (so anything over grey junk),
-- then the first listed
function J.Best(list)
    local best
    for _, c in ipairs(list or {}) do
        if not best or (c.q or 1) > (best.q or 1) then best = c end
    end
    return best
end

-- This kind's share of the catches in a water, 0-1, or nil below `enough`
J.ENOUGH = 20
function J.Share(here, hereTotal, enough)
    here, hereTotal = tonumber(here), tonumber(hereTotal)
    if not (here and hereTotal) or hereTotal < (enough or J.ENOUGH) then return nil end
    return here / hereTotal
end

---------------------------------------------------------------------------
-- The game: what a fishing loot window holds
---------------------------------------------------------------------------
function J.ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

function J.Loot()
    local items = {}
    for i = 1, tonumber((Call(GetNumLootItems))) or 0 do
        local icon, name, count, _, quality = Call(GetLootSlotInfo, i)
        local id = J.ItemID(Call(GetLootSlotLink, i))
        if id then
            -- (the quality from the item when the slot's doesn't say)
            quality = tonumber(quality) or (C_Item and tonumber((Call(C_Item.GetItemQualityByID, id)))) or 1
            items[#items + 1] = { id = id, name = name, icon = icon, q = quality, n = tonumber(count) or 1 }
        end
    end
    return items
end

function J.DB()
    local char = ns.Shared.CharDB()
    char.fishJournal = J.Fresh(char.fishJournal)
    return char.fishJournal
end
