-- The Gestures tab: what each gesture runs, as a grid of cards that fills the
-- page, and a status column. Always 12 slots, one per number (the key WoW
-- Helper presses): the gesture recorded there in WoW Helper (named and
-- described by its data addon; none: a small reminder) and, apart from it,
-- the action given here, so either can change alone. A card: what it does
-- (the action's icon, large), its name, the motion in words, and
-- the action on a plate (Choose); a quiet × on hover. The status column: the link, how many, the
-- helper's mode, and the last gesture that ran (on the gesture's own click,
-- no polling). The key chord WoW Helper presses stays in the tooltip.
local _, ns = ...
local S, Shell, HUI = ns.OptionsSkin, ns.Shell, ns.HapticsUI
local W, PH = Shell.W, Shell.H

local ui = { cards = {} }
local ACCEPTS = ns.TouchModel.ACCEPTS
local GLYPH = "Interface\\AddOns\\GamepadCompanion\\Media\\tab-gestures"
local GAP, STATUS_W, COLS = 14, 250, 4
local GRID_W = W - STATUS_W - GAP
local CARD_W = math.floor((GRID_W - (COLS - 1) * GAP) / COLS)
local ROWS = 3                  -- 12 slots: 4 x 3, always
local CARD_H = math.floor((PH - (ROWS - 1) * GAP) / ROWS)

-- "wave" -> "Wave", "sit down" -> "Sit Down"
local function Title(s)
    return (tostring(s):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end
ui.Title = Title

-- What WoW Helper says of a slot: { name, mode, desc } (nil: nothing)
local function Recorded(slot)
    local C = ns.HelperCues
    return C and type(C.Gesture) == "function" and C.Gesture(slot) or nil
end

-- The 12 slots, in order: each with WoW Helper's gesture there (or none)
function ui.Shown()
    local G = ns.Gestures
    local list = {}
    for slot = 1, G.SLOTS do
        local rec = Recorded(slot)
        list[slot] = { slot = slot, name = rec and Title(rec.name or G.Label(slot)) or "Empty", rec = rec }
    end
    return list
end

-- A texture cut round (the client's circle mask, when it has one)
local function Round(frame, tex)
    if not (frame.CreateMaskTexture and tex.AddMaskTexture) then return end
    local mask = frame:CreateMaskTexture()
    if mask then mask:SetAtlas("CircleMask"); mask:SetAllPoints(tex); tex:AddMaskTexture(mask) end
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
    card.slot = i
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    card:SetPoint("TOPLEFT", col * (CARD_W + GAP), -row * (CARD_H + GAP))
    -- the slot's number, large and engraved, behind everything
    card.num = card:CreateFontString(nil, "BACKGROUND")
    card.num:SetFont(STANDARD_TEXT_FONT, 72, "")
    card.num:SetPoint("TOPRIGHT", -12, -6)
    card.num:SetText(tostring(i))
    card.num:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3], 0.13)
    -- the gesture there and its motion in words
    card.name = S.Text(card, "", 16, -16, CARD_W - 32 - 50, 14, S.YELLOW)
    card.name:SetWordWrap(false)
    card.desc = S.Text(card, "", 16, -36, CARD_W - 32 - 50, 11, S.GREY)
    card.desc:SetWordWrap(false)
    -- no gesture in WoW Helper at this number: a small reminder
    card.hint = CreateFrame("Frame", nil, card)
    card.hint:SetSize(CARD_W - 32, 16)
    card.hint:SetPoint("TOPLEFT", 14, -34)
    card.hint:EnableMouse(true)
    local dot = card.hint:CreateTexture(nil, "ARTWORK")
    dot:SetSize(7, 7)
    dot:SetPoint("LEFT", 2, 0)
    dot:SetColorTexture(1, 0.66, 0.2, 0.9)
    Round(card.hint, dot)
    card.hint.text = S.Text(card.hint, "Record in WoW Helper", 14, -2, CARD_W - 50, 11, S.GREY)
    S.Tooltip(card.hint, "No gesture", "WoW Helper › Gestures › " .. i)
    -- what it does, large: the action's icon in a round gold socket
    card.glyphBox = CreateFrame("Frame", nil, card)
    card.glyphBox:SetSize(64, 64)
    card.glyphBox:SetPoint("CENTER", 0, 2)
    card.ring = card.glyphBox:CreateTexture(nil, "BORDER")
    card.ring:SetAllPoints()
    card.ring:SetColorTexture(S.GOLD[1], S.GOLD[2], S.GOLD[3], 0.55)
    Round(card.glyphBox, card.ring)
    card.well = card.glyphBox:CreateTexture(nil, "ARTWORK", nil, -1)
    card.well:SetPoint("CENTER")
    card.well:SetSize(60, 60)
    card.well:SetColorTexture(0, 0, 0, 0.85)
    Round(card.glyphBox, card.well)
    card.glyph = card.glyphBox:CreateTexture(nil, "ARTWORK")
    card.glyph:SetPoint("CENTER")
    card.glyph:SetSize(56, 56)
    Round(card.glyphBox, card.glyph)
    -- the action, on its plate, at the foot
    card.pick = S.NewButton(card, "", 14, 0, CARD_W - 28, function() Pick(card) end, nil, 12, 40)
    card.pick:ClearAllPoints()
    card.pick:SetPoint("BOTTOMLEFT", 14, 14)

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
    local n = 0
    for i, card in ipairs(ui.cards) do
        local g = list[i]
        local action = G.Get(g.slot)
        card.action = action
        local name, icon
        if action and ns.Touch then name, icon = ns.Touch.ActionLook(action) end
        local rec = g.rec
        if rec then n = n + 1 end
        card.name:SetText(g.name)
        card.name:SetTextColor(unpack(rec and S.YELLOW or S.DIM))
        -- (what it is: WoW Helper's words and its mode; Not ready, calmly)
        local desc = rec and rec.desc or ""
        if rec and rec.mode then desc = desc ~= "" and (desc .. "  ·  " .. Title(rec.mode)) or Title(rec.mode) end
        if rec and rec.ready == false then desc = "Not ready" end
        -- (words that only repeat the name say nothing)
        if desc:lower() == g.name:lower() then desc = "" end
        card.desc:SetText(desc)
        card.desc:SetShown(rec ~= nil)
        card.hint:SetShown(rec == nil)
        -- (a lone typed command by its name: /sit -> Sit)
        local command = action and action:match("^text:/([%a]+)%s*$")
        if command then name = Title(command) end
        card.glyph:SetTexture(icon or GLYPH)
        card.glyph:SetDesaturated(rec == nil)
        card.glyph:SetAlpha(action and (rec and 1 or 0.6) or 0.25)
        card.ring:SetAlpha(action and rec and 1 or 0.35)
        card.num:SetAlpha(rec and 1 or 0.6)
        card.pick:SetAlpha(action and 1 or 0.7)
        card.pick.icon:SetTexture(icon or "Interface\AddOns\GamepadCompanion\Media\tab-controller")
        card.pick.icon:SetDesaturated(action == nil)
        card.pick.icon:SetAlpha(action and 1 or 0.5)
        card.pick.label:SetText(action and (name or action) or "Choose")
        if action then card.pick.label:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
        else card.pick.label:SetTextColor(S.GREY[1], S.GREY[2], S.GREY[3]) end
        S.Tooltip(card.pick, rec and g.name or ("Gesture " .. g.slot), (G.IsPending() and "After combat · " or "") .. "Ctrl Shift Alt F" .. g.slot)
        card.clear:SetAlpha(action and card:IsMouseOver() and 1 or 0)
    end
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
