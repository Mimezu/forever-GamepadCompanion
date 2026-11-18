local _, ns = ...
local S = {}
ns.OptionsSkin = S

local FONT = "Fonts\\FRIZQT__.TTF"
S.GOLD, S.YELLOW, S.GREY, S.DIM = { 0.94, 0.86, 0.69 }, { 1, 0.82, 0 }, { 0.78, 0.78, 0.78 }, { 0.62, 0.62, 0.62 }

-- A gradient on a plain texture (start = left or bottom); the end colour
-- alone where the client has no gradients
function S.Gradient(tex, orient, a, b)
    tex:SetColorTexture(1, 1, 1, 1)
    if tex.SetGradient and type(CreateColor) == "function" then
        local ok = pcall(tex.SetGradient, tex, orient, CreateColor(a[1], a[2], a[3], a[4] or 1), CreateColor(b[1], b[2], b[3], b[4] or 1))
        if ok then return end
    end
    tex:SetColorTexture(b[1], b[2], b[3], b[4] or 1)
end

-- A short fade-in (a page, a popup, the status): one AnimationGroup, made once
function S.FadeIn(region, duration)
    if not (region and type(region.CreateAnimationGroup) == "function") then return end
    local ag = rawget(region, "gpcFade")
    if type(ag) ~= "table" then
        ag = region:CreateAnimationGroup()
        if type(ag) ~= "table" or type(ag.CreateAnimation) ~= "function" then return end
        local a = ag:CreateAnimation("Alpha")
        if type(a) ~= "table" or type(a.SetFromAlpha) ~= "function" then return end
        a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(duration or 0.12)
        if a.SetSmoothing then a:SetSmoothing("OUT") end
        region.gpcFade = ag
    end
    ag:Stop(); ag:Play()
end

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

-- A label cut short shows in full (a 40-letter spell on a 136 px plate)
local function Cut(fs)
    return fs and fs.IsTruncated and fs:IsTruncated() and fs:GetText() or nil
end
S.Cut = Cut

function S.ShowTooltip(self)
    if not GameTooltip then return end
    local full = Cut(self.label)
    if not self.tipTitle and not full then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(full or self.tipTitle, 1, 0.82, 0)
    if full and self.tipTitle and self.tipTitle ~= full then GameTooltip:AddLine(self.tipTitle, 1, 1, 1, true) end
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
    local underline = rawget(button, "underline")
    if underline then underline:SetShown(button.selected) end
    LabelColor(button)
end

