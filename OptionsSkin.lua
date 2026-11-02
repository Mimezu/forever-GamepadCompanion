local _, ns = ...
local S = {}
ns.OptionsSkin = S

local FONT = "Fonts\\FRIZQT__.TTF"
S.GOLD, S.YELLOW, S.GREY, S.DIM = { 0.94, 0.86, 0.69 }, { 1, 0.82, 0 }, { 0.78, 0.78, 0.78 }, { 0.62, 0.62, 0.62 }

-- Same standalone Forever atlas artwork as ForeverNames and BindCards.
local function Texture(frame, atlas, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetAtlas(atlas, true)
    return t
end

-- The smooth rail uses a center texel of the native atlas. Repeating the
-- entire ornamented edge produces the seams found during Frame Gambit QA.
local function Plate(frame, atlas, borderOnly)
    local art = { pieces = {} }
    function art:Update()
        local info = C_Texture.GetAtlasInfo(atlas)
        if not info then return end
        local w,h = frame:GetSize()
        if not w or not h or w <= 0 or h <= 0 then return end
        if self.w == w and self.h == h then return end
        self.w,self.h = w,h
        local x,y = math.min(5,w/2,info.width/2),math.min(5,h/2,info.height/2)
        local iw,ih = info.width,info.height
        local sections = {
            {0,0,x,y,0,0,x,y}, {w-x,0,x,y,iw-x,0,x,y},
            {0,h-y,x,y,0,ih-y,x,y}, {w-x,h-y,x,y,iw-x,ih-y,x,y},
            {x,0,w-2*x,y,math.floor(iw/2),0,1,y},
            {x,h-y,w-2*x,y,math.floor(iw/2),ih-y,1,y},
            {0,y,x,h-2*y,0,math.floor(ih/2),x,1},
            {w-x,y,x,h-2*y,iw-x,math.floor(ih/2),x,1},
            {x,y,w-2*x,h-2*y,x,y,iw-2*x,ih-2*y},
        }
        for i,p in ipairs(sections) do
            if borderOnly and i==9 then break end
            local t = self.pieces[i] or frame:CreateTexture(nil,borderOnly and "BORDER" or "BACKGROUND",nil,borderOnly and 1 or -2)
            self.pieces[i] = t
            t:SetTexture(info.file or info.filename)
            local du,dv = info.rightTexCoord-info.leftTexCoord,info.bottomTexCoord-info.topTexCoord
            t:SetTexCoord(info.leftTexCoord+du*p[5]/iw,info.leftTexCoord+du*(p[5]+p[7])/iw,
                info.topTexCoord+dv*p[6]/ih,info.topTexCoord+dv*(p[6]+p[8])/ih)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT",frame,"TOPLEFT",p[1],-p[2])
            t:SetSize(math.max(.01,p[3]),math.max(.01,p[4]))
            t:SetShown(self.visible ~= false)
        end
    end
    function art:SetShown(show)
        self.visible=show
        if show then self:Update() end
        for _,t in ipairs(self.pieces) do t:SetAlpha(1); t:SetShown(show) end
    end
    function art:Tint(color)
        for _,t in ipairs(self.pieces) do t:SetVertexColor(color[1],color[2],color[3],color[4] or 1) end
    end
    art:Update()
    return art
end
S.Plate = Plate

local function Leather(frame)
    local t = Texture(frame,"Legacy-Challenge-BG","BACKGROUND",-4)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT",3,-3); t:SetPoint("BOTTOMRIGHT",-3,3)
    local info = C_Texture.GetAtlasInfo("Legacy-Challenge-BG")
    if info then
        local du,dv=info.rightTexCoord-info.leftTexCoord,info.bottomTexCoord-info.topTexCoord
        t:SetTexture(info.file or info.filename)
        t:SetTexCoord(info.leftTexCoord+.05*du,info.rightTexCoord-.05*du,
            info.topTexCoord+.20*dv,info.bottomTexCoord-.02*dv)
    end
    return t
end

function S.Panel(frame)
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    local background=Leather(frame)
    local rim=Plate(frame,"common-button-list-collapseExpand",true)
    frame.legacyRim=rim
    frame:HookScript("OnSizeChanged",function() rim:Update() end)
    return background
end

function S.Button(button)
    -- GPC buttons have no template artwork; preserve their action scripts.
    local art=Plate(button,"common-button-list-collapseExpand")
    local hover=button:CreateTexture(nil,"HIGHLIGHT")
    hover:SetPoint("TOPLEFT",4,-4); hover:SetPoint("BOTTOMRIGHT",-4,4)
    hover:SetColorTexture(1,.7,.2,.12)
    local pressed=false
    local function Update()
        local shade=not button:IsEnabled() and .45 or pressed and .7 or 1
        art:Tint({shade,shade,shade,1})
    end
    button:HookScript("OnSizeChanged",function() art:Update() end)
    button:HookScript("OnMouseDown",function() pressed=true; Update() end)
    button:HookScript("OnMouseUp",function() pressed=false; Update() end)
    button:HookScript("OnHide",function() pressed=false; Update() end)
    button:HookScript("OnEnable",Update); button:HookScript("OnDisable",Update)
    return art
end

function S.Edit(frame)
    frame:SetBackdrop(nil)
    return Plate(frame, 'common-searchbar-a')
end

-- Widgets ------------------------------------------------------------------
-- Shared by the options, help and Edit Mode layout windows. Positions are
-- TOPLEFT offsets inside the parent.

function S.Text(parent, value, x, y, width, size, color)
    local font = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    font:SetFont(FONT, size or 12, "")
    font:SetPoint("TOPLEFT", x, y)
    if width then font:SetWidth(width) end
    font:SetJustifyH("LEFT")
    color = color or S.GOLD
    font:SetTextColor(color[1], color[2], color[3])
    font:SetText(value or "")
    return font
end

-- A one- or two-line note with a fixed box, so a long message wraps inside
-- its own space instead of running into the next control.
function S.Note(parent, x, y, width, lines, size, color)
    local font = S.Text(parent, "", x, y, width, size or 11, color or S.GREY)
    font:SetHeight(math.ceil((size or 11) * 1.25 * (lines or 2)))
    font:SetJustifyV("TOP")
    if font.SetMaxLines then font:SetMaxLines(lines or 2) end
    return font
end

function S.Tooltip(frame, title, body)
    frame.tipTitle, frame.tipBody = title, body
end

function S.ShowTooltip(self)
    if not self.tipTitle or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tipTitle, 1, 0.82, 0)
    if self.tipBody then GameTooltip:AddLine(self.tipBody, 1, 1, 1, true) end
    GameTooltip:Show()
