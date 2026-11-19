-- Profiles (docs/UX.md §10): each character uses a Controls profile and a
-- Feel profile, kept account-wide by name; Recommended ships. The live
-- places the code reads ARE the profile's tables: at ADDON_LOADED (this file
-- is first in the TOC, so before every module) they are pointed at the
-- character's profiles; at logout (a frame registered at PLAYER_LOGIN, after
-- every module's own logout work) they are set back to nil, so only the
-- profiles are saved. Only what this session pointed is ever cleared.
-- Switching a profile saves the choice and reloads.
local ADDON, ns = ...
local P = {}
ns.Profiles = P

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end
P.Copy = Copy

---------------------------------------------------------------------------
-- What a Feel profile holds (GamepadCompanionHapticsDB), and what the
-- Controls profile's bars leave account-wide
---------------------------------------------------------------------------
P.FEEL_TABLES = { "events", "lightEvents", "lightBase", "lightStack", "triggerStack", "feelStack", "spells", "when" }
P.FEEL_VALUES = { "light", "lightGameOnly", "landMin", "landMax", "landLong", "stepNudge", "triggers", "kick", "minPulse" }
P.FEEL_NESTED = { { "link", "cues", "cues" }, { "link", "sounds", "sounds" }, { "link", "trigRules", "triggerRules" }, { "volume", "feel", "volumeFeel" },
    { "volume", "sound", "volumeSound" } }
P.LEARNED = { "hitTiming", "strikes" }   -- inside vibration, but physical: account-wide
P.UI_KEYS = { "optionsStyle", "optionsStyleVersion", "minimap" }

---------------------------------------------------------------------------
-- Recommended: a few changes over the code's own defaults (the calm set
-- tuned on Alberich), and a class's touches
---------------------------------------------------------------------------
P.RECOMMENDED = {
    events = { hit = false, miss = false, targetDodge = false, targetParry = false, targetBlock = false, dodge = false,
        parry = false, missedYou = false, hitTaken = false, aggro = false, targetCast = false, gcd = false,
        combo = false, full = false, tension = false, heartbeat = false, rested = false, riding = false, oom = false },
    -- Full feels: a plain rumble under WoW Helper's HD plays at this much (a felt tap if it crashed)
    plainUnderHD = 0.3,
}
P.CLASS = {
    ROGUE = { events = { combo = true, comboFull = true } },
    DRUID = { events = { combo = true, comboFull = true } },
    HUNTER = { vibration = { shot = true } },
}

-- A Feel profile as shipped for a class
function P.Recommended(class)
    local feel = { events = {}, cues = {}, vibration = { events = {} } }
    local function Apply(r)
        for key, on in pairs(r.events or {}) do feel.events[key] = { on = on } end
        for key, v in pairs(r.cues or {}) do feel.cues[key] = v end
        for key, on in pairs(r.vibration or {}) do feel.vibration.events[key] = { on = on } end
    end
    Apply(P.RECOMMENDED)
    if class and P.CLASS[class] then Apply(P.CLASS[class]) end
    return feel
end

