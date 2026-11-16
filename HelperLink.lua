-- HelperLink: signals the outside helper (helper/gpc_helper.py) through a strip
-- of coloured cells at the screen's top-left corner. Addons can't use files,
-- the network or processes live, so the helper reads these pixels and drives
-- the DualSense's adaptive triggers and true haptics (USB audio channels 3-4).
-- docs/HELPER.md is the protocol, the single source of truth.
--
-- Pure part (testable): K.Encode / K.Decode. Live part: one parentless
-- TOOLTIP-strata frame, shown only while the link is on, redrawn on change.
local addonName, ns = ...
local K = {}
ns.HelperLink = K

local floor = math.floor

K.CELLS = 18           -- 2 markers + 16 data cells
K.CELL = 4             -- cell size in physical pixels (default)
K.MIN_FRAMES = 3       -- an event stays on screen at least this many frames
K.MIN_TIME = 0.05      -- and at least this long (s): a 60 Hz reader sees it 3 times
K.QUEUE_MAX = 8        -- events waiting beyond this are dropped

K.MARKERS = { { 1, 0, 1 }, { 0, 1, 0 } }   -- magenta, green

-- Trigger modes (3 bits).
K.MODES = {
    off = 0,      -- no effect
    resist = 1,   -- resistance from start on (force)
    section = 2,  -- resistance between start and finish (force)
    weapon = 3,   -- a click between start and finish (force)
    vibrate = 4,  -- vibration from start on: finish = amplitude, force = frequency
    slope = 5,    -- resistance rising from start to finish, up to force (progress)
}

-- Event ids: 1-127 haptic clips (channels 3-4), 128-255 speaker sounds (1-2).
-- Names match helper/clips.py (its selftest checks this file).
K.CLIPS = {
    micro_tap = 1,
    micro_tap_left = 2,
    micro_tap_right = 3,
    thump = 4,
    heartbeat = 5,
    crackle = 6,
    rumble_rise = 7,
    release_hit = 8,
    swing_light = 9,
    swing_heavy = 10,
    landing_soft = 11,
    landing_hard = 12,
}
K.SOUNDS = {
    click = 128,
    coin = 129,
    chime = 130,
    thud = 131,
    heartbeat_thump = 132,
    error = 133,
}

---------------------------------------------------------------------------
-- Encode / decode (pure)
---------------------------------------------------------------------------
local function Int(v, hi)
    v = floor((tonumber(v) or 0) + 0.5)
    if v < 0 then return 0 elseif v > hi then return hi end
    return v
end

local function Put(bits, pos, value, n)
    for i = 0, n - 1 do
        bits[pos + i] = value % 2
        value = floor(value / 2)
    end
end

local function Get(bits, pos, n)
    local v, m = 0, 1
    for i = 0, n - 1 do
        v = v + bits[pos + i] * m
        m = m * 2
    end
    return v
end

local function Xor3(a, b)
    local r, m = 0, 1
    for _ = 1, 3 do
        if a % 2 ~= b % 2 then r = r + m end
        a, b, m = floor(a / 2), floor(b / 2), m * 2
    end
    return r
end

local function PutTrigger(bits, pos, t)
    t = type(t) == "table" and t or {}
    Put(bits, pos, Int(t.mode, 7), 3)
    Put(bits, pos + 3, Int(t.start, 15), 4)
    Put(bits, pos + 7, Int(t.finish, 15), 4)
    Put(bits, pos + 11, Int(t.force, 15), 4)
end

local function GetTrigger(bits, pos)
    return { mode = Get(bits, pos, 3), start = Get(bits, pos + 3, 4),
        finish = Get(bits, pos + 7, 4), force = Get(bits, pos + 11, 4) }
end

local function Checksum(bits)
    local x = 0
    for g = 0, 14 do x = Xor3(x, Get(bits, g * 3, 3)) end
    return x
end

