-- The picker: a popup to choose what a button, bar slot or touchpad zone runs,
-- without dragging. Categories on the left (the spellbook's lines, usable
-- items, macros, Halo rings, windows, a typed macro), a search box and an
-- icon grid. Picker.Open{ title, accepts, current, onPick }.
-- Actions use the touchpad's format: spell:<id>, item:<id>, macro:<name>,
-- window:<key>, halo:<ring id>, text:<macro text>.
local _, ns = ...
local S, T, Sh = ns.OptionsSkin, ns.TouchModel, ns.Shared
local Picker = {}
ns.Picker = Picker

local FONT = "Fonts\\FRIZQT__.TTF"
local BODY_W, BODY_H = 640, 440
local LEFT_W = 156
local COLS, ROWS, TILE_W, TILE_H, GAP = 6, 4, 72, 82, 6
local GRID_X = LEFT_W + 14

local window, body
local ui = { cats = {}, tiles = {} }
local request          -- the open request
local category, query, offset = nil, "", 0
local entries = {}     -- the category's entries, after the search

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

-- Sources --------------------------------------------------------------------------

local function SpellLines()
    local lines = {}
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    if book and book.GetNumSpellBookSkillLines then
        for i = 1, Call(book.GetNumSpellBookSkillLines) or 0 do
            local info = Call(book.GetSpellBookSkillLineInfo, i)
            if info and not info.shouldHide then
                local list = {}
                for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = Call(book.GetSpellBookItemInfo, slot, bank)
                    if item and item.itemType == spellType and not item.isPassive and not item.isOffSpec then
                        local id = item.spellID or item.actionID
                        list[#list + 1] = { action = "spell:" .. id, name = item.name, icon = item.iconID, spell = id }
                    end
                end
                if #list > 0 then lines[#lines + 1] = { name = info.name, icon = info.iconID, list = list } end
            end
        end
        return lines
    end
    -- (older spellbook API)
    for i = 1, Call(GetNumSpellTabs) or 0 do
        local name, icon, first, count = Call(GetSpellTabInfo, i)
        local list = {}
        for slot = (first or 0) + 1, (first or 0) + (count or 0) do
            local kind, id = Call(GetSpellBookItemInfo, slot, "spell")
            if kind == "SPELL" and not Call(IsPassiveSpell, slot, "spell") then
                local spellName = Call(GetSpellBookItemName, slot, "spell")
                list[#list + 1] = { action = "spell:" .. id, name = spellName or tostring(id),
                    icon = Call(GetSpellBookItemTexture, slot, "spell"), spell = id }
            end
        end
        if #list > 0 then lines[#lines + 1] = { name = name, icon = icon, list = list } end
    end
    return lines
end

local function ItemName(id)
    return Call(C_Item and C_Item.GetItemNameByID, id) or Call(GetItemInfo, id)
end

local function Usable(id)
    return (Call(C_Item and C_Item.GetItemSpell, id) or Call(GetItemSpell, id)) ~= nil
end

local function Items()
    local list, seen = {}, {}
    local function Add(id, icon)
        if not id or seen[id] or not Usable(id) then return end
        seen[id] = true
        list[#list + 1] = { action = "item:" .. id, name = ItemName(id) or ("Item " .. id), icon = icon, item = id }
    end
    for _, slot in ipairs({ 13, 14 }) do   -- trinkets
        local id = Call(GetInventoryItemID, "player", slot)
        if id then Add(id, Call(GetInventoryItemTexture, "player", slot)) end
    end
    local container = C_Container
    for bag = 0, _G.NUM_BAG_SLOTS or 4 do
        local slots = Call(container and container.GetContainerNumSlots or GetContainerNumSlots, bag) or 0
        for slot = 1, slots do
            local info = Call(container and container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" then Add(info.itemID, info.iconFileID) end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function Macros()
    local list = {}
    local global, char = Call(GetNumMacros)
    local function Add(index)
        local name, icon = Call(GetMacroInfo, index)
        if name then list[#list + 1] = { action = "macro:" .. name, name = name, icon = icon, macro = index } end
    end
    for i = 1, global or 0 do Add(i) end
    local first = (_G.MAX_ACCOUNT_MACROS or 120) + 1
    for i = first, first + (char or 0) - 1 do Add(i) end
    return list
end

local function Windows()
    local list = {}
    for _, w in ipairs(T.WINDOWS) do
        local action = "window:" .. w.key
        local name, icon, atlas = ns.Touch.ActionLook(action)
        list[#list + 1] = { action = action, name = name or w.label, icon = icon, atlas = atlas }
    end
    return list
end

local function Rings()
    local list = {}
    for _, ring in ipairs(Sh.HaloRings()) do
        list[#list + 1] = { action = "halo:" .. ring.id, name = ring.name or ("Ring " .. ring.id), icon = Sh.HaloIcon(ring) }
    end
    return list
end

-- The categories this request can use
local function Categories()
    local cats, accepts = {}, request.accepts
    if accepts.spell then
        for _, line in ipairs(SpellLines()) do
            cats[#cats + 1] = { key = "spells:" .. line.name, label = line.name, icon = line.icon, list = line.list, group = "Spells" }
        end
    end
    if accepts.item then cats[#cats + 1] = { key = "items", label = "Items", list = Items(), group = "More" } end
    if accepts.macro then cats[#cats + 1] = { key = "macros", label = "Macros", list = Macros(), group = "More" } end
    if accepts.halo then
        local rings = Rings()
        if #rings > 0 then cats[#cats + 1] = { key = "halo", label = "Halo rings", list = rings, group = "More" } end
    end
    if accepts.window then cats[#cats + 1] = { key = "windows", label = "Windows", list = Windows(), group = "More" } end
    if accepts.text then cats[#cats + 1] = { key = "text", label = "Typed macro", text = true, group = "More" } end
    return cats
end
Picker.Categories = function(req) local old = request; request = req; local c = Categories(); request = old; return c end

-- Layout ---------------------------------------------------------------------------

local Refresh

local function Pick(action)
    local req = request
    window:Hide()
    if req and req.onPick then req.onPick(action) end
end

local function Tile(index)
    if ui.tiles[index] then return ui.tiles[index] end
    local col, row = (index - 1) % COLS, math.floor((index - 1) / COLS)
    local t = CreateFrame("Button", nil, ui.grid)
    t:SetSize(TILE_W, TILE_H)
    t:SetPoint("TOPLEFT", col * (TILE_W + GAP), -row * (TILE_H + GAP))
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.bg:SetColorTexture(1, 0.85, 0.55, 0.05)
    t.selection = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    t.selection:SetAllPoints()
    t.selection:SetColorTexture(1, 0.72, 0.2, 0.22)
    t.selection:Hide()
    local hover = t:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.75, 0.3, 0.16)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(40, 40)
    t.icon:SetPoint("TOP", 0, -6)
    t.rim = t:CreateTexture(nil, "OVERLAY")
    t.rim:SetPoint("TOPLEFT", t.icon, "TOPLEFT", -2, 2)
    t.rim:SetPoint("BOTTOMRIGHT", t.icon, "BOTTOMRIGHT", 2, -2)
    t.rim:SetColorTexture(0, 0, 0, 0)
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.label:SetFont(FONT, 10, "")
    t.label:SetPoint("TOPLEFT", 3, -50)
    t.label:SetPoint("TOPRIGHT", -3, -50)
    t.label:SetHeight(28)
    t.label:SetJustifyH("CENTER")
    t.label:SetJustifyV("TOP")
    t.label:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
    t:RegisterForClicks("LeftButtonUp")
    t:SetScript("OnClick", function(self) if self.entry then Pick(self.entry.action) end end)
    t:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if e.spell and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(e.spell)
        elseif e.item and GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.item)
        else
            GameTooltip:SetText(e.name, 1, 0.82, 0)
            if e.macro then
                local _, _, macroBody = Call(GetMacroInfo, e.macro)
                if macroBody then GameTooltip:AddLine(macroBody, 1, 1, 1, true) end
            end
        end
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    ui.tiles[index] = t
    return t
end

local function Matches(entry)
    if query == "" then return true end
    return (entry.name or ""):lower():find(query, 1, true) ~= nil
end

local function Filtered()
    wipe(entries)
    if query ~= "" then
        -- (searching looks in every category)
        local seen = {}
        for _, cat in ipairs(ui.categories) do
            for _, e in ipairs(cat.list or {}) do
                if Matches(e) and not seen[e.action] then seen[e.action] = true; entries[#entries + 1] = e end
            end
        end
        return
    end
    for _, e in ipairs(category and category.list or {}) do entries[#entries + 1] = e end
end

Refresh = function()
    if not window or not window:IsShown() then return end
    for key, b in pairs(ui.cats) do S.SetSelected(b, query == "" and category and category.key == key) end
    local typed = query == "" and category and category.text
    ui.grid:SetShown(not typed)
    ui.textPane:SetShown(typed and true or false)
    ui.pageText:SetShown(not typed)
    ui.prev:SetShown(not typed)
    ui.next:SetShown(not typed)
    if typed then
        ui.heading:SetText("Typed macro")
        return
    end
    Filtered()
    local per = COLS * ROWS
    if offset >= #entries then offset = math.max(0, math.floor((#entries - 1) / per) * per) end
    for i = 1, per do
        local t = Tile(i)
        local e = entries[offset + i]
        t.entry = e
        if e then
            if e.atlas then t.icon:SetAtlas(e.icon) else t.icon:SetTexture(e.icon or 134400) end
            t.label:SetText(e.name or "")
            t.selection:SetShown(request.current == e.action)
            t:Show()
        else
            t:Hide()
        end
    end
    ui.heading:SetText(query ~= "" and ("Search: " .. query) or (category and category.label or ""))
    ui.empty:SetShown(#entries == 0)
    ui.pageText:SetText(#entries > per and ("%d–%d of %d"):format(offset + 1, math.min(offset + per, #entries), #entries)
        or (#entries > 0 and tostring(#entries) or ""))
    ui.prev:SetEnabled(offset > 0)
    ui.next:SetEnabled(offset + per < #entries)
end

local function Page(delta)
    local per = COLS * ROWS
    local nextOffset = offset + delta * per
    if nextOffset < 0 or nextOffset >= #entries then return end
    offset = nextOffset
    Refresh()
end

local function LayoutCategories()
    for _, b in pairs(ui.cats) do b:Hide() end
    for _, h in ipairs(ui.groups or {}) do h:Hide() end
    ui.groups = ui.groups or {}
    local y, lastGroup, g = 0, nil, 0
    for _, cat in ipairs(ui.categories) do
        if cat.group ~= lastGroup then
            lastGroup = cat.group
            g = g + 1
            local h = ui.groups[g] or S.Text(ui.left, "", 2, 0, LEFT_W, 11, S.YELLOW)
            ui.groups[g] = h
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 2, y - 4)
            h:SetText(cat.group)
            h:Show()
            y = y - 22
        end
        local b = ui.cats[cat.key]
        if not b then
            b = S.NewButton(ui.left, cat.label, 0, 0, LEFT_W, nil, nil, 11, 24)
            ui.cats[cat.key] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, y)
        b.label:SetText(cat.label)
        b:SetScript("OnClick", function()
            category, offset, query = cat, 0, ""
            ui.search:SetText("")
            ui.search:ClearFocus()
            Refresh()
        end)
        b:Show()
        y = y - 27
    end
end

local function Build()
    window = CreateFrame("Frame", "GamepadCompanionPicker", UIParent)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window.chrome = S.Chrome(window, "Choose")
    body = CreateFrame("Frame", nil, window)
    body:SetSize(BODY_W, BODY_H)

    ui.left = CreateFrame("Frame", nil, body)
    ui.left:SetPoint("TOPLEFT", 0, 0)
    ui.left:SetSize(LEFT_W, BODY_H - 34)
    local rule = body:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(0.68, 0.5, 0.26, 0.35)
    rule:SetPoint("TOPLEFT", LEFT_W + 6, 0)
    rule:SetSize(1, BODY_H - 34)

    ui.heading = S.Text(body, "", GRID_X, -6, 220, 13, S.YELLOW)
    ui.heading:SetWordWrap(false)
    local search = CreateFrame("EditBox", nil, body, "BackdropTemplate")
    search:SetPoint("TOPRIGHT", 0, 0)
    search:SetSize(220, 26)
    search:SetAutoFocus(false)
    search:SetFont(FONT, 12, "")
    search:SetTextColor(1, 1, 1)
    search:SetTextInsets(8, 8, 0, 0)
    S.Edit(search)
    search.hint = S.Text(search, "Search", 8, -7, 200, 11, S.DIM)
    search:SetScript("OnTextChanged", function(self)
        query = (self:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        search.hint:SetShown((self:GetText() or "") == "")
        offset = 0
        Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ui.search = search

    ui.grid = CreateFrame("Frame", nil, body)
    ui.grid:SetPoint("TOPLEFT", GRID_X, -38)
    ui.grid:SetSize(COLS * (TILE_W + GAP), ROWS * (TILE_H + GAP))
    ui.grid:EnableMouseWheel(true)
    ui.grid:SetScript("OnMouseWheel", function(_, delta) Page(delta > 0 and -1 or 1) end)
    ui.empty = S.Text(ui.grid, "Nothing here", 0, -150, COLS * (TILE_W + GAP), 12, S.DIM)
    ui.empty:SetJustifyH("CENTER")

    -- Typed macro
    ui.textPane = CreateFrame("Frame", nil, body)
    ui.textPane:SetPoint("TOPLEFT", GRID_X, -38)
    ui.textPane:SetSize(BODY_W - GRID_X, 300)
    local box = CreateFrame("EditBox", nil, ui.textPane, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 0, 0)
    box:SetSize(BODY_W - GRID_X, 200)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(255)
    box:SetFont(FONT, 12, "")
    box:SetTextColor(1, 1, 1)
    box:SetTextInsets(8, 8, 8, 8)
    S.Edit(box)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ui.macro = box
    ui.useMacro = S.NewButton(ui.textPane, "Use macro", BODY_W - GRID_X - 120, -210, 120, function()
        local text = (box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text ~= "" then Pick("text:" .. text) end
    end)

    -- Footer
    ui.prev = S.NewButton(body, "<", GRID_X, -(BODY_H - 28), 30, function() Page(-1) end, nil, 13, 26)
    ui.pageText = S.Text(body, "", GRID_X + 36, -(BODY_H - 22), 160, 11, S.GREY)
    ui.next = S.NewButton(body, ">", GRID_X + 200, -(BODY_H - 28), 30, function() Page(1) end, nil, 13, 26)
    S.NewButton(body, "Cancel", BODY_W - 100, -(BODY_H - 28), 100, function() window:Hide() end)

    window:SetScript("OnHide", function() request = nil end)
    UISpecialFrames[#UISpecialFrames + 1] = "GamepadCompanionPicker"
    S.RegisterWindow(window)
    window:Hide()
end

-- req: { title, accepts = { spell, item, macro, halo, window, text }, current, onPick(action) }
function Picker.Open(req)
    if not window then Build() end
    request = req
    window.chrome:SetTitle(req.title or "Choose")
    window.chrome:SetKind("legacy")
    local inset = window.chrome:Insets()
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", inset.left, -inset.top)
    window:SetSize(BODY_W + inset.left + inset.right, BODY_H + inset.top + inset.bottom)
    S.Fit(window)
    ui.categories = Categories()
    LayoutCategories()
    -- Start where the current action is
    category, offset, query = ui.categories[1], 0, ""
    for _, cat in ipairs(ui.categories) do
        for i, e in ipairs(cat.list or {}) do
            if e.action == req.current then
                category = cat
                offset = math.floor((i - 1) / (COLS * ROWS)) * COLS * ROWS
            end
        end
        if cat.text and type(req.current) == "string" and req.current:match("^text:") then category = cat end
    end
    ui.search:SetText("")
    ui.macro:SetText(type(req.current) == "string" and req.current:match("^text:(.*)$") or "")
    window:Show()
    window:Raise()
    Refresh()
end

function Picker.Close() if window then window:Hide() end end
function Picker.IsShown() return window ~= nil and window:IsShown() end

-- Harness access
ns.PickerWindow = function() return window, ui end
