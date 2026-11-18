-- When: a moment's thresholds, as data (design audit H9, Fable critique N11).
-- Each moment that waits for a level lists its knobs here, with the value it
-- ships with; the row shows them as a small When chip ("below 35 %") and a
-- click opens a stepper with Default. Saved in the Feel profile (`when`),
-- only where they differ; landing keeps its older keys (landMin, landMax).
local _, ns = ...
local W = {}
ns.When = W

local function Pct(v) return math.floor(v * 100 + 0.5) .. " %" end
local function Secs(v) return string.format("%.2f s", v) end

-- { key, label (in the stepper), words (on the chip), default, step, min, max, format, saved = an older key }
W.PARAMS = {
    lowHp = { { key = "below", label = "Below", words = "below", default = 0.35, step = 0.05, min = 0.1, max = 0.6, format = Pct,
        note = "Health hidden in a fight: the game's warning (35 %)" } },
    heartbeat = { { key = "below", label = "Below", words = "below", default = 0.5, step = 0.05, min = 0.1, max = 0.9, format = Pct } },
    oom = { { key = "below", label = "Mana below", words = "below", default = 0.15, step = 0.05, min = 0.05, max = 0.5, format = Pct } },
    landing = {
        { key = "soft", label = "Soft at", words = "soft", default = 0.5, step = 0.05, min = 0.2, max = 3, format = Secs, saved = "landMin" },
        { key = "full", label = "Full at", words = "full", default = 1.2, step = 0.05, min = 0.25, max = 4, format = Secs, saved = "landMax" },
    },
}

local function DB()
    local H = ns.Haptics
    local db = H and H.DB and H.DB() or {}
    if type(db.when) ~= "table" then db.when = {} end
    return db
end

local function Param(moment, key)
    for _, p in ipairs(W.PARAMS[moment] or {}) do if p.key == key then return p end end
end
W.Param = Param

function W.Has(moment) return W.PARAMS[moment] ~= nil end

-- A knob's value now: the player's, else as it ships
function W.Get(moment, key)
    local p = Param(moment, key)
    if not p then return nil end
    local db = DB()
    local v
    if p.saved then v = db[p.saved] else v = type(db.when[moment]) == "table" and db.when[moment][key] or nil end
    if type(v) ~= "number" then return p.default end
    return v
end

-- nil: back to as it ships. Soft stays under Full (0.05 apart)
function W.Set(moment, key, v)
    local p = Param(moment, key)
    if not p then return end
    if v ~= nil then v = math.max(p.min, math.min(p.max, v)) end
    if v ~= nil and math.abs(v - p.default) < 1e-6 then v = nil end
    local db = DB()
    if p.saved then db[p.saved] = v
    else
        if type(db.when[moment]) ~= "table" then db.when[moment] = {} end
        db.when[moment][key] = v
        if next(db.when[moment]) == nil then db.when[moment] = nil end
    end
    if moment == "landing" and v then
        local soft, full = W.Get("landing", "soft"), W.Get("landing", "full")
        if key == "soft" and full <= soft then W.Set("landing", "full", soft + 0.05) end
        if key == "full" and soft >= full then W.Set("landing", "soft", full - 0.05) end
    end
end

function W.IsDefault(moment)
    for _, p in ipairs(W.PARAMS[moment] or {}) do
        if math.abs(W.Get(moment, p.key) - p.default) > 1e-6 then return false end
    end
    return true
end

function W.Default(moment)
    for _, p in ipairs(W.PARAMS[moment] or {}) do W.Set(moment, p.key, nil) end
end

-- The chip's words: "below 35 %", "soft 0.50 s · full 1.20 s"
function W.Words(moment)
    local parts = {}
    for _, p in ipairs(W.PARAMS[moment] or {}) do parts[#parts + 1] = p.words .. " " .. p.format(W.Get(moment, p.key)) end
    return table.concat(parts, " · ")
end

-- What Default changes, to put back (Undo)
function W.Snapshot(moment)
    local was = {}
    for _, p in ipairs(W.PARAMS[moment] or {}) do was[p.key] = W.Get(moment, p.key) end
    return function()
        for _, p in ipairs(W.PARAMS[moment] or {}) do W.Set(moment, p.key, was[p.key]) end
    end
end
