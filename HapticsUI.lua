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

-- A value with - and + (and the mouse wheel), its value over a track that
-- shows where it sits in its range (a click on the track sets it); a list
-- shows a pip for each choice instead.
local TRACK_W = 68
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
    local TRACK_W = opts.width and max(TRACK_W, opts.width - lw - 52) or TRACK_W
    row.minus = S.NewButton(row, "-", lw, 0, 24, function() change(-1) end, nil, 13, 24)
    row.value = S.Text(row, "", lw + 26, -1, TRACK_W + 2, 11, YELLOW)
    row.value:SetJustifyH("CENTER")
    row.plus = S.NewButton(row, "+", lw + TRACK_W + 30, 0, 24, function() change(1) end, nil, 13, 24)
    -- the track (a value) or the pips (a list)
    row.track = row:CreateTexture(nil, "BORDER")
    row.track:SetPoint("TOPLEFT", lw + 27, -16); row.track:SetSize(TRACK_W, 4)
    row.track:SetColorTexture(0, 0, 0, 0.45)
    row.fill = row:CreateTexture(nil, "ARTWORK")
    row.fill:SetPoint("TOPLEFT", row.track, "TOPLEFT", 0, 0); row.fill:SetHeight(4)
    S.Gradient(row.fill, "HORIZONTAL", { 0.7, 0.45, 0.1, 1 }, { 1, 0.78, 0.25, 1 })
    if opts.list then
        row.track:Hide(); row.fill:Hide()
        row.pips = {}
        local n = #opts.list
        local gap = n > 1 and (TRACK_W - 4) / (n - 1) or 0
        for i = 1, n do
            local p = row:CreateTexture(nil, "ARTWORK")
            p:SetSize(4, 4)
            p:SetPoint("TOPLEFT", lw + 27 + (n > 1 and (i - 1) * gap or (TRACK_W - 4) / 2), -16)
            row.pips[i] = p
        end
    else
        -- (a click on the track: that value)
        local hit = CreateFrame("Button", nil, row)
        hit:SetPoint("TOPLEFT", lw + 26, -12); hit:SetSize(TRACK_W + 2, 12)
        hit:SetScript("OnMouseDown", function()
            if row.enabled == false or not (GetCursorPosition and row.track.GetLeft and row.track:GetLeft()) then return end
            local cx = GetCursorPosition() / (row.track:GetEffectiveScale() or 1)
            local f = max(0, min(1, (cx - row.track:GetLeft()) / TRACK_W))
            local v = opts.min + f * (opts.max - opts.min)
            opts.set(max(opts.min, min(opts.max, floor(v / opts.step + 0.5) * opts.step)))
            pg.Refresh()
        end)
        row.hit = hit
    end
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
        if row.pips then
            for i, p in ipairs(row.pips) do
                local on = opts.list[i][1] == v
                p:SetColorTexture(on and 1 or 0.5, on and 0.82 or 0.4, on and 0.25 or 0.25, on and 1 or 0.6)
            end
        elseif opts.max and opts.max > opts.min then
            local f = max(0, min(1, ((v or opts.min) - opts.min) / (opts.max - opts.min)))
            row.fill:SetWidth(max(0.01, f * TRACK_W))
            row.fill:SetShown(f > 0)
        end
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
    local widths = {}
    for i = 1, #list do widths[i] = width end
    S.Segments(row, 111, 1, widths, 26)
    for i, item in ipairs(list) do
        buttons[i] = S.Segment(row, item[2], 112 + (i - 1) * width, 0, width, function()
            set(item[1])
            pg.Refresh()
        end, 11, 26)
    end
    row.buttons = buttons
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
        S.Popup(popup, "GamepadCompanionBetaFeels", { outside = true })
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
    S.FadeIn(popup, 0.1)
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
    popup.title:SetWidth(cols * (tw + 3) - (paged and 140 or 30))
    for _, b in ipairs({ popup.prev, popup.next }) do b:SetShown(paged) end
    popup.pageText:SetShown(paged)
    if paged then
        popup.next:ClearAllPoints(); popup.next:SetPoint("TOPRIGHT", -34, -6)
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
    -- (every other row a little warmer: a long list reads as rows)
    local odd = floor(-y / ROW_H + 0.5) % 2 == 1
    wash:SetColorTexture(1, 0.85, 0.55, odd and 0.07 or 0.04)
    r.hover = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.hover:SetAllPoints()
    r.hover:SetColorTexture(1, 0.8, 0.4, 0.05)
    r.hover:Hide()
    -- (its state at a glance: gold on, dim off, a light's own colour)
    r.accent = r:CreateTexture(nil, "ARTWORK")
    r.accent:SetPoint("TOPLEFT", 0, -4); r.accent:SetPoint("BOTTOMLEFT", 0, 4); r.accent:SetWidth(2)
    r.accent:SetColorTexture(1, 0.78, 0.25, 0.9)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("LEFT", 6, 0)
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
        -- (opts.quiet: a small × instead of the word)
        local cw = opts.quiet and 26 or 50
        x = x - cw - 2
        r.clear = S.NewButton(r, opts.quiet and "×" or "Clear", x, -5, cw, function() opts.clear() end, nil, opts.quiet and 14 or 11, 30)
        if opts.quiet then S.Tooltip(r.clear, "Remove") end
        x = x - 4
    end
    if onTry then
        x = x - 34
        r.try = S.NewButton(r, "Try", x, -5, 32, function()
            onTry()
            r:Flash()
            if Shell.PadPresent and Shell.PadPresent() == false then Shell.SetStatus("|cffff7a5cNo pad|r", true) end
        end, nil, 11, 30)
        S.Tooltip(r.try, "Try", label)
        x = x - 4
    end
    -- the volume: a chip ("80%") after the plate; a click opens its slider
    local plateW = 136
    if opts.level then
        x = x - 54
        local lv = opts.level
        r.level = S.NewButton(r, "", x, -5, 52, function(self) HUI.LevelPopover(self, lv, label, opts.pg) end, nil, 11, 30)
        r.level.value = r.level.label
        -- (a row not filled yet has no value to show)
        local function Show()
            local ok, v = pcall(lv.get)
            if ok and v then r.level.label:SetText((lv.format or tostring)(v)) end
        end
        if opts.pg then opts.pg.refresh[#opts.pg.refresh + 1] = Show end
        Show()
        S.Tooltip(r.level, "Volume")
        x = x - 6
        plateW = 200
    end
    x = x - plateW
    r.pick = S.NewButton(r, "", x, -5, plateW, nil, nil, 11, 30)
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
    r.label = S.Text(r, label, 44, -4, textW - 4, 13, GOLD)
    r.label:SetWordWrap(false)
    r.sub = S.Text(r, "", 44, -22, textW - 4, 11, GREY)
    r.sub:SetWordWrap(false)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        r.hover:Show()
        local full = S.Cut(r.label)
        if not (full and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(full, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(self) r.hover:Hide(); S.HideTooltip(self) end)
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
    -- (the plate flashes gold 0.4 s: Try, Default, a pick)
    function r:Flash()
        if not r.flash then
            r.flash = r.pick:CreateTexture(nil, "OVERLAY", nil, 2)
            r.flash:SetPoint("TOPLEFT", 3, -3); r.flash:SetPoint("BOTTOMRIGHT", -3, 3)
            r.flash:SetColorTexture(1, 0.8, 0.3, 0.45)
            if r.flash.SetBlendMode then r.flash:SetBlendMode("ADD") end
            r.flash:SetAlpha(0)
        end
        local f = r.flash
        if type(f.CreateAnimationGroup) ~= "function" then return end
        local ag = rawget(f, "gpcFlash")
        if type(ag) ~= "table" then
            ag = f:CreateAnimationGroup()
            if type(ag) ~= "table" or type(ag.CreateAnimation) ~= "function" then return end
            local a = ag:CreateAnimation("Alpha")
            if type(a) ~= "table" or type(a.SetFromAlpha) ~= "function" then return end
            a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(0.4)
            if ag.SetToFinalAlpha then ag:SetToFinalAlpha(true) end
            f.gpcFlash = ag
        end
        ag:Stop(); ag:Play()
    end
    -- WoW Helper's proposal for this row: "Proposed · Coin tap", Accept, Dismiss (nil: none)
    function r:SetProposal(p, accept, dismiss)
        if not p then
            if r.proposal then r.proposal:Hide() end
            r.sub:SetTextColor(GREY[1], GREY[2], GREY[3])
            return
        end
        if not r.proposal then
            local f = CreateFrame("Frame", nil, r)
            f:SetSize(120, 20)
            f.accept = S.NewButton(f, "Accept", 0, 0, 58, nil, nil, 10, 20)
            f.dismiss = S.NewButton(f, "Dismiss", 60, 0, 58, nil, nil, 10, 20)
            r.proposal = f
        end
        local f = r.proposal
        r.sub:SetText("Proposed · " .. p.name)
        r.sub:SetTextColor(YELLOW[1], YELLOW[2], YELLOW[3])
        local w = r.sub:GetStringWidth()
        f:ClearAllPoints()
        f:SetPoint("LEFT", r.sub, "LEFT", math.min((type(w) == "number" and w or 120) + 8, 200), 0)
        f.accept:SetScript("OnClick", accept)
        f.dismiss:SetScript("OnClick", dismiss)
        f:Show()
    end
    function r:SetChoice(name, icon2, sub, off, rgb, isDefault)
        -- (a new choice, not the first draw: a pick or Default)
        if r.shown ~= nil and r.shown ~= name then r:Flash() end
        r.shown = name
        if off then r.accent:SetColorTexture(0.62, 0.62, 0.62, 0.35)
        elseif rgb then r.accent:SetColorTexture(rgb[1], rgb[2], rgb[3], 0.95)
        else r.accent:SetColorTexture(1, 0.78, 0.25, 0.9) end
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
        -- (changed from Recommended: a gold dot on its name)
        local changed = r.default ~= nil and isDefault == false
        if changed and not r.changed then
            r.changed = S.Text(r, "•", 35, -2, 10, 14, YELLOW)
        end
        if r.changed then r.changed:SetShown(changed) end
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
        if b.current ~= key and b.panels[key] then S.FadeIn(b.panels[key], 0.1) end
        for k, panel in pairs(b.panels) do panel:SetShown(k == key) end
        for k, btn in pairs(b.buttons) do S.SetSelected(btn, k == key) end
        if opts.onSelect then opts.onSelect(key) end
    end
    -- the next group shown (the pad's L2 / R2)
    function b.Step(dir)
        local list = {}
        for _, g in ipairs(groups) do
            local btn = b.buttons[g.key]
            if btn and (type(btn.IsShown) ~= "function" or btn:IsShown()) then list[#list + 1] = g.key end
        end
        local at = 1
        for i, k in ipairs(list) do if k == b.current then at = i end end
        if #list > 0 then b.Select(list[(at - 1 + dir) % #list + 1]) end
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

-- Setup › Range: micro-taps at a grip's floor, the same 33 ms tap the faint
-- feels use. Repeated every 0.6 s while a side is being set (Audition), or one
-- at a level (Tap, for the yes/no check). Straight to the motor: the floor is
-- the motor's level, before calibration.
local TAP, EVERY = 0.033, 0.6
local taps = { side = nil, level = nil, untilT = 0, nextT = 0, offT = 0 }
local tapper = CreateFrame("Frame")
tapper:Hide()
local function TapsOff()
    tapper:Hide()
    H.Silence()
    H.hold = false
    taps.side = nil
end
tapper:SetScript("OnUpdate", function()
    local now = GetTime()
    local side = taps.side
    if not side then return TapsOff() end
    local level = taps.level or H.DB().floor[side] or 0
    if now >= taps.nextT and now < taps.untilT then
        taps.offT, taps.nextT = now + TAP, now + EVERY
    end
    local on = now < taps.offT
    H.Send(side == 1 and "Low" or "High", on and level or 0)
    H.Send(side == 1 and "High" or "Low", 0)
    if not on and now >= taps.untilT then TapsOff() end
end)
local function TapsStart(side, level, seconds, delay)
    local L = ns.HapticsLab
    if L.Ramping() then L.StopRamp() end
    if taps.side ~= side or not tapper:IsShown() or level then
        H.Stop()
        taps.nextT, taps.offT = GetTime() + (delay or 0), 0
    end
    H.hold = true
    taps.side, taps.level, taps.untilT = side, level, GetTime() + seconds
    tapper:Show()
end
-- Taps at the side's floor (read live, so a change is felt on the next tap)
-- for `seconds` from now; called again: longer
function HUI.Audition(side, seconds) TapsStart(side, nil, seconds or 2.5) end
-- One tap at `level`, after `delay` s (not under the click that asked)
function HUI.Tap(side, level, delay) TapsStart(side, level, (delay or 0) + 0.05, delay) end
function HUI.StopTaps() if tapper:IsShown() then TapsOff() end end

-- A row's volume: a small popover with its slider and Default (one, shared)
local levelPop
function HUI.LevelPopover(anchor, lv, title, pg)
    if not levelPop then
        levelPop = CreateFrame("Frame", "GamepadCompanionLevel", Shell.Window())
        levelPop:SetFrameStrata("DIALOG")
        levelPop:SetToplevel(true)
        levelPop:EnableMouse(true)
        levelPop:SetSize(300, 112)
        S.Panel(levelPop)
        levelPop.title = S.Text(levelPop, "", 14, -12, 240, 13, YELLOW)
        levelPop.title:SetWordWrap(false)
        levelPop.lv = {}
        local proxy = { step = 0.1, min = 0, max = 1, labelWidth = 0, width = 270,
            format = function(v) return (levelPop.lv.format or tostring)(v) end,
            get = function() return levelPop.lv.get() end,
            set = function(v) levelPop.lv.set(v) end }
        levelPop.proxy = proxy
        levelPop.stepper = HUI.Stepper(pg, levelPop, "", 14, -44, proxy)
        levelPop.default = S.NewButton(levelPop, "Default", 14, -76, 80, function()
            if levelPop.lv.default then levelPop.lv.default(); pg.Refresh() end
        end, nil, 11, 24)
        levelPop:Hide()
        S.Popup(levelPop, "GamepadCompanionLevel", { outside = true })
    end
    if levelPop:IsShown() and levelPop.anchor == anchor then return levelPop:Hide() end
    levelPop.anchor, levelPop.lv = anchor, lv
    local p = levelPop.proxy
    p.step, p.min, p.max = lv.step or 0.1, lv.min or 0, lv.max or 1
    levelPop.title:SetText(title or "Volume")
    levelPop.default:SetShown(lv.default ~= nil)
    levelPop:ClearAllPoints()
    levelPop:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    levelPop:SetClampedToScreen(true)
    levelPop:Show()
    levelPop:Raise()
    if levelPop.stepper.Update then levelPop.stepper:Update() end
    S.FadeIn(levelPop, 0.1)
end
HUI.LevelPop = function() return levelPop end

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
        textWin.title = S.Text(textWin, "", 16, -12, 490, 13, YELLOW)
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
        S.Popup(textWin, "GamepadCompanionText")
    end
    textWin.title:SetText(title)
    textWin.box:SetText(text or "")
    textWin.onAccept = onAccept
    textWin.accept.label:SetText(acceptLabel or "OK")
    textWin.accept:SetShown(onAccept ~= nil)
    textWin:Show()
    textWin:Raise()
    S.FadeIn(textWin, 0.1)
    textWin.box:SetFocus()
    textWin.box:HighlightText()
end

function HUI.HideTextWindow() if textWin then textWin:Hide() end end

---------------------------------------------------------------------------
-- Just felt: a small chip with the last moment of a kind (its icon, its
-- name, then what played, quieter), going quiet as it ages; a click lists
-- the last few, each one jumping to its row. On HapticsDebug's notes, no
-- polling. right: the chip's right edge in the header; kind() -> feel,
-- light or sound; opts.icon(key, kind), opts.jump(key, kind)
---------------------------------------------------------------------------
local CAPTION = { feel = "Just felt", light = "Just lit", sound = "Just played" }
HUI.JUST_FELT = CAPTION
local function Ago(s)
    s = math.max(0, s or 0)
    if s < 60 then return floor(s) .. " s" end
    if s < 3600 then return floor(s / 60) .. " min" end
    return floor(s / 3600) .. " h"
end
HUI.Ago = Ago
function HUI.JustFelt(header, right, kind, opts)
    local D = ns.HapticsDebug
    local CHIP_W = 300
    local chip = CreateFrame("Button", nil, header)
    chip:SetSize(CHIP_W, 26)
    chip:SetPoint("TOPLEFT", right - CHIP_W, -3)
    local back = chip:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(1, 0.85, 0.55, 0.06)
    local edge = chip:CreateTexture(nil, "BORDER")
    edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
    S.Gradient(edge, "HORIZONTAL", { 0.85, 0.66, 0.32, 0 }, { 0.85, 0.66, 0.32, 0.45 })
    local hover = chip:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.8, 0.4, 0.08)
    -- right to left: the feel, the name, the icon, the caption
    chip.choice = S.Text(chip, "", 0, -7, 110, 11, GREY)
    chip.choice:ClearAllPoints(); chip.choice:SetPoint("RIGHT", -8, 0)
    chip.choice:SetJustifyH("RIGHT"); chip.choice:SetWordWrap(false)
    chip.name = S.Text(chip, "", 0, -7, 120, 11, GOLD)
    chip.name:ClearAllPoints(); chip.name:SetPoint("RIGHT", chip.choice, "LEFT", -6, 0)
    chip.name:SetJustifyH("RIGHT"); chip.name:SetWordWrap(false)
    chip.icon = chip:CreateTexture(nil, "ARTWORK")
    chip.icon:SetSize(18, 18)
    chip.icon:SetPoint("RIGHT", chip.name, "LEFT", -5, 0)
    chip.caption = S.Text(chip, "", 8, -8, 70, 10, DIM)
    -- (fresh, then quiet over half a minute)
    local fade
    if type(chip.CreateAnimationGroup) == "function" then
        fade = chip:CreateAnimationGroup()
        local a = type(fade) == "table" and type(fade.CreateAnimation) == "function" and fade:CreateAnimation("Alpha")
        if type(a) == "table" and type(a.SetFromAlpha) == "function" then
            a:SetFromAlpha(1); a:SetToAlpha(0.4); a:SetDuration(20)
            if a.SetStartDelay then a:SetStartDelay(10) end
            if fade.SetToFinalAlpha then fade:SetToFinalAlpha(true) end
        else
            fade = nil
        end
    end
    local function Latest() return D and D.Recent(kind())[1] end
    function chip.Update(fresh)
        local e = Latest()
        chip:SetShown(e ~= nil)
        if not e then return end
        local k = kind()
        chip.caption:SetText(CAPTION[k] or "")
        S.Tooltip(chip, CAPTION[k] or CAPTION.feel, "Click: the last 10 · Right-click: again")
        chip.icon:SetTexture(opts.icon(e.key, k))
        chip.name:SetText(e.label or e.key)
        chip.choice:SetText(e.choice or "")
        local sw = chip.name:GetStringWidth()
        chip.name:SetWidth(math.min(140, math.max(20, (type(sw) == "number" and sw or 120) + 2)))
        local age = (GetTime and GetTime() or 0) - e.at
        if fade then fade:Stop() end
        if fresh or age < 10 then
            chip:SetAlpha(1)
            if fade then fade:Play() end
        else
            chip:SetAlpha(age < 30 and 0.7 or 0.4)
        end
    end
    chip:SetScript("OnClick", function(self)
        local k = kind()
        local now = GetTime and GetTime() or 0
        local entries = {}
        for i, e in ipairs(D and D.Recent(k) or {}) do
            entries[#entries + 1] = { key = i, icon = opts.icon(e.key, k),
                label = (e.label or e.key) .. (e.choice and ("  ·  " .. e.choice) or "") .. "  ·  " .. Ago(now - e.at) }
        end
        HUI.Popup(self, CAPTION[k], entries, nil, function(i)
            local e = D.Recent(k)[i]
            if e then opts.jump(e.key, k) end
        end, 1, 300)
    end)
    -- Again: a right-click plays the last moment once more
    if chip.RegisterForClicks then chip:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    local click = chip:GetScript("OnClick")
    chip:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local e = Latest()
            if e and opts.again then opts.again(e.key, kind()) end
            return
        end
        click(self, button)
    end)
    S.Tooltip(chip, CAPTION.feel, "Click: the last 10 · Right-click: again")
    if D and D.Listen then
        D.Listen(function(e) if e.kind == kind() and header:IsVisible() then chip.Update(true) end end)
    end
    chip:SetScript("OnShow", function() chip.Update() end)
    chip.Update()
    return chip
end

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
-- The palette's hover preview: once (a loop too), faint; only as Try would play (Feel on, not
-- Improved Forever's, not in a fight); stopped on leave, on hide and when a fight starts
local function PreviewOK()
    if InCombatLockdown and InCombatLockdown() then return false end
    local V = ns.Rumble
    if not V then return true end
    local ok, on = pcall(function() return V.Settings().enabled and not V.Other() end)
    return ok and on and true or false
end
HUI.PreviewOK = PreviewOK
function HUI.StopPreview() if H.Stop then H.Stop("preview") end end
local previewStop = CreateFrame("Frame")
pcall(previewStop.RegisterEvent, previewStop, "PLAYER_REGEN_DISABLED")
previewStop:SetScript("OnEvent", function() HUI.StopPreview() end)

function HUI.Palette(parent, x, y, w, h, opts)
    local L = ns.HapticsLab
    local pal = CreateFrame("Frame", nil, parent)
    pal:SetPoint("TOPLEFT", x, y)
    pal:SetSize(w, h)
    pal:SetScript("OnHide", function() pal.hovered = nil; HUI.StopPreview() end)
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
        -- (hovered 300 ms: it plays faint, once; the pick plays it full)
        t:SetScript("OnEnter", function(self)
            pal.hovered = self
            if not (C_Timer and C_Timer.After) then return end
            C_Timer.After(0.3, function()
                local f = pal.hovered == self and self.key and self.key ~= "off" and H.Feel(self.key)
                if f and PreviewOK() and pal:IsVisible() then pcall(H.Play, f, { voice = "preview", gain = 0.5, loop = false }) end
            end)
        end)
        t:SetScript("OnLeave", function(self)
            if pal.hovered == self then pal.hovered = nil end
            HUI.StopPreview()
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
        palWin:Hide()
        S.Popup(palWin, "GamepadCompanionPalette", { outside = true })
        palWin:HookScript("OnHide", function() palWin.pal.hovered = nil; HUI.StopPreview() end)
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
