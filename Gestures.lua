-- Gestures: what the pad's motion gestures run. WoW Helper records and
-- recognises them (slots 1-12) and presses Ctrl+Shift+Alt+F<slot>; here each
-- slot gets an action, in the touchpad's format (spell:, item:, macro:,
-- window:, halo:, text: for a typed macro such as /dance). One secure button
-- runs them all ("g1" .. "g12"), as Keys.lua does; per character; out of
-- combat only, a change in combat applies after it.
local _, ns = ...
local T, Sh = ns.TouchModel, ns.Shared
local G = {}
ns.Gestures = G

G.SLOTS = 12
G.RECENT = 5             -- the last gestures the Gestures tab lists
G.BUTTON = "GamepadCompanionGestures"
-- (WoW names chords Alt, Ctrl, Shift in that order; another order never matches)
function G.Key(slot) return "ALT-CTRL-SHIFT-F" .. slot end
function G.Label(slot) return "Gesture " .. slot end

local settings = {}         -- slot -> action
local bound = {}            -- binding key -> "CLICK GamepadCompanionGestures:g<slot>"
local pending, loaded = false, false

local button = CreateFrame("Button", G.BUTTON, UIParent, "SecureActionButtonTemplate")
button:SetSize(1, 1)
button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
button:RegisterForClicks("AnyDown", "AnyUp")
local owner = CreateFrame("Frame", "GamepadCompanionGestureBinds")
-- The last gesture that ran: { slot, at } (the Gestures tab's Last gesture)
button:HookScript("OnClick", function(_, id, down)
    local slot = type(id) == "string" and tonumber(id:match("^g(%d+)$"))
    if not slot or down == false then return end
    G.last = { slot = slot, at = GetTime and GetTime() or 0 }
    G.recent = G.recent or {}
    table.insert(G.recent, 1, G.last)
    while #G.recent > G.RECENT do table.remove(G.recent) end
    if G.onFire then G.onFire(slot) end
end)

function G.Normalize(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for slot = 1, G.SLOTS do
        if T.ValidAction(raw[slot]) then out[slot] = raw[slot] end
    end
    return out
end

function G.Get(slot) return settings[slot] end
function G.Settings() return settings end
function G.IsPending() return pending end
function G.Bound(slot) return bound[G.Key(slot)] end

function G.Apply()
    if InCombatLockdown and InCombatLockdown() then pending = true; return false end
    pending = false
    ClearOverrideBindings(owner)
    wipe(bound)
    for slot = 1, G.SLOTS do
        local id = "g" .. slot
        local binding = T.BindingOf(settings[slot])
        local macro = not binding and T.MacroText(settings[slot], Sh.lookup) or nil
        button:SetAttribute("*type-" .. id, macro and "macro" or nil)
        button:SetAttribute("*macrotext-" .. id, macro)
        if binding then
            -- (Blizzard's own function: the gesture's key runs its binding)
            SetOverrideBinding(owner, true, G.Key(slot), binding)
            bound[G.Key(slot)] = binding
        elseif macro then
            SetOverrideBindingClick(owner, true, G.Key(slot), G.BUTTON, id)
            bound[G.Key(slot)] = "CLICK " .. G.BUTTON .. ":" .. id
        end
    end
    return true
end

-- action nil or "none" clears
function G.Set(slot, action)
    if type(slot) ~= "number" or slot < 1 or slot > G.SLOTS then return false end
    if action == "none" then action = nil end
    if action ~= nil and not T.ValidAction(action) then return false end
    settings[slot] = action
    G.Apply()
    return true
end

Sh.Claim(bound, function()
    if InCombatLockdown and InCombatLockdown() then pending = true; return end
    G.Apply()
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "UPDATE_MACROS", "SPELLS_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= "GamepadCompanion" then return end
        local char = Sh.CharDB()
        settings = G.Normalize(char.gestures)
        char.gestures = settings
        loaded = true
        return
    end
    if not loaded then return end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    G.Apply()
end)
