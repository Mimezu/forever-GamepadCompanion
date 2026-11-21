-- Flight list: at a flight master, a list beside the game's flight map of
-- every place you can fly to from here, chosen with the pad (docs/FLIGHT-LIST.md).
-- The map stays Blizzard's (TaxiFrame); it only reflects the chosen row: a
-- gold ring on that place, the route there drawn stop by stop.
--
-- The pad: the panel takes the d-pad, L1 / R1, A, B and Y as pad buttons, one
-- press at a time, on its own frame (each handled press stops there, every
-- other one passes on), out of combat only, as the Companion window does
-- (Focus.lua). No binding of anyone's is changed.
--
-- Taint: nothing of ours is written into Blizzard's frames or tables. The map
-- is read (its node buttons' places), never drawn on: the ring and the route
-- are our own regions on our own frame over it. TakeTaxiNode and
-- CloseTaxiMap are plain calls, from a press or a click.
local _, ns = ...
local Sh = ns.Shared
local FL = {}
ns.FlightList = FL

---------------------------------------------------------------------------
-- Pure (tests/FlightList.lua)
---------------------------------------------------------------------------
FL.SORTS = { near = "name", name = "near" }   -- Y: one to the other

-- "Ironforge, Dun Morogh" -> "Ironforge", "Dun Morogh"; no comma: name, nil
function FL.SplitName(name)
    name = tostring(name or "")
    local place, zone = name:match("^(.-),%s*(.+)$")
    if place and place ~= "" then return place, zone end
    return name, nil
end

-- The map's nodes through api = { count, name(i), type(i), cost(i), pos(i) -> x, y,
-- hops(i) }: here (the CURRENT node, or nil) and the places you can fly to
-- (REACHABLE only), each { index, name, place, zone, cost, x, y, hops, dist }
function FL.Read(api)
    local here, list = nil, {}
    local n = tonumber(api.count) or 0
    for i = 1, n do
        local kind = api.type(i)
        if kind == "CURRENT" or kind == "REACHABLE" then
            local name = api.name(i) or ""
            local place, zone = FL.SplitName(name)
            local x, y = api.pos(i)
            local node = { index = i, name = name, place = place, zone = zone, x = tonumber(x) or 0, y = tonumber(y) or 0 }
            if kind == "CURRENT" then here = node
            else
                node.cost = tonumber(api.cost(i)) or 0
                node.hops = math.max(1, tonumber(api.hops and api.hops(i)) or 1)
                list[#list + 1] = node
            end
        end
    end
    for _, node in ipairs(list) do
        if here then
            local dx, dy = node.x - here.x, node.y - here.y
            node.dist = math.sqrt(dx * dx + dy * dy)
        else
            node.dist = 0
        end
    end
    return here, list
end

local function ByName(a, b)
    local pa, pb = a.place:lower(), b.place:lower()
    if pa ~= pb then return pa < pb end
    return (a.zone or ""):lower() < (b.zone or ""):lower()
end

-- In place: "near" (nearest first) or "name" (A-Z); ties by name, then index
function FL.Sort(list, mode)
    table.sort(list, function(a, b)
        if mode ~= "name" and a.dist ~= b.dist then return a.dist < b.dist end
        if a.place:lower() ~= b.place:lower() or (a.zone or "") ~= (b.zone or "") then return ByName(a, b) end
        return a.index < b.index
    end)
    return list
end

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
-- Copper as coins: "1|T..Gold..|t  20|T..Silver..|t"; zero parts left out; 0: ""
function FL.Coins(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local parts = {}
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then parts[#parts + 1] = g .. COIN:format("Gold") end
    if s > 0 then parts[#parts + 1] = s .. COIN:format("Silver") end
    if c > 0 then parts[#parts + 1] = c .. COIN:format("Copper") end
    return table.concat(parts, "  ")
end

-- One row on: wrap = true goes round the ends, else stops there
function FL.Step(sel, n, delta, wrap)
    if n < 1 then return nil end
    sel = (tonumber(sel) or 1) + delta
    if wrap then return (sel - 1) % n + 1 end
    return math.max(1, math.min(n, sel))
end

-- The first row shown so sel stays in view (visible rows of n)
function FL.Scroll(offset, sel, visible, n)
    offset = tonumber(offset) or 0
    if not sel or n <= visible then return 0 end
    if sel <= offset then offset = sel - 1 end
    if sel > offset + visible then offset = sel - visible end
    return math.max(0, math.min(n - visible, offset))
end

-- The scroll thumb: top and length in a track of height px; nil when all fit
function FL.Thumb(offset, visible, n, height)
    if n <= visible or n < 1 then return nil end
    local len = math.max(16, height * visible / n)
    return (height - len) * offset / (n - visible), len
end

-- Where to start: the last place flown to from here, else the first row
function FL.Start(list, last)
    for i, node in ipairs(list) do if last and node.name == last then return i end end
    return #list > 0 and 1 or nil
end

-- A node's point on the map, from its BOTTOMLEFT (the game's own placing)
function FL.NodePoint(x, y, w, h)
    return x * w, (1 - y) * h
end

-- Smooth start and end, t in 0..1
function FL.Ease(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

-- Settings (per character, as the bag grid) ----------------------------------
function FL.Enabled() return Sh.CharDB().flightList ~= false end

-- Shown: on, in the gamepad UI only, while the flight map is open
function FL.Wanted(enabled, gamepadUI, mapShown)
    return enabled and gamepadUI == true and mapShown and true or false
end
function FL.Sorting() return Sh.CharDB().flightSort == "name" and "name" or "near" end
function FL.LastFrom(here)
    local t = Sh.CharDB().flightLast
    return here and type(t) == "table" and t[here] or nil
end
function FL.Remember(here, dest)
    if not (here and dest) then return end
    local db = Sh.CharDB()
    if type(db.flightLast) ~= "table" then db.flightLast = {} end
    db.flightLast[here] = dest
end

-- Game wiring ------------------------------------------------------------------
if not CreateFrame then return end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and Call(C_Texture.GetAtlasInfo, name) ~= nil
end

local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local INK = { 0.20, 0.12, 0.04 }
local FADED = { 0.42, 0.31, 0.18 }
local DEAR = { 0.62, 0.10, 0.04 }   -- a cost you can't pay
local GOLD = { 1.00, 0.82, 0.38 }
local ROW_H, HEAD_H, FOOT_H, WIDTH = 40, 62, 40, 260
local RING = "ChallengeMode-AffixRing-Sm"
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local GLOW = "Interface\\TaxiFrame\\UI-Taxi-Icon-Highlight"
local NUB = "Interface\\TaxiFrame\\UI-Taxi-Icon-Nub"
local HERE_ICON = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green"

local state = { here = nil, list = {}, sel = nil, offset = 0, visible = 10 }

local function Text(parent, font, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- The panel: the map's own chrome, parchment inside ---------------------------
local panel
do
    local ok, made = pcall(CreateFrame, "Frame", "GamepadCompanionFlightList", UIParent, "BasicFrameTemplateWithInset")
    panel = ok and made or CreateFrame("Frame", "GamepadCompanionFlightList", UIParent)
end
panel:Hide()
panel:SetSize(WIDTH, 608)
panel:EnableMouse(true)
if panel.TitleText then panel.TitleText:SetText("Fly to") end
if panel.CloseButton then panel.CloseButton:SetScript("OnClick", function() Call(CloseTaxiMap) end) end

local inner = CreateFrame("Frame", nil, panel)
if panel.InsetBg then
    inner:SetPoint("TOPLEFT", panel.InsetBg, "TOPLEFT")
    inner:SetPoint("BOTTOMRIGHT", panel.InsetBg, "BOTTOMRIGHT")
else
    inner:SetPoint("TOPLEFT", 8, -26)
    inner:SetPoint("BOTTOMRIGHT", -6, 6)
end

local paper = inner:CreateTexture(nil, "BACKGROUND", nil, 1)
paper:SetAllPoints()
if HasAtlas("QuestBG-Parchment") then paper:SetAtlas("QuestBG-Parchment")
else paper:SetColorTexture(0.85, 0.76, 0.58, 1) end

-- where you are: not a row
local head = CreateFrame("Frame", nil, inner)
head:SetPoint("TOPLEFT")
head:SetPoint("TOPRIGHT")
head:SetHeight(HEAD_H)
head.icon = head:CreateTexture(nil, "ARTWORK")
head.icon:SetTexture(HERE_ICON)
head.icon:SetSize(22, 22)
head.icon:SetPoint("LEFT", 12, 2)
head.place = Text(head, TITLE_FONT, 17, INK)
head.place:SetPoint("TOPLEFT", head.icon, "TOPRIGHT", 8, 4)
head.place:SetPoint("RIGHT", -12, 0)
head.zone = Text(head, BODY_FONT, 10, FADED)
head.zone:SetPoint("TOPLEFT", head.place, "BOTTOMLEFT", 0, -3)
head.zone:SetPoint("RIGHT", -12, 0)
local rule = head:CreateTexture(nil, "ARTWORK")
rule:SetHeight(1)
rule:SetPoint("BOTTOMLEFT", 12, 4)
rule:SetPoint("BOTTOMRIGHT", -12, 4)
rule:SetColorTexture(INK[1], INK[2], INK[3], 0.35)

local body = CreateFrame("Frame", nil, inner)
body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
body:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 0, FOOT_H)
body:SetClipsChildren(true)

local empty = Text(body, BODY_FONT, 12, FADED, "CENTER")
empty:SetPoint("TOP", 0, -24)
empty:SetText("No flights")

-- the scroll thumb: a thin ink line at the right edge
local track = CreateFrame("Frame", nil, body)
track:SetPoint("TOPRIGHT", -4, -2)
track:SetPoint("BOTTOMRIGHT", -4, 2)
track:SetWidth(2)
local thumb = track:CreateTexture(nil, "ARTWORK")
thumb:SetWidth(2)
thumb:SetColorTexture(INK[1], INK[2], INK[3], 0.35)

-- Rows -------------------------------------------------------------------------
local rows = {}
local Select, Fly   -- (below)

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, body)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 6, -(i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", -10, -(i - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp")
    -- the chosen row: a warm band of light fading to the right, a thin gilt edge
    r.band = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.band:SetAllPoints()
    r.band:SetColorTexture(1, 1, 1, 1)
    local faded = r.band.SetGradient and CreateColor and pcall(r.band.SetGradient, r.band, "HORIZONTAL",
        CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.55), CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.05))
    if not faded then r.band:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.35) end
    r.edge = r:CreateTexture(nil, "ARTWORK")
    r.edge:SetWidth(2)
    r.edge:SetPoint("TOPLEFT", 0, -4)
    r.edge:SetPoint("BOTTOMLEFT", 0, 4)
    r.edge:SetColorTexture(0.55, 0.36, 0.10, 0.9)
    r.place = Text(r, BODY_FONT, 13, INK)
    r.place:SetPoint("TOPLEFT", 10, -6)
    r.cost = Text(r, BODY_FONT, 11, INK, "RIGHT")
    r.cost:SetPoint("TOPRIGHT", -2, -7)
    r.place:SetPoint("RIGHT", r.cost, "LEFT", -6, 0)
    r.zone = Text(r, BODY_FONT, 10, FADED)
    r.zone:SetPoint("TOPLEFT", r.place, "BOTTOMLEFT", 0, -3)
    -- a pip per stop on the way
    r.pips = {}
    for p = 1, 4 do
        local pip = r:CreateTexture(nil, "ARTWORK")
        pip:SetTexture(NUB)
        pip:SetSize(9, 9)
        pip:SetVertexColor(INK[1], INK[2], INK[3], 0.7)
        pip:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -2 - (p - 1) * 8, 6)
        r.pips[p] = pip
    end
    r.zone:SetPoint("RIGHT", r, "RIGHT", -40, 0)
    r:SetScript("OnEnter", function(self) if self.at then Select(self.at) end end)
    r:SetScript("OnClick", function(self) if self.at then Select(self.at); Fly() end end)
    rows[i] = r
    return r
