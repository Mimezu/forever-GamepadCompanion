-- Edit Mode spots: Companion's small frames that sit anywhere (the lure float, the flight's
-- passage, the meal's), each with its own box in Edit Mode, in Edit Mode's colours as the bar
-- boxes (EditModeBars.lua): blue while waiting, gold once picked, the name on it. Drag one to
-- move it, right-click puts it home, the arrows and the d-pad nudge the picked one. Boxes on
-- top of each other: a click (no drag) brings the next one under the cursor to the front, so
-- any one of them can be picked and dragged ("Click: the one under" shows while two or more
-- are under the cursor). Edit Mode listened to (EventRegistry), never hooked; picking one lets
-- Blizzard's pick and the bars' go. Pure: S.Under, S.Next (tests/EditSpots.lua)
local _, ns = ...
local S = { spots = {} }
ns.EditSpots = S

-- The spots whose rect holds x, y, front first. spots: { { rect = { l, b, r, t }, level } }
function S.Under(spots, x, y)
    local list = {}
    for _, s in ipairs(spots) do
        local r = s.rect
        if r and x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then list[#list + 1] = s end
    end
    table.sort(list, function(a, b) return (a.level or 0) > (b.level or 0) end)
    return list
end

-- The one after current in list (wrapping), or the first
function S.Next(list, current)
    for i, s in ipairs(list) do
        if s == current then return list[i % #list + 1] end
    end
    return list[1]
end

if not CreateFrame then return end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function Combat() return InCombatLockdown and InCombatLockdown() end

local BLUE, GOLD = { 0.25, 0.6, 1 }, { 1, 0.82, 0.2 }
local NUDGE = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 },
    PADDUP = { 0, 1 }, PADDDOWN = { 0, -1 }, PADDLEFT = { -1, 0 }, PADDRIGHT = { 1, 0 } }
local BASE_LEVEL = 50
local selected, front = nil, 0

local function Paint(box, c, fill)
    box.fill:SetColorTexture(c[1], c[2], c[3], fill)
    for _, e in ipairs(box.edges) do e:SetColorTexture(c[1], c[2], c[3], 0.95) end
end

local function Rect(spot)
    local f = spot.frame
    local l, b, w, h = Call(f.GetLeft, f), Call(f.GetBottom, f), Call(f.GetWidth, f), Call(f.GetHeight, f)
    if not (l and b and w and h) then return nil end
    return { l, b, l + w, b + h }
end

-- The cursor in UIParent units
local function Cursor()
    local x, y = Call(GetCursorPosition)
    local scale = Call(UIParent.GetEffectiveScale, UIParent) or 1
    if not (x and y) then return nil end
    return x / scale, y / scale
end

