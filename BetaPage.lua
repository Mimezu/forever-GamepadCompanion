-- The Haptics tab: the light bar, the feels and their editor, the mixer and
-- calibration, the helper, the probes (Haptics.lua, HapticsLab.lua). The events are on the Rumble tab.
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
-- (the shared widgets: HapticsUI.lua)
local HUI = ns.HapticsUI
local function Stepper(...) return HUI.Stepper(ui, ...) end
local function Choice(...) return HUI.Choice(ui, ...) end

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

local Popup, PickFeel, ROW_H = HUI.Popup, HUI.PickFeel, HUI.ROW_H

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
-- Feels: the library and the player's own
---------------------------------------------------------------------------
local feelsUI = {}

local OpenEditor   -- set below

local function BuildFeels(p)
    local cardW = 290
    feelsUI.pal = HUI.Palette(p, 0, -4, W - cardW - 10, PH - 44, {
        current = function() return feelsUI.selected end,
        onPick = function(key, button)
            if button == "RightButton" then return OpenEditor(key) end
            feelsUI.selected = key
            Play(key, (IsShiftKeyDown and IsShiftKeyDown()) or nil)
            Refresh()
        end,
    })
    feelsUI.pal:ShowGroup(L.GROUPS[1])
    local card = S.Card(p, "", W - cardW, 0, cardW, PH - 40)
    feelsUI.name = S.Text(card, "Pick a feel", 14, -14, cardW - 28, 14, YELLOW)
    feelsUI.info = S.Text(card, "", 14, -38, cardW - 28, 11, GREY)
    feelsUI.graph = Graph(card, 14, -62, cardW - 28, 120, 80)
    S.NewButton(card, "Play", 14, -196, 84, function() if feelsUI.selected then Play(feelsUI.selected) end end, nil, 12, 28)
    S.NewButton(card, "Loop", 102, -196, 84, function() if feelsUI.selected then Play(feelsUI.selected, true) end end,
        nil, 12, 28)
    S.NewButton(card, "Stop", 190, -196, 84, function() H.Stop("beta"); Say("Stopped") end, nil, 12, 28)
    S.NewButton(card, "Edit a copy", 14, -232, cardW - 28, function()
        if feelsUI.selected then OpenEditor(feelsUI.selected, true) end
    end, nil, 12, 30)
    S.Note(card, 14, -276, cardW - 28, 3, 11, DIM):SetText("Click: play · Shift: loop · Right-click: edit a copy")
    ui.refresh[#ui.refresh + 1] = function()
        local f = feelsUI.selected and H.Feel(feelsUI.selected)
        feelsUI.name:SetText(f and (f.label or f.key) or "Pick a feel")
        feelsUI.info:SetText(f and string.format("%.2f s%s%s", H.Length(f), f.loop and " · loops" or "",
            H.IsOwn(feelsUI.selected) and " · yours" or (f.rumble and " · Rumble's" or "")) or "")
        local view = f and math.max(0.5, H.Length(f) * 1.1) or 1
        local plain = f and H.Copy(f)
        if plain then plain.loop = false end
        feelsUI.graph:Draw(function(i)
            if not plain then return 0, 0 end
            local l, r = H.Sample(plain, (i - 0.5) / 80 * view, 1)
            return l or 0, r or 0
        end)
        feelsUI.pal:ShowGroup(feelsUI.pal.group or L.GROUPS[1])
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
    feel.key, feel.group, feel.rumble = nil, nil, nil
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
        ed.assign:SetText(f and own_ and "In the palette of every event (Rumble tab)" or "")
        ed.Draw()
    end
end

---------------------------------------------------------------------------
-- Light: the base colour on the left, the light events by group
---------------------------------------------------------------------------
local function BuildLight(p)
    local LT = ns.Lights
    local base = S.Card(p, "Light bar", 0, 0, 330, PH - 40)
    local master = S.NewCheck(base, "On", 12, -38, function(self)
        LT.SetOn(self:GetChecked() == true)
        Refresh()
    end, 60)
    S.Tooltip(master, "Light bar", "Off: the game's own colour")
    -- what the bar shows now
    local swatch = base:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPRIGHT", -14, -38)
    swatch:SetSize(90, 26)
    local swatchRim = base:CreateTexture(nil, "BORDER")
    swatchRim:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
    swatchRim:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
    swatchRim:SetColorTexture(0.68, 0.5, 0.26, 0.8)
    S.Text(base, "Now", 330 - 150, -44, 40, 11, DIM)
    local tick = CreateFrame("Frame", nil, base)
    tick:SetScript("OnUpdate", function()
        local r, g, bb, on = H.LedNow()
        if on then swatch:SetColorTexture(r, g, bb, 1) else swatch:SetColorTexture(0.08, 0.08, 0.08, 1) end
    end)
    S.Heading(base, "Base colour", 10, -78, 308)
    Choice(base, "", -100, -96, LT.BASE_MODES, function() return LT.Base().mode end, function(v)
        LT.Base().mode = v
        LT.ApplyBase()
    end, 64)
    -- the palette
    local swatches = {}
    local n = 0
    for _, c in ipairs(LT.PALETTE) do
        if c.rgb then
            n = n + 1
            local col, row = (n - 1) % 5, floor((n - 1) / 5)
            local sw = CreateFrame("Button", nil, base)
            sw:SetSize(52, 26)
            sw:SetPoint("TOPLEFT", 14 + col * 60, -134 - row * 34)
            sw.tex = sw:CreateTexture(nil, "ARTWORK")
            sw.tex:SetPoint("TOPLEFT", 3, -3)
            sw.tex:SetPoint("BOTTOMRIGHT", -3, 3)
            sw.tex:SetColorTexture(c.rgb[1], c.rgb[2], c.rgb[3], 1)
            sw.sel = sw:CreateTexture(nil, "BACKGROUND")
            sw.sel:SetAllPoints()
            sw.sel:SetColorTexture(1, 0.82, 0, 1)
            sw:SetScript("OnClick", function()
                local b = LT.Base()
                b.mode, b.color = "color", c.key
                LT.ApplyBase()
                Refresh()
            end)
            sw:SetScript("OnEnter", S.ShowTooltip)
            sw:SetScript("OnLeave", S.HideTooltip)
            S.Tooltip(sw, c.label)
            sw.key = c.key
            swatches[#swatches + 1] = sw
        end
    end
    local function BRow(label, y, opts)
        opts.labelWidth, opts.width = 110, 306
        return Stepper(base, label, 12, y, opts)
    end
    BRow("Brightness", -214, { step = 0.05, min = 0.05, max = 1, format = function(v) return floor(v * 100 + 0.5) .. "%" end,
        get = function() return LT.Base().level end, set = function(v) LT.Base().level = v; LT.ApplyBase() end })
    BRow("Breathe", -242, { list = { { false, "No" }, { true, "Yes" } },
        get = function() return LT.Base().breathe end, set = function(v) LT.Base().breathe = v; LT.ApplyBase() end })
    S.Heading(base, "Try", 10, -282, 308)
    S.NewButton(base, "A cast", 12, -306, 146, function() LT.Try("cast") end, nil, 12, 30)
    S.NewButton(base, "A crit", 166, -306, 146, function() LT.Try("crit") end, nil, 12, 30)
    S.NewButton(base, "Level up", 12, -342, 146, function() LT.Try("levelUp") end, nil, 12, 30)
    S.NewButton(base, "Low health", 166, -342, 146, function() LT.Try("lowHp") end, nil, 12, 30)
    S.NewButton(base, "Stop", 12, -378, 300, function()
        H.LightStop()
        LT.ApplyBase()
    end, nil, 12, 30)

    -- the events, a group at a time
    local area = CreateFrame("Frame", nil, p)
    area:SetPoint("TOPLEFT", 340, 0)
    area:SetSize(W - 340, PH - 40)
    local tabs, panels, rows = {}, {}, {}
    local current = LT.GROUPS[1]
    local function Select(g)
        current = g
        for k, panel in pairs(panels) do panel:SetShown(k == g) end
        for k, t in pairs(tabs) do S.SetSelected(t, k == g) end
    end
    local aw = W - 340
    for i, g in ipairs(LT.GROUPS) do
        tabs[g] = S.NewButton(area, g, (i - 1) * 124, 0, 120, function() Select(g) end, nil, 12, 28)
        local list = {}
        for _, e in ipairs(LT.EVENTS) do if e.group == g then list[#list + 1] = e end end
        local panel = S.Card(area, nil, 0, -36, aw, 40 + #list * ROW_H)
        panels[g] = panel
        for j, e in ipairs(list) do
            local y = -12 - (j - 1) * ROW_H
            local r = CreateFrame("Frame", nil, panel)
            r:SetPoint("TOPLEFT", 10, y)
            r:SetSize(aw - 20, ROW_H - 4)
            local wash = r:CreateTexture(nil, "BACKGROUND")
            wash:SetAllPoints()
            wash:SetColorTexture(1, 0.85, 0.55, 0.04)
            r.dot = r:CreateTexture(nil, "ARTWORK")
            r.dot:SetSize(26, 26)
            r.dot:SetPoint("LEFT", 4, 0)
            r.label = S.Text(r, e.label, 40, -4, 200, 13, GOLD)
            r.label:SetWordWrap(false)
            r.sub = S.Text(r, "", 40, -22, 200, 11, GREY)
            r.sub:SetWordWrap(false)
            -- effect (with Off), colour, strength, Try
            r.effect = S.NewButton(r, "", 248, -5, 124, function(self)
                local entries = { { key = "off", label = "Off", icon = ns.Rumble and ns.Rumble.OFF_ICON } }
                for _, ef in ipairs(LT.EFFECTS) do
                    entries[#entries + 1] = { key = ef.key, label = ef.label .. (ef.state and " ·" or ""),
                        icon = "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_vibe_" .. (ef.state and "pulse" or "tick") }
                end
                local s = LT.Settings(e.key)
                Popup(self, e.label, entries, s.on and s.effect or "off", function(key)
                    if key == "off" then s.on = false else s.on, s.effect = true, key; LT.Try(e.key) end
                    Refresh()
                end, 2, 150)
            end, nil, 11, 30)
            S.Tooltip(r.effect, "Effect", "· lasts while it does")
            r.color = S.NewButton(r, "", 378, -5, 124, function(self)
                local entries = {}
                for _, c in ipairs(LT.PALETTE) do
                    entries[#entries + 1] = { key = c.key, label = c.label, rgb = c.rgb or (c.key == "base" and LT.BaseRGB())
                        or (c.key == "school" and { 1, 0.35, 0 }) or { 1, 1, 1 } }
                end
                local s = LT.Settings(e.key)
                Popup(self, e.label, entries, s.color, function(key)
                    s.color = key
                    LT.Try(e.key)
                    Refresh()
                end, 3, 130)
            end, nil, 11, 30)
            r.color.sw = r.color:CreateTexture(nil, "OVERLAY")
            r.color.sw:SetSize(16, 16)
            r.color.sw:SetPoint("LEFT", 8, 0)
            r.color.label:ClearAllPoints()
            r.color.label:SetPoint("LEFT", 30, 0)
            r.color.label:SetPoint("RIGHT", -6, 0)
            r.color.label:SetJustifyH("LEFT")
            r.level = Stepper(r, "", 508, -8, { labelWidth = 0, width = 130, step = 0.05, min = 0.05, max = 1,
                format = function(v) return floor(v * 100 + 0.5) .. "%" end,
                get = function() return LT.Settings(e.key).level end, set = function(v) LT.Settings(e.key).level = v end })
            r.try = S.NewButton(r, "Try", aw - 20 - 42, -5, 40, function() LT.Try(e.key) end, nil, 11, 30)
            r.e = e
            rows[#rows + 1] = r
        end
    end
    Select(current)

    ui.refresh[#ui.refresh + 1] = function()
        master:SetChecked(H.DB().light == true)
        local b = LT.Base()
        for _, sw in ipairs(swatches) do sw.sel:SetShown(b.mode == "color" and b.color == sw.key) end
        for _, r in ipairs(rows) do
            local s = LT.Settings(r.e.key)
            local ef = LT.Effect(s.effect)
            local rgb = LT.ColorRGB(s.color)
            r.dot:SetColorTexture(rgb[1], rgb[2], rgb[3], s.on and 1 or 0.25)
            r.effect.label:SetText(s.on and ef.label or "Off")
            if s.on then r.effect.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else r.effect.label:SetTextColor(RED[1], RED[2], RED[3]) end
            local c
            for _, pc in ipairs(LT.PALETTE) do if pc.key == s.color then c = pc end end
            r.color.label:SetText(c and c.label or s.color)
            r.color.sw:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
            r.sub:SetText(r.e.state and "While it lasts" or "")
            r.label:SetAlpha(s.on and 1 or 0.6)
            r.color:SetAlpha(s.on and 1 or 0.5)
            r.level:SetAlpha(s.on and 1 or 0.5)
        end
    end
end

---------------------------------------------------------------------------
-- Tune: the mixer, the live view, each grip's calibration
---------------------------------------------------------------------------
local calib = {}

local function BuildTune(p)
    local card = S.Card(p, "Mixer", 0, 0, 560, PH - 40)
    local db = H.DB
    Choice(card, "Mix", 12, -40, { { "max", "Max" }, { "screen", "Blend" }, { "sum", "Sum" } },
        function() return db().mix end, function(v) db().mix = v end)
    Choice(card, "Sends", 12, -72, { { 0, "Every frame" }, { 120, "120/s" }, { 60, "60/s" }, { 30, "30/s" }, { 10, "10/s" } },
        function() return db().rate end, function(v) db().rate = v end, 76)
    Choice(card, "Resend", 12, -104, { { 0, "Never" }, { 0.05, "0.05 s" }, { 0.1, "0.1 s" }, { 0.25, "0.25 s" }, { 0.5, "0.5 s" } },
        function() return db().keepAlive end, function(v) db().keepAlive = v end)
    Choice(card, "Shortest pulse", 12, -136, { { 0, "Off" }, { 0.025, "25 ms" }, { 0.033, "33 ms" }, { 0.04, "40 ms" },
        { 0.05, "50 ms" } }, function() return db().minPulse end, function(v) db().minPulse = v end)
    Choice(card, "Low battery", 12, -168, { { true, "Softer" }, { false, "Same" } },
        function() return db().battery end, function(v) db().battery = v end)
    Choice(card, "Triggers", 12, -200, { { "off", "Off" }, { "mirror", "Mirror" }, { "only", "Only" } },
        function() return db().triggers end, function(v) db().triggers = v; H.Stop() end)
    Choice(card, "Overdrive", 12, -232, { { 0, "Off" }, { 0.01, "10 ms" }, { 0.02, "20 ms" }, { 0.03, "30 ms" }, { 0.04, "40 ms" } },
        function() return db().kick end, function(v) db().kick = v end)
    S.Note(card, 12, -266, 530, 2, 11, DIM):SetText("Triggers: Xbox pads only · Overdrive: a full-strength start, off for subtle taps")
    S.Heading(card, "Try the mix", 12, -306, 530)
    S.NewButton(card, "Taps + hits", 12, -330, 170, function()
        H.Play("orbit", { voice = "mixA", loop = true })
        for i = 0, 3 do C_Timer.After(0.5 + i * 0.7, function() H.Play("knock", { voice = "mixB" .. i }) end) end
        C_Timer.After(3.5, function() H.Stop("mixA") end)
    end, nil, 12, 30)
    S.NewButton(card, "Heart + boom", 190, -330, 170, function()
        H.Play("heart60", { voice = "mixA", loop = true })
        C_Timer.After(1.3, function() H.Play("boom", { voice = "mixB" }) end)
        C_Timer.After(4, function() H.Stop("mixA") end)
    end, nil, 12, 30)
    S.NewButton(card, "Stop all", 368, -330, 170, function() H.Stop(); L.Halt(); Say("Stopped") end, nil, 12, 30)

    -- Live
    local rw = W - 570
    local live = S.Card(p, "Live", 570, 0, rw, 210)
    local graph = Graph(live, 12, -38, rw - 24, 130, 200)
    local info = S.Text(live, "", 12, -180, rw - 24, 12, GREY)
    local t = CreateFrame("Frame", nil, live)
    local acc = 0
    t:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 0.05 then return end
        acc = 0
        local hist = H.History()
        local off = #hist - 200
        graph:Draw(function(i) local h = hist[i + off]; return h[1], h[2] end)
        local o = H.out
        info:SetText(string.format("Left %d%%  ·  Right %d%%  ·  %d sends/s", o.l * 100, o.r * 100, H.SendRate()))
    end)

    -- Calibration, a column per grip
    local cal = S.Card(p, "Calibration", 570, -220, rw, PH - 40 - 220)
    local cw = (rw - 30) / 2
    for side = 1, 2 do
        local x = 12 + (side - 1) * (cw + 6)
        local c = { side = side }
        calib[side] = c
        S.Text(cal, side == 1 and "Left grip" or "Right grip", x, -38, cw, 12, side == 1 and LEFT_C or RIGHT_C)
        local function CRow(label, y, opts)
            opts.labelWidth, opts.width = 70, cw
            return Stepper(cal, label, x, y, opts)
        end
        CRow("Floor", -58, { get = function() return db().floor[side] end,
            set = function(v) db().floor[side] = min(v, db().ceil[side] - 0.05) end, step = 0.01, min = 0, max = 0.9 })
        CRow("Ceiling", -86, { get = function() return db().ceil[side] end,
            set = function(v) db().ceil[side] = max(v, db().floor[side] + 0.05) end, step = 0.01, min = 0.1, max = 1 })
        CRow("Curve", -114, { get = function() return db().gamma[side] end,
            set = function(v) db().gamma[side] = v end, step = 0.05, min = 0.3, max = 3 })
        c.find = S.NewButton(cal, "Find floor", x, -148, cw / 2 - 3, function()
            if L.Ramping() and calib.active == c and calib.mode == "floor" then
                db().floor[side] = floor(L.StopRamp() * 100 + 0.5) / 100
                if db().ceil[side] <= db().floor[side] then db().ceil[side] = 1 end
                calib.active = nil
            else
                calib.active, calib.mode = c, "floor"
                L.StartRamp(side, 0, 8)
                Say("Rising: Felt it as soon as you feel it")
            end
            Refresh()
        end, nil, 11, 28)
        c.ceil = S.NewButton(cal, "Find ceiling", x + cw / 2 + 3, -148, cw / 2 - 3, function()
            if L.Ramping() and calib.active == c and calib.mode == "ceil" then
                db().ceil[side] = max(db().floor[side] + 0.05, floor(L.StopRamp() * 100 + 0.5) / 100)
                calib.active = nil
            else
                calib.active, calib.mode = c, "ceil"
                L.StartRamp(side, db().floor[side], 6)
                Say("Rising: No stronger when it stops growing")
            end
            Refresh()
        end, nil, 11, 28)
        S.NewButton(cal, "Test steps", x, -182, cw / 2 - 3, function()
            H.Stop()
            local keys = {}
            for i = 0, 9 do keys[#keys + 1] = { i * 0.3, (i + 1) / 10, "hold" } end
            keys[#keys + 1] = { 3, 0 }
            local zero = { { 0, 0 }, { 3, 0 } }
            H.Play({ keys = side == 1 and { left = keys, right = zero } or { left = zero, right = keys } }, { voice = "beta" })
        end, nil, 11, 28)
        S.NewButton(cal, "Reset", x + cw / 2 + 3, -182, cw / 2 - 3, function()
            db().floor[side], db().ceil[side], db().gamma[side] = H.DEFAULTS.floor[side], 1, 1
            Refresh()
        end, nil, 11, 28)
        c.level = S.Text(cal, "", x, -218, cw, 12, YELLOW)
    end
    L.onRampEnd = function() calib.active = nil; Refresh() end
    local rt = CreateFrame("Frame", nil, cal)
    rt:SetScript("OnUpdate", function()
        for side = 1, 2 do
            local c = calib[side]
            c.level:SetText(L.Ramping() and L.ramp.side == side and string.format("Sending %.0f%%", L.ramp.level * 100) or "")
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
        end
    end
end

---------------------------------------------------------------------------
-- Helper: the outside program (helper\) for the triggers, true haptics and
-- the speaker: the link, the cues, and tries of each
---------------------------------------------------------------------------
local function BuildHelper(p)
    local K, C = ns.HelperLink, ns.HelperCues
    if not (K and C) then
        S.Text(p, "Helper link not loaded", 12, -12, 400, 13, RED)
        return
    end
    -- The link
    local link = S.Card(p, "Link", 0, 0, 330, 250)
    local on = S.NewCheck(link, "Link on", 12, -38, function(self)
        K.SetEnabled(self:GetChecked() == true)
        C.Refresh()
        Refresh()
    end, 90)
    S.Tooltip(on, "Link on", "A few pixels bottom left, read by WoW Helper")
    S.Note(link, 12, -72, 306, 4, 11, GREY):SetText("Run WowHelper.exe" .. string.char(10) .. "Game windowed or borderless"
        .. string.char(10) .. "Bluetooth: triggers, haptics")
    Stepper(link, "Cell size", 12, -140, { labelWidth = 110, width = 306, step = 1, min = 2, max = 8,
        format = function(v) return v .. " px" end,
        get = function() return K.CellSize() end, set = function(v) K.SetCellSize(v) end })
    local state = S.Note(link, 12, -176, 306, 3, 11, DIM)

    -- The cues
    local cues = S.Card(p, "Cues", 0, -260, 330, PH - 40 - 260)
    local checks = {}
    for i, g in ipairs(C.GROUPS) do
        local c = S.NewCheck(cues, g.label, 12, -38 - (i - 1) * 30, function(self)
            C.Settings()[g.key] = self:GetChecked() == true
            C.Refresh()
        end, 220)
        S.Tooltip(c, g.label, g.tip)
        checks[g.key] = c
    end

    -- Triggers by hand
    local trig = S.Card(p, "Triggers", 340, 0, 380, PH - 40)
    local MODES = { { "off", "Off" }, { "resist", "Resistance" }, { "section", "Section" }, { "weapon", "Click" },
        { "vibrate", "Vibration" }, { "slope", "Slope" } }
    local hand = { L2 = { mode = "resist", start = 3, finish = 9, force = 8 },
        R2 = { mode = "weapon", start = 4, finish = 8, force = 7 } }
    for i, side in ipairs({ "L2", "R2" }) do
        local y0 = -38 - (i - 1) * 250
        local h = hand[side]
        S.Text(trig, side, 12, y0, 60, 13, i == 1 and LEFT_C or RIGHT_C)
        local function TRow(label, y, opts)
            opts.labelWidth, opts.width = 110, 356
            return Stepper(trig, label, 12, y, opts)
        end
        TRow("Effect", y0 - 22, { list = MODES, get = function() return h.mode end, set = function(v) h.mode = v end })
        TRow("Start", y0 - 50, { step = 1, min = 0, max = 15, format = tostring,
            get = function() return h.start end, set = function(v) h.start = v end })
        TRow("End, amplitude", y0 - 78, { step = 1, min = 0, max = 15, format = tostring,
            get = function() return h.finish end, set = function(v) h.finish = v end })
        TRow("Force, speed", y0 - 106, { step = 1, min = 0, max = 15, format = tostring,
            get = function() return h.force end, set = function(v) h.force = v end })
        S.NewButton(trig, "Apply", 12, y0 - 140, 170, function()
            if not K.Enabled() then return Say("Link is off", true) end
            K.SetTrigger(side, h.mode, h.start, h.finish, h.force)
            Say(side .. ": " .. h.mode)
        end, nil, 12, 30)
        S.NewButton(trig, "Free", 190, y0 - 140, 170, function()
            K.SetTrigger(side, "off", 0, 0, 0)
            Say(side .. ": free")
        end, nil, 12, 30)
    end

    -- Haptics and sounds
    local rx = 730
    local snd = S.Card(p, "Haptics and sounds", rx, 0, W - rx, PH - 40)
    local gain = 4
    Stepper(snd, "Volume", 12, -38, { labelWidth = 90, width = W - rx - 24, step = 1, min = 1, max = 7,
        format = function(v) return v .. "/7" end, get = function() return gain end, set = function(v) gain = v end })
    local function Buttons(title, tbl, y)
        S.Heading(snd, title, 10, y, W - rx - 22)
        local names = {}
        for name, id in pairs(tbl) do names[#names + 1] = { name, id } end
        table.sort(names, function(a, b) return a[2] < b[2] end)
        local bw = (W - rx - 30) / 2
        for i, n in ipairs(names) do
            local col, row = (i - 1) % 2, floor((i - 1) / 2)
            S.NewButton(snd, n[1]:gsub("_", " "), 12 + col * (bw + 6), y - 24 - row * 30, bw, function()
                if not K.Enabled() then return Say("Link is off", true) end
                K.Play(n[1], gain)
                Say(n[1])
            end, nil, 11, 26)
        end
        return y - 24 - math.ceil(#names / 2) * 30
    end
    local y = Buttons("True haptics", K.CLIPS, -72)
    Buttons("Speaker", K.SOUNDS, y - 12)

    ui.refresh[#ui.refresh + 1] = function()
        on:SetChecked(K.Enabled())
        local cs = C.Settings()
        for key, c in pairs(checks) do c:SetChecked(cs[key] == true) end
        local st, names = K.state, {}
        for name, v in pairs(K.MODES) do names[v] = name end
        state:SetText(K.Enabled() and string.format("L2 %s · R2 %s", names[st.left.mode] or "?", names[st.right.mode] or "?")
            or "Off")
    end
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local SECTIONS = {
    { "light", "Light", BuildLight },
    { "feels", "Feels", BuildFeels },
    { "editor", "Editor", BuildEditor },
    { "tune", "Tune", BuildTune },
    { "helper", "Helper", BuildHelper },
    { "probes", "Probes", BuildProbes },
}

-- A copy of a feel, yours, open in the editor (the Rumble tab's Edit)
function ui.EditCopy(feel, label)
    Shell.Open("beta")
    local key = SaveOwn(feel, label)
    ed.key, ed.sel = key, nil
    ui.Select("editor")
    return key
end

function ui.Select(key)
    ui.current = key
    for k, panel in pairs(ui.panels) do panel:SetShown(k == key) end
    Refresh()
end

local function Build(frame, header)
    -- Why it vibrates: the debug window, and the latest reason in the header
    local dbg = S.NewButton(header, "Debug", W - 450, -4, 80, function()
        if ns.HapticsDebug then ns.HapticsDebug.Show() end
    end, nil, 12, 26)
    S.Tooltip(dbg, "Debug", "What vibrates and why, while you play")
    ui.why = S.Text(header, "", 260, -10, W - 720, 11, GREY)
    ui.why:SetWordWrap(false)
    local whyTick = CreateFrame("Frame", nil, header)
    local whyAcc = 0
    whyTick:SetScript("OnUpdate", function(_, elapsed)
        whyAcc = whyAcc + (elapsed or 0)
        if whyAcc < 0.25 then return end
        whyAcc = 0
        local D = ns.HapticsDebug
        local text, ago
        if D then text, ago = D.Latest() end
        local playing = D and #H.ActiveVoices() or 0
        if text then
            ui.why:SetText(string.format("%s · %ds ago%s", text, floor(ago), playing > 0 and ("  ·  " .. playing .. " playing") or ""))
        else
            ui.why:SetText(playing > 0 and (playing .. " playing: Debug") or "")
        end
    end)
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
    ui.current = ui.current or "light"
end

Refresh = function()
    if not ui.tabs then return end
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
    key = "beta", name = "Haptics", order = 2.5, icon = "Interface\\Icons\\Spell_Nature_Lightning",
    sub = "Light, feels, tuning",
    build = Build, refresh = function() Refresh() end,
    hide = function()
        if trigWin then trigWin:Hide() end
        L.Halt()
        probe.playing = false
        L.FpsCap(false)
        if L.Ramping() then L.StopRamp() end
        H.Stop("beta"); H.Stop("editor"); H.Stop("record")
        HUI.HidePopup()
        if textWin then textWin:Hide() end
    end,
})

function API.OpenBeta() Shell.Open("beta") end
