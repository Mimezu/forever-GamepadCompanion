-- Shared by the touchpad zones, the button bindings and the Controller page:
-- the character's profile, layer modifiers, macro lookups, Halo rings, and
-- keeping Companion's key bindings on top of Blizzard's.
local _, ns = ...
local Sh = {}
ns.Shared = Sh

-- Profile ----------------------------------------------------------------------
-- Bindings are per character (GamepadCompanionCharDB). A new character starts
-- from a copy of the account-wide touchpad settings.
function Sh.CharDB()
    if type(GamepadCompanionCharDB) ~= "table" then GamepadCompanionCharDB = { version = 1 } end
    return GamepadCompanionCharDB
end

-- Layers -----------------------------------------------------------------------
-- The gamepad UI sends L2 as Shift and R2 as Ctrl (GamepadConstants.lua)
Sh.LAYERS = { "base", "lt", "rt", "both" }
function Sh.LayerPrefix(layer)
    local left, right = _G.GAMEPAD_MOD_LEFT or "SHIFT", _G.GAMEPAD_MOD_RIGHT or "CTRL"
    local both = _G.GAMEPAD_MOD_LEFT_AND_RIGHT or (right .. "-" .. left)
    if layer == "lt" then return left .. "-" end
    if layer == "rt" then return right .. "-" end
    if layer == "both" then return both .. "-" end
    return ""
end

-- The pad ----------------------------------------------------------------------
-- The one place "is a pad button down" is read: the pad's own state
-- (C_GamePad.GetDeviceMappedState), what the secure snippets read as
-- GetGamePadState. Never IsKeyDown on a binding's key: the game's key state
-- is the bindings' (a release a window ate leaves it down, and Blizzard's
-- sets rebind the triggers' keys), which bound Focus UI to Create with L2 up
-- (2026-11-21). nil: no pad to read.
function Sh.PadButtons()
    local P = C_GamePad
    if not (P and P.GetDeviceMappedState) then return nil end
    local okId, id = pcall(P.GetActiveDeviceID)
    local ok, state = pcall(P.GetDeviceMappedState, okId and id or nil)
    return ok and type(state) == "table" and type(state.buttons) == "table" and state.buttons or nil
end

-- Is key ("PADLTRIGGER") down in buttons (Sh.PadButtons()); nil when unknown
-- (each key's index, kept: the watchers read every key ten times a second; a new pad
-- clears them, Sh.ForgetPadIndexes)
local padIndex, padLookup = {}, nil
function Sh.ForgetPadIndexes() padIndex = {} end
function Sh.PadDown(buttons, key)
    local P = C_GamePad
    if not (buttons and P and P.ButtonBindingToIndex) then return nil end
    if padLookup ~= P.ButtonBindingToIndex then padIndex, padLookup = {}, P.ButtonBindingToIndex end
    local index = padIndex[key]
    if index == nil then
        local ok, i = pcall(P.ButtonBindingToIndex, key)
        if not ok or type(i) ~= "number" then return nil end
        index = i
        padIndex[key] = i
    end
    return buttons[index + 1] and true or false
end

-- L2, R2 down now: true / false each; nil, nil without a pad to read
function Sh.Held()
    local buttons = Sh.PadButtons()
    local lt, rt = Sh.PadDown(buttons, "PADLTRIGGER"), Sh.PadDown(buttons, "PADRTRIGGER")
    if lt == nil or rt == nil then return nil, nil end
    return lt, rt
end

-- The layer the triggers held make
function Sh.LayerOf(lt, rt)
    return (lt and rt and "both") or (lt and "lt") or (rt and "rt") or "base"
end

-- The layer L2 / R2 hold now, from the pad; nil without one (callers fall
-- back to Base: nothing of a held layer is ever bound on a guess)
function Sh.Layer()
    local lt, rt = Sh.Held()
    if lt == nil then return nil end
    return Sh.LayerOf(lt, rt)
end

-- Halo rings (when Halo is loaded) --------------------------------------------
function Sh.HaloRings()
    local H = _G.Halo
    local list = {}
    if type(H) ~= "table" or type(H.db) ~= "table" or type(H.db.rings) ~= "table" then return list end
    for _, ring in ipairs(H.db.rings) do
        local here = type(H.RingActiveHere) ~= "function" or H.RingActiveHere(ring)
        if here and ring.id then list[#list + 1] = ring end
    end
    return list
end

function Sh.HaloRing(id)
    id = tonumber(id)
    for _, ring in ipairs(Sh.HaloRings()) do if ring.id == id then return ring end end
end

function Sh.HaloIcon(ring)
    local H = _G.Halo
    local ok, icon = pcall(function() return H.RingIcon(ring, true) end)
    return ok and icon or "Interface\\Icons\\INV_Misc_Gem_Variety_01"
end

-- What T.MacroText needs from the game
Sh.lookup = {
    button = function(name) local b = _G[name]; return type(b) == "table" and b.Click ~= nil end,
    spellName = function(id)
        if not id then return nil end
        if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
        return GetSpellInfo and (GetSpellInfo(id))
    end,
    macroBody = function(name)
        if not GetMacroInfo then return nil end
        local _, _, body = GetMacroInfo(name)
        return body
    end,
    haloRing = function(id) return Sh.HaloRing(id) ~= nil end,
}

-- Keeping bindings on top -------------------------------------------------------
-- Blizzard's binding sets bind with priority on UIParent; the last priority
-- binding wins. Each claim is { keys = key -> action, apply = fn }: when
-- Blizzard takes one of its keys, apply runs (next frame) to put them back.
local claims, queued = {}, false
function Sh.Claim(keys, apply)
    claims[#claims + 1] = { keys = keys, apply = apply }
end

local function Check()
    queued = false
    for _, claim in ipairs(claims) do
        for key, action in pairs(claim.keys) do
            if GetBindingAction and GetBindingAction(key, true) ~= action then
                claim.apply(key)
                break
            end
        end
    end
end

local function Taken(owner, _, key)
    if owner ~= UIParent or queued then return end
    for _, claim in ipairs(claims) do
        if claim.keys[key] then
            queued = true
            C_Timer.After(0, Check)
            return
        end
    end
end
hooksecurefunc("SetOverrideBinding", Taken)
hooksecurefunc("SetOverrideBindingClick", Taken)
