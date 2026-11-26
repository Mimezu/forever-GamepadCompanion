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
K.LIGHT_CELLS = 17      -- version 0
K.LIGHT_CELLS_V1 = 23   -- version 1: each light's dots and mic too
K.LIGHT_MARKER = { 1, 1, 0 }   -- yellow

-- CRC-8 over bits 0..n-1 (bytes padded with zero bits)
local function CrcBits(bits, n)
    local bytes = {}
    for k = 0, math.ceil(n / 8) - 1 do bytes[k + 1] = Get(bits, k * 8, math.min(8, n - k * 8)) end
    return K.Crc8(bytes)
end

-- The light row as drawn: the lights' own (K.light) with the HD switch on bit 3; while HD
-- is off, a row is drawn even without lights, so WoW Helper knows (HD-RELEASE.md)
function K.HDOff()
    local C = ns.HelperCues
    return C ~= nil and C.HDMode ~= nil and C.HDMode() == "off"
end
local bare = {}
function K.LightRow()
    local off = K.HDOff()
    local row = K.light
    if not row then
        if not off then return nil end
        row = bare
    end
    row.hdOff = off or nil
    return row
end
-- row = { version, resting, hold, holdTint, holdStrength, progress, cue, cueTint, cueStrength,
--   (version 1:) holdDots, holdMic, cueDots, cueMic }: 17 cells (version 0) or 23 (version 1)
function K.EncodeLight(row)
    row = row or {}
    local v1 = (tonumber(row.version) or 0) >= 1
    local bits = {}
    for i = 0, 65 do bits[i] = 0 end
    Put(bits, 0, v1 and 1 or 0, 2)
    Put(bits, 2, row.resting and 1 or 0, 1)
    -- (bit 3: the addon's HD feels off: WoW Helper then leaves the game's rumble alone;
    -- WowHelper docs/HD-RELEASE.md)
    Put(bits, 3, row.hdOff and 1 or 0, 1)
    Put(bits, 4, Int(row.hold, 255), 8)
    Put(bits, 12, Int(row.holdTint, 31), 5)
    Put(bits, 17, Int(row.holdStrength, 7), 3)
    Put(bits, 20, Int(row.progress, 15), 4)
    Put(bits, 24, Int(row.cue, 255), 8)
    Put(bits, 32, Int(row.cueTint, 31), 5)
    Put(bits, 37, Int(row.cueStrength, 7), 3)
    local data = 16
    if v1 then
        Put(bits, 40, Int(row.holdDots, 15), 4)
        Put(bits, 44, Int(row.holdMic, 7), 3)
        Put(bits, 47, Int(row.cueDots, 15), 4)
        Put(bits, 51, Int(row.cueMic, 7), 3)
        Put(bits, 58, CrcBits(bits, 58), 8)
        data = 22
    else
        Put(bits, 40, CrcBits(bits, 40), 8)
    end
    local cells = { { 1, 1, 0 } }
    for c = 0, data - 1 do cells[#cells + 1] = { bits[c * 3], bits[c * 3 + 1], bits[c * 3 + 2] } end
    return cells
end

function K.DecodeLight(cells)
    if type(cells) ~= "table" or #cells < K.LIGHT_CELLS then return nil, "length" end
    local m = cells[1]
    if m[1] ~= 1 or m[2] ~= 1 or m[3] ~= 0 then return nil, "marker" end
    local v1 = cells[2][1] == 1 and cells[2][2] == 0
    local n = v1 and K.LIGHT_CELLS_V1 or K.LIGHT_CELLS
    if #cells < n then return nil, "length" end
    local bits = {}
    for c = 0, n - 2 do
        for k = 1, 3 do
            local v = cells[c + 2][k]
            if v ~= 0 and v ~= 1 then return nil, "value" end
            bits[c * 3 + k - 1] = v
        end
    end
    local at = v1 and 58 or 40
    if CrcBits(bits, at) ~= Get(bits, at, 8) then return nil, "crc" end
    local row = { version = Get(bits, 0, 2), resting = Get(bits, 2, 1) == 1, hdOff = Get(bits, 3, 1) == 1, hold = Get(bits, 4, 8),
        holdTint = Get(bits, 12, 5), holdStrength = Get(bits, 17, 3), progress = Get(bits, 20, 4),
        cue = Get(bits, 24, 8), cueTint = Get(bits, 32, 5), cueStrength = Get(bits, 37, 3) }
    if v1 then
        row.holdDots, row.holdMic = Get(bits, 40, 4), Get(bits, 44, 3)
        row.cueDots, row.cueMic = Get(bits, 47, 4), Get(bits, 51, 3)
    end
    return row
end

---------------------------------------------------------------------------
-- The trigger row (C:\games\WowHelper\docs\TRIGGERS.md): 19 cells two rows
-- inward of the v2 strip, red first, 54 bits: version (2), then per trigger
-- (L2 at bit 2, R2 at bit 23) a WoW Helper shape (10), its value (7: 0-100,
-- 127 none) and a count (4); a CRC-8 over bits 0-43. Drawn only while a
-- trigger holds a shape.
---------------------------------------------------------------------------
K.TRIG_CELLS = 19
K.TRIG_MARKER = { 1, 0, 0 }   -- red
K.VALUE_NONE = 127

-- A pick's value 0-1 (or nil) as the row's 0-100 / 127
local function Value7(v)
    v = tonumber(v)
    if not v then return K.VALUE_NONE end
    return math.floor(math.max(0, math.min(1, v)) * 100 + 0.5)
end
K.Value7 = Value7

-- row = { left = { shape, value (0-1 or nil), count }, right = ... }
function K.EncodeTrigRow(row)
    row = row or {}
    local bits = {}
    for i = 0, 53 do bits[i] = 0 end
    local function pick(at, p)
        p = p or {}
        Put(bits, at, Int(p.shape, 1023), 10)
        Put(bits, at + 10, Value7(p.value), 7)
        Put(bits, at + 17, Int(p.count, 15), 4)
    end
    pick(2, row.left)
    pick(23, row.right)
    Put(bits, 44, CrcBits(bits, 44), 8)
    local cells = { { 1, 0, 0 } }
    for c = 0, K.TRIG_CELLS - 2 do cells[#cells + 1] = { bits[c * 3], bits[c * 3 + 1], bits[c * 3 + 2] } end
    return cells
end

function K.DecodeTrigRow(cells)
    if type(cells) ~= "table" or #cells < K.TRIG_CELLS then return nil, "length" end
    local m = cells[1]
    if m[1] ~= 1 or m[2] ~= 0 or m[3] ~= 0 then return nil, "marker" end
    local bits = {}
    for c = 0, K.TRIG_CELLS - 2 do
        for k = 1, 3 do
            local v = cells[c + 2][k]
            if v ~= 0 and v ~= 1 then return nil, "value" end
            bits[c * 3 + k - 1] = v
        end
    end
    if Get(bits, 0, 2) ~= 0 or Get(bits, 52, 2) ~= 0 then return nil, "value" end
    if CrcBits(bits, 44) ~= Get(bits, 44, 8) then return nil, "crc" end
    local function pick(at)
        local v = Get(bits, at + 10, 7)
        return { shape = Get(bits, at, 10), value = v <= 100 and v / 100 or nil, count = Get(bits, at + 17, 4) }
    end
    return { left = pick(2), right = pick(23) }
end

---------------------------------------------------------------------------
-- The spell row (WoW Helper reads it to the same contract): 13 cells, three
-- rows inward of the v2 strip (one line: from cell 76), blue first, 36 bits
-- little-endian: seq (4, +1 each spell event), phase (2: 0 none, 1 casting
-- started, 2 released / landed, 3 stopped / interrupted), the spell id (20),
-- spare (2, 0), a CRC-8 over bits 0-27. Drawn only while WowHelperData.spellRow
-- is true. A spell id secret in combat (or past 20 bits) goes as 0: phase only.
---------------------------------------------------------------------------
K.SPELL_CELLS = 13
K.SPELL_MARKER = { 0, 0, 1 }   -- blue
K.SPELL_NONE, K.SPELL_CASTING, K.SPELL_RELEASED, K.SPELL_STOPPED = 0, 1, 2, 3
K.SPELL_ID_MAX = 1048575

-- ev = { seq, phase, id } -> 13 cells
function K.EncodeSpellRow(ev)
    ev = ev or {}
    local bits = {}
    for i = 0, 35 do bits[i] = 0 end
    Put(bits, 0, Int(ev.seq, 15), 4)
    Put(bits, 4, Int(ev.phase, 3), 2)
    local id = Int(ev.id, K.SPELL_ID_MAX + 1)
    Put(bits, 6, id > K.SPELL_ID_MAX and 0 or id, 20)
    Put(bits, 28, CrcBits(bits, 28), 8)
    local cells = { { 0, 0, 1 } }
    for c = 0, K.SPELL_CELLS - 2 do cells[#cells + 1] = { bits[c * 3], bits[c * 3 + 1], bits[c * 3 + 2] } end
    return cells
end

function K.DecodeSpellRow(cells)
    if type(cells) ~= "table" or #cells < K.SPELL_CELLS then return nil, "length" end
    local m = cells[1]
    if m[1] ~= 0 or m[2] ~= 0 or m[3] ~= 1 then return nil, "marker" end
    local bits = {}
    for c = 0, K.SPELL_CELLS - 2 do
        for k = 1, 3 do
            local v = cells[c + 2][k]
            if v ~= 0 and v ~= 1 then return nil, "value" end
            bits[c * 3 + k - 1] = v
        end
    end
    if Get(bits, 26, 2) ~= 0 then return nil, "value" end
    if CrcBits(bits, 28) ~= Get(bits, 28, 8) then return nil, "crc" end
    return { seq = Get(bits, 0, 4), phase = Get(bits, 4, 2), id = Get(bits, 6, 20) }
end

-- The map row (WoW Helper's node compass, its docs/NODE-COMPASS.md): 28 cells, white first, 81
-- bits LE: version 0-1 (1), facing 2-11 (GetPlayerFacing / 2pi * 1024), the minimap's centre x
-- 12-23 and y 24-35 (client pixels from the top-left), radius 36-45 (pixels), yards across 46-55,
-- rotates 56, tracking 57-58 (1 minerals, 2 herbs, 3 treasure), camera known 59, camera yaw 60-69
-- (as facing), x bit 12 at 70 and y bit 12 at 71 (a 5120 px wide screen), CRC-8 over bits 0-71 at 72-79, spare 80. Four rows up (stacked) or
-- from cell 89 (one line: 117 cells); drawn only while WowHelperData.mapRow is 2 and a node
-- tracking is on (NodeCompass.lua).
K.MAP_CELLS = 28
K.MAP_MARKER = { 1, 1, 1 }   -- white

-- m = { facing, x, y, radius, yards, rotates, tracking, camera (nil: unknown) } -> 28 cells
function K.EncodeMapRow(m)
    m = m or {}
    local bits = {}
    for i = 0, 80 do bits[i] = 0 end
    Put(bits, 0, 1, 2)
    Put(bits, 2, Int(m.facing, 1023), 10)
    local x, y = Int(m.x, 8191), Int(m.y, 8191)
    Put(bits, 12, x % 4096, 12)
    Put(bits, 24, y % 4096, 12)
    Put(bits, 70, floor(x / 4096), 1)
    Put(bits, 71, floor(y / 4096), 1)
    Put(bits, 36, Int(m.radius, 1023), 10)
    Put(bits, 46, Int(m.yards, 1023), 10)
    Put(bits, 56, m.rotates and 1 or 0, 1)
    Put(bits, 57, Int(m.tracking, 3), 2)
    if m.camera then
        Put(bits, 59, 1, 1)
        Put(bits, 60, Int(m.camera, 1023), 10)
    end
    Put(bits, 72, CrcBits(bits, 72), 8)
    local cells = { { 1, 1, 1 } }
    for c = 0, K.MAP_CELLS - 2 do cells[#cells + 1] = { bits[c * 3], bits[c * 3 + 1], bits[c * 3 + 2] } end
    return cells
end

function K.DecodeMapRow(cells)
    if type(cells) ~= "table" or #cells < K.MAP_CELLS then return nil, "length" end
    local m = cells[1]
    if m[1] ~= 1 or m[2] ~= 1 or m[3] ~= 1 then return nil, "marker" end
    local bits = {}
    for c = 0, K.MAP_CELLS - 2 do
        for k = 1, 3 do
            local v = cells[c + 2][k]
            if v ~= 0 and v ~= 1 then return nil, "value" end
            bits[c * 3 + k - 1] = v
        end
    end
    if Get(bits, 0, 2) ~= 1 then return nil, "value" end
    if CrcBits(bits, 72) ~= Get(bits, 72, 8) then return nil, "crc" end
    return { facing = Get(bits, 2, 10), x = Get(bits, 12, 12) + 4096 * Get(bits, 70, 1),
        y = Get(bits, 24, 12) + 4096 * Get(bits, 71, 1), radius = Get(bits, 36, 10),
        yards = Get(bits, 46, 10), rotates = Get(bits, 56, 1) == 1, tracking = Get(bits, 57, 2),
        camera = Get(bits, 59, 1) == 1 and Get(bits, 60, 10) or nil }
end

-- The node row (NodeSense.lua -> WoW Helper's node compass: what each minimap dot is): 54 cells,
-- cyan first, 159 bits LE: version 0-1 (1), count 2-4 (0-6), then 6 nodes of 24 bits from bit 5
-- (unused all zero): dx + 128 (8 bits: the dot from the minimap's centre, rightward, radius/127
-- units), dy + 128 (8: downward), kind (6: S.ORES' numbers, 32 an herb, 48 treasure, 0 unknown),
-- wanted (1), gatherable (1); CRC-8 over bits 0-148 at 149-156, spare 157-158. Six rows up
-- (stacked) or from cell 117 (one line: 171 cells); drawn only while the map row is and
-- WowHelperData.nodeRow is 1.
-- Version 2 (WowHelperData.nodeRow = 2): 4 nodes at most, then from bit 101 each kind's choice
-- (Setup > Nodes), 3 bits a slot (the veins 1-13 at 0-12, herbs 13, treasure 14): mode (2 bits:
-- 0 show, 1 track, 2 mute), gatherable by your skill (1).
K.NODE_CELLS = 54
K.NODE_MARKER = { 0, 1, 1 }   -- cyan
K.NODE_MAX, K.NODE_MAX_V2, K.PREFS_AT, K.NODE_SLOTS = 6, 4, 101, 15

-- A kind's slot in the choices (nil: none)
function K.NodeSlot(kind)
    if type(kind) ~= "number" then return nil end
    if kind >= 1 and kind <= 13 then return kind - 1 end
    if kind == 32 then return 13 end
    if kind == 48 then return 14 end
end

-- nodes = { { dx, dy, kind, wanted, gatherable } }, prefs = { mode = { [slot] = 0-2 },
-- gatherable = { [slot] = false } } (nil: version 1) -> 54 cells
function K.EncodeNodeRow(nodes, prefs)
    nodes = nodes or {}
    local bits = {}
    for i = 0, 158 do bits[i] = 0 end
    Put(bits, 0, prefs and 2 or 1, 2)
    local count = math.min(#nodes, prefs and K.NODE_MAX_V2 or K.NODE_MAX)
    Put(bits, 2, count, 3)
    for i = 1, count do
        local n, at = nodes[i], 5 + (i - 1) * 24
        Put(bits, at, Int((n.dx or 0) + 128, 255), 8)
        Put(bits, at + 8, Int((n.dy or 0) + 128, 255), 8)
        Put(bits, at + 16, Int(n.kind, 63), 6)
        Put(bits, at + 22, n.wanted == false and 0 or 1, 1)
        Put(bits, at + 23, n.gatherable == false and 0 or 1, 1)
    end
    if prefs then
        for k = 0, K.NODE_SLOTS - 1 do
            Put(bits, K.PREFS_AT + 3 * k, Int(prefs.mode and prefs.mode[k] or 0, 2), 2)
            Put(bits, K.PREFS_AT + 3 * k + 2, (prefs.gatherable and prefs.gatherable[k] == false) and 0 or 1, 1)
        end
    end
    Put(bits, 149, CrcBits(bits, 149), 8)
    local cells = { { K.NODE_MARKER[1], K.NODE_MARKER[2], K.NODE_MARKER[3] } }
    for c = 0, K.NODE_CELLS - 2 do cells[#cells + 1] = { bits[c * 3], bits[c * 3 + 1], bits[c * 3 + 2] } end
    return cells
end

function K.DecodeNodeRow(cells)
    if type(cells) ~= "table" or #cells < K.NODE_CELLS then return nil, "length" end
    local m = cells[1]
    if m[1] ~= 0 or m[2] ~= 1 or m[3] ~= 1 then return nil, "marker" end
    local bits = {}
    for c = 0, K.NODE_CELLS - 2 do
        for k = 1, 3 do
            local v = cells[c + 2][k]
            if v ~= 0 and v ~= 1 then return nil, "value" end
            bits[c * 3 + k - 1] = v
        end
    end
    local version = Get(bits, 0, 2)
    if version ~= 1 and version ~= 2 then return nil, "value" end
    if CrcBits(bits, 149) ~= Get(bits, 149, 8) then return nil, "crc" end
    local out = {}
    if version == 2 then
        out.prefs = { mode = {}, gatherable = {} }
        for k = 0, K.NODE_SLOTS - 1 do
            out.prefs.mode[k] = Get(bits, K.PREFS_AT + 3 * k, 2)
            out.prefs.gatherable[k] = Get(bits, K.PREFS_AT + 3 * k + 2, 1) == 1
        end
    end
    for i = 1, Get(bits, 2, 3) do
        local at = 5 + (i - 1) * 24
        out[i] = { dx = Get(bits, at, 8) - 128, dy = Get(bits, at + 8, 8) - 128, kind = Get(bits, at + 16, 6),
            wanted = Get(bits, at + 22, 1) == 1, gatherable = Get(bits, at + 23, 1) == 1 }
    end
    return out
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
    -- (0.59.4: the old strip (v1) had a Lab switch also named "HD"; it's gone, so the wide strip
    -- comes back once: HD on or off is Setup's switch, sent on the light row)
    if not db.link.v1Cleared then db.link.v1, db.link.v1Cleared = nil, true end
    return db.link
end

function K.Enabled() return DB().on == true end

-- At load: a fresh install with WoW Helper already run (its data addon is here) starts linked;
-- once. Turned off in Setup, it stays off.
function K.AutoOn()
    local l = DB()
    if l.on == nil and type(WowHelperData) == "table" then l.on = true end
end

-- The strip's rows: stacked (the main strip, the light row one up, the trigger row two up) or
-- one line (main 34 cells, the light row from cell 34 padded to 23, the trigger row from 57:
-- 76 cells). One line only when Lab › Strip says so and WoW Helper says it reads it
-- (WowHelperData.stripOneLine); else stacked, as before.
K.STRIPS = { { "stacked", "Stacked" }, { "oneline", "One line" } }
K.LINE_LIGHT, K.LINE_TRIG, K.LINE_CELLS = 34, 57, 76
K.LINE_SPELL, K.LINE_CELLS_SPELL = 76, 89   -- (the spell row after the trigger row: 89 cells)
K.LINE_MAP, K.LINE_CELLS_MAP = 89, 117      -- (the map row after the spell row's place: 117 cells)
K.LINE_NODE, K.LINE_CELLS_NODE = 117, 171   -- (the node row after the map row: 171 cells)
function K.Strip() return DB().strip == "oneline" and "oneline" or "stacked" end
function K.SetStrip(v)
    DB().strip = v == "oneline" and "oneline" or nil
    K.Layout()
    dirty = true
end
function K.OneLine()
    local d = WowHelperData
    return K.V2() and K.Strip() == "oneline" and type(d) == "table" and d.stripOneLine == true
end

-- The spell row: only once WoW Helper says it reads it (WowHelperData.spellRow)
function K.SpellRowOn()
    local d = WowHelperData
    return K.V2() and type(d) == "table" and d.spellRow == true
end

-- The map row: only once WoW Helper says it reads this version (WowHelperData.mapRow = 2), and
-- while NodeCompass.lua has one (a node tracking on)
function K.MapRowOn()
    local d = WowHelperData
    return K.V2() and type(d) == "table" and d.mapRow == 2 and K.map ~= nil
end

-- The map row's state (NodeCompass.lua), or nil: none. Redrawn when a field changes.
K.map = nil
function K.SetMap(m)
    -- (the kinds' choices with it: a pick in Setup, a skill up)
    if m ~= nil and ns.NodeSense and ns.NodeSense.Prefs then K.SetNodePrefs(ns.NodeSense.Prefs()) end
    if m == nil then
        if K.map then K.map = nil; dirty = true end
        return
    end
    local key = Int(m.facing, 1023) .. ":" .. Int(m.x, 8191) .. ":" .. Int(m.y, 8191) .. ":" .. Int(m.radius, 1023)
        .. ":" .. Int(m.yards, 1023) .. ":" .. (m.rotates and 1 or 0) .. ":" .. Int(m.tracking, 3)
        .. ":" .. (m.camera and Int(m.camera, 1023) or "-")
    if K.map and K.map.key == key then return end
    K.map = { key = key, facing = m.facing, x = m.x, y = m.y, radius = m.radius, yards = m.yards, rotates = m.rotates,
        tracking = m.tracking, camera = m.camera }
    dirty = true
end

-- The node row: only while the map row is drawn and WoW Helper says it reads it: version 1
-- (WowHelperData.nodeRow = 1) with dots named (NodeSense.lua); version 2 (nodeRow = 2) always,
-- for each kind's choice
function K.NodeRowV2()
    local d = WowHelperData
    return type(d) == "table" and type(d.nodeRow) == "number" and d.nodeRow >= 2
end
function K.NodeRowOn()
    local d = WowHelperData
    return K.MapRowOn() and type(d) == "table" and (K.NodeRowV2() or (d.nodeRow == 1 and K.nodes ~= nil))
end

-- Each kind's choice and gatherable (NodeSense.Prefs), redrawn when it changes: { mode, gatherable }
K.prefs = nil
function K.SetNodePrefs(p)
    local parts = {}
    for k = 0, K.NODE_SLOTS - 1 do
        parts[#parts + 1] = (p and p.mode and p.mode[k] or 0) .. ((p and p.gatherable and p.gatherable[k] == false) and "x" or "")
    end
    local key = table.concat(parts, ",")
    if K.prefs and K.prefs.key == key then return end
    K.prefs = { key = key, mode = p and p.mode or {}, gatherable = p and p.gatherable or {} }
    dirty = true
end

-- The named dots (NodeSense.Row), or nil: none. Redrawn when they change
K.nodes = nil
function K.SetNodes(list)
    local key
    if type(list) == "table" then
        local parts = {}
        for i, n in ipairs(list) do
            parts[i] = (n.dx or 0) .. "," .. (n.dy or 0) .. "," .. (n.kind or 0) .. (n.wanted == false and "-" or "") .. (n.gatherable == false and "x" or "")
        end
        key = table.concat(parts, ";")
    end
    if (K.nodes and K.nodes.key) == key then return end
    K.nodes = key and { key = key, list = list } or nil
    dirty = true
end

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

-- A spell event goes with the cue it belongs to, in the same frame: on the cue queued this
-- frame (before or after it), on screen with it; with none, on its own at the next frame
local lastQueued
local function Now() return GetTime and GetTime() or 0 end
local function Attach(item)
    item.at = Now()
    local p = K.spellPending
    if p and p.at == item.at and not item.spell then item.spell, K.spellPending = p.ev, nil end
    lastQueued = item
end

-- A spell event: phase (K.SPELL_*), its id (nil or secret: 0). Returns the event.
function K.SpellEvent(phase, id)
    K.spellSeq = ((K.spellSeq or 0) + 1) % 16
    if type(id) ~= "number" or id < 0 or id > K.SPELL_ID_MAX then id = 0 end
    local ev = { seq = K.spellSeq, phase = Int(phase, 3), id = floor(id) }
    local now = Now()
    if lastQueued and lastQueued.at == now and not lastQueued.started and not lastQueued.spell then
        lastQueued.spell = ev
    else
        K.spellPending = { ev = ev, at = now }
    end
    return ev
end

local function Queue(item)
    if not K.Enabled() or #K.queue >= K.QUEUE_MAX then return false end
    -- Hush (Hush.lua): no sounds, no moment lights; a touch still goes (the Feel channel scales it)
    -- (and no race and sex: WoW Helper's yell for Fall damage is a sound too)
    if ns.Stack and ns.Stack.Is("hush") and not K.previewing then
        item.sound, item.light, item.seed = 0, nil, nil
        if (item.touch or 0) == 0 and not item.open then return false end
    end
    Attach(item)
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
-- A swing or gathering marker (Timing, WoW Helper's src/calib.rs and
-- src/gather.rs): moment 110-126 (swings) or 100-108 (gathering), side =
-- race id, seed = sex bit and the addon's delay, level = result, with or
-- without the hit's touch and sound (WoW Helper times them). Shown ahead of
-- waiting cues: its moment on screen is the swing's news.
K.MARKER_FIRST, K.MARKER_LAST = 100, 126
function K.Marker(item)
    if not (K.Enabled() and K.V2()) then return false end
    local m = Int(item.moment, 127)
    -- (96-98 footsteps, 99 an emote's voice, 100-108 gathering, 109 its node, 110-126 swings,
    -- 127 who plays)
    if not ((m >= 96 and m <= 99) or (m >= 100 and m <= 109) or (m >= 110 and m <= 127)) then return false end
    local touch = Int(item.touch, 4095)
    if touch > 0 and touch < 128 then touch = 0 end
    -- (ahead of the cues, behind the markers already waiting: a stop and a
    -- start in one frame keep their order)
    local at = 1
    while K.queue[at] and K.queue[at].marker do at = at + 1 end
    local queued = { touch = touch, sound = Int(item.sound, 4095), gain = Int(item.gain == nil and 4 or item.gain, 7),
        intensity = item.intensity and Int(item.intensity, 7) or 4, moment = m, side = Int(item.side, 15),
        seed = Int(item.seed, 255), level = Int(item.level, 3), marker = true }
    Attach(queued)
    table.insert(K.queue, at, queued)
    while #K.queue > K.QUEUE_MAX do table.remove(K.queue) end
    return true
end

function K.Cue(item)
    if not K.V2() then return false end
    local touch, sound = Int(item.touch, 4095), Int(item.sound, 4095)
    if touch > 0 and touch < 128 then touch = 0 end
    if touch == 0 and sound == 0 and not item.open then return false end
    -- (seed: nil = a random variation; Fall damage's carries the race and sex, K.RaceSexSeed)
    return Queue({ touch = touch, sound = sound, gain = Int(item.gain == nil and 4 or item.gain, 7),
        intensity = item.intensity and Int(item.intensity, 7) or 4, moment = Int(item.moment, 127),
        open = item.open and true or false, seed = item.seed and Int(item.seed, 255) or nil })
end

-- Fall damage (moment 92) carries the character's race and sex in its cue's seed (v2 bits
-- 70-77), so WoW Helper plays that character's own yell with it, in the same frame: bits 0-6
-- the race id (UnitRace's third value, 1-127; 0 unknown), bit 7 female (UnitSex 3), the
-- markers' convention (src/calib.rs, src/gather.rs). An older WoW Helper takes the byte for a
-- variation seed, as for any cue.
function K.RaceSexSeed(race, sex)
    race = type(race) == "number" and race or 0
    if race < 1 or race > 127 or race ~= floor(race) then race = 0 end
    return race + (sex == 3 and 128 or 0)
end
-- seed -> race (0 unknown), sex (2 male, 3 female)
function K.RaceSexOf(seed)
    seed = Int(seed, 255)
    return seed % 128, seed >= 128 and 3 or 2
end

-- Emote voices (WoW Helper's src/emote_voice.rs): a voiced emote by a character the game shows,
-- for WoW Helper to play the game's own voice for its race and sex. Marker moment 99, touch 0 and
-- sound 0 (an older WoW Helper plays nothing: no cue to it); the emote id (EmotesText, 1-4095; 0:
-- "the player's race and sex", sent at login so their voices are made ready ahead) in side (bits
-- 0-3), gain (4-6), intensity (7-9) and level (10-11); the seed: race + 128 if female
-- (K.RaceSexSeed). Vectors: tests/fixtures/helperlink-emote-vectors.txt
K.EMOTE_MARKER = 99
function K.EmoteFields(id)
    id = Int(id, 4095)
    return id % 16, floor(id / 16) % 8, floor(id / 128) % 8, floor(id / 1024) % 4
end
function K.EmoteOf(side, gain, intensity, level)
    return Int(side, 15) + Int(gain, 7) * 16 + Int(intensity, 7) * 128 + Int(level, 3) * 1024
end
function K.EmoteVoice(id, race, sex)
    -- (Hush: no sounds, so no voice)
    if ns.Stack and ns.Stack.Is("hush") and not K.previewing then return false end
    local side, gain, intensity, level = K.EmoteFields(id)
    return K.Marker({ moment = K.EMOTE_MARKER, touch = 0, sound = 0, side = side, gain = gain, intensity = intensity,
        level = level, seed = K.RaceSexSeed(race, sex) })
end

-- Who plays (WoW Helper's src/who.rs): its full feels can play a card for one character, a race,
-- a sex or a faction. Marker moment 127, touch 0 and sound 0 (an older WoW Helper plays nothing);
-- the character's number (1-1023, Profiles' list, never reused) in side (bits 0-3), gain (4-6) and
-- intensity (7-9); level: the faction (0 unknown, 1 Horde, 2 Alliance); the seed: race + 128 if
-- female (K.RaceSexSeed); touch: the Sounds volume, the pad speaker's master (128 + percent,
-- 128-228; 0: not said: K.Marker keeps no touch under 128), which WoW Helper applies to every
-- sound it plays on the speaker. Sent at login, every 30 s and when Volume changes (Profiles). Vectors:
-- tests/fixtures/helperlink-who-vectors.txt
K.WHO_MARKER = 127
function K.WhoFields(n, faction)
    n = Int(n, 1023)
    local f = (faction == "Horde" and 1) or (faction == "Alliance" and 2) or 0
    return n % 16, floor(n / 16) % 8, floor(n / 128) % 8, f
end
-- The speaker's master in the who marker's touch: 128 + percent, 0 when not given
function K.SpeakerTouch(volume)
    local v = tonumber(volume)
    if not v then return 0 end
    return 128 + floor(math.max(0, math.min(1, v)) * 100 + 0.5)
end
function K.Who(n, faction, race, sex, speaker)
    local side, gain, intensity, level = K.WhoFields(n, faction)
    return K.Marker({ moment = K.WHO_MARKER, touch = K.SpeakerTouch(speaker), sound = 0, side = side, gain = gain, intensity = intensity,
        level = level, seed = K.RaceSexSeed(race, sex) })
end

-- The voiced emotes' chat lines (WowHelperData.emoteVoices: { [id] = { "TOKEN", "%s laughs.",
-- "You laugh.", ... } }, the client's language, read by WoW Helper from the game's tables) as
-- patterns, the longest wording first ("%s laughs at %s." before "%s laughs.")
function K.EmoteLines(src)
    local list = {}
    if type(src) ~= "table" then return list end
    for id, lines in pairs(src) do
        if type(id) == "number" and type(lines) == "table" then
            for i = 2, #lines do
                local line = lines[i]
                if type(line) == "string" and line:find("%S") then
                    local words = (line:gsub("%%s", ""))
                    local p = (line:gsub("%%s", "\1")):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
                    p = "^" .. (p:gsub("\1", "(.-)")) .. "$"
                    list[#list + 1] = { p, id, #words, lines[1] }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a[3] ~= b[3] then return a[3] > b[3] end
        return a[1] < b[1]
    end)
    return list
end
-- A chat line's emote: its id and token, or nil (not a voiced one)
function K.EmoteOfLine(list, text)
    if type(text) ~= "string" then return nil end
    for _, e in ipairs(list) do
        if text:find(e[1]) then return e[2], e[4] end
    end
end

-- The mic LED (v2): "leave", "off", "on", "pulse"
function K.SetMic(mode)
    local m = K.MIC[mode] or 0
    if K.state.mic ~= m then K.state.mic = m; dirty = true end
end

-- The light row's version WoW Helper reads (its data addon says): 1, else 0 (L5)
function K.LightVersion()
    local d = type(WowHelperData) == "table" and WowHelperData or nil
    return d and (tonumber(d.lightRow) or 0) >= 1 and 1 or 0
end

-- A preview (a Try in the window) goes out even while hushed (L2-5)
local function Previewed(ok, ...)
    K.previewing = false
    if not ok then error((...), 0) end
    return ...
end
function K.Preview(fn, ...)
    K.previewing = true
    return Previewed(pcall(fn, ...))
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
    local version = row.version == nil and K.LightVersion() or row.version   -- (0: an older helper: L5, L2-12)
    local same = cur.hold == row.hold and cur.holdTint == row.holdTint and cur.holdStrength == row.holdStrength
        and cur.progress == row.progress and (cur.resting or false) == (row.resting or false)
        and cur.holdDots == (row.holdDots or 0) and cur.holdMic == (row.holdMic or 0) and cur.version == version
    if same and K.light then return end
    -- (a cue on screen keeps its fields until it has had its frames: L16)
    K.light = { version = version, hold = row.hold or 0, holdTint = row.holdTint or 0, holdStrength = row.holdStrength or 0,
        progress = row.progress or 0, resting = row.resting or false, holdDots = row.holdDots or 0, holdMic = row.holdMic or 0,
        cue = cur.cue or 0, cueTint = cur.cueTint or 0, cueStrength = cur.cueStrength or 0, cueDots = cur.cueDots or 0, cueMic = cur.cueMic or 0 }
    dirty = true
end

-- The trigger row's state (TriggerStack.lua): { left = { shape, value, count },
-- right = ... }, or nil: no row (the strip's own trigger fields only). Redrawn
-- when a shape or count changes, or a value moves by 1/100.
K.trig = nil
function K.SetTrigRow(row)
    local function key(p) p = p or {}; return Int(p.shape, 1023) .. ":" .. Value7(p.value) .. ":" .. Int(p.count, 15) end
    local function any(p) return p and Int(p.shape, 1023) > 0 end
    if row and not (any(row.left) or any(row.right)) then row = nil end
    if row == nil then
        if K.trig then K.trig = nil; dirty = true end
        return
    end
    local k = key(row.left) .. "|" .. key(row.right)
    if K.trig and K.trig.key == k then return end
    K.trig = { key = k, left = row.left or {}, right = row.right or {} }
    dirty = true
end

-- A once light on the pad (v2 + the light row): its id 1-255, tint 0-31, strength 0-7, dots
-- 0-14 and mic 0-4 (0: the light's own)
function K.LightCue(id, tint, strength, dots, mic)
    if not K.V2() then return false end
    id = Int(id, 255)
    if id == 0 then return false end
    if not K.light then K.SetLight({ hold = 0 }) end
    return Queue({ touch = 0, sound = 0, light = { id, Int(tint, 31), Int(strength, 7), Int(dots, 15), Int(mic, 7) } })
end

local function Start(item)
    item.started = true
    if item.spell then K.spell = item.spell end
    local s = K.state
    s.seq = (s.seq + 1) % 16
    s.touch, s.sound, s.gain = item.touch or 0, item.sound or 0, item.gain or 4
    s.side, s.intensity, s.level = item.side or 0, item.intensity or 4, item.level or 0
    s.moment, s.open = item.moment or 0, item.open or false
    s.seed = item.seed or (math.random and math.random(0, 255) or 0)
    if K.light then
        local c = item.light
        K.light.cue, K.light.cueTint, K.light.cueStrength = c and c[1] or 0, c and c[2] or 0, c and c[3] or 0
        K.light.cueDots, K.light.cueMic = c and c[4] or 0, c and c[5] or 0
    end
    -- (v1: one event id, a clip or a sound up to 255)
    local v1 = s.sound ~= 0 and s.sound or s.touch
    s.event = v1 <= 255 and v1 or 0
    active, frames, age, dirty = true, 0, 0, true
end

-- One frame: the event queue (each event on screen >= MIN_FRAMES frames and
-- >= MIN_TIME), then a redraw if anything changed. Returns true on redraw.
function K.Step(elapsed)
    -- (a spell event no cue took: on its own)
    local p = K.spellPending
    if p and p.at ~= Now() then K.spell, K.spellPending, dirty = p.ev, nil, true end
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
                if K.light then K.light.cue, K.light.cueTint, K.light.cueStrength, K.light.cueDots, K.light.cueMic = 0, 0, 0, 0, 0 end
                dirty = true
            end
        end
    elseif #K.queue > 0 then
        Start(table.remove(K.queue, 1))
    end
    if dirty then
        dirty = false
        -- (WoW Helper's word on one line arrives with its data: the layout follows)
        if (K.lineDrawn ~= nil and K.lineDrawn ~= K.OneLine()) or (K.spellDrawn ~= nil and K.spellDrawn ~= K.SpellRowOn())
            or (K.mapDrawn ~= nil and K.mapDrawn ~= K.MapRowOn()) or (K.nodeDrawn ~= nil and K.nodeDrawn ~= K.NodeRowOn()) then
            K.Layout()
        end
        if K.Draw then K.Draw(K.V2() and K.EncodeV2(K.state) or K.Encode(K.state)) end
        if K.DrawLight then K.DrawLight(K.V2() and K.LightRow() and K.EncodeLight(K.LightRow()) or nil) end
        if K.DrawTrig then K.DrawTrig(K.V2() and K.trig and K.EncodeTrigRow(K.trig) or nil) end
        if K.DrawSpell then K.DrawSpell(K.SpellRowOn() and K.EncodeSpellRow(K.spell or { seq = K.spellSeq or 0 }) or nil) end
        if K.DrawMap then K.DrawMap(K.MapRowOn() and K.EncodeMapRow(K.map) or nil) end
        if K.DrawNode then K.DrawNode(K.NodeRowOn() and K.EncodeNodeRow(K.nodes and K.nodes.list, K.NodeRowV2() and (K.prefs or {}) or nil) or nil) end
        if K.DrawHold then K.DrawHold() end
        if K.DrawCheck then K.DrawCheck() end
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
    local line, spell, map, node = K.OneLine(), K.SpellRowOn(), K.MapRowOn(), K.NodeRowOn()
    K.lineDrawn, K.spellDrawn, K.mapDrawn, K.nodeDrawn = line, spell, map, node
    frame:SetSize(unit * (line and (node and K.LINE_CELLS_NODE or map and K.LINE_CELLS_MAP or spell and K.LINE_CELLS_SPELL
        or K.LINE_CELLS) or n), unit)
    for i, tex in ipairs(textures) do
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, 0)
        tex:SetSize(unit, unit)
        tex:SetShown(i <= n)
    end
    -- the light row: one row up (inward from the bottom-left corner); one line: from cell 34
    for i, tex in ipairs(K.lightTextures or {}) do
        tex:ClearAllPoints()
        if line then
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (K.LINE_LIGHT + i - 1) * unit, 0)
        else
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, unit)
        end
        tex:SetSize(unit, unit)
    end
    -- the trigger row: two rows up; one line: from cell 57
    for i, tex in ipairs(K.trigTextures or {}) do
        tex:ClearAllPoints()
        if line then
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (K.LINE_TRIG + i - 1) * unit, 0)
        else
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, 2 * unit)
        end
        tex:SetSize(unit, unit)
    end
    -- the spell row: three rows up; one line: from cell 76
    for i, tex in ipairs(K.spellTextures or {}) do
        tex:ClearAllPoints()
        if line then
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (K.LINE_SPELL + i - 1) * unit, 0)
        else
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, 3 * unit)
        end
        tex:SetSize(unit, unit)
    end
    -- the map row: four rows up; one line: from cell 89
    for i, tex in ipairs(K.mapTextures or {}) do
        tex:ClearAllPoints()
        if line then
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (K.LINE_MAP + i - 1) * unit, 0)
        else
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, 4 * unit)
        end
        tex:SetSize(unit, unit)
    end
    if K.LayoutNodes then K.LayoutNodes(unit, line) end
    if K.LayoutHold then K.LayoutHold(unit, line) end
    if K.LayoutCheck then K.LayoutCheck(unit, line) end
end

-- the node row: six rows up (the goblin row is five up); one line: from cell 117
function K.LayoutNodes(unit, line)
    for i, tex in ipairs(K.nodeTextures or {}) do
        tex:ClearAllPoints()
        if line then
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (K.LINE_NODE + i - 1) * unit, 0)
        else
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, 6 * unit)
        end
        tex:SetSize(unit, unit)
    end
end

---------------------------------------------------------------------------
-- The hold cells (WoW Helper's docs/PROTOCOL-V2.md): two cells seven rows up (one line: cells
-- 171-172) saying n, 0-9: cell A (16n, 255-16n, 90), cell B (255-16n, 16n, 165). While n > 0,
-- WoW Helper holds the chord Keys.CHORD .. n (Keys.lua binds them): a pad key's Focus UI,
-- Radial, Ping wheel or own game command, held as long as the key is. Drawn only while the
-- link is on and WoW Helper says it reads them (WowHelperData.holdCells = 1)
---------------------------------------------------------------------------
K.LINE_HOLD = 171
K.hold = 0
function K.HoldCellsOn()
    local d = WowHelperData
    return K.Enabled() and type(d) == "table" and d.holdCells == 1
end
-- n's two colours, 0-1 each
function K.HoldCells(n)
    local v = 16 * n
    return { { v / 255, (255 - v) / 255, 90 / 255 }, { (255 - v) / 255, v / 255, 165 / 255 } }
end
function K.DrawHold()
    local on = K.HoldCellsOn()
    local cells = on and K.HoldCells(K.hold)
    for i, tex in ipairs(K.holdTextures or {}) do
        if cells then local c = cells[i]; tex:SetColorTexture(c[1], c[2], c[3], 1) end
        tex:SetShown(on and true or false)
    end
end
function K.LayoutHold(unit, line)
    for i, tex in ipairs(K.holdTextures or {}) do
        tex:ClearAllPoints()
        if line then tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (K.LINE_HOLD + i - 1) * unit, 0)
        else tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * unit, 7 * unit) end
        tex:SetSize(unit, unit)
    end
end
-- Hold chord n (0: let go), drawn at once. A let-go waits till n has been on
-- screen HOLD_FRAMES rendered frames (WoW Helper reads one a frame): a short tap
-- is still seen
K.HOLD_FRAMES = 2
K.holdFrames, K.holdLetGo = 0, false
function K.Hold(n)
    n = math.floor(tonumber(n) or 0)
    if n < 0 or n > 9 then n = 0 end
    if n == 0 and K.hold > 0 and K.holdFrames <= K.HOLD_FRAMES and K.HoldCellsOn() then
        K.holdLetGo = true
        return
    end
    K.hold, K.holdFrames, K.holdLetGo = n, 0, false
    K.DrawHold()
end
-- Each rendered frame (the strip's OnUpdate; the frame Hold was called in counts once)
function K.HoldTick()
    if K.hold == 0 then return end
    K.holdFrames = K.holdFrames + 1
    if K.holdLetGo and K.holdFrames > K.HOLD_FRAMES then
        K.hold, K.holdFrames, K.holdLetGo = 0, 0, false
        K.DrawHold()
    end
end

-- (the check pixel's pair: blue false red, blue; true blue, red)
local function CheckCells(blue)
    local red, bl = { 1, 0, 0 }, { 0, 0, 1 }
    return blue and { bl, red } or { red, bl }
end
K.CheckCells = CheckCells

---------------------------------------------------------------------------
-- The check pixel (WoW Helper's docs/PROTOCOL-V2.md, "The check pixel"): a red|blue pair,
-- cells 2-3 of the hold cells' row (one line: 173-174), swapped for each "Check
-- minimap": WoW Helper puts the cursor on the minimap's next node dot, the game's tooltip shown.
-- Drawn only while WoW Helper says it reads it (WowHelperData.minimapCheck = 1)
---------------------------------------------------------------------------
K.LINE_CHECK = 173
K.checkBlue = false
function K.CheckPixelOn()
    local d = WowHelperData
    return K.Enabled() and K.V2() and type(d) == "table" and d.minimapCheck == 1
end
function K.DrawCheck()
    local on = K.CheckPixelOn()
    local cells = on and CheckCells(K.checkBlue)
    for i, tex in ipairs(K.checkTextures or {}) do
        if cells then local c = cells[i]; tex:SetColorTexture(c[1], c[2], c[3], 1) end
        tex:SetShown(on and true or false)
    end
end
function K.LayoutCheck(unit, line)
    for i, tex in ipairs(K.checkTextures or {}) do
        tex:ClearAllPoints()
        if line then tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (K.LINE_CHECK + i - 1) * unit, 0)
        else tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i + 1) * unit, 7 * unit) end
        tex:SetSize(unit, unit)
    end
end
-- The next node dot through WoW Helper; false: it doesn't read the pixel (nothing done)
function K.AskCheck()
    if not K.CheckPixelOn() then return false end
    K.checkBlue = not K.checkBlue
    K.DrawCheck()
    return true
end
-- (the "Check minimap" action's macro: /run GamepadCompanionCheckMinimap())
function GamepadCompanionCheckMinimap() return K.AskCheck() end

-- The node row's cells, or nil: hidden
function K.DrawNode(cells)
    for i, tex in ipairs(K.nodeTextures or {}) do
        local c = cells and cells[i]
        if c then tex:SetColorTexture(c[1], c[2], c[3], 1) end
        tex:SetShown(c ~= nil)
    end
end

-- The trigger row's cells, or nil: hidden (one line with the spell or map row: black, so the
-- rows after it stay put)
function K.DrawTrig(cells)
    local pad = not cells and K.lineDrawn and (K.spellDrawn or K.mapDrawn)
    for i, tex in ipairs(K.trigTextures or {}) do
        local c = cells and cells[i] or (pad and { 0, 0, 0 }) or nil
        if c then tex:SetColorTexture(c[1], c[2], c[3], 1) end
        tex:SetShown(c ~= nil)
    end
end

-- The spell row's cells, or nil: hidden (one line with the map row: black, so the map row's
-- start stays put)
function K.DrawSpell(cells)
    local pad = not cells and K.lineDrawn and K.mapDrawn
    for i, tex in ipairs(K.spellTextures or {}) do
        local c = cells and cells[i] or (pad and { 0, 0, 0 }) or nil
        if c then tex:SetColorTexture(c[1], c[2], c[3], 1) end
        tex:SetShown(c ~= nil)
    end
end

-- The map row's cells, or nil: hidden
function K.DrawMap(cells)
    for i, tex in ipairs(K.mapTextures or {}) do
        local c = cells and cells[i]
        if c then tex:SetColorTexture(c[1], c[2], c[3], 1) end
        tex:SetShown(c ~= nil)
    end
end

-- The light row's cells, or nil: hidden (no row: the game's lights). One line: a shorter
-- row (17 cells) padded to 23 with black, so the trigger row's start stays put
function K.DrawLight(cells)
    for i, tex in ipairs(K.lightTextures or {}) do
        local c = cells and cells[i]
        if cells and not c and K.lineDrawn then c = { 0, 0, 0 } end
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
    for i = 1, K.LIGHT_CELLS_V1 do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex:Hide()
        K.lightTextures[i] = tex
    end
    K.trigTextures = {}
    for i = 1, K.TRIG_CELLS do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex:Hide()
        K.trigTextures[i] = tex
    end
    K.spellTextures = {}
    for i = 1, K.SPELL_CELLS do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex:Hide()
        K.spellTextures[i] = tex
    end
    K.mapTextures = {}
    for i = 1, K.MAP_CELLS do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex:Hide()
        K.mapTextures[i] = tex
    end
    K.nodeTextures = {}
    for i = 1, K.NODE_CELLS do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex:Hide()
        K.nodeTextures[i] = tex
    end
    K.holdTextures = {}
    for i = 1, 2 do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex:Hide()
        K.holdTextures[i] = tex
    end
    K.checkTextures = {}
    for i = 1, 2 do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex:Hide()
        K.checkTextures[i] = tex
    end
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, elapsed) K.HoldTick(); K.Step(elapsed) end)
    frame:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then
            if name == addonName then K.AutoOn(); K.Refresh() end
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
        K.hold, K.holdFrames, K.holdLetGo = 0, 0, false
        for i = #K.queue, 1, -1 do K.queue[i] = nil end
        active = false
        K.state.event, K.state.gain, K.state.touch, K.state.sound = 0, 0, 0, 0
        K.state.left, K.state.right = OffTrigger(), OffTrigger()
        K.trig = nil
        dirty = true
    end
    K.Refresh()
    if ns.Lights and ns.Lights.LinkChanged then ns.Lights.LinkChanged() end
    -- the triggers: the stack's current ones again (its resolution has not changed)
    if ns.TriggerStack and ns.TriggerStack.LinkChanged then ns.TriggerStack.LinkChanged() end
end

Build()
