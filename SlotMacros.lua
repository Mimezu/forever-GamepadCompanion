-- Bar slots run any action: a window, a Halo ring, Quick use, a typed macro
-- or a pet goes onto a slot as a character macro Companion makes for it
-- ("gpc:q:food"). Its body is the touchpad's (T.MacroText), kept current (Quick
-- use picks, login); the slot reads back as the action. A macro no slot holds
-- any more is deleted; macros Companion didn't make are never touched.
-- Out of combat only.
local _, ns = ...
local T, Sh = ns.TouchModel, ns.Shared
local M = {}
ns.SlotMacros = M

local DYNAMIC = 134400   -- the question mark: the game shows the macro's item

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- name -> action, for the macros Companion made (per character)
local function Made()
    local db = Sh.CharDB()
    if type(db.slotMacros) ~= "table" then db.slotMacros = {} end
    return db.slotMacros
end

function M.Owns(name) return type(name) == "string" and Made()[name] ~= nil end
function M.ActionFor(name) return type(name) == "string" and Made()[name] or nil end

local function Index(name)
    local index = Call(GetMacroIndexByName, name)
    return type(index) == "number" and index > 0 and index or nil
end

local function Body(action) return T.MacroText(action, Sh.lookup) or "" end

-- The macro's icon: an item macro's own (dynamic), else the action's
function M.Icon(action)
    local kind, value = action:match("^(%a+):(.+)$")
    local q = kind == "quick" and T.QUICK_BY_KEY[value]
    if q and not q.run then return DYNAMIC end
    local look = ns.Touch and ns.Touch.ActionLook
    if look then
        local _, icon, atlas = Call(look, action)
        if icon and not atlas then return icon end
    end
    local w = kind == "window" and T.WINDOW_BY_KEY[value]
    return (q and q.icon) or (w and w.icon) or DYNAMIC
end

-- The macro for an action, made or brought up to date: its name, or nil and
-- a few words why
function M.Ensure(action)
    if InCombat() then return nil, "Not in combat" end
    if T.BindingOf(action) then return nil, "Not on bar slots" end
    local name = T.SlotMacroName(action)
    if not name then return nil, "Can't place" end
    local body = Body(action)
    if #body > 255 then return nil, "Too long" end
    local made, index = Made(), Index(name)
    if index and not made[name] then return nil, "Name taken" end
    if not index then
        local _, char = Call(GetNumMacros)
        local consts = Constants and Constants.MacroConsts
        local limit = consts and consts.MAX_CHARACTER_MACROS or _G.MAX_CHARACTER_MACROS or 18
        if (char or 0) >= limit then return nil, "Macros full" end
        index = Call(CreateMacro, name, M.Icon(action), body, true)
        if type(index) ~= "number" or index < 1 then return nil, "Macros full" end
    elseif Call(GetMacroBody, index) ~= body then
        Call(EditMacro, index, name, M.Icon(action), body)
    end
    made[name] = action
    return name
end

-- Every macro's body again (Quick use picks, Halo, windows)
function M.Apply()
    if InCombat() then return end
    local made = Made()
    for name, action in pairs(made) do
        local index = Index(name)
        if index then   -- (not loaded yet, or deleted by hand: Sweep's)
            local body = Body(action)
            if #body <= 255 and Call(GetMacroBody, index) ~= body then
                Call(EditMacro, index, name, M.Icon(action), body)
            end
        end
    end
end

-- The name of the macro on a bar slot, or nil. A macro that resolves to an
-- item or a spell (Quick use's "/use item:") reports that item's or spell's
-- id, not the macro's index (subType "item" / "spell"): its name comes from
-- the slot's text then
function M.MacroAt(slot)
    local kind, id, subType = Call(GetActionInfo, slot)
    if kind ~= "macro" then return nil end
    local text = Call(GetActionText, slot)
    if type(text) == "string" and text ~= "" and Index(text) then return text end
    if subType == "item" or subType == "spell" then return nil end
    return (Call(GetMacroInfo, id))
end

-- The action a bar slot runs through one of ours, or nil
function M.SlotAction(slot)
    return M.ActionFor(M.MacroAt(slot))
end

local function LastSlot()
    local C = ns.ControllerModel
    local k = C and C.Constants and C.Constants()
    local last = k and (k.first + k.perPage * (k.pages or 1)) or 0
    return math.max(1000, last + 512)
end

-- Deletes our macros no slot holds: not while one is on the cursor, nor
-- before the bars have loaded (a few seconds into the world)
local ready = false
function M.Sweep()
    if not ready or InCombat() or (GetCursorInfo and GetCursorInfo()) then return end
    local made = Made()
    if not next(made) then return end
    local used, any, unknown = {}, false, false
    for slot = 1, LastSlot() do
        local kind = Call(GetActionInfo, slot)
        if kind then any = true end
        if kind == "macro" then
            local name = M.MacroAt(slot)
            if name then used[name] = true else unknown = true end
        end
    end
    -- (a macro slot whose name can't be read may be ours: delete nothing)
    if unknown then return end
    if not any then return end   -- (bars not there: never delete on that)
    for name in pairs(made) do
        if not used[name] then
            local index = Index(name)
            if index then Call(DeleteMacro, index) end
            made[name] = nil
        end
    end
end

-- A moment later: the slots have settled
local waiting = false
function M.SweepSoon()
    if waiting then return end
    waiting = true
    local after = C_Timer and C_Timer.After
    if not after then waiting = false; M.Sweep(); return end
    after(0.3, function() waiting = false; M.Sweep() end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_MACROS", "ACTIONBAR_SLOT_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if ready then return end
        local after = C_Timer and C_Timer.After or function(_, f) f() end
        after(3, function() ready = true; M.Apply(); M.SweepSoon() end)
    elseif event == "UPDATE_MACROS" then
        if ready then M.Apply() end
    else
        M.SweepSoon()
    end
end)
