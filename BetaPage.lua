-- The Beta tab: a haptics lab on the Beta engine (Haptics.lua, HapticsLab.lua).
-- Sections: Probes (what the pad really does, answers kept), Calibrate,
-- Feels (the library), Editor (shape, keyframes, recorded with L2 / R2),
-- Events (more of the game), Light (the light bar), Engine (mixer settings
-- and a live view). Untested in game: this is where we find out.
local _, ns = ...
local S, Shell, H, L = ns.OptionsSkin, ns.Shell, ns.Haptics, ns.HapticsLab
local API = GamepadCompanionAPI
local W, PH = Shell.W, Shell.H
local GOLD, GREY, DIM, YELLOW = S.GOLD, S.GREY, S.DIM, S.YELLOW
local RED = { 1, 0.48, 0.36 }
local FONT = "Fonts\\FRIZQT__.TTF"
local LEFT_C, RIGHT_C = { 1, 0.62, 0.2 }, { 0.35, 0.7, 1 }
local floor, min, max = math.floor, math.min, math.max

local ui = { panels = {}, sections = {}, refresh = {} }
local Refresh

local function Say(text, warn)
    Shell.SetStatus(warn and ("|cffff7a5c" .. text .. "|r") or text, true)
end

local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Shared widgets
---------------------------------------------------------------------------
-- A value with - and + (and the mouse wheel)
local function Stepper(parent, label, x, y, opts)
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
        Refresh()
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
    ui.refresh[#ui.refresh + 1] = function() row:Update() end
    return row
end

-- Buttons, one of them selected
local function Choice(parent, label, x, y, list, get, set, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", x, y)
    row:SetSize(600, 26)
    S.Text(row, label, 0, -6, 110, 12, GOLD)
    local buttons = {}
    width = width or 74
    for i, item in ipairs(list) do
        buttons[i] = S.NewButton(row, item[2], 112 + (i - 1) * (width + 4), 0, width, function()
            set(item[1])
            Refresh()
        end, nil, 11, 26)
    end
    ui.refresh[#ui.refresh + 1] = function()
        local v = get()
        for i, item in ipairs(list) do S.SetSelected(buttons[i], item[1] == v) end
    end
    return row
end

-- Two lanes, mirrored: left grip above the line, right grip below
local function Graph(parent, x, y, w, h, columns)
    local g = CreateFrame("Frame", nil, parent)
    g:SetPoint("TOPLEFT", x, y)
    g:SetSize(w, h)
    local bg = g:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    local mid = g:CreateTexture(nil, "ARTWORK")
    mid:SetColorTexture(1, 1, 1, 0.25)
    mid:SetPoint("LEFT", 0, 0)
    mid:SetSize(w, 1)
    g.columns = columns
    g.up, g.down = {}, {}
    local cw = w / columns
    for i = 1, columns do
        local u = g:CreateTexture(nil, "ARTWORK")
        u:SetColorTexture(LEFT_C[1], LEFT_C[2], LEFT_C[3], 0.85)
        u:SetPoint("BOTTOMLEFT", g, "LEFT", (i - 1) * cw, 0)
        u:SetSize(max(1, cw - 0.5), 1)
        local d = g:CreateTexture(nil, "ARTWORK")
        d:SetColorTexture(RIGHT_C[1], RIGHT_C[2], RIGHT_C[3], 0.85)
        d:SetPoint("TOPLEFT", g, "LEFT", (i - 1) * cw, 0)
        d:SetSize(max(1, cw - 0.5), 1)
        g.up[i], g.down[i] = u, d
    end
    g.head = g:CreateTexture(nil, "OVERLAY")
    g.head:SetColorTexture(1, 1, 1, 0.8)
    g.head:SetSize(1, h)
    g.head:Hide()
    -- sample(i) gives the column's left and right (0-1)
    function g:Draw(sample)
        local half = h / 2 - 2
        for i = 1, columns do
            local l, r = sample(i)
            g.up[i]:SetHeight(max(0.01, (l or 0) * half))
            g.down[i]:SetHeight(max(0.01, (r or 0) * half))
            g.up[i]:SetShown((l or 0) > 0.001)
            g.down[i]:SetShown((r or 0) > 0.001)
        end
    end
    function g:Head(fraction)
        if not fraction then return g.head:Hide() end
        g.head:ClearAllPoints()
        g.head:SetPoint("TOPLEFT", fraction * w, 0)
        g.head:Show()
    end
    return g
end

-- A text box in a small window (the report, export, import)
local textWin
local function TextWindow(title, text, onAccept, acceptLabel)
    if not textWin then
        textWin = CreateFrame("Frame", "GamepadCompanionBetaText", Shell.Window())
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
        UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionBetaText"
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

-- A grid of feels to pick from
local picker
local function PickFeel(anchor, current, onPick)
    if not picker then
        picker = CreateFrame("Frame", "GamepadCompanionBetaFeels", Shell.Window())
        picker:SetFrameStrata("DIALOG")
        picker:SetToplevel(true)
        picker:EnableMouse(true)
        S.Panel(picker)
        picker.tiles = {}
        picker:Hide()
        UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionBetaFeels"
    end
    if picker:IsShown() and picker.anchor == anchor then return picker:Hide() end
    picker.anchor = anchor
    local feels = H.AllFeels()
    local cols, tw, th = 8, 104, 26
    for _, t in ipairs(picker.tiles) do t:Hide() end
    for i, f in ipairs(feels) do
        local t = picker.tiles[i]
        if not t then
            t = S.NewButton(picker, "", 0, 0, tw, nil, nil, 10, th)
            t.icon = t:CreateTexture(nil, "OVERLAY")
            t.icon:SetSize(18, 18)
            t.icon:SetPoint("LEFT", 4, 0)
            t.label:ClearAllPoints()
            t.label:SetPoint("LEFT", 24, 0)
            t.label:SetPoint("RIGHT", -3, 0)
            t.label:SetJustifyH("LEFT")
            picker.tiles[i] = t
        end
        local col, row = (i - 1) % cols, floor((i - 1) / cols)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 12 + col * (tw + 3), -12 - row * (th + 3))
        t.label:SetText(f.label or f.key)
        t.icon:SetTexture(f.icon or "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_pulse")
        S.SetSelected(t, f.key == current)
        t:SetScript("OnClick", function()
            picker:Hide()
            onPick(f.key)
        end)
        t:Show()
    end
    local rows = math.ceil(#feels / cols)
    picker:SetSize(24 + cols * (tw + 3), 24 + rows * (th + 3))
    picker:ClearAllPoints()
    picker:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 8)
    picker:SetClampedToScreen(true)
    picker:Show()
    picker:Raise()
end

local function Play(key, loop)
    local feel = H.Feel(key)
    if not feel then return end
    local strength = 0.8
    pcall(function() strength = ns.Rumble.Settings().intensity end)
    H.Play(feel, { voice = "beta", gain = strength, loop = loop })
    Say((feel.label or key) .. (loop and " · looping" or ""))
end

-- The trigger test window: squeeze L2 or R2, each squeeze the next variation
local trigWin
local function TriggerWindow()
    if not trigWin then
        local f = CreateFrame("Frame", "GamepadCompanionTriggerTest", Shell.Window())
        trigWin = f
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:SetSize(600, 120 + #L.TRIGGER_TESTS * 34)
        f:SetPoint("CENTER")
        S.Panel(f)
        S.Text(f, "Trigger test", 16, -14, 400, 15, YELLOW)
        S.Text(f, "Squeeze L2 or R2: each squeeze plays the next one", 16, -38, 560, 12, GREY)
        f.status = S.Text(f, "", 16, -58, 560, 12, GOLD)
        -- live depth of each trigger
        f.bars = {}
        for side = 1, 2 do
            S.Text(f, side == 1 and "L2" or "R2", 380 + (side - 1) * 110, -14, 30, 12, GOLD)
            local bg = f:CreateTexture(nil, "ARTWORK")
            bg:SetColorTexture(1, 1, 1, 0.12)
            bg:SetPoint("TOPLEFT", 404 + (side - 1) * 110, -17)
            bg:SetSize(70, 8)
            local bar = f:CreateTexture(nil, "OVERLAY")
            local c = side == 1 and LEFT_C or RIGHT_C
            bar:SetColorTexture(c[1], c[2], c[3], 0.95)
            bar:SetPoint("TOPLEFT", 404 + (side - 1) * 110, -17)
            bar:SetSize(1, 8)
            f.bars[side] = bar
        end
        S.Text(f, "L2", 392, -84, 60, 12, YELLOW)
        S.Text(f, "R2", 492, -84, 60, 12, YELLOW)
        f.rows = {}
        for i, t in ipairs(L.TRIGGER_TESTS) do
            local y = -104 - (i - 1) * 34
            local row = { test = t, marks = {} }
            row.label = S.Text(f, i .. ".  " .. t.label, 16, y - 7, 340, 12, GOLD)
            for side = 1, 2 do
                local b = S.NewButton(f, "?", 370 + (side - 1) * 100, y, 92, nil, nil, 11, 28)
                b:SetScript("OnClick", function()
                    local cur = L.TriggerAnswers(t.key)[side == 1 and "L2" or "R2"] or "?"
                    local n = 1
                    for k, a in ipairs(L.TRIGGER_ANSWERS) do if a == cur then n = k end end
                    L.TriggerAnswer(t.key, side, L.TRIGGER_ANSWERS[n % #L.TRIGGER_ANSWERS + 1])
                    trigWin.Update()
                end)
                S.Tooltip(b, t.label, "Click: Trigger, Grip, Nothing")
                row.marks[side] = b
            end
            f.rows[i] = row
        end
        S.NewButton(f, "Close", 470, -(120 + #L.TRIGGER_TESTS * 34 - 44), 112, function() f:Hide() end, nil, 12, 30)
        function f.Update()
            local tt = L.trigger
            for i, row in ipairs(f.rows) do
                local a = L.TriggerAnswers(row.test.key)
                for side = 1, 2 do
                    local b = row.marks[side]
                    b.label:SetText(a[side == 1 and "L2" or "R2"] or "?")
                    S.SetSelected(b, tt.index[side] == i)
                end
            end
            if tt.noAxes then f.status:SetText("|cffff7a5cNo trigger reading from the pad|r") end
        end
        f:SetScript("OnUpdate", function()
            local tt = L.trigger
            for side = 1, 2 do f.bars[side]:SetWidth(math.max(1, (tt.depth[side] or 0) * 70)) end
        end)
        f:SetScript("OnShow", function() L.TriggerTest(true); f.status:SetText(""); f.Update() end)
        f:SetScript("OnHide", function() L.TriggerTest(false) end)
        L.onTrigger = function(side, index)
            f.status:SetText(string.format("%s:  %d. %s", side == 1 and "L2" or "R2", index, L.TRIGGER_TESTS[index].label))
            f.Update()
        end
        UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionTriggerTest"
        f:Hide()
    end
    trigWin:Show()
    trigWin:Raise()
end

---------------------------------------------------------------------------
-- Probes
---------------------------------------------------------------------------
local probe = { index = 1, step = 1 }

local function BuildProbes(p)
    local list = S.Card(p, "Probes", 0, 0, 300, PH - 40)
    probe.rows = {}
    for i, pr in ipairs(L.PROBES) do
        local b = S.NewButton(list, pr.label, 12, -40 - (i - 1) * 34, 276, function()
            L.Halt()
            probe.playing = false
            probe.index, probe.step = i, 1
            Refresh()
        end, nil, 12, 30)
        b.label:SetJustifyH("LEFT")
        b.count = S.Text(b, "", 0, 0, 50, 11, GREY)
        b.count:ClearAllPoints()
        b.count:SetPoint("RIGHT", -8, 0)
        b.count:SetJustifyH("RIGHT")
        probe.rows[i] = b
    end
    local trig = S.NewButton(list, "Trigger test", 12, -(PH - 40 - 84), 276, function() TriggerWindow() end, nil, 12, 30)
    S.Tooltip(trig, "Trigger test", "Squeeze L2 / R2 in a window")
    S.NewButton(list, "Report", 12, -(PH - 40 - 46), 276, function()
        TextWindow("Probe report", L.Report())
    end, nil, 12, 30)

    local card = S.Card(p, "", 312, 0, W - 312, PH - 40)
    probe.title = S.Text(card, "", 16, -14, 600, 16, YELLOW)
    probe.stepName = S.Text(card, "", 16, -48, 500, 14, GOLD)
    probe.ask = S.Text(card, "", 16, -74, 900, 13, GREY)
    probe.play = S.NewButton(card, "Play", 16, -104, 160, function()
        local pr = L.PROBES[probe.index]
        local step = pr.steps[probe.step]
        if not step then return end
        probe.playing = true
        Say(pr.label .. ": " .. step[1])
        local index = probe.step
        L.Run(step[2](), function()
            probe.playing = false
            L.KeepMeasured(pr, index)
            Refresh()
        end)
        Refresh()
    end, nil, 14, 34)
    probe.stop = S.NewButton(card, "Stop", 184, -104, 100, function() L.Halt(); probe.playing = false; Refresh() end,
        nil, 13, 34)
    probe.answers = {}
    for i = 1, 4 do
        probe.answers[i] = S.NewButton(card, "", 16 + (i - 1) * 154, -150, 148, nil, nil, 13, 34)
    end
    probe.back = S.NewButton(card, "Previous", 16, -196, 120, function()
        probe.step = max(1, probe.step - 1); Refresh()
    end, nil, 12, 28)
    probe.next = S.NewButton(card, "Next", 144, -196, 120, function()
        probe.step = min(#L.PROBES[probe.index].steps, probe.step + 1); Refresh()
    end, nil, 12, 28)
    probe.fps = S.NewButton(card, "Cap 60 fps", 300, -196, 140, function()
        L.FpsCap(not L.FpsCapped())
        Say(L.FpsCapped() and "60 fps cap on" or "Frame cap restored")
        Refresh()
    end, nil, 12, 28)
    S.Tooltip(probe.fps, "Cap 60 fps", "Game setting maxFPS · put back on a second click")
    ui.refresh[#ui.refresh + 1] = function()
        probe.fps.label:SetText(L.FpsCapped() and "Restore fps" or "Cap 60 fps")
        S.SetSelected(probe.fps, L.FpsCapped())
    end
    S.Heading(card, "Answers", 12, -244, W - 340)
    probe.lines = {}
    for i = 1, 10 do
        probe.lines[i] = S.Text(card, "", 16, -268 - (i - 1) * 18, 420, 12, GREY)
    end
    S.Heading(card, "Pad", 470, -244, 300)
    probe.facts = {}
    for i = 1, 6 do probe.facts[i] = S.Text(card, "", 474, -268 - (i - 1) * 18, 320, 12, GREY) end

    ui.refresh[#ui.refresh + 1] = function()
        local pr = L.PROBES[probe.index]
        local answers = L.Answers(pr)
        for i, b in ipairs(probe.rows) do
            S.SetSelected(b, i == probe.index)
            local a, n = L.Answers(L.PROBES[i]), 0
            for k = 1, #L.PROBES[i].steps do if a[k] then n = n + 1 end end
            b.count:SetText(n .. "/" .. #L.PROBES[i].steps)
        end
        local step = pr.steps[probe.step]
        probe.title:SetText(pr.label)
        probe.stepName:SetText(string.format("%d/%d  %s", probe.step, #pr.steps, step and step[1] or ""))
        probe.ask:SetText((pr.how and (pr.how .. "   ·   ") or "") .. pr.ask)
        probe.play.label:SetText(probe.playing and "Playing..." or (answers[probe.step] and "Play again" or "Play"))
        for i, b in ipairs(probe.answers) do
            local text = pr.answers[i]
            b:SetShown(text ~= nil)
            if text then
                b.label:SetText(text)
                S.SetSelected(b, answers[probe.step] == text)
                b:SetScript("OnClick", function()
                    L.Answer(pr, probe.step, text)
                    if probe.step < #pr.steps then probe.step = probe.step + 1 end
                    Refresh()
                end)
            end
        end
        probe.back:SetEnabled(probe.step > 1)
        probe.next:SetEnabled(probe.step < #pr.steps)
        for i, line in ipairs(probe.lines) do
            local s = pr.steps[i]
            local real = answers.lengths and answers.lengths[i]
            line:SetText(s and (s[1] .. ":  " .. (answers[i] or "-") .. (real and ("   ·  real " .. real) or "")) or "")
            local c = (s and answers[i]) and GOLD or DIM
            line:SetTextColor(c[1], c[2], c[3])
        end
        local facts = L.Facts()
        for i, f in ipairs(probe.facts) do f:SetText(facts[i] and (facts[i][1] .. ":  " .. facts[i][2]) or "") end
    end
end

---------------------------------------------------------------------------
-- Calibrate
---------------------------------------------------------------------------
local calib = {}

local function BuildCalibrate(p)
    local db = function() return H.DB() end
    for side = 1, 2 do
        local x = (side - 1) * 370
        local card = S.Card(p, side == 1 and "Left grip" or "Right grip", x, 0, 360, PH - 40)
        local c = { side = side }
        calib[side] = c
        Stepper(card, "Floor", 14, -44, { get = function() return db().floor[side] end,
            set = function(v) db().floor[side] = min(v, db().ceil[side] - 0.05) end, step = 0.01, min = 0, max = 0.9 })
        Stepper(card, "Ceiling", 14, -74, { get = function() return db().ceil[side] end,
            set = function(v) db().ceil[side] = max(v, db().floor[side] + 0.05) end, step = 0.01, min = 0.1, max = 1 })
        Stepper(card, "Curve", 14, -104, { get = function() return db().gamma[side] end,
            set = function(v) db().gamma[side] = v end, step = 0.05, min = 0.3, max = 3 })
        c.find = S.NewButton(card, "Find floor", 14, -144, 160, function()
            if L.Ramping() and calib.active == c and calib.mode == "floor" then
                db().floor[side] = floor(L.StopRamp() * 100 + 0.5) / 100
                if db().ceil[side] <= db().floor[side] then db().ceil[side] = 1 end
                calib.active = nil
                Say("Floor: " .. db().floor[side])
            else
                calib.active, calib.mode = c, "floor"
                L.StartRamp(side, 0, 8)
                Say("Rising: Felt it as soon as you feel it")
            end
            Refresh()
        end, nil, 13, 32)
        c.ceil = S.NewButton(card, "Find ceiling", 182, -144, 160, function()
            if L.Ramping() and calib.active == c and calib.mode == "ceil" then
                db().ceil[side] = max(db().floor[side] + 0.05, floor(L.StopRamp() * 100 + 0.5) / 100)
                calib.active = nil
                Say("Ceiling: " .. db().ceil[side])
            else
                calib.active, calib.mode = c, "ceil"
                L.StartRamp(side, db().floor[side], 6)
                Say("Rising: No stronger when it stops growing")
            end
            Refresh()
        end, nil, 13, 32)
        S.NewButton(card, "Test steps", 14, -184, 160, function()
            H.Stop()
            local keys = {}
            for i = 0, 9 do keys[#keys + 1] = { i * 0.3, (i + 1) / 10, "hold" } end
            keys[#keys + 1] = { 3, 0 }
            local zero = { { 0, 0 }, { 3, 0 } }
            H.Play({ keys = side == 1 and { left = keys, right = zero } or { left = zero, right = keys } }, { voice = "beta" })
            Say("10% to 100%: each step stronger?")
        end, nil, 13, 32)
        S.NewButton(card, "Reset", 182, -184, 160, function()
            db().floor[side], db().ceil[side], db().gamma[side] = H.DEFAULTS.floor[side], 1, 1
            Refresh()
        end, nil, 13, 32)
        c.graph = Graph(card, 14, -236, 330, 150, 66)
        S.Text(card, "Sent for 0 to 100%", 14, -392, 200, 11, DIM)
        c.level = S.Text(card, "", 14, -420, 330, 14, YELLOW)
    end
    L.onRampEnd = function() calib.active = nil; Refresh() end
    -- Live level while ramping
    local tick = CreateFrame("Frame", nil, p)
    tick:SetScript("OnUpdate", function()
        for side = 1, 2 do
            local c = calib[side]
            if L.Ramping() and L.ramp.side == side then
                c.level:SetText(string.format("Sending %.0f%%", L.ramp.level * 100))
            else
                c.level:SetText("")
            end
        end
    end)
    ui.refresh[#ui.refresh + 1] = function()
        for side = 1, 2 do
            local c = calib[side]
            local active = calib.active == c and L.Ramping()
            c.find.label:SetText(active and calib.mode == "floor" and "Felt it" or "Find floor")
            c.ceil.label:SetText(active and calib.mode == "ceil" and "No stronger" or "Find ceiling")
            S.SetSelected(c.find, active and calib.mode == "floor")
            S.SetSelected(c.ceil, active and calib.mode == "ceil")
            c.graph:Draw(function(i)
                local v = H.Calibrated(side, (i - 1) / (c.graph.columns - 1))
                if side == 1 then return v, 0 end
                return 0, v
            end)
        end
    end
    local info = S.Card(p, "How", 740, 0, W - 740, PH - 40)
    local lines = { "Find floor: press when first felt", "Find ceiling: press when it stops growing",
        "Curve: below 1 lifts soft levels", "Test steps: ten even steps", "Used by the Beta engine only" }
    for i, t in ipairs(lines) do S.Text(info, t, 14, -44 - (i - 1) * 22, W - 770, 12, GREY) end
end

---------------------------------------------------------------------------
-- Feels: the library and the player's own
---------------------------------------------------------------------------
local feelsUI = {}

local function FeelTile(parent, x, y, w)
    local t = S.NewButton(parent, "", x, y, w, nil, nil, 11, 30)
    t.icon = t:CreateTexture(nil, "OVERLAY")
    t.icon:SetSize(20, 20)
    t.icon:SetPoint("LEFT", 5, 0)
    t.label:ClearAllPoints()
    t.label:SetPoint("LEFT", 28, 0)
    t.label:SetPoint("RIGHT", -3, 0)
    t.label:SetJustifyH("LEFT")
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return t
end

local OpenEditor   -- set below

local function BuildFeels(p)
    local groups = {}
    for _, g in ipairs(L.GROUPS) do groups[#groups + 1] = g end
    groups[#groups + 1] = "Yours"
    local tw, cols = 108, 9
    feelsUI.rows = {}
    for gi, g in ipairs(groups) do
        local y = -(gi - 1) * 40
        S.Text(p, g, 4, y - 9, 86, 12, YELLOW)
        local row = { group = g, tiles = {} }
        for c = 1, cols do
            local t = FeelTile(p, 92 + (c - 1) * (tw + 3), y, tw)
            t:SetScript("OnClick", function(self, button)
                if not self.key then return end
                if button == "RightButton" then return OpenEditor(self.key) end
                Play(self.key, (IsShiftKeyDown and IsShiftKeyDown()) or nil)
                feelsUI.selected = self.key
                Refresh()
            end)
            row.tiles[c] = t
        end
        feelsUI.rows[gi] = row
    end
    local y = -(#groups) * 40 - 6
    S.NewButton(p, "Stop", 92, y, 120, function() H.Stop("beta"); Say("Stopped") end, nil, 12, 28)
    S.NewButton(p, "Edit a copy", 220, y, 120, function()
        if feelsUI.selected then OpenEditor(feelsUI.selected, true) end
    end, nil, 12, 28)
    feelsUI.note = S.Text(p, "Click: play · Shift: loop · Right-click: edit", 352, y - 7, 500, 11, DIM)
    ui.refresh[#ui.refresh + 1] = function()
        local byGroup = {}
        for _, f in ipairs(H.AllFeels()) do
            local g = H.IsOwn(f.key) and "Yours" or f.group or "Yours"
            byGroup[g] = byGroup[g] or {}
            table.insert(byGroup[g], f)
        end
        for _, row in ipairs(feelsUI.rows) do
            local list = byGroup[row.group] or {}
            for c, t in ipairs(row.tiles) do
                local f = list[c]
                t:SetShown(f ~= nil)
                if f then
                    t.key = f.key
                    t.label:SetText(f.label or f.key)
                    t.icon:SetTexture(f.icon or "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_pulse")
                    S.SetSelected(t, f.key == feelsUI.selected)
                    S.Tooltip(t, f.label or f.key, string.format("%.2f s%s", H.Length(f), f.loop and " · loop" or ""))
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Editor
---------------------------------------------------------------------------
local ed = { key = nil }
local VIEW_MIN = 1

local function Feel() return ed.key and H.Feel(ed.key) end
local function Own() return ed.key and H.IsOwn(ed.key) end

local function SaveOwn(feel, label)
    local key = H.NewKey()
    feel = H.Copy(feel)
    feel.key, feel.group = nil, nil
    feel.label = label or feel.label or "Mine"
    feel.icon = feel.icon or "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_pulse"
    H.DB().feels[key] = feel
    if L.RegisterInRumble then L.RegisterInRumble() end
    return key
end

OpenEditor = function(key, copy)
    if copy or (key and not H.IsOwn(key)) then
        local src = H.Feel(key)
        if src then key = SaveOwn(src, (src.label or "Feel") .. " copy") end
    end
    ed.key = key
    ui.Select("editor")
end

local function View()
    -- (fixed while dragging: the last key would push it away)
    if ed.drag and ed.drag.view then return ed.drag.view end
    local f = Feel()
    if not f then return VIEW_MIN end
    return max(VIEW_MIN, H.Length(f) * 1.15)
end

-- Shape to keyframes (the envelope sampled, then simplified)
local SHAPE_FIELDS = { "attack", "hold", "decay", "peak", "curve", "grain", "noise", "sparks", "bed", "pan", "panTo",
    "panRate", "panDepth", "kick" }

-- A feel's mode in the editor
local function ModeOf(f)
    return f and (f.pulses and "pulses" or f.keys and "keys" or "shape") or nil
end

-- Any feel to pulses: a pulse wherever it is felt, on a 60 ms grid
local function ToPulses(f)
    local len = H.Length(f)
    local plain = H.Copy(f)
    plain.loop = false
    local list = {}
    for t = 0, len - 0.001, 0.06 do
        local l, r = H.Sample(plain, t + 0.001, 1)
        local s = max(l or 0, r or 0)
        if s > 0.04 then
            local side = s > 0 and ((r or 0) - (l or 0)) / s or 0
            list[#list + 1] = { t, 0.05, s, max(-1, min(1, side)) }
        end
    end
    if #list == 0 then list[1] = { 0, 0.06, 0.4, 0 } end
    for _, k in ipairs(SHAPE_FIELDS) do f[k] = nil end
    f.keys, f.pulses = nil, list
    if f.loop then f.length = len end
end

local function ToKeys(f)
    local len = H.Length(f)
    local plain = H.Copy(f)
    plain.grain, plain.noise, plain.sparks, plain.loop, plain.keys = nil, nil, nil, false, nil
    local left, right = {}, {}
    local n = max(8, floor(len / 0.02))
    for i = 0, n do
        local t = len * i / n
        local l, r = H.Sample(plain, min(t, len - 0.0001), 1)
        left[#left + 1] = { t, l or 0 }
        right[#right + 1] = { t, r or 0 }
    end
    f.keys = { left = H.Simplify(left, 0.01), right = H.Simplify(right, 0.01) }
    f.pan, f.panTo, f.panRate, f.kick = nil, nil, nil, nil
    f.pulses, f.length = nil, nil
end

local DRAG_R = 6
local function CanvasPoint(canvas)
    local x, y = GetCursorPosition()
    local scale = canvas:GetEffectiveScale()
    x, y = x / scale, y / scale
    local left, bottom = canvas:GetLeft(), canvas:GetBottom()
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    return (x - left) / w, (y - bottom) / h
end

local function KeyList(side, create)
    local f = Feel()
    if not (f and f.keys) then return nil end
    if side == "right" and not f.keys.right and create then f.keys.right = H.Copy(f.keys.left) end
    return f.keys[side] or (side == "right" and f.keys.left) or nil
end

-- Stable: two keys at one moment make a step and keep their order
local function SortKeys(list)
    for i, k in ipairs(list) do k.order = i end
    table.sort(list, function(a, b)
        if a[1] ~= b[1] then return a[1] < b[1] end
        return a.order < b.order
    end)
    for _, k in ipairs(list) do k.order = nil end
end

local function BuildEditor(p)
    -- Left: the player's feels
    local list = S.Card(p, "Yours", 0, 0, 210, PH - 40)
    ed.items = {}
    for i = 1, 12 do
        local b = S.NewButton(list, "", 10, -38 - (i - 1) * 30, 190, nil, nil, 11, 28)
        b.label:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self) if self.key then ed.key, ed.sel = self.key, nil; Refresh() end end)
        ed.items[i] = b
    end
    S.NewButton(list, "New", 10, -(PH - 40 - 116), 92, function()
        ed.key = SaveOwn({ label = "New feel", pulses = { { 0, 0.06, 0.4, 0 } } }, "New feel")
        ed.sel = nil
        Refresh()
    end, nil, 12, 28)
    S.NewButton(list, "Copy", 108, -(PH - 40 - 116), 92, function()
        if Feel() then ed.key = SaveOwn(Feel(), (Feel().label or "Feel") .. " copy"); Refresh() end
    end, nil, 12, 28)
    ed.delete = S.NewButton(list, "Delete", 10, -(PH - 40 - 84), 92, function()
        if Own() then
            H.DB().feels[ed.key] = nil
            ed.key = nil
            Refresh()
        end
    end, nil, 12, 28)
    S.NewButton(list, "Import", 108, -(PH - 40 - 84), 92, function()
        TextWindow("Import a feel: paste its line", "", function(text)
            local feel, why = H.Import(text)
            if not feel then return Say("Not imported: " .. tostring(why), true) end
            ed.key = SaveOwn(feel, feel.label)
            Refresh()
        end, "Import")
    end, nil, 12, 28)
    S.NewButton(list, "Export", 10, -(PH - 40 - 52), 190, function()
        if Feel() then TextWindow("Export: copy this line", H.Export(Feel())) end
    end, nil, 12, 28)

    -- Middle: name, canvas, transport
    local mid = S.Card(p, "", 220, 0, 560, PH - 40)
    ed.name = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    ed.name:SetPoint("TOPLEFT", 20, -10)
    ed.name:SetSize(220, 24)
    ed.name:SetAutoFocus(false)
    ed.name:SetMaxLetters(24)
    ed.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    ed.name:SetScript("OnEditFocusLost", function(self)
        if Own() then Feel().label = self:GetText(); if L.RegisterInRumble then L.RegisterInRumble() end end
        Refresh()
    end)
    ed.length = S.Text(mid, "", 452, -15, 100, 12, GREY)
    ed.mode = Choice(mid, "", 132, -8, { { "pulses", "Pulses" }, { "keys", "Keys" }, { "shape", "Shape" } }, function()
        return ModeOf(Feel())
    end, function(v)
        local f = Feel()
        if not (f and Own()) or v == ModeOf(f) then return end
        ed.sel = nil
        if v == "pulses" then ToPulses(f)
        elseif v == "keys" then ToKeys(f)
        else
            f.keys, f.pulses, f.length = nil, nil, nil
            f.attack, f.hold, f.decay, f.peak = f.attack or 0.05, f.hold or 0.3, f.decay or 0.2, f.peak or 0.7
        end
    end, 54)
    ed.canvas = Graph(mid, 10, -44, 540, 300, 180)
    ed.canvas:EnableMouse(true)
    ed.canvas.points = {}
    S.Text(mid, "Left grip", 14, -48, 100, 10, LEFT_C)
    S.Text(mid, "Right grip", 14, -330, 100, 10, RIGHT_C)
    ed.hint = S.Text(mid, "", 10, -350, 540, 11, DIM)

    local function ValueAt(fy)
        -- top half: left grip (up), bottom half: right grip (down)
        if fy >= 0.5 then return "left", min(1, max(0, (fy - 0.5) * 2)) end
        return "right", min(1, max(0, (0.5 - fy) * 2))
    end

    -- (a pulse's handle: its start and strength, above the line for the left
    -- grip or both, below for the right)
    local function PulseY(p, hgt)
        local up = (p[4] or 0) <= 0
        return up and (hgt / 2 + p[3] * (hgt / 2 - 2)) or (hgt / 2 - p[3] * (hgt / 2 - 2))
    end

    ed.canvas:SetScript("OnMouseDown", function(self, button)
        local f = Feel()
        if f and f.pulses and Own() and button == "LeftButton" then
            local fx, fy = CanvasPoint(self)
            local view = View()
            local side = ed.newSide or 0
            local p = { max(0, fx * view), 0.06, max(0.05, min(1, math.abs(fy - 0.5) * 2)), side }
            f.pulses[#f.pulses + 1] = p
            table.sort(f.pulses, function(a, b) return a[1] < b[1] end)
            ed.sel = p
            ed.drag = { pulse = p, view = view }
            Refresh()
            return
        end
        if not (f and f.keys and Own()) or button ~= "LeftButton" then return end
        local fx, fy = CanvasPoint(self)
        local side, v = ValueAt(fy)
        local list = KeyList(side, true)
        local view = View()
        local key = { max(0, fx * view), v }
        list[#list + 1] = key
        SortKeys(list)
        ed.drag = { list = list, key = key, side = side, view = view }
        Refresh()
    end)
    ed.canvas:SetScript("OnMouseUp", function() ed.drag = nil end)
    ed.canvas:SetScript("OnUpdate", function(self)
        local d = ed.drag
        if d and d.pulse and IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
            local fx, fy = CanvasPoint(self)
            d.pulse[1] = max(0, min(30, fx * View()))
            d.pulse[3] = max(0.05, min(1, math.abs(fy - 0.5) * 2))
            local f = Feel()
            if f and f.pulses then table.sort(f.pulses, function(a, b) return a[1] < b[1] end) end
            ed.Draw()
        elseif d and IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
            local fx, fy = CanvasPoint(self)
            local _, v = ValueAt(fy)
            if d.side == "right" then v = min(1, max(0, (0.5 - fy) * 2)) else v = min(1, max(0, (fy - 0.5) * 2)) end
            d.key[1] = max(0, min(30, fx * View()))
            d.key[2] = v
            SortKeys(d.list)
            ed.Draw()
        elseif d then
            ed.drag = nil
            Refresh()
        end
        -- playhead
        if H.Playing("editor") and ed.started then
            local f = Feel()
            local t = Now() - ed.started
            if f and (f.loop or ed.loop) then t = t % (H.Length(f) + (ed.loop and not f.loop and 0.12 or 0)) end
            self:Head(min(1, t / View()))
        else
            self:Head(nil)
        end
    end)

    -- Key handles for dragging and deleting
    local function Handle(i)
        local h = ed.canvas.points[i]
        if h then return h end
        h = CreateFrame("Button", nil, ed.canvas)
        h:SetSize(DRAG_R * 2, DRAG_R * 2)
        h:SetFrameLevel((ed.canvas:GetFrameLevel() or 1) + 5)
        h.tex = h:CreateTexture(nil, "OVERLAY")
        h.tex:SetAllPoints()
        h.tex:SetColorTexture(1, 1, 1, 0.9)
        h:RegisterForClicks("RightButtonUp")
        h:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            if self.pulse then
                ed.sel = self.pulse
                ed.drag = { pulse = self.pulse, view = View() }
                Refresh()
                return
            end
            ed.drag = { list = self.list, key = self.key, side = self.side, view = View() }
        end)
        h:SetScript("OnClick", function(self)
            for k, key in ipairs(self.list) do
                if key == (self.pulse or self.key) and #self.list > 1 then table.remove(self.list, k); break end
            end
            if ed.sel == self.pulse then ed.sel = nil end
            Refresh()
        end)
        h:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.pulse then
                local p = self.pulse
                GameTooltip:SetText(string.format("%.2f s  ·  %d ms  ·  %d%%", p[1], p[2] * 1000 + 0.5, p[3] * 100 + 0.5),
                    1, 0.82, 0)
                GameTooltip:AddLine("Drag · Right-click: delete · Wheel: length", 1, 1, 1)
                GameTooltip:Show()
                return
            end
            GameTooltip:SetText(string.format("%.2f s  ·  %d%%", self.key[1], self.key[2] * 100), 1, 0.82, 0)
            GameTooltip:AddLine("Drag · Right-click: delete · Wheel: ease", 1, 1, 1)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        h:EnableMouseWheel(true)
        h:SetScript("OnMouseWheel", function(self, delta)
            if self.pulse then
                self.pulse[2] = max(0.05, min(2, self.pulse[2] + (delta > 0 and 0.01 or -0.01)))
                Say(string.format("Length: %d ms", self.pulse[2] * 1000 + 0.5))
                Refresh()
                return
            end
            local eases = H.EASES
            local cur = 1
            for k, e in ipairs(eases) do if e == (self.key[3] or "linear") then cur = k end end
            cur = (cur - 1 + (delta > 0 and 1 or -1)) % #eases + 1
            self.key[3] = eases[cur] ~= "linear" and eases[cur] or nil
            Say("Ease: " .. eases[cur])
            Refresh()
        end)
        ed.canvas.points[i] = h
        return h
    end

    function ed.Draw()
        local f = Feel()
        local view = View()
        local cols = ed.canvas.columns
        if not f then
            ed.canvas:Draw(function() return 0, 0 end)
        else
            local plain = f
            if f.loop then plain = H.Copy(f); plain.loop = false end
            ed.canvas:Draw(function(i)
                local t = (i - 0.5) / cols * view
                local l, r = H.Sample(plain, t, 1)
                return l or 0, r or 0
            end)
        end
        for _, h in ipairs(ed.canvas.points) do h:Hide() end
        if f and f.pulses and Own() then
            local w, hgt = ed.canvas:GetWidth(), ed.canvas:GetHeight()
            for n, p in ipairs(f.pulses) do
                local h = Handle(n)
                h.list, h.pulse, h.key, h.side = f.pulses, p, nil, nil
                h:ClearAllPoints()
                h:SetPoint("CENTER", ed.canvas, "BOTTOMLEFT", p[1] / view * w, PulseY(p, hgt))
                local side = p[4] or 0
                local c = side < -0.3 and LEFT_C or side > 0.3 and RIGHT_C or { 1, 1, 1 }
                h.tex:SetColorTexture(c[1], c[2], c[3], 1)
                h:SetSize(ed.sel == p and DRAG_R * 3 or DRAG_R * 2, ed.sel == p and DRAG_R * 3 or DRAG_R * 2)
                h:Show()
            end
        elseif f and f.keys and Own() then
            local n, w, hgt = 0, ed.canvas:GetWidth(), ed.canvas:GetHeight()
            for _, side in ipairs({ "left", "right" }) do
                local list = f.keys[side]
                if list then
                    for _, key in ipairs(list) do
                        n = n + 1
                        local h = Handle(n)
                        h.list, h.key, h.side, h.pulse = list, key, side, nil
                        h:SetSize(DRAG_R * 2, DRAG_R * 2)
                        local y = side == "left" and (hgt / 2 + key[2] * (hgt / 2 - 2)) or (hgt / 2 - key[2] * (hgt / 2 - 2))
                        h:ClearAllPoints()
                        h:SetPoint("CENTER", ed.canvas, "BOTTOMLEFT", key[1] / view * w, y)
                        local c = side == "left" and LEFT_C or RIGHT_C
                        h.tex:SetColorTexture(c[1], c[2], c[3], 1)
                        h:Show()
                    end
                end
            end
        end
    end

    local ty = -380
    ed.playB = S.NewButton(mid, "Play", 10, ty, 100, function()
        local f = Feel()
        if not f then return end
        ed.started = Now()
        H.Play(f, { voice = "editor", loop = ed.loop or nil })
    end, nil, 13, 32)
    ed.loopB = S.NewButton(mid, "Loop", 116, ty, 80, function() ed.loop = not ed.loop; Refresh() end, nil, 12, 32)
    S.NewButton(mid, "Stop", 202, ty, 80, function() H.Stop("editor"); H.Stop("record"); ed.recording = nil; Refresh() end,
        nil, 12, 32)
    ed.recB = S.NewButton(mid, "Record L2 R2", 288, ty, 140, function() ed.ToggleRecord() end, nil, 12, 32)
    S.Tooltip(ed.recB, "Record", "Tap a rhythm on L2 / R2: each squeeze a pulse · 6 s")
    ed.recInfo = S.Text(mid, "", 436, ty - 9, 120, 12, YELLOW)
    ed.sideRow = Choice(mid, "New pulses", 10, ty - 42, { { -1, "Left" }, { 0, "Both" }, { 1, "Right" } },
        function() return ed.newSide or 0 end, function(v) ed.newSide = v end, 70)
    ed.assign = S.Text(mid, "", 10, ty - 80, 540, 11, DIM)

    -- Right: parameters
    local right = S.Card(p, "Shape", 790, 0, W - 790, PH - 40)
    ed.right = right
    local function param(field, sub)
        return function()
            local f = Feel()
            if not f then return 0 end
            if sub then return f[sub] and f[sub][field] or 0 end
            return f[field] or 0
        end, function(v)
            local f = Feel()
            if not (f and Own()) then return end
            if field == "rateTo" and v == 0 then v = nil end
            if sub then
                f[sub] = f[sub] or { rate = 0, depth = 0 }
                f[sub][field] = v
            else
                f[field] = v
            end
        end
    end
    local function P(label, y, field, sub, step, lo, hi, fmt, shapeOnly)
        local get, set = param(field, sub)
        local row = Stepper(right, label, 10, y, { get = get, set = set, step = step, min = lo, max = hi, format = fmt,
            labelWidth = 92, width = 300 })
        row.modes = shapeOnly and { shape = true } or { shape = true, keys = true }
        ed.params = ed.params or {}
        ed.params[#ed.params + 1] = row
        return row
    end
    local secs = function(v) return string.format("%.2f s", v) end
    local pct = function(v) return string.format("%d%%", floor(v * 100 + 0.5)) end
    local hz = function(v) return string.format("%g Hz", v) end
    local y = -38
    local function nexty() local v = y; y = y - 25; return v end
    P("Attack", nexty(), "attack", nil, 0.02, 0, 5, secs, true)
    P("Hold", nexty(), "hold", nil, 0.02, 0, 5, secs, true)
    P("Decay", nexty(), "decay", nil, 0.02, 0, 5, secs, true)
    P("Peak", nexty(), "peak", nil, 0.05, 0, 1, pct, true)
    P("Curve", nexty(), "curve", nil, 0.1, 0.2, 5, nil, true)
    P("Kick", nexty(), "kick", nil, 0.01, 0, 0.1, secs)
    P("Grain", nexty(), "rate", "grain", 1, 0, 60, hz)
    P("Grain to", nexty(), "rateTo", "grain", 1, 0, 60, hz)
    P("Depth", nexty(), "depth", "grain", 0.05, 0, 1, pct)
    local wave = Stepper(right, "Wave", 10, nexty(), { labelWidth = 92, width = 300,
        list = { { "sine", "Sine" }, { "square", "Square" }, { "tri", "Triangle" }, { "saw", "Saw" }, { "ramp", "Ramp" } },
        get = function() local f = Feel(); return f and f.grain and f.grain.wave or "sine" end,
        set = function(v) local f = Feel(); if f and Own() then f.grain = f.grain or { rate = 0, depth = 0 }; f.grain.wave = v end end })
    wave.modes = { shape = true, keys = true }
    ed.params[#ed.params + 1] = wave
    P("Duty", nexty(), "duty", "grain", 0.05, 0.05, 0.95, pct)
    local alt = Stepper(right, "Alternate", 10, nexty(), { labelWidth = 92, width = 300,
        list = { { false, "Off" }, { true, "L / R" } },
        get = function() local f = Feel(); return f and f.grain and f.grain.alternate == true or false end,
        set = function(v) local f = Feel(); if f and Own() then f.grain = f.grain or { rate = 0, depth = 0 }; f.grain.alternate = v end end })
    alt.modes = { shape = true, keys = true }
    ed.params[#ed.params + 1] = alt
    P("Noise", nexty(), "noise", nil, 0.05, 0, 1, pct)
    P("Sparks", nexty(), "sparks", nil, 1, 0, 40, function(v) return v .. "/s" end)
    P("Spark bed", nexty(), "bed", nil, 0.05, 0, 1, pct)
    P("Pan", nexty(), "pan", nil, 0.1, -1, 1)
    P("Pan to", nexty(), "panTo", nil, 0.1, -1, 1)
    P("Pan sway", nexty(), "panRate", nil, 0.25, 0, 8, hz)
    local loopRow = Stepper(right, "Loops", 10, nexty(), { labelWidth = 92, width = 300,
        list = { { false, "No" }, { true, "Yes" } },
        get = function() local f = Feel(); return f and f.loop == true or false end,
        set = function(v) local f = Feel(); if f and Own() then f.loop = v end end })
    loopRow.modes = { shape = true, keys = true, pulses = true }
    ed.params[#ed.params + 1] = loopRow
    local duck = Stepper(right, "Ducks others", 10, nexty(), { labelWidth = 92, width = 300,
        list = { { 0, "No" }, { 0.4, "40%" }, { 0.7, "70%" }, { 1, "Fully" } },
        get = function() local f = Feel(); return f and f.duck and f.duck.amount or 0 end,
        set = function(v) local f = Feel(); if f and Own() then f.duck = v > 0 and { amount = v, time = 0.2 } or nil end end })
    duck.modes = { shape = true, keys = true, pulses = true }
    ed.params[#ed.params + 1] = duck

    -- Pulses: the one picked on the canvas, and the cycle
    local function pulseField(i)
        return function() return ed.sel and ed.sel[i] or 0 end,
            function(v) if ed.sel and Own() then ed.sel[i] = v end end
    end
    local function PR(label, py, i, step, lo, hi, fmt, list)
        local get, set = pulseField(i)
        local row = Stepper(right, label, 10, py, { get = get, set = set, step = step, min = lo, max = hi, format = fmt,
            list = list, labelWidth = 92, width = 300 })
        row.modes, row.needsPulse = { pulses = true }, true
        ed.params[#ed.params + 1] = row
    end
    PR("Time", -38, 1, 0.01, 0, 30, secs)
    PR("Length", -63, 2, 0.01, 0.05, 2, function(v) return string.format("%d ms", v * 1000 + 0.5) end)
    PR("Strength", -88, 3, 0.05, 0.05, 1, pct)
    PR("Side", -113, 4, 0.5, -1, 1, function(v)
        return v <= -0.75 and "Left" or v >= 0.75 and "Right" or math.abs(v) < 0.25 and "Both"
            or (v < 0 and "More left" or "More right")
    end)
    local cycle = Stepper(right, "Cycle", 10, -148, { labelWidth = 92, width = 300, step = 0.05, min = 0, max = 10,
        format = function(v) return v > 0 and string.format("%.2f s", v) or "To last" end,
        get = function() local f = Feel(); return f and f.length or 0 end,
        set = function(v) local f = Feel(); if f and Own() then f.length = v > 0 and v or nil end end })
    cycle.modes = { pulses = true }
    ed.params[#ed.params + 1] = cycle
    S.Tooltip(cycle, "Cycle", "A loop's length: silence after the last pulse")

    -- Recording with the triggers
    local rec = CreateFrame("Frame", nil, p)
    rec:Hide()
    local TriggerAxes = L.TriggerAxes
    function ed.ToggleRecord()
        if ed.recording then
            rec:Hide()
            H.Stop("record")
            local r = ed.recording
            ed.recording = nil
            -- Each squeeze a pulse: where it starts, how long, how deep; L2
            -- the left grip, R2 the right
            local pulses = {}
            for side, samples in ipairs({ r.left, r.right }) do
                local from, top
                for i = 1, #samples + 1 do
                    local s = samples[i]
                    local down = s and s[2] > 0.15
                    if down and not from then from, top = s[1], s[2]
                    elseif down then top = max(top, s[2])
                    elseif from then
                        local to = samples[i - 1][1]
                        pulses[#pulses + 1] = { from, max(0.05, to - from), top, side == 1 and -1 or 1 }
                        from = nil
                    end
                end
            end
            if #pulses == 0 then Say("Nothing squeezed", true); return Refresh() end
            table.sort(pulses, function(a, b) return a[1] < b[1] end)
            local first = pulses[1][1]
            for _, pl in ipairs(pulses) do pl[1] = pl[1] - first end
            ed.key = SaveOwn({ label = "Recorded", pulses = pulses }, "Recorded " .. date("%H:%M"))
            ed.sel = nil
            Say("Recorded: " .. #pulses .. " pulses")
            Refresh()
            return
        end
        if InCombatLockdown and InCombatLockdown() then return Say("Not in combat", true) end
        if not TriggerAxes() then return Say("No trigger axes", true) end
        ed.recording = { left = {}, right = {}, start = Now() }
        H.Stop("editor")
        rec:Show()
        Say("Recording: squeeze L2 / R2")
        Refresh()
    end
    rec:SetScript("OnUpdate", function()
        local r = ed.recording
        if not r then return rec:Hide() end
        local t = Now() - r.start
        local l, rr = TriggerAxes()
        if not l then return end
        r.left[#r.left + 1] = { t, l }
        r.right[#r.right + 1] = { t, rr }
        H.Set("record", l, rr)
        ed.recInfo:SetText(string.format("%.1f s", t))
        if t >= 6 then ed.ToggleRecord() end
    end)

    ui.refresh[#ui.refresh + 1] = function()
        -- the list
        local own = {}
        for _, f in ipairs(H.AllFeels()) do if H.IsOwn(f.key) then own[#own + 1] = f end end
        for i, b in ipairs(ed.items) do
            local f = own[i]
            b:SetShown(f ~= nil)
            if f then
                b.key = f.key
                b.label:SetText(f.label or f.key)
                S.SetSelected(b, f.key == ed.key)
            end
        end
        local f = Feel()
        local own_ = Own()
        if not ed.name:HasFocus() then ed.name:SetText(f and (f.label or f.key) or "") end
        ed.name:SetEnabled(own_ and true or false)
        ed.length:SetText(f and string.format("%.2f s%s", H.Length(f), f.loop and " · loop" or "") or "")
        ed.delete:SetEnabled(own_ and true or false)
        local mode = ModeOf(f) or "pulses"
        if ed.sel and not (f and f.pulses) then ed.sel = nil end
        for _, row in ipairs(ed.params or {}) do
            row:SetShown(row.modes[mode] == true)
            row:SetEnabled((own_ and (not row.needsPulse or ed.sel ~= nil)) and true or false)
        end
        ed.right.title:SetText(mode == "pulses" and "Pulse" or mode == "keys" and "Keys" or "Shape")
        ed.sideRow:SetShown(mode == "pulses" and own_ and true or false)
        S.SetSelected(ed.loopB, ed.loop)
        ed.recB.label:SetText(ed.recording and "Stop recording" or "Record L2 R2")
        S.SetSelected(ed.recB, ed.recording ~= nil)
        if not ed.recording then ed.recInfo:SetText("") end
        ed.hint:SetText(not f and "New, or pick one" or not own_ and "Library feel: Copy to edit"
            or f.pulses and "Click: add a pulse · Drag: time, strength · Right-click: delete · Wheel: length"
            or f.keys and "Click: add · Drag · Right-click: delete · Wheel on a point: ease"
            or "Pulses: what the pad keeps best")
        ed.assign:SetText(f and own_ and "In Rumble's grid and Events while the Beta engine is on" or "")
        ed.Draw()
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function BuildEvents(p)
    local cols = { { "Combat", "Resources" }, { "Moving", "World" }, { "Social", "Living" } }
    local colW = (W - 20) / 3
    local rows = {}
    for ci, groups in ipairs(cols) do
        local y = 0
        for _, g in ipairs(groups) do
            local events = {}
            for _, e in ipairs(L.EVENTS) do if e.group == g then events[#events + 1] = e end end
            local height = 40 + #events * 30
            local card = S.Card(p, g, (ci - 1) * (colW + 10), -y, colW, height)
            for i, e in ipairs(events) do
                local ry = -36 - (i - 1) * 30
                local check = S.NewCheck(card, e.label, 8, ry, function(self)
                    L.EventSettings(e.key).on = self:GetChecked() == true
                    Refresh()
                end, 140)
                local pick = S.NewButton(card, "", colW - 162, ry, 110, nil, nil, 11, 26)
                pick:SetScript("OnClick", function(self)
                    PickFeel(self, L.EventSettings(e.key).feel, function(key)
                        L.EventSettings(e.key).feel = key
                        L.Try(e.key)
                        Refresh()
                    end)
                end)
                local try = S.NewButton(card, "Try", colW - 48, ry, 40, function() L.Try(e.key) end, nil, 11, 26)
                rows[#rows + 1] = { e = e, check = check, pick = pick, try = try }
            end
            y = y + height + 10
        end
    end
    -- Footsteps sync, under Social and Living
    local fx = 2 * (colW + 10)
    local fy = -(2 * 40 + 6 * 30 + 20)
    local sync = S.Card(p, "Steps and landing", fx, fy, colW, 280)
    local gaits, buttons = { { "run", "Run" }, { "walk", "Walk" } }, {}
    for i, g in ipairs(gaits) do
        local y = -38 - (i - 1) * 32
        buttons[g[1]] = S.NewButton(sync, "Sync " .. g[2]:lower(), 12, y, 100, function()
            if L.sync then L.StepSyncCancel() else L.StepSync(g[1]) end
            Refresh()
        end, nil, 12, 28)
        S.Tooltip(buttons[g[1]], "Sync " .. g[2]:lower(), g[1] == "walk" and "Walk on, move, squeeze R2 on each footfall"
            or "Run, squeeze R2 on each footfall")
        g.text = S.Text(sync, "", 122, y - 8, colW - 134, 11, GREY)
    end
    local status = S.Note(sync, 12, -100, colW - 24, 1, 11, GOLD)
    local function Row(label, y, opts)
        opts.labelWidth, opts.width = 110, colW - 24
        return Stepper(sync, label, 12, y, opts)
    end
    local function rateRow(label, y, band)
        Row(label, y, { step = 0.02, min = 0.5, max = 5, format = function(v) return string.format("%.2f /s", v) end,
            get = function() return L.StepRate(band) end, set = function(v) L.SetStepRate(band, v) end })
    end
    rateRow("Run steps", -116, "run")
    rateRow("Walk steps", -140, "walk")
    Row("Nudge", -164, { step = 0.01, min = -0.5, max = 0.5,
        format = function(v) return string.format("%+d ms", floor(v * 1000 + 0.5)) end,
        get = function() return H.DB().stepNudge or 0 end, set = function(v) H.DB().stepNudge = v end })
    Row("Landing soft at", -188, { step = 0.05, min = 0.2, max = 3, format = function(v) return string.format("%.2f s", v) end,
        get = function() return H.DB().landMin or L.LAND_MIN end,
        set = function(v) local db = H.DB(); db.landMin = v; if (db.landMax or L.LAND_MAX) <= v then db.landMax = v + 0.05 end end })
    Row("Landing full at", -212, { step = 0.05, min = 0.25, max = 4, format = function(v) return string.format("%.2f s", v) end,
        get = function() return H.DB().landMax or L.LAND_MAX end,
        set = function(v) local db = H.DB(); db.landMax = v; if (db.landMin or L.LAND_MIN) >= v then db.landMin = v - 0.05 end end })
    Row("Landing longest", -236, { step = 0.05, min = 0.1, max = 1.5, format = function(v) return string.format("%.2f s", v) end,
        get = function() return H.DB().landLong or L.LAND_LONG end, set = function(v) H.DB().landLong = v end })
    local landed = S.Text(sync, "No landing yet", 12, -262, colW - 24, 11, GREY)
    L.onSync = function(text) status:SetText(text) end
    L.onLand = function(t, k, sent)
        local text = string.format("Last landing: %.2f s in the air, %d%%", t, floor(k * 100 + 0.5))
        if sent then
            text = text .. string.format(" · sent %d%% for %.2f s", floor(sent.peak * 100 + 0.5),
                max(0, sent.last - sent.start))
        end
        landed:SetText(text)
    end
    ui.refresh[#ui.refresh + 1] = function()
        for _, g in ipairs(gaits) do
            local cal = L.StepCal(g[1])
            g.text:SetText(cal and string.format("%.2f steps/s, first %.2f s", cal.rate, cal.offset) or "Not synced: a guess")
            local busy = L.sync and L.sync.band == g[1]
            buttons[g[1]].label:SetText(busy and "Cancel" or ("Sync " .. g[2]:lower()))
            S.SetSelected(buttons[g[1]], busy and true or false)
        end
    end

    local flash = {}
    L.onFire = function(key) flash[key] = Now() end
    ui.refresh[#ui.refresh + 1] = function()
        for _, r in ipairs(rows) do
            local s = L.EventSettings(r.e.key)
            r.check:SetChecked(s.on)
            local f = H.Feel(s.feel)
            r.pick.label:SetText(f and (f.label or f.key) or "?")
            r.pick:SetAlpha(s.on and 1 or 0.5)
        end
    end
end

---------------------------------------------------------------------------
-- Light
---------------------------------------------------------------------------
local function BuildLight(p)
    local card = S.Card(p, "Light bar", 0, 0, 420, PH - 40)
    local master = S.NewCheck(card, "Light bar on", 12, -40, function(self)
        H.DB().light = self:GetChecked() == true
        H.LightStop()
        L.ApplyBaseLight()
        Refresh()
    end, 140)
    local rows = {}
    for i, l in ipairs(L.LIGHTS) do
        local c = S.NewCheck(card, l.label, 12, -80 - (i - 1) * 30, function(self)
            H.DB().lights[l.key] = self:GetChecked() == true
            if l.key == "class" then L.ApplyBaseLight() end
            Refresh()
        end, 180)
        rows[#rows + 1] = { l = l, check = c }
    end
    local test = S.Card(p, "Try colours", 430, 0, 360, PH - 40)
    local colors = { { "Red", 1, 0, 0 }, { "Green", 0, 1, 0 }, { "Blue", 0, 0, 1 }, { "Gold", 1, 0.8, 0.2 },
        { "Fire", 1, 0.35, 0 }, { "Frost", 0.3, 0.6, 1 }, { "Shadow", 0.5, 0, 0.8 }, { "White", 1, 1, 1 } }
    for i, c in ipairs(colors) do
        local col, row = (i - 1) % 2, floor((i - 1) / 2)
        S.NewButton(test, c[1], 12 + col * 170, -40 - row * 36, 160, function()
            H.Flash("test", c[2], c[3], c[4], 1.5, 9)
        end, nil, 12, 30)
    end
    S.NewButton(test, "Pulse", 12, -200, 160, function()
        H.Light("test", function(now, v)
            local t = now - v.start
            if t > 4 then return nil end
            local k = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 1.4)
            return k, 0, 0
        end, 9)
    end, nil, 12, 30)
    S.NewButton(test, "Rainbow", 182, -200, 160, function()
        H.Light("test", function(now, v)
            local t = now - v.start
            if t > 4 then return nil end
            local h = (t / 2) % 1 * 6
            local x = 1 - math.abs(h % 2 - 1)
            local seg = floor(h)
            local rgb = ({ { 1, x, 0 }, { x, 1, 0 }, { 0, 1, x }, { 0, x, 1 }, { x, 0, 1 }, { 1, 0, x } })[seg + 1]
            return rgb[1], rgb[2], rgb[3]
        end, 9)
    end, nil, 12, 30)
    S.NewButton(test, "Clear", 12, -240, 330, function() H.LightStop(); H.LedClear(); L.ApplyBaseLight() end, nil, 12, 30)
    ui.refresh[#ui.refresh + 1] = function()
        local db = H.DB()
        master:SetChecked(db.light)
        for _, r in ipairs(rows) do
            local v = db.lights[r.l.key]
            if v == nil then v = r.l.on end
            r.check:SetChecked(v)
            r.check:SetAlpha(db.light and 1 or 0.5)
        end
    end
end

---------------------------------------------------------------------------
-- Engine: mixer settings and the live view
---------------------------------------------------------------------------
local function BuildEngine(p)
    local card = S.Card(p, "Mixer", 0, 0, 560, PH - 40)
    local db = H.DB
    Choice(card, "Mix", 12, -40, { { "max", "Max" }, { "screen", "Blend" }, { "sum", "Sum" } },
        function() return db().mix end, function(v) db().mix = v end)
    Choice(card, "Sends", 12, -72, { { 0, "Every frame" }, { 120, "120/s" }, { 60, "60/s" }, { 30, "30/s" }, { 10, "10/s" } },
        function() return db().rate end, function(v) db().rate = v end, 76)
    Choice(card, "Resend", 12, -104, { { 0, "Never" }, { 0.05, "0.05 s" }, { 0.1, "0.1 s" }, { 0.25, "0.25 s" }, { 0.5, "0.5 s" } },
        function() return db().keepAlive end, function(v) db().keepAlive = v end)
    Choice(card, "Overdrive", 12, -136, { { 0, "Off" }, { 0.01, "10 ms" }, { 0.02, "20 ms" }, { 0.03, "30 ms" }, { 0.04, "40 ms" } },
        function() return db().kick end, function(v) db().kick = v end)
    Choice(card, "Triggers", 12, -168, { { "off", "Off" }, { "mirror", "Mirror" }, { "only", "Only" } },
        function() return db().triggers end, function(v) db().triggers = v; H.Stop() end)
    Choice(card, "Low battery", 12, -200, { { true, "Softer" }, { false, "Same" } },
        function() return db().battery end, function(v) db().battery = v end)
    Choice(card, "Shortest pulse", 12, -232, { { 0, "Off" }, { 0.025, "25 ms" }, { 0.033, "33 ms" }, { 0.04, "40 ms" },
        { 0.05, "50 ms" } }, function() return db().minPulse end, function(v) db().minPulse = v end)
    S.Heading(card, "Try the mix", 12, -276, 530)
    S.NewButton(card, "Purr + hits", 12, -300, 170, function()
        H.Play("orbit", { voice = "mixA", loop = true })
        for i = 0, 3 do C_Timer.After(0.5 + i * 0.7, function() H.Play("knock", { voice = "mixB" .. i }) end) end
        C_Timer.After(3.5, function() H.Stop("mixA") end)
    end, nil, 12, 30)
    S.NewButton(card, "Heart + boom", 190, -300, 170, function()
        H.Play("heart60", { voice = "mixA", loop = true })
        C_Timer.After(1.3, function() H.Play("boom", { voice = "mixB" }) end)
        C_Timer.After(4, function() H.Stop("mixA") end)
    end, nil, 12, 30)
    S.NewButton(card, "Stop all", 368, -300, 170, function() H.Stop(); L.Halt(); Say("Stopped") end, nil, 12, 30)

    local live = S.Card(p, "Live", 570, 0, W - 570, PH - 40)
    local graph = Graph(live, 12, -40, W - 570 - 24, 260, 240)
    local info = S.Text(live, "", 12, -312, 400, 12, GREY)
    local tick = CreateFrame("Frame", nil, live)
    local acc = 0
    tick:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 0.05 then return end
        acc = 0
        local hist = H.History()
        graph:Draw(function(i) local h = hist[i]; return h[1], h[2] end)
        local o = H.out
        info:SetText(string.format("Left %d%%  ·  Right %d%%  ·  %d sends/s%s", o.l * 100, o.r * 100, H.SendRate(),
            (o.lt > 0 or o.rt > 0) and string.format("  ·  Triggers %d / %d%%", o.lt * 100, o.rt * 100) or ""))
    end)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local SECTIONS = {
    { "probes", "Probes", BuildProbes },
    { "calibrate", "Calibrate", BuildCalibrate },
    { "feels", "Feels", BuildFeels },
    { "editor", "Editor", BuildEditor },
    { "events", "Events", BuildEvents },
    { "light", "Light", BuildLight },
    { "engine", "Engine", BuildEngine },
}

function ui.Select(key)
    ui.current = key
    for k, panel in pairs(ui.panels) do panel:SetShown(k == key) end
    Refresh()
end

local function Build(frame, header)
    ui.engine = S.NewCheck(header, "Beta engine", W - 150, -4, function(self)
        L.SetEngine(self:GetChecked() == true)
        Say(H.Engine() and "Beta engine on: Rumble runs through it" or "Beta engine off")
        Refresh()
    end, 110)
    S.Tooltip(ui.engine, "Beta engine", "Rumble through the mixer, events, light bar")
    -- A small live meter in the header
    ui.meterL = header:CreateTexture(nil, "ARTWORK")
    ui.meterR = header:CreateTexture(nil, "ARTWORK")
    ui.meterL:SetColorTexture(LEFT_C[1], LEFT_C[2], LEFT_C[3], 0.9)
    ui.meterR:SetColorTexture(RIGHT_C[1], RIGHT_C[2], RIGHT_C[3], 0.9)
    ui.meterL:SetPoint("TOPRIGHT", header, "TOPLEFT", W - 262, -13)
    ui.meterR:SetPoint("TOPLEFT", header, "TOPLEFT", W - 260, -13)
    ui.meterL:SetSize(1, 8)
    ui.meterR:SetSize(1, 8)
    local meter = CreateFrame("Frame", nil, header)
    meter:SetScript("OnUpdate", function()
        local o = H.out
        local l, r = H.driver:IsShown() and o.l or 0, H.driver:IsShown() and o.r or 0
        ui.meterL:SetWidth(max(1, l * 80))
        ui.meterR:SetWidth(max(1, r * 80))
    end)

    local tabs = {}
    for i, s in ipairs(SECTIONS) do
        tabs[i] = S.NewButton(frame, s[2], (i - 1) * 124, 0, 120, function() ui.Select(s[1]) end, nil, 13, 30)
        local panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", 0, -40)
        panel:SetSize(W, PH - 40)
        panel:Hide()
        ui.panels[s[1]] = panel
        s[3](panel)
    end
    ui.tabs = tabs
    ui.current = ui.current or "probes"
end

Refresh = function()
    if not ui.engine then return end
    ui.engine:SetChecked(H.Engine())
    for i, s in ipairs(SECTIONS) do S.SetSelected(ui.tabs[i], s[1] == ui.current) end
    for k, panel in pairs(ui.panels) do panel:SetShown(k == ui.current) end
    for _, fn in ipairs(ui.refresh) do fn() end
    local V = ns.Rumble
    if H.Engine() and V and V.Other and V.Other() then
        Shell.SetStatus("Improved Forever: Vibration rumbles: Rumble not routed")
    end
end
ui.Refresh = function() Refresh() end
ns.BetaPage = ui

Shell.AddPage({
    key = "beta", name = "Beta", order = 2.5, icon = "Interface\\Icons\\Spell_Nature_Lightning",
    sub = "Haptics lab",
    build = Build, refresh = function() Refresh() end,
    hide = function()
        if trigWin then trigWin:Hide() end
        L.Halt()
        probe.playing = false
        L.FpsCap(false)
        if L.Ramping() then L.StopRamp() end
        H.Stop("beta"); H.Stop("editor"); H.Stop("record")
        if picker then picker:Hide() end
        if textWin then textWin:Hide() end
    end,
})

function API.OpenBeta() Shell.Open("beta") end
