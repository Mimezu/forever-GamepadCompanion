-- The Moments tab (once Rumble): what the pad does when. One kind at a time
-- (Feel | Light | Sound), the same eight groups for each; the kind's master on
-- the left with the groups under it; a group's moments on the right, each a
-- row: its choice on a plate (opens its grid: Off first), Try, Default (as it
-- ships), Edit (WoW Helper once its data is there, else a copy of your own in
-- Lab's editor), and marks for the moment's other kinds. Rumble's own events
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

-- A moment's volume beside its plate (Volume.lua): kind "feel" or "sound"
local function Volume(kind)
    return function(key)
        local Vol = ns.Volume
        if not Vol then return nil end
        local get = kind == "feel" and Vol.Feel or Vol.Sound
        local set = kind == "feel" and Vol.SetFeel or Vol.SetSound
        return { step = Vol.STEP, min = 0, max = 1, format = Vol.Pct, get = function() return get(key) end,
            set = function(v) set(key, v) end }
    end
end

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
            V.Play(pattern, false, V.Scaled(nil, key))
        end
    end,
    level = Volume("feel"),
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
    level = Volume("feel"),
}

---------------------------------------------------------------------------
-- Lights and sounds: the same eight groups as the feels
---------------------------------------------------------------------------
local LT, C, K = ns.Lights, ns.HelperCues, ns.HelperLink
local BELL = "Interface\\Icons\\INV_Misc_Bell_01"
local LIGHT_ICON = "Interface\\Icons\\Spell_Nature_Lightning"

-- a light moment's group
local LIGHT_GROUP = {
    crit = "Attacks", kill = "Attacks",
    critTaken = "Defense", hitTaken = "Defense", avoid = "Defense", lowHp = "Defense", combat = "Defense",
    cast = "Abilities", release = "Abilities", interrupted = "Abilities", instant = "Abilities",
    levelUp = "Progress", questDone = "Progress", loot = "Progress", death = "Progress", alive = "Progress",
    whisper = "Social", readyCheck = "Social", invite = "Social", halo = "Social", haloUse = "Social",
}
-- a feel moment's light (several feels can share one light)
local LIGHT_OF = {
    crit = "crit", critRanged = "crit", critted = "critTaken", hitTaken = "hitTaken", dodge = "avoid", parry = "avoid",
    block = "avoid", kill = "kill", lowHp = "lowHp", spell = "cast", instant = "instant", haloOpen = "halo",
    haloUse = "haloUse", levelUp = "levelUp", questDone = "questDone", loot = "loot", death = "death", alive = "alive",
    whisper = "whisper", readyCheck = "readyCheck", invite = "invite",
}
-- and back: a light's first feel moment
local FEEL_OF = {}
for _, g in ipairs(GROUPS) do
    for _, item in ipairs(g.items) do
        local lk = LIGHT_OF[item[2]]
        if lk and not FEEL_OF[lk] then FEEL_OF[lk] = item[2] end
    end
end

-- Any moment's name and icon, whichever list has it
local function LabelOf(key)
    local e = REVENT[key] or (L.EVENT and L.EVENT[key]) or KIND[key] or (LT and LT.EVENT[key])
    return e and e.label or key
end
local function IconOf(key)
    local e = REVENT[key] or (L.EVENT and L.EVENT[key]) or KIND[key]
    return e and e.icon or LIGHT_ICON
end

local function Pct(v) return floor((v or 0) * 100 + 0.5) .. "%" end

ITEM.light = {
    label = function(key) return LT.EVENT[key].label end,
    icon = function(key) return FEEL_OF[key] and IconOf(FEEL_OF[key]) or LIGHT_ICON end,
    tip = function() return "Light, colour, strength" end,
    show = function(key)
        local s = LT.Settings(key)
        if not s.on then return "Off", V.OFF_ICON, nil, true end
        local l = LT.Light(s.light)
        -- who plays it: WoW Helper (every light, precisely) or the game (the bar)
        local sub = (LT.EVENT[key].state and "While it lasts · " or "") .. (LT.HelperDrives() and "WoW Helper" or "Game")
        return l and l.name or "?", nil, sub, false, LT.ColorRGB(s.color)
    end,
    pick = function(key, anchor) ns.LightPicker.Open(anchor, key, Refresh) end,
    isDefault = function(key) return LT.IsDefault(key) end,
    default = function(key) LT.Default(key) end,
    try = function(key) LT.Try(key) end,
    -- (strength: in the picker, one control)
}