end

local function Draw()
    local list, n = state.list, #state.list
    local here = state.here
    head.place:SetText(here and here.place or "")
    head.zone:SetText(here and here.zone or "")
    empty:SetShown(n == 0)
    state.offset = FL.Scroll(state.offset, state.sel, state.visible, n)
    local money = Call(GetMoney) or 0
    for i = 1, math.max(state.visible, #rows) do
        local at = state.offset + i
        local node = i <= state.visible and list[at]
        if node then
            local r = Row(i)
            r.at = at
            r.place:SetText(node.place)
            r.zone:SetText(node.zone or "")
            r.cost:SetText(FL.Coins(node.cost))
            local c = node.cost > money and DEAR or INK
            r.cost:SetTextColor(c[1], c[2], c[3])
            for p, pip in ipairs(r.pips) do pip:SetShown(p < node.hops) end
            local on = at == state.sel
            r.band:SetShown(on)
            r.edge:SetShown(on)
            r:Show()
        elseif rows[i] then
            rows[i].at = nil
            rows[i]:Hide()
        end
    end
    local top, len = FL.Thumb(state.offset, state.visible, n, track:GetHeight() or 0)
    thumb:SetShown(top ~= nil)
    if top then
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -top)
        thumb:SetHeight(len)
    end
end

