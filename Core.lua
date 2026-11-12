local ADDON, ns = ...
local M = ns.Model
local API = { version = 1 }
GamepadCompanionAPI = API
local eventFrame = CreateFrame("Frame")
local subscribers, records, dispatching = {}, {}, {}
local settings, state = M.Normalize(), { available = false, enabled = false, gameplay = false }
local ready, queued, pending, refreshing = false, false, false, false
local observingNative = false
local observedPages = setmetatable({}, { __mode = "k" })
local ticker, tickerInterval
local EnsureClassButtonHooks
local layoutElapsed, layoutState = 0, nil
local stopped = false
local editing, spread = false, false
local hookedClassButtons = setmetatable({}, { __mode = "k" })
local barLayers = { "base", "lt", "rt", "both", "stance" }
local Refresh

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and M.Readable(value) then return value end
end

local function Finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function SameNumber(a, b)
    return Finite(a) and Finite(b) and math.abs(a - b) <= math.max(0.0001, math.abs(a) * 0.000001, math.abs(b) * 0.000001)
end

local function PageUnit()
    local root = _G.GamepadMainActionBarFrame
    return root and root.PageUnit
end

local function NativeBar(layer)
    local page = PageUnit()
    return page and page.actionBars and page.actionBars[M.barKeys[layer]]
end

local function QueueRefresh()
    if queued or not ready then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Refresh()
    end)
end

local function ReadHeld(action)
    if not GetBindingKey or not IsKeyDown then return nil end
    local ok, first, second = pcall(GetBindingKey, action, 1)
    if not ok then return nil end
    local keys = { first, second }
    local known = false
    for index = 1, 2 do
        local key = keys[index]
        if M.Readable(key) and type(key) == "string" then
            local held = SafeCall(IsKeyDown, key)
            if type(held) == "boolean" then
                known = true
                if held then return true end
            end
        end
    end
    if known then return false end
end

local function ReadState()
    local page = PageUnit()
    local available = page ~= nil and type(page.actionBars) == "table" and GamepadMode ~= nil
    local nativeEnabled = InputUtil and SafeCall(InputUtil.IsGamepadUIEnabled)
    if type(nativeEnabled) ~= "boolean" then nativeEnabled = nil end
    available = available and nativeEnabled ~= nil
    local enabled = available and settings.enabled and not stopped and nativeEnabled == true or false
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    local gameplay = enabled and manager and SafeCall(manager.IsOnlyCoreBindingSetActive, manager) == true or false
    local result = { available = available, enabled = enabled, nativeEnabled = nativeEnabled,
        gameplay = gameplay, pendingLayout = pending, editing = editing and enabled, spread = spread and editing and enabled }
    -- Blizzard's per-character "Compact action bar" option. Read it even while
    -- Companion is off so the options window can show which layout is in use.
    result.compact = page ~= nil and SafeCall(page.ShouldUseCompactLayout, page) == true
    result.mode = result.compact and "compact" or "standard"
    if not enabled then return result end
    result.ltHeld, result.rtHeld = ReadHeld("GAMEPADLEFTMOD"), ReadHeld("GAMEPADRIGHTMOD")
    if result.ltHeld ~= nil and result.rtHeld ~= nil then result.bothHeld = result.ltHeld and result.rtHeld end
    local leftShoulder = SafeCall(IsKeyDown, "PADLSHOULDER")
    local rightShoulder = SafeCall(IsKeyDown, "PADRSHOULDER")
    if type(leftShoulder) == "boolean" then result.leftShoulderHeld = leftShoulder end
    if type(rightShoulder) == "boolean" then result.rightShoulderHeld = rightShoulder end
    if result.leftShoulderHeld ~= nil and result.rightShoulderHeld ~= nil then
        result.bothShouldersHeld = result.leftShoulderHeld and result.rightShoulderHeld
    end
    result.page = SafeCall(page.GetCurrentPage, page)
    if not Finite(result.page) then result.page = nil end
    if gameplay then
        local active = SafeCall(page.GetActiveBar, page)
        for _, layer in ipairs(M.layers) do
            if active and active == NativeBar(layer) then result.activeLayer = layer end
        end
        -- A native targeting/stance/possess override has independent controls.
        result.nativeOverride = active ~= nil and result.activeLayer == nil
        if active and active == NativeBar("stance") then result.activeSpecialBar = "stance" end
    end
    return result