-- state = { seq, left = {mode, start, finish, force}, right = {...}, event, gain }
-- -> 18 cells { r, g, b } of 0 / 1.
function K.Encode(state)
    state = state or {}
    local bits = {}
    Put(bits, 0, Int(state.seq, 1e9) % 16, 4)
    PutTrigger(bits, 4, state.left)
    PutTrigger(bits, 19, state.right)
    Put(bits, 34, Int(state.event, 255), 8)
    Put(bits, 42, Int(state.gain, 7), 3)
    Put(bits, 45, Checksum(bits), 3)
    local cells = { { 1, 0, 1 }, { 0, 1, 0 } }
    for c = 0, 15 do cells[#cells + 1] = { bits[c * 3], bits[c * 3 + 1], bits[c * 3 + 2] } end
    return cells
end

-- 18 cells -> state, or nil and a reason.
function K.Decode(cells)
    if type(cells) ~= "table" or #cells ~= K.CELLS then return nil, "length" end
    for i = 1, 2 do
        local c, m = cells[i], K.MARKERS[i]
        if c[1] ~= m[1] or c[2] ~= m[2] or c[3] ~= m[3] then return nil, "marker" end
    end
    local bits = {}
    for c = 0, 15 do
        local cell = cells[c + 3]
        for k = 1, 3 do
            local v = cell[k]
            if v ~= 0 and v ~= 1 then return nil, "value" end
            bits[c * 3 + k - 1] = v
        end
    end
    if Checksum(bits) ~= Get(bits, 45, 3) then return nil, "checksum" end
    return { seq = Get(bits, 0, 4), left = GetTrigger(bits, 4), right = GetTrigger(bits, 19),
        event = Get(bits, 34, 8), gain = Get(bits, 42, 3) }
end

---------------------------------------------------------------------------
-- Live state and the event queue
---------------------------------------------------------------------------
local function OffTrigger() return { mode = 0, start = 0, finish = 0, force = 0 } end
K.state = { seq = 0, left = OffTrigger(), right = OffTrigger(), event = 0, gain = 0 }
K.queue = {}
local active          -- an event is on screen
local frames, age = 0, 0
local dirty = true

local function DB()
    if type(GamepadCompanionHapticsDB) ~= "table" then GamepadCompanionHapticsDB = {} end
    local db = GamepadCompanionHapticsDB
    if type(db.link) ~= "table" then db.link = {} end
    return db.link
end

function K.Enabled() return DB().on == true end

local function Side(side)
    if side == "left" or side == "L" or side == "L2" or side == 1 then return "left" end
    if side == "right" or side == "R" or side == "R2" or side == 2 then return "right" end
end

-- mode: number or a K.MODES name; values 0..15.
function K.SetTrigger(side, mode, start, finish, force)
    side = Side(side)
    if not side then return end
    if type(mode) == "string" then mode = K.MODES[mode] end
    local t = { mode = Int(mode, 7), start = Int(start, 15), finish = Int(finish, 15), force = Int(force, 15) }
    local cur = K.state[side]
    if cur.mode == t.mode and cur.start == t.start and cur.finish == t.finish and cur.force == t.force then return end
    K.state[side] = t
    dirty = true
end

-- eventId: number or a name from K.CLIPS / K.SOUNDS; gain 0..7 (default 4).
function K.Play(eventId, gain)
    if type(eventId) == "string" then eventId = K.CLIPS[eventId] or K.SOUNDS[eventId] end
    eventId = Int(eventId, 255)
    if eventId == 0 or not K.Enabled() then return false end
    if #K.queue >= K.QUEUE_MAX then return false end
    K.queue[#K.queue + 1] = { eventId, Int(gain == nil and 4 or gain, 7) }
    return true
end

local function Start(item)
    local s = K.state
    s.seq = (s.seq + 1) % 16
    s.event, s.gain = item[1], item[2]
    active, frames, age, dirty = true, 0, 0, true
end

-- One frame: the event queue (each event on screen >= MIN_FRAMES frames and
-- >= MIN_TIME), then a redraw if anything changed. Returns true on redraw.
function K.Step(elapsed)
    if active then
        frames, age = frames + 1, age + (elapsed or 0)   -- (the last frame was drawn with it)
        if frames >= K.MIN_FRAMES and age >= K.MIN_TIME then
            if #K.queue > 0 then
                Start(table.remove(K.queue, 1))
            else
                active = false
                K.state.event, K.state.gain = 0, 0   -- (seq kept: no new event)
                dirty = true
            end
        end
    elseif #K.queue > 0 then
        Start(table.remove(K.queue, 1))
    end
    if dirty then
        dirty = false
        if K.Draw then K.Draw(K.Encode(K.state)) end
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- The strip
---------------------------------------------------------------------------
local frame, textures

local function PixelUnit()
    -- One physical pixel in this frame's units (as Blizzard's PixelUtil: 768 / height).
    local h = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize())
    if not h or h <= 0 then h = 768 end
    local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    if not scale or scale <= 0 then scale = 1 end
    return (768 / h) / scale
end
K.PixelUnit = PixelUnit

function K.CellSize()
    local s = tonumber(DB().cell)
    if not s or s < 1 or s > 16 then s = K.CELL end
    return floor(s)
end

function K.SetCellSize(px)
    DB().cell = Int(px, 16)
    K.Layout()
end

function K.Layout()
    if not frame then return end
    local unit = PixelUnit() * K.CellSize()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", nil, "TOPLEFT", 0, 0)
    frame:SetSize(unit * K.CELLS, unit)
    for i, tex in ipairs(textures) do
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", (i - 1) * unit, 0)
        tex:SetSize(unit, unit)
    end
end

function K.Draw(cells)
    if not textures then return end
    for i, tex in ipairs(textures) do
        local c = cells[i]
        tex:SetColorTexture(c[1], c[2], c[3], 1)
    end
end

local function Build()
    if frame or not CreateFrame then return end
    frame = CreateFrame("Frame", "GamepadCompanionHelperLink", nil)
    frame:SetFrameStrata("TOOLTIP")
    if frame.SetFrameLevel then frame:SetFrameLevel(10000) end
    frame:SetScale(1)
    if frame.SetIgnoreParentScale then frame:SetIgnoreParentScale(true) end
    textures = {}
    for i = 1, K.CELLS do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        textures[i] = tex
    end
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, elapsed) K.Step(elapsed) end)
    frame:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then
            if name == addonName then K.Refresh() end
        else
            K.Layout()
        end
    end)
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    K.frame = frame
    K.Layout()
end

-- Show or hide the strip from the saved switch.
function K.Refresh()
    Build()
    if not frame then return end
    if K.Enabled() then
        dirty = true
        K.Layout()
        frame:Show()
        K.Step(0)
    else
        frame:Hide()
    end
end

function K.SetEnabled(on)
    DB().on = on and true or false
    if not on then
        for i = #K.queue, 1, -1 do K.queue[i] = nil end
        active = false
        K.state.event, K.state.gain = 0, 0
        K.state.left, K.state.right = OffTrigger(), OffTrigger()
        dirty = true
    end
    K.Refresh()
end

Build()