-- On the map: the ring and the route ---------------------------------------
local mapFrame     -- over TaxiRouteMap, ours: the ring
local routeFrame   -- at the map's own level: the route, under its node icons
local marker, lines, dots = nil, {}, {}
local glide = { fromX = nil, fromY = nil, toX = nil, toY = nil, t = 1 }

local function Map() return _G.TaxiRouteMap end

-- A node's point from the map's BOTTOMLEFT: where Blizzard placed its button
-- (it nudges overlapping ones apart), else from the node's own position
local function Point(index)
    local map = Map()
    local button = _G["TaxiButton" .. index]
    if button and button.GetPoint then
        local _, _, rp, x, y = Call(button.GetPoint, button, 1)
        if rp == "BOTTOMLEFT" and x and y then return x, y end
    end
    local nx, ny = Call(TaxiNodePosition, index)
    if not (nx and map) then return nil end
    return FL.NodePoint(nx, ny, map:GetWidth() or 0, map:GetHeight() or 0)
end

local function BuildMap()
    if mapFrame or not Map() then return mapFrame end
    local map = Map()
    mapFrame = CreateFrame("Frame", nil, map)
    mapFrame:SetAllPoints(map)
    mapFrame:SetFrameLevel((map:GetFrameLevel() or 1) + 20)
    mapFrame:EnableMouse(false)
    routeFrame = CreateFrame("Frame", nil, map)
    routeFrame:SetAllPoints(map)
    routeFrame:SetFrameLevel(map:GetFrameLevel() or 1)
    routeFrame:EnableMouse(false)

    marker = CreateFrame("Frame", nil, mapFrame)
    marker:SetSize(40, 40)
    marker:SetFrameLevel(mapFrame:GetFrameLevel() + 2)
    marker:EnableMouse(false)
    -- a warm glow inside, the gold ring
    marker.glow = marker:CreateTexture(nil, "ARTWORK")
    marker.glow:SetTexture(GLOW)
    marker.glow:SetSize(46, 46)
    marker.glow:SetPoint("CENTER")
    marker.glow:SetBlendMode("ADD")
    marker.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    marker.ring = marker:CreateTexture(nil, "OVERLAY")
    marker.ring:SetSize(34, 34)
    marker.ring:SetPoint("CENTER")
    if HasAtlas(RING) then
        marker.ring:SetAtlas(RING)
    else
        marker.ring:SetTexture(GLOW)
        marker.ring:SetBlendMode("ADD")
        marker.ring:SetVertexColor(1, 0.9, 0.6, 1)
    end
    -- breathing, slowly
    local breathe = marker:CreateAnimationGroup()
    breathe:SetLooping("BOUNCE")
    local grow = breathe:CreateAnimation("Scale")
    if grow.SetScaleFrom then grow:SetScaleFrom(1, 1); grow:SetScaleTo(1.12, 1.12)
    else grow:SetScale(1.12, 1.12) end
    grow:SetDuration(1.4)
    grow:SetSmoothing("IN_OUT")
    breathe:Play()
    marker.breathe = breathe

    -- (moving: the ring glides to the new place)
    marker:SetScript("OnUpdate", function(self, elapsed)
        if glide.t >= 1 then return end
        glide.t = math.min(1, glide.t + (elapsed or 0) / 0.16)
        local e = FL.Ease(glide.t)
        local x = glide.fromX + (glide.toX - glide.fromX) * e
        local y = glide.fromY + (glide.toY - glide.fromY) * e
        self:ClearAllPoints()
        self:SetPoint("CENTER", mapFrame, "BOTTOMLEFT", x, y)
    end)
    return mapFrame
