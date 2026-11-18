-- Light picker: one popup for a moment's light (C:\games\WowHelper\docs\LIGHTS.md
-- section 3). Which light (tiles that play it), its colour, its strength
-- (8 steps), Off and Try. Lights fit for the moment: once lights for a moment,
-- lights that last for a state; the moment's own first, then shapes, then the
-- player's own (made in WoW Helper), then the rest.
local _, ns = ...
local S, Shell = ns.OptionsSkin, ns.Shell
local LP = {}
ns.LightPicker = LP

local floor, max, min = math.floor, math.max, math.min
local GOLD, YELLOW, DIM = S.GOLD, S.YELLOW, S.DIM
local TILE_W, TILE_H, COLS = 104, 44, 6

local pop
local function Now() return GetTime and GetTime() or 0 end

-- linear light -> a screen colour (faint stays visible)
local function Shown(r, g, b)
    local k = 1 / 2.2
    return (r or 0) ^ k, (g or 0) ^ k, (b or 0) ^ k
end

-- The lights to offer: { heading, { light, ... } } in order
function LP.Sections(key)
    local LT = ns.Lights
    local e = LT.Def(key)
    local kind = e.state and "hold" or "once"
    local ownId = LT.DefaultLight(e.parent or key)
    local own, shapes, yours, more = {}, {}, {}, {}
    for _, l in ipairs(LT.Lights()) do
        -- (a state can rest: Steady, Breathe, Ember)
        if l.kind == kind and (e.state or l.group ~= "Resting") then
            if l.id == ownId then own[#own + 1] = l
            elseif l.yours then yours[#yours + 1] = l
            elseif l.group == "Basics" or l.group == "Shapes" then shapes[#shapes + 1] = l
            else more[#more + 1] = l end
        end
    end
    local first = {}
    -- a state can leave the bar to what is below it
    if e.state then first[#first + 1] = { id = 0, name = "Pass", kind = "hold", bar = {}, pass = true } end
    for _, l in ipairs(own) do first[#first + 1] = l end
    for _, l in ipairs(shapes) do first[#first + 1] = l end
    local out = { { "Lights", first } }
    if #yours > 0 then out[#out + 1] = { "Yours", yours } end
    if #more > 0 then out[#out + 1] = { "More", more } end
    return out
end

-- The colours to offer (School only on spell moments)
function LP.Colours(key)
    local LT = ns.Lights
    local list = {}
    for _, c in ipairs(LT.PALETTE) do
        if c.key ~= "school" or LT.Def(key).school then list[#list + 1] = c end
    end
    return list
end

local function Build()
    pop = CreateFrame("Frame", "GamepadCompanionLightPicker", Shell.Window())
    pop:SetFrameStrata("DIALOG")
    pop:SetToplevel(true)
    pop:EnableMouse(true)
    S.Panel(pop)
    pop.title = S.Text(pop, "", 14, -12, 600, 13, YELLOW)
    pop.heads, pop.tiles, pop.swatches, pop.dots, pop.pats = {}, {}, {}, {}, {}
    pop:Hide()
    S.Popup(pop, "GamepadCompanionLightPicker", { outside = true })
    pop.off = S.NewButton(pop, "Off", 0, 0, 70, nil, nil, 12, 26)
    pop.off.label:SetTextColor(1, 0.48, 0.36)
    pop.try = S.NewButton(pop, "Try", 0, 0, 70, nil, nil, 12, 26)
    pop.colourHead = S.Text(pop, "Colour", 14, 0, 80, 11, DIM)
    pop.strengthHead = S.Text(pop, "Strength", 14, 0, 80, 11, DIM)
    pop.dotsHead = S.Text(pop, "Dots", 14, 0, 300, 11, DIM)
    pop.micHead = S.Text(pop, "Mic · orange", 14, 0, 300, 11, DIM)
    pop:SetScript("OnUpdate", function()
        local LT = ns.Lights
        if not pop.key then return end
        local s = LT.Settings(pop.key)
        local ctx = LT.Ctx(s.color, s.strength)
        local now = Now() - (pop.started or 0)
        for _, t in ipairs(pop.tiles) do
            if t:IsShown() and t.light then
                local l = t.light
                local len = LT.Length(l)
                local tt = l.kind == "once" and now % (len + 0.7) or LT.LoopTime(l, now % 8)
                local r, g, b = LT.Sample(l, tt, ctx)
                if r then t.swatch:SetColorTexture(Shown(r, g, b)) else t.swatch:SetColorTexture(0.05, 0.05, 0.05, 1) end
            end
        end
    end)
end

local function Tile(i)
    local t = pop.tiles[i]
    if t then return t end
    t = S.NewButton(pop, "", 0, 0, TILE_W, nil, nil, 11, TILE_H)
    t.swatch = t:CreateTexture(nil, "ARTWORK")
    t.swatch:SetPoint("TOPLEFT", 10, -8)
    t.swatch:SetPoint("TOPRIGHT", -10, -8)
    t.swatch:SetHeight(9)
    t.label:ClearAllPoints()
    t.label:SetPoint("BOTTOMLEFT", 6, 6)
    t.label:SetPoint("BOTTOMRIGHT", -6, 6)
    pop.tiles[i] = t
    return t
end

local function Head(i)
    local h = pop.heads[i]
    if not h then h = S.Text(pop, "", 14, 0, 200, 11, DIM); pop.heads[i] = h end
    return h
end

-- Open the picker for a moment's light next to `anchor`; onChange() after any pick
function LP.Open(anchor, key, onChange)
    local LT = ns.Lights
    if not (LT and LT.Def(key)) then return end
    if not pop then Build() end
    if pop:IsShown() and pop.anchor == anchor then return pop:Hide() end
    pop.anchor, pop.key, pop.started = anchor, key, Now()
    local function Changed()
        if onChange then onChange() end
        LP.Refresh()
    end
    pop.title:SetText(LT.Def(key).label)
    for _, t in ipairs(pop.tiles) do t:Hide() end
    for _, h in ipairs(pop.heads) do h:Hide() end
    local y, n = -36, 0
    for si, sec in ipairs(LP.Sections(key)) do
        local h = Head(si)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 14, y)
        h:SetText(sec[1])
        h:Show()
        y = y - 16
        for j, l in ipairs(sec[2]) do
            n = n + 1
            local t = Tile(n)
            local col, row = (j - 1) % COLS, floor((j - 1) / COLS)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", 12 + col * (TILE_W + 3), y - row * (TILE_H + 3))
            t.label:SetText(l.name)
            S.Tooltip(t, l.name)
            t.light = l
            t:SetScript("OnClick", function()
                local s = LT.Own(key)
                s.on, s.light = true, l.id
                -- a light of yours with its own dots or mic plays them
                if l.yours and l.leds then s.dots = "light" end
                if l.yours and l.mic then s.mic = "light" end
                LT.Try(key)
                Changed()
            end)
            t:Show()
        end
        y = y - math.ceil(#sec[2] / COLS) * (TILE_H + 3) - 6
    end
    -- colours
    pop.colourHead:ClearAllPoints()
    pop.colourHead:SetPoint("TOPLEFT", 14, y - 2)
    y = y - 18
    for _, sw in ipairs(pop.swatches) do sw:Hide() end
    for i, c in ipairs(LP.Colours(key)) do
        local sw = pop.swatches[i]
        if not sw then
            sw = CreateFrame("Button", nil, pop)
            sw:SetSize(30, 22)
            sw.tex = sw:CreateTexture(nil, "ARTWORK")
            sw.tex:SetPoint("TOPLEFT", 3, -3)
            sw.tex:SetPoint("BOTTOMRIGHT", -3, 3)
            sw.sel = sw:CreateTexture(nil, "BACKGROUND")
            sw.sel:SetAllPoints()
            sw.sel:SetColorTexture(1, 0.82, 0, 1)
            sw.text = sw:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sw.text:SetPoint("CENTER")
            sw:SetScript("OnEnter", S.ShowTooltip)
            sw:SetScript("OnLeave", S.HideTooltip)
            pop.swatches[i] = sw
        end
        sw:ClearAllPoints()
        sw:SetPoint("TOPLEFT", 12 + (i - 1) * 33, y)
        local rgb = c.rgb or LT.ColorRGB(c.key)
        sw.tex:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
        sw.text:SetText(c.key == "own" and "·" or c.key == "base" and "B" or c.key == "school" and "S" or "")
        S.Tooltip(sw, c.label)
        sw.key = c.key
        sw:SetScript("OnClick", function()
            LT.Own(key).color = c.key
            LT.Try(key)
            Changed()
        end)
        sw:Show()
    end
    y = y - 30
    -- strength: 8 dots
    pop.strengthHead:ClearAllPoints()
    pop.strengthHead:SetPoint("TOPLEFT", 14, y - 2)
    for i = 0, 7 do
        local d = pop.dots[i]
        if not d then
            d = CreateFrame("Button", nil, pop)
            d:SetSize(18, 18)
            d.tex = d:CreateTexture(nil, "ARTWORK")
            d.tex:SetPoint("CENTER")
            d.tex:SetSize(10, 10)
            d:SetScript("OnEnter", S.ShowTooltip)
            d:SetScript("OnLeave", S.HideTooltip)
            S.Tooltip(d, floor(LT.Strength(i) * 100 + 0.5) .. "%")
            pop.dots[i] = d
        end
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", 90 + i * 22, y)
        d:SetScript("OnClick", function()
            LT.Own(key).strength = i
            LT.Try(key)
            Changed()
        end)
        d:Show()
    end
    -- the dots under the touchpad and the mic: a row of patterns each ("Light's": a light of
    -- yours with its own)
    local s0 = LT.Settings(key)
    local lit = LT.Light(s0.light)
    -- (a row wraps at the popup's edge: L9) -> the lines it took
    local inside = COLS * (TILE_W + 3) - 4
    local function Row(head, list, field, y0)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 14, y0 - 2)
        local x, line = 0, 0
        for _, p in ipairs(list) do
            if p.key ~= "light" or (lit and lit.yours) or s0[field] == "light" then
                local b = pop.pats[field .. p.key]
                if not b then
                    b = S.NewButton(pop, p.label, 0, 0, 40, nil, nil, 11, 22)
                    pop.pats[field .. p.key] = b
                end
                local w = (p.key == "light" and 56) or (#p.label == 1 and 26) or 52
                if x + w > inside then x, line = 0, line + 1 end
                b:SetWidth(w)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 12 + x, y0 - 16 - line * 25)
                b.field, b.value = field, p.key
                b:SetScript("OnClick", function()
                    LT.Own(key)[field] = p.key
                    LT.Try(key)
                    Changed()
                end)
                b:Show()
                x = x + w + 3
            elseif pop.pats[field .. p.key] then
                pop.pats[field .. p.key]:Hide()
            end
        end
        return line + 1
    end
    local strengthY = y
    y = y - 30
    y = y - 19 - 25 * Row(pop.dotsHead, LT.DOTS, "dots", y)
    y = y - 21 - 25 * Row(pop.micHead, LT.MICS, "mic", y)
    if not ns.HelperLink or not ns.Lights.HelperDrives() then
        pop.dotsHead:SetText("Dots · WoW Helper")
        pop.micHead:SetText("Mic · orange · WoW Helper")
    else
        pop.dotsHead:SetText("Dots")
        pop.micHead:SetText("Mic · orange")
    end
    -- Off, Try
    local width = 24 + COLS * (TILE_W + 3)
    pop.try:ClearAllPoints()
    pop.try:SetPoint("TOPRIGHT", -12, strengthY + 4)   -- (on the strength row)
    pop.try:SetScript("OnClick", function() LT.Try(key) end)
    pop.off:ClearAllPoints()
    pop.off:SetPoint("RIGHT", pop.try, "LEFT", -6, 0)
    pop.off:SetScript("OnClick", function()
        LT.Own(key).on = false
        Changed()
        pop:Hide()
    end)
    y = y + 8
    pop:SetSize(width, -y + 8)
    pop.title:SetWidth(width - 56)
    pop:ClearAllPoints()
    pop:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 8)
    pop:SetClampedToScreen(true)
    LP.Refresh()
    pop:Show()
    pop:Raise()
end

-- Selection marks: the light, the colour, the strength
function LP.Refresh()
    if not (pop and pop.key) then return end
    local s = ns.Lights.Settings(pop.key)
    for _, t in ipairs(pop.tiles) do S.SetSelected(t, t:IsShown() and s.on and t.light and t.light.id == s.light) end
    for _, sw in ipairs(pop.swatches) do sw.sel:SetShown(sw.key == s.color) end
    for _, b in pairs(pop.pats) do S.SetSelected(b, b:IsShown() and s[b.field] == b.value) end
    for i = 0, 7 do
        local d = pop.dots[i]
        if d then
            local lit = i <= s.strength
            d.tex:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], lit and (i == s.strength and 1 or 0.6) or 0.15)
        end
    end
end

function LP.Hide() if pop then pop:Hide() end end
