-- The Gamepad Companion window: one Forever window, its pages on side tabs
-- (as in Forever Names). Pages register with Shell.AddPage; the window builds
-- them when first opened. Controller is the main page.
local ADDON, ns = ...
local S = ns.OptionsSkin
local API = GamepadCompanionAPI
local Shell = {}
ns.Shell = Shell

Shell.W, Shell.H = 1101, 604          -- a page's area
local HEADER, FOOTER = 40, 40
local TAB_SCALE = 0.82

local defs, built, tabs = {}, {}, {}
local window, content, header, current
local status, statusUntil

function Shell.AddPage(def)
    defs[#defs + 1] = def
    table.sort(defs, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

-- A page by its key, or by an old key it answers to (def.aliases)
local function Def(key)
    for _, def in ipairs(defs) do
        if def.key == key then return def end
        for _, alias in ipairs(def.aliases or {}) do if alias == key then return def end end
    end
end

-- A page whose def.shown() says false has no tab (Lab, until Tools › Lab); it still opens by key
local function Listed(def) return def.shown == nil or def.shown() == true end

-- Status line, bottom left. A message from the player's last action stays a few seconds.
function Shell.SetStatus(text, sticky)
    if not window then return end
    local now = GetTime and GetTime() or 0
    if sticky then statusUntil = now + 5
    elseif statusUntil and now < statusUntil then return end
    text = text or ""
    window.status:SetText(text)
    -- a dot: orange for a warning, green for what just happened
    local dot = window.statusDot
    if dot then
        local warn = text:find("|cffff7a5c", 1, true) == 1
        dot:SetShown(text ~= "")
        if warn then dot:SetColorTexture(1, 0.48, 0.36, 1)
        elseif sticky then dot:SetColorTexture(0.35, 0.85, 0.4, 1)
        else dot:SetColorTexture(0.62, 0.62, 0.62, 0.8) end
    end
    if sticky and text ~= "" then S.FadeIn(window.status, 0.15) end
end

-- A status with an action beside it for a while ("…: as it ships · Undo", 5 s)
function Shell.Offer(text, action, fn, seconds)
    if not window then return end
    Shell.SetStatus(text, true)
    local b = window.offer
    if not b then
        b = S.NewButton(window, "", 0, 0, 60, nil, nil, 11, 22)
        window.offer = b
    end
    b.label:SetText(action)
    b:ClearAllPoints()
    local w = window.status:GetStringWidth()
    b:SetPoint("LEFT", window.status, "LEFT", (type(w) == "number" and w or 120) + 10, 0)
    b:SetScript("OnClick", function() b:Hide(); fn(); Shell.SetStatus(text:gsub(":.*$", "") .. ": back", true) end)
    b:Show()
    b.until_ = (GetTime and GetTime() or 0) + (seconds or 5)
    if C_Timer and C_Timer.After then
        C_Timer.After(seconds or 5, function()
            if (GetTime and GetTime() or 0) >= (b.until_ or 0) - 0.05 then b:Hide() end
        end)
    end
end

-- The WoW Helper chip, once a little brighter: where to look
function Shell.PulseLink()
    if window and window.link then S.FadeIn(window.link, 0.5) end
end

-- What the addon knows of WoW Helper: its data file read at login (when),
-- not read, or the link off. Never "Linked": only the helper can say that.
-- Returns the words after "WoW Helper · " and a state: read, unread, off.
function Shell.LinkWords()
    local K, C = ns.HelperLink, ns.HelperCues
    if not (K and K.Enabled()) then return "off", "off" end
    local data = C and type(C.HelperData) == "function" and C.HelperData()
    if data then return "read " .. tostring(data.at or "?"), "read" end
    return "not read", "unread"
end

-- Whether a pad is there (nil: the game can't say)
function Shell.PadPresent()
    if not (C_GamePad and C_GamePad.GetActiveDeviceID) then return nil end
    local ok, id = pcall(C_GamePad.GetActiveDeviceID)
    if not ok then return nil end
    return type(id) == "number" and id >= 0
end

-- The WoW Helper chip: read (green), not read (orange), off (grey); No pad beside it
function Shell.RefreshLink()
    local chip = window and window.link
    if not chip then return end
    local words, state = Shell.LinkWords()
    if state == "read" then chip.dot:SetColorTexture(0.35, 0.85, 0.4, 1)
    elseif state == "unread" then chip.dot:SetColorTexture(1, 0.62, 0.25, 1)
    else chip.dot:SetColorTexture(0.5, 0.5, 0.5, 1) end
    chip.text:SetText("WoW Helper · " .. words)
    S.Tooltip(chip, "WoW Helper", "Setup")
    if window.noPad then window.noPad:SetShown(Shell.PadPresent() == false) end
end

function Shell.Window() return window end
function Shell.Current() return current end
function Shell.IsShown(key) return window ~= nil and window:IsShown() and (key == nil or current == key) end

local function Fit()
    local tabW = 48
    local w, h = window:GetWidth() + tabW, window:GetHeight()
    -- (the Size setting, smaller still on a small screen; popups follow the window)
    window:SetScale(math.max(0.45, math.min(S.UIScale(), (UIParent:GetWidth() - 40) / w, (UIParent:GetHeight() - 40) / h)))
end
S.OnScale(function() if window then Fit() end end)

local function Page(key)
    local def = Def(key)
    if not def then return nil end
    local page = built[key]
    if page then return page end
    page = { def = def }
    page.frame = CreateFrame("Frame", nil, content)
    page.frame:SetPoint("TOPLEFT", 0, -HEADER)
    page.frame:SetSize(Shell.W, Shell.H)
    page.frame:Hide()
    -- Header: the page's name, a tooltip line, and room on the right for its switch
    page.header = CreateFrame("Frame", nil, content)
    page.header:SetPoint("TOPLEFT", 0, 0)
    page.header:SetSize(Shell.W, HEADER - 6)
    page.header:Hide()
    local glyph = page.header:CreateTexture(nil, "ARTWORK")
    glyph:SetSize(26, 26)
    glyph:SetPoint("LEFT", 2, 0)
    Shell.Glyph(glyph, def, 0.07)
    S.OnSkin(function() Shell.PaintGlyph(glyph, "active") end)
    page.glyph = glyph
    local title = page.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", glyph, "RIGHT", 8, 0)
    title:SetText(def.name)
    page.title = title
    if def.sub then
        local sub = S.Text(page.header, def.sub, 0, 0, 600, 12, S.GREY)
        sub:ClearAllPoints()
        sub:SetPoint("LEFT", title, "RIGHT", 14, -1)
        page.sub = sub
    end
    local strip = S.SkinTexture(page.header, "header", "BACKGROUND", 0, false)
    strip:SetPoint("TOPLEFT", -2, 4); strip:SetPoint("BOTTOMRIGHT", 2, -2)
    -- (Gilded: the plaque, its ends kept square, its middle stretched)
    local G = { gilded = true }
    local ph, pw = HEADER - 6, 300
    local pl = S.SkinTexture(page.header, "plaqueL", "BACKGROUND", 1, false, nil, G)
    pl:SetPoint("LEFT", -2, 0); pl:SetSize(ph, ph)
    local pr = S.SkinTexture(page.header, "plaqueR", "BACKGROUND", 1, false, nil, G)
    pr:SetPoint("LEFT", pw - ph, 0); pr:SetSize(ph, ph)
    local pm = S.SkinTexture(page.header, "plaqueM", "BACKGROUND", 1, false, nil, G)
    pm:SetPoint("LEFT", pl, "RIGHT", 0, 0); pm:SetPoint("RIGHT", pr, "LEFT", 0, 0); pm:SetHeight(ph)
    local line = page.header:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 0, -2)
    line:SetSize(Shell.W, 1)
    line:SetColorTexture(0.68, 0.50, 0.26, 0.45)
    def.build(page.frame, page.header)
    built[key] = page
    return page
end

function Shell.Select(key)
    key = (Def(key) or defs[1]).key
    local page = Page(key)
    for k, p in pairs(built) do
        local on = k == key
        if not on and p.frame:IsShown() and p.def.hide then p.def.hide() end
        p.frame:SetShown(on)
        p.header:SetShown(on)
    end
    for k, tab in pairs(tabs) do tab.selected:SetShown(k == key); if tab.Paint then tab.Paint() end end
    if current ~= key then S.FadeIn(page.frame, 0.12); S.FadeIn(page.header, 0.12) end
    current = key
    statusUntil = nil
    Shell.SetStatus("")
    if page.def.show then page.def.show() end
    if page.def.refresh then page.def.refresh() end
end

function Shell.Refresh()
    if not (window and window:IsShown() and current) then return end
    local page = built[current]
    if page and page.def.refresh then page.def.refresh() end
end

-- Each page's glyph: one set in the feel icons' style (Media\\tab-<key>), the
-- page's own icon when the file is missing
Shell.GLYPHS = { controller = true, moments = true, gestures = true, setup = true, bars = true, tools = true,
    help = true, lab = true }
function Shell.Glyph(tex, def, cut)
    if Shell.GLYPHS[def.key] then
        local ok, loaded = pcall(tex.SetTexture, tex, "Interface\\AddOns\\GamepadCompanion\\Media\\tab-" .. def.key)
        if ok and loaded ~= false then
            if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
            tex.gpcGlyph = true
            return
        end
    end
    if def.atlas then tex:SetAtlas(def.atlas) else
        tex:SetTexture(def.icon)
        if tex.SetTexCoord then tex:SetTexCoord(cut, 1 - cut, cut, 1 - cut) end
    end
end
-- active (bright), hover, idle (dim); Gilded warms the cream to gold
local GLYPH_ALPHA = { active = 1, hover = 0.85, idle = 0.55 }
function Shell.PaintGlyph(tex, state)
    if not rawget(tex, "gpcGlyph") then tex:SetVertexColor(1, 1, 1); tex:SetAlpha(state == "idle" and 0.8 or 1); return end
    if S.Skin() == "gilded" then tex:SetVertexColor(1, 0.84, 0.5) else tex:SetVertexColor(1, 1, 1) end
    tex:SetAlpha(GLYPH_ALPHA[state] or 1)
end

local function Tab(def, index)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-sidetab")
    local tab = CreateFrame("Button", nil, window)
    tab:SetSize(info and info.width or 43, info and (info.height - 5) or 55)
    tab:SetScale(TAB_SCALE)
    local background = tab:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("common-sidetab", true)
    background:SetPoint("CENTER")
    local icon = tab:CreateTexture(nil, "ARTWORK")
    Shell.Glyph(icon, def, 0.03125)
    icon:SetPoint("CENTER", -4, 0)
    if rawget(icon, "gpcGlyph") then
        -- (a glyph on the native tab: no mask, a little inside its round)
        icon:SetSize(36, 36)
    else
        local mask = tab.CreateMaskTexture and icon.AddMaskTexture and tab:CreateMaskTexture()
        if mask then
            icon:SetSize(50, 50)
            mask:SetAtlas("common-sidetab-mask", true)
            mask:SetPoint("CENTER")
            icon:AddMaskTexture(mask)
        else
            icon:SetSize(34, 34)
        end
    end
    tab.icon = icon
    local function Paint()
        Shell.PaintGlyph(icon, tab.selected:IsShown() and "active" or tab.hovered and "hover" or "idle")
    end
    tab.Paint = Paint
    tab.selected = tab:CreateTexture(nil, "OVERLAY")
    tab.selected:SetAtlas("common-sidetab-selected", true)
    tab.selected:SetPoint("CENTER")
    tab.selected:Hide()
    S.OnSkin(function() Paint() end)
    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAtlas("common-sidetab-hover", true)
    hover:SetPoint("CENTER")
    tab:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", -3, -1) end)
    tab:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", -4, 0) end)
    tab:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        Shell.Select(def.key)
    end)
    tab:SetScript("OnEnter", function(self)
        tab.hovered = true; Paint()
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(def.name, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function()
        tab.hovered = false; Paint()
        if GameTooltip then GameTooltip:Hide() end
    end)
    tab.def = def
    tabs[def.key] = tab
    return tab
end

-- Tabs in order, the hidden ones left out
function Shell.Relayout()
    if not window then return end
    local previous
    for _, def in ipairs(defs) do
        local tab = tabs[def.key]
        tab:ClearAllPoints()
        tab:SetShown(Listed(def))
        if tab:IsShown() then
            if previous then tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
            else tab:SetPoint("TOPLEFT", window, "TOPRIGHT", -6 / TAB_SCALE, -52 / TAB_SCALE) end
            previous = tab
        end
    end
end

local function Build()
    window = CreateFrame("Frame", "GamepadCompanionOptions", UIParent)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    local title = "Gamepad Companion"
    window.chrome = S.Chrome(window, title)
    window.chrome:SetKind("legacy")
    local inset = window.chrome:Insets()
    window:SetSize(Shell.W + inset.left + inset.right, HEADER + Shell.H + FOOTER + inset.top + inset.bottom)
    -- (the skin's background, inside the native frame, under everything)
    local back = S.SkinTexture(window, "background", "BACKGROUND", 7, true, nil, { v2 = true, gilded = true })
    back:SetPoint("TOPLEFT", inset.left, -inset.top)
    back:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom)
    content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", inset.left, -inset.top)
    content:SetSize(Shell.W, HEADER + Shell.H)

    -- Side tabs, outside the right edge
    for index, def in ipairs(defs) do Tab(def, index) end
    Shell.Relayout()
    for _, def in ipairs(defs) do Page(def.key) end

    -- Footer: status, version, Close
    window.status = S.Note(window, inset.left + 16, -(inset.top + HEADER + Shell.H + 14), Shell.W - 740, 1, 12, S.GREY)
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    window.version = S.Text(window, type(version) == "string" and ("v" .. version) or "", 0, 0, 80, 11, S.DIM)
    window.version:ClearAllPoints()
    window.version:SetPoint("BOTTOMRIGHT", -(inset.right + 112), inset.bottom + 14)
    window.version:SetJustifyH("RIGHT")
    if ns.ProfileMenu and ns.Profiles then ns.ProfileMenu.Build(window, window.version) end
    -- the status's dot, and the WoW Helper chip left of the profiles
    window.statusDot = window:CreateTexture(nil, "ARTWORK")
    window.statusDot:SetSize(7, 7)
    window.statusDot:SetPoint("RIGHT", window.status, "LEFT", -5, 0)
    window.statusDot:Hide()
    local chipAnchor = ns.ProfileMenu and ns.ProfileMenu.chips and ns.ProfileMenu.chips[#ns.ProfileMenu.chips] or window.version
    local link = CreateFrame("Button", nil, window)
    link:SetSize(170, 22)
    link:SetPoint("RIGHT", chipAnchor, "LEFT", -10, 0)
    link.dot = link:CreateTexture(nil, "ARTWORK")
    link.dot:SetSize(7, 7); link.dot:SetPoint("LEFT", 4, 0)
    link.text = S.Text(link, "WoW Helper", 0, 0, 156, 11, S.GREY)
    link.text:SetJustifyH("LEFT")
    link.text:ClearAllPoints(); link.text:SetPoint("LEFT", link.dot, "RIGHT", 5, 0)
    link:SetScript("OnClick", function() Shell.Open("setup") end)
    link:SetScript("OnEnter", S.ShowTooltip)
    link:SetScript("OnLeave", S.HideTooltip)
    window.link = link
    -- No pad: grey, beside the chip, while the game sees no pad
    window.noPad = S.Text(window, "No pad", 0, 0, 60, 11, S.DIM)
    window.noPad:ClearAllPoints()
    window.noPad:SetPoint("RIGHT", link, "LEFT", -8, 0)
    window.noPad:SetJustifyH("RIGHT")
    window.noPad:Hide()
    local padEvents = CreateFrame("Frame")
    for _, e in ipairs({ "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GAME_PAD_ACTIVE_CHANGED" }) do
        pcall(padEvents.RegisterEvent, padEvents, e)
    end
    padEvents:SetScript("OnEvent", function() Shell.RefreshLink() end)
    window.close = S.NewButton(window, "Close", 0, 0, 100, function() window:Hide() end)
    window.close:ClearAllPoints()
    window.close:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom + 6)

    window:SetScript("OnShow", function()
        if ns.ProfileMenu then ns.ProfileMenu.Refresh() end
        Shell.RefreshLink()
        -- (what happened to the profiles at login, once)
        local note = ns.Profiles and ns.Profiles.state.note
        if note then
            ns.Profiles.state.note = nil
            if C_Timer and C_Timer.After then C_Timer.After(0, function() Shell.SetStatus(note, true) end)
            else Shell.SetStatus(note, true) end
        end
        for _, def in ipairs(defs) do if def.windowShow then def.windowShow() end end
    end)
    window:SetScript("OnHide", function()
        local page = current and built[current]
        if page and page.def.hide then page.def.hide() end
        for _, def in ipairs(defs) do if def.windowHide then def.windowHide() end end
    end)
    UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionOptions"
    S.RegisterWindow(window)
    window:Hide()
end

-- Open on a page (default: the last one, else Controller)
function Shell.Open(key)
    if not window then Build() end
    Fit()
    if not window:IsShown() then window:Show() end
    window:Raise()
    -- (the last page, unless its tab is hidden now: Lab after an Edit)
    local last = current and Def(current)
    if not key and last and not Listed(last) then last = nil end
    Shell.Select(key or (last and last.key) or defs[1].key)
end

function Shell.Toggle(key)
    if window and window:IsShown() and (key == nil or key == current) then window:Hide(); return end
    Shell.Open(key)
end

-- Harness access
ns.ShellWindow = function() return window, tabs, built end

-- /gpc gestures, setup, lab: a page by its key
function API.OpenPage(key) Shell.Open(key) end
function API.IsOptionsShown() return Shell.IsShown() end
