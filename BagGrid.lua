-- Bag grid: the d-pad moves item by item in the combined bag (gamepad UI).
-- Moved here from Gear Glance 2.4.2, where it was built and confirmed in game.
--
-- In the gamepad UI Blizzard adds the gamepad bag buttons (one per bag, with
-- free-slot counts) as cells of the combined bag's item grid, and the d-pad
-- cursor goes astray on them. Blizzard's bag navigation is a grid
-- (ContainerFrameCombinedBagsMixin:SmartNavPanelInfoAdded: grid navigation,
-- wrapping): one column per distinct button center x among the bag's
-- clickable frames, so any stray frame (the tracked-currency line under the
-- items) becomes a column the cursor lands on.
--
-- With Bag grid on, after Blizzard lays out the bag:
-- - the items are laid out again on the same grid (10 columns, from the
--   bottom right, Blizzard's order) without those buttons; the buttons are
--   hidden; the frame is sized for the items alone;
-- - whatever sits under the items (currencies, money) is marked ignored;
-- - the bag doesn't wrap from its last column to its first;
-- - after the loot window closes, the cursor goes back to the open bag
--   (Blizzard does that only when LOOT_OPENED says the loot came from an item,
--   which Forever apparently doesn't).
--
-- Taint rule: nothing of ours is written into SmartNavigation's tables or
-- Blizzard's buttons. The calls into it (SmartNavigation_MarkFrameIgnored,
-- SmartNavigation:SetWrapping, the focus manager's FrameHidden / FrameShown)
-- are the ones Blizzard opened to addons (SecureHelper, build 70938): out of
-- combat they run securely. In combat they'd be refused ("Interface action
-- failed"), so they aren't made.
local _, ns = ...
local Sh = ns.Shared
local B = {}
ns.BagGrid = B

B.COLUMNS = 10
local PREFIX = "|cff80c0ffGamepad Companion:|r "

local function InCombat() return InCombatLockdown and InCombatLockdown() end

function B.Enabled() return Sh.CharDB().bagGrid ~= false end
function B.SetEnabled(on)
    Sh.CharDB().bagGrid = on and true or false
    local bag = ContainerFrameCombinedBags
    if bag and bag:IsShown() and not InCombat() and type(bag.UpdateItemLayout) == "function" then
        pcall(bag.UpdateItemLayout, bag)   -- (off: Blizzard's own layout back)
    end
end

function B.GamepadUI()
    if not (InputUtil and InputUtil.IsGamepadUIEnabled) then return false end
    local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
    return ok and on == true
end

-- Blizzard's way to keep a frame (and its children) out of the cursor's
-- reach. Once per frame, out of combat only.
local navIgnored = setmetatable({}, { __mode = "k" })
function B.IgnoreForNavigation(frame)
    if not frame or navIgnored[frame] or InCombat() or type(SmartNavigation_MarkFrameIgnored) ~= "function" then return end
    if pcall(SmartNavigation_MarkFrameIgnored, frame) then navIgnored[frame] = true end
end

local function Wanted(bag)
    return B.Enabled() and B.GamepadUI() and bag and bag:IsShown() and not InCombat()
end

-- The gamepad bag buttons, for every bag the combined bag can hold
local function GamepadBagButtons()
    local list = {}
    if not (GamepadBagBar and GamepadBagBar.GetBagButton) then return list end
    local last = (NUM_TOTAL_BAG_FRAMES or NUM_BAG_SLOTS or 4) + 1
    for bagID = (KEYRING_CONTAINER and math.min(KEYRING_CONTAINER, 0) or 0), last do
        local ok, button = pcall(GamepadBagBar.GetBagButton, GamepadBagBar, bagID)
        if ok and type(button) == "table" then list[#list + 1] = button end
    end
    return list
end

-- Blizzard's order: highest bag first, highest slot first, laid from the
-- bottom right (so the backpack starts top left); the keyring last
local function SortBagID(item)
    local bagID = item:GetBagID()
    if KEYRING_CONTAINER and bagID == KEYRING_CONTAINER then return (NUM_TOTAL_BAG_FRAMES or 5) + 1 end
    return bagID
end
local function SortItems(a, b)
    local bagA, bagB = SortBagID(a), SortBagID(b)
    if bagA ~= bagB then return bagA > bagB end
    return a:GetID() > b:GetID()
end

function B.Layout(bag)
    if not Wanted(bag) then return end
    local items = {}
    for first, second in bag:EnumerateValidItems() do
        local item = type(first) == "table" and first or second
        if type(item) == "table" and item.GetBagID and item:GetBagID() then items[#items + 1] = item end
    end
    if #items == 0 then return end
    table.sort(items, SortItems)
    -- Only the ones placed inside the bag (they may sit in a holder frame of it)
    for _, button in ipairs(GamepadBagButtons()) do
        local parent, depth = button:GetParent(), 0
        while parent and parent ~= bag and depth < 5 do parent, depth = parent:GetParent(), depth + 1 end
        if parent == bag and button:IsShown() then button:Hide() end
    end
    -- Items of a bag collapsed earlier (with its gamepad button) come back:
    -- without the buttons it couldn't be opened again
    for _, item in ipairs(items) do if not item:IsShown() then item:Show() end end
    local anchorTo = bag.MoneyFrame or bag
    local spacingX, spacingY = ITEM_SPACING_X or 5, ITEM_SPACING_Y or 5
    for index, item in ipairs(items) do
        local cell = index - 1
        local col, row = cell % B.COLUMNS, math.floor(cell / B.COLUMNS)
        item:ClearAllPoints()
        item:SetPoint("BOTTOMRIGHT", anchorTo, "TOPRIGHT",
            -col * (item:GetWidth() + spacingX), 4 + row * (item:GetHeight() + spacingY))
    end
    -- Blizzard's own height formula (CalculateHeight), for the item rows alone
    local rows = math.ceil(#items / B.COLUMNS)
    local okPad, pad = pcall(bag.GetPaddingHeight, bag)
    local okExtra, extra = pcall(bag.CalculateExtraHeight, bag)
    if okPad and okExtra and tonumber(pad) and tonumber(extra) then
        local height = rows * items[1]:GetHeight() + (rows - 1) * spacingY + pad + extra
        if math.abs((bag:GetHeight() or 0) - height) > 0.5 then
            bag:SetHeight(height)
            if NineSliceUtil and NineSliceUtil.UpdateCornerCropping then pcall(NineSliceUtil.UpdateCornerCropping, bag, height) end
        end
    end
    -- Whatever sits under the items (tracked currencies, money) isn't a stop
    local isItem, gridBottom = {}, nil
    for _, item in ipairs(items) do
        isItem[item] = true
        local bottom = item:GetBottom()
        if bottom and (not gridBottom or bottom < gridBottom) then gridBottom = bottom end
    end
    if gridBottom then
        for _, child in ipairs({ bag:GetChildren() }) do
            local top = not isItem[child] and child:IsShown() and child:GetTop()
            if top and top <= gridBottom + 1 then B.IgnoreForNavigation(child) end
        end
    end
end

-- The loot window closed: the cursor goes back to the open bag. The bag is
-- announced again with FrameHidden and FrameShown (what Blizzard calls when
-- the bag opens). Nothing happens when Blizzard already focused it or another
-- window has focus.
function B.RefocusAfterLoot()
    local bag = ContainerFrameCombinedBags
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if not B.Enabled() or not B.GamepadUI() or InCombat() then return end
    if not (manager and manager.FrameHidden and manager.FrameShown and bag and bag:IsShown()) then return end
    if manager.isUIFocused and manager.focusedFrame ~= nil then return end
    pcall(manager.FrameHidden, manager, bag)
    pcall(manager.FrameShown, manager, bag)
end

local lootHooked, gridHooked = false, false
function B.Hook()
    if not lootHooked and LootFrame and LootFrame.HookScript then
        lootHooked = true
        -- Next frame: Blizzard's own focus hand-off finishes first
        LootFrame:HookScript("OnHide", function() C_Timer.After(0, B.RefocusAfterLoot) end)
    end
    local bag = ContainerFrameCombinedBags
    if gridHooked or not bag or type(bag.UpdateItemLayout) ~= "function" then return end
    gridHooked = true
    hooksecurefunc(bag, "UpdateItemLayout", B.Layout)
    -- A frame size set after the layout would undo the item-only height
    if type(bag.UpdateFrameSize) == "function" then hooksecurefunc(bag, "UpdateFrameSize", B.Layout) end
    -- Blizzard turns wrapping on each time the bag joins the navigation
    if type(bag.SmartNavPanelInfoAdded) == "function" then
        hooksecurefunc(bag, "SmartNavPanelInfoAdded", function(self)
            if B.Enabled() and not InCombat() and SmartNavigation and SmartNavigation.SetWrapping then
                pcall(SmartNavigation.SetWrapping, SmartNavigation, self, false)
            end
        end)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() B.Hook() end)

---------------------------------------------------------------------------
-- /gpc nav: the bag cursor recorder (read-only diagnostics)
--
-- Records each cursor move in the combined bag (from, to, d-pad direction),
-- where a plain grid would have gone, whether that slot was in Blizzard's
-- list, presses that moved nothing, and once per opening Blizzard's grid
-- columns and the per-button rules. It only reads fields, from its own
-- OnUpdate, while the bag is open in the gamepad UI: nothing is written to,
-- hooked or called in SmartNavigation (a value of ours read by it would
-- taint it). Kept in GamepadCompanionCharDB.navLog (last 150) across /reload.
---------------------------------------------------------------------------
do
    local MAX = 150
    local DIRS = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

    local function Log()
        local db = Sh.CharDB()
        if type(db.navLog) ~= "table" then db.navLog = {} end
        return db.navLog
    end
    B.Log = Log

    local function Add(entry)
        local log = Log()
        entry.t = GetTime and math.floor(GetTime() * 100) / 100 or 0
        log[#log + 1] = entry
        while #log > MAX do table.remove(log, 1) end
    end

    local function Bag()
        local bag = ContainerFrameCombinedBags
        if bag and bag:IsVisible() and bag.EnumerateValidItems then return bag end
    end

    -- The visible item buttons and their centers
    local function Slots(bag)
        local slots = {}
        for first, second in bag:EnumerateValidItems() do
            local button = type(first) == "table" and first or second
            if type(button) == "table" and button:IsVisible() then
                local x, y = button:GetCenter()
                if x then slots[#slots + 1] = { button = button, x = x, y = y, size = button:GetWidth() or 37 } end
            end
        end
        return slots
    end

    local function Describe(button, slots)
        if not button then return "none" end
        if type(button) ~= "table" then return tostring(button) end
        local ok, forbidden = pcall(button.IsForbidden, button)
        if not ok or forbidden then return "forbidden" end
        if button.GetBagID and button.GetID then
            local okBag, bag = pcall(button.GetBagID, button)
            if okBag and type(bag) == "number" then
                local text = "bag " .. bag .. " slot " .. button:GetID()
                if slots then
                    -- Row and column in the bag, from the top left
                    local me
                    for _, s in ipairs(slots) do if s.button == button then me = s end end
                    if me then
                        local step = me.size / 2
                        local function Key(v) return math.floor(v / step + 0.5) end
                        local rows, cols = {}, {}
                        for _, s in ipairs(slots) do rows[Key(s.y)] = true; cols[Key(s.x)] = true end
                        local row, col = 1, 1
                        for key in pairs(rows) do if key > Key(me.y) then row = row + 1 end end
                        for key in pairs(cols) do if key < Key(me.x) then col = col + 1 end end
                        text = text .. " (r" .. row .. " c" .. col .. ")"
                    end
                end
                return text
            end
        end
        local name = button.GetName and button:GetName()
        local parent = button.GetParent and button:GetParent()
        local parentName = parent and parent.GetName and parent:GetName()
        return (name or (button.GetObjectType and button:GetObjectType() or "frame"))
            .. (parentName and (" in " .. parentName) or "")
    end

    -- Where a plain grid goes from this button: the nearest slot in the same
    -- row (or column) in that direction
    local function GridNeighbor(from, dir, slots)
        local me
        for _, s in ipairs(slots) do if s.button == from then me = s end end
        if not me then return end
        local tolerance = me.size / 2
        local best, bestDistance
        for _, s in ipairs(slots) do
            if s ~= me then
                local dx, dy = s.x - me.x, s.y - me.y
                local along = dir[1] ~= 0 and dx * dir[1] or dy * dir[2]
                local across = dir[1] ~= 0 and math.abs(dy) or math.abs(dx)
                if along > 0 and across < tolerance and (not bestDistance or along < bestDistance) then
                    best, bestDistance = s.button, along
                end
            end
        end
        return best
    end

    -- Blizzard's current list of buttons the cursor may go to
    local function Candidates()
        local nav = SmartNavigation
        local info = nav and nav.activeInfo
        local groups = info and info.buttonGroups
        local group = groups and (groups.focusedGroup or groups.mainGroup)
        return group and group.buttons, info
    end

    local function DirectionName(directions)
        if type(directions) ~= "table" or #directions == 0 then return nil end
        local names = {}
        for _, d in ipairs(directions) do
            for name, v in pairs(DIRS) do
                if d.x == v[1] and d.y == v[2] then names[#names + 1] = name end
            end
        end
        return table.concat(names, "+")
    end

    local watcher = CreateFrame("Frame")
    local lastButton, lastDirection, movedWhileHeld, openLogged

    local function OnUpdate()
        local bag = Bag()
        local nav = SmartNavigation
        if not bag or not nav or not B.GamepadUI() then
            lastButton, lastDirection, openLogged = nil, nil, false
            return
        end
        local current = nav.currentButton
        local direction = DirectionName(nav.currentDirections)

        -- Where a button is, from the bag's top left, in screen pixels:
        -- "x,y wxh", and "+anchor" when its cursor point is set elsewhere
        local function Where(button)
            if type(button) ~= "table" or not button.GetScaledRect then return nil end
            local ok, l, b, w, h = pcall(button.GetScaledRect, button)
            local okBag, bl, bb, bw, bh = pcall(bag.GetScaledRect, bag)
            if not (ok and l and okBag and bl) then return "no rect" end
            local text = ("%d,%d %dx%d"):format(l - bl, (bb + bh) - (b + h), w, h)
            if button.smartNavigationCustomCursorAnchor then text = text .. " +anchor" end
            return text
        end

        -- Blizzard's rules stored on a button: jump overrides per direction,
        -- a focus group key, a custom cone, an ignore flag. Read only
        local function Rules(button)
            if type(button) ~= "table" then return nil end
            local parts = {}
            local data = rawget(button, "smartNavData")
            local overrides = type(data) == "table" and data.navigationOverrides
            if type(overrides) == "table" then
                for key, target in pairs(overrides) do
                    parts[#parts + 1] = tostring(key) .. ">" .. (type(target) == "function" and "fn"
                        or type(target) == "table" and Describe(target) or tostring(target))
                end
            end
            if rawget(button, "smartNavigationFocusKey") ~= nil then parts[#parts + 1] = "group " .. tostring(button.smartNavigationFocusKey) end
            if rawget(button, "smartNavigationDirectionBufferData") then parts[#parts + 1] = "cone" end
            if rawget(button, "smartNavigationIgnored") or rawget(button, "smartNavigationIgnoredDontPropagate") then parts[#parts + 1] = "ignored" end
            if #parts == 0 then return nil end
            return table.concat(parts, ", ")
        end

        -- Once per bag opening: what besides item slots can the cursor go to?
        if not openLogged then
            local buttons, info = Candidates()
            if buttons and info and info.frame == bag then
                openLogged = true
                local slots, inList, isSlot, others = Slots(bag), {}, {}, {}
                for _, s in ipairs(slots) do isSlot[s.button] = true end
                for _, b in ipairs(buttons) do
                    inList[b] = true
                    if not isSlot[b] and #others < 40 then
                        local okVisible, visible = pcall(b.IsVisible, b)
                        if okVisible and visible then
                            local rules = Rules(b)
                            others[#others + 1] = Describe(b) .. " @" .. tostring(Where(b)) .. (rules and (" [" .. rules .. "]") or "")
                        end
                    end
                end
                local missing = 0
                for _, s in ipairs(slots) do if not inList[s.button] then missing = missing + 1 end end
                local first = slots[1] and Where(slots[1].button)
                local ruled = {}
                for _, s in ipairs(slots) do
                    local rules = Rules(s.button)
                    if rules and #ruled < 10 then ruled[#ruled + 1] = Describe(s.button, slots) .. " [" .. rules .. "]" end
                end
                -- Blizzard's grid: one column per distinct x. Columns holding
                -- anything but slots send the cursor astray
                local grid, gridText = info.grid, "no grid"
                if type(grid) == "table" then
                    local stray = {}
                    for index, column in ipairs(grid) do
                        local names = {}
                        for _, b in ipairs(column) do if not isSlot[b] then names[#names + 1] = Describe(b) end end
                        if #names > 0 and #stray < 20 then
                            stray[#stray + 1] = "col " .. index .. " (" .. #column .. "): " .. table.concat(names, ", ")
                        end
                    end
                    gridText = #grid .. " columns" .. (#stray > 0 and ("; " .. table.concat(stray, "; ")) or "")
                end
                Add({ kind = "open", slots = #slots, listed = #buttons, missing = missing,
                    slot1 = first, others = others, ruledSlots = ruled, grid = gridText })
            end
        end

        -- A press that ended without the cursor moving
        if direction ~= lastDirection then
            if lastDirection and not movedWhileHeld then
                Add({ kind = "lost", dir = lastDirection, at = Describe(current, Slots(bag)) })
            end
            movedWhileHeld = false
            lastDirection = direction
        end

        if current ~= lastButton then
            local slots = Slots(bag)
            local dir = direction or lastDirection
            local entry = { kind = "move", dir = dir or "?", from = Describe(lastButton, slots), to = Describe(current, slots),
                fromAt = Where(lastButton), toAt = Where(current), fromRules = Rules(lastButton) }
            -- Inside a focus group the cursor only sees that group's buttons
            local navInfo = nav.activeInfo
            local groups = navInfo and navInfo.buttonGroups
            if groups and groups.focusedGroup then
                entry.group = tostring(navInfo.focusedKey) .. " (" .. #(groups.focusedGroup.buttons or {}) .. ")"
            end
            local vector = dir and DIRS[dir]
            if vector and lastButton then
                local expected = GridNeighbor(lastButton, vector, slots)
                entry.grid = Describe(expected, slots)
                entry.ok = expected == current or nil
                if expected and expected ~= current then
                    local listed = false
                    for _, b in ipairs(Candidates() or {}) do if b == expected then listed = true; break end end
                    entry.gridListed = listed
                end
            end
            if lastButton then Add(entry) end
            movedWhileHeld = true
            lastButton = current
        end
    end

    watcher:SetScript("OnUpdate", OnUpdate)
    B.Watch = OnUpdate

    -- /gpc nav: summary in chat. /gpc nav clear: start over
    function B.Report(clear)
        local log = Log()
        if clear then
            for i = #log, 1, -1 do log[i] = nil end
            print(PREFIX .. "Bag log cleared")
            return
        end
        local moves, wrong, lost, unlisted = 0, 0, 0, 0
        for _, e in ipairs(log) do
            if e.kind == "move" then
                moves = moves + 1
                if e.grid and not e.ok then wrong = wrong + 1 end
                if e.gridListed == false then unlisted = unlisted + 1 end
            elseif e.kind == "lost" then
                lost = lost + 1
            end
        end
        print(PREFIX .. ("Bag cursor: %d moves, %d off grid (%d unlisted), %d presses no move"):format(
            moves, wrong, unlisted, lost))
        local shown = 0
        for i = #log, 1, -1 do
            local e = log[i]
            if shown >= 6 then break end
            if e.kind == "move" and e.grid and not e.ok then
                print(("  %s: %s -> %s (grid: %s)"):format(e.dir, e.from, e.to, e.grid))
                shown = shown + 1
            end
        end
    end
end