end

local function ReadPoints(frame)
    local points = {}
    local count = SafeCall(frame.GetNumPoints, frame)
    if type(count) ~= "number" or count < 0 or count > 16 or count ~= math.floor(count) then return nil end
    for index = 1, count do
        local ok, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, index)
        if not ok or not M.Readable(point) or not M.Readable(relative) or not M.Readable(relativePoint)
            or not M.Readable(x) or not M.Readable(y) then return nil end
        if type(point) ~= "string" or not Finite(x) or not Finite(y) then return nil end
        points[#points + 1] = { point, relative, relativePoint, x, y }
    end
    return points
end

local function SamePoints(a, b)
    if not a or not b or #a ~= #b then return false end
    for index, point in ipairs(a) do
        for field = 1, 3 do if point[field] ~= b[index][field] then return false end end
        if not SameNumber(point[4], b[index][4]) or not SameNumber(point[5], b[index][5]) then return false end
    end
    return true
end

local function OwnsGeometry(record)
    return record.ownsPoints or record.ownsScale
end

-- A changed component belongs to the host again. Never infer its new baseline
-- by subtracting our offsets: native layout may already have replaced them.
local function ObserveGeometry(record)
    local frame = record.frame
    local points, scale = ReadPoints(frame), SafeCall(frame.GetScale, frame)
    if points and (not record.ownsPoints or not SamePoints(points, record.lastPoints)) then
        record.points, record.ownsPoints, record.lastPoints = points, false, nil
    end
    if Finite(scale) and (not record.ownsScale or not SameNumber(scale, record.lastScale)) then
        record.scale, record.ownsScale, record.lastScale = scale, false, nil
    end
    return points, scale
end

local function WritePoints(record, points)
    if InCombat() or record.failed then return false end
    local frame = record.frame
    local before = ReadPoints(frame)
    if not before then return false end
    if SamePoints(before, points) then return true end
    local ok = pcall(function()
        frame:ClearAllPoints()
        for _, point in ipairs(points) do
            frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
        end
    end)
    -- Read back even on failure: ClearAllPoints or some SetPoint calls may
    -- already have succeeded. Retain that exact partial result for retry.
    local after = ReadPoints(frame)
    if after and (record.ownsPoints or not SamePoints(before, after)) then
        record.ownsPoints, record.lastPoints = true, after
    end
    local complete = ok and SamePoints(after, points)
    if not complete then record.failed = true end
    return complete
end

local function WriteScale(record, scale)
    if InCombat() or record.failed then return false end
    local frame = record.frame
    local before = SafeCall(frame.GetScale, frame)
    if not Finite(before) then return false end
    if SameNumber(before, scale) then return true end
    local ok = pcall(frame.SetScale, frame, scale)
    local after = SafeCall(frame.GetScale, frame)
    if Finite(after) and (record.ownsScale or not SameNumber(before, after)) then
        record.ownsScale, record.lastScale = true, after
    end
    local complete = ok and SameNumber(after, scale)
    if not complete then record.failed = true end
    return complete
end

local function Restore(record)
    local points, scale = ObserveGeometry(record)
    if not OwnsGeometry(record) then return true end
    if InCombat() then return false end
    if record.ownsPoints and points and WritePoints(record, record.points) then
        record.ownsPoints, record.lastPoints = false, nil
    end
    if record.ownsScale and Finite(scale) and WriteScale(record, record.scale) then
        record.ownsScale, record.lastScale = false, nil
    end
    return not OwnsGeometry(record)
end

local function Track(frame)
    if not records[frame] then records[frame] = { frame = frame } end
    return records[frame]
end

local shoulderBarKeys = { "friendlyTargetingBar", "hostileTargetingBar", "shortcutsBar" }

local function VisualCenterOffset(base)
    local center = SafeCall(base.GetCenter, base)
    local scale = SafeCall(base.GetEffectiveScale, base)
    if not Finite(center) or not Finite(scale) or type(base.actionButtons) ~= "table" then return 0 end
    local left, right
    for index = 1, 8 do
        local button = base.actionButtons[index]
        if not button then return 0 end
        local x = SafeCall(button.GetLeft, button)
        local edge = SafeCall(button.GetRight, button)
        local buttonScale = SafeCall(button.GetEffectiveScale, button)
        if not Finite(x) or not Finite(edge) or not Finite(buttonScale) then return 0 end
        left = math.min(left or x * buttonScale, x * buttonScale)
        right = math.max(right or edge * buttonScale, edge * buttonScale)
    end
    return (left + right) / 2 - center * scale
end

local function ApplyFrameLayout(frame, config, wanted, followBase, page, visualOffset)
    if not frame then pending = true; return end
    wanted[frame] = true
    local record = Track(frame)
    local livePoints, liveScale = ObserveGeometry(record)
    if not record.points or #record.points == 0 or not Finite(record.scale)
        or not livePoints or not Finite(liveScale) then pending = true; return end
    local desiredPoints = {}
    local desiredScale = M.DesiredScale(record.scale, config)
    for _, point in ipairs(record.points) do
        local relative, relativePoint, x, y = point[2], point[3], point[4], point[5]
        if followBase then
            -- Native shoulder backgrounds and override bars use the top anchor's
            -- center. Follow the actual Base bar instead, even while it is hidden.
            -- Icons/highlights already follow their background: don't move twice.
            if relative == page.TopCenteredAnchor and point[3] == "CENTER" then relative = followBase end
            if relative == page.TopCenteredAnchor and relativePoint == "TOP" then
                -- The page numbers sit above a 50px native anchor, not above
                -- the action bar's differently sized bounds. Preserve that gap.
                local height = SafeCall(relative.GetHeight, relative)
                local anchorScale = SafeCall(relative.GetEffectiveScale, relative)
                local frameScale = SafeCall(frame.GetEffectiveScale, frame)
                if not Finite(height) or not Finite(anchorScale) or not Finite(frameScale)
                    or frameScale <= 0 or record.scale <= 0 then pending = true; return end
                y = y + height * anchorScale * liveScale / (2 * frameScale * record.scale)
                relative, relativePoint = followBase, "CENTER"
            end
        else
            x, y = x + config.x, y + config.y
        end
        if visualOffset ~= nil and relative == followBase then
            local frameScale = SafeCall(frame.GetEffectiveScale, frame)
            local baseScale = SafeCall(followBase.GetEffectiveScale, followBase)
            local baseLocalScale = SafeCall(followBase.GetScale, followBase)
            local baseRecord = records[followBase]
            if not Finite(frameScale) or frameScale <= 0 or liveScale <= 0
                or not Finite(baseScale) or not Finite(baseLocalScale) or baseLocalScale <= 0
                or not baseRecord then pending = true; return end
            local baseNeutralScale = baseScale / baseLocalScale * baseRecord.scale
            local ratio = baseNeutralScale * config.scale / (frameScale / liveScale * desiredScale)
            -- Follow the saved layout, not the live bar's expansion or button
            -- bounds. The native anchor is independent of bar selection.
            relative = page.TopCenteredAnchor
            x = x + (config.x + visualOffset) * ratio
            y = y + config.y * ratio
        end
        desiredPoints[#desiredPoints + 1] = { point[1], relative, relativePoint, x, y }
    end
    if not SamePoints(livePoints, desiredPoints) and not WritePoints(record, desiredPoints) then pending = true end
    if not SameNumber(liveScale, desiredScale) and not WriteScale(record, desiredScale) then pending = true end
end

-- Compact mode hides every trigger bar except the active one. Spread view
-- shows the others itself (outside combat) and hides them again on release.
local function RevealSpreadBar(frame, record)
    if InCombat() or SafeCall(frame.IsShown, frame) ~= false then return end
    if pcall(frame.Show, frame) then record.revealed = true else pending = true end
end

local function ApplySpreadLayout(frame, index, wanted, reveal)
    if not frame then pending = true; return end
    wanted[frame] = true
    local record = Track(frame)
    if reveal then RevealSpreadBar(frame, record) end
    local points, scale = ObserveGeometry(record)
    local effective = SafeCall(frame.GetEffectiveScale, frame)
    local uiScale = SafeCall(UIParent.GetEffectiveScale, UIParent)
    local width, height = SafeCall(UIParent.GetWidth, UIParent), SafeCall(UIParent.GetHeight, UIParent)
    if not points or not Finite(scale) or scale <= 0 or not Finite(effective) or effective <= 0
        or not Finite(uiScale) or not Finite(width) or not Finite(height) then pending = true; return end
    local fit = math.min(1, height / 720, width / 1100)
    local desiredScale = uiScale / (effective / scale) * fit
    local desiredPoints = { { "CENTER", UIParent, "CENTER", width * 0.27 / fit, (2.5 - index) * 150 } }
    if not SamePoints(points, desiredPoints) and not WritePoints(record, desiredPoints) then pending = true end
    if not SameNumber(scale, desiredScale) and not WriteScale(record, desiredScale) then pending = true end
end

-- Class-action buttons (LB+LT / RB+RT) re-anchor themselves to their native
-- offset on every press. Offsets here are in PageUnit units, so scaling the
-- button keeps it where the user put it instead of pushing it outward.
local function ApplyClassButton(layer, config, wanted, page)
    local button = page[M.classKeys[layer]]
    if not button then return end
    local prompt = page[M.promptKeys[layer]]
    local hidePrompt = not settings.classPrompts
    if M.IsDefault(config) and not hidePrompt then return end
    if prompt then
        wanted[prompt] = true
        local record = Track(prompt)
        if record.alpha == nil then
            local alpha = SafeCall(prompt.GetAlpha, prompt)
            record.alpha = Finite(alpha) and alpha or 1
        end
        local desired = hidePrompt and 0 or record.alpha
        if record.promptAlpha ~= desired and pcall(prompt.SetAlpha, prompt, desired) then
            record.promptAlpha = desired
        end
    end
    if M.IsDefault(config) then return end
    -- Blizzard reparents the button into its radial flyout while that is open, and
    -- offsets are measured in the parent's scale. Keep the same screen spot by
    -- converting between the page's and the current parent's effective scale;
    -- with the page as parent (the usual case) every factor is exactly 1.
    local parent = SafeCall(button.GetParent, button)
    local pageEff = SafeCall(page.GetEffectiveScale, page)
    local parentEff = parent and SafeCall(parent.GetEffectiveScale, parent)
    if not Finite(pageEff) or pageEff <= 0 or not Finite(parentEff) or parentEff <= 0 then
        if records[button] then wanted[button] = true end
        pending = true
        return
    end
    wanted[button] = true
    local record = Track(button)
    local livePoints, liveScale = ObserveGeometry(record)
    if not record.points or #record.points ~= 1 or not Finite(record.scale) or record.scale <= 0
        or not livePoints or not Finite(liveScale) then pending = true; return end
    local native = record.points[1]
    local scale = record.scale * config.scale
    -- While its radial flyout is open, Blizzard (since 70532) anchors the button to the
    -- flyout's centre with no offset, after centring the flyout on the button where we had
    -- put it. Nothing to add then, and the prompt stays where it is.
    local popup = SafeCall(button.IsPopupOpen, button) == true and SafeCall(button.GetPopup, button) or nil
    local onPopup = popup ~= nil and native[2] == popup
    local cx, cy = onPopup and 0 or config.x, onPopup and 0 or config.y
    -- Blizzard's own offset is the same number under any parent (it rewrites it in the
    -- parent's units); only ours is in page units and needs converting.
    local nx, ny = native[4] * record.scale, native[5] * record.scale
    local x, y = nx + cx, ny + cy
    local toParent = pageEff / parentEff
    local desired = { { native[1], native[2], native[3], (nx + cx * toParent) / scale, (ny + cy * toParent) / scale } }
    if not SamePoints(livePoints, desired) and not WritePoints(record, desired) then pending = true end
    if not SameNumber(liveScale, scale) and not WriteScale(record, scale) then pending = true end
    if not prompt or onPopup then return end
    local promptRecord = records[prompt]
    local promptPoints, promptLiveScale = ObserveGeometry(promptRecord)
    if not promptRecord.points or #promptRecord.points ~= 1 or not Finite(promptRecord.scale)
        or promptRecord.scale <= 0 or not promptPoints or not Finite(promptLiveScale) then pending = true; return end
    local p = promptRecord.points[1]
    local promptScale = promptRecord.scale * config.scale
    -- Keep the prompt's native gap to its button, scaled with the button.
    local px = x + (p[4] * promptRecord.scale - nx) * config.scale
    local py = y + (p[5] * promptRecord.scale - ny) * config.scale
    local promptDesired = { { p[1], p[2], p[3], px / promptScale, py / promptScale } }
    if not SamePoints(promptPoints, promptDesired) and not WritePoints(promptRecord, promptDesired) then pending = true end
    if not SameNumber(promptLiveScale, promptScale) and not WriteScale(promptRecord, promptScale) then pending = true end
end

local function ApplyLayout(current)
    pending = false
    if settings.enabled and not stopped and current.nativeEnabled == nil then
        -- Unknown is not a transition to keyboard/mouse mode. Keep existing
        -- leases untouched until the public getter becomes readable again.
        for _, record in pairs(records) do if OwnsGeometry(record) then pending = true; break end end
        return
    end
    local wanted = {}
    if current.enabled then
        local page = PageUnit()
        local mode = current.mode or "standard"
        for index, layer in ipairs(barLayers) do
            local frame, config = NativeBar(layer), M.Config(settings, mode, layer)
            if current.spread and layer ~= "stance" then
                ApplySpreadLayout(frame, index, wanted, current.compact)
            elseif not M.IsDefault(config) then
                ApplyFrameLayout(frame, config, wanted)
            end
        end
        for _, layer in ipairs(M.classLayers) do
            ApplyClassButton(layer, M.Config(settings, mode, layer), wanted, page)
        end
        local base, config = NativeBar("base"), M.Config(settings, mode, "base")
        if base and not current.spread and not M.IsDefault(config) then
            local baseRecord = records[base]
            if baseRecord.visualOffset == nil then
                local scale = SafeCall(base.GetEffectiveScale, base)
                baseRecord.visualOffset = Finite(scale) and scale > 0 and VisualCenterOffset(base) / scale or 0
            end
            local visualOffset = baseRecord.visualOffset
            if page.PageTracker then
                ApplyFrameLayout(page.PageTracker, config, wanted, base, page, visualOffset)
            end
            for _, key in ipairs(shoulderBarKeys) do
                local frame = page.actionBars[key]
                if frame then ApplyFrameLayout(frame, config, wanted, base, page) end
            end
            for _, side in ipairs({ "Left", "Right" }) do
                for _, part in ipairs({ "Background", "Icon", "Highlight" }) do
                    local region = page[side .. "Shoulder" .. part]
                    if region then ApplyFrameLayout(region, config, wanted, base, page, visualOffset) end
                end
            end
        end
    end
    local page = PageUnit()
    for frame, record in pairs(records) do
        if not wanted[frame] and record.revealed then
            -- Only Blizzard's compact rule hid this bar; its active bar stays shown.
            if page and SafeCall(page.ShouldUseCompactLayout, page) == true
                and SafeCall(page.GetActiveBar, page) ~= frame then
                if not InCombat() and pcall(frame.Hide, frame) then record.revealed = nil end
            else
                record.revealed = nil
            end
        end
        if not wanted[frame] then
            if record.promptAlpha ~= nil then
                if record.promptAlpha == record.alpha or pcall(frame.SetAlpha, frame, record.alpha) then
                    record.promptAlpha = nil
                end
            end
            if Restore(record) and record.promptAlpha == nil and not record.revealed then
                records[frame] = nil
            else
                pending = true
            end
        end
    end
    if settings.enabled and not current.available then
        for _, mode in ipairs(M.modes) do
            for _, config in pairs(M.Layout(settings, mode)) do
                if not M.IsDefault(config) then pending = true end
            end
        end
    end
end

local function HasLayoutWork(current)
    if current.enabled then
        if current.spread or not settings.classPrompts then return true end
        for _, config in pairs(M.Layout(settings, current.mode)) do if not M.IsDefault(config) then return true end end
    end
    if not InCombat() then
        for _, record in pairs(records) do
            if (OwnsGeometry(record) or record.revealed) and not record.failed then return true end
        end
    end
    return false
end

local function UpdateTicker(current)
    -- Held buttons and native input-context changes have no safe observer here.
    -- Poll them only while a consumer needs live state. Geometry recovery can
    -- run much more slowly and must never retry protected writes during combat.
    local interval
    if current.enabled and next(subscribers) then interval = 0.1
    elseif current.enabled and editing then interval = 0.25
    elseif not InCombat() and HasLayoutWork(current) then interval = 0.5 end
    if interval == tickerInterval then return end
    if ticker then ticker:Cancel(); ticker = nil end
    tickerInterval = interval
    if interval then
        ticker = C_Timer.NewTicker(interval, function() Refresh(interval) end)
    end
end

local function Notify(owner, callback, reason)
    if dispatching[owner] then return end
    dispatching[owner] = true
    local ok, message = pcall(function() callback(M.Copy(state), reason) end)
    dispatching[owner] = nil
    if not ok and geterrorhandler then
        local handler = SafeCall(geterrorhandler)
        if type(handler) == "function" then pcall(handler, message) end
    end
end

local function PublishState(newState, reason, force)
    newState.pendingLayout = pending
    newState.layoutError = false
    for _, record in pairs(records) do if record.failed then newState.layoutError = true; break end end
    if not force and M.SameState(newState, state) then return end
    state = newState
    -- Copy subscribers before dispatch; a callback can unsubscribe safely.
    local listeners = {}
    for owner, callback in pairs(subscribers) do listeners[#listeners + 1] = { owner, callback } end
    for _, listener in ipairs(listeners) do
        if subscribers[listener[1]] == listener[2] then
            Notify(listener[1], listener[2], reason)
        end
    end
end

local function EnsureNativeBarObserver()
    local page = PageUnit()
    if not ready or not settings.enabled or stopped or InCombat() or not page
        or observedPages[page] ~= nil or type(page.SetActiveActionBar) ~= "function"
        or type(hooksecurefunc) ~= "function" then return end
    -- This is the sole native posthook. Never register in the input manager or
    -- hook geometry: the native method finishes its own highlight/resize first.
    observedPages[page] = false
    local ok, result = pcall(hooksecurefunc, page, "SetActiveActionBar", function()
        if not ready or not settings.enabled or stopped or PageUnit() ~= page
            or observingNative or refreshing then return end
        observingNative = true
        local observed, message = pcall(function()
            local newState = ReadState()
            if newState.enabled then
                -- Repaint notifications are meaningful even when the layer is the
                -- same: subscribers may need to recompose alpha after native work.
                PublishState(newState, "native-bar", true)
                QueueRefresh()
            end
        end)
        observingNative = false
        if not observed and geterrorhandler then
            local handler = SafeCall(geterrorhandler)
            if type(handler) == "function" then pcall(handler, message) end
        end
    end)
    observedPages[page] = ok and result ~= false
end

-- Blizzard re-anchors a class-action button on every press and release. Put
-- the saved placement back straight away when that happens outside combat;
-- in combat the button stays native until PLAYER_REGEN_ENABLED.
local function ReapplyClassButton(layer)
    if not ready or refreshing or InCombat() or not state.enabled then return end
    local page = PageUnit()
    if not page then return end
    local config = M.Config(settings, state.mode or "standard", layer)
    if M.IsDefault(config) then return end
    ApplyClassButton(layer, config, {}, page)
end

-- Second native posthook, on the two class-action button instances only. It
-- never runs Blizzard code itself and never writes geometry during combat.
EnsureClassButtonHooks = function()
    local page = PageUnit()
    if not ready or not settings.enabled or stopped or InCombat() or not page
        or type(hooksecurefunc) ~= "function" then return end
    for _, layer in ipairs(M.classLayers) do
        local button = page[M.classKeys[layer]]
        if button and hookedClassButtons[button] == nil
            and type(button.ApplyExtraButtonStylesForState) == "function" then
            hookedClassButtons[button] = false
            local ok = pcall(hooksecurefunc, button, "ApplyExtraButtonStylesForState", function()
                pcall(ReapplyClassButton, layer)
            end)
            hookedClassButtons[button] = ok
            -- The radial flyout takes and gives back the button's parent: follow it now,
            -- or the button sits at Blizzard's spot until the next poll.
            if type(button.SetParent) == "function" then
                pcall(hooksecurefunc, button, "SetParent", function()
                    pcall(ReapplyClassButton, layer)
                end)
            end
        end
    end
end

Refresh = function(pollElapsed)
    if not ready then return end
    if refreshing or observingNative then QueueRefresh(); return end
    refreshing = true
    EnsureNativeBarObserver()
    EnsureClassButtonHooks()
    local newState = ReadState()
    layoutElapsed = layoutElapsed + (pollElapsed or 0)
    local changed = not layoutState or newState.enabled ~= layoutState.enabled
        or newState.gameplay ~= layoutState.gameplay or newState.activeLayer ~= layoutState.activeLayer
        or newState.activeSpecialBar ~= layoutState.activeSpecialBar or newState.spread ~= layoutState.spread
        or newState.mode ~= layoutState.mode
    local audit = not InCombat() and HasLayoutWork(newState) and (changed or layoutElapsed >= 0.5)
    if not pollElapsed or audit then
        ApplyLayout(newState)
        layoutState, layoutElapsed = newState, 0
    end
    -- Closed-editor form discovery is event-driven, not part of input polling.
    if ns.UpdateSpreadOverview and (not pollElapsed or (newState.spread and layoutElapsed == 0)) then
        ns.UpdateSpreadOverview(newState)
    end
    UpdateTicker(newState)
    PublishState(newState)
    refreshing = false
end

function API.GetState() return M.Copy(state) end
function API.GetSettings() return M.Copy(settings) end
function API.SetEditing(value)
    editing = value == true
    if not editing then spread = false end
    Refresh()
end
function API.SetSpread(value)
    if value and InCombat() then return false, "Not in combat" end
    spread = editing and value == true
    Refresh()
    return true, pending and "Applies after combat" or nil
end
function API.GetBarFrame(layer)
    if M.classKeys[layer] then
        local page = PageUnit()
        return page and page[M.classKeys[layer]]
    end
    return M.barKeys[layer] and NativeBar(layer)
end
function API.GetCapabilities()
    -- activeZoom stays in the table for consumers; it is always false since 0.4.0.
    -- bindingOverrides: only the opt-in touchpad zones (Touchpad.lua) bind keys
    local touch = ns.Touch
    return { layout = state.available, activeZoom = false, activeZoomInCombat = false,
        toggle = false, bindingOverrides = touch ~= nil and touch.BindsKeys() or false, version = 1,
        synchronousBarState = observedPages[PageUnit()] == true }
end
function API.Subscribe(owner, callback)
    if owner == nil or type(callback) ~= "function" then return false end
    subscribers[owner] = callback
    Notify(owner, callback, observingNative and "native-bar" or nil)
    UpdateTicker(state)
    return true
end
function API.Unsubscribe(owner) subscribers[owner] = nil; UpdateTicker(state) end
local function Save()
    GamepadCompanionDB = M.Copy(settings)
    for _, record in pairs(records) do record.failed = nil end
    if InCombat() then pending = true end
    if observingNative then QueueRefresh() else Refresh() end
    if state.layoutError then return true, "Layout blocked" end
    return true, pending and "Saved · applies later" or nil
end
-- `mode` is "standard" or "compact". Omitted means standard, the only layout
-- older callers know about.
local function CheckLayer(layer, mode)
    mode = mode == "compact" and "compact" or "standard"
    if not M.IsLayer(mode, layer) then return nil end
    return mode
end
function API.GetMode() return state.mode or "standard" end
function API.SetBarOption(layer, key, value, mode)
    mode = CheckLayer(layer, mode)
    if not mode or not M.bounds[key] then return false, "Unknown setting" end
    local range = M.bounds[key]
    local checked = M.Number(value, range[1], range[2], nil)
    if checked == nil then return false, "Not a number" end
    M.Layout(settings, mode)[layer][key] = checked
    return Save()
end
function API.SetEnabled(enabled) settings.enabled = enabled == true; return Save() end
function API.SetClassPrompts(shown) settings.classPrompts = shown ~= false; return Save() end
function API.ResetBar(layer, mode)
    mode = CheckLayer(layer, mode)
    if not mode then return false, "Unknown bar" end
    M.Layout(settings, mode)[layer] = M.Entry()
    return Save()
end
function API.ResetMode(mode)
    local neutral = M.Normalize()
    if mode == "compact" then settings.compact = neutral.compact else settings.bars = neutral.bars end
    return Save()
end
-- Copies stance and class buttons, plus Base <-> the compact bar, between layouts.
function API.CopyLayout(from, to)
    local valid = { compact = true, standard = true }
    if from == to or not valid[from] or not valid[to] then return false, "Unknown layout" end
    local source, target = M.Layout(settings, from), M.Layout(settings, to)
    for _, layer in ipairs({ "stance", "classLeft", "classRight" }) do target[layer] = M.Copy(source[layer]) end
    if to == "compact" then target.bars = M.Copy(source.base) else target.base = M.Copy(source.bars) end
    return Save()
end
function API.ResetAll()
    local style = settings.optionsStyle
    settings = M.Normalize({ optionsStyle = style, optionsStyleVersion = M.styleVersion })
    return Save()
end
-- Look of the options windows only; no layout work.
function API.SetOptionsStyle(style)
    if not M.styles[style] then return false, "Unknown style" end
    settings.optionsStyle = style
    GamepadCompanionDB = M.Copy(settings)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "GAME_PAD_CONNECTED" then
        for _, record in pairs(records) do record.failed = nil end
    end
    if event == "ADDON_LOADED" and arg == ADDON then
        settings = M.Normalize(GamepadCompanionDB)
        GamepadCompanionDB = M.Copy(settings)
        ready = true
    elseif event == "PLAYER_LEAVING_WORLD" or event == "GAME_PAD_DISCONNECTED" then
        stopped = true
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GAME_PAD_CONNECTED" then
        stopped = false
    end
    QueueRefresh()
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
    "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "INPUT_DEVICE_INTERFACE_TRANSITION", "UPDATE_BINDINGS",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "CVAR_UPDATE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_STEALTH", "SPELLS_CHANGED",
    "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end

SLASH_GAMEPADCOMPANION1 = "/gpc"
SLASH_GAMEPADCOMPANION2 = "/gamepadcompanion"
local function Say(message) print("|cff80c0ffGamepad Companion:|r " .. message) end
local commandHelp = {
    "/gpc  window",
    "/gpc pad  controller",
    "/gpc touch  touchpad",
    "/gpc bars  bar layout",
    "/gpc rumble  rumble · test: each motor",
    "/gpc on | off  my bar layout",
    "/gpc reset  both bar layouts",
    "/gpc gamepad  Blizzard options",
    "/gpc edit  Edit Mode layout",
}
SlashCmdList.GAMEPADCOMPANION = function(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "edit" and API.EditMode then
        API.EditMode.Command(rest)
        return
    end
    if command == "touch" and API.Touch then
        API.Touch.Command(rest)
        return
    end
    if (command == "pad" or command == "controller") and API.ToggleController then
        API.ToggleController()
        return
    end
    if command == "rumble" and API.OpenRumble then
        if rest:lower() == "test" and API.Rumble then API.Rumble.TestSides() else API.OpenRumble() end
        return
    end
    if command == "bars" and API.OpenBars then
        API.OpenBars()
        return
    end
    if command == "reset" then
        API.ResetAll()
        Say("Layout reset" .. (pending and " · after combat" or ""))
    elseif command == "off" or command == "on" then
        API.SetEnabled(command == "on")
        Say(command == "on" and "Layout on" or "Layout off")
    elseif command == "gamepad" then
        -- (`a and f()` would keep only the first return, so the reason was lost.)
        local ok, reason = false, nil
        if API.OpenGamepadSettings then ok, reason = API.OpenGamepadSettings() end
        if not ok and reason then Say(reason) end
    elseif command == "help" or command == "?" then
        for _, line in ipairs(commandHelp) do Say(line) end
    elseif command == "" or command == "options" or command == "config" then
        if API.ToggleOptions then API.ToggleOptions() end
    else
        Say("Unknown command \"" .. command .. "\" · /gpc help")
    end
end

-- Harness access; not part of the public provider contract.
ns.Refresh = Refresh
ns.EventFrame = eventFrame
