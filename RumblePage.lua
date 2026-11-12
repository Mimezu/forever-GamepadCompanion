-- The Rumble page: the controller's motors on game events and casts
-- (Rumble.lua, ported from Improved Forever: Vibration). On / off and
-- strength; each event's pattern, or each kind of cast's set, chosen from a
-- grid of patterns; Try plays it as the game would.
local _, ns = ...
local S, Shell, V = ns.OptionsSkin, ns.Shell, ns.Rumble
local API = GamepadCompanionAPI
local W, H = Shell.W, Shell.H
local GOLD, GREY, DIM, YELLOW = S.GOLD, S.GREY, S.DIM, S.YELLOW
local FONT = "Fonts\\FRIZQT__.TTF"

local ui = { rows = {} }
local Refresh

local function Say(text, warn)
    Shell.SetStatus(warn and ("|cffff7a5c" .. text .. "|r") or text, true)
end

local function On()
    if V.Other() then Say("Improved Forever: Vibration is on", true); return false end
    if V.Settings().enabled then return true end
    Say("Rumble is off", true)
    return false
end

-- Rows: each event, and each kind of cast (a set for its four moments) --------------

local SECTION = {}
for _, g in ipairs(V.GROUPS) do SECTION[g.key] = g.label end

-- An event's choices: Off, its Match the..., its family's patterns, the general ones
local function Patterns(event)
    local entries = { { action = "off", name = "Off", icon = V.OFF_ICON } }
    if event.auto then entries[#entries + 1] = { action = "auto", name = event.auto, icon = event.icon } end
    for _, p in ipairs(V.PATTERNS) do
        if event.family and p[event.family] then entries[#entries + 1] = { action = p.key, name = p.label, icon = p.icon } end
    end
    for _, p in ipairs(V.PATTERNS) do
        if not p.action then entries[#entries + 1] = { action = p.key, name = p.label, icon = p.icon } end
    end
    return entries
end

local function CastSets()
    local entries = {}
    for _, p in ipairs(V.CAST_PRESETS) do
        if not p.action then entries[#entries + 1] = { action = p.key, name = p.label, icon = p.icon } end
    end
    return entries
end

local function PhaseName(phase)
    return phase == "cast" and "Casting" or phase == "pushback" and "Pushed back" or (phase:sub(1, 1):upper() .. phase:sub(2))
end

-- What a row shows: its choice, a second line, the choice's icon, whether it is off
local function Describe(rail)
    if rail.castKind then
        local preset = V.Preset(V.CastPreset(rail.castKind))
        if not preset or preset.key == "off" then return "Off", nil, V.OFF_ICON, true end
        if preset.auto then return preset.label, "Each action its own feel", preset.icon end
        local parts = {}
        for _, phase in ipairs(V.CAST_PHASES) do
            local pattern = V.Pattern(preset[phase])
            if pattern then parts[#parts + 1] = PhaseName(phase) .. ": " .. pattern.label end
        end
        return preset.label, table.concat(parts, " · "), preset.icon
    end
    local event = rail.subs[1]
    local choice = V.EventChoice(event.key)
    if choice == "auto" and event.family == "move" then return event.auto, "Each ability its own feel", event.icon end
    local pattern = V.Pattern(V.EventPattern(event.key))
    if not pattern then return "Off", nil, V.OFF_ICON, true end
    if choice == "auto" then return event.auto, "Now: " .. pattern.label, pattern.icon end
    return pattern.label, nil, pattern.icon
end

local function Choose(rail, action)
    if rail.castKind then
        V.SetCastPreset(rail.castKind, action)
        local preset = V.Preset(action)
        Say(rail.label .. ": " .. (preset and preset.label or action))
        Refresh()
        if action ~= "off" and V.Settings().enabled then rail.try() end
        return
    end
    local event = rail.subs[1]
    V.SetEventPattern(event.key, action)
    local key = not (action == "auto" and event.family == "move") and V.EventPattern(event.key)
    if key and V.Settings().enabled then V.Play(key) end
    local pattern = V.Pattern(key)
    Say(event.label .. ": " .. (action == "auto" and (event.auto .. (pattern and " (" .. pattern.label .. ")" or ""))
        or (pattern and pattern.label or "Off")))
    Refresh()
end

-- Try: felt as the game would play it (a cast's moments, a run of crits, a loop...)
local function Try(rail)
    if not On() then return end
    if rail.castKind then
        if V.CastPreset(rail.castKind) == "off" then return Say(rail.label .. " is off", true) end
        V.SimulateCast(function(label) if label then Say(rail.label .. ": " .. label) end end, rail.castKind)
        return
    end
    local event = rail.subs[1]
    local pattern = V.EventPattern(event.key)
    if event.family == "move" and V.EventChoice(event.key) ~= "off" then
        V.SimulateMoves(event.key, function(name)
            local feel = V.Pattern(V.EventPattern(event.key))
            Say(name .. (feel and ": " .. feel.label or ""))
        end)
    elseif not pattern then
        Say(event.label .. " is off", true)
    elseif event.loop then
        if V.SimulateLoop(event.key, 6) then Say(event.label .. ": playing · Try again stops")
        else Say(event.label .. ": stopped") end
    elseif event.key == "shot" then
        V.SimulateShots(event.key, function(n)
            Say(event.label .. ": " .. V.Pattern(pattern).label .. (n > 1 and " x" .. n or ""))
        end)
    elseif event.combo then
        V.SimulateCombo(event.key, function(n) Say(event.label .. (n > 1 and " x" .. n or "")) end)
    else
        V.Play(pattern)
    end
end

-- The pattern grid ----------------------------------------------------------------

local COLS, TILE_W, TILE_H = 4, 92, 70
local grid

local function BuildGrid()
    grid = CreateFrame("Frame", "GamepadCompanionRumbleChoices", Shell.Window())
    grid:SetFrameStrata("DIALOG")
    grid:SetToplevel(true)
    grid:EnableMouse(true)
    S.Panel(grid)
    grid.title = S.Text(grid, "", 14, -12, COLS * (TILE_W + 4), 13, YELLOW)
    grid.tiles = {}
    grid:Hide()
    grid:SetScript("OnHide", function() grid.rail = nil end)
    UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionRumbleChoices"
end

local function Tile(index)
    local t = grid.tiles[index]
    if t then return t end
    t = CreateFrame("Button", nil, grid)
    t:SetSize(TILE_W, TILE_H)
    t.bg = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    t.bg:SetAllPoints()
    t.bg:SetColorTexture(1, 0.85, 0.55, 0.05)
    t.selection = t:CreateTexture(nil, "BACKGROUND", nil, 2)
    t.selection:SetAllPoints()
    t.selection:SetColorTexture(1, 0.72, 0.2, 0.25)
    local hover = t:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.75, 0.3, 0.16)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(38, 38)
    t.icon:SetPoint("TOP", 0, -5)
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.label:SetFont(FONT, 10, "")
    t.label:SetPoint("BOTTOMLEFT", 2, 5)
    t.label:SetPoint("BOTTOMRIGHT", -2, 5)
    t.label:SetJustifyH("CENTER")
    t.label:SetWordWrap(false)
    t.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    t:RegisterForClicks("LeftButtonUp")
    t:SetScript("OnClick", function(self)
        local rail = grid.rail
        grid:Hide()
        if rail and self.entry then Choose(rail, self.entry.action) end
    end)
    grid.tiles[index] = t
    return t
end

local function OpenGrid(rail, anchor)
    if not grid then BuildGrid() end
    if grid:IsShown() and grid.rail == rail then grid:Hide(); return end
    grid.rail = rail
    local entries = rail.castKind and CastSets() or Patterns(rail.subs[1])
    local current = rail.castKind and V.CastPreset(rail.castKind) or V.EventChoice(rail.subs[1].key)
    grid.title:SetText(rail.label)
    for _, t in ipairs(grid.tiles) do t:Hide() end
    for i, e in ipairs(entries) do
        local t = Tile(i)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 12 + col * (TILE_W + 4), -36 - row * (TILE_H + 4))
        t.entry = e
        t.icon:SetTexture(e.icon)
        t.label:SetText(e.name)
        t.selection:SetShown(e.action == current)
        t:Show()
    end
    local rows = math.ceil(#entries / COLS)
    grid:SetSize(24 + COLS * (TILE_W + 4) - 4, 48 + rows * (TILE_H + 4))
    grid:ClearAllPoints()
    grid:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 8)
    grid:SetClampedToScreen(true)
    grid:Show()
    grid:Raise()
end

-- Build ---------------------------------------------------------------------------

local ROW_H = 44

local function Row(parent, rail, y, width)
    local r = CreateFrame("Frame", nil, parent)
    r:SetPoint("TOPLEFT", 10, y)
    r:SetSize(width - 20, ROW_H - 4)
    local hover = r:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.85, 0.55, 0.04)
    r.eventIcon = r:CreateTexture(nil, "ARTWORK")
    r.eventIcon:SetSize(30, 30)
    r.eventIcon:SetPoint("LEFT", 2, 0)
    r.eventIcon:SetTexture(rail.icon)
    r.label = S.Text(r, rail.label, 40, -4, 140, 13, GOLD)
    r.label:SetWordWrap(false)
    r.choice = S.Text(r, "", 40, -22, width - 20 - 40 - 150, 11, GREY)
    r.choice:SetWordWrap(false)
    -- The pattern: its icon and name on a plate that opens the grid
    r.pick = S.NewButton(r, "", width - 20 - 146, -5, 110, nil, nil, 11, 30)
    r.pick.icon = r.pick:CreateTexture(nil, "OVERLAY")
    r.pick.icon:SetSize(20, 20)
    r.pick.icon:SetPoint("LEFT", 6, 0)
    r.pick.label:ClearAllPoints()
    r.pick.label:SetPoint("LEFT", 30, 0)
    r.pick.label:SetPoint("RIGHT", -6, 0)
    r.pick.label:SetJustifyH("LEFT")
    r.pick:SetScript("OnClick", function(self) OpenGrid(rail, self) end)
    S.Tooltip(r.pick, rail.label, rail.tip or (rail.subs and rail.subs[1].tip))
    r.try = S.NewButton(r, "Try", width - 20 - 32, -5, 32, function() Try(rail) end, nil, 11, 30)
    S.Tooltip(r.try, "Try", rail.label)
    rail.try = function() Try(rail) end
    r.rail = rail
    ui.rows[#ui.rows + 1] = r
    return r
end

local function Column(frame, groups, x, width)
    local y = 0
    for _, g in ipairs(groups) do
        local rails = {}
        for _, rail in ipairs(V.RAIL) do if rail.group == g then rails[#rails + 1] = rail end end
        local height = 40 + #rails * ROW_H
        local card = S.Card(frame, SECTION[g], x, -y, width, height)
        for i, rail in ipairs(rails) do Row(card, rail, -36 - (i - 1) * ROW_H, width) end
        y = y + height + 10
    end
end

local function Build(frame, header)
    ui.enable = S.NewCheck(header, "Rumble", W - 110, -4, function(self)
        V.Settings().enabled = self:GetChecked() == true
        if V.Settings().enabled then V.Play("pulse") else V.Stop() end
        Refresh()
    end, 70)
    S.Tooltip(ui.enable, "Rumble", "Off: no event rumbles")

    -- Left: strength, the motors, the other addon
    local left = S.Card(frame, "Feel", 0, 0, 300, H)
    S.Text(left, "Strength", 14, -48, 100, 13, GOLD)
    ui.minus = S.NewButton(left, "-", 120, -40, 34, function()
        local s = V.Settings()
        s.intensity = math.max(0.1, math.floor(s.intensity * 10 + 0.5) / 10 - 0.1)
        V.Play("pulse")
        Refresh()
    end, nil, 16, 30)
    ui.strength = S.Text(left, "", 156, -47, 70, 14, YELLOW)
    ui.strength:SetJustifyH("CENTER")
    ui.plus = S.NewButton(left, "+", 228, -40, 34, function()
        local s = V.Settings()
        s.intensity = math.min(1, math.floor(s.intensity * 10 + 0.5) / 10 + 0.1)
        V.Play("pulse")
        Refresh()
    end, nil, 16, 30)
    -- (ten notches, lit up to the strength)
    ui.bar = {}
    for i = 1, 10 do
        local t = left:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", 14 + (i - 1) * 27, -84)
        t:SetSize(23, 8)
        ui.bar[i] = t
    end
    ui.pulse = S.NewButton(left, "Feel it", 14, -106, 272, function() if On() then V.Play("pulse") end end, nil, 13, 32)
    S.Text(left, "Motors", 14, -164, 260, 13, GOLD)
    ui.sides = S.NewButton(left, "Test each motor", 14, -186, 272, function() V.TestSides() end, nil, 13, 32)
    S.Tooltip(ui.sides, "Test each motor", "Left grip, right grip, triggers · in chat")
    ui.stop = S.NewButton(left, "Stop", 14, -224, 272, function() V.StopSimulation(); V.Stop(); Say("Stopped") end, nil, 13, 32)
    ui.other = S.Text(left, "", 14, -280, 272, 12, { 1, 0.48, 0.36 })
    ui.other:SetHeight(60)
    ui.other:SetJustifyV("TOP")
    ui.credit = S.Text(left, "Patterns: Improved Forever: Vibration (markg) and Easy Controller (moust4ki), MIT",
        14, -(H - 60), 272, 10, DIM)

    -- Right: the events, in two columns
    local colW = (W - 312 - 10) / 2
    Column(frame, { "combat", "progress" }, 312, colW)
    Column(frame, { "casting", "rest", "wheel" }, 312 + colW + 10, colW)
end

Refresh = function()
    if not ui.enable then return end
    local s = V.Settings()
    local other = V.Other()
    ui.enable:SetChecked(s.enabled and not other)
    ui.enable:SetEnabled(not other)
    local n = math.floor(s.intensity * 10 + 0.5)
    ui.strength:SetText((n * 10) .. "%")
    ui.minus:SetEnabled(n > 1)
    ui.plus:SetEnabled(n < 10)
    for i, t in ipairs(ui.bar) do
        if i <= n then t:SetColorTexture(1, 0.78, 0.25, 0.9) else t:SetColorTexture(1, 1, 1, 0.12) end
    end
    ui.other:SetText(other and "Improved Forever: Vibration is on: it rumbles, Companion stays off" or "")
    for _, r in ipairs(ui.rows) do
        local name, line, icon, off = Describe(r.rail)
        r.pick.label:SetText(name)
        r.pick.icon:SetTexture(icon)
        r.choice:SetText(line or "")
        if off then r.pick.label:SetTextColor(1, 0.48, 0.36) else r.pick.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
        r.eventIcon:SetDesaturated(off == true)
        r:SetAlpha((s.enabled and not other) and 1 or 0.55)
    end
    Shell.SetStatus(other and "Improved Forever: Vibration rumbles" or (s.enabled and "" or "Rumble off"))
end

Shell.AddPage({
    key = "rumble", name = "Rumble", order = 2, icon = "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_mod_vibration",
    build = Build, refresh = function() Refresh() end,
    hide = function()
        V.StopSimulation()
        if grid then grid:Hide() end
    end,
})

function API.OpenRumble() Shell.Open("rumble") end
