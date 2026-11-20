-- NodeCompass: tracking kinds, the map row's numbers from the minimap (pixels, zoom, facing).
-- lua5.1 tests/NodeCompass.lua <addon folder>
local root = arg[1] or "."

local cvars = { minimapZoom = "0", minimapInsideZoom = "2", rotateMinimap = "0" }
function GetCVar(k) return cvars[k] end
local physH = 1440
function GetPhysicalScreenSize() return 2560, physH end
local facing = math.pi / 2
function GetPlayerFacing() return facing end
local indoors = false
function IsIndoors() return indoors end
local tracking = {}
C_Minimap = {
    GetNumTrackingTypes = function() return #tracking end,
    GetTrackingInfo = function(i) return tracking[i] end,
}
local zoom, shown = 0, true
-- a 140-unit minimap at scale 1, its centre at (1200, 700) UI units of a 1440 px tall screen
Minimap = {
    GetZoom = function() return zoom end,
    IsVisible = function() return shown end,
    GetCenter = function() return 1200, 700 end,
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 140 end,
}
local sent = {}
local ns = { HelperLink = { SetMap = function(m) sent[#sent + 1] = m or false end } }
assert(loadfile(root .. "/NodeCompass.lua"))("GamepadCompanion", ns)
local N = ns.NodeCompass

-- kinds: by spell id, by texture, by name; others are not nodes
assert(N.Kind(2580) == 1 and N.Kind(2383) == 2 and N.Kind(2481) == 3, "spell ids")
assert(N.Kind(nil, 136025) == 1 and N.Kind(nil, 133939) == 2, "textures")
assert(N.Kind(nil, nil, "Find Herbs") == 2 and N.Kind(nil, nil, "Track Beasts") == nil, "names")
tracking = { { name = "Track Beasts", active = true, spellID = 1494 }, { name = "Find Minerals", active = false, spellID = 2580 } }
assert(N.Tracking() == 0, "a beast tracking is not a node tracking")
tracking[2].active = true
assert(N.Tracking() == 1, "minerals")

-- the row: pixels = units * scale * 1440 / 768; y from the top
N.Refresh()
local m = assert(N.Row())
local k = 1440 / 768
assert(m.x == math.floor(1200 * k + 0.5) and m.y == math.floor(1440 - 700 * k + 0.5), "centre " .. m.x .. "," .. m.y)
assert(m.radius == math.floor(70 * k + 0.5), "radius " .. m.radius)
assert(m.facing == 256 and m.tracking == 1 and m.rotates == false, "facing a quarter turn")
assert(m.yards == 467, "outdoor zoom 0: 467 yards across")
zoom = 2
assert(N.Row().yards == 180, "indoor (the minimap shows the inside zoom): 180")
cvars.minimapInsideZoom = "0"
cvars.minimapZoom = "2"
assert(N.Row().yards == 333, "outdoor zoom 2: 333")
cvars.minimapInsideZoom = "2"
indoors = true
assert(N.Row().yards == 180, "both CVars agree: IsIndoors decides")
cvars.rotateMinimap = "1"
assert(N.Row().rotates, "rotates")
facing = nil
assert(N.Row() == nil, "no facing (an instance): no row")
facing = 0
shown = false
assert(N.Row() == nil, "no minimap: no row")
shown = true
tracking[2].active = false
N.Refresh()
assert(N.Row() == nil and sent[#sent] == false, "tracking off: the row goes")
print("NodeCompass: ok")
