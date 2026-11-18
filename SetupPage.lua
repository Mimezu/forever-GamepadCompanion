-- The Setup tab: the pad itself, set once. WoW Helper (the link, HD), the
-- grips' range (the faintest felt, low battery, the battery), the light bar's
-- light (resting light, colour, brightness, mic), the triggers' cues, and timing (footsteps, mining, landing).
-- What happens on each moment is the Moments tab's; the lab's tuning is Lab's.
local _, ns = ...
local S, Shell, H, L, V, HUI = ns.OptionsSkin, ns.Shell, ns.Haptics, ns.HapticsLab, ns.Rumble, ns.HapticsUI
local W, PH = Shell.W, Shell.H
local GOLD, GREY, DIM, YELLOW = S.GOLD, S.GREY, S.DIM, S.YELLOW
local floor = math.floor
local NL = string.char(10)

local pg = { refresh = {} }
local function Refresh()
    if not pg.built then return end
    for _, fn in ipairs(pg.refresh) do fn() end
end
pg.Refresh = Refresh
local function Stepper(...) return HUI.Stepper(pg, ...) end
local function Choice(...) return HUI.Choice(pg, ...) end
local function Say(text, warn) Shell.SetStatus(warn and ("|cffff7a5c" .. text .. "|r") or text, true) end

local COL = floor((W - 20) / 3)
local X2, X3 = COL + 10, 2 * (COL + 10)
local function Pct(v) return floor((v or 0) * 100 + 0.5) .. "%" end

