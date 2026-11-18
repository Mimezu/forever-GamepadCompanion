-- Stack: one state stack for every kind of output (lights now, triggers next).
--
--   Events (one-shots: crits, spells, whispers)   <- on top, brief, each kind's own
--   States, in the player's order (highest true wins, per channel):
--     Dead or ghost · Low health · Casting · Stealth · In combat · Swimming · Mounted · Moving · Resting …
--   Base                                           <- always true
--
-- A kind (lights, triggers) registers its channels (lights: bar, mic, dots; triggers: L2, R2) and
-- its states. Each state is a moment: on or off, and for each channel a value or nothing (it
-- passes: what is below shows through). The order lives in the Feel profile, with a Recommended
-- order. Conditions are the game's ("In combat", "Moving"…), read on their events, never every
-- frame; a module can push its own ("Low health", "Casting") with Stack.Set.
local _, ns = ...
local St = {}
ns.Stack = St

local floor = math.floor

---------------------------------------------------------------------------
-- Conditions: shared by every kind
---------------------------------------------------------------------------
local conds, condList = {}, {}
local flags = {}      -- condition key -> true while it holds
local pushed = {}     -- key -> true/false for conditions a module sets
local kinds = {}

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

-- A condition: key, label, test() -> bool (nil: pushed with Stack.Set), events that change it
function St.Condition(key, def)
    def.key = key
    if not conds[key] then condList[#condList + 1] = def end
    conds[key] = def
    return def
end

function St.Conditions() return condList end
function St.Label(key) return conds[key] and conds[key].label or key end

-- A module's own condition (Low health, Casting): set it, every kind re-resolves
function St.Set(key, on)
    on = on and true or false
    if pushed[key] == on then return end
    pushed[key] = on
    flags[key] = on
    St.Refresh()
end

function St.Is(key) return flags[key] == true end

local function Moving()
    local speed = call(GetUnitSpeed, "player")
    return (tonumber(speed) or 0) > 0
end
local function Mounted() return call(IsMounted) == true end

St.Condition("dead", { label = "Dead or ghost", test = function() return call(UnitIsDeadOrGhost, "player") == true end,
    events = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" } })
St.Condition("afk", { label = "Away", test = function() return call(UnitIsAFK, "player") == true end,
    events = { "PLAYER_FLAGS_CHANGED" } })
St.Condition("stealth", { label = "Stealth", test = function() return call(IsStealthed) == true end,
    events = { "UPDATE_STEALTH" } })
St.Condition("combat", { label = "In combat", test = function() return call(UnitAffectingCombat, "player") == true end,
    events = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" } })
St.Condition("swimming", { label = "Swimming", test = function() return call(IsSwimming) == true end,
    events = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "MIRROR_TIMER_START", "MIRROR_TIMER_STOP" } })
St.Condition("mounted", { label = "Mounted", test = Mounted,
    events = { "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_AURA", "PLAYER_STARTED_MOVING" } })
St.Condition("moving", { label = "Moving", test = Moving, events = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" } })
St.Condition("rested", { label = "Resting", test = function() return call(IsResting) == true end,
    events = { "PLAYER_UPDATE_RESTING" } })
-- (pushed by their modules)
St.Condition("lowHp", { label = "Low health" })
St.Condition("cast", { label = "Casting" })
St.Condition("halo", { label = "Halo ring open" })

-- Read every condition with a test (on the events, and at login)
local function ReadAll()
    for _, c in ipairs(condList) do
        if c.test then flags[c.key] = c.test() and true or false end
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
--   layers = { { key = "combat", when = "combat" }, ... },   -- every state this kind has
--   recommended = { "dead", "lowHp", ... },                    -- the order, top first
--   store = fn() -> table                                       -- where the order is saved (Feel profile)
--   enabled = fn(key) -> bool                                   -- the state is on
--   value = fn(key, channel) -> value or nil                    -- nil: passes
--   base = fn(channel) -> value
--   apply = fn(result)        -- result[channel] = { value =, layer = key or "base" }; on a change
--   same = fn(a, b) -> bool   -- (optional) two values are the same
-- }
function St.Kind(name, spec)
    local k = setmetatable({ name = name, spec = spec, last = nil }, Kind)
    k.byKey = {}
    for _, l in ipairs(spec.layers) do k.byKey[l.key] = l end
    kinds[name] = k
    return k
end

function St.Get(name) return kinds[name] end

-- The order, top first: the saved one (states it doesn't know dropped), then any new state at its
-- Recommended place
function Kind:Order()
    local store = self.spec.store()
    local saved = type(store.order) == "table" and store.order or nil
    if not saved then
        local list = {}
        for _, key in ipairs(self.spec.recommended) do if self.byKey[key] then list[#list + 1] = key end end
        return list
    end
    local list, seen = {}, {}
    for _, key in ipairs(saved) do
        if self.byKey[key] and not seen[key] then list[#list + 1] = key; seen[key] = true end
    end
    -- (a state added later: after the Recommended neighbour above it)
    for i, key in ipairs(self.spec.recommended) do
        if self.byKey[key] and not seen[key] then
            local at = 1
            for j = i - 1, 1, -1 do
                local above = self.spec.recommended[j]
                for p, have in ipairs(list) do if have == above then at = p + 1 end end
                if at > 1 then break end
            end
            table.insert(list, at, key)
            seen[key] = true
        end
    end
    return list
end

function Kind:IsDefaultOrder()
    local cur, rec = self:Order(), {}
    for _, key in ipairs(self.spec.recommended) do if self.byKey[key] then rec[#rec + 1] = key end end
    if #cur ~= #rec then return false end
    for i = 1, #cur do if cur[i] ~= rec[i] then return false end end
    return true
end

function Kind:SetOrder(list)
    self.spec.store().order = list
    self:Refresh(true)
end

-- Up (-1) or down (+1) one place
function Kind:Move(key, delta)
    local list = self:Order()
    for i, have in ipairs(list) do
        if have == key then
            local j = i + delta
            if j < 1 or j > #list then return false end
            list[i], list[j] = list[j], list[i]
            self:SetOrder(list)
            return true
        end
    end
    return false
end

function Kind:DefaultOrder()
    self.spec.store().order = nil
    self:Refresh(true)
end

-- The state's condition holds now
function Kind:Active(key)
    local l = self.byKey[key]
    return l ~= nil and flags[l.when or key] == true
end

-- For each channel: the highest state that is on, true and sets it; else the base
function Kind:Resolve()
    local spec, result = self.spec, {}
    local order = self:Order()
    for _, ch in ipairs(spec.channels) do
        for _, key in ipairs(order) do
            if spec.enabled(key) and self:Active(key) then
                local v = spec.value(key, ch)
                if v ~= nil then
                    result[ch] = { value = v, layer = key }
                    break
                end
            end
        end
        if not result[ch] then result[ch] = { value = spec.base(ch), layer = "base" } end
    end
    return result
end

local function Same(spec, a, b)
    if not (a and b) then return a == b end
    for _, ch in ipairs(spec.channels) do
        local x, y = a[ch], b[ch]
        if x.layer ~= y.layer then return false end
        if spec.same then
            if not spec.same(x.value, y.value) then return false end
        elseif x.value ~= y.value then
            return false
        end
    end
    return true
end

-- Re-resolve; apply when something changed (force: always, a setting changed)
function Kind:Refresh(force)
    local r = self:Resolve()
    if force or not Same(self.spec, r, self.last) then
        self.last = r
        if self.spec.apply then self.spec.apply(r) end
    end
    return r
end

-- What wins each channel now (for the page: "Now: Moving")
function Kind:Now()
    return self.last or self:Resolve()
end

function St.Refresh(force)
    for _, k in pairs(kinds) do k:Refresh(force) end
end

---------------------------------------------------------------------------
-- The events: read the conditions, re-resolve every kind
---------------------------------------------------------------------------
local frame = CreateFrame and CreateFrame("Frame")
if frame then
    local seen = {}
    for _, c in ipairs(condList) do
        for _, ev in ipairs(c.events or {}) do
            if not seen[ev] then
                seen[ev] = true
                if ev == "UNIT_AURA" then
                    if not pcall(frame.RegisterUnitEvent, frame, ev, "player") then pcall(frame.RegisterEvent, frame, ev) end
                else
                    pcall(frame.RegisterEvent, frame, ev)
                end
            end
        end
    end
    pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and unit and unit ~= "player" then return end
        ReadAll()
        St.Refresh()
    end)
end
St.frame = frame
