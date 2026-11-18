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
-- Range: the faintest each grip feels (set by hand while it taps; or Check,
-- yes or no tap by tap: no timing), low battery, the battery
---------------------------------------------------------------------------
-- (the arrows and the d-pad nudge a hovered side)
local NUDGE = { LEFT = -1, DOWN = -1, PADDLEFT = -1, PADDDOWN = -1, RIGHT = 1, UP = 1, PADDRIGHT = 1, PADDUP = 1 }
local FLOOR_TOP = 0.4
local min, max = math.min, math.max

local function BuildRange(frame)
    local card = S.Card(frame, "Range", X2, 0, COL, 200, "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_mod_vibration")
    local St = ns.Staircase
    local check -- { side, s }: a check under way
    local function SetFloor(side, v)
        local db = H.DB()
        db.floor[side] = max(0, min(FLOOR_TOP, floor(v * 100 + 0.5) / 100))
        if db.ceil[side] <= db.floor[side] then db.ceil[side] = 1 end
    end
    S.Text(card, "Faint feels start here", 12, -38, COL - 24, 11, GREY)
    local rows, checks = {}, {}
    local cw = 64
    for side = 1, 2 do
        local y = side == 1 and -56 or -86
        local name = side == 1 and "Left" or "Right"
        local row = Stepper(card, name, 12, y, { labelWidth = 44, width = COL - 24 - cw - 8, step = 0.01, min = 0, max = FLOOR_TOP,
            format = Pct, get = function() return H.DB().floor[side] or 0 end,
            set = function(v) SetFloor(side, v); if not check then HUI.Audition(side) end end })
        rows[side] = row
        pg.range = rows
        local function Press(self, key)
            local n = NUDGE[key]
            if not InCombatLockdown() and self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, not n) end
            if n and not check then
                SetFloor(side, (H.DB().floor[side] or 0) + n * 0.01)
                HUI.Audition(side)
                Refresh()
            end
        end
        row:SetScript("OnKeyDown", Press)
        row:SetScript("OnGamePadButtonDown", Press)
        checks[side] = S.NewButton(card, "Check", COL - 12 - cw, y, cw, function()
            if check and check.side == side then
                check = nil
                HUI.StopTaps()
            else
                local start = min(0.3, max(0.1, (H.DB().floor[side] or 0) + 0.08))
                check = { side = side, s = St.New(start) }
                HUI.Tap(side, check.s:Level(), 0.3)
            end
            Refresh()
        end, nil, 11, 24)
        S.Tooltip(checks[side], "Check", "Yes or no, tap by tap")
    end
    -- hovering a side: taps at its level, and the keys nudge it
    local hovered
    local function Keys(row, on)
        if InCombatLockdown() then return end
        pcall(row.EnableKeyboard, row, on)
        if row.EnableGamePadButton then pcall(row.EnableGamePadButton, row, on) end
    end
    local watch = CreateFrame("Frame", nil, card)
    watch:SetScript("OnUpdate", function()
        local h
        for side = 1, 2 do if rows[side]:IsMouseOver() then h = side end end
        if h ~= hovered then
            if hovered then Keys(rows[hovered], false) end
            if h then Keys(rows[h], true) end
            hovered = h
        end
        if h and not check then HUI.Audition(h, 0.7) end
    end)
    watch:SetScript("OnHide", function()
        if hovered then Keys(rows[hovered], false) end
        hovered, check = nil, nil
        HUI.StopTaps()
    end)

    -- the check: Felt? Yes / No / Again, in place of low battery while it runs
    local ask = CreateFrame("Frame", nil, card)
    ask:SetPoint("TOPLEFT", 12, -120)
    ask:SetSize(COL - 24, 60)
    S.Text(ask, "Felt?", 0, -6, 70, 12, GOLD)
    local function Answer(felt)
        if not check then return end
        check.s:Answer(felt)
        if check.s.done then
            local side, v = check.side, check.s:Result()
            SetFloor(side, v)
            check = nil
            Say((side == 1 and "Left " or "Right ") .. Pct(v))
            HUI.Audition(side, 1.3)
        else
            HUI.Tap(check.side, check.s:Level(), 0.3)
        end
        Refresh()
    end
    local abw = floor((COL - 24 - 70 - 12) / 3)
    S.NewButton(ask, "Yes", 70, 0, abw, function() Answer(true) end, nil, 12, 26)
    S.NewButton(ask, "No", 70 + abw + 6, 0, abw, function() Answer(false) end, nil, 12, 26)
    S.NewButton(ask, "Again", 70 + 2 * (abw + 6), 0, abw, function()
        if check then HUI.Tap(check.side, check.s:Level(), 0.1) end
    end, nil, 12, 26)
    local progress = S.Text(ask, "", 0, -36, COL - 24, 11, GREY)

    local lowBattery = Choice(card, "Low battery", 12, -120, { { true, "Softer" }, { false, "Same" } },
        function() return H.DB().battery end, function(v) H.DB().battery = v end)
    local battery = S.Text(card, "", 12, -158, COL - 24, 12, GREY)
    pg.refresh[#pg.refresh + 1] = function()
        for side = 1, 2 do
            local on = check and check.side == side
            checks[side].label:SetText(on and "Stop" or "Check")
            S.SetSelected(checks[side], on and true or false)
            checks[side]:SetEnabled(not check or on)
            rows[side]:SetEnabled(not check)
        end
        ask:SetShown(check ~= nil)
        lowBattery:SetShown(check == nil)
        battery:SetShown(check == nil)
        if check then progress:SetText((check.side == 1 and "Left" or "Right") .. " · tap " .. (check.s.trials + 1)) end
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
    -- (WoW Helper learns these by listening: a status each, one Reset; any
    -- nudge by hand is WoW Helper's one Pad delay)
    local rows = {}
    local function Row(y, title, reset, try)
        local r = {}
        S.Text(card, title, 12, y, 90, 12, GOLD)
        r.text = S.Text(card, "", 12, y - 18, COL - 24, 11, GREY)
        if try then
            r.try = S.NewButton(card, "Try", COL - 138, y + 6, 60, try, nil, 11, 24)
            S.Tooltip(r.try, "Try", "The next swings")
        end
        if reset then
            r.reset = S.NewButton(card, "Reset", COL - 72, y + 6, 60, function() reset(); Refresh() end, nil, 11, 24)
            S.Tooltip(r.reset, "Reset", "To what WoW Helper learns")
        end
        rows[#rows + 1] = r
        return r
    end
    local function word(source, n)
        if source == "learned" then return "Learned ✓" .. (n and (" · " .. n) or "") end
        if source == "yours" or source == "set" or source == "synced" then return "Yours" end
        return "Learning…"
    end
    local hits = Row(-40, "Hits", function()
        local kind = V.WeaponKind(16)
        ns.Timing.Clear(kind, kind == "ranged" and "ranged" or "main")
        ns.Timing.Clear(kind, "off")
    end, function() V.HitTry(); Refresh() end)
    local mine = Row(-84, "Mining", function()
        V.Settings().strikes.mining = nil
    end)
    local steps = Row(-128, "Footsteps", function()
        local db = H.DB()
        db.stepSync = db.stepSync or {}
        for k in pairs(db.stepSync) do db.stepSync[k] = nil end
    end)
    local wading = Row(-172, "Wading")
    wading.text:SetText("Not yet: not told apart by sound")
    -- Landing: when a fall is a real jump (not learned: yours)
    S.Text(card, "Landing", 12, -216, 80, 12, GOLD)
    local function secs(v) return string.format("%.2f s", v) end
    Stepper(card, "Soft at", 12, -236, { labelWidth = 110, width = COL - 24, step = 0.05, min = 0.2, max = 3, format = secs,
        get = function() return H.DB().landMin or L.LAND_MIN end,
        set = function(v) local db = H.DB(); db.landMin = v; if (db.landMax or L.LAND_MAX) <= v then db.landMax = v + 0.05 end end })
    Stepper(card, "Full at", 12, -264, { labelWidth = 110, width = COL - 24, step = 0.05, min = 0.25, max = 4, format = secs,
        get = function() return H.DB().landMax or L.LAND_MAX end,
        set = function(v) local db = H.DB(); db.landMax = v; if (db.landMin or L.LAND_MIN) >= v then db.landMin = v - 0.05 end end })
    local status = S.Note(card, 12, -302, COL - 24, 2, 11, GOLD)
    V.onHitSync = function(text) status:SetText(text); Refresh() end
    pg.refresh[#pg.refresh + 1] = function()
        local kind = V.WeaponKind(16)
        local d, _, source, n = V.HitDelay(kind)
        hits.text:SetText(V.HitKindLabel(kind) .. " · " .. word(source, source == "learned" and n or nil)
            .. string.format(" · %.2f s", d))
        S.SetSelected(hits.try, V.HitTrying() and true or false)
        local _, first, _, mineSource, mineStrikes = V.StrikeTiming("mining")
        mine.text:SetText(word(mineSource, mineSource == "learned" and mineStrikes or nil)
            .. string.format(" · %.2f s, then the crack", first))
        local parts = {}
        for _, g in ipairs({ { "run", "Run" }, { "walk", "Walk" } }) do
            local source, sn = L.StepSource(g[1])
            parts[#parts + 1] = g[2] .. " " .. word(source, sn)
        end
        local footsteps = L.EventSettings("footsteps").on
        steps.text:SetText(table.concat(parts, " · ") .. (footsteps and "" or " · off in Moments"))
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
    -- the moments whose light uses it, and the way to them (each moment's Mic is in its light)
    local micNote = S.Text(card, "", 12, y - 118, cw - 130, 11, GREY)
    micNote:SetWordWrap(false)
    local toMoments = S.NewButton(card, "Moments", cw - 108, y - 112, 96, function()
        if GamepadCompanionAPI and GamepadCompanionAPI.OpenMoments then GamepadCompanionAPI.OpenMoments("light") end
    end, nil, 11, 24)
    S.Tooltip(toMoments, "Mic light", "Set it per moment: a light's Mic")
    -- who draws the lights now
    local who = S.Text(card, "", 12, y - 134, cw - 24, 11, GREY)
    pg.refresh[#pg.refresh + 1] = function()
        local helper = LT.HelperDrives()
        who:SetText("")
        mic:SetAlpha(helper and 1 or 0.45)
        local used = LT.MicMoments and LT.MicMoments() or {}
        micNote:SetText(not helper and "Needs WoW Helper" or #used > 0 and ("Used by " .. table.concat(used, ", ")) or "No moment uses it")
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