---------------------------------------------------------------------------
-- WoW Helper: the link and HD
---------------------------------------------------------------------------
local function BuildHelper(frame)
    local K, C = ns.HelperLink, ns.HelperCues
    local card = S.Card(frame, "WoW Helper", 0, 0, COL, 200, "Interface\\Icons\\INV_Misc_Gear_01")
    if not (K and C) then return end
    local link = S.NewCheck(card, "Link", 12, -38, function(self)
        K.SetEnabled(self:GetChecked() == true)
        if Shell.RefreshLink then Shell.RefreshLink() end
        C.Refresh()
        Refresh()
    end, 90)
    S.Tooltip(link, "Link", "A few pixels bottom left")
    -- the pad's link as WoW Helper found it (read-only)
    local via = S.Note(card, COL - 112, -42, 100, 1, 11, GREY)
    via:SetJustifyH("RIGHT")
    pg.via = via
    S.Note(card, 12, -72, COL - 24, 2, 11, GREY):SetText("Run WowHelper.exe" .. NL .. "Windowed or borderless")
    -- HD: the setup flow's mode when there, else the cue switch
    local function HD()
        if type(C.HDMode) == "function" then return C.HDMode() end
        return C.Settings().hdFeels == true and "auto" or "off"
    end
    local function SetHD(v)
        if type(C.SetHDMode) == "function" then return C.SetHDMode(v) end
        C.Settings().hdFeels = v == "auto"
        C.Refresh()
    end
    Choice(card, "Detail", 12, -108, { { "auto", "Auto" }, { "off", "Off" } }, HD, SetHD)
    local data = S.Note(card, 12, -144, COL - 24, 1, 11, DIM)
    pg.refresh[#pg.refresh + 1] = function()
        link:SetChecked(K.Enabled())
        local l = ns.Timing and ns.Timing.Link and ns.Timing.Link()
        via:SetText(l == "usb" and "USB" or l == "bt" and "Bluetooth" or "")
        local d = type(C.Data) == "function" and C.Data() or nil
        if d and d.at then
            local sounds = tonumber(d.sounds) or 0
            data:SetText("Read " .. tostring(d.at))
        else
            data:SetText("Not read yet")
        end
    end
end

---------------------------------------------------------------------------
-- Triggers: the cues WoW Helper plays on L2 / R2
---------------------------------------------------------------------------
-- (the player's own rules, TriggerRules.lua: when → trigger → effect; the
-- first rule that holds wins its trigger, so the list's order is the priority)
local function BuildTriggers(frame)
    local C, T = ns.HelperCues, ns.TriggerRules
    local card = S.Card(frame, "Triggers", 0, -210, COL, PH - 210, "Interface\\Icons\\INV_Gauntlets_04")
    if not (C and T and C.TriggerRules) then return end
    local sel = 1
    local function Rules() return C.TriggerRules() end
    local function Cur()
        local l = Rules()
        sel = math.max(1, math.min(sel, #l))
        return l[sel]
    end
    local function Changed() C.Refresh(); Refresh() end
    local add = S.NewButton(card, "Add", COL - 74, -6, 62, function()
        local l = Rules()
        if #l >= T.MAX then return Say("Six at most", true) end
        l[#l + 1] = T.Clean({ when = "combat", side = "R2", effect = "resist", from = 6, strength = 4 })
        sel = #l
        Changed()
    end, nil, 11, 22)
    S.Tooltip(add, "Add", "A new rule")
    -- the list
    local rows = {}
    for i = 1, T.MAX do
        local y = -34 - (i - 1) * 22
        local check = S.NewCheck(card, "", 10, y + 1, function(self)
            local r = Rules()[i]
            if r then r.on = self:GetChecked() == true; Changed() end
        end, 0)
        check:SetSize(22, 22)
        local b = S.NewButton(card, "", 36, y, COL - 48, function() sel = i; Refresh() end, nil, 11, 21)
        b.label:SetJustifyH("LEFT")
        rows[i] = { check = check, button = b }
    end
    -- the chosen rule
    local y0 = -172
    S.Text(card, "When", 12, y0 - 5, 100, 12, GOLD)
    local when = S.NewButton(card, "", 112, y0, COL - 124, nil, nil, 11, 24)
    when:SetScript("OnClick", function(self)
        local r = Cur()
        if not r then return end
        local entries = {}
        for _, w in ipairs(T.WHEN) do entries[#entries + 1] = { key = w.key, label = w.label, icon = false } end
        HUI.Popup(self, "When", entries, r.when, function(k)
            r.when = k
            if k ~= "cast" then r.grow = false end
            Changed()
        end, 3, 110)
    end)
    Choice(card, "Trigger", 12, y0 - 27, T.SIDES, function() local r = Cur(); return r and r.side end,
        function(v) local r = Cur(); if r then r.side = v; C.Refresh() end end, 56)
    S.Text(card, "Effect", 12, y0 - 59, 100, 12, GOLD)
    local effect = S.NewButton(card, "", 112, y0 - 54, COL - 124, nil, nil, 11, 24)
    effect:SetScript("OnClick", function(self)
        local r = Cur()
        if not r then return end
        local entries = {}
        for _, e in ipairs(T.EFFECTS) do entries[#entries + 1] = { key = e.key, label = e.label, icon = false } end
        HUI.Popup(self, "Effect", entries, r.effect, function(k) r.effect = k; Changed() end, 3, 90)
    end)
    local function Num(key, label, y, fmt, lo, hi)
        return Stepper(card, label, 12, y, { labelWidth = 100, width = 240, step = 1, min = lo, max = hi, format = fmt,
            get = function() local r = Cur(); return r and r[key] or lo end,
            set = function(v) local r = Cur(); if r then r[key] = v; C.Refresh() end end })
    end
    local from = Num("from", "From", y0 - 81, T.Pct, 0, 15)
    local to = Num("to", "To", y0 - 108, T.Pct, 0, 15)
    local strength = Num("strength", "Strength", y0 - 135, T.Pct, 1, 15)
    local speed = Num("speed", "Speed", y0 - 162, T.Hz, 0, 15)
    local grow = S.NewCheck(card, "Grows", 248, y0 - 162, function(self)
        local r = Cur()
        if r then r.grow = self:GetChecked() == true; C.Refresh() end
    end, 60)
    S.Tooltip(grow, "Grows", "With the cast")
    local bw = floor((COL - 24 - 18) / 4)
    local function Btn(i, label, tip, fn)
        local b = S.NewButton(card, label, 12 + (i - 1) * (bw + 6), y0 - 192, bw, fn, nil, 11, 24)
        if tip then S.Tooltip(b, label, tip) end
        return b
    end
    local try = Btn(1, "Try", "Felt for 4 s", function()
        local r = Cur()
        if not r then return end
        if not (ns.HelperLink and ns.HelperLink.Enabled()) then return Say("Link is off", true) end
        C.TryTrigger(r, 4)
        Say("Squeeze " .. (r.side == "both" and "L2 and R2" or r.side))
    end)
    local up = Btn(2, "Up", "First wins", function()
        local l = Rules()
        if sel > 1 then l[sel], l[sel - 1] = l[sel - 1], l[sel]; sel = sel - 1; Changed() end
    end)
    local remove = Btn(3, "Remove", nil, function()
        local l = Rules()
        if l[sel] then table.remove(l, sel); Changed() end
    end)
    Btn(4, "Default", "Cast, auto shot, low health", function()
        C.ResetTriggerRules()
        sel = 1
        Changed()
    end)
    pg.refresh[#pg.refresh + 1] = function()
        local l = Rules()
        for i, row in ipairs(rows) do
            local r = l[i]
            row.check:SetShown(r ~= nil)
            row.button:SetShown(r ~= nil)
            if r then
                row.check:SetChecked(r.on)
                row.button.label:SetText(T.Label(r))
                S.SetSelected(row.button, i == sel)
                row.button:SetAlpha(r.on and 1 or 0.5)
            end
        end
        add:SetEnabled(#l < T.MAX)
        local r = Cur()
        local uses = r and T.EFFECT[r.effect].uses or {}
        when.label:SetText(r and T.WHEN_LABEL[r.when] or "")
        effect.label:SetText(r and T.EFFECT[r.effect].label or "")
        when:SetEnabled(r ~= nil)
        effect:SetEnabled(r ~= nil)
        from:SetShown(r ~= nil and uses.from == true)
        to:SetShown(r ~= nil and uses.to == true)
        strength:SetShown(r ~= nil and uses.strength == true)
        speed:SetShown(r ~= nil and uses.speed == true)
        grow:SetShown(r ~= nil and r.when == "cast" and uses.strength == true)
        grow:SetChecked(r and r.grow or false)
        for _, b in ipairs({ try, up, remove }) do b:SetEnabled(r ~= nil) end
        up:SetEnabled(r ~= nil and sel > 1)
        S.SetSelected(try, r ~= nil and C.TryingTrigger() == r)
    end
end

---------------------------------------------------------------------------
-- Range: the faintest each grip feels, low battery, the battery
---------------------------------------------------------------------------
local function BuildRange(frame)
    local card = S.Card(frame, "Range", X2, 0, COL, 200, "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_mod_vibration")
    local faint = S.Text(card, "", 12, -40, COL - 24, 13, YELLOW)
    local find = {}
    local bw = (COL - 30) / 2
    for side = 1, 2 do
        find[side] = S.NewButton(card, side == 1 and "Find left" or "Find right", 12 + (side - 1) * (bw + 6), -66, bw, function()
            if HUI.Calibrate(side, "floor") then Say("Rising · click Felt it") end
            Refresh()
        end, nil, 12, 28)
        S.Tooltip(find[side], "Faintest", "The lowest level you feel")
    end
    Choice(card, "Low battery", 12, -110, { { true, "Softer" }, { false, "Same" } },
        function() return H.DB().battery end, function(v) H.DB().battery = v end)
    local battery = S.Text(card, "", 12, -150, COL - 24, 12, GREY)
    pg.refresh[#pg.refresh + 1] = function()
        local db = H.DB()
        faint:SetText("Faintest  L " .. Pct(db.floor[1]) .. " · R " .. Pct(db.floor[2]))
        for side = 1, 2 do
            local on = HUI.Calibrating(side, "floor")
            find[side].label:SetText(on and "Felt it" or (side == 1 and "Find left" or "Find right"))
            S.SetSelected(find[side], on)
        end
        local B = ns.Battery
        local _, _, name = nil, nil, nil
        if B then _, _, name = B.Look(B.Level()) end
        battery:SetText("Battery  " .. (name or "—"))
    end
end

---------------------------------------------------------------------------
-- Timing: footsteps and mining in step with the game, the landing's range
---------------------------------------------------------------------------
local function BuildTiming(frame)
    local card = S.Card(frame, "Timing", X2, -210, COL, PH - 210, "Interface\\Icons\\INV_Misc_PocketWatch_01")
    local gaits, buttons, texts = { { "run", "Run" }, { "walk", "Walk" } }, {}, {}
    local bw = (COL - 30) / 2
    S.Text(card, "Footsteps", 12, -40, COL - 24, 12, GOLD)
    for i, g in ipairs(gaits) do
        buttons[g[1]] = S.NewButton(card, "Sync " .. g[2]:lower(), 12 + (i - 1) * (bw + 6), -58, bw, function()
            if L.sync then L.StepSyncCancel() else L.StepSync(g[1]) end
            Refresh()
        end, nil, 12, 28)
        S.Tooltip(buttons[g[1]], "Sync " .. g[2]:lower(), "Squeeze R2 on each footfall")
    end
    texts.steps = S.Note(card, 12, -92, COL - 24, 2, 11, GREY)
    S.Text(card, "Mining", 12, -128, 80, 12, GOLD)
    local mine = S.NewButton(card, "Sync", 12, -146, bw, function()
        if V.strikeSync then V.StrikeSyncCancel() else V.StrikeSync("mining") end
        Refresh()
    end, nil, 12, 28)
    S.Tooltip(mine, "Sync", "Squeeze R2 on each strike")
    texts.mine = S.Text(card, "", 18 + bw, -154, bw, 11, GREY)
    local status = S.Note(card, 12, -180, COL - 24, 1, 11, GOLD)
    L.onSync = function(text) status:SetText(text) end
    V.onStrikeSync = function(text) status:SetText(text); Refresh() end
    V.onHitSync = function(text) status:SetText(text); Refresh() end
    S.Text(card, "Landing", 12, -206, 80, 12, GOLD)
    local function secs(v) return string.format("%.2f s", v) end
    Stepper(card, "Soft at", 12, -226, { labelWidth = 110, width = COL - 24, step = 0.05, min = 0.2, max = 3, format = secs,
        get = function() return H.DB().landMin or L.LAND_MIN end,
        set = function(v) local db = H.DB(); db.landMin = v; if (db.landMax or L.LAND_MAX) <= v then db.landMax = v + 0.05 end end })
    Stepper(card, "Full at", 12, -254, { labelWidth = 110, width = COL - 24, step = 0.05, min = 0.25, max = 4, format = secs,
        get = function() return H.DB().landMax or L.LAND_MAX end,
        set = function(v) local db = H.DB(); db.landMax = v; if (db.landMin or L.LAND_MIN) >= v then db.landMin = v - 0.05 end end })
    -- Hits: each weapon's blow lands after the swing's news (the weapon in hand)
    S.Text(card, "Hits", 12, -288, 80, 12, GOLD)
    local hitKind = S.Text(card, "", 60, -288, COL - 72, 11, GREY)
    local half = floor((bw - 6) / 2)
    local hit = S.NewButton(card, "Sync", 12, -306, half, function()
        if V.hitSync then V.HitSyncCancel() else V.HitSync() end
        Refresh()
    end, nil, 12, 28)
    S.Tooltip(hit, "Sync", "Squeeze R2 on each impact")
    local try = S.NewButton(card, "Try", 18 + half, -306, half, function()
        V.HitTry()
        Refresh()
    end, nil, 12, 28)
    S.Tooltip(try, "Try", "The next swings, felt at this time")
    local function kindNow() return V.hitSync and V.hitSync.kind or V.WeaponKind(16) end
    -- (earlier / later by 20 ms, no squeezing needed)
    Stepper(card, "Delay", 18 + bw, -306, { labelWidth = 44, width = bw, step = 0.02, min = 0, max = 1, format = secs,
        get = function() return (V.HitDelay(kindNow())) end, set = function(v) V.SetHitDelay(kindNow(), v) end })
    pg.refresh[#pg.refresh + 1] = function()
        local parts = {}
        local footsteps = L.EventSettings("footsteps").on
        for _, g in ipairs(gaits) do
            local cal = L.StepCal(g[1])
            parts[#parts + 1] = g[2] .. (cal and " synced" or ": not synced")
            local busy = L.sync and L.sync.band == g[1]
            buttons[g[1]].label:SetText(busy and "Cancel" or ("Sync " .. g[2]:lower()))
            S.SetSelected(buttons[g[1]], busy and true or false)
            buttons[g[1]]:SetEnabled(footsteps or busy and true or false)
        end
        texts.steps:SetText(footsteps and table.concat(parts, " · ") or "Footsteps off: Moments › Moving")
        local period, _, synced, mineSource, mineStrikes = V.StrikeTiming("mining")
        texts.mine:SetText((synced or mineSource == "set") and "Synced" or mineSource == "learned" and "Learned" or "Not synced")
        mine.label:SetText(V.strikeSync and "Cancel" or "Sync")
        S.SetSelected(mine, V.strikeSync and true or false)
        local kind = kindNow()
        local _, _, source, hits = V.HitDelay(kind)
        hitKind:SetText(V.HitKindLabel(kind) .. (source == "learned" and " · learned" or source == "guess" and " · not synced" or ""))
        hit.label:SetText(V.hitSync and "Cancel" or "Sync")
        S.SetSelected(hit, V.hitSync and true or false)
        S.SetSelected(try, V.HitTrying() and true or false)
    end
end

---------------------------------------------------------------------------
-- Base colour: the light bar between moments
---------------------------------------------------------------------------
local function BuildBase(frame)
    local LT = ns.Lights
    local cw = W - X3
    local card = S.Card(frame, "Base colour", X3, 0, cw, 320, "Interface\\Icons\\INV_Misc_Gem_Ruby_01")
    if not LT then return end
    local swatch = card:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPRIGHT", -14, -10)
    swatch:SetSize(60, 20)
    local rim = card:CreateTexture(nil, "BORDER")
    rim:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
    rim:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
    rim:SetColorTexture(0.68, 0.5, 0.26, 0.8)
    local tick = CreateFrame("Frame", nil, card)
    local tickAcc = 0
    tick:SetScript("OnUpdate", function(_, elapsed)
        tickAcc = tickAcc + (elapsed or 0)
        if tickAcc < 0.05 then return end
        tickAcc = 0
        local r, g, b, on = H.LedNow()
        if on then swatch:SetColorTexture(r, g, b, 1) else swatch:SetColorTexture(0.08, 0.08, 0.08, 1) end
    end)
    Choice(card, "", -100, -40, LT.BASE_MODES, function() return LT.Base().mode end, function(v)
        LT.Base().mode = v
        LT.ApplyBase()
    end, 64)
    local swatches, n = {}, 0
    local sw = floor((cw - 24 - 4 * 6) / 5)
    for _, c in ipairs(LT.PALETTE) do
        if c.rgb then
            n = n + 1
            local col, row = (n - 1) % 5, floor((n - 1) / 5)
            local b = CreateFrame("Button", nil, card)
            b:SetSize(sw, 26)
            b:SetPoint("TOPLEFT", 12 + col * (sw + 6), -78 - row * 34)
            b.tex = b:CreateTexture(nil, "ARTWORK")
            b.tex:SetPoint("TOPLEFT", 3, -3)
            b.tex:SetPoint("BOTTOMRIGHT", -3, 3)
            b.tex:SetColorTexture(c.rgb[1], c.rgb[2], c.rgb[3], 1)
            b.sel = b:CreateTexture(nil, "BACKGROUND")
            b.sel:SetAllPoints()
            b.sel:SetColorTexture(1, 0.82, 0, 1)
            b:SetScript("OnClick", function()
                local base = LT.Base()
                base.mode, base.color = "color", c.key
                LT.ApplyBase()
                Refresh()
            end)
            b:SetScript("OnEnter", S.ShowTooltip)
            b:SetScript("OnLeave", S.HideTooltip)
            S.Tooltip(b, c.label)
            b.key = c.key
            swatches[#swatches + 1] = b
        end
    end
    local y = -78 - math.ceil(n / 5) * 34 - 8
    Stepper(card, "Brightness", 12, y, { labelWidth = 110, width = cw - 24, step = 0.125, min = 0.125, max = 1, format = Pct,
        get = function() return LT.Base().level end, set = function(v) LT.Base().level = v; LT.ApplyBase() end })
    Stepper(card, "Resting", 12, y - 28, { labelWidth = 110, width = cw - 24, list = LT.RESTING,
        get = function() return LT.Base().light end, set = function(v) LT.Base().light = v; LT.ApplyBase() end })
    -- the mic light (WoW Helper only: the game can't reach it); moments' lights can pulse it
    S.Heading(card, "Mic light", 10, y - 64, cw - 20)
    local mic = Choice(card, "", -100, y - 84, LT.MIC_MODES, function() return LT.Base().mic end, function(v)
        LT.Base().mic = v
        LT.ApplyMic()
    end, floor((cw - 24 - 8) / 3))
    local micNote = S.Text(card, "", 12, y - 116, cw - 24, 11, GREY)
    -- who draws the lights now
    local who = S.Text(card, "", 12, y - 134, cw - 24, 11, GREY)
    pg.refresh[#pg.refresh + 1] = function()
        local helper = LT.HelperDrives()
        who:SetText("")
        mic:SetAlpha(helper and 1 or 0.45)
        micNote:SetText(helper and "Whispers, invites, low health pulse it" or "Needs WoW Helper")
    end
    pg.refresh[#pg.refresh + 1] = function()
        local base = LT.Base()
        for _, b in ipairs(swatches) do b.sel:SetShown(base.mode == "color" and base.color == b.key) end
    end
end

local function Build(frame)
    BuildHelper(frame)
    BuildTriggers(frame)
    BuildRange(frame)
    BuildTiming(frame)
    BuildBase(frame)
    pg.built = true
end

ns.SetupPage = pg

Shell.AddPage({
    key = "setup", name = "Setup", order = 4, icon = "Interface\\Icons\\INV_Misc_Wrench_01",
    build = Build, refresh = Refresh,
    hide = function()
        if L.Ramping() then L.StopRamp() end
    end,
})
