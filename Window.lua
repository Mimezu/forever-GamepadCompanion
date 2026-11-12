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

local function Def(key)
    for _, def in ipairs(defs) do if def.key == key then return def end end
end

-- Status line, bottom left. A message from the player's last action stays a few seconds.
function Shell.SetStatus(text, sticky)
    if not window then return end
    local now = GetTime and GetTime() or 0
    if sticky then statusUntil = now + 5
    elseif statusUntil and now < statusUntil then return end
    window.status:SetText(text or "")
end

function Shell.Window() return window end
function Shell.Current() return current end
function Shell.IsShown(key) return window ~= nil and window:IsShown() and (key == nil or current == key) end

local function Fit()
    local tabW = 48
    local w, h = window:GetWidth() + tabW, window:GetHeight()
    window:SetScale(math.max(0.45, math.min(1, (UIParent:GetWidth() - 40) / w, (UIParent:GetHeight() - 40) / h)))
end

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
    local title = page.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 4, 0)
    title:SetText(def.name)
    page.title = title
    if def.sub then
        local sub = S.Text(page.header, def.sub, 0, 0, 600, 12, S.GREY)
        sub:ClearAllPoints()
        sub:SetPoint("LEFT", title, "RIGHT", 14, -1)
        page.sub = sub
    end
    local line = page.header:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 0, -2)
    line:SetSize(Shell.W, 1)
    line:SetColorTexture(0.68, 0.50, 0.26, 0.45)
    def.build(page.frame, page.header)
    built[key] = page
    return page
end

function Shell.Select(key)
    if not Def(key) then key = defs[1].key end
    local page = Page(key)
    for k, p in pairs(built) do
        local on = k == key
        if not on and p.frame:IsShown() and p.def.hide then p.def.hide() end
        p.frame:SetShown(on)
        p.header:SetShown(on)
    end
    for k, tab in pairs(tabs) do tab.selected:SetShown(k == key) end
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

local function Tab(def, index)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-sidetab")
    local tab = CreateFrame("Button", nil, window)
    tab:SetSize(info and info.width or 43, info and (info.height - 5) or 55)
    tab:SetScale(TAB_SCALE)
    local background = tab:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("common-sidetab", true)
    background:SetPoint("CENTER")
    local icon = tab:CreateTexture(nil, "ARTWORK")
    if def.atlas then icon:SetAtlas(def.atlas) else
        icon:SetTexture(def.icon)
        icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
    end
    icon:SetPoint("CENTER", -4, 0)
    local mask = tab.CreateMaskTexture and icon.AddMaskTexture and tab:CreateMaskTexture()
    if mask then
        icon:SetSize(50, 50)
        mask:SetAtlas("common-sidetab-mask", true)
        mask:SetPoint("CENTER")
        icon:AddMaskTexture(mask)
    else
        icon:SetSize(34, 34)
    end
    tab.selected = tab:CreateTexture(nil, "OVERLAY")
    tab.selected:SetAtlas("common-sidetab-selected", true)
    tab.selected:SetPoint("CENTER")
    tab.selected:Hide()
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
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(def.name, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    tab.def = def
    tabs[def.key] = tab
    return tab
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
    content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", inset.left, -inset.top)
    content:SetSize(Shell.W, HEADER + Shell.H)

    -- Side tabs, outside the right edge
    local anchor = window.chrome.border or window
    local previous
    for index, def in ipairs(defs) do
        local tab = Tab(def, index)
        if previous then tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
        else tab:SetPoint("TOPLEFT", window, "TOPRIGHT", -6 / TAB_SCALE, -52 / TAB_SCALE) end
        previous = tab
    end
    for _, def in ipairs(defs) do Page(def.key) end

    -- Footer: status, version, Close
    window.status = S.Note(window, inset.left + 2, -(inset.top + HEADER + Shell.H + 14), Shell.W - 300, 1, 12, S.GREY)
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    window.version = S.Text(window, type(version) == "string" and ("v" .. version) or "", 0, 0, 80, 11, S.DIM)
    window.version:ClearAllPoints()
    window.version:SetPoint("BOTTOMRIGHT", -(inset.right + 112), inset.bottom + 14)
    window.version:SetJustifyH("RIGHT")
    window.close = S.NewButton(window, "Close", 0, 0, 100, function() window:Hide() end)
    window.close:ClearAllPoints()
    window.close:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom + 6)

    window:SetScript("OnShow", function()
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
    Shell.Select(key or current or defs[1].key)
end

function Shell.Toggle(key)
    if window and window:IsShown() and (key == nil or key == current) then window:Hide(); return end
    Shell.Open(key)
end

-- Harness access
ns.ShellWindow = function() return window, tabs, built end
