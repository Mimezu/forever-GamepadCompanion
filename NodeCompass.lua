-- NodeCompass: the map row for WoW Helper's node compass (its docs/NODE-COMPASS.md). While Find
-- Minerals, Find Herbs or Find Treasure is on, it sends what the game says about the minimap:
-- the character's facing, the minimap's centre and radius in client pixels, its zoom in yards
-- across, whether it rotates, which tracking, and the camera's yaw. WoW Helper finds the live
-- node dots in its capture of the minimap and draws arrows on the screen's edge. Nothing here
-- reads the dots: no API does.
-- With it the world (the compact line's world section, HelperLink.lua): whether the minimap
-- shows, is faded out (Frame Gambit while you stand) or hidden, the zone (uiMapID), where the
-- character stands in world yards (UnitPosition; east and north at half a yard, wrapping) and
-- whether it moves. With a WoW Helper that reads it, the row keeps coming while the minimap is
-- faded or hidden: the helper then draws its arrows from what it remembers instead of dropping
-- them, and keeps its nodes in yards from the position, exact (2026-11-27).
--
-- The camera: no API gives its yaw, so it is worked out from the pad. Moving with the left stick
-- is camera-relative and the character turns to face where it goes (GamePadFaceMovementMaxAngle,
-- 0 = always; in combat its Combat twin): once the facing has settled, camera = facing + the
-- stick's angle (past the limit the character faces the camera: camera = facing). Standing,
-- only the right stick turns the camera: its turning is added up, and each fix while moving
-- corrects it and learns how fast the camera turns (saved). Mouse turning is caught at the next
-- fix.
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
local sqrt, abs, atan2 = math.sqrt, math.abs, math.atan2 or function(y, x) return math.atan(y, x) end
local TAU = 2 * pi
local function Wrap(a)
    a = a % TAU
    if a > pi then a = a - TAU end
    return a
end
N.Wrap = Wrap

N.GAIN0 = 2.5          -- rad/s at full right stick (x GamePadCameraYawSpeed), until learned
N.SETTLE = 0.12        -- s of steady stick and facing before a fix
N.DEAD = 0.15          -- right stick dead zone
N.MOVE = 0.5           -- left stick past this: moving by stick

-- One frame of the camera estimate. c: the state ({ yaw, gain, ... }); dt seconds; facing (rad);
-- the left stick (lx, ly: up +), the right stick's x (right +); moving: the character moves;
-- limit: the face-movement angle (rad; pi: always). Returns the yaw (rad, as facing).
function N.CameraStep(c, dt, facing, lx, ly, rx, moving, limit)
    c.yaw = c.yaw or facing
    local gain = c.gain or N.GAIN0
    -- the right stick turns the camera: right is clockwise (the yaw goes down)
    if abs(rx or 0) > N.DEAD then
        c.yaw = Wrap(c.yaw - rx * gain * dt)
        c.turned = (c.turned or 0) - rx * dt
    end
    local len = sqrt((lx or 0) ^ 2 + (ly or 0) ^ 2)
    if moving and len > N.MOVE then
        local a = atan2(lx, ly)   -- the stick's angle, clockwise from up
        local still = c.lastA and abs(Wrap(a - c.lastA)) < 0.05 and abs(Wrap(facing - c.lastF)) < 0.02
        c.steady = still and (c.steady or 0) + dt or 0
        c.lastA, c.lastF = a, facing
        if c.steady >= N.SETTLE then
            local fix = abs(a) <= limit and Wrap(facing + a) or Wrap(facing)
            -- learn the right stick's speed from the turn since the last fix
            local t = c.turned or 0
            if c.fixYaw and abs(t) > 0.4 and abs(t * gain) < 2.5 then
                local g = Wrap(fix - c.fixYaw) / t
                if g > 0.5 and g < 10 then c.gain = gain + 0.3 * (g - gain) end
            end
            c.yaw, c.fixYaw, c.turned = fix, fix, 0
        end
    else
        c.steady, c.lastA = 0, nil
    end
    return c.yaw
end

local function MappedSticks()
    local P = C_GamePad
    if not (P and P.GetDeviceMappedState and P.GetActiveDeviceID) then return nil end
    local ok, st = pcall(P.GetDeviceMappedState, P.GetActiveDeviceID())
    local s = ok and type(st) == "table" and st.sticks
    if not s or not s[1] or not s[2] then return nil end
    return s[1].x or 0, s[1].y or 0, s[2].x or 0
end

local function FaceLimit()
    local combat = UnitAffectingCombat and UnitAffectingCombat("player")
    local v = tonumber(GetCVar(combat and "GamePadFaceMovementMaxAngleCombat" or "GamePadFaceMovementMaxAngle"))
    if not v or v <= 0 or v >= 180 then return pi end
    return v * pi / 180
end

-- The learned speed, kept per camera yaw speed setting
local function GainStore()
    if type(GamepadCompanionHapticsDB) ~= "table" then return nil end
    local db = GamepadCompanionHapticsDB
    if type(db.compass) ~= "table" then db.compass = {} end
    return db.compass
end

N.cam = {}
local lastT
-- The camera's yaw now (rad), or nil: no pad
function N.Camera(facing)
    local lx, ly, rx = MappedSticks()
    if not lx then return nil end
    local now = GetTime and GetTime() or 0
    local dt = lastT and math.min(now - lastT, 0.2) or 0
    lastT = now
    local c = N.cam
    if not c.gain then
        local store = GainStore()
        local speed = tonumber(GetCVar("GamePadCameraYawSpeed")) or 1
        c.speed = speed
        c.gain = store and store.speed == speed and tonumber(store.gain) or N.GAIN0 * speed
    end
    local moving = N.Moving()
    local was = c.gain
    local yaw = N.CameraStep(c, dt, facing, lx, ly, rx, moving, FaceLimit())
    if c.gain ~= was then
        local store = GainStore()
        if store then store.gain, store.speed = c.gain, c.speed end
    end
    return yaw
end

-- The character moves (the speed is a secret number in combat: the last known kept then)
function N.Moving()
    local c = N.cam
    local sp = GetUnitSpeed and GetUnitSpeed("player")
    if type(sp) == "number" and not (issecretvalue and issecretvalue(sp)) then c.moving = sp > 0 end
    return c.moving or false
end

-- The minimap's state (the world section's 2 bits): 0 shown, 1 faded out by an addon (an
-- effective alpha under 0.3: Frame Gambit while you stand), 2 hidden
function N.MinimapState(mm)
    if not mm or not mm:IsVisible() then return 2 end
    if mm.GetEffectiveAlpha and (mm:GetEffectiveAlpha() or 1) < 0.3 then return 1 end
    return 0
