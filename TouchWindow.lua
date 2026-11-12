-- The Touchpad window: turn zones on, pick the mode and grid, see the pad, and
-- put a window, spell, item, macro or typed macro on each zone and swipe.
-- Opened by /gpc touch and the options window's Touchpad button.
local _, ns = ...
local T, S = ns.TouchModel, ns.OptionsSkin
local API = GamepadCompanionAPI
local Touch = ns.Touch

local FONT = "Fonts\\FRIZQT__.TTF"
local BODY_W, BODY_H = 700, 476
local PAD_Y, PAD_W, PAD_H = -176, 380, 190
local RIGHT_X, RIGHT_W = 404, 296

local window, body
local ui = { tiles = {}, swipes = {}, windows = {}, layers = {}, modes = {} }
local selectedLayer, selectedZone = "base", "r1c1"
local Refresh

local function Settings() return Touch.Settings() end
local function Grid() local s = Settings(); return T.Grid(s, s.mode) end

-- Tiles ------------------------------------------------------------------------

local function Tile(parent, onClick)
    local tile = S.NewButton(parent, "", 0, 0, 80, nil, nil, 11, 60)
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetSize(26, 26)
    tile.icon:SetPoint("TOP", 0, -8)
    tile.label:ClearAllPoints()
    tile.label:SetPoint("BOTTOMLEFT", 4, 6)
    tile.label:SetPoint("BOTTOMRIGHT", -4, 6)
    tile:RegisterForClicks("LeftButtonUp")
    tile:SetScript("OnClick", onClick)
    tile:SetScript("OnReceiveDrag", onClick)
    return tile
end

local function ShowAction(tile, action, inherited)
    local label, icon, isAtlas = Touch.ActionLook(action)
    if icon then
        if isAtlas then tile.icon:SetAtlas(icon) else tile.icon:SetTexture(icon) end
        tile.icon:Show()
    else
        tile.icon:Hide()
    end
    tile.icon:SetAlpha(inherited and 0.4 or 1)
    return label
end

-- The action a zone runs on this layer, and whether it comes from Base
local function ActionOf(zone, layer)
    local s = Settings()
    local action = s.actions[s.mode][layer][zone]
    if (action == nil or action == "none") and layer ~= "base" then
        local base = s.actions[s.mode].base[zone]
        if base and base ~= "none" then return base, true end
    end
    if action == "none" then action = nil end
    return action, false
end

-- Put what the cursor holds on a zone; true when it did
local function Drop(zone)
    if not (GetCursorInfo and GetCursorInfo()) then return false end
    local action = Touch.TakeCursor()
    if not action then return false end
    Touch.SetZone(selectedLayer, zone, action)
    return true
end

local function Select(zone)
    selectedZone = zone
    Drop(zone)
    Refresh()
end

-- Layout -------------------------------------------------------------------

local function LayoutPad()
    local s = Settings()
    local grid, split = Grid(), s.mode == "split"
    local x0, w = 0, PAD_W
    if split then x0, w = PAD_W / 2 + 4, PAD_W / 2 - 4 end
    ui.native:SetShown(split)
    for _, tile in pairs(ui.tiles) do tile:Hide() end
    local cw, ch = w / grid.cols, PAD_H / grid.rows
    for _, zone in ipairs(T.Zones(s)) do
        local tile = ui.tiles[zone]
        if not tile then
            tile = Tile(ui.pad, function() Select(zone) end)
            ui.tiles[zone] = tile
        end
        local row, col = zone:match("^r(%d)c(%d)$")
        row, col = tonumber(row), tonumber(col)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", ui.pad, "TOPLEFT", x0 + (col - 1) * cw + 2, -(row - 1) * ch - 2)
        tile:SetSize(cw - 4, ch - 4)
        local action, inherited = ActionOf(zone, selectedLayer)
        local label = ShowAction(tile, action, inherited)
        tile.label:SetText(label or T.ZoneLabel(zone, grid))
        if not label then tile.label:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3]) end
        S.SetSelected(tile, zone == selectedZone)
        if label and inherited and zone ~= selectedZone then tile.label:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3]) end
        if action and not Touch.Runs(action) then tile.label:SetTextColor(1, 0.35, 0.3) end
        tile:Show()
    end
    for _, gesture in ipairs(T.GESTURES) do
        local tile = ui.swipes[gesture]
        local action, inherited = ActionOf(gesture, selectedLayer)
        ShowAction(tile, action, inherited)
        tile.label:SetText(T.GESTURE_LABELS[gesture])
        S.SetSelected(tile, gesture == selectedZone)
    end
end

