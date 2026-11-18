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
    local card = S.Card(frame, "WoW Helper", 0, 0, COL, 200)
    if not (K and C) then return end
    local link = S.NewCheck(card, "Link", 12, -38, function(self)
        K.SetEnabled(self:GetChecked() == true)
        C.Refresh()
        Refresh()
    end, 90)
    S.Tooltip(link, "Link", "A few pixels bottom left")
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
    -- (USB: WoW Helper's own short clips for crits, landings, swings)
    local usb = S.NewCheck(card, "USB feels", 12, -140, function(self)
        C.Settings().clips = self:GetChecked() == true
        C.Refresh()
    end, 120)
    S.Tooltip(usb, "USB feels", "USB only")
    local data = S.Note(card, 12, -172, COL - 24, 1, 11, DIM)
    pg.refresh[#pg.refresh + 1] = function()
        link:SetChecked(K.Enabled())
        usb:SetChecked(C.Settings().clips == true)
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
local function BuildTriggers(frame)
    local C = ns.HelperCues
    local card = S.Card(frame, "Triggers", 0, -210, COL, PH - 210)
    if not C then return end
    local checks, n = {}, 0
    for _, g in ipairs(C.GROUPS) do
        if g.key:find("Trigger", 1, true) then
            n = n + 1
            local c = S.NewCheck(card, g.label, 12, -38 - (n - 1) * 30, function(self)
                C.Settings()[g.key] = self:GetChecked() == true
                C.Refresh()
            end, COL - 60)
            if g.tip then S.Tooltip(c, g.label, g.tip) end
            checks[g.key] = c
        end
    end
    S.Note(card, 12, -48 - n * 30, COL - 24, 1, 11, DIM):SetText("With WoW Helper")
    pg.refresh[#pg.refresh + 1] = function()
        local cs = C.Settings()
        for key, c in pairs(checks) do c:SetChecked(cs[key] == true) end
    end
end

---------------------------------------------------------------------------
-- Range: the faintest each grip feels, low battery, the battery
---------------------------------------------------------------------------
local function BuildRange(frame)
    local card = S.Card(frame, "Range", X2, 0, COL, 200)
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
    local card = S.Card(frame, "Timing", X2, -210, COL, PH - 210)
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
    local card = S.Card(frame, "Base colour", X3, 0, cw, 320)
    if not LT then return end
    local swatch = card:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPRIGHT", -14, -10)
    swatch:SetSize(60, 20)
    local rim = card:CreateTexture(nil, "BORDER")
    rim:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
    rim:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
    rim:SetColorTexture(0.68, 0.5, 0.26, 0.8)
    local tick = CreateFrame("Frame", nil, card)
    tick:SetScript("OnUpdate", function()
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