end

local function Public(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end
local function Ask(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok and Public(a) then return a end
    return nil
end

-- Where the character stands in world yards: east and north (the world's axes: UnitPosition gives
-- posY (west) then posX (north), so east = -posY, north = posX); nil: the game doesn't say (an
-- instance, a secret value). Without UnitPosition, the map position through the game's own
-- map-to-world (C_Map.GetWorldPosFromMapPos: no table of zone sizes)
function N.Position()
    if UnitPosition then
        local ok, py, px = pcall(UnitPosition, "player")
        if ok and Public(py) and Public(px) and type(py) == "number" and type(px) == "number" then return -py, px end
    end
    local C = C_Map
    if not (C and C.GetBestMapForUnit and C.GetPlayerMapPosition and C.GetWorldPosFromMapPos) then return nil end
    local map = Ask(C.GetBestMapForUnit, "player")
    if type(map) ~= "number" or map <= 0 then return nil end
    local pos = Ask(C.GetPlayerMapPosition, map, "player")
    if type(pos) ~= "table" and type(pos) ~= "userdata" then return nil end
    local ok, _, world = pcall(C.GetWorldPosFromMapPos, map, pos)
    if not ok or (type(world) ~= "table" and type(world) ~= "userdata") then return nil end
    local wx, wy = world.x, world.y
    if world.GetXY then
        local ok2, a, b = pcall(world.GetXY, world)
        if ok2 then wx, wy = a, b end
    end
    if Public(wx) and Public(wy) and type(wx) == "number" and type(wy) == "number" then return -wy, wx end
    return nil
end

-- The world section's place fields: the zone's uiMapID (nil: unknown) and the position in half
-- yards, 0-65535 wrapping (nil, nil: unknown)
function N.World()
    local zone
    local C = C_Map
    if C and C.GetBestMapForUnit then
        zone = Ask(C.GetBestMapForUnit, "player")
        if type(zone) ~= "number" or zone <= 0 then zone = nil end
    end
    local east, north = N.Position()
    if not east then return zone, nil, nil end
    return zone, floor(east * 2 + 0.5) % 65536, floor(north * 2 + 0.5) % 65536
end

-- Yards across at this zoom: the outdoor table when the outdoor zoom CVar is what the minimap
-- shows (as HereBeDragons), IsIndoors() when both CVars agree
function N.Yards(mm)
    local zoom = mm:GetZoom() or 0
    local out, inside = tonumber(GetCVar("minimapZoom")), tonumber(GetCVar("minimapInsideZoom"))
    local indoor
    if out == inside then indoor = IsIndoors and IsIndoors() or false else indoor = out ~= zoom end
    return (indoor and N.YARDS.indoor or N.YARDS.outdoor)[zoom] or 0
end

-- The row now, or nil: none (no node tracking, no minimap, no facing). The minimap hidden or
-- faded out (an addon hiding it while you stand): the row says so (minimap 1 or 2); HelperLink
-- sends it then only to a WoW Helper that reads the world section, which keeps the nodes it
-- knows and their arrows until it shows again (an older helper gets no row, as before)
function N.Row()
    if (N.tracking or 0) == 0 then return nil end
    local mm = Minimap
    if not mm then return nil end
    local minimap = N.MinimapState(mm)
    local facing = GetPlayerFacing and GetPlayerFacing()
    if type(facing) ~= "number" or (issecretvalue and issecretvalue(facing)) then return nil end
    local cx, cy = mm:GetCenter()
    local _, ph = GetPhysicalScreenSize()
    if not cx or not ph or ph <= 0 then return nil end
    local k = mm:GetEffectiveScale() * ph / 768   -- UI units -> physical pixels
    local cam = N.Camera(facing)
    local zone, east, north = N.World()
    return {
        facing = Round(facing / (2 * pi) * 1024) % 1024,
        x = Round(cx * k), y = Round(ph - cy * k),
        radius = Round(mm:GetWidth() * k / 2),
        yards = Round(N.Yards(mm)),
        rotates = GetCVar("rotateMinimap") == "1",
        tracking = N.tracking,
        camera = cam and Round(cam / (2 * pi) * 1024) % 1024 or nil,
        -- the world section (the compact line only)
        minimap = minimap, zone = zone, east = east, north = north, moving = N.Moving(),
    }
end

local frame
local function Update() if ns.HelperLink then ns.HelperLink.SetMap(N.Row()) end end

-- Tracking changed (or the world): run each frame only while a node tracking is on
function N.Refresh(_, event)
    N.tracking = N.Tracking()
    if event == "PLAYER_ENTERING_WORLD" then N.cam.yaw, N.cam.fixYaw, N.cam.turned = nil, nil, nil end   -- (the camera behind)
    if frame then frame:SetScript("OnUpdate", N.tracking ~= 0 and Update or nil) end
    Update()
end

if CreateFrame then
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", N.Refresh)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
end
