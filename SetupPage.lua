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
    -- (the exe to run; the limit: the game windowed)
    S.Text(card, "Run WowHelper.exe", 12, -72, COL - 24, 12, GOLD)
    S.Text(card, "Windowed or borderless", 12, -90, COL - 24, 11, DIM)
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
    -- (Link off: no HD, the game's own rumble; the switch shows Off, dimmed, until Link is on)
    local hdRow = Choice(card, "HD", 12, -112, { { "auto", "On" }, { "off", "Off" } },
        function() return K.Enabled() and HD() or "off" end,
        function(v) if K.Enabled() then SetHD(v) end end)
    S.Text(card, "Bluetooth only", 124, -142, COL - 136, 11, DIM)
    local data = S.Note(card, 12, -166, COL - 24, 1, 11, DIM)
    pg.refresh[#pg.refresh + 1] = function()
        link:SetChecked(K.Enabled())
        hdRow:SetAlpha(K.Enabled() and 1 or 0.45)
        for _, b in ipairs(hdRow.buttons) do if b.EnableMouse then b:EnableMouse(K.Enabled()) end end
        local l = ns.Timing and ns.Timing.Link and ns.Timing.Link()
        via:SetText(l == "usb" and "USB" or l == "bt" and "Bluetooth" or "")
        -- (the footer chip's words: what the addon knows, read at login)
        local words = Shell.LinkWords and Shell.LinkWords() or ""
        data:SetText("WoW Helper · " .. words)
    end
end

---------------------------------------------------------------------------
-- Triggers: on the stack now, Moments › Triggers (one place per setting)
---------------------------------------------------------------------------
local function BuildTriggers(frame)
    local card = S.Card(frame, "Triggers", 0, -210, COL, 110, "Interface\\Icons\\INV_Gauntlets_04")
    S.Text(card, "Moments › Triggers", 12, -44, COL - 24, 12, GREY)
    S.NewButton(card, "Open", 12, -70, 90, function()
        Shell.Open("moments")
        if ns.RumblePage and ns.RumblePage.SetKind then ns.RumblePage.SetKind("trigger") end
    end, nil, 12, 26)
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
    -- (the check climbs no higher than the floor can be set)
    if ns.Staircase then ns.Staircase.TOP = FLOOR_TOP end
    local card = S.Card(frame, "Faintest feel", X2, 0, COL, 200, "Interface\\AddOns\\GamepadCompanion\\art\\rumble\\ic_mod_vibration")
    local St = ns.Staircase
    local check -- { side, s }: a check under way
    local function SetFloor(side, v)
        local db = H.DB()
        db.floor[side] = max(0, min(FLOOR_TOP, floor(v * 100 + 0.5) / 100))
        if db.ceil[side] <= db.floor[side] then db.ceil[side] = 1 end
    end
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
            -- (in combat: nothing nudged, every key passes on)
            if InCombatLockdown() then return end
            if self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, not n) end
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
    -- (keys taken only out of combat; let go whenever asked, in combat too)
    local function Keys(row, on)
        if on and InCombatLockdown() then on = false end
        if row.gpcKeys == on then return end
        pcall(row.EnableKeyboard, row, on)
        if row.EnableGamePadButton then pcall(row.EnableGamePadButton, row, on) end
        row.gpcKeys = on
    end
    pg.rangeKeys = Keys
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
        for side = 1, 2 do Keys(rows[side], false) end
        hovered, check = nil, nil
        HUI.StopTaps()
    end)
    -- (a fight: both rows let go of the keys; after it, the hovered one takes them again)
    for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do pcall(watch.RegisterEvent, watch, e) end
    watch:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            for side = 1, 2 do Keys(rows[side], false) end
        elseif hovered then
            Keys(rows[hovered], true)
        end
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
            -- (what was stored: the floor's own clamp)
            Say((side == 1 and "Left " or "Right ") .. Pct(H.DB().floor[side]))
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
-- Timing: footsteps and mining in step with the game
---------------------------------------------------------------------------
local function BuildTiming(frame)
    local card = S.Card(frame, "Timing", X2, -210, COL, PH - 210, "Interface\\Icons\\INV_Misc_PocketWatch_01")
    -- (WoW Helper learns these by listening and owns them (one place): read
    -- only here; Reset and the one Pad delay are WoW Helper's)
    local rows = {}
    local function Row(y, title, reset, try)
        local r = {}
        S.Text(card, title, 12, y, 90, 12, GOLD)
        r.text = S.Text(card, "", 12, y - 18, COL - 24, 11, GREY)
        if try then
            r.try = S.NewButton(card, "Try", COL - 138, y + 6, 60, try, nil, 11, 24)
            S.Tooltip(r.try, "Try", "The next swings")
        end

        rows[#rows + 1] = r
        return r
    end
    -- (the same words as WoW Helper's Timing card)
    local function word(source, n)
        if source == "learned" then return "Learned |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t" .. (n and (" · " .. n) or "") end
        return "Learning…"
    end
    -- (hits and mining: Moments › Learned, one place, U2-14; Landing: its row's When chip)
    local steps = Row(-40, "Footsteps")
    local wading = Row(-84, "Wading")
    wading.text:SetText("Not yet")
    local status = S.Note(card, 12, -128, COL - 24, 2, 11, GOLD)
    local learned = S.NewButton(card, "Learned ›", 12, -160, 120, function()
        Shell.Open("moments")
        local page = ns.RumblePage
        if page and page.SetKind then page.SetKind("feel") end
        if page and page.browser and page.browser.buttons.learnedWeapons then page.browser.Select("learnedWeapons") end
    end, nil, 11, 24)
    S.Tooltip(learned, "Learned", "Hits and gathering · Moments")
    V.onHitSync = function(text) status:SetText(text); Refresh() end
    pg.refresh[#pg.refresh + 1] = function()
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
    local card = S.Card(frame, "Resting light", X3, 0, cw, 320, "Interface\\Icons\\INV_Misc_Gem_Ruby_01")
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
    -- (its motion between moments; "Shape" is the verb only)
    Choice(card, "Resting", 12, y - 28, LT.RESTING, function() return LT.Base().light end,
        function(v) LT.Base().light = v; LT.ApplyBase() end, math.floor((cw - 24 - 112) / 3))
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
    S.Tooltip(toMoments, "Mic light", "Per moment")
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

---------------------------------------------------------------------------
-- Camera: autorun counts as moving for Turn Player with Camera
---------------------------------------------------------------------------
local function BuildCamera(frame)
    local AT = ns.AutorunTurn
    if not AT then return end
    local card = S.Card(frame, "Camera", 0, -330, COL, 110, "Interface\\Icons\\Ability_Rogue_Sprint")
    local check = S.NewCheck(card, "Autorun turns too", 12, -38, function(self)
        AT.SetEnabled(self:GetChecked() == true)
    end, COL - 60)
    S.Tooltip(check, "Autorun turns too", "When moving: autorun counts")
    pg.autorun = check
    pg.refresh[#pg.refresh + 1] = function() check:SetChecked(AT.Enabled()) end
end

---------------------------------------------------------------------------
-- Bags: the combined bag as a plain grid for the d-pad
---------------------------------------------------------------------------
local function BuildBags(frame)
    local BG = ns.BagGrid
    if not BG then return end
    local card = S.Card(frame, "Bags", 0, -450, COL, 110, "Interface\\Icons\\INV_Misc_Bag_08")
    local check = S.NewCheck(card, "Bag grid", 12, -38, function(self)
        BG.SetEnabled(self:GetChecked() == true)
    end, COL - 60)
    S.Tooltip(check, "Bag grid", "D-pad moves item by item")
    pg.bagGrid = check
    pg.refresh[#pg.refresh + 1] = function() check:SetChecked(BG.Enabled()) end
end

local function Build(frame)
    BuildHelper(frame)
    BuildTriggers(frame)
    BuildCamera(frame)
    BuildBags(frame)
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
