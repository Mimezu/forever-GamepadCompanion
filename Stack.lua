-- Stack: one state stack for every kind of output (lights now, triggers next), on FrameGambit's
-- model and words (docs/STACK.md):
--
--   Moments (crits, spells, whispers)   on top, brief: each kind plays them, then hands back
--   Reactions, in the player's order    checked top to bottom: the first match sets each channel it
--                                       has (a channel it leaves empty: Pass, the next match's)
--   Otherwise                           when nothing matches
--
-- A reaction: a condition, its requirements (all must be true), On / Off, and a value per channel.
-- Conditions come in families (Player, Target, Travel, Group & instances, System, Events); some
-- take a percentage and an operator (Health percentage < 35); events hold for a duration that
-- restarts. Read on their events, never every frame. A kind (lights: bar, mic, dots; triggers: L2,
-- R2) registers its channels; its reactions live in its Feel-profile table, Recommended ships.
local _, ns = ...
local St = {}
ns.Stack = St

local floor, min, max = math.floor, math.min, math.max

-- A value the game keeps from addons (health, speed... in combat): never compared or counted
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) == true end
St.Secret = secret

-- A game call: its results, a secret one as nil (unknown, never an error)
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    if secret(a) then a = nil end
    if secret(b) then b = nil end
    return a, b
end

-- Moving, from the game's own events when the speed is secret (set in the event handler below)
local movingByEvent = false
local function Moving()
    local speed = call(GetUnitSpeed, "player")
    if speed == nil then return movingByEvent end
    return (tonumber(speed) or 0) > 0