-- Native check box with a gold label; the label is part of the click area.
-- On / off as a switch (a track, a knob), its label to the right; still a
-- CheckButton, so clicks, keys and GetChecked work as before.
local TRACK_OFF, RIM = { 0.18, 0.15, 0.11, 1 }, { 0.68, 0.5, 0.26, 0.6 }
function S.NewCheck(parent, label, x, y, onClick, labelWidth)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(34, 26)
    check:SetPoint("TOPLEFT", x, y)
    -- (the template's box and tick hidden: the switch draws itself)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
        local t = check[get] and check[get](check)
        if t and t.SetAlpha then t:SetAlpha(0) end
    end
    -- (a capsule: a middle and two round caps, so the track's ends are round)
    local function Round(tex)
        if check.CreateMaskTexture and tex.AddMaskTexture then
            local mask = check:CreateMaskTexture()
            if mask then mask:SetAtlas("CircleMask"); mask:SetAllPoints(tex); tex:AddMaskTexture(mask) end
        end
        return tex
    end
    local function Capsule(layer, sub)
        return { mid = check:CreateTexture(nil, layer, nil, sub), a = Round(check:CreateTexture(nil, layer, nil, sub)),
            b = Round(check:CreateTexture(nil, layer, nil, sub)) }
    end
    local rim, track = Capsule("BACKGROUND", 0), Capsule("BORDER", 0)
    local knob = Round(check:CreateTexture(nil, "ARTWORK"))
    knob:SetColorTexture(0.95, 0.9, 0.8, 1)
    local travel = 19
    local function Place(cap, x, w, h)
        cap.a:ClearAllPoints(); cap.a:SetPoint("LEFT", x, 0); cap.a:SetSize(h, h)
        cap.b:ClearAllPoints(); cap.b:SetPoint("LEFT", x + w - h, 0); cap.b:SetSize(h, h)
        cap.mid:ClearAllPoints(); cap.mid:SetPoint("LEFT", x + h / 2, 0); cap.mid:SetSize(math.max(1, w - h), h)
    end
    local function Paint(cap, a, b)
        for _, t in pairs(cap) do
            if b then S.Gradient(t, "VERTICAL", a, b) else t:SetColorTexture(a[1], a[2], a[3], a[4]) end
        end
    end
    local function Layout()
        local compact = (check:GetWidth() or 34) < 30
        local w, h = compact and 26 or 34, compact and 14 or 16
        Place(rim, 0, w, h)
        Place(track, 1, w - 2, h - 2)
        knob:SetSize(h - 4, h - 4)
        travel = w - h
    end
    Paint(rim, RIM)
    local function Update()
        local on = check:GetChecked() and true or false
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", check, "LEFT", 2 + (on and travel or 0), 0)
        if on then Paint(track, { 0.7, 0.45, 0.1, 1 }, { 1, 0.78, 0.25, 1 }) else Paint(track, TRACK_OFF) end
        check:SetAlpha(check:IsEnabled() and 1 or 0.45)
    end
    Layout()
    check.UpdateSwitch = Update
    local set = check.SetChecked
    check.SetChecked = function(self, v) set(self, v); Update() end
    local text = type(check.Text) == "table" and check.Text or check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:ClearAllPoints()
    text:SetPoint("LEFT", check, "RIGHT", 6, 0)
    text:SetFont(FONT, 12, "")
    text:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
    text:SetText(label)
    check.label = text
    if check.SetHitRectInsets then check:SetHitRectInsets(0, -(labelWidth or 80), 0, 0) end
    check:SetScript("OnClick", function(self, ...)
        if onClick then onClick(self, ...) end
        Update()
    end)
    check:SetScript("OnEnter", S.ShowTooltip)
    check:SetScript("OnLeave", S.HideTooltip)
    if check.HookScript then
        check:HookScript("OnEnable", Update)
        check:HookScript("OnDisable", Update)
        check:HookScript("OnSizeChanged", function() Layout(); Update() end)
    end
    Update()
    return check
end

-- One segment of a joined control (S.Segments): no plate of its own, a
-- warm fill and an underline when selected; works with S.SetSelected.
function S.Segment(parent, label, x, y, width, action, size, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(width, height or 26)
    b.selection = b:CreateTexture(nil, "BACKGROUND")
    b.selection:SetAllPoints()
    S.Gradient(b.selection, "VERTICAL", { 0.6, 0.4, 0.1, 0.2 }, { 1, 0.82, 0.3, 0.35 })
    b.selection:Hide()
    b.underline = b:CreateTexture(nil, "ARTWORK")
    b.underline:SetPoint("BOTTOMLEFT", 3, 1); b.underline:SetPoint("BOTTOMRIGHT", -3, 1)
    b.underline:SetHeight(2)
    b.underline:SetColorTexture(S.YELLOW[1], S.YELLOW[2], S.YELLOW[3], 0.9)
    b.underline:Hide()
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(); hover:SetColorTexture(1, 0.7, 0.2, 0.08)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetFont(FONT, size or 12, "")
    b.label:SetPoint("LEFT", 4, 0); b.label:SetPoint("RIGHT", -4, 0)
    b.label:SetJustifyH("CENTER")
    b.label:SetWordWrap(false)
    b.label:SetText(label)
    b:SetScript("OnMouseDown", function() b.label:SetPoint("LEFT", 5, -1); b.label:SetPoint("RIGHT", -3, -1) end)
    b:SetScript("OnMouseUp", function() b.label:SetPoint("LEFT", 4, 0); b.label:SetPoint("RIGHT", -4, 0) end)
    b:SetScript("OnEnter", S.ShowTooltip)
    b:SetScript("OnLeave", S.HideTooltip)
    if b.HookScript then b:HookScript("OnEnable", LabelColor); b:HookScript("OnDisable", LabelColor) end
    if action then b:SetScript("OnClick", action) end
    b.segment = true
    LabelColor(b)
    return b
end

-- The well a row of segments sits in: one dark track, a rim, dividers
function S.Segments(parent, x, y, widths, height)
    local well = CreateFrame("Frame", nil, parent)
    well:SetPoint("TOPLEFT", x, y)
    local total = 0
    for _, w in ipairs(widths) do total = total + w end
    well:SetSize(total + 2, (height or 26) + 2)
    local bg = well:CreateTexture(nil, "BACKGROUND", nil, -3)
    bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.35)
    local rim = Plate(well, "common-button-list-collapseExpand", true)
    rim:Tint({ 0.85, 0.85, 0.85, 0.7 })
    local at = 1
    for i = 1, #widths - 1 do
        at = at + widths[i]
        local d = well:CreateTexture(nil, "BORDER")
        d:SetPoint("TOPLEFT", at, -4); d:SetSize(1, (height or 26) - 6)
        d:SetColorTexture(0.68, 0.5, 0.26, 0.35)
    end
    return well
end

-- Section heading for the classic look: gold caps and a thin rule.
function S.Heading(parent, value, x, y, width)
    local label = S.Text(parent, value, x + 4, y, width, 11, S.YELLOW)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    S.Gradient(rule, "HORIZONTAL", { 1, 0.82, 0, 0.45 }, { 1, 0.82, 0, 0 })
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", x, y - 16)
    rule:SetWidth(width)
    return label
end

-- Card for the Legacy looks, matching Forever Names: a warm wash, hairline
-- edges and a title band.
function S.Card(parent, title, x, y, width, height, icon)
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, height)
    local wash = card:CreateTexture(nil, "BACKGROUND", nil, -2)
    wash:SetAllPoints()
    -- (deeper toward the foot)
    S.Gradient(wash, "VERTICAL", { 0.16, 0.11, 0.05, 0.22 }, { 0.25, 0.17, 0.085, 0.14 })
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
        -- a warm title band, a soft shadow under it, an icon before the title
        local band = card:CreateTexture(nil, "BACKGROUND", nil, -1)
        band:SetPoint("TOPLEFT", 1, -1); band:SetPoint("TOPRIGHT", -1, -1); band:SetHeight(29)
        S.Gradient(band, "VERTICAL", { 0.35, 0.24, 0.1, 0 }, { 0.35, 0.24, 0.1, 0.35 })
        local shade = card:CreateTexture(nil, "BACKGROUND", nil, -1)
        shade:SetPoint("TOPLEFT", 1, -31); shade:SetPoint("TOPRIGHT", -1, -31); shade:SetHeight(6)
        S.Gradient(shade, "VERTICAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.25 })
        local tx = 12
        if icon then
            card.icon = card:CreateTexture(nil, "ARTWORK")
            card.icon:SetSize(16, 16); card.icon:SetPoint("TOPLEFT", 10, -8)
            card.icon:SetTexture(icon)
            if card.icon.SetTexCoord then card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
            card.icon:SetAlpha(0.85)
            local rim = card:CreateTexture(nil, "BORDER")
            rim:SetPoint("TOPLEFT", card.icon, "TOPLEFT", -1, 1); rim:SetPoint("BOTTOMRIGHT", card.icon, "BOTTOMRIGHT", 1, -1)
            rim:SetColorTexture(0.68, 0.5, 0.26, 0.6)
            tx = 32
        end
        card.title = S.Text(card, title, tx, -10, width - tx - 12, 12, S.YELLOW)
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
    legacyClose:SetSize(28, 28)
    -- Forever's UIPanelCloseButtonDefaultAnchorsMixin: 28 px at (0, 3) since build 70532 (24 px at (-2, 1) before).
    legacyClose:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 3)
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
