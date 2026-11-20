-- NodeCompass: the map row for WoW Helper's node compass (its docs/NODE-COMPASS.md). While Find
-- Minerals, Find Herbs or Find Treasure is on, it sends what the game says about the minimap:
-- the character's facing, the minimap's centre and radius in client pixels, its zoom in yards
-- across, whether it rotates, which tracking. WoW Helper finds the live node dots in its capture
-- of the minimap and draws arrows on the screen's edge. Nothing here reads the dots: no API does.
local _, ns = ...
local N = {}
ns.NodeCompass = N

local floor, pi = math.floor, math.pi

-- Tracking kinds (the row's 2 bits): 1 minerals, 2 herbs, 3 treasure
N.SPELLS = { [2580] = 1, [2383] = 2, [2481] = 3 }
N.TEXTURES = { [136025] = 1, [133939] = 2 }   -- Spell_Nature_Earthquake, INV_Misc_Flower_02
N.NAMES = { { "Mineral", 1 }, { "Herb", 2 }, { "Treasure", 3 } }

-- Yards across the minimap at each zoom level 0-5 (as HereBeDragons-Pins)
N.YARDS = {
    indoor = { [0] = 300, 240, 180, 120, 80, 50 },
    outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
}

function N.Kind(spellID, texture, name)
    if spellID and N.SPELLS[spellID] then return N.SPELLS[spellID] end
    if texture and N.TEXTURES[texture] then return N.TEXTURES[texture] end
    if type(name) == "string" then
        for _, p in ipairs(N.NAMES) do
            if name:find(p[1]) then return p[2] end
        end
    end
    return nil
end

-- The node tracking on now: 0 none, else its kind
function N.Tracking()
    local C = C_Minimap
    if C and C.GetNumTrackingTypes and C.GetTrackingInfo then
        for i = 1, C.GetNumTrackingTypes() or 0 do
            local info = C.GetTrackingInfo(i)
            if type(info) == "table" and info.active then
                local k = N.Kind(info.spellID, info.texture, info.name)
                if k then return k end
            end
        end
        return 0
    end
    if GetTrackingTexture then return N.Kind(nil, GetTrackingTexture(), nil) or 0 end
    return 0
end

local function Round(v) return floor(v + 0.5) end

-- Yards across at this zoom: the outdoor table when the outdoor zoom CVar is what the minimap
-- shows (as HereBeDragons), IsIndoors() when both CVars agree
function N.Yards(mm)
    local zoom = mm:GetZoom() or 0
    local out, inside = tonumber(GetCVar("minimapZoom")), tonumber(GetCVar("minimapInsideZoom"))
    local indoor
    if out == inside then indoor = IsIndoors and IsIndoors() or false else indoor = out ~= zoom end
    return (indoor and N.YARDS.indoor or N.YARDS.outdoor)[zoom] or 0
end

-- The row now, or nil: none (no node tracking, no minimap, no facing)
function N.Row()
    if (N.tracking or 0) == 0 then return nil end
    local mm = Minimap
    if not mm or not mm:IsVisible() then return nil end
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not facing then return nil end
    local cx, cy = mm:GetCenter()
    local _, ph = GetPhysicalScreenSize()
    if not cx or not ph or ph <= 0 then return nil end
    local k = mm:GetEffectiveScale() * ph / 768   -- UI units -> physical pixels
    return {
        facing = Round(facing / (2 * pi) * 1024) % 1024,
        x = Round(cx * k), y = Round(ph - cy * k),
        radius = Round(mm:GetWidth() * k / 2),
        yards = Round(N.Yards(mm)),
        rotates = GetCVar("rotateMinimap") == "1",
        tracking = N.tracking,
    }
end

local frame
local function Update() if ns.HelperLink then ns.HelperLink.SetMap(N.Row()) end end

-- Tracking changed (or the world): run each frame only while a node tracking is on
function N.Refresh()
    N.tracking = N.Tracking()
    if frame then frame:SetScript("OnUpdate", N.tracking ~= 0 and Update or nil) end
    Update()
end

if CreateFrame then
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", N.Refresh)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
end
