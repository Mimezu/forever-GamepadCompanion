-- The Gestures tab: what each gesture runs, as a grid of cards that fills the
-- page, and a status column. Only the gestures that exist show: recorded in
-- WoW Helper (its data addon names them, and may describe them: a few words
-- and a motion path) or already given an action here. A card: the motion
-- (its path drawn, else the Gestures glyph), its name, what it is, and the
-- action on a plate (Choose); a quiet × on hover. The last card points to
-- WoW Helper to record one more. The status column: the link, how many, the
-- helper's mode, and the last gesture that ran (on the gesture's own click,
-- no polling). The key chord WoW Helper presses stays in the tooltip.
local _, ns = ...
local S, Shell, HUI = ns.OptionsSkin, ns.Shell, ns.HapticsUI
local W, PH = Shell.W, Shell.H

local ui = { cards = {} }
local ACCEPTS = ns.TouchModel.ACCEPTS
local GLYPH = "Interface\\AddOns\\GamepadCompanion\\Media\\tab-gestures"
local GAP, STATUS_W, COLS = 14, 250, 3
local GRID_W = W - STATUS_W - GAP
local CARD_W = math.floor((GRID_W - (COLS - 1) * GAP) / COLS)
local CARD_H = 140              -- (the cards share the page's height: Place)
local TALL = 190                -- taller than this: the motion large, above the name
local PATH_SEGMENTS = 24

-- "wave" -> "Wave", "sit down" -> "Sit Down"
local function Title(s)
    return (tostring(s):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end
ui.Title = Title

-- What WoW Helper says of a slot: { name, mode, desc, path } (nil: nothing)
local function Recorded(slot)
    local C = ns.HelperCues
    return C and type(C.Gesture) == "function" and C.Gesture(slot) or nil
end

-- The gestures to show, in slot order: recorded, or with an action
function ui.Shown()
    local G = ns.Gestures
    local list = {}
    for slot = 1, G.SLOTS do
        local rec = Recorded(slot)
        if rec or G.Get(slot) then
            list[#list + 1] = { slot = slot, name = Title(rec and rec.name or G.Label(slot)), rec = rec }
        end
    end
    return list
end

-- A motion path, drawn as lines in its box (points 0-1, y down); false when
-- the client can't draw lines or there is no path
local function DrawPath(card, path)
    local box = card.glyphBox
    for _, l in ipairs(card.lines) do l:Hide() end
    for _, l in ipairs(card.arrow) do l:Hide() end
    card.start:Hide()
    if type(path) ~= "table" or #path < 2 or type(box.CreateLine) ~= "function" then return false end
    -- (a long path: every n-th point, so it fits the pool)
    local step = math.max(1, math.ceil((#path - 1) / PATH_SEGMENTS))
    local pts = {}
    for i = 1, #path, step do pts[#pts + 1] = path[i] end
    if pts[#pts] ~= path[#path] then pts[#pts + 1] = path[#path] end
    local size, pad = box:GetWidth() or 56, 6
    local function At(p)
        local x, y = tonumber(p[1] or p.x) or 0, tonumber(p[2] or p.y) or 0
        return pad + math.max(0, math.min(1, x)) * (size - 2 * pad), -(pad + math.max(0, math.min(1, y)) * (size - 2 * pad))
    end
    for i = 1, #pts - 1 do
        local l = card.lines[i]
        if not l then
            l = box:CreateLine(nil, "ARTWORK")
            if type(l) ~= "table" then return false end
            l:SetThickness(2.5)
            l:SetColorTexture(1, 1, 0.75, 0.95)
            card.lines[i] = l
        end
        local x0, y0 = At(pts[i])
        local x1, y1 = At(pts[i + 1])
        l:SetStartPoint("TOPLEFT", box, x0, y0)
        l:SetEndPoint("TOPLEFT", box, x1, y1)
        l:Show()
    end
    -- (an arrow at the end: two short strokes back along the last segment)
    local ex, ey = At(pts[#pts])
    local px, py = At(pts[#pts - 1])
    local dx, dy = ex - px, ey - py
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.01 then
        dx, dy = dx / len, dy / len
        local head = math.max(6, size / 10)
        for k, a in ipairs({ 0.5, -0.5 }) do
            local l = card.arrow[k]
            if not l then
                l = box:CreateLine(nil, "ARTWORK")
                if type(l) ~= "table" then break end
                l:SetThickness(2.5)
                l:SetColorTexture(1, 1, 0.75, 0.95)
                card.arrow[k] = l
            end
            local c, s = math.cos(math.pi - a), math.sin(math.pi - a)
            local bx, by = dx * c - dy * s, dx * s + dy * c
            l:SetStartPoint("TOPLEFT", box, ex, ey)
            l:SetEndPoint("TOPLEFT", box, ex + bx * head, ey + by * head)
            l:Show()
        end
    end
    local sx, sy = At(pts[1])
    card.start:ClearAllPoints()
    card.start:SetPoint("CENTER", box, "TOPLEFT", sx, sy)
    card.start:Show()
    return true
end

local function Pick(card)
    local G = ns.Gestures
    local slot = card.slot
    ns.Picker.Open({ title = card.name:GetText() or G.Label(slot), accepts = ACCEPTS, current = G.Get(slot),
        onPick = function(action) G.Set(slot, action); ui.Refresh() end })
end

local function Card(parent, i)
    local card = S.Card(parent, nil, 0, 0, CARD_W, CARD_H)
    card:EnableMouse(true)
    -- the motion: a box, its path or the glyph
    card.glyphBox = CreateFrame("Frame", nil, card)
    card.glyphBox:SetSize(56, 56)
    local well = card.glyphBox:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints()
    well:SetColorTexture(0, 0, 0, 0.25)
    card.glyph = card.glyphBox:CreateTexture(nil, "ARTWORK")
    -- (no path: a quiet dot, the motion's start)
    card.glyph:SetPoint("CENTER")
    card.glyph:SetSize(12, 12)
    card.glyph:SetColorTexture(1, 1, 0.75, 0.4)
    if card.glyphBox.CreateMaskTexture and card.glyph.AddMaskTexture then
        local mask = card.glyphBox:CreateMaskTexture()
        if mask then mask:SetAtlas("CircleMask"); mask:SetAllPoints(card.glyph); card.glyph:AddMaskTexture(mask) end
    end
    card.lines, card.arrow = {}, {}
    card.start = card.glyphBox:CreateTexture(nil, "OVERLAY")
    card.start:SetSize(7, 7)
    card.start:SetColorTexture(0.43, 0.78, 0.55, 1)
    -- its name and what it is
    card.name = S.Text(card, "", 0, 0, CARD_W - 82 - 34, 14, S.YELLOW)
    card.name:SetWordWrap(false)
    card.desc = S.Text(card, "", 0, 0, CARD_W - 82 - 14, 11, S.GREY)
    card.desc:SetWordWrap(false)
    -- the action, on its plate, at the foot
    card.pick = S.NewButton(card, "", 14, 0, CARD_W - 28, function() Pick(card) end, nil, 12, 40)

    card.pick.icon = card.pick:CreateTexture(nil, "OVERLAY")
    card.pick.icon:SetSize(26, 26)
    card.pick.icon:SetPoint("LEFT", 8, 0)
    card.pick.label:ClearAllPoints()
    card.pick.label:SetPoint("LEFT", 42, 0)
    card.pick.label:SetPoint("RIGHT", -8, 0)
    card.pick.label:SetJustifyH("LEFT")
    -- a quiet ×, on hover
    card.clear = S.NewButton(card, "×", CARD_W - 32, -10, 24, function()
        ns.Gestures.Set(card.slot, nil); ui.Refresh()
    end, nil, 14, 22)
    S.Tooltip(card.clear, "Clear")
    card.clear:SetAlpha(0)
    local function Hover(on)
        card.clear:SetAlpha(on and card.action and 1 or 0)
    end
    for _, f in ipairs({ card, card.pick, card.clear }) do
        f:HookScript("OnEnter", function() Hover(true) end)
        f:HookScript("OnLeave", function() Hover(card:IsMouseOver()) end)
    end
    card:Hide()
    return card
end

-- A card's parts for its height: short, the motion beside the name; tall,
-- the motion large and the name under it, the block centred above the plate
local function Layout(card, h)
    local box, name, desc, pick = card.glyphBox, card.name, card.desc, card.pick
    box:ClearAllPoints(); name:ClearAllPoints(); desc:ClearAllPoints(); pick:ClearAllPoints()
    if h <= TALL then
        pick:SetPoint("BOTTOMLEFT", 14, 14)
        box:SetSize(56, 56)
        box:SetPoint("TOPLEFT", 14, -14)
        name:SetPoint("TOPLEFT", 82, -20); name:SetWidth(CARD_W - 82 - 34); name:SetJustifyH("LEFT")
        desc:SetPoint("TOPLEFT", 82, -42); desc:SetWidth(CARD_W - 82 - 14); desc:SetJustifyH("LEFT")
        return
    end
    -- (the motion, the name, what it is and the plate: one block, centred)
    local g = math.max(56, math.min(200, h - 230))
    local block = g + 14 + 18 + 6 + 14 + 22 + 40
    local top = math.floor((h - block) / 2)
    box:SetSize(g, g)
    box:SetPoint("TOP", 0, -math.max(20, top))
    name:SetPoint("TOP", box, "BOTTOM", 0, -14); name:SetWidth(CARD_W - 40); name:SetJustifyH("CENTER")
    desc:SetPoint("TOP", name, "BOTTOM", 0, -6); desc:SetWidth(CARD_W - 28); desc:SetJustifyH("CENTER")
    pick:SetPoint("TOP", desc, "BOTTOM", 0, -22)
end

-- Every shown card (the record card too) sharing the grid's height
local function Place(cards)
    local rows = math.max(1, math.ceil(#cards / COLS))
    local h = math.floor((PH - (rows - 1) * GAP) / rows)
    for i, card in ipairs(cards) do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", col * (CARD_W + GAP), -row * (h + GAP))
        card:SetSize(CARD_W, h)
        if card.glyphBox then Layout(card, h) end
    end
    return h
end
ui.Place = Place

-- One more: where gestures are recorded
local function RecordCard(parent)
    local card = S.Card(parent, nil, 0, 0, CARD_W, CARD_H)
    local plus = S.Text(card, "+", 0, 0, CARD_W, 28, S.GOLD)
    plus:ClearAllPoints(); plus:SetPoint("CENTER", 0, 16); plus:SetJustifyH("CENTER")
    local t = S.Text(card, "Record in WoW Helper", 0, 0, CARD_W - 20, 13, S.GOLD)
    t:ClearAllPoints(); t:SetPoint("TOP", plus, "BOTTOM", 0, -6); t:SetJustifyH("CENTER")
    card:SetAlpha(0.6)
    return card
end

local function StatusRow(card, label, y)
    S.Text(card, label, 14, y, 90, 12, S.GREY)
    local v = S.Text(card, "", 104, y, STATUS_W - 118, 12, S.GOLD)
    v:SetJustifyH("RIGHT")
    v:SetWordWrap(false)
    return v
end

-- The last gestures that ran, newest first (the newest bright, the rest quieter)
local function RefreshLast()
    local G = ns.Gestures
    local s = ui.status
    if not (G and s) then return end
    local recent = G.recent or {}
    s.none:SetShown(#recent == 0)
    local now = GetTime and GetTime() or 0
    for i, r in ipairs(s.recent) do
        local e = recent[i]
        r:SetShown(e ~= nil)
        if e then
            local rec = Recorded(e.slot)
            r.name:SetText(Title(rec and rec.name or G.Label(e.slot)))
            local action = G.Get(e.slot)
            local _, icon
            if action and ns.Touch then _, icon = ns.Touch.ActionLook(action) end
            r.icon:SetTexture(icon or GLYPH)
            r.ago:SetText(HUI.Ago(now - e.at))
            r:SetAlpha(i == 1 and 1 or 0.65)
        end
    end
    s.lastName = s.recent[1].name
end
ui.RefreshLast = RefreshLast

local function Refresh()
    local G = ns.Gestures
    if not (G and ui.grid) then return end
    local list = ui.Shown()
    for i, card in ipairs(ui.cards) do
        local g = list[i]
        card:SetShown(g ~= nil)
        if g then
            card.slot = g.slot
            local action = G.Get(g.slot)
            card.action = action
            local name, icon
            if action and ns.Touch then name, icon = ns.Touch.ActionLook(action) end
            card.name:SetText(g.name)
            local rec = g.rec or {}
            -- (what it is: WoW Helper's words and its mode; Not ready, calmly)
            local desc = rec.desc or ""
            if rec.mode then desc = desc ~= "" and (desc .. "  ·  " .. Title(rec.mode)) or Title(rec.mode) end
            if rec.ready == false then desc = "Not ready" end
            -- (words that only repeat the name say nothing)
            if desc:lower() == g.name:lower() then desc = "" end
            card.desc:SetText(desc)
            -- (a lone typed command by its name: /sit -> Sit)
            local command = action and action:match("^text:/([%a]+)%s*$")
            if command then name = Title(command) end
            card.pick:SetAlpha(action and 1 or 0.7)
            card.pick.icon:SetTexture(icon or "Interface\\AddOns\\GamepadCompanion\\Media\\tab-controller")
            card.pick.icon:SetDesaturated(action == nil)
            card.pick.icon:SetAlpha(action and 1 or 0.5)
            card.pick.label:SetText(action and (name or action) or "Choose")
            if action then card.pick.label:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
            else card.pick.label:SetTextColor(S.GREY[1], S.GREY[2], S.GREY[3]) end
            S.Tooltip(card.pick, g.name, (G.IsPending() and "After combat · " or "") .. "Ctrl Shift Alt F" .. g.slot)
            card.clear:SetAlpha(action and card:IsMouseOver() and 1 or 0)
        end
    end
    local n = #list
    -- the record card after the last (none when every slot is taken); the
    -- cards share the page's height, so the grid is never half empty
    local free = n < G.SLOTS
    ui.record:SetShown(free and n > 0)
    local placed = {}
    for i = 1, n do placed[i] = ui.cards[i] end
    if free and n > 0 then placed[#placed + 1] = ui.record end
    ui.cardH = Place(placed)
    for i = 1, n do
        local g = list[i]
        ui.cards[i].glyph:SetShown(not DrawPath(ui.cards[i], (g.rec or {}).path))
    end
    ui.empty:SetShown(n == 0)
    -- status
    local s = ui.status
    local K, C = ns.HelperLink, ns.HelperCues
    local linked = K and K.Enabled()
    local data = C and C.Data and C.Data()
    s.link:SetText(linked and (data and "Linked" or "Linked · no data") or "Off")
    s.dot:SetColorTexture(linked and 0.35 or 0.5, linked and 0.85 or 0.5, linked and 0.4 or 0.5, 1)
    s.count:SetText(n .. " of " .. G.SLOTS)
    local on = C and C.GesturesEnabled and C.GesturesEnabled()
    s.mode:SetText(on == true and "On" or on == false and "Off" or "—")
    RefreshLast()
end

local function Build(frame)
    local G = ns.Gestures
    if not G then return end
    ui.grid = CreateFrame("Frame", nil, frame)
    ui.grid:SetPoint("TOPLEFT", 0, 0)
    ui.grid:SetSize(GRID_W, PH)
    for i = 1, G.SLOTS do ui.cards[i] = Card(ui.grid, i) end
    ui.record = RecordCard(ui.grid)
    -- the empty state: the whole grid, calm
    ui.empty = S.Card(ui.grid, nil, 0, 0, GRID_W, PH)
    local glyph = ui.empty:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(GLYPH)
    glyph:SetSize(72, 72)
    glyph:SetPoint("CENTER", 0, 40)
    glyph:SetAlpha(0.7)
    local title = S.Text(ui.empty, "No gestures yet", 0, 0, GRID_W, 15, S.GOLD)
    title:ClearAllPoints(); title:SetPoint("TOP", glyph, "BOTTOM", 0, -14); title:SetJustifyH("CENTER")
    local hint = S.Text(ui.empty, "Record them in WoW Helper › Gestures", 0, 0, GRID_W, 12, S.GREY)
    hint:ClearAllPoints(); hint:SetPoint("TOP", title, "BOTTOM", 0, -8); hint:SetJustifyH("CENTER")
    ui.empty:Hide()
    -- the status column
    local s = S.Card(frame, "WoW Helper", GRID_W + GAP, 0, STATUS_W, PH)
    ui.status = s
    s.link = StatusRow(s, "Link", -48)
    s.dot = s:CreateTexture(nil, "ARTWORK")
    s.dot:SetSize(8, 8)
    s.dot:SetPoint("TOPLEFT", 50, -51)
    s.count = StatusRow(s, "Gestures", -74)
    s.mode = StatusRow(s, "Recognition", -100)
    S.Heading(s, "Last gestures", 12, -136, STATUS_W - 24)
    s.none = S.Text(s, "None yet", 14, -164, STATUS_W - 28, 12, S.DIM)
    s.recent = {}
    for i = 1, G.RECENT do
        local r = CreateFrame("Frame", nil, s)
        r:SetPoint("TOPLEFT", 12, -158 - (i - 1) * 40)
        r:SetSize(STATUS_W - 24, 36)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(28, 28)
        r.icon:SetPoint("LEFT", 2, 0)
        r.name = S.Text(r, "", 38, -10, STATUS_W - 24 - 38 - 50, 13, S.YELLOW)
        r.name:SetWordWrap(false)
        r.ago = S.Text(r, "", STATUS_W - 24 - 50, -11, 48, 11, S.GREY)
        r.ago:SetJustifyH("RIGHT")
        r:Hide()
        s.recent[i] = r
    end
    -- (the last gesture, as it runs)
    G.onFire = function()
        if frame:IsVisible() then RefreshLast(); S.FadeIn(s.lastName, 0.2) end
    end
end

ns.GesturesPage = ui
ui.Refresh = Refresh

Shell.AddPage({
    key = "gestures", name = "Gestures", order = 3, icon = "Interface\\Icons\\Ability_Rogue_Sprint",
    build = Build, refresh = Refresh,
    hide = function() if ns.Picker then ns.Picker.Close() end end,
})
