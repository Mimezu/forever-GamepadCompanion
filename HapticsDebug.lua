-- Haptics debug: why the pad vibrates and the light bar glows. A small,
-- see-through window that can stay up while playing: both motors and the
-- light bar now, each vibration and light playing with its reason, and the
-- last things that set them off. Opened from the Beta tab, the Rumble tab or
-- /gpc debug. Also the latest reason for the tabs' headers (D.Latest).
local _, ns = ...
local H, L, LT = ns.Haptics, ns.HapticsLab, ns.Lights
local D = {}
ns.HapticsDebug = D

local floor, max = math.floor, math.max
local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- The log: what set something off, newest first
---------------------------------------------------------------------------
D.log = {}
function D.Note(text)
    table.insert(D.log, 1, { at = Now(), text = text })
    while #D.log > 30 do table.remove(D.log) end
    if D.onNote then D.onNote(text) end
end

function D.Latest()
    local e = D.log[1]
    if not e then return nil end
    return e.text, Now() - e.at
end

-- The Rumble tab's group of an event (Attacks, Moving...), from its page
local groupOf
local function Group(key)
    if not groupOf then
        local page = ns.RumblePage
        if not (page and page.GROUPS) then return nil end
        groupOf = {}
        for _, g in ipairs(page.GROUPS) do
            for _, item in ipairs(g.items) do groupOf[item[2]] = g.key end
        end
        groupOf.cast = "Abilities"
        for _, k in ipairs({ "interrupted", "cancelled", "pushback" }) do groupOf[k] = "Abilities" end
    end
    return groupOf[key]
end

-- "Moving · Jump: Micro tick"
local function Named(key, label, feel)
    local g = Group(key)
    return (g and (g .. " · ") or "") .. label .. (feel and (": " .. feel) or "")
end
D.Named = Named

local function FeelLabel(key)
    local f = key and H.Feel(key)
    return f and (f.label or f.key) or tostring(key)
end

local function RumbleEvent(key)
    local V = ns.Rumble
    for _, e in ipairs(V and V.EVENTS or {}) do if e.key == key then return e end end
end

-- What a Rumble pattern key is called
local function PatternLabel(key)
    local V = ns.Rumble
    local p = V and key and V.Pattern(key)
    return p and p.label or tostring(key)
end

---------------------------------------------------------------------------
-- Why a voice plays, from its id
---------------------------------------------------------------------------
local LIVE_WHY = {
    footsteps = "moving", wading = "in shallow water", riding = "riding", heartbeat = "under half health", underwater = "breath running",
    bandage = "bandaging", tension = "casting",
}

function D.VoiceWhy(id)
    local V = ns.Rumble
    local key = id:match("^ev_(.+)")
    if key then
        local e = L.EVENT[key]
        if not e then return key end
        return Named(key, e.label, FeelLabel(L.EventSettings(key).feel))
    end
    key = id:match("^live_(.+)")
    if key then
        local e = L.EVENT[key]
        local why = LIVE_WHY[key]
        if not why and e and e.group == "Weather" then
            local w = L.weatherNow
            if w and w.name and key ~= "embers" then
                why = "the game: " .. w.name .. (w.intensity and string.format(" %.2f", w.intensity) or "")
            else
                why = ((GetRealZoneText and GetRealZoneText()) or "?") .. ", by zone"
            end
        end
        return Named(key, (e and e.label or key) .. (why and (" (" .. why .. ")") or ""))
    end
    if id == "rumble" or id == "rumbleFeel" then
        local loop = V and V.looping
        if loop then
            local e = RumbleEvent(loop.key)
            local label = e and e.label or (loop.key == "cast" and "Casting") or loop.key
            return Named(loop.key, label .. " (while it lasts)", PatternLabel(loop.pattern))
        end
        return D.lastRumble or "A pattern"
    end
    if id == "beta" or id == "editor" or id:match("^mix") then return "Trying a feel" end
    if id == "record" then return "Recording L2 / R2" end
    return id
end

function D.LightWhy(id)
    if id == "lt_base" then return "Light · base colour" end
    local key = id:match("^lt_(.+)")
    if key and LT and LT.EVENT[key] then
        local s = LT.Settings(key)
        local ef = LT.Effect(s.effect)
        return "Light · " .. LT.EVENT[key].label .. ": " .. (ef and ef.label or s.effect)
    end
    if id == "test" then return "Light · trying" end
    return "Light · " .. id
