-- The Help tab: a codex. Topics down the left (the side tabs' glyphs); a
-- topic: its title, a small picture drawn from the addon's own art and
-- widgets (never clickable), numbered points that match the picture's
-- marks, and Go there. Start here first: three steps, each ticked from the
-- live state (the pad, WoW Helper's link). Commands: a two-column table.
local _, ns = ...
local S, Shell = ns.OptionsSkin, ns.Shell
local API = GamepadCompanionAPI
local W, H = Shell.W, Shell.H
local MEDIA = "Interface\\AddOns\\GamepadCompanion\\Media\\"
local ART = "Interface\\AddOns\\GamepadCompanion\\art\\"
local LIST_W, ROW_H = 220, 40
local CX = LIST_W + 14
local CW = W - CX
local WELL_W, WELL_H = CW - 36, 220

local help = { buttons = {}, visuals = {} }
local FeelIt
ns.HelpPage = help

-- a side tab's glyph ("bars"), or one of Help's own ("topic-credits")
local function Glyph(key) return MEDIA .. (key:find("^topic%-") and key or ("tab-" .. key)) end
local function Go(key) return function() if API and API.OpenPage then API.OpenPage(key) end end end

-- A numbered mark: a gold disc, its number dark (the points use the same)
local function Badge(parent, n, x, y, anchor)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(20, 20)
    b:SetPoint("CENTER", anchor or parent, "TOPLEFT", x, y)
    if b.SetFrameLevel and parent.GetFrameLevel then b:SetFrameLevel((parent:GetFrameLevel() or 0) + 8) end
    local disc = b:CreateTexture(nil, "ARTWORK")
    disc:SetAllPoints()
    disc:SetColorTexture(1, 0.8, 0.3, 1)
    if b.CreateMaskTexture and disc.AddMaskTexture then
        local mask = b:CreateMaskTexture()
        if mask then mask:SetAtlas("CircleMask"); mask:SetAllPoints(disc); disc:AddMaskTexture(mask) end
    end
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    t:SetPoint("CENTER", 0, 0)
    t:SetTextColor(0.16, 0.1, 0.04)
    t:SetText(tostring(n))
    return b
end
help.Badge = Badge

-- Everything in a picture is for looking at only
local function Still(frame)
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.GetChildren then for _, c in ipairs({ frame:GetChildren() }) do Still(c) end end
end

local function Tex(parent, path, x, y, w, h, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(path)
    t:SetSize(w, h)
    t:SetPoint("TOPLEFT", x, y)
    return t
end

local function Label(parent, text, x, y, w, size, color, justify)
    local l = S.Text(parent, text, x, y, w, size or 12, color or S.GOLD)
    if justify then l:SetJustifyH(justify) end
    return l
end

-- Pictures -------------------------------------------------------------------
-- Each builds into a frame the size of the well; the marks match the points.

local PICTURES = {}

-- the pad, drawn as on the Controller page, its parts marked
PICTURES.controller = function(f)
    local h = WELL_H - 20
    local w = h * 1024 / 680
    local x0 = (WELL_W - w) / 2
    local art = Tex(f, ART .. "DualSense", x0, -10, w, h)
    art:SetTexCoord(0, 1, 0, 680 / 1024)
    local k = h / 680
    Badge(f, 1, x0 + 812 * k + 40, -10 - 83 * k)
    Badge(f, 2, x0 + 212 * k, -10 - 44 * k + 4)
    Badge(f, 3, x0 + 198 * k - 30, -10 - 272 * k)
end

-- the touchpad, its zones and a swipe
PICTURES.touchpad = function(f)
    local w, h = 380, 200
    local x0, y0 = (WELL_W - w) / 2, -(WELL_H - h) / 2
    local pad = Tex(f, ART .. "DualSense", x0, y0, w, h)
    pad:SetTexCoord(360 / 1024, 664 / 1024, 112 / 1024, 272 / 1024)
    for c = 1, 2 do
        local l = f:CreateTexture(nil, "OVERLAY")
        l:SetColorTexture(1, 0.82, 0.3, 0.55)
        l:SetSize(2, h - 16); l:SetPoint("TOPLEFT", x0 + c * w / 3, y0 - 8)
    end
    local mid = f:CreateTexture(nil, "OVERLAY")
    mid:SetColorTexture(1, 0.82, 0.3, 0.55)
    mid:SetSize(w - 16, 2); mid:SetPoint("TOPLEFT", x0 + 8, y0 - h / 2)
    local arrow = Label(f, "»", x0 + w + 8, y0 - h / 2 + 14, 40, 26, S.YELLOW)
    Badge(f, 1, x0 + w / 6, y0 - h / 4)
    Badge(f, 2, x0 + w + 46, y0 - h / 2)
    Badge(f, 3, x0 + w / 2, y0 - 3 * h / 4)
    return arrow
end

-- a moment's row, as on the Moments page, with Feel | Light | Sound above
PICTURES.moments = function(f)
    local seg = CreateFrame("Frame", nil, f)
    seg:SetPoint("TOPLEFT", (WELL_W - 216) / 2, -26)
    seg:SetSize(218, 30)
    S.Segments(seg, 0, 0, { 72, 72, 72 }, 28)
    for i, name in ipairs({ "Feel", "Light", "Sound" }) do
        local b = S.Segment(seg, name, 1 + (i - 1) * 72, -1, 72, nil, 12, 28)
        S.SetSelected(b, i == 1)
    end
    Still(seg)
    Badge(f, 4, -8, -2, seg)
    -- (HapticsUI loads after this file: read it when drawn)
    local HUI = ns.HapticsUI
    if not HUI then return end
    local holder = CreateFrame("Frame", nil, f)
    local rw = 720
    holder:SetPoint("TOPLEFT", (WELL_W - rw) / 2 - 10, -96)
    holder:SetSize(rw, 60)
    local row = HUI.MomentRow(holder, 0, rw, ART .. "rumble\\ic_event_crit", "Critical hit", function() end, function() end, nil,
        { default = function() end })
    if row.label then row.label:SetText("Critical hit") end
    if row.SetChoice then row:SetChoice("Impact", ART .. "rumble\\ic_vibe_impact", nil, false) end
    Still(holder)
    Badge(f, 1, 0, 0, row.pick)
    Badge(f, 2, 0, 0, row.try)
    if row.default then Badge(f, 3, 0, 0, row.default) end
end

-- the helper's loop: recorded, recognised, run
PICTURES.gestures = function(f)
    -- (the action: the first gesture's own, else a typed macro's note)
    local G, icon = ns.Gestures, nil
    for slot = 1, G and G.SLOTS or 0 do
        local a = G.Get(slot)
        if a and ns.Touch and not icon then local _, i = ns.Touch.ActionLook(a); icon = i end
    end
    local steps = { { Glyph("gestures"), "Recorded" }, { false, "Keys pressed" }, { icon or "Interface\\Icons\\INV_Misc_Note_01", "Action runs" } }
    local step, size = 230, 72
    local x0 = (WELL_W - (2 * step + size)) / 2
    for i, s in ipairs(steps) do
        local x = x0 + (i - 1) * step
        local well = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        well:SetColorTexture(0, 0, 0, 0.3)
        well:SetSize(size + 24, size + 24); well:SetPoint("TOPLEFT", x - 12, -48)
        if s[1] then Tex(f, s[1], x, -60, size, size)
        else
            -- (a keycap: the chord WoW Helper presses)
            local cap = f:CreateTexture(nil, "ARTWORK")
            cap:SetColorTexture(0.95, 0.9, 0.75, 0.9); cap:SetSize(size, size - 20); cap:SetPoint("TOPLEFT", x, -70)
            Label(f, "F1", x, -88, size, 20, { 0.16, 0.1, 0.04 }, "CENTER")
            Label(f, "Ctrl Shift Alt", x - 30, -60 - size + 6 + 0, size + 60, 10, S.GREY, "CENTER")
        end
        Label(f, s[2], x - 40, -60 - size - 24, size + 80, 13, S.YELLOW, "CENTER")
        Badge(f, i, x + size + 12, -48)
        if i < 3 then Label(f, "›", x + size + 70, -78, 40, 36, S.GOLD, "CENTER") end
    end
end

-- the bars: two rows of slots on a preview, Compact | Standard
PICTURES.bars = function(f)
    -- (as the topic says: 1 Edit Mode, 2 a bar picked in it, dragged; no preview, no switch: UI-7)
    local slot, gap = 26, 4
    local rowW = 12 * slot + 11 * gap
    local x0 = (WELL_W - rowW) / 2
    local edit = S.NewButton(f, "Edit Mode", (WELL_W - 140) / 2, -24, 140, nil, nil, 12, 28)
    Still(edit)
    Badge(f, 1, -8, -2, edit)
    local frame = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame:SetColorTexture(0, 0, 0, 0.3)
    frame:SetSize(rowW + 40, slot + 40); frame:SetPoint("TOPLEFT", x0 - 20, -86)
    for c = 0, 11 do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(0.85, 0.66, 0.32, 0.55)
        t:SetSize(slot, slot)
        t:SetPoint("TOPLEFT", x0 + c * (slot + gap), -106)
    end
    -- (picked: a gold box round the bar)
    for _, e in ipairs({ { "TOPLEFT", rowW + 12, 2, -6 }, { "BOTTOMLEFT", rowW + 12, 2, -6 - slot - 12 + 2 },
        { "TOPLEFT", 2, slot + 12, -6 }, { "TOPRIGHT", 2, slot + 12, -6 } }) do
        local l = f:CreateTexture(nil, "OVERLAY")
        l:SetColorTexture(1, 0.78, 0.25, 0.9)
        l:SetSize(e[2], e[3])
        if e[1] == "TOPRIGHT" then l:SetPoint("TOPLEFT", x0 + rowW + 4, -100)
        elseif e[1] == "BOTTOMLEFT" then l:SetPoint("TOPLEFT", x0 - 6, -100 - slot - 10)
        else l:SetPoint("TOPLEFT", x0 - 6, -100) end
    end
    Label(f, "↔", x0 + rowW + 30, -110, 40, 22, S.YELLOW)
    Badge(f, 2, x0 + rowW + 70, -120)
end
PICTURES.setup = function(f)
    local cw, gap = 230, 24
    local x0 = (WELL_W - (3 * cw + 2 * gap)) / 2
    local titles = { "WoW Helper", "Faintest feel", "Resting light" }
    for i = 1, 3 do
        local card = S.Card(f, titles[i], x0 + (i - 1) * (cw + gap), -28, cw, 160)
        Badge(f, i, x0 + (i - 1) * (cw + gap) + cw - 14, -28)
        if i == 1 then
            local dot = card:CreateTexture(nil, "ARTWORK")
            dot:SetColorTexture(0.35, 0.85, 0.4, 1); dot:SetSize(10, 10); dot:SetPoint("TOPLEFT", 16, -60)
            Label(card, "Read", 34, -57, 150, 13, S.GOLD)   -- (never "Linked": only WoW Helper can say that)
            Label(card, "USB", 34, -80, 150, 12, S.GREY)
        elseif i == 2 then
            -- (Left and Right, each a slider: as on Setup)
            for k, side in ipairs({ { "Left", 0.35 }, { "Right", 0.3 } }) do
                local y = -54 - (k - 1) * 30
                Label(card, side[1], 16, y - 2, 50, 12, S.GOLD)
                local track = card:CreateTexture(nil, "ARTWORK")
                track:SetColorTexture(1, 1, 1, 0.12); track:SetSize(cw - 110, 6); track:SetPoint("TOPLEFT", 66, y - 6)
                local fill = card:CreateTexture(nil, "OVERLAY")
                fill:SetColorTexture(1, 0.78, 0.25, 0.9); fill:SetSize((cw - 110) * side[2], 6); fill:SetPoint("TOPLEFT", 66, y - 6)
            end
        else
            for k, c in ipairs({ { 0.9, 0.3, 0.2 }, { 1, 0.7, 0.2 }, { 0.3, 0.8, 0.4 }, { 0.3, 0.5, 1 }, { 0.7, 0.4, 1 } }) do
                local sw = card:CreateTexture(nil, "ARTWORK")
                sw:SetColorTexture(c[1], c[2], c[3], 1); sw:SetSize(28, 22); sw:SetPoint("TOPLEFT", 16 + (k - 1) * 40, -64)
            end
        end
        Still(card)
    end
end

-- the footer's two chips
PICTURES.profiles = function(f)
    local x0 = (WELL_W - 460) / 2
    for i, word in ipairs({ "Controls · Alberich", "Feel · Alberich" }) do
        local b = S.NewButton(f, word .. "  ▾", x0 + (i - 1) * 240, -96, 220, nil, nil, 13, 34)
        b:EnableMouse(false)
        Badge(f, i, 0, 0, b)
    end
    Label(f, "Footer", x0, -150, 460, 12, S.DIM, "CENTER")
end

-- Topics ----------------------------------------------------------------------

local function PadReady()
    local id = C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
    return type(id) == "number" and id >= 0
end
local function HelperReady()
    local K, C = ns.HelperLink, ns.HelperCues
    return K and K.Enabled() and C and C.Data and C.Data() ~= nil or false
end

-- Feel it: the Feel tour (one control for one thing: U2-15); again: Stop
FeelIt = function()
    local page = ns.RumblePage
    if page and page.PlayTour then page.PlayTour() end
end

-- /gpc: Start here while the pad or WoW Helper isn't ready (a client that
-- can't tell about the pad counts as ready), once; then the last page (playing
-- without WoW Helper is fine: Start here isn't forced every time, U2-7)
function help.NeedsStart()
    local padKnown = C_GamePad and C_GamePad.GetActiveDeviceID
    return (padKnown and not PadReady()) or not HelperReady()
end
local function UI()
    if type(GamepadCompanionHapticsDB) ~= "table" then GamepadCompanionHapticsDB = {} end
    local h = GamepadCompanionHapticsDB
    if type(h.ui) ~= "table" then h.ui = {} end
    return h.ui
end
function API.OpenStart()
    if not help.NeedsStart() or UI().startSeen then return false end
    UI().startSeen = true
    Shell.Open("help")
    if help.ShowTopic then help.ShowTopic(1) end
    return true
end

local TOPICS = {
    { key = "start", name = "Start here", glyph = "help", start = true, tour = true },
    { key = "fix", name = "Fix it", glyph = "topic-fix", fix = true },
    { key = "controller", name = "Controller", glyph = "controller", marks = 3, go = Go("controller"), points = {
        "Click any button: set it", "Hold L2 or R2: its layer", "D-pad and face: bar slots, pages 1-3",
        "Choose: spell, item, macro, window", "In combat: applies after" } },
    { key = "touchpad", name = "Touchpad", glyph = "topic-touchpad", picture = "touchpad", marks = 3,
        go = function() if API and API.ToggleTouchpad then API.ToggleTouchpad() end end, points = {
        "Zones: an action each", "Swipes: four more", "Touch + click: two a zone", "Taps: out of combat only" } },
    { key = "moments", name = "Moments", glyph = "moments", marks = 4, go = Go("moments"), tour = true, points = {
        "The feel: click to pick", "Try: feel it now", "Default: as it ships", "Feel, Light, Sound: a view each" } },
    { key = "gestures", name = "Gestures", glyph = "gestures", marks = 3, go = Go("gestures"), points = {
        "Record: WoW Helper › Gestures", "Recognised: WoW Helper presses its keys", "Runs: the action chosen here" } },
    { key = "bars", name = "Bars", glyph = "bars", marks = 2, go = Go("bars"), points = {
        "Edit Mode: drag a bar", "Compact or Standard: Edit Mode", "Click a bar: scale, prompt, reset",
        "Class menus: L1 + L2, R1 + R2" } },
    { key = "setup", name = "Setup", glyph = "setup", marks = 3, go = Go("setup"), points = {
        "WoW Helper: run it, Link on", "Faintest feel: just felt",
        "Resting light: between moments", "Timing: learned by WoW Helper" } },
    { key = "profiles", name = "Profiles", glyph = "topic-profiles", marks = 2, points = {
        "Controls: buttons, touchpad, bars", "Feel: vibration, light, sound", "New character: Recommended" } },
    { key = "commands", name = "Commands", glyph = "tools", commands = {
        { "/gpc", "window" }, { "/gpc moments", "moments" }, { "/gpc pad", "controller" }, { "/gpc touch", "touchpad" },
        { "/gpc bars", "bar layout" }, { "/gpc light", "moments: light" }, { "/gpc rumble", "same as moments" },
        { "/gpc rumble test", "each motor" },
        { "/gpc gestures", "gestures" }, { "/gpc setup", "setup" }, { "/gpc lab", "lab, on for good" },
        { "/gpc on | off", "my bar layout" }, { "/gpc reset", "both bar layouts" }, { "/gpc gamepad", "Blizzard options" },
        { "/gpc edit", "Edit Mode layout" }, { "/gpc help", "commands in chat" } } },
    { key = "credits", name = "Credits", glyph = "topic-credits", points = {
        "Rumble patterns: Improved Forever: Vibration (markg)", "and Easy Controller (moust4ki), MIT", "Licenses: licenses/" },
        plain = true },
}
help.TOPICS = TOPICS

local function Points(topic)
    local p = help.points
    local top = (topic.commands or topic.plain) and -52 or -(46 + WELL_H + 18)
    if topic.start then top = -(46 + WELL_H + 18) end
    for i, row in ipairs(p) do
        local text = topic.points and topic.points[i]
        row:SetShown(text ~= nil)
        if text then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 18, top - (i - 1) * 32)
            row.text:SetText(text)
            -- (a number only where the picture has that mark; else a quiet dot)
            local marked = i <= (topic.marks or 0)
            row.badge:SetShown(marked)
            row.dot:SetShown(not marked and not topic.plain)
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", topic.plain and 4 or 32, 0)
        end
    end
end

local function StartSteps()
    local s = help.start
    local ready = { PadReady(), HelperReady(), PadReady() and HelperReady() }
    for i, tile in ipairs(s.tiles) do
        local on = ready[i]
        tile.state:SetText(i == 4 and "Crit · Loot · Level up" or on and "Ready" or (i == 3 and "After 1 and 2" or "Not yet"))
        tile.state:SetTextColor(on and 0.35 or S.GREY[1], on and 0.85 or S.GREY[2], on and 0.4 or S.GREY[3])
        tile.tick:SetShown(on)
    end
end

-- Fix it: what a player says, the checks that answer it (live), where to go
local function Fighting() return InCombatLockdown and InCombatLockdown() end
local function V() return ns.Rumble end
local function LinkOn() local K = ns.HelperLink; return K and K.Enabled() or false end
local function Read() local C = ns.HelperCues; return LinkOn() and C and C.HelperData and C.HelperData() ~= nil or false end
help.FIXES = {
    { "Nothing is felt", "moments", {
        { "Pad", function() return Shell.PadPresent == nil or Shell.PadPresent() ~= false end },
        { "Feel on", function() return V() and V().Settings().enabled == true end },
        { "No other vibration addon", function() return not (V() and V().Other and V().Other()) end } } },
    { "WoW Helper not read", "setup", {
        { "Link on", LinkOn },
        { "Read at login", Read } } },
    { "Sounds silent", "sound", {
        { "Link on", LinkOn },
        { "Sounds on", function() local C = ns.HelperCues; return C and C.Settings and C.Settings().sounds == true end },
        { "Read at login", Read } } },
    { "Lights stay class colour", "light", {
        { "Light on", function() local H = ns.Haptics; return H and H.DB().light == true end },
        { "Link on", LinkOn } } },
}
local function FixGo(where)
    if where == "sound" or where == "light" then
        return function()
            if API and API.OpenMoments then API.OpenMoments(where) else Go("moments")() end
        end
    end
    return Go(where)
end
local function RefreshFix()
    for i, f in ipairs(help.FIXES) do
        local row = help.fixRows and help.fixRows[i]
        if row then
            local parts, ok = {}, true
            for _, c in ipairs(f[3]) do
                local good = c[2]() and true or false
                ok = ok and good
                parts[#parts + 1] = (good and "|cff5ad966✓|r " or "|cffff7a5c✗|r ") .. c[1]
            end
            row.checks:SetText(table.concat(parts, "    "))
            row.state:SetText(ok and "|cff5ad966All good|r" or "")
        end
    end
end
help.RefreshFix = RefreshFix

local function ShowTopic(index)
    local topic = TOPICS[index]
    help.index = index
    help.title:SetText(topic.name)
    for i, b in ipairs(help.buttons) do S.SetSelected(b, i == index) end
    -- the picture
    for _, v in pairs(help.visuals) do v:Hide() end
    local key = topic.picture or topic.key
    local hasPicture = PICTURES[key] ~= nil or topic.start
    help.well:SetShown(hasPicture)
    if topic.start then
        help.start:Show(); StartSteps()
    else
        help.start:Hide()
        if PICTURES[key] then
            if not help.visuals[key] then
                local f = CreateFrame("Frame", nil, help.well)
                f:SetAllPoints()
                PICTURES[key](f)
                help.visuals[key] = f
            end
            help.visuals[key]:Show()
        end
    end
    -- Fix it: the four rows, checked now
    if help.fix then
        help.fix:SetShown(topic.fix == true)
        if topic.fix then help.well:Hide(); RefreshFix() end
    end
    -- the tour: Start here and Moments
    if help.tour then
        help.tour:SetShown(topic.tour == true)
        if topic.tour then
            help.tour:ClearAllPoints()
            local n = #(topic.points or {})
            local y = -(46 + WELL_H + 18) - n * 32 - 10
            help.tour:SetPoint("TOPLEFT", topic.go and 200 or 50, y)
        end
    end
    -- the commands table, or the points
    help.table:SetShown(topic.commands ~= nil)
    Points(topic)
    help.go:SetShown(topic.go ~= nil)
    help.go:SetScript("OnClick", topic.go)
    if topic.go then
        local n = #(topic.points or {})
        help.go:ClearAllPoints()
        help.go:SetPoint("TOPLEFT", 50, -(46 + WELL_H + 18) - n * 32 - 10)
    end
    S.FadeIn(help.card, 0.12)
end
help.ShowTopic = ShowTopic

local function Build(frame)
    -- the topics
    local list = S.Card(frame, nil, 0, 0, LIST_W, H)
    for i, topic in ipairs(TOPICS) do
        local b = S.NewButton(list, topic.name, 10, -12 - (i - 1) * ROW_H, LIST_W - 20, function() ShowTopic(i) end, nil, 13, ROW_H - 6)
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetTexture(Glyph(topic.glyph))
        b.icon:SetSize(24, 24)
        b.icon:SetPoint("LEFT", 8, 0)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", 40, 0); b.label:SetPoint("RIGHT", -8, 0)
        b.label:SetJustifyH("LEFT")
        help.buttons[i] = b
    end
    -- the topic
    local card = S.Card(frame, " ", CX, 0, CW, H)
    help.card = card
    help.title = card.title
    help.well = CreateFrame("Frame", nil, card)
    help.well:SetPoint("TOPLEFT", 18, -46)
    help.well:SetSize(WELL_W, WELL_H)
    local shade = help.well:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.22)
    -- Start here: three steps, ticked from the live state
    help.start = CreateFrame("Frame", nil, help.well)
    help.start:SetAllPoints()
    help.start.tiles = {}
    local tw, gap = 186, 18
    local x0 = (WELL_W - (4 * tw + 3 * gap)) / 2
    for i, step in ipairs({ { "controller", "Connect the pad" }, { "setup", "Start WoW Helper" }, { "moments", "Play" },
        { "gestures", "Feel it", FeelIt } }) do
        local tile = S.Card(help.start, nil, x0 + (i - 1) * (tw + gap), -24, tw, WELL_H - 48)
        -- (a step opens its page: Controller, Setup, Moments; Feel it plays three)
        tile:EnableMouse(true)
        tile:SetScript("OnMouseUp", step[3] or Go(step[1]))
        local hover = tile:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(); hover:SetColorTexture(1, 0.8, 0.4, 0.08)
        tile.page = step[1]
        Badge(help.start, i, x0 + (i - 1) * (tw + gap) + 18, -42)
        Tex(tile, Glyph(step[1]), (tw - 64) / 2, -22, 64, 64)
        Label(tile, step[2], 10, -100, tw - 20, 14, S.YELLOW, "CENTER")
        tile.state = Label(tile, "", 10, -126, tw - 20, 12, S.GREY, "CENTER")
        tile.tick = Label(tile, "✓", tw - 34, -12, 24, 18, { 0.35, 0.85, 0.4 }, "CENTER")
        help.start.tiles[i] = tile
    end
    help.start:Hide()
    -- the points: a mark, a few words
    help.points = {}
    for i = 1, 5 do
        local row = CreateFrame("Frame", nil, card)
        row:SetSize(CW - 200, 26)
        row.badge = Badge(row, i, 10, -13)
        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetColorTexture(S.GOLD[1], S.GOLD[2], S.GOLD[3], 0.5)
        row.dot:SetSize(6, 6)
        row.dot:SetPoint("CENTER", row, "TOPLEFT", 10, -13)
        row.text = Label(row, "", 32, -6, CW - 240, 13, S.GOLD)
        help.points[i] = row
    end
    -- the commands: two columns, the command and what it opens
    help.table = CreateFrame("Frame", nil, card)
    help.table:SetPoint("TOPLEFT", 18, -52)
    help.table:SetSize(CW - 36, H - 70)
    local cmds
    for _, t in ipairs(TOPICS) do if t.commands then cmds = t.commands end end
    local per = math.ceil(#cmds / 2)
    for i, c in ipairs(cmds) do
        local col, row = math.floor((i - 1) / per), (i - 1) % per
        local x, y = col * (CW - 36) / 2, -row * 34
        if row % 2 == 0 then
            local band = help.table:CreateTexture(nil, "BACKGROUND")
            band:SetColorTexture(1, 0.85, 0.55, 0.05)
            band:SetSize((CW - 36) / 2 - 12, 30); band:SetPoint("TOPLEFT", x, y + 4)
        end
        Label(help.table, c[1], x + 10, y - 4, 170, 13, S.YELLOW)
        Label(help.table, c[2], x + 190, y - 4, (CW - 36) / 2 - 210, 13, S.GREY)
    end
    help.table:Hide()
    help.go = S.NewButton(card, "Go there", CW - 160, -(H - 52), 140, nil, nil, 13, 36)
    -- the Feel tour: six moments in 25 s, each named in Just felt
    help.tour = S.NewButton(card, "Play the tour", 0, 0, 140, function() FeelIt() end, nil, 13, 36)
    help.tour:Hide()
    -- (while it plays the same button stops it)
    local page = ns.RumblePage
    if page then
        page.onTour = function(on) help.tour.label:SetText(on and "Stop" or "Play the tour") end
    end
    -- Fix it: a row a problem: its name, its checks, Go there
    help.fix = CreateFrame("Frame", nil, card)
    help.fix:SetPoint("TOPLEFT", 18, -46)
    help.fix:SetSize(CW - 36, H - 64)
    help.fixRows = {}
    for i, f in ipairs(help.FIXES) do
        local row = S.Card(help.fix, nil, 0, -(i - 1) * 118, CW - 36, 106)
        Label(row, f[1], 16, -14, CW - 260, 15, S.YELLOW)
        row.checks = Label(row, "", 16, -44, CW - 260, 13, S.GOLD)
        row.state = Label(row, "", 16, -70, CW - 260, 12, S.GREY)
        row.go = S.NewButton(row, "Go there", CW - 36 - 156, -34, 140, FixGo(f[2]), nil, 13, 36)
        help.fixRows[i] = row
    end
    help.fix:Hide()
    if API and API.GetCapabilities and API.GetCapabilities().suspended then
        help.title:SetText("Paused in this recovery build")
    else
        ShowTopic(1)
    end
end

Shell.AddPage({
    key = "help", name = "Help", order = 7, icon = "Interface\\Icons\\INV_Misc_Book_09", build = Build,
    refresh = function()
        if help.index == 1 and help.start then StartSteps() end
        if help.fix and help.fix:IsShown() then RefreshFix() end
    end,
})
