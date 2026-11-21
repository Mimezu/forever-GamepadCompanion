-- The pad in the window: a focus ring the d-pad moves, out of combat only.
--
-- Our own ring, not Blizzard's SmartNavigation: SmartNav's tables can't be
-- written without taint (only its secure calls are addon-safe, and only out
-- of combat), and its grid is built from every clickable frame's position,
-- which custom widgets derail (the bag-grid lesson). It also knows nothing of
-- Try or Default. So the window takes the pad's buttons itself, out of combat,
-- one press at a time (each handled press stops there, every other one passes
-- on to the game), and lets go of the pad entirely when a fight starts.
--
-- The d-pad moves to the nearest control that way; A picks (a click); B
-- closes the popup, else the window; X is the focused row's Try, Y its
-- Default; L1 / R1 the side tabs (the focus starts on the new page's first
-- control); L2 / R2 the page's own (Moments: the group). Left / right on a
-- value row (a stepper) change its value. While the pad is in use a legend
-- of glyphs replaces the status line and L1 / R1 glyphs sit at the tab
-- strip's ends; the mouse hides them again.
--
-- Hooks for pages: a control or any frame above it may carry gpcTry /
-- gpcDefault (functions) or .try / .default (buttons: a MomentRow's);
-- gpcFocusSkip = true keeps a frame out of the ring; gpcNudge = fn(dir) makes
-- a frame one value row (focused whole, its own buttons out of the ring, left /
-- right call it with -1 / 1; .enabled = false: skipped); Focus.SetTrigger(page,
-- fn(dir)) gives a page its L2 / R2; Focus.SetProvider(page, fn() -> list of
-- controls) replaces the scan for a page; Focus.OnFocus(fn(control)).
local _, ns = ...
local S, Shell = ns.OptionsSkin, ns.Shell
local Focus = {}
ns.Focus = Focus

local triggers, providers, listeners = {}, {}, {}
function Focus.SetTrigger(page, fn) triggers[page] = fn end
function Focus.SetProvider(page, fn) providers[page] = fn end
function Focus.OnFocus(fn) listeners[#listeners + 1] = fn end

local function Fighting() return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false end
local function Call(f, method, ...)
    if f and type(f[method]) == "function" then return pcall(f[method], f, ...) end
end

---------------------------------------------------------------------------
-- What can take the focus: visible, enabled, clickable, not protected
---------------------------------------------------------------------------
local function Nudger(f) return type(rawget(f, "gpcNudge")) == "function" end

local function Focusable(f)
    if rawget(f, "gpcFocusSkip") then return false end
    if Nudger(f) then
        if rawget(f, "enabled") == false then return false end
        if type(f.IsVisible) == "function" and not f:IsVisible() then return false end
        return not (type(f.GetAlpha) == "function" and (f:GetAlpha() or 1) < 0.05)
    end
    if not (type(f.IsObjectType) == "function" and (f:IsObjectType("Button") or f:IsObjectType("CheckButton"))) then return false end
    if type(f.IsVisible) == "function" and not f:IsVisible() then return false end
    if type(f.IsMouseEnabled) == "function" and not f:IsMouseEnabled() then return false end
    if type(f.IsEnabled) == "function" and not f:IsEnabled() then return false end
    -- (a secure button, or one that runs an action (InsecureActionButtonTemplate: a
    -- type attribute), clicked from here would run tainted: never focused)
    if type(f.IsProtected) == "function" and f:IsProtected() then return false end
    if type(f.GetAttribute) == "function" then
        for _, a in ipairs({ "type", "type1", "*type1", "*type-1", "macrotext", "spell" }) do
            if f:GetAttribute(a) ~= nil then return false end
        end
    end
    if type(f.GetAlpha) == "function" and (f:GetAlpha() or 1) < 0.05 then return false end
    return true
end
Focus.Focusable = Focusable

local function Collect(root, out)
    if not (root and type(root.GetChildren) == "function") then return out end
    for _, child in ipairs({ root:GetChildren() }) do
        if type(child) == "table" and not rawget(child, "gpcFocusSkip") and (type(child.IsShown) ~= "function" or child:IsShown()) then
            if Focusable(child) then out[#out + 1] = child end
            -- (a value row is one stop: its - / + stay the mouse's)
            if not Nudger(child) then Collect(child, out) end
        end
    end
    return out
end

-- The controls in reach now: the top popup's, else the page's (and its header)
function Focus.Controls()
    local top = S.TopPopup and S.TopPopup()
    if top then return Collect(top, {}), top end
    local key = Shell.Current and Shell.Current()
    if key and providers[key] then return providers[key]() or {}, nil end
    -- (both frames: "a and f()" would keep the first only)
    local frame, header
    if Shell.PageFrames then frame, header = Shell.PageFrames(key) end
    local out = Collect(frame, {})
    Collect(header, out)
    -- (the status line's Undo, while it is offered)
    local w = Shell.Window and Shell.Window()
    local offer = w and rawget(w, "offer")
    if offer and Focusable(offer) then out[#out + 1] = offer end
    return out, nil
end

---------------------------------------------------------------------------
-- The next control that way: ahead of the focus, the straightest first
---------------------------------------------------------------------------
local DIRS = { up = { 0, 1 }, down = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
local function Center(f)
    if type(f.GetCenter) ~= "function" then return nil end
    local x, y = f:GetCenter()
    if not (x and y) then return nil end
    local s = type(f.GetEffectiveScale) == "function" and f:GetEffectiveScale() or 1
    return x * s, y * s
end
Focus.Center = Center

-- points: { { x, y, item } }; from: a point; dir: up, down, left, right
function Focus.Pick(points, from, dir)
    local d = DIRS[dir]
    if not (d and from) then return nil end
    local best, bestScore
    for _, p in ipairs(points) do
        if p ~= from then
            local dx, dy = p[1] - from[1], p[2] - from[2]
            local ahead = dx * d[1] + dy * d[2]
            if ahead > 2 then
                local side = math.abs(dx * d[2] - dy * d[1])
                local score = ahead + side * 2.5
                if not bestScore or score < bestScore then best, bestScore = p, score end
            end
        end
    end
    return best
end

-- The first control: the top left
function Focus.First(points)
    local best
    for _, p in ipairs(points) do
        if not best or p[2] > best[2] + 4 or (math.abs(p[2] - best[2]) <= 4 and p[1] < best[1]) then best = p end
    end
    return best
end

---------------------------------------------------------------------------
-- The ring and the legend
---------------------------------------------------------------------------
local ring
local function Ring()
    if ring then return ring end
    ring = CreateFrame("Frame", "GamepadCompanionFocusRing", UIParent)
    ring:SetFrameStrata("FULLSCREEN_DIALOG")
    if ring.EnableMouse then ring:EnableMouse(false) end
    ring.edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
        { "TOPLEFT", "BOTTOMLEFT", 2 }, { "TOPRIGHT", "BOTTOMRIGHT", 2 } }) do
        local t = ring:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 0.82, 0.3, 0.95)
        t:SetPoint(pts[1]); t:SetPoint(pts[2])
        if pts[3] then t:SetWidth(pts[3]) else t:SetHeight(pts[4]) end
        ring.edges[i] = t
    end
    ring.glow = ring:CreateTexture(nil, "BACKGROUND")
    ring.glow:SetAllPoints()
    ring.glow:SetColorTexture(1, 0.8, 0.35, 0.12)
    ring:Hide()
    return ring
end

local state = { focus = nil, active = false }
Focus.state = state

local function Legend(show)
    local w = Shell.Window and Shell.Window()
    if not (w and w.status) then return end
    if not w.padLegend then
        local C = ns.ControllerModel
        local function G(name) return C and C.Glyph and C.Glyph(name, 16) or "" end
        w.padLegend = S.Text(w, "", 0, 0, 640, 12, S.GREY)
        w.padLegend:ClearAllPoints()
        w.padLegend:SetPoint("LEFT", w.status, "LEFT", 0, 0)
        w.padLegend:SetText(G("Shp_Cross") .. " Pick    " .. G("Shp_Circle") .. " Back    " .. G("Shp_Square") .. " Try    "
            .. G("Shp_Triangle") .. " Default    " .. G("Shp_LTrigger") .. G("Shp_RTrigger") .. " Groups")
        -- L1 above the side tabs, R1 below them
        w.padTabUp = S.Text(w, G("Shp_LShoulder"), 0, 0, 24, 12, S.GREY)
        w.padTabDown = S.Text(w, G("Shp_RShoulder"), 0, 0, 24, 12, S.GREY)
    end
    local first, last
    if Shell.TabEnds then first, last = Shell.TabEnds() end
    for _, e in ipairs({ { w.padTabUp, first, "BOTTOM", "TOP", 4 }, { w.padTabDown, last, "TOP", "BOTTOM", -4 } }) do
        e[1]:ClearAllPoints()
        if e[2] then e[1]:SetPoint(e[3], e[2], e[4], 0, e[5]) end
        e[1]:SetShown(show and e[2] ~= nil)
    end
    -- (after the Undo when one is offered, not over it)
    local offer = rawget(w, "offer")
    w.padLegend:ClearAllPoints()
    if offer and offer:IsShown() then w.padLegend:SetPoint("LEFT", offer, "RIGHT", 14, 0)
    else w.padLegend:SetPoint("LEFT", w.status, "LEFT", 0, 0) end
    w.padLegend:SetShown(show)
    w.status:SetAlpha(show and 0 or 1)
    if w.statusDot then w.statusDot:SetAlpha(show and 0 or 1) end
end

function Focus.Set(control)
    state.focus = control
    local r = Ring()
    if not (control and state.active) then r:Hide(); return end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", control, "TOPLEFT", -3, 3)
    r:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", 3, -3)
    r:Show()
    for _, fn in ipairs(listeners) do pcall(fn, control) end
end

function Focus.Relayout() if state.active then Legend(true) end end

-- the pad in use (a press) or not (the mouse, the window gone, a fight)
function Focus.SetActive(on)
    state.active = on and true or false
    Legend(state.active)
    if not state.active then Ring():Hide() else Focus.Set(state.focus) end
end

---------------------------------------------------------------------------
-- The presses
---------------------------------------------------------------------------
local function Points()
    local controls = Focus.Controls()
    local pts = {}
    for _, c in ipairs(controls) do
        local x, y = Center(c)
        if x then pts[#pts + 1] = { x, y, c } end
    end
    return pts
end

local function Valid(c)
    if not c then return false end
    for _, x in ipairs((Focus.Controls())) do if x == c then return true end end
    return false
end

local NUDGE = { left = -1, right = 1 }
local function Move(dir)
    local f = state.focus
    if NUDGE[dir] and f and Nudger(f) and Valid(f) then f.gpcNudge(NUDGE[dir]); return end
    local pts = Points()
    local from
    -- (a focus not among the points leaves from nil)
    for _, p in ipairs(pts) do if p[3] == state.focus then from = p end end
    local to = from and Focus.Pick(pts, from, dir) or Focus.First(pts)
    if to then Focus.Set(to[3]) end
end

-- X and Y: the focused control's row (a frame above it) decides
local function RowAction(which)
    local f = state.focus
    while f do
        local fn = rawget(f, which == "try" and "gpcTry" or "gpcDefault")
        if type(fn) == "function" then fn(); return true end
        local b = rawget(f, which)
        if type(b) == "table" and type(b.Click) == "function" and (type(b.IsShown) ~= "function" or b:IsShown())
            and (type(b.IsEnabled) ~= "function" or b:IsEnabled()) then
            b:Click(); return true
        end
        f = type(f.GetParent) == "function" and f:GetParent() or nil
    end
    return false
end

local ACTIONS = {
    PADDUP = function() Move("up") end, PADDDOWN = function() Move("down") end,
    PADDLEFT = function() Move("left") end, PADDRIGHT = function() Move("right") end,
    PAD1 = function()
        local f = state.focus
        if not Valid(f) then Move("down")
        elseif type(f.Click) == "function" then f:Click() end
    end,
    PAD2 = function()
        local top = S.TopPopup and S.TopPopup()
        if top then top:Hide() else local w = Shell.Window(); if w then w:Hide() end end
    end,
    PAD3 = function() RowAction("try") end,
    PAD4 = function() RowAction("default") end,
    PADLTRIGGER = function() local t = triggers[Shell.Current()]; if t then t(-1); Focus.Set(nil) end end,
    PADRTRIGGER = function() local t = triggers[Shell.Current()]; if t then t(1); Focus.Set(nil) end end,
}
Focus.ACTIONS = ACTIONS

local DPAD = { PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true }
local SHOULDER = { PADLSHOULDER = -1, PADRSHOULDER = 1 }

-- (the mouse moved since the last press: the player is back on the mouse)
local function Cursor()
    if type(GetCursorPosition) ~= "function" then return nil end
    return GetCursorPosition()
end
local function MouseMoved()
    local x, y = Cursor()
    if not (x and state.cx) then return false end
    return math.abs(x - state.cx) + math.abs(y - state.cy) > 6
end

-- One press: handled here (it stops) or passed on to the game. Never in combat.
-- Nothing is taken until the d-pad engages the ring: the window open, the pad
-- still plays. Once engaged: A, B, X, Y and the d-pad; L2 / R2 only where the
-- page uses them; L1 / R1 never taken (they step the tabs when released, unless
-- the touchpad came with them: Blizzard's Focus UI chord). Any other button,
-- or the mouse moved, gives it all back.
function Focus.Press(frame, button)
    if Fighting() then return false end
    if state.active and MouseMoved() then Focus.SetActive(false) end
    if SHOULDER[button] then
        if state.active then state.shoulder, state.chord = button, false end
        return false
    end
    -- (the touchpad: part of a chord, the game's; the ring stays)
    if button == "PADBACK" then state.chord = true; return false end
    local act = ACTIONS[button]
    if not act then
        if state.active then Focus.SetActive(false) end
        return false
    end
    if not state.active and not DPAD[button] then return false end
    if (button == "PADLTRIGGER" or button == "PADRTRIGGER") and not triggers[Shell.Current()] then return false end
    -- (this press stops here; from the next frame on, presses pass again)
    Call(frame, "SetPropagateKeyboardInput", false)
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, function() if not Fighting() then Call(frame, "SetPropagateKeyboardInput", true) end end)
    end
    if not state.active then Focus.SetActive(true) end
    state.cx, state.cy = Cursor()
    act()
    if state.active and state.focus then Focus.Set(state.focus) end
    return true
end

-- L1 / R1 released: the side tabs, unless the touchpad came with them
function Focus.Release(button)
    local dir = SHOULDER[button]
    if not dir or state.shoulder ~= button then return end
    local chord = state.chord
    state.shoulder, state.chord = nil, false
    if chord or Fighting() or not state.active then return end
    if Shell.Step then Shell.Step(dir) end
    -- (the new page's first control, once its frames have their places)
    Focus.Set(nil)
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then C_Timer.After(0, Focus.Rescope)
    else Focus.Rescope() end
end

-- A popup opened or closed: the focus starts again where the pad can reach
function Focus.Rescope()
    if not state.active then return end
    state.focus = nil
    local first = Focus.First(Points())
    Focus.Set(first and first[3] or nil)
end

-- The window takes the pad's buttons while open, out of combat
function Focus.Attach(window)
    local function Take(on)
        if on and Fighting() then on = false end
        if on then Call(window, "SetPropagateKeyboardInput", true) end
        Call(window, "EnableGamePadButton", on)
        state.taking = on
    end
    window:HookScript("OnShow", function() Take(true) end)
    window:HookScript("OnHide", function() Take(false); Focus.SetActive(false); state.focus = nil end)
    window:SetScript("OnGamePadButtonDown", function(self, button) Focus.Press(self, button) end)
    window:SetScript("OnGamePadButtonUp", function(_, button) Focus.Release(button) end)
    local events = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GLOBAL_MOUSE_DOWN" }) do
        pcall(events.RegisterEvent, events, e)
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then Take(false); Focus.SetActive(false)
        elseif event == "PLAYER_REGEN_ENABLED" then if window:IsShown() then Take(true) end
        elseif state.active then Focus.SetActive(false) end
    end)
end

if S.OnPopupChange then S.OnPopupChange(function() Focus.Rescope() end) end

-- Moments: L2 / R2 step through the groups
Focus.SetTrigger("moments", function(dir)
    local b = ns.RumblePage and ns.RumblePage.browser
    if b and b.Step then b.Step(dir) end
end)
