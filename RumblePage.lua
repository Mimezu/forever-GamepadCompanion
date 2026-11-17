-- The Rumble tab: every vibration in one place. Strength and the motors on
-- the left with the groups under them; a group's events on the right, each
-- a row: its feel on a plate (opens the palette: Off and Match the... first,
-- then every feel by group), Try, Default (the feel it ships with) and Edit
-- (a copy of your own, in the Beta tab's editor). Rumble's own events
-- (Rumble.lua, ported from Improved Forever: Vibration), the Beta engine's
-- (HapticsLab.lua) and the cast sets share the rows.
local _, ns = ...
local S, Shell, V, H, L, HUI = ns.OptionsSkin, ns.Shell, ns.Rumble, ns.Haptics, ns.HapticsLab, ns.HapticsUI
local API = GamepadCompanionAPI
local W, PH = Shell.W, Shell.H
local GOLD, GREY, DIM, YELLOW = S.GOLD, S.GREY, S.DIM, S.YELLOW
local RED = { 1, 0.48, 0.36 }
local floor, max, min = math.floor, math.max, math.min

local ui = { rows = {} }
local pg = { refresh = {} }
local Refresh
pg.Refresh = function() Refresh() end

local function Say(text, warn)
    Shell.SetStatus(warn and ("|cffff7a5c" .. text .. "|r") or text, true)
end

local function On()
    if V.Other() then Say("Improved Forever: Vibration is on", true); return false end
    if V.Settings().enabled then return true end
    Say("Rumble is off", true)
    return false
end

---------------------------------------------------------------------------
-- The groups and what is in each: r Rumble's events, c the cast sets, l the
-- Beta engine's events
---------------------------------------------------------------------------
local GROUPS = {
    { key = "Attacks", items = { { "r", "autoAttack" }, { "l", "hit" }, { "r", "crit" }, { "r", "critRanged" }, { "r", "shot" },
        { "l", "miss" }, { "l", "targetDodge" }, { "l", "targetParry" }, { "l", "targetBlock" }, { "l", "kill" } } },
    { key = "Defense", items = { { "l", "hitTaken" }, { "r", "critted" }, { "l", "dodge" }, { "l", "parry" }, { "l", "block" },
        { "l", "missedYou" }, { "r", "lowHp" }, { "l", "heartbeat" }, { "l", "control" }, { "l", "targetCast" }, { "l", "aggro" } } },
    { key = "Abilities", items = { { "c", "spell" }, { "c", "gather" }, { "c", "craft" }, { "r", "instant" }, { "l", "tension" },
        { "l", "gcd" }, { "l", "combo" }, { "l", "comboFull" }, { "l", "full" }, { "l", "oom" } } },
    { key = "Moving", items = { { "r", "jump" }, { "l", "landing" }, { "l", "footsteps" }, { "l", "wading" }, { "l", "riding" }, { "l", "splash" },
        { "l", "underwater" }, { "l", "mount" }, { "l", "dismount" }, { "l", "taxi" } } },
    { key = "Care", items = { { "r", "eat" }, { "r", "drink" }, { "l", "bandage" }, { "l", "potion" }, { "l", "rested" } } },
    { key = "Weather", items = { { "l", "rain" }, { "l", "thunder" }, { "l", "snow" }, { "l", "sand" }, { "l", "embers" } } },
    { key = "Progress", items = { { "r", "levelUp" }, { "l", "loot" }, { "l", "money" }, { "l", "questAccepted" },
        { "l", "questDone" }, { "l", "skillUp" }, { "l", "death" }, { "l", "alive" } } },
    { key = "Social", items = { { "l", "whisper" }, { "l", "readyCheck" }, { "l", "invite" }, { "l", "summon" }, { "l", "uiError" },
        { "r", "haloOpen" }, { "r", "wheelTick" }, { "r", "haloUse" }, { "r", "haloClose" } } },
}
ui.GROUPS = GROUPS

local REVENT, KIND = {}, {}
for _, e in ipairs(V.EVENTS) do REVENT[e.key] = e end
for _, k in ipairs(V.CAST_KINDS) do KIND[k.key] = k end

local OFF = { key = "off", label = "Off", icon = V.OFF_ICON }

---------------------------------------------------------------------------
-- Each kind of row: what it shows, how it is picked, tried, reset, copied
---------------------------------------------------------------------------
local ITEM = {}

-- Rumble's events: a pattern (any feel of the palette: "r_" Rumble's own,
-- else a Beta feel registered as "x_"), Match the..., or Off
ITEM.r = {
    label = function(key) return REVENT[key].label end,
    icon = function(key) return REVENT[key].icon end,
    tip = function(key) return REVENT[key].tip end,
    show = function(key)
        local e = REVENT[key]
        local choice = V.EventChoice(key)
        if choice == "off" then return "Off", V.OFF_ICON, nil, true end
        if choice == "auto" then
            local now = e.family ~= "move" and V.Pattern(V.EventPattern(key))
            return e.auto, e.icon, now and ("Now: " .. now.label) or "Each one its own feel"
        end
        local p = V.Pattern(choice)
        return p and p.label or choice, p and p.icon, e.loop and "While it lasts" or nil
    end,
    current = function(key)
        local choice = V.EventChoice(key)
        if choice == "off" or choice == "auto" then return choice end
        return L.FeelFor(choice)
    end,
    specials = function(key)
        local e = REVENT[key]
        local list = { OFF }
        if e.auto then list[2] = { key = "auto", label = e.auto, icon = e.icon } end
        return list
    end,
    pick = function(key, feel)
        local pattern = feel
        if feel ~= "off" and feel ~= "auto" then
            L.RegisterInRumble()
            pattern = L.PatternFor(feel)
        end
        V.SetEventPattern(key, pattern)
        if pattern ~= "off" and V.Settings().enabled then
            local now = V.EventPattern(key)
            if now then V.Play(now) end
        end
    end,
    isDefault = function(key)
        local e = REVENT[key]
        local cfg = V.Settings().events[key]
        return cfg.on == e.on and cfg.pattern == e.pattern
    end,
    default = function(key)
        local e = REVENT[key]
        local cfg = V.Settings().events[key]
        cfg.on, cfg.pattern = e.on, e.pattern
    end,
    -- the feel to copy: the one playing now (Match the...: the current match)
    feel = function(key)
        local p = V.Pattern(V.EventPattern(key))
        return p and p.feel, p and p.label
    end,
    assign = function(key, ownKey)
        L.RegisterInRumble()
        V.SetEventPattern(key, "x_" .. ownKey)
    end,
    try = function(key)
        if not On() then return end
        local e = REVENT[key]
        local pattern = V.EventPattern(key)
        if e.family == "move" and V.EventChoice(key) ~= "off" then
            V.SimulateMoves(key, function(name)
                local feel = V.Pattern(V.EventPattern(key))
                Say(name .. (feel and ": " .. feel.label or ""))
            end)
        elseif not pattern then
            Say(e.label .. " is off", true)
        elseif e.loop then
            if V.SimulateLoop(key, 6) then Say(e.label .. ": playing · Try again stops") else Say(e.label .. ": stopped") end
        elseif key == "shot" or key == "autoAttack" then
            V.SimulateShots(key, function(n)
                local p = V.Pattern(V.EventPattern(key))
                Say(e.label .. ": " .. (p and p.label or "") .. (n > 1 and " x" .. n or ""))
            end)
        elseif e.combo then
            V.SimulateCombo(key, function(n) Say(e.label .. (n > 1 and " x" .. n or "")) end)
        else
            V.Play(pattern)
        end
    end,
}