-- One meaning of Default: a row's Default and the profile's Reset both go to Recommended.
-- A moment's Recommended on/off for this character's class, or nil where Recommended keeps
-- the code's own. part: "events" (the engine's moments) or "vibration" (Rumble's)
function P.RecommendedOn(part, key)
    local function Of(r)
        local t = r and r[part]
        if type(t) ~= "table" then return nil end
        return t[key]
    end
    local class = P.state and P.state.class
    local v = Of(class and P.CLASS[class])
    if v == nil then v = Of(P.RECOMMENDED) end
    return v
end

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------
local function HDB()
    if type(GamepadCompanionHapticsDB) ~= "table" then GamepadCompanionHapticsDB = {} end
    return GamepadCompanionHapticsDB
end

function P.DB()
    local h = HDB()
    if type(h.profiles) ~= "table" then h.profiles = {} end
    local p = h.profiles
    for _, k in ipairs({ "controls", "feel", "use", "startControls", "startFeel", "beforeChar" }) do
        if type(p[k]) ~= "table" then p[k] = {} end
    end
    return p
end

local state = { pointed = false }
P.state = state

-- The account Feel parts as they are now (for the snapshot)
local function TakeFeel(h)
    local feel = {}
    for _, k in ipairs(P.FEEL_TABLES) do feel[k] = Copy(h[k]) end
    for _, k in ipairs(P.FEEL_VALUES) do feel[k] = h[k] end
    for _, n in ipairs(P.FEEL_NESTED) do
        local parent = h[n[1]]
        feel[n[3]] = type(parent) == "table" and Copy(parent[n[2]]) or nil
    end
    return feel
end

local function TakeBars(db)
    local bars = Copy(type(db) == "table" and db or nil)
    if bars then for _, k in ipairs(P.UI_KEYS) do bars[k] = nil end end
    return bars
end

-- A free profile name
local function Free(kind, name)
    local list = P.DB()[kind]
    if not list[name] then return name end
    local n = 2
    while list[name .. " " .. n] do n = n + 1 end
    return name .. " " .. n
end
P.Free = Free

---------------------------------------------------------------------------
-- Load: migrate once, give the character its profiles, point the live places
---------------------------------------------------------------------------
function P.Load(name, realm, class)
    if not (type(name) == "string" and name ~= "" and type(realm) == "string") then
        state.note = "Profiles: off this session (no character name yet)"
        return false
    end
    local h, p = HDB(), P.DB()
    local key = name .. "-" .. realm
    state.key, state.name, state.class = key, name, class
    -- (once: the account parts frozen as they were, the backup)
    if not p.version then
        p.before = { feel = TakeFeel(h), bars = TakeBars(GamepadCompanionDB) }
        p.version = 1
    end
    if type(h.learned) ~= "table" then h.learned = {} end
    if type(h.ui) ~= "table" then
        h.ui = {}
        if type(GamepadCompanionDB) == "table" then for _, k in ipairs(P.UI_KEYS) do h.ui[k] = GamepadCompanionDB[k] end end
    end
    local use = p.use[key]
    if type(use) ~= "table" or not (p.controls[use.controls] and p.feel[use.feel]) then
        use = type(use) == "table" and use or {}
        local char = GamepadCompanionCharDB
        local existing = type(char) == "table" and not char.profiled
        if existing then
            -- an existing character: its own tables and the account parts as they were
            p.beforeChar[key] = p.beforeChar[key] or Copy(char)
            local vibration = char.vibration
            char.vibration = nil
            local feel = Copy(p.before.feel) or {}
            feel.vibration = type(vibration) == "table" and vibration or {}
            -- (learned timings join the account's, the first one known kept)
            for _, k in ipairs(P.LEARNED) do
                local mine = feel.vibration[k]
                if type(mine) == "table" then
                    if type(h.learned[k]) ~= "table" then h.learned[k] = {} end
                    for kk, v in pairs(mine) do if h.learned[k][kk] == nil then h.learned[k][kk] = v end end
                end
                feel.vibration[k] = nil
            end
            if not p.controls[use.controls] then
                use.controls = Free("controls", name)
                p.controls[use.controls] = { char = char, bars = Copy(p.before.bars) }
            end
            if not p.feel[use.feel] then
                use.feel = Free("feel", name)
                p.feel[use.feel] = feel
            end
            state.note = "Profile: " .. use.feel
        else
            -- a new character: its class's start, else Recommended (Feel) and fresh (Controls)
            if not p.controls[use.controls] then
                local start = class and p.startControls[class]
                local from = start and p.controls[start]
                use.controls = Free("controls", name)
                p.controls[use.controls] = from and Copy(from) or { char = { version = 1 }, bars = Copy(p.before.bars) }
                if from then state.note = "Controls: " .. use.controls .. " · from " .. start end
            end
            if not p.feel[use.feel] then
                local start = class and p.startFeel[class]
                local from = start and p.feel[start]
                use.feel = Free("feel", name)
                p.feel[use.feel] = from and Copy(from) or P.Recommended(class)
                state.note = "Feel: " .. use.feel .. " · from " .. (from and start or "Recommended")
            end
        end
        p.use[key] = use
    end
    P.Point(use)
    return true
end

-- The live places become the profiles' tables
function P.Point(use)
    local h, p = HDB(), P.DB()
    local controls, feel = p.controls[use.controls], p.feel[use.feel]
    if type(controls.char) ~= "table" then controls.char = { version = 1 } end
    if type(feel.vibration) ~= "table" then feel.vibration = {} end
    controls.char.profiled = nil
    GamepadCompanionCharDB = controls.char
    controls.char.vibration = feel.vibration
    for _, k in ipairs(P.LEARNED) do
        if type(h.learned[k]) ~= "table" then h.learned[k] = {} end
        feel.vibration[k] = h.learned[k]
    end
    local bars = Copy(controls.bars) or {}
    for _, k in ipairs(P.UI_KEYS) do bars[k] = h.ui[k] end
    GamepadCompanionDB = next(bars) and bars or nil
    for _, k in ipairs(P.FEEL_TABLES) do
        if type(feel[k]) ~= "table" then feel[k] = {} end
        h[k] = feel[k]
    end
    for _, k in ipairs(P.FEEL_VALUES) do h[k] = feel[k] end
    for _, n in ipairs(P.FEEL_NESTED) do
        if type(h[n[1]]) ~= "table" then h[n[1]] = {} end
        if type(feel[n[3]]) ~= "table" then feel[n[3]] = {} end
        h[n[1]][n[2]] = feel[n[3]]
    end
    h.liveOwner = state.key
    state.use, state.controls, state.feel = use, controls, feel
    state.pointed = true
end

-- Logout: the profiles keep what changed; the live places let go
function P.Release()
    if not state.pointed then return end
    local h = HDB()
    local controls, feel = state.controls, state.feel
    -- (a module may have replaced a table: keep the live one)
    if type(GamepadCompanionCharDB) == "table" then controls.char = GamepadCompanionCharDB end
    local vibration = type(controls.char.vibration) == "table" and controls.char.vibration or feel.vibration
    feel.vibration = vibration
    controls.char.vibration = nil
    for _, k in ipairs(P.LEARNED) do
        if type(vibration[k]) == "table" then h.learned[k] = vibration[k] end
        vibration[k] = nil
    end
    GamepadCompanionCharDB = { profiled = 1 }
    if type(GamepadCompanionDB) == "table" then
        for _, k in ipairs(P.UI_KEYS) do h.ui[k] = GamepadCompanionDB[k] end
        controls.bars = TakeBars(GamepadCompanionDB)
    end
    GamepadCompanionDB = nil
    for _, k in ipairs(P.FEEL_TABLES) do
        if type(h[k]) == "table" then feel[k] = h[k] end
        h[k] = nil
    end
    for _, k in ipairs(P.FEEL_VALUES) do feel[k] = h[k]; h[k] = nil end
    for _, n in ipairs(P.FEEL_NESTED) do
        local parent = h[n[1]]
        if type(parent) == "table" then
            if type(parent[n[2]]) == "table" then feel[n[3]] = parent[n[2]] end
            parent[n[2]] = nil
        end
    end
    h.liveOwner = nil
    state.pointed = false
end

---------------------------------------------------------------------------
-- The menu's actions (each change of the profile in use reloads)
---------------------------------------------------------------------------
function P.Current(kind) return state.use and state.use[kind] end
function P.Names(kind)
    local list = {}
    for name in pairs(P.DB()[kind]) do list[#list + 1] = name end
    table.sort(list)
    return list
end

-- Used by any character
function P.InUse(kind, name)
    for _, use in pairs(P.DB().use) do if use[kind] == name then return true end end
    return false
end

local function Reload()
    if P.reload then return P.reload() end
    if ReloadUI then ReloadUI() end
end

local function Busy() return InCombatLockdown and InCombatLockdown() end

function P.Use(kind, name)
    if not (state.use and P.DB()[kind][name]) or Busy() then return false end
    state.use[kind] = name
    Reload()
    return true
end

-- New: Recommended (Feel) or fresh (Controls), or a copy of a profile
function P.New(kind, name, from)
    local p = P.DB()
    name = Free(kind, name)
    if from then
        if from == P.Current(kind) then P.Release(); P.Point(state.use or {}) end
        p[kind][name] = Copy(p[kind][from])
    elseif kind == "feel" then
        p[kind][name] = P.Recommended(state.class)
    else
        p[kind][name] = { char = { version = 1 }, bars = Copy(p.before and p.before.bars) }
    end
    return name
end

function P.Rename(kind, old, new)
    local p = P.DB()
    if not p[kind][old] or type(new) ~= "string" or new == "" or p[kind][new] then return false end
    p[kind][new], p[kind][old] = p[kind][old], nil
    for _, use in pairs(p.use) do if use[kind] == old then use[kind] = new end end
    for _, start in ipairs({ kind == "feel" and p.startFeel or p.startControls }) do
        for class, n in pairs(start) do if n == old then start[class] = new end end
    end
    return true
end

function P.Delete(kind, name)
    local p = P.DB()
    if not p[kind][name] or P.InUse(kind, name) then return false end
    p[kind][name] = nil
    local start = kind == "feel" and p.startFeel or p.startControls
    for class, n in pairs(start) do if n == name then start[class] = nil end end
    return true
end

-- Reset the one in use: Recommended (Feel), fresh (Controls)
function P.Reset(kind)
    local name = P.Current(kind)
    if not name or Busy() then return false end
    local p = P.DB()
    state.pointed = false   -- (its live tables are dropped, not saved back)
    if kind == "feel" then p.feel[name] = P.Recommended(state.class)
    else p.controls[name] = { char = { version = 1 }, bars = Copy(p.before and p.before.bars) } end
    Reload()
    return true
end

-- New characters of this class start from it
function P.StartHere(kind, on)
    local p = P.DB()
    local start = kind == "feel" and p.startFeel or p.startControls
    if not state.class then return end
    start[state.class] = on and P.Current(kind) or nil
end
function P.IsStart(kind)
    local p = P.DB()
    local start = kind == "feel" and p.startFeel or p.startControls
    return state.class ~= nil and start[state.class] == P.Current(kind)
end

-- Back to the account as it was before profiles (the Feel and bars in use)
function P.Restore()
    local p = P.DB()
    if not (p.before and state.use) or Busy() then return false end
    state.pointed = false
    local feel = Copy(p.before.feel) or {}
    local old = p.feel[state.use.feel]
    feel.vibration = old and old.vibration or {}
    p.feel[state.use.feel] = feel
    p.controls[state.use.controls].bars = Copy(p.before.bars)
    Reload()
    return true
end

---------------------------------------------------------------------------
-- Share: a profile as a line of text, and back
---------------------------------------------------------------------------
local function Serialize(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t ~= "table" then return "nil" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        local ks = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
        parts[#parts + 1] = ks .. "=" .. Serialize(v[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function P.Export(kind, name)
    local p = P.DB()
    local t = Copy(p[kind][name])
    if not t then return nil end
    if t.vibration then for _, k in ipairs(P.LEARNED) do t.vibration[k] = nil end end
    if t.char then t.char.vibration = nil end
    -- your own feels it uses go with it
    if kind == "feel" and type(HDB().feels) == "table" then
        local mine = {}
        local text = Serialize(t)
        for key, f in pairs(HDB().feels) do if text:find(key, 1, true) then mine[key] = Copy(f) end end
        if next(mine) then t.feels = mine end
    end
    return "GPC1:" .. kind .. ":" .. Serialize(t)
end

-- A shared text -> a new profile (its name), or nil, why
function P.Import(text, name)
    if type(text) ~= "string" then return nil, "Not a profile" end
    local kind, body = text:match("^%s*GPC1:(%a+):(.+)$")
    if not (kind == "feel" or kind == "controls") then return nil, "Not a profile" end
    if body:find("function") or body:find("[%a_]+%s*%(") then return nil, "Not a profile" end
    local load = loadstring or load
    local fn = load and load("return " .. body)
    if not fn then return nil, "Not a profile" end
    if setfenv then setfenv(fn, {}) end
    local ok, t = pcall(fn)
    if not ok or type(t) ~= "table" then return nil, "Not a profile" end
    if t.feels then
        local feels = HDB().feels
        if type(feels) == "table" then for key, f in pairs(t.feels) do if feels[key] == nil then feels[key] = f end end end
        t.feels = nil
    end
    name = Free(kind, name or "Shared")
    P.DB()[kind][name] = t
    return name, kind
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        local name = UnitName and UnitName("player")
        local realm = GetRealmName and GetRealmName()
        local _, class = nil, nil
        if UnitClass then _, class = UnitClass("player") end
        local ok, err = pcall(P.Load, name, realm, class)
        if not ok then state.note = "Profiles: off this session"; state.error = err end
    elseif event == "PLAYER_LOGIN" and not state.logout then
        -- (registered now, so it runs after every module's own logout work)
        state.logout = CreateFrame("Frame")
        state.logout:RegisterEvent("PLAYER_LOGOUT")
        state.logout:SetScript("OnEvent", function() P.Release() end)
    end
end)