end

---------------------------------------------------------------------------
-- Cues, logged: Rumble's events, the Beta events, the lights
---------------------------------------------------------------------------
local function Wrap()
    local V = ns.Rumble
    if V and not V.debugWrapped then
        V.debugWrapped = true
        local fire, endLoop = V.Fire, V.EndLoop
        V.Fire = function(key, ...)
            fire(key, ...)
            local ok, active = pcall(V.Active)
            local pattern = ok and active and V.EventPattern(key)
            if pattern then
                local e = RumbleEvent(key)
                local label = e and e.label or (key == "cast" and "Casting") or key
                D.lastRumble = Named(key, label, PatternLabel(pattern))
                D.Note(D.lastRumble)
            end
        end
        V.EndLoop = function(key, ...)
            endLoop(key, ...)
        end
    end
    if L and not L.debugWrapped then
        L.debugWrapped = true
        local fire = L.Fire
        L.Fire = function(key, ...)
            fire(key, ...)
            local e = L.EVENT[key]
            if e and H.Engine() and L.EventSettings(key).on then
                D.Note(Named(key, e.label, FeelLabel(L.EventSettings(key).feel)))
            end
        end
    end
    if LT and not LT.debugWrapped then
        LT.debugWrapped = true
        local fire, start = LT.Fire, LT.StartState
        LT.Fire = function(key, ...)
            fire(key, ...)
            if LT.On() and LT.EVENT[key] and LT.Settings(key).on then D.Note("Light · " .. LT.EVENT[key].label) end
        end
        LT.StartState = function(key, ...)
            start(key, ...)
            if LT.On() and LT.EVENT[key] and LT.Settings(key).on then D.Note("Light · " .. LT.EVENT[key].label .. " (while it lasts)") end
        end
    end
end
Wrap()

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name ~= "GamepadCompanion" then return end
    Wrap()
    if H.DB().debug then D.Show(true) end
end)

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local win
local FONT = "Fonts\\FRIZQT__.TTF"
local LINES_NOW, LINES_LOG = 7, 8

local function Line(parent, y, size, r, g, b)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f:SetFont(FONT, size or 10, "")
    f:SetPoint("TOPLEFT", 10, y)
    f:SetWidth(320)
    f:SetJustifyH("LEFT")
    f:SetWordWrap(false)
    f:SetTextColor(r or 1, g or 1, b or 1)
    return f
end

local function Build()
    win = CreateFrame("Frame", "GamepadCompanionHapticsDebug", UIParent)
    win:SetSize(340, 142 + (LINES_NOW + LINES_LOG) * 14)
    win:SetFrameStrata("MEDIUM")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        H.DB().debugPos = { point, rel, x, y }
    end)
    local pos = H.DB().debugPos
    if type(pos) == "table" and pos[1] then win:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else win:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -180) end
    local bg = win:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.45)
    local title = Line(win, -8, 11, 1, 0.82, 0)
    title:SetText("Haptics now")
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButtonNoScripts")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() D.Show(false) end)
    -- motors and light
    local function Bar(y, r, g, b, name)
        local label = Line(win, y, 10, 0.8, 0.8, 0.8)
        label:SetText(name)
        local bar = win:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", 50, y - 2)
        bar:SetSize(1, 8)
        bar:SetColorTexture(r, g, b, 0.95)
        local pct = Line(win, y, 10, 0.8, 0.8, 0.8)
        pct:ClearAllPoints()
        pct:SetPoint("TOPLEFT", 180, y)
        pct:SetWidth(50)
        return bar, pct
    end
    win.left, win.leftPct = Bar(-28, 1, 0.62, 0.2, "Left")
    win.right, win.rightPct = Bar(-42, 0.35, 0.7, 1, "Right")
    win.swatch = win:CreateTexture(nil, "ARTWORK")
    win.swatch:SetPoint("TOPRIGHT", -14, -28)
    win.swatch:SetSize(60, 22)
    win.lightLabel = Line(win, -54, 9, 0.6, 0.6, 0.6)
    win.lightLabel:ClearAllPoints()
    win.lightLabel:SetPoint("TOPRIGHT", -14, -54)
    win.lightLabel:SetJustifyH("RIGHT")
    win.lightLabel:SetWidth(120)
    win.state = Line(win, -66, 10, 0.75, 0.75, 0.75)
    win.water = Line(win, -80, 10, 0.6, 0.8, 1)
    local nowTitle = Line(win, -98, 10, 1, 0.82, 0)
    nowTitle:SetText("Playing")
    win.now = {}
    for i = 1, LINES_NOW do win.now[i] = Line(win, -98 - i * 14, 10, 0.95, 0.9, 0.8) end
    local logY = -98 - (LINES_NOW + 1) * 14 - 4
    local logTitle = Line(win, logY, 10, 1, 0.82, 0)
    logTitle:SetText("Last cues")
    win.logs = {}
    for i = 1, LINES_LOG do win.logs[i] = Line(win, logY - i * 14, 10, 0.75, 0.75, 0.75) end
    local acc = 0
    win:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 0.1 then return end
        acc = 0
        D.Update()
    end)
    win:Hide()