end

-- the route: a dark under-line for the map's light parts, gold on it
local function Line(i)
    if lines[i] then return lines[i] end
    if not routeFrame.CreateLine then return {} end
    local under = routeFrame:CreateLine(nil, "ARTWORK", nil, 1)
    under:SetThickness(5)
    under:SetColorTexture(0.08, 0.05, 0.02, 0.55)
    local gold = routeFrame:CreateLine(nil, "ARTWORK", nil, 2)
    gold:SetThickness(2.5)
    gold:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.95)
    lines[i] = { under, gold }
    return lines[i]
end

local function Dot(i)
    if dots[i] then return dots[i] end
    local d = routeFrame:CreateTexture(nil, "ARTWORK", nil, 3)
    d:SetTexture(DISC)
    d:SetSize(7, 7)
    d:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    dots[i] = d
    return d
end

local function ClearRoute(from)
    for i = from, #lines do lines[i][1]:Hide(); lines[i][2]:Hide() end
    for i = from, #dots do dots[i]:Hide() end
end

local function DrawMap(instant)
    if not BuildMap() then return end
    local node = state.sel and state.list[state.sel]
    if not node then marker:Hide(); ClearRoute(1); return end
    local x, y = Point(node.index)
    if not x then marker:Hide(); ClearRoute(1); return end
    -- the ring glides from where it was
    if instant or not marker:IsShown() or not glide.toX then
        glide.fromX, glide.fromY, glide.t = x, y, 1
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", mapFrame, "BOTTOMLEFT", x, y)
    else
        local e = FL.Ease(glide.t)
        glide.fromX = glide.fromX + (glide.toX - glide.fromX) * e
        glide.fromY = glide.fromY + (glide.toY - glide.fromY) * e
        glide.t = 0
    end
    glide.toX, glide.toY = x, y
    marker:Show()
    -- the route, stop by stop
    local n = tonumber(Call(GetNumRoutes, node.index)) or 0
    local drawn = 0
    for r = 1, n do
        local a, b = Call(TaxiGetNodeSlot, node.index, r, true), Call(TaxiGetNodeSlot, node.index, r, false)
        local ax, ay = Point(a or 0)
        local bx, by = Point(b or 0)
        if ax and bx then
            drawn = drawn + 1
            for _, l in ipairs(Line(drawn)) do
                l:SetStartPoint("BOTTOMLEFT", routeFrame, ax, ay)
                l:SetEndPoint("BOTTOMLEFT", routeFrame, bx, by)
                l:Show()
            end
            local d = Dot(drawn)
            d:ClearAllPoints()
            d:SetPoint("CENTER", routeFrame, "BOTTOMLEFT", bx, by)
            d:SetShown(r < n)   -- (a stop; the end has the ring)
        end
    end
    ClearRoute(drawn + 1)