local function RefreshBinder()
    local s = Settings()
    local grid = Grid()
    ui.binder.title:SetText(T.ZoneLabel(selectedZone, grid) .. " · " .. T.LAYER_LABELS[selectedLayer])
    local action, inherited = ActionOf(selectedZone, selectedLayer)
    local label, icon, isAtlas = Touch.ActionLook(action)
    if icon then
        if isAtlas then ui.current:SetAtlas(icon) else ui.current:SetTexture(icon) end
        ui.current:Show()
    else
        ui.current:Hide()
    end
    local missing = action and not Touch.Runs(action)
    ui.currentText:SetText(label and ((inherited and (label .. "  (Base)") or label) .. (missing and "  · not found" or ""))
        or "Empty")
    ui.clear:SetEnabled(not inherited and action ~= nil)
    for key, button in pairs(ui.windows) do
        S.SetSelected(button, not inherited and action == "window:" .. key)
    end
    local text = not inherited and action and action:match("^text:(.*)$") or ""
    if not ui.macro:HasFocus() then ui.macro:SetText(text) end
end

local function StatusText()
    local s, st = Settings(), Touch.Status()
    if not s.enabled then return "Off" end
    if st.padStyle ~= "Shapes" then return "No PlayStation pad" end
    if st.note then return st.note:sub(1, 1):upper() .. st.note:sub(2) end
    if Touch.IsPending() then return "Applies after combat" end
    if s.mode == "chord" then return st.ours and "On" or "On · a window has the pad" end
    return "On"
end

Refresh = function()
    if not window or not window:IsShown() then return end
    local s = Settings()
    local grid, limit = Grid(), T.GRID_LIMITS[s.mode]
    if not T.IsZone(s, s.mode, selectedZone) then selectedZone = "r1c1" end
    ui.enable:SetChecked(s.enabled)
    ui.preview:SetChecked(s.preview)
    ui.tap:SetChecked(s.tap)
    for mode, button in pairs(ui.modes) do S.SetSelected(button, mode == s.mode) end
    ui.modeNote:SetText(s.mode == "chord" and "L1 + touchpad: Blizzard's focus" or "Left half: Blizzard's focus")
    ui.cols:SetText(grid.cols .. (grid.cols == 1 and " column" or " columns"))
    ui.rows:SetText(grid.rows .. (grid.rows == 1 and " row" or " rows"))
    ui.colsMinus:SetEnabled(grid.cols > 1); ui.colsPlus:SetEnabled(grid.cols < limit.cols)
    ui.rowsMinus:SetEnabled(grid.rows > 1); ui.rowsPlus:SetEnabled(grid.rows < limit.rows)
    for layer, button in pairs(ui.layers) do S.SetSelected(button, layer == selectedLayer) end
    LayoutPad()
    RefreshBinder()
    ui.status:SetText(StatusText())
end

-- Build --------------------------------------------------------------------

local function Label(parent, text, x, y)
    return S.Text(parent, text, x, y - 6, nil, 12, S.GOLD)
end

