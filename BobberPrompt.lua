-- The bobber's prompt: while the line is out and R2 catches (Fishing.lua), the game's own
-- soft-target prompt over the bobber shows R2, not the Interact button.
--
-- Blizzard draws that prompt on the soft-interact unit's nameplate: NamePlateDriverFrame's
-- UpdateSoftTargetIconInternal fills SoftTargetFrame.Icon with SetUnitCursorTexture(...,
-- preferGamepadIcon = true): a Gamepad_<style>_<button> glyph. A post-hook (hooksecurefunc) puts
-- the R2 glyph of that same set on that same texture, only when the unit is the fishing bobber. No frame of ours, nothing
-- protected: every other prompt (NPCs, nodes, chests, mail) is left exactly as Blizzard draws it,
-- and the bobber's goes back the moment the target changes or R2 stops catching.
-- WoW Helper's fishing eye finds the bobber by this badge: it knows the R2 glyph too (helper
-- branch claude/bobber-r2), so the two ship together.
local _, ns = ...
local P = {}
ns.BobberPrompt = P

-- The fishing bobber (GameObject entry), and its name as a fallback
P.BOBBER = 35591
P.BOBBER_NAMES = { ["Fishing Bobber"] = true }
P.KEY = "PADRTRIGGER"

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

-- The entry of a GameObject GUID ("GameObject-0-server-instance-zone-ID-spawn"), else nil
function P.EntryOf(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "GameObject" then return nil end
    return tonumber(id)
end

-- Whether `unit` is the bobber we cast: the soft-interact game object, entry or name the bobber's
function P.IsBobber(unit)
    if not unit then return false end
    if not Call(UnitIsUnit, unit, "softinteract") then return false end
    if not Call(UnitIsGameObject, unit) then return false end
    if P.EntryOf(Call(UnitGUID, unit)) == P.BOBBER then return true end
    return P.BOBBER_NAMES[Call(UnitName, unit) or ""] == true
end

-- R2 catches now (the line out, a pole in hand, R2 bound to Interact)
function P.Catching()
    local F = ns.Fishing
    return F ~= nil and type(F.Catching) == "function" and F.Catching() == true
end

-- The game's world prompts are the Gamepad_<style>_<button>_<size> glyphs (the soft target's
-- badge over the bobber: Gamepad_Shp_Square_32 with a PlayStation pad, read from the install).
-- R2 in the same set: the drawn atlas' style and size kept, its button RTrigger. Drawn as a file
-- (no atlas name to read), the active controller style's set (Shapes: Shp...), at 32.
P.STYLES = { Shapes = "Shp", Letters = "Ltr", Reverse = "Rev", Generic = "Gen" }

local function Exists(atlas)
    local T = C_Texture
    if not (T and T.GetAtlasInfo) then return true end
    return Call(T.GetAtlasInfo, atlas) ~= nil
end

function P.Glyph(drawn)
    local style, size
    if type(drawn) == "string" then
        style, size = drawn:lower():match("^gamepad_(%a+)_.-_(%d+)$")
    end
    if not style then
        local M = InputDeviceIconSetManager
        local set = M and M.GetActiveInputDeviceIconSet and Call(M.GetActiveInputDeviceIconSet, M)
        style, size = P.STYLES[set or ""], "32"
        if style then style = style:lower() end
    end
    if not style then return nil end
    local atlas = "Gamepad_" .. style:sub(1, 1):upper() .. style:sub(2) .. "_RTrigger_" .. size
    if Exists(atlas) then return atlas end
end

-- Icons we changed: icon -> what Blizzard had drawn there (to put back)
local swapped = setmetatable({}, { __mode = "k" })
P.swapped = swapped

-- What the game drew for the bobber and what went on it, once a session: kept in the
-- character's saved settings (fishing.prompt), so a /reload after fishing shows the swap ran
local function Seen(original, glyph)
    if P.seen then return end
    P.seen = original
    local Sh = ns.Shared
    local char = Sh and Sh.CharDB and Sh.CharDB()
    if type(char) == "table" and type(char.fishing) == "table" then
        char.fishing.prompt = { atlas = original.atlas, texture = original.texture, glyph = glyph }
    end
end

-- Put Blizzard's drawing back on `icon` (only if it's still ours)
function P.Restore(icon)
    local was = swapped[icon]
    if not was then return end
    swapped[icon] = nil
    if was.atlas then
        icon:SetAtlas(was.atlas)
    elseif was.texture then
        icon:SetTexture(was.texture)
    end
    if was.coords then icon:SetTexCoord(unpack(was.coords)) end
end

-- After Blizzard drew (or hid) a nameplate's soft-target icon: R2 on it if it's the bobber
function P.Update(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    local uf = frame.UnitFrame
    local icon = uf and uf.SoftTargetFrame and uf.SoftTargetFrame.Icon
    if not icon then return end
    local unit = frame.GetUnit and frame:GetUnit() or frame.namePlateUnitToken
    local was = swapped[icon]
    if was then
        if icon:GetAtlas() == was.glyph then
            -- (Blizzard only hid it, or didn't redraw: ours is still there, its drawing back)
            P.Restore(icon)
        else
            -- (Blizzard drew it anew. A file texture keeps the texcoords our atlas left: the
            -- whole of it, as a file is drawn)
            swapped[icon] = nil
            if not icon:GetAtlas() then icon:SetTexCoord(0, 1, 0, 1) end
        end
    end
    if not (icon:IsShown() and P.Catching() and P.IsBobber(unit)) then return end
    local original = { atlas = icon:GetAtlas(), texture = icon:GetTexture(), coords = { icon:GetTexCoord() } }
    local glyph = P.Glyph(original.atlas)
    if not glyph then return end
    Seen(original, glyph)
    original.glyph = glyph
    swapped[icon] = original
    icon:SetAtlas(glyph)
end

-- R2's job or the line changed (Fishing.lua): put the bobber's prompt right without waiting for
-- the game's next update
function P.Refresh()
    if not P.Catching() then
        for icon in pairs(swapped) do P.Restore(icon) end
        return
    end
    local plate = C_NamePlate and Call(C_NamePlate.GetNamePlateForUnit, "softinteract")
    if plate then P.Update(plate) end
end

local hooked = false
function P.Hook()
    if hooked then return true end
    local driver = NamePlateDriverFrame
    if not (driver and type(driver.UpdateSoftTargetIconInternal) == "function" and hooksecurefunc) then return false end
    hooksecurefunc(driver, "UpdateSoftTargetIconInternal", function(_, frame) P.Update(frame) end)
    hooked = true
    return true
end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function()
        P.Hook()
        local F = ns.Fishing
        if F and F.OnChange then F.OnChange(P.Refresh) end
    end)
end

return P