end

-- Choosing and flying ---------------------------------------------------------
function Select(at)
    if not state.list[at] or at == state.sel then return end
    state.sel = at
    Draw()
    DrawMap(false)
end

function Fly()
    local node = state.sel and state.list[state.sel]
    if not node or InCombat() then return end
    FL.Remember(state.here and state.here.name, node.name)
    Call(TakeTaxiNode, node.index)
end

local function Move(delta, wrap)
    local n = #state.list
    if n == 0 then return end
    Select(FL.Step(state.sel or 0, n, delta, wrap))
end

local function Resort()
    local cur = state.sel and state.list[state.sel]
    FL.Sort(state.list, FL.Sorting())
    state.sel = nil
    for i, node in ipairs(state.list) do if node == cur then state.sel = i end end
    state.sel = state.sel or FL.Start(state.list)
end

-- The legend (Blizzard's glyphs, as the bank's bar) -------------------------
local legend, sortPrompt
local function Legend()
    if legend ~= nil then return legend or nil end
    legend = false
    local L = _G.InputPromptLegends
    if not (L and L.CreateInputLegend) then return nil end
    local ok, made = pcall(function()
        local l = L.CreateInputLegend(inner, "legend")
        local divider = _G.GAMEPAD_PROMPT_DIVIDER_SLASH or "SLASH"
        for _, a in ipairs({
            { "PAD1", "Fly" },
            { "PAD2", type(_G.FRAME_ACTION_CLOSE) == "string" and _G.FRAME_ACTION_CLOSE or "Close" },
            { "PAD4", "A-Z" },
        }) do
            local prompt = l:GetOrCreatePromptFrameUsingTemplateAndInputs("StandardOneIcon", { a[1] }, divider)
            prompt:SetPromptText(a[2])
            prompt:EnablePrompt()
            prompt:Show()
            if a[1] == "PAD4" then sortPrompt = prompt end
        end
        l:ApplyDefaultPromptPositioning()
        l:ClearAllPoints()
        l:SetPoint("BOTTOM", inner, "BOTTOM", 0, 8)
        return l
    end)
    if ok and made then legend = made end
    return legend or nil
