-- Button bindings: what L1, R1, L3, R3, Create, Options, PS and Mute run, on
-- each layer, per character. One secure button runs them all ("k1", "k2" ...);
-- a layer is a modified key (Shift / Ctrl, for keyboards). Forever's gamepad
-- bar takes L2 / R2 for itself (no Shift while L2 is held), so while L2 / R2
-- is held out of combat the bare key runs that layer's action, and goes back
-- to the base one on release. In combat: the base action (bindings can't
-- change there). Out of combat only; a change in combat applies after it.
local _, ns = ...
local T, Sh = ns.TouchModel, ns.Shared
local Keys = {}
ns.Keys = Keys

Keys.KEYS = { "PADLSHOULDER", "PADRSHOULDER", "PADLSTICK", "PADRSTICK", "PADSOCIAL", "PADFORWARD", "PADSYSTEM", "PAD5" }
local ALLOWED = {}
for _, key in ipairs(Keys.KEYS) do ALLOWED[key] = true end
Keys.BUTTON = "GamepadCompanionKeys"

local settings = {}
local bound = {}            -- binding key -> "CLICK GamepadCompanionKeys:k1"
local used = 0              -- attributes set last time
local pending, loaded = false, false
local listeners = {}

local button = CreateFrame("Button", Keys.BUTTON, UIParent, "SecureActionButtonTemplate")
button:SetSize(1, 1)
button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
button:RegisterForClicks("AnyDown", "AnyUp")
local owner = CreateFrame("Frame", "GamepadCompanionKeyBinds")

-- key -> layer -> action, valid entries only
function Keys.Normalize(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for key, layers in pairs(raw) do
        if ALLOWED[key] and type(layers) == "table" then
            for _, layer in ipairs(Sh.LAYERS) do
                local action = layers[layer]
                if T.ValidAction(action) then
                    out[key] = out[key] or {}
                    out[key][layer] = action
                end
            end
        end
    end
    return out
end

function Keys.Allowed(key) return ALLOWED[key] == true end
function Keys.Get(key, layer) return settings[key] and settings[key][layer] or nil end
function Keys.Settings() return settings end
function Keys.IsPending() return pending end
function Keys.OnChange(callback) listeners[#listeners + 1] = callback end
local function Notify() for _, callback in ipairs(listeners) do pcall(callback) end end

-- The layer L2 / R2 hold now: "base", "lt", "rt" or "both"
function Keys.HeldLayer()
    local held = ns.Model and ns.Model.Held
    if type(held) ~= "function" then return "base" end
    local lt, rt = held("GAMEPADLEFTMOD") == true, held("GAMEPADRIGHTMOD") == true
    return lt and rt and "both" or lt and "lt" or rt and "rt" or "base"
end
Keys.active = "base"

function Keys.Apply(layer)
    if InCombatLockdown and InCombatLockdown() then pending = true; return false end
    pending = false
    if layer then Keys.active = layer end
    local active = Keys.active
    ClearOverrideBindings(owner)
    wipe(bound)
    local n = 0
    for _, key in ipairs(Keys.KEYS) do
        for _, layer in ipairs(Sh.LAYERS) do
            local action = Keys.Get(key, layer)
            -- (the bare key: the held layer's action, else the base one)
            if layer == "base" and active ~= "base" then action = Keys.Get(key, active) or action end
            local binding = T.BindingOf(action)
            local macro = not binding and T.MacroText(action, Sh.lookup) or nil
            if binding then
                -- (Blizzard's own function: the key runs its binding, securely)
                local bindKey = Sh.LayerPrefix(layer) .. key
                SetOverrideBinding(owner, true, bindKey, binding)
                bound[bindKey] = binding
            elseif macro then
                n = n + 1
                local id = "k" .. n
                button:SetAttribute("*type-" .. id, "macro")
                button:SetAttribute("*macrotext-" .. id, macro)
                local bindKey = Sh.LayerPrefix(layer) .. key
                SetOverrideBindingClick(owner, true, bindKey, Keys.BUTTON, id)
                bound[bindKey] = "CLICK " .. Keys.BUTTON .. ":" .. id
            end
        end
    end
    for i = n + 1, used do
        button:SetAttribute("*type-k" .. i, nil)
        button:SetAttribute("*macrotext-k" .. i, nil)
    end
    used = n
    return true
end

-- action nil or "none" clears
function Keys.Set(key, layer, action)
    if not ALLOWED[key] then return false end
    if action == "none" then action = nil end
    if action ~= nil and not T.ValidAction(action) then return false end
    settings[key] = settings[key] or {}
    settings[key][layer] = action
    if next(settings[key]) == nil then settings[key] = nil end
    Keys.Apply()
    Notify()
    return true
end

-- The binding key and the command Companion bound there, for a key and layer
function Keys.Bound(key, layer)
    local bindKey = Sh.LayerPrefix(layer) .. key
    return bound[bindKey]
end

Sh.Claim(bound, function()
    if InCombatLockdown and InCombatLockdown() then pending = true; return end
    Keys.Apply()
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "UPDATE_MACROS", "SPELLS_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= "GamepadCompanion" then return end
        local char = Sh.CharDB()
        settings = Keys.Normalize(char.keys)
        char.keys = settings
        loaded = true
        return
    end
    if not loaded then return end
    -- (combat: the base actions, while bindings can still change)
    if event == "PLAYER_REGEN_DISABLED" then
        if Keys.active ~= "base" then Keys.Apply("base") end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    Keys.Apply()
end)

-- L2 / R2 held, out of combat: the bare keys follow the layer (only the keys
-- with a layer action; nothing changes when none has one)
local function HasLayers()
    for _, layers in pairs(settings) do
        if layers.lt or layers.rt or layers.both then return true end
    end
    return false
end
local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.02 or not loaded then return end
    since = 0
    if InCombatLockdown and InCombatLockdown() then return end
    local layer = HasLayers() and Keys.HeldLayer() or "base"
    if layer ~= Keys.active then Keys.Apply(layer) end
end)
