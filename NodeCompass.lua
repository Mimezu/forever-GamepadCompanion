-- NodeCompass: the map row for WoW Helper's node compass (its docs/NODE-COMPASS.md). While Find
-- Minerals, Find Herbs or Find Treasure is on, it sends what the game says about the minimap:
-- the character's facing, the minimap's centre and radius in client pixels, its zoom in yards
-- across, whether it rotates, which tracking, and the camera's yaw. WoW Helper finds the live
-- node dots in its capture of the minimap and draws arrows on the screen's edge. Nothing here
-- reads the dots: no API does.
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
    -- (the speed is a secret number in combat: the last known kept then)
    local sp = GetUnitSpeed and GetUnitSpeed("player")
    if type(sp) == "number" and not (issecretvalue and issecretvalue(sp)) then c.moving = sp > 0 end
    local moving = c.moving or false
    local was = c.gain
    local yaw = N.CameraStep(c, dt, facing, lx, ly, rx, moving, FaceLimit())
    if c.gain ~= was then
        local store = GainStore()
        if store then store.gain, store.speed = c.gain, c.speed end
    end
    return yaw
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

-- The row now, or nil: none (no node tracking, no minimap, no facing)
function N.Row()
    if (N.tracking or 0) == 0 then return nil end
    local mm = Minimap
    -- (hidden, or faded out (an addon hiding it while you stand): no row; WoW Helper keeps
    -- the nodes it knows until it shows again)
    if not mm or not mm:IsVisible() then return nil end
    if mm.GetEffectiveAlpha and (mm:GetEffectiveAlpha() or 1) < 0.3 then return nil end
    local facing = GetPlayerFacing and GetPlayerFacing()
    if type(facing) ~= "number" or (issecretvalue and issecretvalue(facing)) then return nil end
    local cx, cy = mm:GetCenter()
    local _, ph = GetPhysicalScreenSize()
    if not cx or not ph or ph <= 0 then return nil end
    local k = mm:GetEffectiveScale() * ph / 768   -- UI units -> physical pixels
    local cam = N.Camera(facing)
    return {
        facing = Round(facing / (2 * pi) * 1024) % 1024,
        x = Round(cx * k), y = Round(ph - cy * k),
        radius = Round(mm:GetWidth() * k / 2),
        yards = Round(N.Yards(mm)),
        rotates = GetCVar("rotateMinimap") == "1",
        tracking = N.tracking,
        camera = cam and Round(cam / (2 * pi) * 1024) % 1024 or nil,
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
