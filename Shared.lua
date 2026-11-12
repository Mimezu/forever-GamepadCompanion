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