-- The shown spots under the cursor, front first
local function UnderCursor()
    local x, y = Cursor()
    if not x then return {} end
    local list = {}
    for _, spot in ipairs(S.spots) do
        if spot.box:IsShown() then
            list[#list + 1] = { rect = Rect(spot), level = spot.box:GetFrameLevel(), spot = spot }
        end
    end
    local under = S.Under(list, x, y)
    for i, u in ipairs(under) do under[i] = u.spot end
    return under
end

local function Raise(spot)
    front = front + 1
    spot.box:SetFrameLevel(BASE_LEVEL + front)
end

local Refresh
local function Select(spot)
    selected = spot
    if spot then
        Raise(spot)
        -- (Blizzard's pick and the bars' let go)
        local manager = EditModeManagerFrame
        if manager and manager.ClearSelectedSystem then pcall(manager.ClearSelectedSystem, manager) end
        if ns.EditModeBars and ns.EditModeBars.Selected and ns.EditModeBars.Selected() then pcall(ns.EditModeBars.Select, nil) end
    end
    Refresh()
end
S.Select = function(name) for _, s in ipairs(S.spots) do if s.name == name then return Select(s) end end; Select(nil) end
function S.Selected() return selected and selected.name or nil end

-- The spot's frame where its owner puts it (from its saved spot)
local function Place(spot)
    local x, y = spot.get()
    spot.frame:ClearAllPoints()
    spot.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function Save(spot)
    local x, y = Call(spot.frame.GetLeft, spot.frame), Call(spot.frame.GetBottom, spot.frame)
    if x and y then spot.set(math.floor(x + 0.5), math.floor(y + 0.5)) end
    Place(spot)
end

local function Box(spot)
    local box = CreateFrame("Frame", nil, UIParent)
    box:SetFrameStrata("HIGH")
    box:SetFrameLevel(BASE_LEVEL)
    box:SetAllPoints(spot.frame)
    box:EnableMouse(true)
    if box.RegisterForDrag then box:RegisterForDrag("LeftButton") end
    box:Hide()
    box.fill = box:CreateTexture(nil, "BACKGROUND")
    box.fill:SetAllPoints()
    box.edges = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
        { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local e = box:CreateTexture(nil, "BORDER")
        e:SetPoint(p[1]); e:SetPoint(p[2])
        if i <= 2 then e:SetHeight(2) else e:SetWidth(2) end
        box.edges[i] = e
    end
    box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    box.label:SetPoint("CENTER", box, "CENTER", 0, 4)
    box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.hint:SetPoint("TOP", box.label, "BOTTOM", 0, -2)
    box:SetScript("OnDragStart", function()
        if Combat() then return end
        Select(spot)
        box.dragged = true
        spot.frame:SetMovable(true)
        spot.frame:StartMoving()
    end)
    box:SetScript("OnDragStop", function()
        spot.frame:StopMovingOrSizing()
        Save(spot)
    end)
    box:SetScript("OnMouseDown", function() box.dragged = false end)
    box:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            spot.set(nil, nil)
            Place(spot)
            return Select(spot)
        end
        if box.dragged then box.dragged = false; return end
        -- (a click: on top of others, the next one under the cursor comes to the front)
        local under = UnderCursor()
        if #under > 1 and selected == spot then return Select(S.Next(under, spot)) end
        Select(spot)
    end)
    box:SetScript("OnEnter", function() box.over = true; Refresh() end)
    box:SetScript("OnLeave", function() box.over = false; Refresh() end)
    return box
end

-- The arrows and the d-pad nudge the picked one (Shift: 1, else 10, as the bars); Escape lets
-- it go before Edit Mode itself closes; every other key goes on to the game
local keys = CreateFrame("Frame", nil, UIParent)
keys:Hide()
local function Press(self, key)
    local n = NUDGE[key]
    local mine = (n ~= nil and selected ~= nil) or (key == "ESCAPE" and selected ~= nil)
    if self.SetPropagateKeyboardInput and not Combat() then pcall(self.SetPropagateKeyboardInput, self, not mine) end
    if not mine or Combat() then return end
    if key == "ESCAPE" then return Select(nil) end
    local step = (IsShiftKeyDown and IsShiftKeyDown()) and 1 or 10
    local x, y = selected.get()
    selected.set(x + n[1] * step, y + n[2] * step)
    Place(selected)
end
S.Press = Press
keys:SetScript("OnKeyDown", Press)
keys:SetScript("OnGamePadButtonDown", Press)

-- Each box shown over its shown frame, painted, named, the hint where boxes overlap
Refresh = function()
    local under = S.active and UnderCursor() or {}
    for _, spot in ipairs(S.spots) do
        local box = spot.box
        local on = S.active and spot.frame:IsShown()
        box:SetShown(on)
        if on then
            local picked = selected == spot
            Paint(box, picked and GOLD or BLUE, picked and 0.3 or 0.18)
            box.label:SetText((picked or box.over) and spot.label or "")
            box.hint:SetText((box.over and #under > 1 and under[1] == spot) and "Click: the one under" or "")
        end
    end
    local listen = S.active and selected ~= nil
    if listen ~= keys:IsShown() and not Combat() then
        keys:SetShown(listen)
        pcall(keys.EnableKeyboard, keys, listen)
        if keys.EnableGamePadButton then pcall(keys.EnableGamePadButton, keys, listen) end
    end
end
S.Refresh = Refresh

-- A spot: { name, label, frame, get() -> x, y (UIParent units, bottom-left), set(x, y) (nil:
-- home) }. Its owner shows the frame (a sample) in Edit Mode; the box follows
function S.Add(spot)
    spot.box = Box(spot)
    S.spots[#S.spots + 1] = spot
    return spot
end
S.Place = Place

-- (while Edit Mode is open: the boxes follow their frames, shown or not)
local watch = CreateFrame("Frame")
watch:Hide()
local since = 0
watch:SetScript("OnUpdate", function(_, elapsed)
    since = since + (elapsed or 0)
    if since < 0.1 then return end
    since = 0
    Refresh()
end)
function S.EditMode(on)
    S.active = on == true
    if not S.active then selected = nil end
    watch:SetShown(S.active)
    Refresh()
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", function() S.EditMode(true) end, S)
    EventRegistry:RegisterCallback("EditMode.Exit", function() S.EditMode(false) end, S)
end