end

function S.HideTooltip(self)
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

local function LabelColor(button)
    local label = button.label
    if not label then return end
    if not button:IsEnabled() then label:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    elseif button.selected then label:SetTextColor(S.YELLOW[1], S.YELLOW[2], S.YELLOW[3])
    else label:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3]) end
end

-- Plate button. The label is anchored to both sides, so it stays centred at
-- any height and is cut short instead of spilling past the edge.
function S.NewButton(parent, label, x, y, width, action, template, size, height)
    local button = CreateFrame("Button", nil, parent, template and ("BackdropTemplate," .. template) or "BackdropTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, height or 26)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetFont(FONT, size or 12, "")
    button.label:SetPoint("LEFT", 5, 0)
    button.label:SetPoint("RIGHT", -5, 0)
    button.label:SetJustifyH("CENTER")
    button.label:SetWordWrap(false)
    button.label:SetText(label)
    S.Button(button)
    button.selection = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    button.selection:SetPoint("TOPLEFT", 4, -4)
    button.selection:SetPoint("BOTTOMRIGHT", -4, 4)
    button.selection:SetColorTexture(1, 0.72, 0.2, 0.2)
    button.selection:Hide()
    button:SetScript("OnEnter", S.ShowTooltip)
    button:SetScript("OnLeave", S.HideTooltip)
    button:HookScript("OnEnable", LabelColor)
    button:HookScript("OnDisable", LabelColor)
    if action then button:SetScript("OnClick", action) end
    LabelColor(button)
    return button
end

function S.SetSelected(button, value)
    button.selected = value == true
    if button.selection then button.selection:SetShown(button.selected) end
    LabelColor(button)
end

-- Native check box with a gold label; the label is part of the click area.
function S.NewCheck(parent, label, x, y, onClick, labelWidth)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", x, y)
    local text = type(check.Text) == "table" and check.Text or check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:ClearAllPoints()
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    text:SetFont(FONT, 12, "")
    text:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
    text:SetText(label)
    check.label = text
    if check.SetHitRectInsets then check:SetHitRectInsets(0, -(labelWidth or 80), 0, 0) end
    check:SetScript("OnClick", onClick)
    check:SetScript("OnEnter", S.ShowTooltip)
    check:SetScript("OnLeave", S.HideTooltip)
    return check
end

-- Section heading for the classic look: gold caps and a thin rule.
function S.Heading(parent, value, x, y, width)
    local label = S.Text(parent, value, x + 4, y, width, 11, S.YELLOW)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(1, 0.82, 0, 0.18)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", x, y - 16)
    rule:SetWidth(width)
    return label
end

-- Card for the Legacy looks, matching Forever Names: a warm wash, hairline
-- edges and a title band.
function S.Card(parent, title, x, y, width, height)
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, height)
    local wash = card:CreateTexture(nil, "BACKGROUND", nil, -2)
    wash:SetAllPoints()
    wash:SetColorTexture(0.25, 0.17, 0.085, 0.16)
    local function Line(lx, ly, lw, lh, alpha)
        local line = card:CreateTexture(nil, "BORDER")
        line:SetPoint("TOPLEFT", lx, ly)
        line:SetSize(lw, lh)
        line:SetColorTexture(0.68, 0.50, 0.26, alpha)
        return line
    end
    Line(0, 0, width, 1, 0.55); Line(0, -height + 1, width, 1, 0.3)
    Line(0, 0, 1, height, 0.3); Line(width - 1, 0, 1, height, 0.3)
    if title then
        card.title = S.Text(card, title, 12, -10, width - 24, 12, S.YELLOW)
        Line(10, -30, width - 20, 1, 0.25)
    end
    return card
