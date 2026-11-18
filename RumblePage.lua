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
        { "l", "missedYou" }, { "r", "lowHp" }, { "l", "heartbeat" }, { "l", "control" }, { "l", "targetCast" }, { "l", "aggro" } } },
    { key = "Abilities", items = { { "c", "spell" }, { "c", "gather" }, { "c", "craft" }, { "l", "tension" },
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
        -- who plays it: WoW Helper (every light, precisely) or the game (the bar)
        local sub = LT.Def(key).state and "While it lasts" or nil
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
        local name, why = C.TrySound(key)
        if not name then return Say(LabelOf(key) .. ": " .. why, true) end
        Say(LabelOf(key) .. ": " .. name)
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

-- A moment's volume, as it ships (Default sets both its choice and its volume)
local function VolumeDefault(kind, key, check)
    local Vol = ns.Volume
    if not Vol then return true end
    local k = KIND_OF[kind]
    if k == "feel" and ITEM[kind].level then
        if check then return math.abs(Vol.Feel(key) - Vol.FeelDefault(key)) < 1e-6 end
        Vol.SetFeel(key, Vol.FeelDefault(key))
    elseif k == "sound" then
        if check then return Vol.Sound(key) >= 1 end
        Vol.SetSound(key, 1)
    end
    return true
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
            VolumeDefault(kind, key)
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
        if not f then return "None", V.OFF_ICON, true end
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
    if not (key and ITEM[kind]) then return "None", V.OFF_ICON, true, nil, "", true end
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
    if plan.moment == "spell" then
        local entries = { OFF }
        for _, e in ipairs(CastSets()) do if e.key ~= "off" then entries[#entries + 1] = e end end
        local o = O.Get(plan.name)
        HUI.Popup(anchor, plan.name, entries, (o and o.on == false) and "off" or plan.set, function(key)
            if key == "off" then O.SetOn(plan.name, false) else O.SetSet(plan.name, key) end
            Refresh()
        end, 3, 150)
        return
    end
    local o = O.Get(plan.name)
    HUI.PickFeel(anchor, (o and o.on == false) and "off" or plan.feel, function(feel)
        if feel == "off" then O.SetOn(plan.name, false) else O.SetFeel(plan.name, feel) end
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
                    Say(row.plan.name .. ": as it ships")
                    Refresh()
                end,
                defaultTip = "As it ships",
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
                        row.level:SetShown(kind == "feel" and not Linked(plan) or kind == "sound" and key ~= nil and not linked)
                    end
                    row:SetMarks({})
                    row:SetAlpha(live and 1 or 0.55)
                end
            end
        end
        -- (the count on the left, as every group's: on of all, in this kind)
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

local function Build(frame, header)
    -- Header: the kind, its switch, the last moment
    ui.seg = {}
    for i, k in ipairs(KINDS) do
        if i == 1 then S.Segments(header, 149, -2, { 72, 72, 72 }, 28) end
        ui.seg[k[1]] = S.Segment(header, k[2], 150 + (i - 1) * 72, -3, 72, function() ui.SetKind(k[1]) end, 12, 28)
    end
    ui.enable = S.NewCheck(header, "On", W - 70, -4, function(self)
        ENABLE[ui.kind].set(self:GetChecked() == true)
        Refresh()
    end, 40)
    ui.recent = HUI.JustFelt(header, W - 90, function() return ui.kind end, {
        icon = function(key, kind) return kind == "light" and FEEL_OF[key] and IconOf(FEEL_OF[key]) or IconOf(key) end,
        jump = function(key, kind) Jump(key, kind) end,
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
        K.PlaySound("chime", gain)
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
    for _, g in ipairs(GROUPS) do
        groups[#groups + 1] = { key = g.key, label = g.key }
        if g.key == "Abilities" and SpellsOn() then groups[#groups + 1] = { key = "spells", label = "Your spells" } end
    end
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
    if b.panels.spells then BuildSpells(b.panels.spells, cw) end
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
        row:SetChoice(name, icon, sub, off, rgb, I.isDefault(row.key) and VolumeDefault(row.kind, row.key, true))
        if row.edit then
            -- the word follows where it goes: Shape in WoW Helper, Edit in Lab (only with Lab on)
            row.edit:SetShown(toHelper or H.DB().lab == true)
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
        Shell.SetStatus(other and "Improved Forever: Vibration rumbles" or (s.enabled and "" or "Feel off"))
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
