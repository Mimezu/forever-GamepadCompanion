-- HelperLink: signals the outside helper (WowHelper.exe, C:\games\WowHelper) through a
-- strip of coloured cells at the screen's bottom-left corner. Addons can't use files,
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
-- Protocol v2 (C:\games\WowHelper\docs\PROTOCOL-V2.md): 34 cells, magenta then
-- cyan, 96 bits: seq, both triggers, touch (12: 1-127 built-in clips,
-- 128-4095 the addon's feels in HD), sound (12), gain, level, side,
-- intensity, seed, the mic LED, and a CRC-8 (poly 0x07) over bits 0-87.
---------------------------------------------------------------------------
K.CELLS_V2 = 34
K.MARKERS_V2 = { { 1, 0, 1 }, { 0, 1, 1 } }   -- magenta, cyan
K.MIC = { leave = 0, off = 1, on = 2, pulse = 3 }

-- (bytes XORed without the bit library: tests run in plain Lua 5.1)
local function BXor(a, b)
    local r, m = 0, 1
    while a > 0 or b > 0 do
        if a % 2 ~= b % 2 then r = r + m end
        a, b, m = floor(a / 2), floor(b / 2), m * 2
    end
    return r
end

-- CRC-8, poly 0x07, init 0, not reflected
function K.Crc8(bytes)
    local crc = 0
    for _, byte in ipairs(bytes) do
        crc = BXor(crc, byte)
        for _ = 1, 8 do
            if crc >= 128 then crc = BXor((crc * 2) % 256, 0x07) else crc = (crc * 2) % 256 end
        end
    end
    return crc
end

local function CrcOfBits(bits)
    local bytes = {}
    for k = 0, 10 do bytes[k + 1] = Get(bits, k * 8, 8) end
    return K.Crc8(bytes)
end

-- state = { seq, left, right, touch, sound, gain, level, side, intensity, seed, mic, moment, open }
-- -> 34 cells { r, g, b } of 0 / 1.
function K.EncodeV2(state)
    state = state or {}
    local bits = {}
    Put(bits, 0, Int(state.seq, 1e9) % 16, 4)
    PutTrigger(bits, 4, state.left)
    PutTrigger(bits, 19, state.right)
    Put(bits, 34, Int(state.touch, 4095), 12)
    Put(bits, 46, Int(state.sound, 4095), 12)
    Put(bits, 58, Int(state.gain, 7), 3)
    Put(bits, 61, Int(state.level, 3), 2)
    Put(bits, 63, Int(state.side, 15), 4)
    Put(bits, 67, Int(state.intensity, 7), 3)
    Put(bits, 70, Int(state.seed, 255), 8)
    Put(bits, 78, Int(state.mic, 3), 2)
    Put(bits, 80, Int(state.moment, 127), 7)
    Put(bits, 87, state.open and 1 or 0, 1)
    Put(bits, 88, CrcOfBits(bits), 8)
    local cells = { { 1, 0, 1 }, { 0, 1, 1 } }
    for c = 0, 31 do cells[#cells + 1] = { bits[c * 3], bits[c * 3 + 1], bits[c * 3 + 2] } end
    return cells
end

function K.DecodeV2(cells)
    if type(cells) ~= "table" or #cells ~= K.CELLS_V2 then return nil, "length" end
    for i = 1, 2 do
        local c, m = cells[i], K.MARKERS_V2[i]
        if c[1] ~= m[1] or c[2] ~= m[2] or c[3] ~= m[3] then return nil, "marker" end
    end
    local bits = {}
    for c = 0, 31 do
        local cell = cells[c + 3]
        for k = 1, 3 do
            local v = cell[k]
            if v ~= 0 and v ~= 1 then return nil, "value" end
            bits[c * 3 + k - 1] = v
        end
    end
    if CrcOfBits(bits) ~= Get(bits, 88, 8) then return nil, "crc" end
    return { seq = Get(bits, 0, 4), left = GetTrigger(bits, 4), right = GetTrigger(bits, 19),
        touch = Get(bits, 34, 12), sound = Get(bits, 46, 12), gain = Get(bits, 58, 3), level = Get(bits, 61, 2),
        side = Get(bits, 63, 4), intensity = Get(bits, 67, 3), seed = Get(bits, 70, 8), mic = Get(bits, 78, 2),
        moment = Get(bits, 80, 7), open = Get(bits, 87, 1) == 1 }
end

---------------------------------------------------------------------------
-- The light row (C:\games\WowHelper\docs\LIGHTS.md section 4): 17 cells one
-- row inward of the v2 strip (above it here: the bottom-left corner), yellow
-- first, 48 bits: version, resting, hold (8), its tint (5) and strength (3),
-- progress (4), cue (8), its tint and strength, a CRC-8 over bits 0-39.
---------------------------------------------------------------------------
K.LIGHT_CELLS = 17
K.LIGHT_MARKER = { 1, 1, 0 }   -- yellow

-- row = { version, resting, hold, holdTint, holdStrength, progress, cue, cueTint, cueStrength }
function K.EncodeLight(row)
    row = row or {}
    local bits = {}
    for i = 0, 47 do bits[i] = 0 end
    Put(bits, 0, Int(row.version, 3), 2)
    Put(bits, 2, row.resting and 1 or 0, 1)
    Put(bits, 4, Int(row.hold, 255), 8)
    Put(bits, 12, Int(row.holdTint, 31), 5)
    Put(bits, 17, Int(row.holdStrength, 7), 3)
    Put(bits, 20, Int(row.progress, 15), 4)
    Put(bits, 24, Int(row.cue, 255), 8)
    Put(bits, 32, Int(row.cueTint, 31), 5)
    Put(bits, 37, Int(row.cueStrength, 7), 3)
    local bytes = {}
    for k = 0, 4 do bytes[k + 1] = Get(bits, k * 8, 8) end
    Put(bits, 40, K.Crc8(bytes), 8)
    local cells = { { 1, 1, 0 } }
    for c = 0, 15 do cells[#cells + 1] = { bits[c * 3], bits[c * 3 + 1], bits[c * 3 + 2] } end
    return cells
end

function K.DecodeLight(cells)
    if type(cells) ~= "table" or #cells ~= K.LIGHT_CELLS then return nil, "length" end
    local m = cells[1]
    if m[1] ~= 1 or m[2] ~= 1 or m[3] ~= 0 then return nil, "marker" end
    local bits = {}
    for c = 0, 15 do
        for k = 1, 3 do
            local v = cells[c + 2][k]
            if v ~= 0 and v ~= 1 then return nil, "value" end
            bits[c * 3 + k - 1] = v
        end
    end
    local bytes = {}
    for k = 0, 4 do bytes[k + 1] = Get(bits, k * 8, 8) end
    if K.Crc8(bytes) ~= Get(bits, 40, 8) then return nil, "crc" end
    return { version = Get(bits, 0, 2), resting = Get(bits, 2, 1) == 1, hold = Get(bits, 4, 8),
        holdTint = Get(bits, 12, 5), holdStrength = Get(bits, 17, 3), progress = Get(bits, 20, 4),
        cue = Get(bits, 24, 8), cueTint = Get(bits, 32, 5), cueStrength = Get(bits, 37, 3) }
end

---------------------------------------------------------------------------
-- Live state and the event queue
---------------------------------------------------------------------------
local function OffTrigger() return { mode = 0, start = 0, finish = 0, force = 0 } end
K.state = { seq = 0, left = OffTrigger(), right = OffTrigger(), event = 0, gain = 0,
    touch = 0, sound = 0, level = 0, side = 0, intensity = 4, seed = 0, mic = 0, moment = 0, open = false }
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

-- v2 (the wide strip) unless set back to v1 (the Helper page)
function K.V2() return DB().v1 ~= true end
function K.SetV2(on)
    DB().v1 = not on or nil
    K.Layout()
    dirty = true
    if ns.Lights and ns.Lights.LinkChanged then ns.Lights.LinkChanged() end
end
K.MarkDirty = function() dirty = true end

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

local function Queue(item)
    if not K.Enabled() or #K.queue >= K.QUEUE_MAX then return false end
    K.queue[#K.queue + 1] = item
    return true
end

-- A built-in touch clip (1-127, or a K.CLIPS name); gain 0..7 (default 4). Touch only: sounds
-- go through K.PlaySound, HD feels through K.PlayFeel / K.Cue (the id spaces never mix).
function K.Play(clip, gain)
    if type(clip) == "string" then clip = K.CLIPS[clip] end
    clip = Int(clip, 4095)
    if clip < 1 or clip > 127 then return false end
    return Queue({ touch = clip, sound = 0, gain = Int(gain == nil and 4 or gain, 7) })
end

-- A sound on the pad's speaker with its own paired touch: a WoW Helper library id (1-4095) or a
-- K.SOUNDS name; gain 0..7; moment: its number (v2), if any. (v1 carries ids up to 255.)
function K.PlaySound(sound, gain, moment)
    if type(sound) == "string" then sound = K.SOUNDS[sound] end
    sound = Int(sound, 4095)
    if sound == 0 then return false end
    return Queue({ touch = 0, sound = sound, gain = Int(gain == nil and 4 or gain, 7), moment = Int(moment, 127) })
end

-- One of the addon's feels in HD (v2): its id (128-4095), gain 0-7, side
-- -1..1 (nil: the feel's own), intensity 0-7 (4: as designed)
function K.PlayFeel(hdId, gain, side, intensity)
    if not K.V2() then return false end
    hdId = Int(hdId, 4095)
    if hdId < 128 then return false end
    local s = side and Int(8 + side * 7, 15) or 0
    if side and s == 0 then s = 1 end
    return Queue({ touch = hdId, sound = 0, gain = Int(gain == nil and 4 or gain, 7), side = s,
        intensity = intensity and Int(intensity, 7) or 4 })
end

-- A moment's cue (v2): its HD feel and sound in one, with the moment's number
-- (1-127) so WoW Helper knows what played; open: also open it in WoW Helper.
-- item = { moment, touch, sound, gain, intensity, open }
-- A swing marker (Timing, WoW Helper's src/calib.rs): moment 110-126, side =
-- race id, seed = sex bit and the addon's delay, level = result, with or
-- without the hit's touch and sound (WoW Helper times them). Shown ahead of
-- waiting cues: its moment on screen is the swing's news.
K.MARKER_FIRST, K.MARKER_LAST = 110, 126
function K.Marker(item)
    if not (K.Enabled() and K.V2()) then return false end
    local m = Int(item.moment, 127)
    if m < K.MARKER_FIRST or m > K.MARKER_LAST then return false end
    local touch = Int(item.touch, 4095)
    if touch > 0 and touch < 128 then touch = 0 end
    table.insert(K.queue, 1, { touch = touch, sound = Int(item.sound, 4095), gain = Int(item.gain == nil and 4 or item.gain, 7),
        intensity = item.intensity and Int(item.intensity, 7) or 4, moment = m, side = Int(item.side, 15),
        seed = Int(item.seed, 255), level = Int(item.level, 3) })
    while #K.queue > K.QUEUE_MAX do table.remove(K.queue) end
    return true
end

function K.Cue(item)
    if not K.V2() then return false end
    local touch, sound = Int(item.touch, 4095), Int(item.sound, 4095)
    if touch > 0 and touch < 128 then touch = 0 end
    if touch == 0 and sound == 0 and not item.open then return false end
    return Queue({ touch = touch, sound = sound, gain = Int(item.gain == nil and 4 or item.gain, 7),
        intensity = item.intensity and Int(item.intensity, 7) or 4, moment = Int(item.moment, 127),
        open = item.open and true or false })
end

-- The mic LED (v2): "leave", "off", "on", "pulse"
function K.SetMic(mode)
    local m = K.MIC[mode] or 0
    if K.state.mic ~= m then K.state.mic = m; dirty = true end
end

-- The light row's state (Lights.lua): what holds { hold, holdTint,
-- holdStrength, progress, resting }, or nil: no light row (the game's lights)
K.light = nil
function K.SetLight(row)
    local cur = K.light
    if row == nil then
        if cur then K.light = nil; dirty = true end
        return
    end
    cur = cur or {}
    local same = cur.hold == row.hold and cur.holdTint == row.holdTint and cur.holdStrength == row.holdStrength
        and cur.progress == row.progress and (cur.resting or false) == (row.resting or false)
    if same and K.light then return end
    K.light = { hold = row.hold or 0, holdTint = row.holdTint or 0, holdStrength = row.holdStrength or 0,
        progress = row.progress or 0, resting = row.resting or false, cue = 0, cueTint = 0, cueStrength = 0 }
    dirty = true
end

-- A once light on the pad (v2 + the light row): its id 1-255, tint 0-31, strength 0-7
function K.LightCue(id, tint, strength)
    if not K.V2() then return false end
    id = Int(id, 255)
    if id == 0 then return false end
    if not K.light then K.SetLight({ hold = 0 }) end
    return Queue({ touch = 0, sound = 0, light = { id, Int(tint, 31), Int(strength, 7) } })
end

local function Start(item)
    local s = K.state
    s.seq = (s.seq + 1) % 16
    s.touch, s.sound, s.gain = item.touch or 0, item.sound or 0, item.gain or 4
    s.side, s.intensity, s.level = item.side or 0, item.intensity or 4, item.level or 0
    s.moment, s.open = item.moment or 0, item.open or false
    s.seed = item.seed or (math.random and math.random(0, 255) or 0)
    if K.light then
        local c = item.light
        K.light.cue, K.light.cueTint, K.light.cueStrength = c and c[1] or 0, c and c[2] or 0, c and c[3] or 0
    end
    -- (v1: one event id, a clip or a sound up to 255)
    local v1 = s.sound ~= 0 and s.sound or s.touch
    s.event = v1 <= 255 and v1 or 0
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
                local s = K.state
                s.event, s.gain, s.touch, s.sound = 0, 0, 0, 0   -- (seq kept: no new event)
                s.moment, s.open = 0, false
                if K.light then K.light.cue, K.light.cueTint, K.light.cueStrength = 0, 0, 0 end
                dirty = true
            end
        end
    elseif #K.queue > 0 then
        Start(table.remove(K.queue, 1))
    end
    if dirty then
        dirty = false
        if K.Draw then K.Draw(K.V2() and K.EncodeV2(K.state) or K.Encode(K.state)) end
        if K.DrawLight then K.DrawLight(K.V2() and K.light and K.EncodeLight(K.light) or nil) end
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
    frame:SetPoint("BOTTOMLEFT", nil, "BOTTOMLEFT", 0, 0)
    local n = K.V2() and K.CELLS_V2 or K.CELLS
    frame:SetSize(unit * n, unit)
    for i, tex in ipairs(textures) do
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, 0)
        tex:SetSize(unit, unit)
        tex:SetShown(i <= n)
    end
    -- the light row: one row up (inward from the bottom-left corner)
    for i, tex in ipairs(K.lightTextures or {}) do
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, unit)
        tex:SetSize(unit, unit)
    end
end

-- The light row's cells, or nil: hidden (no row: the game's lights)
function K.DrawLight(cells)
    for i, tex in ipairs(K.lightTextures or {}) do
        local c = cells and cells[i]
        if c then tex:SetColorTexture(c[1], c[2], c[3], 1) end
        tex:SetShown(c ~= nil)
    end
end

function K.Draw(cells)
    if not textures then return end
    for i, tex in ipairs(textures) do
        local c = cells[i]
        if c then tex:SetColorTexture(c[1], c[2], c[3], 1) end
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
    for i = 1, K.CELLS_V2 do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        textures[i] = tex
    end
    K.lightTextures = {}
    for i = 1, K.LIGHT_CELLS do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex:Hide()
        K.lightTextures[i] = tex
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
        K.state.event, K.state.gain, K.state.touch, K.state.sound = 0, 0, 0, 0
        K.state.left, K.state.right = OffTrigger(), OffTrigger()
        dirty = true
    end
    K.Refresh()
    if ns.Lights and ns.Lights.LinkChanged then ns.Lights.LinkChanged() end
end

Build()