end
local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Conditions (FrameGambit's families and words, the ones a pad uses)
---------------------------------------------------------------------------
St.CATEGORIES = {
    { id = "player", label = "Player" },
    { id = "target", label = "Target" },
    { id = "travel", label = "Travel" },
    { id = "social", label = "Group & instances" },
    { id = "system", label = "System" },
    { id = "moment", label = "Events" },
}
St.OPERATORS = {
    { id = "<", label = "Less than" }, { id = "<=", label = "At most" },
    { id = "=", label = "Equal to" }, { id = "~=", label = "Not equal to" },
    { id = ">=", label = "At least" }, { id = ">", label = "More than" },
}
local COMPARE = {
    ["<"] = function(a, b) return a < b end, ["<="] = function(a, b) return a <= b end,
    ["="] = function(a, b) return a == b end, ["~="] = function(a, b) return a ~= b end,
    [">="] = function(a, b) return a >= b end, [">"] = function(a, b) return a > b end,
}

local conds, condList = {}, {}
local flags = {}       -- state key -> true while it holds
local values = {}      -- percentage key -> 0-100 now
local moments = {}     -- moment key -> when it last happened
local kinds = {}

-- A condition: key, { label, category, kind = "state" | "moment", test = fn -> bool, value = fn ->
-- 0-100 (a percentage), events = { ... }, duration = s (a moment) }. No test or value: pushed
-- (Stack.Set / Stack.Fire / Stack.SetValue).
function St.Condition(key, def)
    def.key = key
    def.kind = def.kind or "state"
    if not conds[key] then condList[#condList + 1] = def end
    conds[key] = def
    return def
end
function St.Conditions() return condList end
-- A condition a kind's reactions can use (some are for one kind only: Hush, Feel's)
function St.Offered(key, kind)
    local c = conds[key]
    return c ~= nil and (c.kinds == nil or (kind ~= nil and c.kinds[kind] == true))
end
function St.Info(key) return conds[key] end
function St.Label(key) return conds[key] and conds[key].label or key end
function St.IsPercentage(key) return conds[key] and conds[key].value ~= nil or false end

local function Pct(cur, top)
    cur, top = tonumber(cur), tonumber(top)
    if not (cur and top and top > 0) then return nil end
    return cur / top * 100
end

-- Player
St.Condition("combat", { label = "In combat", category = "player", test = function() return call(UnitAffectingCombat, "player") == true end,
    events = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" } })
St.Condition("out_of_combat", { label = "Out of combat", category = "player", test = function() return call(UnitAffectingCombat, "player") ~= true end,
    events = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" } })
St.Condition("moving", { label = "Movement", category = "player", test = Moving,
    events = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" } })
St.Condition("cast", { label = "Casting", category = "player" })
St.Condition("dead", { label = "Dead or ghost", category = "player", test = function() return call(UnitIsDeadOrGhost, "player") == true end,
    events = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" } })
St.Condition("stealth", { label = "Stealthed / invisible", category = "player", test = function() return call(IsStealthed) == true end,
    events = { "UPDATE_STEALTH" } })
St.Condition("lowHp", { label = "Low health", category = "player" })   -- (Rumble's heartbeat threshold)
St.Condition("player_health", { label = "Health percentage", category = "player",
    value = function() return Pct(call(UnitHealth, "player"), call(UnitHealthMax, "player")) end,
    events = { "UNIT_HEALTH", "UNIT_MAXHEALTH" } })
St.Condition("player_power", { label = "Power percentage", category = "player",
    value = function() return Pct(call(UnitPower, "player"), call(UnitPowerMax, "player")) end,
    events = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } })
St.Condition("halo", { label = "Halo ring open", category = "player" })
-- Target
St.Condition("target_any", { label = "Has any target", category = "target", test = function() return call(UnitExists, "target") == true end,
    events = { "PLAYER_TARGET_CHANGED" } })
St.Condition("target_hostile", { label = "Has hostile target", category = "target",
    test = function() return call(UnitExists, "target") == true and call(UnitCanAttack, "player", "target") == true end,
    events = { "PLAYER_TARGET_CHANGED", "UNIT_FACTION" } })
St.Condition("target_friendly", { label = "Has friendly target", category = "target",
    test = function() return call(UnitExists, "target") == true and call(UnitIsFriend, "player", "target") == true end,
    events = { "PLAYER_TARGET_CHANGED", "UNIT_FACTION" } })
St.Condition("no_target", { label = "No target", category = "target", test = function() return call(UnitExists, "target") ~= true end,
    events = { "PLAYER_TARGET_CHANGED" } })
St.Condition("target_health", { label = "Target health percentage", category = "target",
    value = function() if call(UnitExists, "target") then return Pct(call(UnitHealth, "target"), call(UnitHealthMax, "target")) end end,
    events = { "PLAYER_TARGET_CHANGED", "UNIT_HEALTH" } })
-- Travel
St.Condition("mounted", { label = "Mounted", category = "travel", test = function() return call(IsMounted) == true end,
    events = { "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_AURA", "PLAYER_STARTED_MOVING" } })
St.Condition("swimming", { label = "Swimming", category = "travel", test = function() return call(IsSwimming) == true end,
    events = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "MIRROR_TIMER_START", "MIRROR_TIMER_STOP" } })
St.Condition("underwater", { label = "Underwater", category = "travel", test = function() return call(IsSubmerged) == true end,
    events = { "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" } })
St.Condition("taxi", { label = "On flight path", category = "travel", test = function() return call(UnitOnTaxi, "player") == true end,
    events = { "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" } })
-- Group & instances
St.Condition("rested", { label = "Resting", category = "social", test = function() return call(IsResting) == true end,
    events = { "PLAYER_UPDATE_RESTING" } })
St.Condition("group", { label = "In party", category = "social", test = function() return call(IsInGroup) == true and call(IsInRaid) ~= true end,
    events = { "GROUP_ROSTER_UPDATE" } })
St.Condition("raid", { label = "In raid", category = "social", test = function() return call(IsInRaid) == true end, events = { "GROUP_ROSTER_UPDATE" } })
St.Condition("solo", { label = "Solo", category = "social", test = function() return call(IsInGroup) ~= true end, events = { "GROUP_ROSTER_UPDATE" } })
St.Condition("instance", { label = "In an instance", category = "social", test = function() return call(IsInInstance) == true end,
    events = { "ZONE_CHANGED_NEW_AREA" } })
St.Condition("indoors", { label = "Indoors", category = "social", test = function() return call(IsIndoors) == true end,
    events = { "ZONE_CHANGED_INDOORS", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA" } })
St.Condition("outdoors", { label = "Outdoors", category = "social", test = function() return call(IsOutdoors) == true end,
    events = { "ZONE_CHANGED_INDOORS", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA" } })
-- System
St.Condition("hush", { label = "Hush", category = "system", kinds = { feel = true } })   -- (Hush.lua: the footer's chip, or when resting)
St.Condition("afk", { label = "Away", category = "system", test = function() return call(UnitIsAFK, "player") == true end,
    events = { "PLAYER_FLAGS_CHANGED" } })
-- Events: true for a while after they happen (again: the while restarts)
St.Condition("whispered", { label = "New private message", category = "moment", kind = "moment", duration = 10,
    events = { "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" } })
St.Condition("xp_gained", { label = "XP gained", category = "moment", kind = "moment", duration = 5, events = { "PLAYER_XP_UPDATE" } })
St.Condition("loot", { label = "Looted an item", category = "moment", kind = "moment", duration = 4, events = { "CHAT_MSG_LOOT" } })
St.Condition("quest_turned_in", { label = "Quest turned in", category = "moment", kind = "moment", duration = 3, events = { "QUEST_TURNED_IN" } })
St.Condition("level_up", { label = "Level up", category = "moment", kind = "moment", duration = 5, events = { "PLAYER_LEVEL_UP" } })

-- Requirements that can't hold together (FrameGambit's, the pad's ones)
local EXCLUSIVE = {
    { "combat", "out_of_combat" }, { "target_hostile", "target_friendly" }, { "group", "raid", "solo" },
    { "indoors", "outdoors" }, { "no_target", "target_any" }, { "no_target", "target_hostile" },
    { "no_target", "target_friendly" }, { "no_target", "target_health" }, { "taxi", "swimming" },
    { "taxi", "underwater" }, { "taxi", "mounted" }, { "dead", "mounted" }, { "dead", "cast" },
}
local CONFLICTS = {}
for _, g in ipairs(EXCLUSIVE) do
    for i = 1, #g - 1 do
        for j = i + 1, #g do
            CONFLICTS[g[i]] = CONFLICTS[g[i]] or {}
            CONFLICTS[g[j]] = CONFLICTS[g[j]] or {}
            CONFLICTS[g[i]][g[j]], CONFLICTS[g[j]][g[i]] = true, true
        end
    end
end

-- The condition of `row` (or one of its requirements) `candidate` can't hold with; nil: fine
function St.Conflict(row, candidate)
    local function bad(c) return c ~= candidate and CONFLICTS[candidate] and CONFLICTS[candidate][c] end
    if bad(row.condition) then return row.condition end
    for _, c in ipairs(row.requirements or {}) do if bad(c) then return c end end
    return nil
end

---------------------------------------------------------------------------
-- Pushed by modules: states, events, values
---------------------------------------------------------------------------
function St.Set(key, on)
    on = on and true or false
    if flags[key] == on then return end
    flags[key] = on
    St.Refresh()
end

local timers = {}
-- An event happened: its condition holds for its duration (restarting)
function St.Fire(key)
    local c = conds[key]
    if not c then return end
    moments[key] = Now()
    St.Refresh()
    local d = c.duration or 3
    if C_Timer and C_Timer.After then
        local mark = moments[key]
        C_Timer.After(d + 0.01, function() if moments[key] == mark then St.Refresh() end end)
    end
end

-- A value source (0-1 or a count) for live channels (a cast's progress, the swing, combo points)
local sources = {}
function St.SetValue(key, v)
    if sources[key] == v then return end
    sources[key] = v
    for _, k in pairs(kinds) do if k.spec.live then k:Refresh() end end
end
function St.Value(key) return sources[key] end

local function Holds(key)
    local c = conds[key]
    if not c then return false end
    if c.kind == "moment" then
        local at = moments[key]
        return at ~= nil and Now() - at <= (c.duration or 3)
    end
    return flags[key] == true
end
St.Is = Holds

local function Percent(row)
    local v = values[row.condition]
    if v == nil then return false end   -- (unknown never counts)
    local cmp = COMPARE[row.operator or "<"] or COMPARE["<"]
    return cmp(v, tonumber(row.threshold) or 50)
end

-- A percentage requirement's own operator and threshold (L10): { operator, threshold }
function St.ReqParams(row, cond)
    local p = type(row.reqParams) == "table" and row.reqParams[cond]
    if type(p) ~= "table" then
        p = { operator = row.reqOperator or "<", threshold = row.reqThreshold or 50 }
    end
    return p
end
function St.SetReqParams(row, cond, operator, threshold)
    row.reqParams = type(row.reqParams) == "table" and row.reqParams or {}
    row.reqParams[cond] = { operator = operator, threshold = threshold }
end

-- A reaction matches: its condition (with its percentage) and all its requirements
function St.Matches(row)
    if conds[row.condition] and conds[row.condition].value then
        if not Percent(row) then return false end
    elseif not Holds(row.condition) then
        return false
    end
    for _, r in ipairs(row.requirements or {}) do
        if conds[r] and conds[r].value then
            local p = St.ReqParams(row, r)
            if not Percent({ condition = r, operator = p.operator, threshold = p.threshold }) then return false end
        elseif not Holds(r) then
            return false
        end
    end
    return true
end

-- The conditions some kind's reactions use (L13: read only these)
local function Needed()
    local need = {}
    for _, k in pairs(kinds) do
        local store = k.spec.store()
        for _, r in ipairs(type(store.rows) == "table" and store.rows or k.spec.recommended) do
            need[r.condition] = true
            for _, q in ipairs(r.requirements or {}) do need[q] = true end
        end
    end
    return need
end

-- Read the conditions with a test or a value (on their events, at login): those in use, or all
local function ReadAll(all)
    local need = not all and Needed() or nil
    for _, c in ipairs(condList) do
        if not need or need[c.key] then
            -- (one condition failing never stops the others, nor the refresh after)
            if c.test then
                local ok, v = pcall(c.test)
                flags[c.key] = (ok and not secret(v) and v) and true or false
            end
            if c.value then
                local ok, v = pcall(c.value)
                values[c.key] = ok and type(v) == "number" and not secret(v) and v or nil
            end
        end
    end
end
St.ReadAll = ReadAll

---------------------------------------------------------------------------
-- Kinds
---------------------------------------------------------------------------
local Kind = {}
Kind.__index = Kind

-- spec = {
--   channels = { "bar", "mic", "dots" },
--   recommended = { { id =, condition =, requirements =, on =, ...channel values... }, ... },  -- top first
--   store = fn() -> table          -- the kind's Feel-profile table: .rows, .nextID, .timing
--   value = fn(row, channel) -> v  -- nil: passes to the next match
--   base = fn(channel) -> v        -- Otherwise
--   apply = fn(result)             -- result[ch] = { value =, row = row | nil (Otherwise) }, result.timing
--   same = fn(a, b) -> bool        -- (optional) two values are the same
--   live = true                    -- (optional) re-resolve when a value source moves (gauges)
--   timing = { fadeIn =, fadeOut =, wait = }   -- (optional) Recommended timing
--   prepare = fn()                 -- (optional) before the first rows: migrate an older saved form
--   hush = "base" | "rows"         -- (optional) while Hush holds: every channel Otherwise (default),
--                                     or the rows as usual (a kind that is itself the mixer: Feel)
-- }
function St.Kind(name, spec)
    local k = setmetatable({ name = name, spec = spec, last = nil, held = {} }, Kind)
    kinds[name] = k
    return k
end
function St.Get(name) return kinds[name] end

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for a, b in pairs(v) do t[a] = Copy(b) end
    return t
end
St.Copy = Copy
-- The Recommended rows' version: a row shipped later carries since = the JOIN it came with
St.JOIN = 1

-- A value in words, the same for equal tables (keys sorted): has it changed since?
local function Sig(v)
    if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. Sig(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end
St.Sig = Sig

-- The reactions, top first (the Recommended ones until the player changes them)
function Kind:Rows()
    local store = self.spec.store()
    -- (checked already: the same list, nothing shipped since: L2-8)
    if self.checked == store.rows and store.rows ~= nil and self.checkedStore == store then return store.rows end
    -- (a kind's older saved form first: prepare migrates it into rows)
    if type(store.rows) ~= "table" and self.spec.prepare then self.spec.prepare() end
    if type(store.rows) ~= "table" then
        store.rows = Copy(self.spec.recommended)
        store.joinV = St.JOIN
    end
    -- (a Recommended reaction shipped later: at its place, unless the player removed it. One
    -- shipped later says so (since = the St.JOIN it came with); a list saved before stamps
    -- (0.49, 0.50: removals not written) lacks the others because the player removed them: L2-7)
    local have = {}
    for _, r in ipairs(store.rows) do have[r.id] = true end
    local removed = type(store.removed) == "table" and store.removed or {}
    local joined = tonumber(store.joinV) or 0
    for i, rec in ipairs(self.spec.recommended) do
        if not have[rec.id] and not removed[rec.id] and (rec.since or 0) <= joined and joined < St.JOIN then
            removed[rec.id] = true
            store.removed = removed
        elseif not have[rec.id] and not removed[rec.id] then
            local at = 1
            for j = i - 1, 1, -1 do
                local above = self.spec.recommended[j].id
                for p, r in ipairs(store.rows) do if r.id == above then at = p + 1 end end
                if at > 1 then break end
            end
            table.insert(store.rows, at, Copy(rec))
            have[rec.id] = true
        end
    end
    store.joinV = St.JOIN
    self.checked, self.checkedStore = store.rows, store
    return store.rows
end

function Kind:Row(id)
    for i, r in ipairs(self:Rows()) do if r.id == id then return r, i end end
end

function Kind:Recommended(id)
    for _, r in ipairs(self.spec.recommended) do if r.id == id then return r end end
end

function Kind:Timing()
    local store = self.spec.store()
    if self.timing and self.timingStore == store and self.timingOf == store.timing then return self.timing end
    local rec = self.spec.timing or {}
    store.timing = type(store.timing) == "table" and store.timing or {}
    local t = store.timing
    self.timing = { fadeIn = tonumber(t.fadeIn) or rec.fadeIn or 0.2, fadeOut = tonumber(t.fadeOut) or rec.fadeOut or 0.2,
        wait = tonumber(t.wait) or rec.wait or 0 }
    self.timingStore, self.timingOf = store, store.timing
    return self.timing
end

function Kind:SetTiming(field, v)
    self:Timing()
    self.spec.store().timing[field] = v
    self.timing = nil
    self:Refresh(true)
end

local function Changed(k) k:Refresh(true) end

-- + Add: a new reaction for a condition, at the top (it matters most when you just added it)
function Kind:Add(condition, at, fields)
    local store, rows = self.spec.store(), self:Rows()
    store.nextID = (tonumber(store.nextID) or 1)
    local row = { id = "r" .. store.nextID, condition = condition, on = true }
    for f, v in pairs(fields or {}) do row[f] = v end
    store.nextID = store.nextID + 1
    if St.IsPercentage(condition) then row.operator, row.threshold = "<", 35 end
    table.insert(rows, at or 1, row)
    ReadAll()   -- (a condition nobody read before)
    Changed(self)
    return row
end

function Kind:Remove(id)
    local _, i = self:Row(id)
    if not i then return end
    table.remove(self:Rows(), i)
    -- (a Recommended one stays removed: not brought back as new)
    if self:Recommended(id) then
        local store = self.spec.store()
        store.removed = type(store.removed) == "table" and store.removed or {}
        store.removed[id] = true
    end
    Changed(self)
end

function Kind:Move(id, delta)
    local rows = self:Rows()
    local _, i = self:Row(id)
    local j = i and i + delta
    if not i or j < 1 or j > #rows then return false end
    rows[i], rows[j] = rows[j], rows[i]
    Changed(self)
    return true
end

-- Drag: to place n
function Kind:MoveTo(id, n)
    local rows = self:Rows()
    local row, i = self:Row(id)
    if not i then return false end
    n = max(1, min(#rows, n))
    if n == i then return false end
    table.remove(rows, i)
    table.insert(rows, n, row)
    Changed(self)
    return true
end

-- A drag's drop: the cursor dy px under the list's first row, rows step px apart, `shown`
-- on screen from `offset` (scrolled), `count` in all -> the slot on screen (1..shown) and the
-- place it lands (MoveTo's n)
function St.DropSlot(dy, step, shown, offset, count)
    shown = max(1, min(shown, count - offset))
    local slot = max(1, min(shown, floor(dy / step) + 1))
    return slot, max(1, min(count, offset + slot))
end

function Kind:SetOn(id, on)
    local row = self:Row(id)
    if row then row.on = on and true or false; Changed(self) end
end

-- A requirement (all must be true): nil, or the condition it can't hold with
function Kind:AddRequirement(id, condition)
    local row = self:Row(id)
    if not row or condition == row.condition then return false end
    local bad = St.Conflict(row, condition)
    if bad then return false, bad end
    row.requirements = row.requirements or {}
    for _, r in ipairs(row.requirements) do if r == condition then return false end end
    row.requirements[#row.requirements + 1] = condition
    ReadAll()
    Changed(self)
    return true
end

function Kind:RemoveRequirement(id, condition)
    local row = self:Row(id)
    for i, r in ipairs(row and row.requirements or {}) do
        if r == condition then
            table.remove(row.requirements, i)
            if #row.requirements == 0 then row.requirements = nil end
            Changed(self)
            return true
        end
    end
    return false
end

-- A reaction's words: "Movement + In combat", "Health percentage < 35%"
function St.Words(row)
    local function one(c, op, th)
        if St.IsPercentage(c) then return St.Label(c) .. " " .. (op or "<") .. " " .. floor(tonumber(th) or 50) .. "%" end
        return St.Label(c)
    end
    local parts = { one(row.condition, row.operator, row.threshold) }
    for _, r in ipairs(row.requirements or {}) do
        local p = St.ReqParams(row, r)
        parts[#parts + 1] = one(r, p.operator, p.threshold)
    end
    return table.concat(parts, " + ")
end

-- The kind's saved reactions, timing and removals as they are now / put back (Undo)
function Kind:Snapshot()
    local store = self.spec.store()
    return { rows = Copy(store.rows), timing = Copy(store.timing), removed = Copy(store.removed), nextID = store.nextID }
end
function Kind:Restore(snap)
    local store = self.spec.store()
    store.rows, store.timing, store.removed, store.nextID = Copy(snap.rows), Copy(snap.timing), Copy(snap.removed), snap.nextID
    self.timing, self.checked = nil, nil
    Changed(self)
end

-- Everything back as shipped (or one Recommended reaction)
function Kind:Default(id)
    if id then
        local rec, row = self:Recommended(id), self:Row(id)
        if rec and row then
            for k2 in pairs(row) do row[k2] = nil end
            for k2, v in pairs(Copy(rec)) do row[k2] = v end
        end
    else
        local store = self.spec.store()
        store.rows, store.timing, store.removed = nil, nil, nil
        self.timing, self.checked = nil, nil
    end
    Changed(self)
end

local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k2, v in pairs(a) do if not Equal(v, b[k2]) then return false end end
    for k2 in pairs(b) do if a[k2] == nil then return false end end
    return true
end
St.Equal = Equal

function Kind:IsDefault(id)
    if id then
        local rec, row = self:Recommended(id), self:Row(id)
        return rec ~= nil and row ~= nil and Equal(rec, row)
    end
    return Equal(self:Rows(), self.spec.recommended) and next(self.spec.store().timing or {}) == nil
end

-- For each channel: the first matching reaction that sets it; else Otherwise. A reaction that
-- stops matching keeps its channels for Wait before fade-out (then re-resolved by a timer).
function Kind:Resolve()
    local spec, result = self.spec, {}
    local rows, timing, now = self:Rows(), self:Timing(), Now()
    local matched = {}
    self.ended = self.ended or {}
    self.waitUntil = nil
    local hushed = spec.hush ~= "rows" and Holds("hush")
    for _, r in ipairs(rows) do
        if r.on ~= false and St.Matches(r) then
            matched[r.id], self.held[r.id], self.ended[r.id] = true, true, nil
        elseif self.held[r.id] then
            -- (the true -> false edge: Wait counts from here: L6; also while hushed: L2-2)
            self.held[r.id] = nil
            self.ended[r.id] = now
        end
    end
    -- Hush: every channel Otherwise (lights at rest, triggers free), unless the kind mixes it;
    -- no Wait timer while it holds (L2-1)
    if hushed then
        for _, ch in ipairs(spec.channels) do result[ch] = { value = spec.base(ch), row = nil } end
        result.timing, result.hushed = timing, true
        return result
    end
    for _, ch in ipairs(spec.channels) do
        for _, r in ipairs(rows) do
            local ended = self.ended[r.id]
            local waiting = r.on ~= false and ended and timing.wait > 0 and now - ended < timing.wait
            if waiting then
                local til = ended + timing.wait
                if not self.waitUntil or til < self.waitUntil then self.waitUntil = til end
            end
            local live = r.on ~= false and (matched[r.id] or waiting)
            if live then
                local v = spec.value(r, ch)
                if v ~= nil then
                    result[ch] = { value = v, row = r }
                    break
                end
            end
        end
        if not result[ch] then result[ch] = { value = spec.base(ch), row = nil } end
    end
    result.timing = timing
    return result
end

-- The reaction now driving a channel (FrameGambit's teal row): a set of row ids
function Kind:Driving()
    local r, set = self:Now(), {}
    for _, ch in ipairs(self.spec.channels) do
        if r[ch].row then set[r[ch].row.id] = set[r[ch].row.id] or {}; table.insert(set[r[ch].row.id], ch) end
    end
    return set
end

local function Same(spec, a, b)
    if not (a and b) then return a == b end
    for _, ch in ipairs(spec.channels) do
        local x, y = a[ch], b[ch]
        if x.row ~= y.row or a.hushed ~= b.hushed then return false end
        if spec.same then
            if not spec.same(x.value, y.value) then return false end
        elseif not Equal(x.value, y.value) then
            return false
        end
    end
    return true
end

function Kind:Refresh(force)
    local r = self:Resolve()
    local changed = force or not Same(self.spec, r, self.last)
    self.last = r
    if changed and self.spec.apply then self.spec.apply(r) end
    -- a reaction held by Wait: look again when it runs out (only while one is waiting)
    if self.waitUntil and C_Timer and C_Timer.After and not self.waiting then
        self.waiting = true
        C_Timer.After(math.max(0.01, self.waitUntil - Now()) + 0.02, function() self.waiting = false; self:Refresh() end)
    end
    return r
end

function Kind:Now() return self.last or self:Resolve() end

function St.Refresh(force)
    for _, k in pairs(kinds) do k:Refresh(force) end
end

---------------------------------------------------------------------------
-- The events: read the conditions, then every kind again (never every frame)
---------------------------------------------------------------------------
local frame = CreateFrame and CreateFrame("Frame")
if frame then
    local momentOf, seen = {}, {}
    local function Listen(ev)
        if seen[ev] then return end
        seen[ev] = true
        if C_EventUtils and C_EventUtils.IsEventValid and not call(C_EventUtils.IsEventValid, ev) then return end
        pcall(frame.RegisterEvent, frame, ev)
    end
    for _, c in ipairs(condList) do
        for _, ev in ipairs(c.events or {}) do
            Listen(ev)
            if c.kind == "moment" then momentOf[ev] = momentOf[ev] or {}; table.insert(momentOf[ev], c.key) end
        end
    end
    Listen("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, unit)
        if (event == "UNIT_AURA" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE"
            or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_FACTION")
            and unit and unit ~= "player" and unit ~= "target" then return end
        if event == "PLAYER_STARTED_MOVING" then movingByEvent = true
        elseif event == "PLAYER_STOPPED_MOVING" then movingByEvent = false end
        for _, key in ipairs(momentOf[event] or {}) do moments[key] = Now() end
        ReadAll()
        St.Refresh()
        if momentOf[event] and C_Timer and C_Timer.After then
            for _, key in ipairs(momentOf[event]) do
                local mark = moments[key]
                C_Timer.After((conds[key].duration or 3) + 0.01, function() if moments[key] == mark then St.Refresh() end end)
            end
        end
    end)
end
St.frame = frame
