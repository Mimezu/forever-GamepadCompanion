-- NodeSense: the minimap's dots named by a hidden sweep. Names to kinds, hits to dots, the row's
-- picks, the slide a still dot makes as you walk, and the whole sweep against a simulated minimap:
-- the reading that finds dots kept; two mirrored readings told apart by the slide; the row's
-- numbers; /gpc ore; the API refused.
-- lua5.1 tests/NodeSense.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end
local function near(a, b, tol, label) check(type(a) == "number" and math.abs(a - b) <= tol, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- The game, simulated ------------------------------------------------------------------------
local function Stub() return setmetatable({}, { __index = function() return function() end end }) end
local driver
CreateFrame = function() local f = Stub(); f.SetScript = function(self, _, fn) self.onUpdate = fn; driver = self end; return f end
local clock = 100
GetTime = function() return clock end
local combat = false
InCombatLockdown = function() return combat end
issecretvalue = function() return false end
UIParent = { GetEffectiveScale = function() return 0.8 end }
local cvars = { rotateMinimap = "0", minimapZoom = "0", minimapInsideZoom = "1" }
GetCVar = function(k) return cvars[k] end
local px, py = 0, 0         -- the player: world east, north (yards)
UnitPosition = function() return -px, py end      -- (y west, x north)
GetPlayerFacing = function() return 0 end
IsIndoors = function() return false end
-- the minimap: 140 wide, centre 1000, 600 in its own units, scale 0.8; dots in world yards
local MM = { cx = 1000, cy = 600, w = 140, h = 140, es = 0.8 }
local dots = {}             -- { e, n (world yards), name }
local truth = "screen"      -- how the engine reads the point
local refused = false
local point
lag, nextPoint = false, nil   -- (lag: the minimap takes the point at its next update)
local function YardsAcross() return 466 + 2 / 3 end
-- the engine's point -> radius units (x right, y up) under the true reading
local function Unread(x, y)
    local m = MM
    if truth == "screen" then return (x * 0.8 / m.es - m.cx) / (m.w / 2), (y * 0.8 / m.es - m.cy) / (m.h / 2) end
    if truth == "local" then return (x - m.w / 2) / (m.w / 2), (y - m.h / 2) / (m.h / 2) end
end
Minimap = {
    IsVisible = function() return true end, IsMouseOver = function() return false end,
    GetCenter = function() return MM.cx, MM.cy end, GetWidth = function() return MM.w end, GetHeight = function() return MM.h end,
    GetEffectiveScale = function() return MM.es end, GetZoom = function() return 0 end,
    SetUsingSoftCursor = function() end,
    UpdateMouseoverAtPoint = function(_, x, y)
        if refused then error("blocked") end
        if lag then nextPoint = { x, y } else point = { x, y } end
    end,
}
C_TooltipInfo = { GetMinimapMouseover = function()
    if not point then return nil end
    local ux, uy = Unread(point[1], point[2])
    -- (the minimap names only what it draws: nothing past its rim)
    if ux * ux + uy * uy > 1 then return { lines = {} } end
    local lines = {}
    local k = 2 / YardsAcross()
    for _, d in ipairs(dots) do
        local dx, dy = (d.e - px) * k, (d.n - py) * k
        -- (a dot's hover reach: about 4 px of a 70 px radius)
        if math.sqrt((ux - dx) ^ 2 + (uy - dy) ^ 2) <= 0.06 then lines[#lines + 1] = { leftText = d.name } end
    end
    return { lines = lines }
end }
C_SkillInfo = { GetNumSkillLines = function() return 1 end, GetSkillLineInfo = function() return { name = "Mining", rank = 180 } end }
local char = {}
local sent
local ns = { Shared = { CharDB = function() return char end },
    NodeCompass = { tracking = 1, Row = function() return { yards = 467 } end, Yards = function() return 467 end },
    HelperLink = { SetNodes = function(list) sent = list end } }
assert(loadfile(root .. "/NodeSense.lua"))("GamepadCompanion", ns)
local S = ns.NodeSense
local function Run(frames) for _ = 1, frames do clock = clock + 1 / 60; if lag and nextPoint then point = nextPoint end; driver.onUpdate(driver, 1 / 60) end end

-- Names ------------------------------------------------------------------------------------------
eq(S.Kind("Mithril Deposit", 1).kind, 6, "Mithril")
eq(S.Kind("Ooze Covered Mithril Deposit", 1).word, "mithril", "Ooze Covered: the ore under it")
eq(S.Kind("Small Thorium Vein", 1).skill, 245, "its skill")
eq(S.Kind("|TInterface\\Minimap\\Tracking\\Mining:0|t Copper Vein", 1).kind, 1, "an icon in front of the name")
eq(S.Kind("|A:Mining:16:16|a|cffffffffTin Vein|r", 1).kind, 2, "an atlas icon and a colour")
eq(S.Kind("Strange Vein", 1).kind, 0, "an ore the list doesn't know: named, kind 0")
eq(S.Kind("Alberich", 1), nil, "a player's name: no node")
eq(S.Kind("Mithril Deposit", 2), nil, "an ore while finding herbs: no")
eq(S.Kind("Khadgar's Whisker", 2).word, "khadgarswhisker", "an herb, its word")
eq(S.Kind("Khadgar's Whisker", 2).kind, 32, "herbs: kind 32")
eq(S.Kind("Chest", 3).kind, 48, "treasure")

-- Hits to dots, picks ------------------------------------------------------------------------------
local m6 = S.Kind("Mithril Deposit", 1)
local i4 = S.Kind("Iron Deposit", 1)
local hits = { { x = 0.30, y = 0.20, node = m6 }, { x = 0.35, y = 0.20, node = m6 }, { x = 0.30, y = 0.25, node = m6 },
    { x = -0.5, y = 0.1, node = i4 }, { x = 0.32, y = 0.22, node = i4 } }
local got = S.Cluster(hits)
eq(#got, 3, "three dots: a mithril (three hits), two irons")
near(got[1].x, (0.30 + 0.35 + 0.30) / 3, 1e-9, "a dot's centre: the hits' mean")
check(S.Wanted(m6, "mithril") and not S.Wanted(i4, "mithril") and S.Wanted(i4, nil) and S.Wanted(i4, "ore"), "wanted")
local picks = S.Pick(got, "iron", 2)
check(picks[1].node.word == "iron" and picks[2].node.word == "iron", "looking for iron: the irons first")

-- The slide ---------------------------------------------------------------------------------------
local ex, ey = S.Expected(0, 10, 400, false, 0)
near(ey, -0.05, 1e-9, "walking north 10 yd: a still dot slides down")
near(ex, 0, 1e-9, "not sideways")
ex, ey = S.Expected(-10, 0, 400, true, math.pi / 2)
near(ey, -0.05, 1e-9, "a rotating minimap, facing west, walking west: down too")
near(S.Agree(0, -1, 0, -2), 1, 1e-9, "the same way: agrees")
near(S.Agree(0, 1, 0, -2), -1, 1e-9, "mirrored: disagrees")
eq(S.Agree(0, 0.001, 0, -1), nil, "too small to tell")

-- The sweep: the screen reading -----------------------------------------------------------------------
dots = { { e = 60, n = 40, name = "Mithril Deposit" }, { e = -90, n = -30, name = "Iron Deposit" },
    { e = 10, n = 120, name = "Truesilver Deposit" } }
Run(600)
eq(GamepadCompanionHapticsDB.nodeSense.reading, 1, "the screen reading found (the only one with dots)")
eq(#S.dots, 3, "three dots")
local byName = {}
for _, d in ipairs(S.dots) do byName[d.node.name] = d end
local k = 2 / (466 + 2 / 3)
near(byName["Mithril Deposit"].x, 60 * k, 0.05, "the mithril where it is: x")
near(byName["Mithril Deposit"].y, 40 * k, 0.05, "and y")
eq(byName["Truesilver Deposit"].gatherable, false, "truesilver at 180 mining: not gatherable")
eq(byName["Iron Deposit"].gatherable, true, "iron: gatherable")
check(type(sent) == "table" and #sent == 3, "the row sent")
local row
for _, n in ipairs(sent) do if n.kind == 6 then row = n end end
near(row.dx, 60 * k * 127, 7, "the row: dx in radius/127")
near(row.dy, -40 * k * 127, 7, "dy downward")
check(row.wanted and row.gatherable, "looking for any: all wanted")
-- /gpc ore mithril: the others dimmed
S.Command("mithril")
eq(char.nodeWant, "mithril", "looking for mithril")
Run(120)
for _, n in ipairs(sent) do
    if n.kind == 6 then check(n.wanted, "mithril wanted") else check(not n.wanted, "the others not: " .. n.kind) end
end
S.Command("any")
eq(char.nodeWant, nil, "any again")
-- tracking off: the row goes
ns.NodeCompass.tracking = 0
Run(2)
eq(#S.dots, 0, "tracking off: no dots")
eq(sent, nil, "and no row")
ns.NodeCompass.tracking = 1
-- in a fight: no sweep
combat = true
local before = point
point = nil
Run(30)
eq(point, nil, "in a fight: nothing probed")
combat = false

-- Two mirrored readings both find dots: the slide as you walk tells them apart -----------------------
S.Forget()
truth = "local"
dots = { { e = 50, n = 60, name = "Iron Deposit" }, { e = -40, n = -70, name = "Gold Vein" },
    { e = 30, n = 220, name = "Silver Vein" }, { e = -70, n = 380, name = "Tin Vein" } }
for _ = 1, 300 do
    py = py + 2.5            -- walking north (about 2 yd/s)
    Run(70)
    if GamepadCompanionHapticsDB.nodeSense.reading then break end
end
eq(GamepadCompanionHapticsDB.nodeSense.reading, 3, "the local reading chosen, not its mirror")
local trace = table.concat(GamepadCompanionTraceDB.nodes, "\n")
check(trace:find("search (soft cursor", 1, true) ~= nil and trace:find("raw (calls", 1, true) ~= nil and trace:find("reading: local") ~= nil, "the search written down")

-- The minimap takes the point at its next update: only reads a frame later find the dots
S.Forget()
truth, lag = "screen", true
px, py = 0, 0
dots = { { e = 60, n = 40, name = "Mithril Deposit" }, { e = -90, n = -30, name = "Iron Deposit" } }
for _ = 1, 120 do
    Run(60)
    if GamepadCompanionHapticsDB.nodeSense.reading then break end
end
eq(GamepadCompanionHapticsDB.nodeSense.reading, 1, "lagging minimap: the screen reading found")
eq(GamepadCompanionHapticsDB.nodeSense.deferred, true, "read a frame later")
Run(900)
eq(#S.dots, 2, "and the dots read that way after")
lag, nextPoint = false, nil

-- The API refused: the sweep stops, written down ------------------------------------------------------
refused = true
S.Forget()
Run(200)
check(table.concat(GamepadCompanionTraceDB.nodes, "\n"):find("blocked") ~= nil, "refused: written down")
eq(#S.dots, 0, "no dots")

-- Each kind's choice (Setup > Nodes) and gatherable by the Mining skill, as the node row's slots
do
    local slots = { [6] = 5, [1] = 0, [10] = 9, [32] = 13, [48] = 14 }
    ns.HelperLink.NodeSlot = function(kind) return slots[kind] end
    eq(S.Mode(6), "show", "shown unless chosen")
    S.SetMode(6, "track")
    S.SetMode(1, "mute")
    eq(S.Mode(6), "track", "tracked")
    local p = S.PrefsFor(180)
    check(p.mode[5] == 1 and p.mode[0] == 2 and p.mode[13] == 0, "track 1, mute 2, show 0")
    check(p.gatherable[5] == true and p.gatherable[9] == false, "Mithril (175) gathered at 180, Rich Thorium (275) not")
    check(S.PrefsFor(nil).gatherable[9] == true, "no skill read: all gatherable")
    S.SetMode(6, "show")
    check(char.nodeKinds[6] == nil, "show: not stored")
    S.SetMode(1, nil)
end

io.write(("NodeSense: %d checks, %d failures\n"):format(checks, failures))
if failures > 0 then os.exit(1) end