end

-- (gamepad mode only: unknown counts as off)
local function GamepadUI()
    local util = _G.InputUtil
    return util and util.IsGamepadUIEnabled and Call(util.IsGamepadUIEnabled) == true or false
end

local function LegendText()
    local l = Legend()
    if not (l and sortPrompt) then return end
    l:Show()
    Call(sortPrompt.SetPromptText, sortPrompt, FL.Sorting() == "near" and "A-Z" or "Nearest")
    Call(l.ApplyDefaultPromptPositioning, l)
    l:ClearAllPoints()
    l:SetPoint("BOTTOM", inner, "BOTTOM", 0, 8)
end

-- The pad -------------------------------------------------------------------------
local hold = { key = nil, wait = 0 }
local REPEAT = { PADDUP = -1, PADDDOWN = 1 }

local ACTIONS = {
    PADDUP = function() Move(-1, true) end,
    PADDDOWN = function() Move(1, true) end,
    PADLSHOULDER = function() Move(-state.visible, false) end,
    PADRSHOULDER = function() Move(state.visible, false) end,
    PADDLEFT = function() if #state.list > 0 then Select(1) end end,
    PADDRIGHT = function() if #state.list > 0 then Select(#state.list) end end,
    PAD1 = function() Fly() end,
    PAD2 = function() Call(CloseTaxiMap) end,
    PAD4 = function()
        Sh.CharDB().flightSort = FL.SORTS[FL.Sorting()]
        Resort()
        state.offset = 0
        Draw()
        DrawMap(true)
        LegendText()
    end,
}
FL.ACTIONS = ACTIONS

local function Take(on)
    if on and InCombat() then on = false end
    if on then Call(panel.SetPropagateKeyboardInput, panel, true) end
    Call(panel.EnableGamePadButton, panel, on)
end

panel:SetScript("OnGamePadButtonDown", function(self, button)
    if InCombat() then return end
    local act = ACTIONS[button]
    if not act then return end
    -- (this press stops here; from the next frame on, presses pass again)
    Call(self.SetPropagateKeyboardInput, self, false)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() if not InCombat() then Call(self.SetPropagateKeyboardInput, self, true) end end)
    end
    act()
    -- held up / down: on after a breath, stopping at the ends (no wrap)
    if REPEAT[button] then hold.key, hold.wait = button, 0.38 else hold.key = nil end