local function Build()
    window = CreateFrame("Frame", "GamepadCompanionTouchpad", UIParent)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window.chrome = S.Chrome(window, "Gamepad Companion · Touchpad")
    body = CreateFrame("Frame", nil, window)
    body:SetSize(BODY_W, BODY_H)

    -- Left: the pad
    ui.enable = S.NewCheck(body, "Touchpad zones", -2, 0, function(self) Touch.SetEnabled(self:GetChecked() == true) end, 100)
    ui.tap = S.NewCheck(body, "Tap to click", 136, 0, function(self) Touch.SetTap(self:GetChecked() == true) end, 84)
    ui.preview = S.NewCheck(body, "Preview", 262, 0, function(self) Touch.SetPreview(self:GetChecked() == true) end, 60)
    S.Tooltip(ui.tap, "Tap to click", "Light touch presses the pad")

    Label(body, "Pad", 0, -40)
    ui.modes.chord = S.NewButton(body, "Whole pad", 70, -40, 150, function() Touch.SetMode("chord") end)
    ui.modes.split = S.NewButton(body, "Right half", 226, -40, 150, function() Touch.SetMode("split") end)
    ui.modeNote = S.Note(body, 72, -70, 300, 1, 11, S.GREY)

    Label(body, "Grid", 0, -96)
    local function Step(x, tip, dc, dr)
        local b = S.NewButton(body, dc + dr < 0 and "-" or "+", x, -96, 28, function()
            local g = Grid()
            Touch.SetGrid(g.cols + dc, g.rows + dr)
        end, nil, 14)
        S.Tooltip(b, tip)
        return b
    end
    ui.colsMinus = Step(70, "Fewer columns", -1, 0)
    ui.cols = S.Text(body, "", 104, -102, 82, 12, S.YELLOW)
    ui.cols:SetJustifyH("CENTER")
    ui.colsPlus = Step(190, "More columns", 1, 0)
    ui.rowsMinus = Step(226, "Fewer rows", 0, -1)
    ui.rows = S.Text(body, "", 260, -102, 82, 12, S.YELLOW)
    ui.rows:SetJustifyH("CENTER")
    ui.rowsPlus = Step(348, "More rows", 0, 1)

    Label(body, "Layer", 0, -134)
    for i, layer in ipairs(T.LAYERS) do
        ui.layers[layer] = S.NewButton(body, T.LAYER_LABELS[layer], 70 + (i - 1) * 78, -134, 72, function()
            selectedLayer = layer
            Refresh()
        end)
    end

    ui.pad = CreateFrame("Frame", nil, body)
    ui.pad:SetPoint("TOPLEFT", 0, PAD_Y)
    ui.pad:SetSize(PAD_W, PAD_H)
    local bg = ui.pad:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    ui.native = CreateFrame("Frame", nil, ui.pad)
    ui.native:SetPoint("TOPLEFT", 2, -2)
    ui.native:SetSize(PAD_W / 2 - 4, PAD_H - 4)
    local nbg = ui.native:CreateTexture(nil, "ARTWORK")
    nbg:SetAllPoints()
    nbg:SetColorTexture(0.25, 0.25, 0.3, 0.6)
    local ntext = S.Text(ui.native, "Blizzard", 0, 0, PAD_W / 2 - 4, 12, S.DIM)
    ntext:ClearAllPoints()
    ntext:SetPoint("CENTER")
    ntext:SetJustifyH("CENTER")

    for i, gesture in ipairs(T.GESTURES) do
        local tile = Tile(body, function() Select(gesture) end)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", (i - 1) * 96, PAD_Y - PAD_H - 8)
        tile:SetSize(92, 56)
        ui.swipes[gesture] = tile
    end
    ui.status = S.Note(body, 2, PAD_Y - PAD_H - 72, 380, 1, 11, S.GREY)

    -- Right: what the selected zone runs
    ui.binder = S.Card(body, " ", RIGHT_X, 0, RIGHT_W, BODY_H - 40)
    local card = ui.binder
    ui.current = card:CreateTexture(nil, "ARTWORK")
    ui.current:SetSize(30, 30)
    ui.current:SetPoint("TOPLEFT", 12, -40)
    ui.currentText = S.Text(card, "", 50, -48, 150, 12, S.GOLD)
    ui.currentText:SetWordWrap(false)
    ui.clear = S.NewButton(card, "Clear", RIGHT_W - 88, -42, 76, function()
        Touch.SetZone(selectedLayer, selectedZone, "none")
    end)

    local drop = S.NewButton(card, "Drop spell, item or macro", 12, -80, RIGHT_W - 24, nil, nil, 11, 34)
    local function DropHere() if Drop(selectedZone) then Refresh() end end
    drop:SetScript("OnClick", DropHere)
    drop:SetScript("OnReceiveDrag", DropHere)
    drop.label:SetTextColor(S.GREY[1], S.GREY[2], S.GREY[3])

    S.Text(card, "Windows", 12, -124, nil, 11, S.YELLOW)
    local colW = (RIGHT_W - 30) / 2
    for i, w in ipairs(T.WINDOWS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        ui.windows[w.key] = S.NewButton(card, w.label, 12 + col * (colW + 6), -142 - row * 28, colW, function()
            Touch.SetZone(selectedLayer, selectedZone, "window:" .. w.key)
        end, nil, 11, 24)
    end

    S.Text(card, "Macro", 12, -320, nil, 11, S.YELLOW)
    local box = CreateFrame("EditBox", nil, card, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 12, -338)
    box:SetSize(RIGHT_W - 24, 56)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(255)
    box:SetFont(FONT, 12, "")
    box:SetTextColor(1, 1, 1)
    box:SetTextInsets(6, 6, 6, 6)
    S.Edit(box)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ui.macro = box
    S.NewButton(card, "Save macro", RIGHT_W - 112, -400, 100, function()
        local text = (box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        box:ClearFocus()
        Touch.SetZone(selectedLayer, selectedZone, text ~= "" and ("text:" .. text) or "none")
    end)

    S.NewButton(body, "Close", BODY_W - 100, -(BODY_H - 30), 100, function() window:Hide() end)

    window:SetScript("OnShow", Refresh)
    local wait = 0
    window:SetScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.5
        ui.status:SetText(StatusText())
    end)
    Touch.OnChange(Refresh)
    UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionTouchpad"
    S.RegisterWindow(window)
    window:Hide()
end

local function ApplyStyle()
    window.chrome:SetKind(S.ChromeKind(S.CurrentStyle()))
    local inset = window.chrome:Insets()
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", inset.left, -inset.top)
    window:SetSize(BODY_W + inset.left + inset.right, BODY_H + inset.top + inset.bottom)
    S.Fit(window)
end

function API.ToggleTouchpad()
    if not window then Build() end
    if window:IsShown() then window:Hide(); return end
    ApplyStyle()
    window:Show()
    window:Raise()
end

-- Harness access
ns.TouchWindow = function() return window, ui end
