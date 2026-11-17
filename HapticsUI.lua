-- Haptics UI: the widgets the Rumble and Beta tabs share. A value with - and
-- +, a row of choices, a grid of choices next to a control (Off first for an
-- event), a row as on the Rumble tab (icon, name, a second line, its choice on
-- a plate, Try, Default, Edit), and groups down the left with one shown at a
-- time. pg: the page using them ({ refresh = {}, Refresh = fn }).
local _, ns = ...
local S, Shell, H = ns.OptionsSkin, ns.Shell, ns.Haptics
local HUI = {}
ns.HapticsUI = HUI
local W, PH = Shell.W, Shell.H
local GOLD, GREY, DIM, YELLOW = S.GOLD, S.GREY, S.DIM, S.YELLOW
local RED = { 1, 0.48, 0.36 }
local floor, min, max = math.floor, math.min, math.max
local FONT = "Fonts\\FRIZQT__.TTF"
HUI.RED = RED

-- A value with - and + (and the mouse wheel)
function HUI.Stepper(pg, parent, label, x, y, opts)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", x, y)
    row:SetSize(opts.width or 270, 24)
    row.label = S.Text(row, label, 0, -5, opts.labelWidth or 110, 12, GOLD)
    row.label:SetWordWrap(false)
    local lw = opts.labelWidth or 110
    local function change(dir)
        local v = opts.get()
        if opts.list then
            local i = 1
            for k, item in ipairs(opts.list) do if item[1] == v then i = k end end
            i = max(1, min(#opts.list, i + dir))
            opts.set(opts.list[i][1])
        else
            v = (v or 0) + dir * opts.step
            v = max(opts.min, min(opts.max, floor(v / opts.step + 0.5) * opts.step))
            opts.set(v)
        end
        pg.Refresh()
    end
    row.minus = S.NewButton(row, "-", lw, 0, 24, function() change(-1) end, nil, 13, 24)
    row.value = S.Text(row, "", lw + 26, -5, 70, 12, YELLOW)
    row.value:SetJustifyH("CENTER")
    row.plus = S.NewButton(row, "+", lw + 98, 0, 24, function() change(1) end, nil, 13, 24)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) if row.enabled ~= false then change(delta) end end)
    function row:Update()
        local v = opts.get()
        local text
        if opts.list then
            text = "?"
            for _, item in ipairs(opts.list) do if item[1] == v then text = item[2] end end
        elseif opts.format then
            text = opts.format(v)
        else
            text = string.format("%.2f", v or 0)
        end
        row.value:SetText(text)
    end
    function row:SetEnabled(on)
        row.enabled = on
        row.minus:SetEnabled(on)
        row.plus:SetEnabled(on)
        row:SetAlpha(on and 1 or 0.45)
    end
    pg.refresh[#pg.refresh + 1] = function() row:Update() end
    return row
end

-- Buttons, one of them selected
function HUI.Choice(pg, parent, label, x, y, list, get, set, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", x, y)
    row:SetSize(600, 26)
    S.Text(row, label, 0, -6, 110, 12, GOLD)
    local buttons = {}
    width = width or 74
    for i, item in ipairs(list) do
        buttons[i] = S.NewButton(row, item[2], 112 + (i - 1) * (width + 4), 0, width, function()
            set(item[1])
            pg.Refresh()
        end, nil, 11, 26)
    end
    pg.refresh[#pg.refresh + 1] = function()
        local v = get()
        for i, item in ipairs(list) do S.SetSelected(buttons[i], item[1] == v) end
    end
    return row
end

-- A grid of choices next to a control (the Rumble tab's pattern grid):
-- entries { key, label, icon or rgb (a colour swatch) }
local popup
-- up: opens above its anchor (a control at the window's foot). A long list
-- (a 200-sound library) pages, 12 rows at a time, from the current one's page.
local POPUP_ROWS = 12
local DrawPopup
function HUI.Popup(anchor, title, entries, current, onPick, cols, tw, up)
    if not popup then
        popup = CreateFrame("Frame", "GamepadCompanionBetaFeels", Shell.Window())
        popup:SetFrameStrata("DIALOG")
        popup:SetToplevel(true)
        popup:EnableMouse(true)
        S.Panel(popup)
        popup.title = S.Text(popup, "", 14, -12, 600, 13, YELLOW)
        popup.title:SetWordWrap(false)
        popup.tiles = {}
        popup.prev = S.NewButton(popup, "‹", 0, 0, 26, function() popup.page = popup.page - 1; DrawPopup() end, nil, 13, 22)
        popup.next = S.NewButton(popup, "›", 0, 0, 26, function() popup.page = popup.page + 1; DrawPopup() end, nil, 13, 22)
        popup.pageText = S.Text(popup, "", 0, 0, 44, 11, GREY)
        popup.pageText:SetJustifyH("CENTER")
        popup:Hide()
        UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionBetaFeels"
    end
    if popup:IsShown() and popup.anchor == anchor then return popup:Hide() end
    popup.anchor = anchor
    cols, tw = cols or 8, tw or 112
    popup.args = { title = title, entries = entries, current = current, onPick = onPick, cols = cols, tw = tw }
    popup.page = 1
    for i, e in ipairs(entries) do if e.key == current then popup.page = math.ceil(i / (cols * POPUP_ROWS)) end end
    DrawPopup()
    popup:ClearAllPoints()
    if up then popup:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 6)
    else popup:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 8) end
    popup:SetClampedToScreen(true)
    popup:Show()
    popup:Raise()
end

DrawPopup = function()
    local a = popup.args
    local entries, cols, tw = a.entries, a.cols, a.tw
    local th = 28
    local per = cols * POPUP_ROWS
    local pages = math.max(1, math.ceil(#entries / per))
    popup.page = math.max(1, math.min(pages, popup.page))
    local first = (popup.page - 1) * per
    popup.title:SetText(a.title or "")
    for _, t in ipairs(popup.tiles) do t:Hide() end
    local shown = 0
    for i = first + 1, math.min(#entries, first + per) do
        local e = entries[i]
        shown = shown + 1
        local t = popup.tiles[shown]
        if not t then
            t = S.NewButton(popup, "", 0, 0, tw, nil, nil, 11, th)
            t.icon = t:CreateTexture(nil, "OVERLAY")
            t.icon:SetSize(20, 20)
            t.icon:SetPoint("LEFT", 5, 0)
            t.label:SetJustifyH("LEFT")
            popup.tiles[shown] = t
        end
        t:SetWidth(tw)
        local col, row = (shown - 1) % cols, floor((shown - 1) / cols)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 12 + col * (tw + 3), -36 - row * (th + 3))
        t.label:SetText(e.label or e.key)
        t.label:ClearAllPoints()
        t.label:SetPoint("LEFT", (e.icon == false and not e.rgb) and 8 or 30, 0)
        t.label:SetPoint("RIGHT", -3, 0)
        if e.rgb then
            t.icon:SetTexture(nil)
            t.icon:SetColorTexture(e.rgb[1], e.rgb[2], e.rgb[3], 1)
        else
            -- (icon false: none, a plain word)
            t.icon:SetTexture(e.icon ~= false and (e.icon or "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_pulse") or nil)
        end
        if e.key == "off" then t.label:SetTextColor(RED[1], RED[2], RED[3]) else t.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
        S.SetSelected(t, e.key == a.current)
        t:SetScript("OnClick", function()
            popup:Hide()
            a.onPick(e.key)
        end)
        t:Show()
    end
    local rows = math.max(1, math.ceil(shown / cols))
    local w = 24 + cols * (tw + 3)
    popup:SetSize(w, 48 + rows * (th + 3))
    local paged = pages > 1
    popup.title:SetWidth(cols * (tw + 3) - (paged and 110 or 0))
    for _, b in ipairs({ popup.prev, popup.next }) do b:SetShown(paged) end
    popup.pageText:SetShown(paged)
    if paged then
        popup.next:ClearAllPoints(); popup.next:SetPoint("TOPRIGHT", -10, -6)
        popup.pageText:ClearAllPoints(); popup.pageText:SetPoint("RIGHT", popup.next, "LEFT", -2, 0)
        popup.prev:ClearAllPoints(); popup.prev:SetPoint("RIGHT", popup.pageText, "LEFT", -2, 0)
        popup.pageText:SetText(popup.page .. "/" .. pages)
        popup.prev:SetEnabled(popup.page > 1)
        popup.next:SetEnabled(popup.page < pages)
    end
end

-- The one row (Moments, Gestures): icon, name, a second line, a plate showing
-- the choice (opens its grid), Try. opts.default / opts.edit / opts.clear add
-- those buttons; opts.level (Stepper opts) a level beside the plate;
-- opts.marks (a number) room for that many marks of the moment's other kinds
-- (r:SetMarks({ { rgb = or icon =, tip =, onClick = } ... })).
HUI.ROW_H = 44
function HUI.MomentRow(parent, y, width, icon, label, onPick, onTry, tip, opts)
    opts = opts or {}
    local ROW_H = HUI.ROW_H
    local r = CreateFrame("Frame", nil, parent)
    r:SetPoint("TOPLEFT", 10, y)
    r:SetSize(width - 20, ROW_H - 4)
    local wash = r:CreateTexture(nil, "BACKGROUND")
    wash:SetAllPoints()
    wash:SetColorTexture(1, 0.85, 0.55, 0.04)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("LEFT", 2, 0)
    if icon then r.icon:SetTexture(icon) end
    -- right to left: Edit, Default, Try, the plate
    local x = width - 20
    if opts.edit then
        local word = opts.editLabel or "Edit"
        x = x - 52
        r.edit = S.NewButton(r, word, x, -5, 50, function() opts.edit() end, nil, 11, 30)
        S.Tooltip(r.edit, word, opts.editTip)
        x = x - 4
    end
    if opts.default then
        x = x - 62
        r.default = S.NewButton(r, "Default", x, -5, 60, function() opts.default() end, nil, 11, 30)
        S.Tooltip(r.default, "Default", opts.defaultTip)
        x = x - 4
    end
    if opts.clear then
        x = x - 52
        r.clear = S.NewButton(r, "Clear", x, -5, 50, function() opts.clear() end, nil, 11, 30)
        x = x - 4
    end
    if onTry then
        x = x - 34
        r.try = S.NewButton(r, "Try", x, -5, 32, function() onTry() end, nil, 11, 30)
        S.Tooltip(r.try, "Try", label)
        x = x - 4
    end
    if opts.level then
        x = x - 124
        local lv = opts.level
        lv.labelWidth, lv.width = 0, 122
        r.level = HUI.Stepper(opts.pg, r, "", x, -8, lv)
        x = x - 6
    end
    x = x - 136
    r.pick = S.NewButton(r, "", x, -5, 136, nil, nil, 11, 30)
    r.pick.icon = r.pick:CreateTexture(nil, "OVERLAY")
    r.pick.icon:SetSize(20, 20)
    r.pick.icon:SetPoint("LEFT", 6, 0)
    r.pick.label:ClearAllPoints()
    r.pick.label:SetPoint("LEFT", 30, 0)
    r.pick.label:SetPoint("RIGHT", -6, 0)
    r.pick.label:SetJustifyH("LEFT")
    r.pick:SetScript("OnClick", function(self) onPick(self) end)
    if tip then S.Tooltip(r.pick, label, tip) end
    -- marks, just left of the plate
    r.marks = {}
    for i = 1, opts.marks or 0 do
        local m = CreateFrame("Button", nil, r)
        m:SetSize(14, 14)
        m:SetPoint("TOPLEFT", x - 8 - i * 18, -13)
        m.tex = m:CreateTexture(nil, "ARTWORK")
        m.tex:SetAllPoints()
        m:SetScript("OnEnter", S.ShowTooltip)
        m:SetScript("OnLeave", S.HideTooltip)
        m:Hide()
        r.marks[i] = m
    end
    local textW = x - 48 - (opts.marks or 0) * 18
    r.label = S.Text(r, label, 40, -4, textW, 13, GOLD)
    r.label:SetWordWrap(false)
    r.sub = S.Text(r, "", 40, -22, textW, 11, GREY)
    r.sub:SetWordWrap(false)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        local full = S.Cut(r.label)
        if not (full and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(full, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", S.HideTooltip)
    function r:SetMarks(list)
        for i, m in ipairs(r.marks) do
            local e = list and list[i]
            m:SetShown(e ~= nil)
            if e then
                if e.rgb then m.tex:SetTexture(nil); m.tex:SetColorTexture(e.rgb[1], e.rgb[2], e.rgb[3], 1)
                else m.tex:SetTexture(e.icon) end
                S.Tooltip(m, e.tip)
                m:SetScript("OnClick", e.onClick)
            end
        end
    end
    -- off: dimmed, the plate's name in red; isDefault: Default greyed
    function r:SetChoice(name, icon2, sub, off, rgb, isDefault)
        r.pick.label:SetText(name or "")
        if rgb then
            r.pick.icon:SetTexture(nil)
            r.pick.icon:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
        else
            r.pick.icon:SetTexture(icon2)
        end
        r.sub:SetText(sub or "")
        if off then r.pick.label:SetTextColor(RED[1], RED[2], RED[3]) else r.pick.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
        r.icon:SetDesaturated(off == true)
        r.label:SetAlpha(off and 0.6 or 1)
        if r.default then r.default:SetEnabled(not isDefault) end
        if r.clear then r.clear:SetEnabled(not off) end
        if r.level then r.level:SetAlpha(off and 0.45 or 1) end
    end
    return r
end
HUI.ChoiceRow = HUI.MomentRow

-- Groups down the left, one shown at a time on the right. opts: left (a
-- frame to put the list in, else a card of its own), top (the list's first
-- y), leftWidth, width (the panels')
function HUI.GroupBrowser(p, groups, opts)
    opts = opts or {}
    local lw = opts.leftWidth or 200
    local left = opts.left or S.Card(p, nil, 0, 0, lw, PH - 40)
    local top = opts.top or -12
    local b = { buttons = {}, panels = {}, current = nil, left = left }
    for i, g in ipairs(groups) do
        local btn = S.NewButton(left, g.label, 10, top - (i - 1) * 36, lw - 20, function() b.Select(g.key) end, nil, 13, 32)
        btn.label:SetJustifyH("LEFT")
        btn.count = S.Text(btn, "", 0, 0, 60, 11, GREY)
        btn.count:ClearAllPoints()
        btn.count:SetPoint("RIGHT", -8, 0)
        btn.count:SetJustifyH("RIGHT")
        b.buttons[g.key] = btn
        local panel = CreateFrame("Frame", nil, p)
        panel:SetPoint("TOPLEFT", lw + 10, 0)
        panel:SetSize(opts.width or (W - lw - 10), PH - (opts.pageTop or 40))
        panel:Hide()
        b.panels[g.key] = panel
    end
    function b.Select(key)
        b.current = key
        for k, panel in pairs(b.panels) do panel:SetShown(k == key) end
        for k, btn in pairs(b.buttons) do S.SetSelected(btn, k == key) end
        if opts.onSelect then opts.onSelect(key) end
    end
    b.Select(groups[1].key)
    return b
end

-- A grip's range, found by a rising ramp: "floor" stops on "Felt it",
-- "ceil" on "No stronger". One for Setup's Find and Lab's calibration.
local cal = {}
function HUI.Calibrating(side, mode)
    local L = ns.HapticsLab
    return L.Ramping() and cal.side == side and (mode == nil or cal.mode == mode)
end

-- Start, or (pressed again) keep the level reached; true while rising
function HUI.Calibrate(side, mode)
    local L, db = ns.HapticsLab, H.DB()
    if HUI.Calibrating(side, mode) then
        local v = floor(L.StopRamp() * 100 + 0.5) / 100
        if mode == "floor" then
            db.floor[side] = v
            if db.ceil[side] <= v then db.ceil[side] = 1 end
        else
            db.ceil[side] = max(db.floor[side] + 0.05, v)
        end
        cal.side = nil
        return false
    end
    if L.Ramping() then L.StopRamp() end
    cal.side, cal.mode = side, mode
    if mode == "floor" then L.StartRamp(side, 0, 8) else L.StartRamp(side, db.floor[side], 6) end
    L.onRampEnd = function() cal.side = nil; Shell.Refresh() end
    return true
end

-- A text box in a small window (Lab's export, a profile's name, Share)
local textWin
function HUI.TextWindow(title, text, onAccept, acceptLabel)
    if not textWin then
        textWin = CreateFrame("Frame", "GamepadCompanionText", Shell.Window())
        textWin:SetFrameStrata("DIALOG")
        textWin:SetToplevel(true)
        textWin:EnableMouse(true)
        textWin:SetSize(560, 340)
        textWin:SetPoint("CENTER")
        S.Panel(textWin)
        textWin.title = S.Text(textWin, "", 16, -14, 520, 13, YELLOW)
        local box = CreateFrame("EditBox", nil, textWin)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFont(FONT, 11, "")
        box:SetTextColor(1, 1, 1)
        box:SetPoint("TOPLEFT", 16, -40)
        box:SetSize(528, 240)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local wash = textWin:CreateTexture(nil, "BACKGROUND", nil, 1)
        wash:SetPoint("TOPLEFT", 12, -36)
        wash:SetSize(536, 250)
        wash:SetColorTexture(0, 0, 0, 0.4)
        textWin.box = box
        textWin.accept = S.NewButton(textWin, "OK", 16, -296, 120, function()
            if textWin.onAccept then textWin.onAccept(textWin.box:GetText()) end
            textWin:Hide()
        end)
        textWin.select = S.NewButton(textWin, "Select all", 144, -296, 120, function()
            textWin.box:SetFocus()
            textWin.box:HighlightText()
        end)
        S.NewButton(textWin, "Close", 424, -296, 120, function() textWin:Hide() end)
        UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionText"
    end
    textWin.title:SetText(title)
    textWin.box:SetText(text or "")
    textWin.onAccept = onAccept
    textWin.accept.label:SetText(acceptLabel or "OK")
    textWin.accept:SetShown(onAccept ~= nil)
    textWin:Show()
    textWin:Raise()
    textWin.box:SetFocus()
    textWin.box:HighlightText()
end

function HUI.HideTextWindow() if textWin then textWin:Hide() end end

function HUI.HidePopup()
    if popup then popup:Hide() end
    if HUI.HidePalette then HUI.HidePalette() end
end

---------------------------------------------------------------------------
-- The palette: every feel, by group down the left, as big tiles (icon and
-- name, as the Rumble tab's grid). specials (Off, Match the...) stay on top.
-- opts: specials, onPick(key, button), onSelect(key), current() -> key
---------------------------------------------------------------------------
local TILE_W, TILE_H = 92, 70
function HUI.Palette(parent, x, y, w, h, opts)
    local L = ns.HapticsLab
    local pal = CreateFrame("Frame", nil, parent)
    pal:SetPoint("TOPLEFT", x, y)
    pal:SetSize(w, h)
    local listW = 150
    pal.groups = {}
    for _, g in ipairs(L.GROUPS) do pal.groups[#pal.groups + 1] = g end
    pal.groups[#pal.groups + 1] = "Yours"
    pal.buttons, pal.tiles, pal.specialTiles = {}, {}, {}
    local cols = math.max(1, floor((w - listW - 10) / (TILE_W + 4)))
    pal.cols = cols
    for i, g in ipairs(pal.groups) do
        local b = S.NewButton(pal, g, 0, -(i - 1) * 29, listW - 8, function() pal:ShowGroup(g) end, nil, 11, 27)
        b.label:SetJustifyH("LEFT")
        pal.buttons[g] = b
    end
    local function Tile(list, i, parentFrame)
        local t = list[i]
        if t then return t end
        t = CreateFrame("Button", nil, parentFrame)
        t:SetSize(TILE_W, TILE_H)
        t.bg = t:CreateTexture(nil, "BACKGROUND", nil, 1)
        t.bg:SetAllPoints()
        t.bg:SetColorTexture(1, 0.85, 0.55, 0.05)
        t.sel = t:CreateTexture(nil, "BACKGROUND", nil, 2)
        t.sel:SetAllPoints()
        t.sel:SetColorTexture(1, 0.72, 0.2, 0.25)
        local hover = t:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 0.75, 0.3, 0.16)
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetSize(36, 36)
        t.icon:SetPoint("TOP", 0, -6)
        t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t.label:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        t.label:SetPoint("BOTTOMLEFT", 2, 5)
        t.label:SetPoint("BOTTOMRIGHT", -2, 5)
        t.label:SetJustifyH("CENTER")
        t.label:SetWordWrap(false)
        t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        t:SetScript("OnClick", function(self, button)
            if self.key and opts.onPick then opts.onPick(self.key, button) end
            pal:Update()
        end)
        list[i] = t
        return t
    end
    -- (the feels start under the specials' row, when there are any: set by SetSpecials)
    local top = 0
    function pal:Update()
        local current = opts.current and opts.current()
        for i, t in ipairs(pal.specialTiles) do t.sel:SetShown(t.key == current) end
        for _, t in ipairs(pal.tiles) do t.sel:SetShown(t:IsShown() and t.key == current) end
        for g, b in pairs(pal.buttons) do S.SetSelected(b, g == pal.group) end
    end
    function pal:ShowGroup(g)
        pal.group = g
        local list = {}
        for _, f in ipairs(H.AllFeels()) do
            local fg = H.IsOwn(f.key) and "Yours" or f.group or "Yours"
            if fg == g then list[#list + 1] = f end
        end
        for _, t in ipairs(pal.tiles) do t:Hide() end
        for i, f in ipairs(list) do
            local t = Tile(pal.tiles, i, pal)
            local col, row = (i - 1) % cols, floor((i - 1) / cols)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", listW + col * (TILE_W + 4), top - row * (TILE_H + 4))
            t.key = f.key
            t.icon:SetTexture(f.icon or "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_pulse")
            t.label:SetText(f.label or f.key)
            t.label:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
            t:Show()
        end
        pal.rows = math.max(1, math.ceil(#list / cols))
        if opts.onSelect then opts.onSelect(g) end
        pal:Update()
    end
    -- (Off and Match the... on top)
    function pal:SetSpecials(specials)
        for _, t in ipairs(pal.specialTiles) do t:Hide() end
        top = (specials and #specials > 0) and -(TILE_H + 10) or 0
        for i, e in ipairs(specials or {}) do
            local t = Tile(pal.specialTiles, i, pal)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", listW + (i - 1) * (TILE_W + 4), 0)
            t.key = e.key
            t.icon:SetTexture(e.icon)
            t.label:SetText(e.label)
            if e.key == "off" then t.label:SetTextColor(RED[1], RED[2], RED[3]) else t.label:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3]) end
            t:Show()
        end
    end
    pal:SetSpecials(opts.specials)
    -- the group of a feel (to open on the current one)
    function pal:GroupOf(key)
        local f = key and H.Feel(key)
        if not f then return nil end
        return H.IsOwn(key) and "Yours" or f.group
    end
    pal.listHeight = #pal.groups * 29
    return pal
end

-- The palette next to a control: pick a feel (specials first: Off, Match the...)
local palWin
function HUI.PickFeel(anchor, current, onPick, specials, title)
    if not palWin then
        palWin = CreateFrame("Frame", "GamepadCompanionPalette", Shell.Window())
        palWin:SetFrameStrata("DIALOG")
        palWin:SetToplevel(true)
        palWin:EnableMouse(true)
        S.Panel(palWin)
        palWin.title = S.Text(palWin, "", 14, -12, 700, 13, YELLOW)
        palWin.pal = HUI.Palette(palWin, 12, -36, 150 + 8 * (TILE_W + 4), 600, {
            specials = {},
            current = function() return palWin.current end,
            onPick = function(key)
                palWin:Hide()
                if palWin.onPick then palWin.onPick(key) end
            end,
        })
        palWin:SetScript("OnKeyDown", nil)
        palWin:Hide()
        UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionPalette"
    end
    if palWin:IsShown() and palWin.anchor == anchor then return palWin:Hide() end
    palWin.anchor, palWin.current, palWin.onPick = anchor, current, onPick
    palWin.title:SetText(title or "Feels")
    if type(specials) ~= "table" then
        specials = specials and { { key = "off", label = "Off", icon = ns.Rumble and ns.Rumble.OFF_ICON } } or {}
    end
    palWin.pal:SetSpecials(specials)
    palWin.pal:ShowGroup(palWin.pal:GroupOf(current) or ns.HapticsLab.GROUPS[1])
    local tilesH = (#specials > 0 and (TILE_H + 10) or 0) + 3 * (TILE_H + 4)
    palWin:SetSize(24 + 150 + 8 * (TILE_W + 4), 48 + math.max(palWin.pal.listHeight, tilesH))
    palWin:ClearAllPoints()
    palWin:SetPoint("CENTER", Shell.Window(), "CENTER", 0, 0)
    palWin:SetClampedToScreen(true)
    palWin:Show()
    palWin:Raise()
end

function HUI.HidePalette()
    if palWin then palWin:Hide() end
end