-- The cast sets (spells, gathering, crafting): a set for the four moments
ITEM.c = {
    label = function(key) return KIND[key].label end,
    icon = function(key) return KIND[key].icon end,
    tip = function(key) return KIND[key].tip end,
    show = function(key)
        local preset = V.Preset(V.CastPreset(key))
        if not preset or preset.key == "off" then return "Off", V.OFF_ICON, nil, true end
        if preset.auto then return preset.label, preset.icon, "Each action its own feel" end
        local parts = {}
        for _, phase in ipairs(V.CAST_PHASES) do
            local p = V.Pattern(preset[phase])
            if p then parts[#parts + 1] = p.label end
        end
        return preset.label, preset.icon, table.concat(parts, " · ")
    end,
    isDefault = function(key) return V.CastPreset(key) == KIND[key].preset end,
    default = function(key) V.SetCastPreset(key, KIND[key].preset) end,
    try = function(key)
        if not On() then return end
        if V.CastPreset(key) == "off" then return Say(KIND[key].label .. " is off", true) end
        V.SimulateCast(function(label) if label then Say(KIND[key].label .. ": " .. label) end end, key)
    end,
}

-- The Beta engine's events: a feel of the palette, or Off
ITEM.l = {
    label = function(key) return L.EVENT[key].label end,
    icon = function(key) return L.EVENT[key].icon end,
    tip = function(key) return L.EVENT[key].tip end,
    show = function(key)
        local e = L.EVENT[key]
        local s = L.EventSettings(key)
        if not s.on then return "Off", V.OFF_ICON, nil, true end
        local f = H.Feel(s.feel)
        local sub = e.live and "While it lasts" or nil
        return f and (f.label or f.key) or "?", f and f.icon, sub
    end,
    current = function(key)
        local s = L.EventSettings(key)
        return s.on and s.feel or "off"
    end,
    specials = function() return { OFF } end,
    pick = function(key, feel)
        local s = L.EventSettings(key)
        if feel == "off" then s.on = false else s.on, s.feel = true, feel; L.Try(key) end
    end,
    isDefault = function(key) return L.IsEventDefault(key) end,
    default = function(key) L.EventDefault(key) end,
    feel = function(key)
        local f = H.Feel(L.EventSettings(key).feel)
        return f, f and f.label
    end,
    assign = function(key, ownKey)
        local s = L.EventSettings(key)
        s.on, s.feel = true, ownKey
    end,
    try = function(key) L.Try(key) end,
}

---------------------------------------------------------------------------
-- A row
---------------------------------------------------------------------------
local function CastSets()
    local entries = {}
    for _, p in ipairs(V.CAST_PRESETS) do
        if not p.action then entries[#entries + 1] = { key = p.key, label = p.label, icon = p.icon } end
    end
    return entries
end

local function MakeRow(parent, y, width, kind, key)
    local I = ITEM[kind]
    local label = I.label(key)
    local function Edit()
        local feel, name = I.feel(key)
        if not feel then return Say("Nothing to copy: pick a feel first", true) end
        local beta = ns.BetaPage
        if not (beta and beta.EditCopy) then return end
        local own = beta.EditCopy(feel, (name or label) .. " (mine)")
        I.assign(key, own)
        Say(label .. ": your copy, in the editor")
    end
    local row = HUI.ChoiceRow(parent, y, width, I.icon(key), label, function(anchor)
        if kind == "c" then
            HUI.Popup(anchor, label, CastSets(), V.CastPreset(key), function(preset)
                V.SetCastPreset(key, preset)
                Refresh()
                if preset ~= "off" then I.try(key) end
            end, 3, 150)
            return
        end
        HUI.PickFeel(anchor, I.current(key), function(feel)
            I.pick(key, feel)
            Refresh()
        end, I.specials(key), label)
    end, function() I.try(key) end, I.tip(key), {
        default = function()
            I.default(key)
            Say(label .. ": its default")
            Refresh()
        end,
        edit = I.feel and Edit or nil,
    })
    row.kind, row.key = kind, key
    ui.rows[#ui.rows + 1] = row
    return row
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local LEFT_W = 300

local function Build(frame, header)
    ui.enable = S.NewCheck(header, "Rumble", W - 110, -4, function(self)
        V.Settings().enabled = self:GetChecked() == true
        if V.Settings().enabled then V.Play("pulse") else V.Stop() end
        Refresh()
    end, 70)
    S.Tooltip(ui.enable, "Rumble", "Off: nothing vibrates")
    local dbg = S.NewButton(header, "Debug", W - 220, -4, 80, function()
        if ns.HapticsDebug then ns.HapticsDebug.Show() end
    end, nil, 12, 26)
    S.Tooltip(dbg, "Debug", "What vibrates and why, while you play")
    ui.why = S.Text(header, "", 140, -10, W - 380, 11, GREY)
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
        ui.why:SetText(text and string.format("%s · %ds ago", text, floor(ago)) or "")
    end)

    -- Left: strength, the motors, then the groups
    local left = S.Card(frame, "Feel", 0, 0, LEFT_W, PH)
    S.Text(left, "Strength", 14, -46, 100, 13, GOLD)
    ui.minus = S.NewButton(left, "-", 120, -38, 34, function()
        local s = V.Settings()
        s.intensity = max(0.1, floor(s.intensity * 10 + 0.5) / 10 - 0.1)
        V.Play("pulse")
        Refresh()
    end, nil, 16, 30)
    ui.strength = S.Text(left, "", 156, -45, 70, 14, YELLOW)
    ui.strength:SetJustifyH("CENTER")
    ui.plus = S.NewButton(left, "+", 228, -38, 34, function()
        local s = V.Settings()
        s.intensity = min(1, floor(s.intensity * 10 + 0.5) / 10 + 0.1)
        V.Play("pulse")
        Refresh()
    end, nil, 16, 30)
    ui.bar = {}
    for i = 1, 10 do
        local t = left:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", 14 + (i - 1) * 27, -78)
        t:SetSize(23, 8)
        ui.bar[i] = t
    end
    ui.pulse = S.NewButton(left, "Feel it", 14, -96, 86, function() if On() then V.Play("pulse") end end, nil, 12, 28)
    ui.sides = S.NewButton(left, "Motors", 107, -96, 86, function() V.TestSides() end, nil, 12, 28)
    S.Tooltip(ui.sides, "Test each motor", "Left grip, right grip, triggers · in chat")
    ui.stop = S.NewButton(left, "Stop", 200, -96, 86, function()
        V.StopSimulation(); V.Stop(); if H then H.Stop() end; Say("Stopped")
    end, nil, 12, 28)
    S.Heading(left, "Events", 10, -136, LEFT_W - 20)

    local groups = {}
    for _, g in ipairs(GROUPS) do groups[#groups + 1] = { key = g.key, label = g.key } end
    local list = CreateFrame("Frame", nil, left)
    list:SetPoint("TOPLEFT", 0, -150)
    list:SetSize(LEFT_W, PH - 150)
    local b = HUI.GroupBrowser(frame, groups, { left = list, leftWidth = LEFT_W, top = -8, width = W - LEFT_W - 10,
        pageTop = 0 })
    ui.browser = b
    for _, g in ipairs(GROUPS) do
        local panel = b.panels[g.key]
        local card = S.Card(panel, g.key, 0, 0, W - LEFT_W - 10, 44 + #g.items * HUI.ROW_H)
        for i, item in ipairs(g.items) do
            MakeRow(card, -38 - (i - 1) * HUI.ROW_H, W - LEFT_W - 10, item[1], item[2])
        end
    end
    ui.other = S.Text(left, "", 14, -(PH - 74), LEFT_W - 28, 11, RED)
    ui.credit = S.Text(left, "Patterns: Improved Forever: Vibration (markg) and Easy Controller (moust4ki), MIT",
        14, -(PH - 46), LEFT_W - 28, 9, DIM)
end

Refresh = function()
    if not ui.enable then return end
    local s = V.Settings()
    local other = V.Other()
    ui.enable:SetChecked(s.enabled and not other)
    ui.enable:SetEnabled(not other)
    local n = floor(s.intensity * 10 + 0.5)
    ui.strength:SetText((n * 10) .. "%")
    ui.minus:SetEnabled(n > 1)
    ui.plus:SetEnabled(n < 10)
    for i, t in ipairs(ui.bar) do
        if i <= n then t:SetColorTexture(1, 0.78, 0.25, 0.9) else t:SetColorTexture(1, 1, 1, 0.12) end
    end
    ui.other:SetText(other and "Improved Forever: Vibration is on: Companion stays off" or "")
    for _, row in ipairs(ui.rows) do
        local I = ITEM[row.kind]
        local name, icon, sub, off = I.show(row.key)
        row:SetChoice(name, icon, sub, off, nil, I.isDefault(row.key))
        row:SetAlpha((s.enabled and not other) and 1 or 0.55)
    end
    for _, g in ipairs(GROUPS) do
        local on = 0
        for _, item in ipairs(g.items) do
            local _, _, _, off = ITEM[item[1]].show(item[2])
            if not off then on = on + 1 end
        end
        ui.browser.buttons[g.key].count:SetText(on .. "/" .. #g.items)
    end
    for _, fn in ipairs(pg.refresh) do fn() end
    Shell.SetStatus(other and "Improved Forever: Vibration rumbles" or (s.enabled and "" or "Rumble off"))
end
ui.Refresh = function() Refresh() end
ns.RumblePage = ui

Shell.AddPage({
    key = "moments", name = "Moments", order = 2, aliases = { "rumble" }, icon = "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_mod_vibration",
    build = Build, refresh = function() Refresh() end,
    hide = function()
        V.StopSimulation()
        HUI.HidePopup()
    end,
})

function API.OpenRumble() Shell.Open("moments") end
-- /gpc light: Moments on a kind
function API.OpenMoments(kind)
    Shell.Open("moments")
    if kind and ui.SetKind then ui.SetKind(kind) end
end