end)

panel:SetScript("OnUpdate", function(_, elapsed)
    if not hold.key then return end
    local down = Sh.PadDown(Sh.PadButtons(), hold.key)
    if not down or InCombat() then hold.key = nil; return end
    hold.wait = hold.wait - (elapsed or 0)
    if hold.wait > 0 then return end
    hold.wait = 0.075
    Move(REPEAT[hold.key], false)
end)

-- Open / close ---------------------------------------------------------------------
local openedAt = 0

local function Api()
    return {
        count = Call(NumTaxiNodes) or 0,
        name = function(i) return Call(TaxiNodeName, i) end,
        type = function(i) return Call(TaxiNodeGetType, i) end,
        cost = function(i) return Call(TaxiNodeCost, i) end,
        pos = function(i) return Call(TaxiNodePosition, i) end,
        hops = function(i) return Call(GetNumRoutes, i) end,
    }
end

local function Layout(taxi)
    if panel:GetParent() ~= taxi then panel:SetParent(taxi) end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", taxi, "TOPRIGHT", -2, 0)
    panel:SetHeight(taxi:GetHeight() or 608)
    panel:SetFrameLevel((taxi:GetFrameLevel() or 1) + 5)
    local tall = inner:GetHeight() or 0
    if tall < 1 then tall = (panel:GetHeight() or 608) - 30 end
    local h = tall - HEAD_H - FOOT_H - 2
    state.visible = math.max(3, math.floor(h / ROW_H))
end

function FL.Open()
    local taxi = _G.TaxiFrame
    if not FL.Wanted(FL.Enabled(), GamepadUI(), taxi and taxi:IsShown()) then return FL.Close() end
    Layout(taxi)
    state.here, state.list = FL.Read(Api())
    FL.Sort(state.list, FL.Sorting())
    state.sel = FL.Start(state.list, FL.LastFrom(state.here and state.here.name))
    state.offset = 0
    openedAt = GetTime and GetTime() or 0
    panel:Show()
    -- (out of combat: Blizzard's cursor kept off our rows; the d-pad is ours)
    if not InCombat() and type(SmartNavigation_MarkFrameIgnored) == "function" then
        pcall(SmartNavigation_MarkFrameIgnored, panel)
    end
    Take(true)
    Draw()
    DrawMap(true)
    LegendText()
end

function FL.Close()
    Take(false)
    hold.key = nil
    panel:Hide()
    if marker then marker:Hide() end
    if mapFrame then ClearRoute(1) end
end

function FL.SetEnabled(on)
    Sh.CharDB().flightList = on and true or false
    if on then FL.Open() else FL.Close() end
end

-- The map's own hover (mouse or Blizzard's cursor) chooses the row too
if type(hooksecurefunc) == "function" and type(_G.TaxiNodeOnButtonEnter) == "function" then
    hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
        if not panel:IsShown() or (GetTime and GetTime() - openedAt < 0.4) then return end
        local index = button and button.GetID and button:GetID()
        for i, node in ipairs(state.list) do if node.index == index then Select(i); return end end
    end)
end

local hooked = false
local function Hook()
    local taxi = _G.TaxiFrame
    if hooked or not (taxi and taxi.HookScript) then return end
    hooked = true
    taxi:HookScript("OnShow", function() if C_Timer and C_Timer.After then C_Timer.After(0, FL.Open) else FL.Open() end end)
    taxi:HookScript("OnHide", FL.Close)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_MONEY" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    Hook()
    if event == "PLAYER_REGEN_DISABLED" then Take(false); hold.key = nil
    elseif event == "PLAYER_REGEN_ENABLED" then if panel:IsShown() then Take(true) end
    elseif event == "TAXIMAP_CLOSED" then FL.Close()
    elseif event == "PLAYER_MONEY" then if panel:IsShown() then Draw() end
    elseif event == "TAXIMAP_OPENED" and not panel:IsShown() then
        if C_Timer and C_Timer.After then C_Timer.After(0, FL.Open) else FL.Open() end
    end
end)