end

-- Opt into Frame Gambit's Cinematic suite windows, so an open window is not
-- blacked out with the HUD. Works whichever addon loaded first.
function S.RegisterWindow(frame)
    local api = _G.FrameGambitAPI
    if api and type(api.RegisterCinematicWindow) == "function" then pcall(api.RegisterCinematicWindow, frame) end
end

-- Window chrome ------------------------------------------------------------
-- "classic" is Gamepad Companion's own leather header; "legacy" is the
-- Forever Names / Petal / Halo window (native NineSlice border, centred title).
-- Content belongs in a child frame placed with chrome:Insets().
local insets = {
    classic = { left = 20, top = 62, right = 20, bottom = 16 },
    legacy = { left = 26, top = 44, right = 22, bottom = 14 },
}

function S.Chrome(frame, title, onClose)
    local chrome = { kind = nil }
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    local leather = Leather(frame)
    local rim = Plate(frame, "common-button-list-collapseExpand", true)
    frame:HookScript("OnSizeChanged", function() rim:Update() end)
    local function Close()
        if onClose then onClose() else frame:Hide() end
    end
    local function Drag(handle)
        handle:EnableMouse(true)
        handle:RegisterForDrag("LeftButton")
        handle:SetScript("OnDragStart", function() frame:StartMoving() end)
        handle:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    end

    -- Classic: leather header plate, left title, close button centred in it.
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetHeight(42)
    S.Panel(header)
    Drag(header)
    local classicTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classicTitle:SetFont(FONT, 15, "")
    classicTitle:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
    classicTitle:SetPoint("LEFT", 16, 0)
    classicTitle:SetPoint("RIGHT", -44, 0)
    classicTitle:SetJustifyH("LEFT")
    classicTitle:SetWordWrap(false)
    local classicClose = CreateFrame("Button", nil, header, "UIPanelCloseButtonNoScripts")
    classicClose:SetSize(24, 24)
    classicClose:SetPoint("RIGHT", -9, 0)
    classicClose:SetScript("OnClick", Close)

    -- Legacy: the Forever Names window. Its NineSlice border has external
    -- offsets; keep the leather inside the visible metal.
    local legacy = CreateFrame("Frame", nil, frame)
    legacy:SetAllPoints(frame)
    legacy:SetFrameLevel((frame:GetFrameLevel() or 0) + 1)
    local border = CreateFrame("Frame", nil, legacy)
    border:SetPoint("TOPLEFT", 8, -16)
    border:SetPoint("BOTTOMRIGHT", -4, 3)
    border:EnableMouse(false)
    local hasBorder = NineSliceUtil and NineSliceUtil.ApplyLayoutByName
        and pcall(NineSliceUtil.ApplyLayoutByName, border, "ButtonFrameTemplateNoPortrait")
    local top = CreateFrame("Frame", nil, legacy)
    top:SetAllPoints(frame)
    top:SetFrameLevel((legacy:GetFrameLevel() or 0) + 2)
    top:EnableMouse(false)
    local titleArea = CreateFrame("Frame", nil, top)
    titleArea:SetPoint("TOPLEFT", border, "TOPLEFT", 30, -1)
    titleArea:SetPoint("TOPRIGHT", border, "TOPRIGHT", -24, -1)
    titleArea:SetHeight(20)
    titleArea:EnableMouse(false)
    local legacyTitle = titleArea:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    legacyTitle:SetPoint("CENTER")
    legacyTitle:SetWordWrap(false)
    local legacyClose = CreateFrame("Button", nil, top, "UIPanelCloseButtonNoScripts")
    legacyClose:SetSize(24, 24)
    -- Forever's UIPanelCloseButtonDefaultAnchorsMixin uses (-2, 1).
    legacyClose:SetPoint("TOPRIGHT", border, "TOPRIGHT", -2, 1)
    legacyClose:SetScript("OnClick", Close)
    local drag = CreateFrame("Frame", nil, top)
    drag:SetPoint("TOPLEFT", border, "TOPLEFT", 0, -1)
    drag:SetPoint("TOPRIGHT", legacyClose, "TOPLEFT", -4, -2)
    drag:SetHeight(20)
    Drag(drag)

    function chrome:SetTitle(text)
        classicTitle:SetText(text)
        -- The centred Legacy title has no room for a coloured version tag.
        legacyTitle:SetText(((text or ""):gsub("%s*|c%x%x%x%x%x%x%x%x.-|r", "")))
    end
    function chrome:SetKind(kind)
        kind = kind == "legacy" and hasBorder and "legacy" or "classic"
        self.kind = kind
        local classic = kind == "classic"
        header:SetShown(classic)
        rim:SetShown(classic)
        legacy:SetShown(not classic)
        leather:ClearAllPoints()
        if classic then
            leather:SetPoint("TOPLEFT", 3, -3); leather:SetPoint("BOTTOMRIGHT", -3, 3)
        else
            leather:SetPoint("TOPLEFT", 12, -13); leather:SetPoint("BOTTOMRIGHT", -6, 6)
        end
    end
    function chrome:Insets() return insets[self.kind or "classic"] end
    chrome.header = header
    chrome:SetTitle(title)
    chrome:SetKind("classic")
    return chrome
end

-- Fit a window on small screens without ever enlarging it.
function S.Fit(frame)
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then return end
    frame:SetScale(math.max(0.5, math.min(1, (UIParent:GetWidth() - 30) / width, (UIParent:GetHeight() - 30) / height)))
end

-- A (controller) and B use the Legacy chrome; C is the classic look.
function S.ChromeKind(style)
    return style == "C" and "classic" or "legacy"
end

function S.CurrentStyle()
    local api = _G.GamepadCompanionAPI
    local ok, settings = pcall(function() return api and api.GetSettings and api.GetSettings() end)
    local style = ok and type(settings) == "table" and settings.optionsStyle
    return (style == "B" or style == "C") and style or "A"
end