local function SoundOn() return C and K and K.Enabled() and C.Settings().sounds == true end

ITEM.sound = {
    label = LabelOf,
    icon = IconOf,
    tip = function() return "A sound on the pad's speaker" end,
    show = function(key)
        local id = C.MomentSound(key)
        if not id then return "None", V.OFF_ICON, nil, true end
        return C.SoundName(id), BELL
    end,
    pick = function(key, anchor)
        local entries = { { key = "off", label = "None", icon = V.OFF_ICON } }
        for _, e in ipairs(C.SoundList()) do entries[#entries + 1] = { key = e.id, label = e.name, icon = BELL } end
        HUI.Popup(anchor, LabelOf(key), entries, C.MomentSound(key) or "off", function(choice)
            C.SetMomentSound(key, choice ~= "off" and choice or false)
            Refresh()
            if choice ~= "off" then ITEM.sound.try(key) end
        end, 3, 150)
    end,
    isDefault = function(key) return C.IsSoundDefault(key) end,
    default = function(key) C.SetMomentSound(key, nil) end,
    try = function(key)
        local id = C.MomentSound(key)
        if not id then return Say(LabelOf(key) .. ": no sound", true) end
        if not K.Enabled() then return Say("Link is off: Setup", true) end
        local gain = 7
        if ns.Volume then gain = ns.Volume.Gain(ns.Volume.SoundLevel(key)) end
        if not gain then return Say(LabelOf(key) .. ": volume 0%", true) end
        K.Play(id, gain)
        Say(LabelOf(key) .. ": " .. C.SoundName(id))
    end,
    level = Volume("sound"),
}

---------------------------------------------------------------------------
-- The kinds, and each one's moments by group
---------------------------------------------------------------------------
local KINDS = { { "feel", "Feel" }, { "light", "Light" }, { "sound", "Sound" } }
ui.kind = "feel"

local function Items(kind, group)
    if kind == "feel" then
        for _, g in ipairs(GROUPS) do if g.key == group then return g.items end end
        return {}
    end
    local list = {}
    if kind == "light" and LT then
        for _, e in ipairs(LT.EVENTS) do if LIGHT_GROUP[e.key] == group then list[#list + 1] = { "light", e.key } end end
    elseif kind == "sound" and C and C.MOMENTS then
        for _, m in ipairs(C.MOMENTS) do if m[2] == group then list[#list + 1] = { "sound", m[1] } end end
    end
    return list
end

local KIND_OF = { r = "feel", c = "feel", l = "feel", light = "light", sound = "sound" }

-- The other kinds a moment has, as marks
local Jump
local function Marks(row)
    local list = {}
    local kind = KIND_OF[row.kind]
    -- the feel, from a light or a sound row
    local feelOf = kind == "light" and FEEL_OF[row.key] or kind == "sound" and C and C.MomentFeel and C.MomentFeel(row.key) and row.key
    if feelOf then
        list[#list + 1] = { icon = "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_mod_vibration", tip = "Feel",
            onClick = function() Jump(feelOf, "feel") end }
    end
    local feelKey = kind == "feel" and row.key or (kind == "light" and FEEL_OF[row.key]) or row.key
    local lightKey = kind == "light" and row.key or LIGHT_OF[feelKey]
    if kind ~= "light" and lightKey and LT then
        local s = LT.Settings(lightKey)
        if s.on then
            list[#list + 1] = { rgb = LT.ColorRGB(s.color), tip = "Light", onClick = function() Jump(lightKey, "light") end }
        end
    end
    if kind ~= "sound" and feelKey and C and C.MomentSound(feelKey) then
        list[#list + 1] = { icon = BELL, tip = "Sound", onClick = function() Jump(feelKey, "sound") end }
    end
    return list
end

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

-- WoW Helper can open a moment: its data read, the HD link on
function ui.ToHelper()
    local data = C and type(C.HelperData) == "function" and C.HelperData()
    return data and K and K.Enabled() and K.V2() and type(C.EditHD) == "function" and true or false
end

local function MakeRow(parent, y, width, kind, key)
    local I = ITEM[kind]
    local label = I.label(key)
    -- Shape: in WoW Helper once it can take it; else Edit: a copy of your own in Lab's editor
    local function Edit()
        if ui.ToHelper() then
            local ok = C.EditHD(key)
            if ok then return Say(label .. ": in WoW Helper") end
        end
        local feel, name = I.feel(key)
        if not feel then return Say("Nothing to copy: pick a feel first", true) end
        local beta = ns.BetaPage
        if not (beta and beta.EditCopy) then return end
        local own = beta.EditCopy(feel, (name or label) .. " (mine)")
        I.assign(key, own)
        Say(label .. ": your copy, in the editor")
    end
    local row = HUI.MomentRow(parent, y, width, I.icon(key), label, function(anchor)
        if kind == "c" then
            HUI.Popup(anchor, label, CastSets(), V.CastPreset(key), function(preset)
                V.SetCastPreset(key, preset)
                Refresh()
                if preset ~= "off" then I.try(key) end
            end, 3, 150)
            return
        end
        if kind == "light" or kind == "sound" then return I.pick(key, anchor) end
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
        editLabel = "Shape",
        editTip = "In WoW Helper (else Lab)",
        defaultTip = "As it ships",
        level = I.level and I.level(key) or nil,
        pg = pg,
        marks = 3,
    })
    row.kind, row.key = kind, key
    ui.rows[#ui.rows + 1] = row
    return row
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local LEFT_W = 300

-- The header's switch: the kind's own on and off
local ENABLE = {
    feel = { get = function() return V.Settings().enabled and not V.Other() end,
        set = function(on)
            V.Settings().enabled = on
            if on then V.Play("pulse") else V.Stop() end
        end, tip = "Off: nothing vibrates" },
    light = { get = function() return H.DB().light == true end, set = function(on) LT.SetOn(on) end, tip = "Off: the game's own colour" },
    sound = { get = function() return C ~= nil and C.Settings().sounds == true end,
        set = function(on) if C then C.Settings().sounds = on; C.Refresh() end end, tip = "With WoW Helper" },
}

function ui.SetKind(kind)
    if not ENABLE[kind] then return end
    ui.kind = kind
    HUI.HidePopup()
    Refresh()
end

-- Find a moment's row: its kind, its group, the row lit a moment
Jump = function(key, kind)
    kind = kind or "feel"
    ui.SetKind(kind)
    for _, row in ipairs(ui.rows) do
        if row.key == key and KIND_OF[row.kind] == kind then
            for _, g in ipairs(GROUPS) do
                for _, item in ipairs(Items(kind, g.key)) do
                    if item[2] == key then ui.browser.Select(g.key) end
                end
            end
            S.SetSelected(row.pick, true)
            if C_Timer and C_Timer.After then C_Timer.After(1.5, function() S.SetSelected(row.pick, false) end) end
            Say(row.label:GetText() or key)
            return row
        end
    end
end
ui.Jump = function(key, kind) return Jump(key, kind) end

local function Build(frame, header)
    -- Header: the kind, its switch, the last moment
    ui.seg = {}
    for i, k in ipairs(KINDS) do
        ui.seg[k[1]] = S.NewButton(header, k[2], 130 + (i - 1) * 74, -3, 72, function() ui.SetKind(k[1]) end, nil, 12, 28)
    end
    ui.enable = S.NewCheck(header, "On", W - 70, -4, function(self)
        ENABLE[ui.kind].set(self:GetChecked() == true)
        Refresh()
    end, 40)
    ui.why = CreateFrame("Button", nil, header)
    ui.why:SetPoint("TOPLEFT", 370, -6)
    ui.why:SetSize(W - 370 - 90, 22)
    ui.why.text = S.Text(ui.why, "", 0, -4, W - 370 - 90, 11, GREY)
    ui.why.text:SetJustifyH("RIGHT")
    ui.why.text:SetWordWrap(false)
    ui.why:SetScript("OnClick", function()
        local D = ns.HapticsDebug
        if not D then return end
        local _, _, key, kind = D.Latest()
        if key then Jump(key, kind) end
    end)
    local whyTick = CreateFrame("Frame", nil, header)
    local whyAcc = 0
    whyTick:SetScript("OnUpdate", function(_, elapsed)
        whyAcc = whyAcc + (elapsed or 0)
        if whyAcc < 0.25 then return end
        whyAcc = 0
        local D = ns.HapticsDebug
        local text, ago
        if D then text, ago = D.Latest() end
        ui.why.text:SetText(text and string.format("%s · %ds ago ›", text, floor(ago)) or "")
    end)

    -- Left: the kind's master, then the groups
    local left = S.Card(frame, "Feel", 0, 0, LEFT_W, PH)
    ui.left = left
    ui.box = {}
    -- Feel: strength, the motors
    local fb = CreateFrame("Frame", nil, left)
    fb:SetPoint("TOPLEFT", 0, 0)
    fb:SetSize(LEFT_W, 136)
    ui.box.feel = fb
    ui.strength = HUI.Stepper(pg, fb, "Strength", 14, -42, { labelWidth = 110, width = LEFT_W - 28, step = 0.1, min = 0.1, max = 1,
        format = Pct, get = function() return V.Settings().intensity end,
        set = function(v) V.Settings().intensity = v; V.Play("pulse") end })
    pg.Refresh = function() Refresh() end
    ui.pulse = S.NewButton(fb, "Try", 14, -96, 86, function() if On() then V.Play("pulse") end end, nil, 12, 28)
    ui.sides = S.NewButton(fb, "Motors", 107, -96, 86, function() V.TestSides() end, nil, 12, 28)
    S.Tooltip(ui.sides, "Each motor", "Left grip, right grip, triggers")
    -- Light: what the bar shows now
    local lb = CreateFrame("Frame", nil, left)
    lb:SetPoint("TOPLEFT", 0, 0)
    lb:SetSize(LEFT_W, 136)
    ui.box.light = lb
    S.Text(lb, "Now", 14, -46, 100, 13, GOLD)
    local now = lb:CreateTexture(nil, "ARTWORK")
    now:SetPoint("TOPLEFT", 120, -40)
    now:SetSize(LEFT_W - 134, 24)
    local nowTick = CreateFrame("Frame", nil, lb)
    nowTick:SetScript("OnUpdate", function()
        local r, g, b, on = H.LedNow()
        if on then now:SetColorTexture(r, g, b, 1) else now:SetColorTexture(0.08, 0.08, 0.08, 1) end
    end)
    S.Text(lb, "Base colour: Setup", 14, -80, LEFT_W - 28, 11, DIM)
    -- Sound: the link
    local sb = CreateFrame("Frame", nil, left)
    sb:SetPoint("TOPLEFT", 0, 0)
    sb:SetSize(LEFT_W, 136)
    ui.box.sound = sb
    if ns.Volume then
        local Vol = ns.Volume
        HUI.Stepper(pg, sb, "Volume", 14, -42, { labelWidth = 110, width = LEFT_W - 28, step = Vol.STEP, min = 0.1, max = 1,
            format = Vol.Pct, get = Vol.Sounds, set = Vol.SetSounds })
    end
    S.NewButton(sb, "Try", 14, -96, 86, function()
        local Vol = ns.Volume
        local gain = Vol and Vol.Gain(Vol.Sounds()) or 7   -- (Sounds: never under 10%)
        if not (K and K.Enabled()) then return Say("Link is off: Setup", true) end
        K.Play("chime", gain)
    end, nil, 12, 28)
    ui.soundNote = S.Note(sb, 14, -76, LEFT_W - 28, 1, 11, GREY)
    -- Stop, for every kind
    ui.stop = S.NewButton(left, "Stop", 200, -96, 86, function()
        V.StopSimulation(); V.Stop(); if H then H.Stop(); H.LightStop() end
        if LT then LT.ApplyBase() end
        Say("Stopped")
    end, nil, 12, 28)
    S.Heading(left, "Moments", 10, -136, LEFT_W - 20)

    local groups = {}
    for _, g in ipairs(GROUPS) do groups[#groups + 1] = { key = g.key, label = g.key } end
    local list = CreateFrame("Frame", nil, left)
    list:SetPoint("TOPLEFT", 0, -150)
    list:SetSize(LEFT_W, PH - 150)
    local b = HUI.GroupBrowser(frame, groups, { left = list, leftWidth = LEFT_W, top = -8, width = W - LEFT_W - 10,
        pageTop = 0 })
    ui.browser = b
    ui.cards = {}
    local cw = W - LEFT_W - 10
    for _, g in ipairs(GROUPS) do
        local panel = b.panels[g.key]
        ui.cards[g.key] = {}
        for _, k in ipairs(KINDS) do
            local items = Items(k[1], g.key)
            local card = S.Card(panel, g.key, 0, 0, cw, max(90, 44 + #items * HUI.ROW_H))
            if #items == 0 then S.Text(card, "None here", 14, -44, cw - 28, 12, DIM) end
            for i, item in ipairs(items) do
                MakeRow(card, -38 - (i - 1) * HUI.ROW_H, cw, item[1], item[2])
            end
            ui.cards[g.key][k[1]] = card
        end
    end
    ui.other = S.Text(left, "", 14, -(PH - 74), LEFT_W - 28, 11, RED)
    ui.credit = S.Text(left, "Patterns: Improved Forever: Vibration (markg) and Easy Controller (moust4ki), MIT",
        14, -(PH - 46), LEFT_W - 28, 9, DIM)
end

Refresh = function()
    if not ui.enable then return end
    local kind = ui.kind
    local s = V.Settings()
    local other = V.Other()
    for k, btn in pairs(ui.seg) do S.SetSelected(btn, k == kind) end
    for k, box in pairs(ui.box) do box:SetShown(k == kind) end
    if ui.left.title then ui.left.title:SetText(kind == "feel" and "Feel" or kind == "light" and "Light" or "Sound") end
    local enabled = ENABLE[kind].get()
    ui.enable:SetChecked(enabled)
    ui.enable:SetEnabled(not (kind == "feel" and other))
    S.Tooltip(ui.enable, "On", ENABLE[kind].tip)
    ui.soundNote:SetText((K and K.Enabled()) and "On the pad's speaker" or "With WoW Helper: Setup › Link")
    ui.other:SetText(kind == "feel" and other and "Improved Forever: Vibration is on: Companion stays off" or "")
    local toHelper = ui.ToHelper()
    for _, row in ipairs(ui.rows) do
        local I = ITEM[row.kind]
        local name, icon, sub, off, rgb = I.show(row.key)
        row:SetChoice(name, icon, sub, off, rgb, I.isDefault(row.key))
        if row.edit then
            -- the word follows where it goes: Shape in WoW Helper, Edit in Lab
            local word = toHelper and "Shape" or "Edit"
            row.edit.label:SetText(word)
            S.Tooltip(row.edit, word, toHelper and "In WoW Helper" or "In Lab")
        end
        row:SetMarks(Marks(row))
        local rk = KIND_OF[row.kind]
        local live = rk == "feel" and (s.enabled and not other) or rk == "light" and H.DB().light == true or rk == "sound" and SoundOn()
        row:SetAlpha(live and 1 or 0.55)
    end
    for _, g in ipairs(GROUPS) do
        for k, card in pairs(ui.cards[g.key]) do card:SetShown(k == kind) end
        local items = Items(kind, g.key)
        local on = 0
        for _, item in ipairs(items) do
            local _, _, _, off = ITEM[item[1]].show(item[2])
            if not off then on = on + 1 end
        end
        ui.browser.buttons[g.key].count:SetText(#items > 0 and (on .. "/" .. #items) or "")
    end
    for _, fn in ipairs(pg.refresh) do fn() end
    if kind == "feel" then
        Shell.SetStatus(other and "Improved Forever: Vibration rumbles" or (s.enabled and "" or "Rumble off"))
    else
        Shell.SetStatus(enabled and "" or (kind == "light" and "Light bar off" or "Sounds off"))
    end
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

function API.OpenRumble() Shell.Open("moments"); ui.SetKind("feel") end
-- /gpc light: Moments on a kind
function API.OpenMoments(kind)
    Shell.Open("moments")
    if kind then ui.SetKind(kind) end
end