end

function D.Update()
    if not (win and win:IsShown()) then return end
    local o = H.out
    local driving = H.driver:IsShown()
    local l, r = driving and o.l or 0, driving and o.r or 0
    win.left:SetWidth(max(1, l * 120))
    win.right:SetWidth(max(1, r * 120))
    win.leftPct:SetText(floor(l * 100 + 0.5) .. "%")
    win.rightPct:SetText(floor(r * 100 + 0.5) .. "%")
    local lr, lg, lb, set = H.LedNow()
    if set then win.swatch:SetColorTexture(lr, lg, lb, 1) else win.swatch:SetColorTexture(0.1, 0.1, 0.1, 0.8) end
    win.lightLabel:SetText(set and "Light bar" or "Light: game's")
    local V = ns.Rumble
    local db = H.DB()
    local okA, active = pcall(function() return V.Active() end)
    win.state:SetText(string.format("Rumble %s · Light %s · %d sends/s",
        (okA and active) and "on" or "off", db.light and "on" or "off", H.SendRate()))
    win.water:SetText(D.WaterText())
    -- playing now: vibrations, then lights
    local rows = {}
    for _, v in ipairs(H.ActiveVoices()) do
        local lvl = max(v.l, v.r)
        rows[#rows + 1] = { text = D.VoiceWhy(v.id), level = lvl, kind = "v" }
    end
    for _, lv in ipairs(H.ActiveLights()) do
        rows[#rows + 1] = { text = D.LightWhy(lv.id), level = max(lv.r, lv.g, lv.b), kind = "l" }
    end
    for i, line in ipairs(win.now) do
        local row = rows[i]
        if row then
            line:SetText(string.format("%s  %d%%", row.text, floor(row.level * 100 + 0.5)))
            if row.kind == "l" then line:SetTextColor(0.75, 0.85, 1) else line:SetTextColor(0.95, 0.9, 0.8) end
        else
            line:SetText(i == 1 and "Nothing" or "")
            line:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    local now = Now()
    for i, line in ipairs(win.logs) do
        local e = D.log[i]
        line:SetText(e and string.format("%3ds  %s", floor(now - e.at), e.text) or "")
    end
end

-- The water as the client tells it (IsSubmerged is untested in this client):
-- "Water: wading · submerged yes · swimming no"
local function YesNo(v) if v == nil then return "?" end return v and "yes" or "no" end
function D.WaterText()
    local w = L.WaterState and L.WaterState()
    if not w then return "Water: ?" end
    local where = w.swimming and "swimming" or w.wading and "wading" or "dry"
    return string.format("Water: %s · submerged %s · swimming %s", where,
        w.api and YesNo(w.submerged) or "no API", YesNo(w.swimming))
end

function D.Show(on)
    if not win then Build() end
    if on == nil then on = not win:IsShown() end
    H.DB().debug = on and true or nil
    win:SetShown(on)
    if on then D.Update() end
    return on
end

function D.Shown() return win ~= nil and win:IsShown() end

if GamepadCompanionAPI then
    GamepadCompanionAPI.ToggleHapticsDebug = function() return D.Show() end
end
