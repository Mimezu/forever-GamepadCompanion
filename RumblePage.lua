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
-- Panels other files add to the group list, after a group: { after = "Attacks",
-- key, label, build = function(panel, width, pg) } (before the page is built)
ui.panels = {}
function ui.AddPanel(def) ui.panels[#ui.panels + 1] = def end
local pg = { refresh = {} }
local Refresh
pg.Refresh = function() Refresh() end

local function Say(text, warn)
    Shell.SetStatus(warn and ("|cffff7a5c" .. text .. "|r") or text, true)
end

local function On()
    if V.Other() then Say("Improved Forever: Vibration is on", true); return false end
    if V.Settings().enabled then return true end
    Say("Feel off", true)
    return false
end

---------------------------------------------------------------------------
-- The groups and what is in each: r Rumble's events, c the cast sets, l the
-- Beta engine's events
---------------------------------------------------------------------------
local GROUPS = {
    { key = "Attacks", items = { { "r", "autoAttack" }, { "l", "hit" }, { "r", "crit" }, { "r", "critRanged" }, { "r", "shot" }, { "r", "instant" },
        { "l", "miss" }, { "l", "targetDodge" }, { "l", "targetParry" }, { "l", "targetBlock" }, { "l", "kill" } } },
    { key = "Defense", items = { { "l", "hitTaken" }, { "r", "critted" }, { "l", "dodge" }, { "l", "parry" }, { "l", "block" },
        { "l", "missedYou" }, { "r", "lowHp" }, { "l", "heartbeat" }, { "l", "control" }, { "l", "targetCast" }, { "l", "aggro" },
        { "l", "death" }, { "l", "alive" } } },
    { key = "Abilities", items = { { "c", "spell" }, { "c", "gather" }, { "c", "craft" }, { "l", "tension" },
        { "l", "gcd" }, { "l", "combo" }, { "l", "comboFull" }, { "l", "full" }, { "l", "oom" } } },
    { key = "Moving", items = { { "r", "jump" }, { "l", "landing" }, { "l", "footsteps" }, { "l", "wading" }, { "l", "riding" }, { "l", "splash" },
        { "l", "underwater" }, { "l", "mount" }, { "l", "dismount" }, { "l", "taxi" } } },
    { key = "Care", items = { { "r", "eat" }, { "r", "drink" }, { "l", "bandage" }, { "l", "potion" }, { "l", "rested" } } },
    { key = "Weather", items = { { "l", "rain" }, { "l", "thunder" }, { "l", "snow" }, { "l", "sand" }, { "l", "embers" } } },
    { key = "Progress", items = { { "r", "levelUp" }, { "l", "loot" }, { "l", "money" }, { "l", "questAccepted" },
        { "l", "questDone" }, { "l", "skillUp" } } },
    { key = "Social", items = { { "l", "whisper" }, { "l", "readyCheck" }, { "l", "invite" }, { "l", "summon" } } },
    -- (the game's own interface: the Halo ring, the error buzz)
    { key = "Interface", items = { { "r", "haloOpen" }, { "r", "wheelTick" }, { "r", "haloUse" }, { "r", "haloClose" }, { "l", "uiError" } } },
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
            set = function(v) set(key, v) end,
            default = function() set(key, kind == "feel" and Vol.FeelDefault(key) or 1) end }
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
            local now = V.Pattern(V.EventPattern(key))
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
    isDefault = function(key) return V.IsEventDefault(key) end,
    default = function(key) V.EventDefault(key) end,
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
            if C and C.TryHD then C.TryHD(key, L.FeelFor(pattern)) end
            Say(e.label)
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
    try = function(key)
        L.Try(key)
        local s = L.EventSettings(key)
        if s.on and C and C.TryHD then C.TryHD(key, s.feel) end
        Say(L.EVENT[key].label)
    end,
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
    critTaken = "Defense", hitTaken = "Defense", avoid = "Defense",
    release = "Abilities", interrupted = "Abilities", instant = "Attacks", death = "Defense", alive = "Defense",
    levelUp = "Progress", questDone = "Progress", loot = "Progress",
    whisper = "Social", readyCheck = "Social", invite = "Social", haloUse = "Interface", halo = "Interface",
}
ui.LIGHT_GROUP = LIGHT_GROUP
-- (the states — Low health, Casting, In combat, Movement… — are the States list: the stack)
-- a feel moment's light (several feels can share one light)
local LIGHT_OF = {
    crit = "crit", critRanged = "crit", critted = "critTaken", hitTaken = "hitTaken", dodge = "avoid", parry = "avoid",
    block = "avoid", kill = "kill", lowHp = "lowHp", spell = "cast", instant = "instant", haloOpen = "halo",
    haloUse = "haloUse", levelUp = "levelUp", questDone = "questDone", loot = "loot", death = "death", alive = "alive",
    whisper = "whisper", readyCheck = "readyCheck", invite = "invite",
}
ui.LIGHT_OF = LIGHT_OF
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
    local e = REVENT[key] or (L.EVENT and L.EVENT[key]) or KIND[key] or (LT and LT.Def(key))
    if e then return e.label end
    local _, name = ns.SubMoment and ns.SubMoment(key)
    return name or key
end
local function IconOf(key)
    local e = REVENT[key] or (L.EVENT and L.EVENT[key]) or KIND[key]
    return e and e.icon or LIGHT_ICON
end

local function Pct(v) return floor((v or 0) * 100 + 0.5) .. "%" end

ITEM.light = {
    label = function(key) return LT.Def(key).label end,
    icon = function(key) return FEEL_OF[key] and IconOf(FEEL_OF[key]) or LIGHT_ICON end,
    tip = function() return "Light, colour, strength" end,
    show = function(key)
        local s = LT.Settings(key)
        if not s.on then return "Off", V.OFF_ICON, nil, true end
        local l = LT.Light(s.light)
        if s.light == 0 then l = { name = "Pass" } end   -- (a state leaving the bar to what is below)
        -- who plays it: WoW Helper (every light, precisely) or the game (the bar)
        -- its dots and mic shown where it has them ("Spark · Mic pulse")
        local words = LT.PatternWords and LT.PatternWords(key)
        local sub = LT.Def(key).state and "While it lasts" or nil
        if words then sub = sub and (sub .. " · " .. words) or words end
        return l and l.name or "?", nil, sub, false, LT.ColorRGB(s.color)
    end,
    pick = function(key, anchor) ns.LightPicker.Open(anchor, key, Refresh) end,
    isDefault = function(key) return LT.IsDefault(key) end,
    default = function(key) LT.Default(key) end,
    try = function(key)
        LT.Try(key)
        Say(LabelOf(key) .. ": " .. (LT.HelperDrives() and "WoW Helper" or "game light"))
    end,
    -- (strength: in the picker, one control)
}

local function SoundOn() return C and K and K.Enabled() and C.Settings().sounds == true end

ITEM.sound = {
    label = LabelOf,
    icon = IconOf,
    tip = function() return "A sound on the pad's speaker" end,
    show = function(key)
        local id = C.MomentSound(key)
        if not id then return "Off", V.OFF_ICON, nil, true end
        return C.SoundName(id), BELL
    end,
    pick = function(key, anchor)
        local entries = { { key = "off", label = "Off", icon = V.OFF_ICON } }
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
        local name, why = C.TrySound(key)
        if not name then return Say(LabelOf(key) .. ": " .. why, true) end
        Say(LabelOf(key) .. ": " .. name)
    end,
    level = Volume("sound"),
}

---------------------------------------------------------------------------
-- The kinds, and each one's moments by group
---------------------------------------------------------------------------
local KINDS = { { "feel", "Feel" }, { "light", "Light" }, { "sound", "Sound" }, { "trigger", "Triggers" } }
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
        for _, m in ipairs(C.MOMENTS) do
            if m[2] == group and not (C.LIGHT_ONLY and C.LIGHT_ONLY[m[1]]) then list[#list + 1] = { "sound", m[1] } end
        end
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
-- A cast's feel (a cast set) in the Feel picker every moment opens: its
-- sets on top as tiles (Off first), any feel below it (a feel's set: it plays
-- while casting, the usual alerts when it ends badly). current: the tile
-- or feel to show selected for a set key
local function SetTile(key)
    local p = V.Preset(key)
    return p and { key = key, label = p.label, icon = p.icon } or nil
end
local function SetCurrent(setKey, specials)
    for _, s in ipairs(specials) do if s.key == setKey then return setKey end end
    local p = V.Preset(setKey)
    if not p or p.key == "off" then return "off" end
    if p.feel or (not p.auto and not p.action and p.cast) then return L.FeelFor(p.cast) end
    return setKey
end
local function PickSet(anchor, title, specials, current, onSet)
    HUI.PickFeel(anchor, current, function(choice)
        for _, s in ipairs(specials) do if s.key == choice then return onSet(choice) end end
        L.RegisterInRumble()
        onSet(V.FeelSet(L.PatternFor(choice)))
    end, specials, title)
end

-- WoW Helper can open a moment: its data read, the HD link on
function ui.ToHelper()
    local data = C and type(C.HelperData) == "function" and C.HelperData()
    return data and K and K.Enabled() and K.V2() and type(C.EditHD) == "function" and true or false
end

-- A moment's volume and its When, as they ship (Default sets its choice, its volume, its When)
local function VolumeDefault(kind, key, check)
    local Vol, Wh = ns.Volume, ns.When
    local k = KIND_OF[kind]
    if k == "feel" and Wh and Wh.Has(key) then
        if check then
            if not Wh.IsDefault(key) then return false end
        else
            Wh.Default(key)
        end
    end
    if not Vol then return true end
    if k == "feel" and ITEM[kind].level then
        if check then return math.abs(Vol.Feel(key) - Vol.FeelDefault(key)) < 1e-6 end
        Vol.SetFeel(key, Vol.FeelDefault(key))
    elseif k == "sound" then
        if check then return Vol.Sound(key) >= 1 end
        Vol.SetSound(key, 1)
    end
    return true
end

-- What Default changes, kept to put back (Undo): the moment's choice and its volume
local function Copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = Copy(v) end
    return o
end
local function Snapshot(kind, key)
    local back
    if kind == "r" then
        local cfg = V.Settings().events[key]
        local on, pattern = cfg.on, cfg.pattern
        back = function() cfg.on, cfg.pattern = on, pattern end
    elseif kind == "c" then
        local preset = V.CastPreset(key)
        back = function() V.SetCastPreset(key, preset) end
    elseif kind == "l" then
        local s = L.EventSettings(key)
        local on, feel = s.on, s.feel
        back = function() s.on, s.feel = on, feel end
    elseif kind == "sound" then
        local id = C.MomentSound(key)
        back = function() C.SetMomentSound(key, id or false) end
    elseif kind == "light" then
        local db = H.DB().lightEvents
        local own = db and Copy(db[key])
        back = function() if db then db[key] = Copy(own) end end
    end
    local Vol, k = ns.Volume, KIND_OF[kind]
    local feelVol = Vol and k == "feel" and Vol.Feel(key)
    local soundVol = Vol and k == "sound" and Vol.Sound(key)
    local when = k == "feel" and ns.When and ns.When.Has(key) and ns.When.Snapshot(key)
    return function()
        if back then back() end
        if when then when() end
        if feelVol then Vol.SetFeel(key, feelVol) end
        if soundVol then Vol.SetSound(key, soundVol) end
    end
end

-- A moment's When: its knob's stepper (with Default), or which knob first when it has two
local function WhenLevel(moment, p)
    local Wh = ns.When
    return { step = p.step, min = p.min, max = p.max, format = p.format,
        get = function() return Wh.Get(moment, p.key) end,
        set = function(v) Wh.Set(moment, p.key, v); Refresh() end,
        default = function() Wh.Set(moment, p.key, nil); Refresh() end }
end
function ui.PickWhen(anchor, moment, label)
    local Wh = ns.When
    local params = Wh and Wh.PARAMS[moment]
    if not params then return end
    if #params == 1 then
        local p = params[1]
        return HUI.LevelPopover(anchor, WhenLevel(moment, p), label .. " · " .. p.label, pg)
    end
    local entries = {}
    for _, p in ipairs(params) do entries[#entries + 1] = { key = p.key, label = p.label .. " " .. p.format(Wh.Get(moment, p.key)) } end
    HUI.Popup(anchor, label .. " · When", entries, nil, function(k)
        HUI.LevelPopover(anchor, WhenLevel(moment, Wh.Param(moment, k)), label .. " · " .. Wh.Param(moment, k).label, pg)
    end, 1, 180)
end

-- A proposal accepted: WoW Helper's pick written as the player's own
local function Accept(kind, key, p)
    local k = KIND_OF[kind]
    if k == "sound" then
        C.SetMomentSound(key, tonumber(p.id) or p.id)
    elseif k == "light" then
        local s = LT.Own(key)
        s.on, s.light = true, p.id
    elseif ITEM[kind].pick and kind ~= "c" then
        if not H.Feel(p.id) then return Say(p.name .. ": not in the game yet · /reload", true) end
        ITEM[kind].pick(key, p.id)
    else
        return Say(p.name .. ": not for this moment", true)
    end
    C.DismissProposal(key, p.id)
    Say(ITEM[kind].label(key) .. ": " .. p.name)
end

-- A moment as Recommended (its choice and its volume)
local function IsRecommended(kind, key)
    return ITEM[kind].isDefault(key) and VolumeDefault(kind, key, true)
end
ui.IsRecommended = IsRecommended

-- A group back to Recommended in one kind: every changed row, and Undo for 5 s
local function ResetGroup(group, kind)
    local undo, n = {}, 0
    for _, item in ipairs(Items(kind, group)) do
        if not IsRecommended(item[1], item[2]) then
            undo[#undo + 1] = Snapshot(item[1], item[2])
            ITEM[item[1]].default(item[2])
            VolumeDefault(item[1], item[2])
            n = n + 1
        end
    end
    Refresh()
    if n == 0 then return end
    Shell.Offer(group .. ": Recommended (" .. n .. ")", "Undo", function()
        for _, back in ipairs(undo) do back() end
        Refresh()
    end)
end
ui.ResetGroup = ResetGroup

local function MakeRow(parent, y, width, kind, key)
    local I = ITEM[kind]
    local label = I.label(key)
    -- Shape: in WoW Helper once it can take it; else Edit: a copy of your own in Lab's editor
    local function Edit()
        if ui.ToHelper() then
            local ok = C.EditHD(key)
            if ok then return Say(label .. ": in WoW Helper") end
        end
        -- (Shape without WoW Helper, Lab off: where to go)
        if not H.DB().lab then
            if Shell.PulseLink then Shell.PulseLink() end
            return Say("Start WoW Helper · Setup", true)
        end
        local feel, name = I.feel(key)
        if not feel then return Say("Pick a feel first", true) end
        local beta = ns.BetaPage
        if not (beta and beta.EditCopy) then return end
        -- (already yours: open it, no second copy)
        if feel.key and H.IsOwn(feel.key) and beta.EditOwn then return beta.EditOwn(feel.key) end
        local own = beta.EditCopy(feel, (name or label) .. " (mine)")
        I.assign(key, own)
        Say(label .. ": your copy, in the editor")
    end
    local row = HUI.MomentRow(parent, y, width, I.icon(key), label, function(anchor)
        if kind == "c" then
            local specials = { OFF, SetTile("auto"), SetTile("alerts") }
            PickSet(anchor, label, specials, SetCurrent(V.CastPreset(key), specials), function(preset)
                V.SetCastPreset(key, preset)
                Refresh()
                if preset ~= "off" then I.try(key) end
            end)
            return
        end
        if kind == "light" or kind == "sound" then return I.pick(key, anchor) end
        HUI.PickFeel(anchor, I.current(key), function(feel)
            I.pick(key, feel)
            Refresh()
        end, I.specials(key), label)
    end, function() I.try(key) end, I.tip(key), {
        default = function()
            local undo = Snapshot(kind, key)
            I.default(key)
            VolumeDefault(kind, key)
            Refresh()
            -- (as it ships, and Undo for 5 s)
            Shell.Offer(label .. ": Recommended", "Undo", function() undo(); Refresh() end)
        end,
        edit = I.feel and Edit or nil,
        editLabel = "Shape",
        editTip = "In WoW Helper (else Lab)",
        defaultTip = "Recommended",
        level = I.level and I.level(key) or nil,
        pg = pg,
        marks = 3,
    })
    row.kind, row.key = kind, key
    -- its When (a threshold it waits for): a chip under its name, a click opens a stepper
    if ns.When and ns.When.Has(key) and (KIND_OF[kind] == "feel" or KIND_OF[kind] == "sound") then
        row.when = S.NewButton(row, "", 44, -21, 150, function(self) ui.PickWhen(self, key, label) end, nil, 10, 17)
        row.when.label:SetTextColor(GREY[1], GREY[2], GREY[3])
        S.Tooltip(row.when, "When", "When it plays · a click to change it")
    end
    ui.rows[#ui.rows + 1] = row
    return row
end

---------------------------------------------------------------------------
-- States (Light): the stack (Stack.lua), FrameGambit's list. Reactions are
-- checked top to bottom: the first match sets each channel (bar, mic, dots)
-- it has; Pass leaves one to the next match; Otherwise at the bottom. A row:
-- On, the condition and its requirements (+), the light (its picker, with
-- Pass), Try, Default, ×; drag or Up / Down to reorder. The teal row is the
-- one driving the light now. Timing: Fade in, Fade out, Wait.
---------------------------------------------------------------------------
local STATE_STEP, STATE_ROWS = 40, 11
local ListArrows
local TEAL = { 0.58, 0.76, 0.77 }
local sts = { offset = 0, pool = {} }

-- Every condition to pick, by family: { key, label } (FrameGambit's palette)
local function ConditionEntries(skip, row)
    local St = ns.Stack
    local list = {}
    for _, cat in ipairs(St.CATEGORIES) do
        for _, c in ipairs(St.Conditions()) do
            if c.category == cat.id and c.key ~= skip then
                local bad = row and St.Conflict(row, c.key)
                if not bad then
                    local have = false
                    for _, r in ipairs(row and row.requirements or {}) do if r == c.key then have = true end end
                    list[#list + 1] = { key = c.key, label = (have and "✓ " or "") .. cat.label .. " · " .. c.label }
                end
            end
        end
    end
    return list
end

-- A percentage's operator, then its threshold: the reaction's own condition (part nil) or one
-- of its requirements (each its own: L10)
local function PickPercent(anchor, row, part)
    local St = ns.Stack
    local cond = part or row.condition
    local cur = part and St.ReqParams(row, part) or { operator = row.operator, threshold = row.threshold }
    local ops = {}
    for _, o in ipairs(St.OPERATORS) do ops[#ops + 1] = { key = o.id, label = o.label } end
    HUI.Popup(anchor, St.Label(cond), ops, cur.operator, function(op)
        local th = {}
        for v = 10, 90, 5 do th[#th + 1] = { key = v, label = v .. "%" } end
        HUI.Popup(anchor, St.Label(cond), th, cur.threshold, function(v)
            if part then St.SetReqParams(row, part, op, v) else row.operator, row.threshold = op, v end
            St.Refresh(true)
            Refresh()
        end, 6, 64)
    end, 3, 120)
end

-- The words clicked: the percentage parts of a reaction (one: straight to it; more: which)
local function PickPercentPart(anchor, row)
    local St = ns.Stack
    local parts = {}
    if St.IsPercentage(row.condition) then parts[#parts + 1] = { key = "", label = St.Label(row.condition) } end
    for _, q in ipairs(row.requirements or {}) do
        if St.IsPercentage(q) then parts[#parts + 1] = { key = q, label = St.Label(q) } end
    end
    if #parts == 1 then return PickPercent(anchor, row, parts[1].key ~= "" and parts[1].key or nil) end
    if #parts > 1 then
        HUI.Popup(anchor, St.Words(row), parts, nil, function(k)
            PickPercent(anchor, row, k ~= "" and k or nil)
        end, 1, 200)
    end
end

-- (▲▼ hit areas: 28 px, the whole half of the row each)
ListArrows = function(r)
    r.up:SetHitRectInsets(0, 0, -2, -1)
    r.down:SetHitRectInsets(0, 0, -1, -2)
end

-- A reactions list's chrome (lights and triggers alike): Otherwise pinned under the rows shown,
-- "1-11 of 14" and a thumb when there are more than fit, `below` (a note) under Otherwise
function ui.PlaceList(card, rows, offset, shown, otherwise, below)
    local n = math.min(shown, #rows - offset)
    otherwise:ClearAllPoints()
    otherwise:SetPoint("TOPLEFT", 10, -38 - n * STATE_STEP)
    if below then
        below:ClearAllPoints()
        below:SetPoint("TOPLEFT", 12, -38 - (n + 1) * STATE_STEP - 8)
    end
    if not card.range then
        card.range = S.Text(card, "", 0, 0, 90, 11, DIM)
        card.range:ClearAllPoints()
        card.range:SetPoint("TOPRIGHT", -232, -14)
        card.range:SetJustifyH("RIGHT")
        card.track = card:CreateTexture(nil, "ARTWORK")
        card.track:SetColorTexture(1, 0.85, 0.55, 0.08)
        card.thumb = card:CreateTexture(nil, "OVERLAY")
        card.thumb:SetColorTexture(1, 0.78, 0.25, 0.6)
    end
    local more = #rows > shown
    card.range:SetText(more and ((offset + 1) .. "–" .. (offset + n) .. " of " .. #rows) or "")
    card.track:SetShown(more)
    card.thumb:SetShown(more)
    if more then
        local h = shown * STATE_STEP
        card.track:ClearAllPoints()
        card.track:SetPoint("TOPRIGHT", -4, -38)
        card.track:SetSize(3, h)
        local th = math.max(18, h * shown / #rows)
        card.thumb:ClearAllPoints()
        card.thumb:SetPoint("TOPRIGHT", -4, -38 - (h - th) * offset / math.max(1, #rows - shown))
        card.thumb:SetSize(3, th)
    end
end

-- one reaction row; o = { kind = fn -> the stack kind, pick = fn(anchor, id), try = fn(id) | nil, default = fn(id) }
local function StateRow(card, cw, i, o)
    local r
    local function key() return r.key end
    r = HUI.MomentRow(card, -38 - (i - 1) * STATE_STEP, cw, nil, "", function(anchor)
        o.pick(anchor, key())
    end, o.try and function() o.try(key()) end or nil, nil, {
        default = function()
            -- (as it ships, and Undo for 5 s: the row as it was, kept)
            local k = key()
            local kind = o.kind and o.kind()
            local live = kind and kind.Row and kind:Row(k)
            local was = Copy(live)
            o.default(k)
            Refresh()
            if live then
                Shell.Offer((r.label:GetText() or "") .. ": Recommended", "Undo", function()
                    for f in pairs(live) do live[f] = nil end
                    for f, v in pairs(Copy(was)) do live[f] = v end
                    Refresh()
                end)
            end
        end,
        clear = function()
            o.kind():Remove(key())
            Say("Removed")
            Refresh()
        end,
        quiet = true,
        defaultTip = "Recommended",
    })
    r.kind = "light"
    r.icon:Hide()
    -- the teal row: the one driving the light now
    r.teal = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.teal:SetAllPoints()
    r.teal:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.16)
    r.teal:Hide()
    -- On / Off
    r.on = S.NewCheck(r, "", 2, -6, function(self)
        o.kind():SetOn(key(), self:GetChecked() == true)
        Refresh()
    end, 0)
    S.Tooltip(r.on, "On")
    -- Up / Down (the pad), drag (the mouse)
    r.up = S.NewButton(r, "▲", 28, -1, 28, function() o.kind():Move(key(), -1); Refresh() end, nil, 10, 18)
    r.down = S.NewButton(r, "▼", 28, -20, 28, function() o.kind():Move(key(), 1); Refresh() end, nil, 10, 18)
    ListArrows(r)
    S.Tooltip(r.up, "Up")
    S.Tooltip(r.down, "Down")
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnDragStart", function(self) self.dragging = true; self:SetAlpha(0.6) end)
    r:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetAlpha(1)
        local _, y = GetCursorPosition()
        local scale = card:GetEffectiveScale() or 1
        local top = card:GetTop() or 0
        local n = math.floor(((top - 38) - y / scale) / STATE_STEP) + 1 + sts.offset
        if o.kind():MoveTo(key(), n) then Refresh() end
    end)
    S.Tooltip(r, "Reorder reaction", "First match wins")
    -- the condition's words; a click: a percentage's operator and threshold
    r.label:ClearAllPoints()
    r.label:SetPoint("TOPLEFT", 58, -4)
    r.sub:ClearAllPoints()
    r.sub:SetPoint("TOPLEFT", 58, -22)
    r.words = CreateFrame("Button", nil, r)
    r.words:SetPoint("TOPLEFT", 56, -2)
    r.words:SetSize(220, 18)
    r.words:SetScript("OnClick", function(self)
        local row = o.kind():Row(key())
        if row then PickPercentPart(self, row) end
    end)
    -- + requirements (all must be true)
    r.req = S.NewButton(r, "+", 280, -8, 34, function(self)
        local row = o.kind():Row(key())
        if not row then return end
        HUI.Popup(self, "Add requirements · All must be true", ConditionEntries(row.condition, row), nil, function(c)
            if not o.kind():RemoveRequirement(row.id, c) then
                local ok, bad = o.kind():AddRequirement(row.id, c)
                if not ok and bad then Say("Can't hold with " .. ns.Stack.Label(bad), true) end
            end
            Refresh()
        end, 3, 200)
    end, nil, 11, 24)
    S.Tooltip(r.req, "Add requirements", "All must be true")
    return r
end

function ui.BuildStates(panel, cw)
    local card = S.Card(panel, "States", 0, 0, cw, PH)
    ui.states, ui.stateRows = card, {}
    S.Text(card, "First match wins", 120, -12, 200, 11, DIM)
    ui.statesAdd = S.NewButton(card, "+ Add reaction", cw - 216, -8, 124, function(self)
        HUI.Popup(self, "Add a reaction", ConditionEntries(), nil, function(c)
            LT.stack:Add(c)
            sts.offset = 0
            Say(ns.Stack.Label(c) .. ": added on top")
            Refresh()
        end, 3, 200)
    end, nil, 11, 24)
    ui.statesDefault = S.NewButton(card, "Default", cw - 84, -8, 72, function()
        LT.stack:Default()
        Say("States: as they ship")
        Refresh()
    end, nil, 11, 24)
    S.Tooltip(ui.statesDefault, "Default", "The Recommended reactions, order and timing")
    local LIGHT = { kind = function() return LT.stack end, pick = function(anchor, id) ns.LightPicker.Open(anchor, id, Refresh) end,
        try = function(id) LT.Try(id) end, default = function(id) LT.Default(id) end }
    for i = 1, STATE_ROWS do sts.pool[i] = StateRow(card, cw, i, LIGHT) end
    if ns.Hush then ui.BuildFeelStates(panel, cw) end
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function(_, d)
        sts.offset = math.max(0, sts.offset - d)
        Refresh()
    end)
    -- Otherwise: the base colour and its light (Setup › Light)
    local o = HUI.MomentRow(card, -38 - STATE_ROWS * STATE_STEP, cw, nil, "Otherwise", function()
        Shell.Open("setup")
    end, function() LT.ApplyBase() end, "Resting light")
    o.icon:Hide()
    o.teal = o:CreateTexture(nil, "BACKGROUND", nil, 2)
    o.teal:SetAllPoints()
    o.teal:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.16)
    ui.otherwise = o
    -- Timing (FrameGambit's: fade in, fade out, wait before fade-out)
    local y = -38 - (STATE_ROWS + 1) * STATE_STEP - 4
    local function T(label, x, field, maxv)
        return HUI.Stepper(pg, card, label, x, y, { labelWidth = 70, width = 200, step = 0.05, min = 0, max = maxv,
            format = function(v) return string.format("%.2fs", v or 0) end,
            get = function() return LT.stack:Timing()[field] end, set = function(v) LT.stack:SetTiming(field, v) end })
    end
    ui.fadeIn = T("Fade in", 12, "fadeIn", 2)
    ui.fadeOut = T("Fade out", 222, "fadeOut", 2)
    T("Wait", 432, "wait", 5)
end

-- Feel (Hush.lua): the same list, each reaction a strength (× every feel), Otherwise full
local fsts = { offset = 0, pool = {} }
local function FK() return ns.Hush.kind end
local function PickStrength(anchor, id)
    local row = FK():Row(id)
    if not row then return end
    local list = {}
    for v = 0, 100, 10 do list[#list + 1] = { key = v / 100, label = v .. "%" } end
    HUI.Popup(anchor, ns.Stack.Words(row), list, row.feel, function(v)
        row.feel = v
        FK():Refresh(true)
        Refresh()
    end, 4, 70)
end

function ui.BuildFeelStates(panel, cw)
    local card = S.Card(panel, "States", 0, 0, cw, PH)
    ui.feelStates = card
    S.Text(card, "First match wins", 120, -12, 320, 11, DIM)
    S.NewButton(card, "+ Add reaction", cw - 216, -8, 124, function(self)
        HUI.Popup(self, "Add a reaction", ConditionEntries(), nil, function(c)
            local row = FK():Add(c)
            row.feel = 0.5
            fsts.offset = 0
            Say(ns.Stack.Label(c) .. ": added on top")
            Refresh()
        end, 3, 200)
    end, nil, 11, 24)
    ui.feelDefault = S.NewButton(card, "Default", cw - 84, -8, 72, function()
        FK():Default()
        Say("States: as they ship")
        Refresh()
    end, nil, 11, 24)
    local FEEL = { kind = FK, pick = PickStrength, default = function(id) FK():Default(id) end }
    for i = 1, STATE_ROWS do fsts.pool[i] = StateRow(card, cw, i, FEEL) end
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function(_, d)
        fsts.offset = math.max(0, fsts.offset - d)
        Refresh()
    end)
    local o = HUI.MomentRow(card, -38 - STATE_ROWS * STATE_STEP, cw, nil, "Otherwise", function() end, nil, "Full")
    o.icon:Hide()
    o.pick:SetEnabled(false)
    o.teal = o:CreateTexture(nil, "BACKGROUND", nil, 2)
    o.teal:SetAllPoints()
    o.teal:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.16)
    ui.feelOtherwise = o
end

function ui.RefreshFeelStates()
    local St, stack = ns.Stack, FK()
    local rows = stack:Rows()
    fsts.offset = math.max(0, math.min(fsts.offset, #rows - STATE_ROWS))
    local driving = stack:Driving()
    for i, r in ipairs(fsts.pool) do
        local row = rows[i + fsts.offset]
        r:SetShown(row ~= nil)
        if row then
            r.key = row.id
            local pct = math.floor((tonumber(row.feel) or 1) * 100 + 0.5) .. "%"
            r:SetChoice(pct, nil, nil, row.on == false, nil, stack:IsDefault(row.id) or stack:Recommended(row.id) == nil)
            r.label:SetText(St.Words(row))
            r.sub:SetText(driving[row.id] and "Now" or (St.Matches(row) and "Matches" or ""))
            r.teal:SetShown(driving[row.id] ~= nil)
            r.on:SetChecked(row.on ~= false)
            r.up:SetEnabled(i + fsts.offset > 1)
            r.down:SetEnabled(i + fsts.offset < #rows)
            r.req.label:SetText(row.requirements and ("+" .. #row.requirements) or "+")
            r.default:SetShown(stack:Recommended(row.id) ~= nil)
        end
    end
    ui.PlaceList(ui.feelStates, rows, fsts.offset, STATE_ROWS, ui.feelOtherwise)
    local full = stack:Now().feel.row == nil
    ui.feelOtherwise:SetChoice("Full", nil, full and "Now" or nil, false, nil, true)
    ui.feelOtherwise.teal:SetShown(full)
    ui.feelDefault:SetEnabled(not stack:IsDefault())
end

function ui.RefreshStates(kind)
    local light = kind == "light"
    local feel = kind == "feel" and ui.feelStates ~= nil
    local btn = ui.browser.buttons.states
    if btn then btn:SetShown(light or feel) end
    if not (light or feel) and ui.browser.current == "states" then ui.browser.Select(GROUPS[1].key) end
    ui.states:SetShown(light)
    if ui.feelStates then ui.feelStates:SetShown(feel) end
    if feel then
        ui.RefreshFeelStates()
        if btn then
            local on = 0
            for _, row in ipairs(FK():Rows()) do if row.on ~= false then on = on + 1 end end
            btn.count:SetText(on .. "/" .. #FK():Rows())
        end
        return
    end
    local St, stack = ns.Stack, LT.stack
    local rows = stack:Rows()
    sts.offset = math.max(0, math.min(sts.offset, #rows - STATE_ROWS))
    local driving = stack:Driving()
    local on = 0
    for _, row in ipairs(rows) do if row.on ~= false then on = on + 1 end end
    for i, r in ipairs(sts.pool) do
        local n = i + sts.offset
        local row = rows[n]
        r:SetShown(row ~= nil)
        if row then
            r.key = row.id
            local name, icon, sub, off, rgb = ITEM.light.show(row.id)
            r:SetChoice(name, icon, nil, row.on == false, rgb, LT.IsDefault(row.id))
            r.label:SetText(St.Words(row))
            local tags = {}
            local chs = driving[row.id]
            if chs then
                for _, ch in ipairs(chs) do tags[#tags + 1] = ch == "bar" and "Bar" or ch == "mic" and "Mic" or "Dots" end
            end
            local tail = #tags > 0 and ("Now: " .. table.concat(tags, ", ")) or (St.Matches(row) and "Matches" or nil)
            r.sub:SetText(sub and tail and (sub .. " · " .. tail) or sub or tail or "")
            r.teal:SetShown(chs ~= nil)
            r.on:SetChecked(row.on ~= false)
            r.up:SetEnabled(n > 1)
            r.down:SetEnabled(n < #rows)
            r.req.label:SetText(row.requirements and ("+" .. #row.requirements) or "+")
            r.default:SetShown(stack:Recommended(row.id) ~= nil)
        end
    end
    local o = ui.otherwise
    ui.PlaceList(ui.states, rows, sts.offset, STATE_ROWS, o)
    -- (the fades are the game's: WoW Helper cross-fades on its own: L7)
    local game = not LT.HelperDrives()
    if ui.fadeIn then ui.fadeIn:SetShown(game); ui.fadeOut:SetShown(game) end
    local b = LT.Base()
    local base = LT.LightByKey(b.light)
    local now = stack:Now()
    local otherwise = now.bar.row == nil and now.mic.row == nil and now.dots.row == nil
    o:SetChoice("Resting light", nil, now.bar.row == nil and "Now: Bar" or nil, b.mode == "off", LT.BaseRGB(), true)
    o.teal:SetShown(otherwise)
    ui.statesDefault:SetEnabled(not stack:IsDefault())
    if btn then btn.count:SetText(on .. "/" .. #rows) end
end

---------------------------------------------------------------------------
-- Triggers: the same list on the triggers' stack (TriggerStack.lua). A row:
-- On, Up/Down and drag, the condition's words (a percentage's operator on a
-- click), + requirements, then each trigger's shape (R2 the hand, L2 the
-- body; Pass leaves it to the next match), Try, Default, x. The teal row
-- holds a trigger now.
---------------------------------------------------------------------------
local tgs = { offset = 0, pool = {} }
local TG_ROWS = 11

local function TK() return ns.TriggerStack and ns.TriggerStack.kind end

-- A trigger's shape: Pass, or a shape (then what it follows, if it can)
local function PickShape(anchor, id, ch)
    local TS = ns.TriggerStack
    local row = TK():Row(id)
    if not row then return end
    local shapes = TS.Shapes()
    local ids = {}
    for sid in pairs(shapes) do ids[#ids + 1] = sid end
    table.sort(ids)
    local entries = { { key = 0, label = "Pass", icon = false } }
    for _, sid in ipairs(ids) do
        local sh = shapes[sid]
        entries[#entries + 1] = { key = sid, label = sh.label .. (sh.own and " · yours" or ""), icon = false }
    end
    local cur = row[ch] and row[ch].shape or 0
    HUI.Popup(anchor, ch == "R2" and "R2 · the hand" or "L2 · the body", entries, cur, function(sid)
        local sh = shapes[sid]
        if sh and sh.gauge then
            local follows = {}
            for _, src in ipairs(TS.SOURCES) do follows[#follows + 1] = { key = src.key, label = src.label, icon = false } end
            HUI.Popup(anchor, "Follows", follows, TS.DefaultFollows(sid), function(src)
                TS.SetChannel(id, ch, sid, src)
                Refresh()
            end, 2, 120)
            return
        end
        TS.SetChannel(id, ch, sid)
        Refresh()
    end, 3, 130)
end

local function PickTriggerPercent(anchor, row)
    local St = ns.Stack
    local ops = {}
    for _, o in ipairs(St.OPERATORS) do ops[#ops + 1] = { key = o.id, label = o.label } end
    HUI.Popup(anchor, St.Label(row.condition), ops, row.operator, function(op)
        row.operator = op
        local th = {}
        for v = 10, 90, 5 do th[#th + 1] = { key = v, label = v .. "%" } end
        HUI.Popup(anchor, St.Label(row.condition), th, row.threshold, function(v)
            row.threshold = v
            TK():Refresh(true)
            Refresh()
        end, 6, 64)
    end, 3, 120)
end

local function TriggerRow(card, cw, i)
    local r
    local function key() return r.key end
    r = HUI.MomentRow(card, -38 - (i - 1) * STATE_STEP, cw, nil, "", function(anchor) PickShape(anchor, key(), "R2") end,
        function()
            if not (K and K.Enabled()) then return Say("Link is off: Setup", true) end
            if ns.TriggerStack.Try(key()) then Say("Squeeze the trigger") end
        end, nil, {
        default = function() TK():Default(key()); Refresh() end,
        clear = function() TK():Remove(key()); Say("Removed"); Refresh() end,
        quiet = true,
        defaultTip = "Recommended",
    })
    r.kind = "trigger"
    r.icon:Hide()
    -- the second plate: L2, left of R2's
    local px = select(4, r.pick:GetPoint(1)) or (cw - 300)
    r.pick2 = S.NewButton(r, "", px - 140, -5, 136, function(self) PickShape(self, key(), "L2") end, nil, 11, 30)
    r.pick2.label:SetJustifyH("LEFT")
    r.label:SetWidth(math.max(80, px - 140 - 120))
    r.sub:SetWidth(math.max(80, px - 140 - 120))
    S.Tooltip(r.pick, "R2", "The hand")
    S.Tooltip(r.pick2, "L2", "The body")
    r.teal = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.teal:SetAllPoints()
    r.teal:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.16)
    r.teal:Hide()
    r.on = S.NewCheck(r, "", 2, -6, function(self) TK():SetOn(key(), self:GetChecked() == true); Refresh() end, 0)
    S.Tooltip(r.on, "On")
    r.up = S.NewButton(r, "▲", 28, -1, 28, function() TK():Move(key(), -1); Refresh() end, nil, 10, 18)
    r.down = S.NewButton(r, "▼", 28, -20, 28, function() TK():Move(key(), 1); Refresh() end, nil, 10, 18)
    ListArrows(r)
    S.Tooltip(r.up, "Up")
    S.Tooltip(r.down, "Down")
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnDragStart", function(self) self:SetAlpha(0.6) end)
    r:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)
        local _, y = GetCursorPosition()
        local scale = card:GetEffectiveScale() or 1
        local top = card:GetTop() or 0
        local n = math.floor(((top - 38) - y / scale) / STATE_STEP) + 1 + tgs.offset
        if TK():MoveTo(key(), n) then Refresh() end
    end)
    S.Tooltip(r, "Reorder reaction", "First match wins")
    r.label:ClearAllPoints()
    r.label:SetPoint("TOPLEFT", 58, -4)
    r.sub:ClearAllPoints()
    r.sub:SetPoint("TOPLEFT", 58, -22)
    r.words = CreateFrame("Button", nil, r)
    r.words:SetPoint("TOPLEFT", 56, -2)
    r.words:SetSize(180, 18)
    r.words:SetScript("OnClick", function(self)
        local row = TK():Row(key())
        if row and ns.Stack.IsPercentage(row.condition) then PickTriggerPercent(self, row) end
    end)
    r.req = S.NewButton(r, "+", px - 140 - 40, -8, 34, function(self)
        local row = TK():Row(key())
        if not row then return end
        HUI.Popup(self, "Add requirements · All must be true", ConditionEntries(row.condition, row), nil, function(c)
            if not TK():RemoveRequirement(row.id, c) then
                local ok, bad = TK():AddRequirement(row.id, c)
                if not ok and bad then Say("Can't hold with " .. ns.Stack.Label(bad), true) end
            end
            Refresh()
        end, 3, 200)
    end, nil, 11, 24)
    S.Tooltip(r.req, "Add requirements", "All must be true")
    return r
end

function ui.BuildTriggerStack(panel, cw)
    local card = S.Card(panel, "Triggers", 0, 0, cw, PH)
    ui.trigStack, ui.trigRows = card, tgs.pool
    S.Text(card, "First match wins", 120, -12, 320, 11, DIM)
    ui.trigAdd = S.NewButton(card, "+ Add reaction", cw - 216, -8, 124, function(self)
        HUI.Popup(self, "Add a reaction", ConditionEntries(), nil, function(c)
            TK():Add(c)
            tgs.offset = 0
            Say(ns.Stack.Label(c) .. ": added on top")
            Refresh()
        end, 3, 200)
    end, nil, 11, 24)
    ui.trigDefault = S.NewButton(card, "Default", cw - 84, -8, 72, function()
        TK():Default()
        Say("Triggers: as they ship")
        Refresh()
    end, nil, 11, 24)
    S.Tooltip(ui.trigDefault, "Default", "The Recommended reactions for your class")
    for i = 1, TG_ROWS do tgs.pool[i] = TriggerRow(card, cw, i) end
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function(_, d)
        tgs.offset = math.max(0, tgs.offset - d)
        Refresh()
    end)
    -- Otherwise: free
    local o = HUI.MomentRow(card, -38 - TG_ROWS * STATE_STEP, cw, nil, "Otherwise", function() end, nil, "Free")
    o.icon:Hide()
    o.pick:SetEnabled(false)
    o.teal = o:CreateTexture(nil, "BACKGROUND", nil, 2)
    o.teal:SetAllPoints()
    o.teal:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.16)
    ui.trigOtherwise = o
    ui.trigShapes = S.Text(card, "Shapes: WoW Helper › Triggers", 12, -38 - (TG_ROWS + 1) * STATE_STEP - 8, cw - 24, 11, DIM)
    -- the teal rows follow the game while the list is open
    local acc = 0
    card:SetScript("OnUpdate", function(_, e)
        acc = acc + (e or 0)
        if acc < 0.25 then return end
        acc = 0
        if ui.kind == "trigger" then ui.RefreshTriggerStack("trigger") end
    end)
end

function ui.RefreshTriggerStack(kind)
    local on = kind == "trigger"
    local b = ui.browser
    local btn = b.buttons.triggers
    if btn then btn:SetShown(on) end
    for _, g in ipairs(GROUPS) do if b.buttons[g.key] then b.buttons[g.key]:SetShown(not on) end end
    if b.buttons.spells then b.buttons.spells:SetShown(not on) end
    if on and b.current ~= "triggers" then b.Select("triggers") end
    if not on and b.current == "triggers" then b.Select(GROUPS[1].key) end
    if not on then return end
    local TS, St, stack = ns.TriggerStack, ns.Stack, TK()
    local rows = stack:Rows()
    tgs.offset = math.max(0, math.min(tgs.offset, #rows - TG_ROWS))
    local driving = stack:Driving()
    local count = 0
    for _, row in ipairs(rows) do if row.on ~= false then count = count + 1 end end
    for i, r in ipairs(tgs.pool) do
        local n = i + tgs.offset
        local row = rows[n]
        r:SetShown(row ~= nil)
        if row then
            r.key = row.id
            local off = row.on == false
            r:SetChoice("R2 · " .. TS.Words(row.R2), nil, nil, off, nil, stack:IsDefault(row.id) or stack:Recommended(row.id) == nil)
            r.pick2.label:SetText("L2 · " .. TS.Words(row.L2))
            r.label:SetText(St.Words(row))
            local chs = driving[row.id]
            local tail = chs and ("Now: " .. table.concat(chs, ", ")) or (St.Matches(row) and "Matches" or "")
            if TS.Trying() == row.id then tail = "Trying" end
            r.sub:SetText(tail)
            r.teal:SetShown(chs ~= nil)
            r.on:SetChecked(not off)
            r.up:SetEnabled(n > 1)
            r.down:SetEnabled(n < #rows)
            r.req.label:SetText(row.requirements and ("+" .. #row.requirements) or "+")
            r.default:SetShown(stack:Recommended(row.id) ~= nil)
        end
    end
    ui.PlaceList(ui.trigStack, rows, tgs.offset, TG_ROWS, ui.trigOtherwise, ui.trigShapes)
    local now = stack:Now()
    local free = {}
    for _, ch in ipairs(TS.CHANNELS) do if not now[ch].row then free[#free + 1] = ch end end
    ui.trigOtherwise:SetChoice("Free", nil, #free > 0 and ("Now: " .. table.concat(free, ", ")) or nil, false, nil, true)
    ui.trigOtherwise.teal:SetShown(#free > 0)
    ui.trigDefault:SetEnabled(not stack:IsDefault())
    if btn then btn.count:SetText(count .. "/" .. #rows) end
    if ui.trigNow then
        local function word(ch)
            local v = now[ch].value
            if type(v) ~= "table" or not v.effect or v.effect == 0 then return "Free" end
            local sh = TS.Shape(v.effect)
            return (sh and sh.label or "?") .. (v.value and (" " .. math.floor(v.value * 100 + 0.5) .. "%") or "") .. (v.count and (" x" .. v.count) or "")
        end
        ui.trigNow:SetText("R2  " .. word("R2") .. "\n" .. "L2  " .. word("L2"))
    end
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
    trigger = { get = function() return ns.TriggerStack ~= nil and ns.TriggerStack.On() end,
        set = function(on) if ns.TriggerStack then ns.TriggerStack.SetOn(on) end end, tip = "With WoW Helper" },
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
    -- (a reaction of the stack: the States list)
    if kind == "light" and LT.stack and LT.stack:Row(key) then
        ui.browser.Select("states")
        Say(ns.Stack.Words(LT.stack:Row(key)))
        return
    end
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

-- The Feel tour: six moments in 25 s, each named in Just felt as it plays
ui.TOUR = { { 0, "footsteps" }, { 5, "autoAttack" }, { 10, "crit" }, { 14, "loot" }, { 18, "levelUp" }, { 22, "whisper" } }
local tourRun = 0
function ui.PlayTour()
    tourRun = tourRun + 1
    local run = tourRun
    local D = ns.HapticsDebug
    for i, step in ipairs(ui.TOUR) do
        local function go()
            if run ~= tourRun then return end
            local key = step[2]
            ui.TryMoment(key)
            -- (named in Just felt, unless its Try already did)
            local last = D and D.Recent and D.Recent("feel")[1]
            if D and D.Note and not (last and last.key == key and (GetTime and GetTime() or 0) - last.at < 0.5) then
                local kind
                for _, g in ipairs(GROUPS) do for _, it in ipairs(g.items) do if it[2] == key then kind = it[1] end end end
                local I = kind and ITEM[kind]
                local label = I and I.label(key) or key
                local feel = I and I.show(key)
                D.Note(label, key, "feel", label, feel)
            end
            Say("Tour " .. i .. "/" .. #ui.TOUR)
        end
        if step[1] == 0 or not (C_Timer and C_Timer.After) then go() else C_Timer.After(step[1], go) end
    end
end
function ui.StopTour() tourRun = tourRun + 1 end

-- Try a feel moment as its row's Try does (Help › Start here › Feel it)
function ui.TryMoment(key)
    for _, g in ipairs(GROUPS) do
        for _, item in ipairs(g.items) do
            if item[2] == key and ITEM[item[1]] and ITEM[item[1]].try then return ITEM[item[1]].try(key) end
        end
    end
end

---------------------------------------------------------------------------
-- Your spells (UX.md §9): the spellbook by tab, a row a spell name, what
-- the rules play for it (V.SpellPlan, Rumble.lua) and its own choice
-- (SpellOverrides.lua). Shown once the rules can answer. Like every group it
-- follows the kind: Feel (the plan), Light and Sound (the spell as a moment
-- of its own, "spell:instant:Frost Nova", under the moment it plays in,
-- with the same rows as any moment's: ITEM.light, ITEM.sound).
---------------------------------------------------------------------------
local SPELL_ROWS = 11
local WHEN = { hit = "At the hit", cast = "At the cast", channel = "While channelling", none = "Nothing" }
local MOMENT_LABEL = { autoAttack = "Auto attack", shot = "Shooting", gather = "Gathering", craft = "Crafting",
    eat = "Eating", drink = "Drinking" }
local sp = { tab = 1, page = 1, rows = {}, lines = {} }
ui.spells = sp

local function SpellsOn() return type(V.SpellPlan) == "function" and ns.SpellOverrides ~= nil end

-- The book, one entry a name (ranks share it), out of combat only
local function ReadBook()
    if InCombatLockdown and InCombatLockdown() and #sp.lines > 0 then return end
    local P = ns.Picker
    local lines = P and P.SpellLines and P.SpellLines() or {}
    sp.lines = {}
    for _, line in ipairs(lines) do
        local seen, list = {}, {}
        for _, e in ipairs(line.list or {}) do
            local name = e.name
            if type(name) == "string" and not seen[name] then
                seen[name] = true
                list[#list + 1] = { id = e.spell, name = name, icon = e.icon }
            end
        end
        if #list > 0 then sp.lines[#sp.lines + 1] = { name = line.name, list = list } end
    end
    -- (your procs: never cast, felt as they land; last, within the six tabs)
    local procs = V.ProcList and V.ProcList() or {}
    if #procs > 0 then
        if #sp.lines >= 6 then sp.lines[6] = nil end
        sp.lines[#sp.lines + 1] = { name = "Procs", list = procs }
    end
    if sp.tab > #sp.lines then sp.tab, sp.page = 1, 1 end
end

local function Shown()
    local line = sp.lines[sp.tab]
    local list = line and line.list or {}
    local pages = math.max(1, math.ceil(#list / SPELL_ROWS))
    if sp.page > pages then sp.page = pages end
    return list, pages
end

-- A spell's plate: what plays (name, icon, off) from its plan
local function PlateOf(plan)
    local O = ns.SpellOverrides
    local o = O.Get(plan.name)
    if o and o.on == false then return "Off", V.OFF_ICON, true end
    if plan.moment == "spell" then
        local p = V.Preset(plan.set)
        return p and p.label or tostring(plan.set), p and p.icon, false
    elseif plan.moment == "instant" or plan.moment == "quiet" then
        local f = plan.feel and H.Feel(plan.feel)
        if not f then return "Off", V.OFF_ICON, true end
        return (f.label or plan.feel) .. (plan.hd and " · HD" or ""), f.icon, false
    end
    return (MOMENT_LABEL[plan.moment] or plan.moment) .. " ›", nil, false
end

local function Linked(plan) return plan.moment ~= "spell" and plan.moment ~= "instant" and plan.moment ~= "quiet" end

-- The moment a spell's row shows in a light or sound view: its own
-- ("spell:instant:Frost Nova"), or a linked spell's moment (Attack: Auto
-- attack's), true; nil where that moment has none
local function SpellKey(plan, kind)
    if Linked(plan) then
        if kind == "light" then return LIGHT_OF[plan.moment], true end
        return C and C.MOMENT_N[plan.moment] and plan.moment or nil, true
    end
    return plan.key, false
end

-- A spell's row in the kind: plate (name, icon, off, rgb), its line, Default
-- greyed, the moment it shows (light, sound)
local function SpellChoice(plan, kind)
    local O = ns.SpellOverrides
    if kind == "feel" then
        local name, icon, off = PlateOf(plan)
        return name, icon, off, nil, WHEN[plan.when] or "", O.IsDefault(plan.name, "feel")
    end
    local when = plan.base == "release" and "When released" or plan.when == "none" and "At the cast" or WHEN[plan.when] or ""
    local key, linked = SpellKey(plan, kind)
    if not (key and ITEM[kind]) then return "Off", V.OFF_ICON, true, nil, "", true end
    local I = ITEM[kind]
    local name, icon, _, off, rgb = I.show(key)
    if linked then return name .. " ›", icon, off, rgb, "With " .. LabelOf(key), true, key, true end
    return name, icon, off, rgb, when, I.isDefault(key) and VolumeDefault(kind, key, true), key
end

local function PickSpell(row, anchor)
    local plan, O = row.plan, ns.SpellOverrides
    if not plan then return end
    if ui.kind ~= "feel" then
        local key, linked = SpellKey(plan, ui.kind)
        if not key then return Say(plan.name .. ": none here", true) end
        if linked then return Jump(key, ui.kind) end
        return ITEM[ui.kind].pick(key, anchor)
    end
    if Linked(plan) then return Jump(plan.moment, "feel") end
    local o = O.Get(plan.name)
    local off = o and o.on == false
    if plan.moment == "spell" then
        -- (its set as it ships on top, beside Off; any feel below)
        local specials = { OFF, SetTile(plan.ruleSet or plan.set) }
        PickSet(anchor, plan.name, specials, off and "off" or SetCurrent(plan.set, specials), function(key)
            if key == "off" then O.SetOn(plan.name, false)
            elseif key == plan.ruleSet then O.SetSet(plan.name, nil)
            else O.SetSet(plan.name, key) end
            Refresh()
        end)
        return
    end
    -- (a spell the rules leave quiet: Off, as the picker says it)
    HUI.PickFeel(anchor, (off or not plan.feel) and "off" or plan.feel, function(feel)
        if feel == "off" then
            if plan.ruleFeel then O.SetOn(plan.name, false) else O.SetFeel(plan.name, nil) end
        elseif feel == plan.ruleFeel then
            O.SetFeel(plan.name, nil)
        else
            O.SetFeel(plan.name, feel)
        end
        Refresh()
    end, { OFF }, plan.name)
end

local function BuildSpells(panel, cw)
    local card = S.Card(panel, "Your spells", 0, 0, cw, PH)
    sp.card = card
    sp.tabs = {}
    for i = 1, 6 do
        local t = S.NewButton(card, "", 130 + (i - 1) * 92, -8, 88, function()
            sp.tab, sp.page = i, 1
            Refresh()
        end, nil, 11, 24)
        t:Hide()
        sp.tabs[i] = t
    end
    sp.prev = S.NewButton(card, "‹", cw - 118, -8, 28, function() sp.page = sp.page - 1; Refresh() end, nil, 13, 24)
    sp.pageText = S.Text(card, "", cw - 88, -14, 50, 11, GREY)
    sp.pageText:SetJustifyH("CENTER")
    sp.next = S.NewButton(card, "›", cw - 38, -8, 28, function() sp.page = sp.page + 1; Refresh() end, nil, 13, 24)
    sp.empty = S.Text(card, "No spells", 14, -50, cw - 28, 12, DIM)
    local O = ns.SpellOverrides
    local Vol = ns.Volume
    for i = 1, SPELL_ROWS do
        local row
        -- (the volume: the feel's, or the sound's; a light has its strength in its picker)
        local function Sound() return ui.kind == "sound" and row.key and not row.linked and Vol end
        row = HUI.MomentRow(card, -40 - (i - 1) * HUI.ROW_H, cw, nil, "", function(anchor) PickSpell(row, anchor) end,
            function()
                if not row.plan then return end
                if ui.kind == "feel" then
                    if type(V.TrySpell) == "function" then V.TrySpell(row.plan.id) end
                elseif row.key then
                    ITEM[ui.kind].try(row.key)
                end
            end,
            nil, {
                default = function()
                    if not row.plan then return end
                    if ui.kind == "feel" then
                        O.ClearKind(row.plan.name, "feel")
                    elseif row.key and not row.linked then
                        ITEM[ui.kind].default(row.key)
                        VolumeDefault(ui.kind, row.key)
                    end
                    Say(row.plan.name .. ": Recommended")
                    Refresh()
                end,
                defaultTip = "Recommended",
                level = { step = 0.1, min = 0, max = 1, format = function(v) return floor(v * 100 + 0.5) .. "%" end,
                    get = function()
                        if Sound() then return Vol.Sound(row.key) end
                        return row.plan and O.Volume(row.plan.name) or 1
                    end,
                    set = function(v)
                        if Sound() then return Vol.SetSound(row.key, v) end
                        if row.plan then O.SetVolume(row.plan.name, v) end
                    end },
                pg = pg,
            })
        row:Hide()
        sp.rows[i] = row
    end
    pg.refresh[#pg.refresh + 1] = function()
        local kind = ui.kind
        if sp.card:IsVisible() or #sp.lines == 0 then
            ReadBook()
            for i, t in ipairs(sp.tabs) do
                local line = sp.lines[i]
                t:SetShown(line ~= nil)
                if line then t.label:SetText(line.name or ("Tab " .. i)); S.SetSelected(t, i == sp.tab) end
            end
            local list, pages = Shown()
            sp.pageText:SetText(sp.page .. "/" .. pages)
            sp.prev:SetEnabled(sp.page > 1)
            sp.next:SetEnabled(sp.page < pages)
            sp.empty:SetShown(#list == 0)
            local live = kind == "feel" and V.Settings().enabled and not V.Other() or kind == "light" and H.DB().light == true
                or kind == "sound" and SoundOn()
            for i, row in ipairs(sp.rows) do
                local e = list[(sp.page - 1) * SPELL_ROWS + i]
                local plan = e and V.SpellPlan(e.id)
                row.plan = plan
                row:SetShown(plan ~= nil)
                if plan then
                    plan.id, plan.name = e.id, plan.name or e.name
                    row.icon:SetTexture(e.icon)
                    row.label:SetText(plan.name)
                    local name, icon, off, rgb, sub, isDefault, key, linked = SpellChoice(plan, kind)
                    row.key, row.linked = key, linked
                    row:SetChoice(name, icon, sub, off, rgb, isDefault)
                    if row.level then
                        row.level:SetShown(not off and (kind == "feel" and not Linked(plan) or kind == "sound" and key ~= nil and not linked))
                    end
                    if row.try then row.try:SetShown(not off) end
                    row:SetMarks({})
                    row:SetAlpha(live and 1 or 0.55)
                end
            end
        end
        -- (the count on the left, as every group's: on of all, in this kind; the whole
        -- spellbook's plans only when the kind changed, the card is open, or now and then)
        local now = GetTime and GetTime() or 0
        if not (sp.card:IsVisible() or sp.countKind ~= kind or not sp.countAt or now - sp.countAt > 10) then return end
        sp.countKind, sp.countAt = kind, now
        local all, on = 0, 0
        for _, line in ipairs(sp.lines) do
            for _, e in ipairs(line.list) do
                local plan = V.SpellPlan(e.id)
                if plan then
                    plan.name = plan.name or e.name
                    all = all + 1
                    local _, _, off = SpellChoice(plan, kind)
                    if not off then on = on + 1 end
                end
            end
        end
        local btn = ui.browser and ui.browser.buttons.spells
        if btn and btn.count then btn.count:SetText(all > 0 and (on .. "/" .. all) or "") end
    end
end

---------------------------------------------------------------------------
-- Search (N2): one field above the group list (Ctrl+F). Every moment in
-- every kind, your spells, the States and Triggers lists; results as rows,
-- each with its group and kind in grey; a click opens it where it lives
---------------------------------------------------------------------------
local SEARCH_ROWS = 13
local KIND_LABEL = { feel = "Feel", light = "Light", sound = "Sound", trigger = "Triggers" }

-- Everything there is to find: { label, where, kind, open = fn }
function ui.SearchIndex()
    local out = {}
    for _, k in ipairs({ "feel", "light", "sound" }) do
        for _, g in ipairs(GROUPS) do
            for _, item in ipairs(Items(k, g.key)) do
                local I, key = ITEM[item[1]], item[2]
                local choice = I.show(key)
                out[#out + 1] = { label = I.label(key), where = g.key .. " · " .. KIND_LABEL[k] .. (choice and (" · " .. choice) or ""),
                    kind = k, open = function() Jump(key, k) end }
            end
        end
    end
    if SpellsOn() then
        ReadBook()
        for i, line in ipairs(sp.lines) do
            for j, e in ipairs(line.list) do
                out[#out + 1] = { label = e.name, where = "Your spells · " .. (line.name or ""), kind = "spell", open = function()
                    sp.tab, sp.page = i, math.ceil(j / SPELL_ROWS)
                    if ui.kind == "trigger" then ui.SetKind("feel") end
                    ui.browser.Select("spells")
                    Refresh()
                end }
            end
        end
    end
    local St = ns.Stack
    local function Stack(stack, kind, group, label)
        if not (St and stack and stack.Rows) then return end
        for _, row in ipairs(stack:Rows()) do
            out[#out + 1] = { label = St.Words(row), where = label, kind = kind, open = function()
                ui.SetKind(kind)
                ui.browser.Select(group)
            end }
        end
    end
    Stack(LT and LT.stack, "light", "states", "States · Light")
    Stack(FK(), "feel", "states", "States · Feel")
    Stack(TK(), "trigger", "triggers", "Triggers")
    return out
end

-- The matches for a query (any word in the name or where it is, each word found)
function ui.Search(query)
    local words = {}
    for w in (query or ""):lower():gmatch("%S+") do words[#words + 1] = w end
    if #words == 0 then return {} end
    local found = {}
    for _, e in ipairs(ui.SearchIndex()) do
        local text = (e.label .. " " .. e.where):lower()
        local all = true
        for _, w in ipairs(words) do if not text:find(w, 1, true) then all = false end end
        -- (the name itself first)
        if all then
            e.rank = e.label:lower():find(words[1], 1, true) and 0 or 1
            found[#found + 1] = e
        end
    end
    table.sort(found, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.label < b.label
    end)
    return found
end

local function BuildSearch(frame, left, cw)
    local box = CreateFrame("EditBox", nil, left, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 10, -128)
    box:SetSize(LEFT_W - 20, 24)
    box:SetAutoFocus(false)
    box:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    box:SetTextColor(1, 1, 1)
    box:SetTextInsets(8, 8, 0, 0)
    S.Edit(box)
    box.hint = S.Text(box, "Search  ·  Ctrl+F", 8, -6, LEFT_W - 40, 11, DIM)
    ui.searchBox = box
    -- the results, where a group's page goes
    local card = S.Card(frame, "Search", LEFT_W + 10, 0, cw, PH)
    if card.SetFrameLevel then card:SetFrameLevel((frame:GetFrameLevel() or 0) + 25) end
    card:EnableMouse(true)
    card:Hide()
    ui.searchCard = card
    card.none = S.Text(card, "Nothing found", 14, -44, cw - 28, 12, DIM)
    card.more = S.Text(card, "", 14, -44 - SEARCH_ROWS * 34, cw - 28, 11, DIM)
    card.rows = {}
    for i = 1, SEARCH_ROWS do
        local b = S.NewButton(card, "", 14, -40 - (i - 1) * 34, cw - 28, nil, nil, 12, 30)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", 10, 0)
        b.label:SetJustifyH("LEFT")
        b.where = S.Text(b, "", 0, 0, cw - 260, 11, GREY)
        b.where:ClearAllPoints()
        b.where:SetPoint("RIGHT", -10, 0)
        b.where:SetJustifyH("RIGHT")
        b.where:SetWordWrap(false)
        card.rows[i] = b
    end
    local results = {}
    local function Open(e)
        if not e then return end
        card:Hide()
        box:ClearFocus()
        e.open()
    end
    function ui.ShowSearch(query)
        results = ui.Search(query)
        local on = (query or ""):match("%S") ~= nil
        card:SetShown(on)
        if not on then return end
        card.title:SetText("Search · " .. #results)
        card.none:SetShown(#results == 0)
        for i, b in ipairs(card.rows) do
            local e = results[i]
            b:SetShown(e ~= nil)
            if e then
                b.label:SetText(e.label)
                b.where:SetText(e.where)
                b:SetScript("OnClick", function() Open(e) end)
            end
        end
        card.more:SetText(#results > SEARCH_ROWS and ((#results - SEARCH_ROWS) .. " more · type more") or "")
    end
    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        box.hint:SetShown(text == "")
        ui.ShowSearch(text)
    end)
    box:SetScript("OnEnterPressed", function() Open(results[1]) end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    -- (a group picked: the results step aside; the text stays to come back to)
    local select = ui.browser.Select
    ui.browser.Select = function(...)
        card:Hide()
        return select(...)
    end
    box:SetScript("OnEditFocusGained", function(self) ui.ShowSearch(self:GetText()) end)
    -- Ctrl+F: to the field (the key still reaches the game: nothing taken)
    function ui.SearchKey(key)
        if key == "F" and IsControlKeyDown and IsControlKeyDown() then box:SetFocus(); return true end
        return false
    end
    -- (only where every key can pass on to the game: never a page that eats the keyboard)
    local fighting = InCombatLockdown and InCombatLockdown()
    if frame.EnableKeyboard and frame.SetPropagateKeyboardInput and not fighting
        and pcall(frame.SetPropagateKeyboardInput, frame, true) then
        frame:EnableKeyboard(true)
        frame:SetScript("OnKeyDown", function(_, key) ui.SearchKey(key) end)
    end
end

local function Build(frame, header)
    -- Header: the kind, its switch, the last moment
    ui.seg = {}
    for i, k in ipairs(KINDS) do
        if i == 1 then S.Segments(header, 149, -2, { 72, 72, 72, 72 }, 28) end
        ui.seg[k[1]] = S.Segment(header, k[2], 150 + (i - 1) * 72, -3, 72, function() ui.SetKind(k[1]) end, 12, 28)
    end
    ui.enable = S.NewCheck(header, "On", W - 70, -4, function(self)
        ENABLE[ui.kind].set(self:GetChecked() == true)
        Refresh()
    end, 40)
    ui.recent = HUI.JustFelt(header, W - 90, function() return ui.kind end, {
        icon = function(key, kind) return kind == "light" and FEEL_OF[key] and IconOf(FEEL_OF[key]) or IconOf(key) end,
        jump = function(key, kind) Jump(key, kind) end,
        -- (Again: the last moment's Try, at its own volume)
        again = function(key, kind)
            for _, row in ipairs(ui.rows) do
                if row.key == key and KIND_OF[row.kind] == kind then return ITEM[row.kind].try(key) end
            end
            if ui.TryMoment then ui.TryMoment(key) end
        end,
    })

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
    ui.pulse = S.NewButton(fb, "Try", 14, -96, 86, function()
        if not On() then return end
        V.Play("pulse")
        if C and C.TryHD then C.TryHD(nil, L.FeelFor("pulse")) end
        Say("Strength " .. floor(V.Settings().intensity * 100 + 0.5) .. "%")
    end, nil, 12, 28)
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
    local nowAcc = 0
    nowTick:SetScript("OnUpdate", function(_, elapsed)
        nowAcc = nowAcc + (elapsed or 0)
        if nowAcc < 0.05 then return end
        nowAcc = 0
        local r, g, b, on = H.LedNow()
        if on then now:SetColorTexture(r, g, b, 1) else now:SetColorTexture(0.08, 0.08, 0.08, 1) end
    end)
    S.Text(lb, "Resting light: Setup", 14, -80, LEFT_W - 28, 11, DIM)
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
        K.PlaySound("chime", gain)
    end, nil, 12, 28)
    ui.soundNote = S.Note(sb, 14, -76, LEFT_W - 28, 1, 11, GREY)
    -- Triggers: what each holds now
    local tb = CreateFrame("Frame", nil, left)
    tb:SetPoint("TOPLEFT", 0, 0)
    tb:SetSize(LEFT_W, 136)
    ui.box.trigger = tb
    S.Text(tb, "Now", 14, -46, 100, 13, GOLD)
    ui.trigNow = S.Note(tb, 70, -46, LEFT_W - 84, 2, 12, GREY)
    -- Stop, for every kind
    ui.stop = S.NewButton(left, "Stop", 200, -96, 86, function()
        V.StopSimulation(); V.Stop(); if H then H.Stop(); H.LightStop() end
        if LT then LT.ApplyBase() end
        Say("Stopped")
    end, nil, 12, 28)

    local groups = {}
    for _, g in ipairs(GROUPS) do
        groups[#groups + 1] = { key = g.key, label = g.key }
        if g.key == "Abilities" and SpellsOn() then groups[#groups + 1] = { key = "spells", label = "Your spells" } end
        -- (panels other files add after a group: ui.AddPanel)
        for _, p in ipairs(ui.panels) do
            if p.after == g.key then groups[#groups + 1] = { key = p.key, label = p.label } end
        end
    end
    if LT and LT.stack then groups[#groups + 1] = { key = "states", label = "States" } end
    if ns.TriggerStack and ns.TriggerStack.kind then groups[#groups + 1] = { key = "triggers", label = "Triggers" } end
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
          if k[1] ~= "trigger" then
            local items = Items(k[1], g.key)
            local card = S.Card(panel, g.key, 0, 0, cw, max(90, 44 + #items * HUI.ROW_H))
            if #items == 0 then S.Text(card, "None here", 14, -44, cw - 28, 12, DIM) end
            for i, item in ipairs(items) do
                MakeRow(card, -38 - (i - 1) * HUI.ROW_H, cw, item[1], item[2])
            end
            -- (in its title band: every changed row back to Recommended, Undo for 5 s)
            if #items > 0 then
                local kind = k[1]
                card.reset = S.NewButton(card, "Reset group", cw - 118, -3, 108, function() ResetGroup(g.key, kind) end, nil, 11, 24)
                S.Tooltip(card.reset, "Reset group", "Every changed moment here back to Recommended")
            end
            ui.cards[g.key][k[1]] = card
          end
        end
    end
    -- sounds while the link is off: one card where the groups go
    ui.soundOff = S.Card(frame, nil, LEFT_W + 10, 0, cw, PH)
    if ui.soundOff.SetFrameLevel then ui.soundOff:SetFrameLevel((frame:GetFrameLevel() or 0) + 30) end
    ui.soundOff:EnableMouse(true)
    local bell = ui.soundOff:CreateTexture(nil, "ARTWORK")
    bell:SetTexture(BELL); bell:SetSize(48, 48); bell:SetPoint("CENTER", 0, 70)
    local t1 = S.Text(ui.soundOff, "Sounds play on the pad's speaker", 0, 0, cw - 40, 15, S.YELLOW)
    t1:ClearAllPoints(); t1:SetPoint("TOP", bell, "BOTTOM", 0, -16); t1:SetJustifyH("CENTER")
    local t2 = S.Text(ui.soundOff, "Needs WoW Helper", 0, 0, cw - 40, 12, S.GREY)
    t2:ClearAllPoints(); t2:SetPoint("TOP", t1, "BOTTOM", 0, -8); t2:SetJustifyH("CENTER")
    ui.soundOff.setup = S.NewButton(ui.soundOff, "Setup", 0, 0, 120, function() Shell.Open("setup") end, nil, 13, 32)
    ui.soundOff.setup:ClearAllPoints(); ui.soundOff.setup:SetPoint("TOP", t2, "BOTTOM", 0, -18)
    ui.soundOff:Hide()
    BuildSearch(frame, left, cw)
    if b.panels.spells then BuildSpells(b.panels.spells, cw) end
    for _, p in ipairs(ui.panels) do
        if b.panels[p.key] then p.build(b.panels[p.key], cw, pg) end
    end
    if b.panels.states then ui.BuildStates(b.panels.states, cw) end
    if b.panels.triggers then
        ui.BuildTriggerStack(b.panels.triggers, cw)
        -- (only with Triggers: first in the list)
        b.buttons.triggers:ClearAllPoints()
        b.buttons.triggers:SetPoint("TOPLEFT", 10, -8)
    end
    ui.other = S.Text(left, "", 14, -(PH - 74), LEFT_W - 28, 11, RED)

end

Refresh = function()
    if not ui.enable then return end
    local kind = ui.kind
    local s = V.Settings()
    local other = V.Other()
    for k, btn in pairs(ui.seg) do S.SetSelected(btn, k == kind) end
    if ui.recent then ui.recent.Update() end
    for k, box in pairs(ui.box) do box:SetShown(k == kind) end
    if ui.left.title then ui.left.title:SetText(kind == "feel" and "Feel" or kind == "light" and "Light" or kind == "trigger" and "Triggers" or "Sound") end
    local enabled = ENABLE[kind].get()
    ui.enable:SetChecked(enabled)
    ui.enable:SetEnabled(not (kind == "feel" and other))
    S.Tooltip(ui.enable, "On", ENABLE[kind].tip)
    ui.soundNote:SetText((K and K.Enabled()) and "On the pad's speaker" or "With WoW Helper: Setup › Link")
    ui.other:SetText(kind == "feel" and other and "Improved Forever: Vibration is on" or "")
    local toHelper = ui.ToHelper()
    if ui.soundOff then
        local blocked = kind == "sound" and not (K and K.Enabled())
        ui.soundOff:SetShown(blocked)
        if ui.browser and ui.browser.panelsFrame then ui.browser.panelsFrame:SetShown(not blocked) end
    end
    for _, row in ipairs(ui.rows) do
        local I = ITEM[row.kind]
        local name, icon, sub, off, rgb = I.show(row.key)
        row:SetChoice(name, icon, sub, off, rgb, I.isDefault(row.key) and VolumeDefault(row.kind, row.key, true))
        -- (nothing plays: no volume, no Try)
        if row.level then row.level:SetShown(not off) end
        if row.try then row.try:SetShown(not off) end
        if row.edit then
            -- Shape, always: in WoW Helper; dim when it can't go there (Edit in Lab when Lab is on)
            local lab = not toHelper and H.DB().lab == true
            local word = lab and "Edit" or "Shape"
            row.edit.label:SetText(word)
            row.edit:SetAlpha((toHelper or lab) and 1 or 0.45)
            S.Tooltip(row.edit, word, toHelper and "In WoW Helper" or lab and "In Lab" or "Needs WoW Helper")
        end
        row:SetMarks(Marks(row))
        if row.when then
            row.when.label:SetText("When: " .. ns.When.Words(row.key))
            local w = (row.sub:GetText() or "") ~= "" and row.sub:GetStringWidth() or nil
            row.when:ClearAllPoints()
            row.when:SetPoint("TOPLEFT", 44 + (type(w) == "number" and (w + 8) or 0), -21)
        end
        local rk = KIND_OF[row.kind]
        local p = C and C.Proposal and C.Proposal(rk, row.key)
        row:SetProposal(p, p and function() Accept(row.kind, row.key, p); Refresh() end,
            p and function() C.DismissProposal(row.key, p.id); Refresh() end)
        local live = rk == "feel" and (s.enabled and not other) or rk == "light" and H.DB().light == true or rk == "sound" and SoundOn()
        row:SetAlpha(live and 1 or 0.55)
    end
    if ui.states then ui.RefreshStates(kind) end
    if ui.trigStack then ui.RefreshTriggerStack(kind) end
    for _, g in ipairs(GROUPS) do
        for k, card in pairs(ui.cards[g.key]) do card:SetShown(k == kind) end
        local items = Items(kind, g.key)
        local on, changed = 0, 0
        for _, item in ipairs(items) do
            local _, _, _, off = ITEM[item[1]].show(item[2])
            if not off then on = on + 1 end
            if not IsRecommended(item[1], item[2]) then changed = changed + 1 end
        end
        local card = ui.cards[g.key][kind]
        if card and card.reset then card.reset:SetEnabled(changed > 0) end
        -- (a gold dot: WoW Helper proposes something in this group)
        local proposed = false
        for _, item in ipairs(items) do
            if C and C.Proposal and C.Proposal(KIND_OF[item[1]], item[2]) then proposed = true end
        end
        local btn = ui.browser.buttons[g.key]
        btn.count:SetText((proposed and "|cffffcc4d•|r " or "") .. (#items > 0 and (on .. "/" .. #items) or ""))
        -- (a ring by the count: something here differs from Recommended)
        if changed > 0 and not btn.ring then
            btn.ring = btn:CreateTexture(nil, "OVERLAY")
            btn.ring:SetTexture("Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_changed_ring")
            btn.ring:SetSize(10, 10)
        end
        if btn.ring then
            btn.ring:SetShown(changed > 0)
            local w = btn.count:GetStringWidth()
            btn.ring:ClearAllPoints()
            btn.ring:SetPoint("RIGHT", btn, "RIGHT", -8 - (type(w) == "number" and w or 30) - 5, 0)
        end
        btn.changed = changed
    end
    for _, fn in ipairs(pg.refresh) do fn() end
    if kind == "feel" then
        Shell.SetStatus(other and "Improved Forever: Vibration rumbles" or (s.enabled and "" or "Feel off"))
    else
        Shell.SetStatus(enabled and "" or (kind == "light" and "Light bar off" or kind == "trigger" and "Triggers off" or "Sounds off"))
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
