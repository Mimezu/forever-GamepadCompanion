-- HelperLink: encode / decode, checksum, event queue, strip layout, fixture shared with the helper.
-- lua5.1 tests/HelperLink.lua <addon folder> [--write]
--   --write regenerates tests/fixtures/helperlink-vectors.txt (helper/gpc_helper.py --selftest reads it)
local root = arg[1] or "."
local write = arg[2] == "--write"

-- Minimal client ------------------------------------------------------------------
local created = {}
local methods = {}
local function new(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, shown = true, points = {},
        events = {} }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
    created[#created + 1] = f
    if name then _G[name] = f end
    return f
end
function methods:SetScript(key, fn) self.scripts[key] = fn end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:CreateTexture() return new("Texture", nil, self) end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetShown(v) self.shown = v and true or false end
function methods:SetFrameStrata(s) self.strata = s end
function methods:SetScale(s) self.scale = s end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function CreateFrame(kind, name, parent) return new(kind, name, parent) end
local physW, physH = 2560, 1440
function GetPhysicalScreenSize() return physW, physH end
GamepadCompanionHapticsDB = { engine = true }   -- (other fields must survive)

local ns = {}
assert(loadfile(root .. "/HelperLink.lua"))("GamepadCompanion", ns)
local K = ns.HelperLink
assert(K and K.frame, "module and frame")
assert(K.frame.parent == nil and K.frame.strata == "TOOLTIP", "parentless, tooltip strata")
assert(not K.frame.shown, "hidden while off")

local function eq(a, b, path)
    path = path or "state"
    if type(a) ~= type(b) then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
    if type(a) == "table" then
        for k, v in pairs(a) do eq(v, b[k], path .. "." .. tostring(k)) end
        for k in pairs(b) do if a[k] == nil then error(path .. "." .. tostring(k) .. " missing") end end
    elseif a ~= b then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
end

-- Deterministic generator (same numbers on every Lua build: the fixture must not drift)
local seed = 12345
local function rand(n)   -- 0 .. n-1
    seed = (seed * 1103515245 + 12345) % 2147483648
    return math.floor(seed / 65536) % n
end
local function randTrigger() return { mode = rand(8), start = rand(16), finish = rand(16), force = rand(16) } end
local function randState() return { seq = rand(16), left = randTrigger(), right = randTrigger(), event = rand(256), gain = rand(8) } end

-- Encode / decode round trips ----------------------------------------------------------
local vectors = {}
for i = 1, 2000 do
    local s = randState()
    local cells = K.Encode(s)
    assert(#cells == 18, "18 cells")
    for _, c in ipairs(cells) do for k = 1, 3 do assert(c[k] == 0 or c[k] == 1, "binary") end end
    eq(K.Decode(cells), s)
    if i <= 64 then vectors[#vectors + 1] = { s, cells } end
end
-- edge values: all zero, all max
local zero = { seq = 0, left = { mode = 0, start = 0, finish = 0, force = 0 }, right = { mode = 0, start = 0, finish = 0, force = 0 }, event = 0, gain = 0 }
local maxed = { seq = 15, left = { mode = 7, start = 15, finish = 15, force = 15 }, right = { mode = 7, start = 15, finish = 15, force = 15 }, event = 255, gain = 7 }
eq(K.Decode(K.Encode(zero)), zero); eq(K.Decode(K.Encode(maxed)), maxed)
vectors[#vectors + 1] = { zero, K.Encode(zero) }
vectors[#vectors + 1] = { maxed, K.Encode(maxed) }
-- markers and bit order: seq 1 sets cell 2's red; event 1 is bit 34 = cell 13 green (index 2+11+1)
local one = K.Encode({ seq = 1 })
assert(one[1][1] == 1 and one[1][2] == 0 and one[1][3] == 1 and one[2][2] == 1, "markers")
assert(one[3][1] == 1 and one[3][2] == 0, "seq bit 0 is cell 0 red")
local ev = K.Encode({ event = 1 })
assert(ev[14][2] == 1, "event bit 0 = bit 34 = data cell 11 green")
-- out of range values clamp, seq wraps
local clamped = K.Decode(K.Encode({ seq = 17, left = { mode = 9, start = -3, finish = 99, force = 7.6 }, event = 300, gain = 9 }))
assert(clamped.seq == 1 and clamped.left.mode == 7 and clamped.left.start == 0 and clamped.left.finish == 15
    and clamped.left.force == 8 and clamped.event == 255 and clamped.gain == 7, "clamped")

-- Checksum and malformed input rejection ---------------------------------------------------
local rejected = 0
seed = 999
for _ = 1, 500 do
    local cells = K.Encode(randState())
    local c, k = 3 + rand(16), 1 + rand(3)
    cells[c][k] = 1 - cells[c][k]          -- one flipped bit: always caught (it changes one group)
    local s, why = K.Decode(cells)
    assert(s == nil and why == "checksum", "single flip rejected")
    rejected = rejected + 1
end
local bad = K.Encode(zero); bad[1] = { 0, 1, 0 }
assert(select(2, K.Decode(bad)) == "marker", "marker")
bad = K.Encode(zero); bad[5] = { 0.5, 0, 0 }
assert(select(2, K.Decode(bad)) == "value", "value")
assert(select(2, K.Decode({})) == "length", "length")

-- Fixture shared with the Python helper -----------------------------------------------------
local function line(v)
    local s, cells = v[1], v[2]
    local digits = {}
    for i, c in ipairs(cells) do digits[i] = tostring(c[1] * 4 + c[2] * 2 + c[3]) end
    return string.format("%d %d %d %d %d %d %d %d %d %d %d : %s", s.seq,
        s.left.mode, s.left.start, s.left.finish, s.left.force,
        s.right.mode, s.right.start, s.right.finish, s.right.force, s.event, s.gain, table.concat(digits))
end
local path = root .. "/tests/fixtures/helperlink-vectors.txt"
local text = { "# HelperLink vectors: seq lmode lstart lfinish lforce rmode rstart rfinish rforce event gain : 18 cells as r*4+g*2+b",
    "# Written by: lua5.1 tests/HelperLink.lua . --write ; read by: helper/gpc_helper.py --selftest" }
for _, v in ipairs(vectors) do text[#text + 1] = line(v) end
text = table.concat(text, "\n") .. "\n"
if write then
    local f = assert(io.open(path, "wb")); f:write(text); f:close()
    print("wrote " .. path)
else
    local f = io.open(path, "rb")
    assert(f, "fixture missing: run with --write")
    local old = f:read("*a"):gsub("\r\n", "\n"); f:close()   -- (git may check it out with CRLF)
    assert(old == text, "fixture differs from this encoder: regenerate with --write and rerun the helper selftest")
end

-- Protocol v2: the helper's vectors (C:\games\WowHelper writes them) ----------------------------
assert(K.Crc8({ 49, 50, 51, 52, 53, 54, 55, 56, 57 }) == 0xF4, "CRC-8 check value")
local v2count = 0
local FIELDS = { "seq", "lmode", "lstart", "lfinish", "lforce", "rmode", "rstart", "rfinish", "rforce",
    "touch", "sound", "gain", "level", "side", "intensity", "seed", "mic", "moment", "open" }
for row in io.lines(root .. "/tests/fixtures/helperlink-v2-vectors.txt") do
    if row:sub(1, 1) ~= "#" and row:find(":") then
        local head, digits = row:match("^(.-)%s*:%s*(%d+)%s*$")
        local n, i = {}, 0
        for num in head:gmatch("%d+") do i = i + 1; n[FIELDS[i]] = tonumber(num) end
        assert(i == 19 and #digits == 34, "v2 vector line: " .. row)
        local s = { seq = n.seq, left = { mode = n.lmode, start = n.lstart, finish = n.lfinish, force = n.lforce },
            right = { mode = n.rmode, start = n.rstart, finish = n.rfinish, force = n.rforce },
            touch = n.touch, sound = n.sound, gain = n.gain, level = n.level, side = n.side,
            intensity = n.intensity, seed = n.seed, mic = n.mic, moment = n.moment, open = n.open == 1 }
        local cells, out = K.EncodeV2(s), {}
        for c = 1, #cells do out[c] = tostring(cells[c][1] * 4 + cells[c][2] * 2 + cells[c][3]) end
        assert(table.concat(out) == digits, "v2 vector: " .. row .. " got " .. table.concat(out))
        local d = assert(K.DecodeV2(cells))
        for _, f in ipairs({ "seq", "touch", "sound", "gain", "level", "side", "intensity", "seed", "mic", "moment", "open" }) do
            assert(d[f] == s[f], "v2 round trip " .. f)
        end
        assert(d.right.mode == s.right.mode and d.left.force == s.left.force, "v2 triggers")
        -- one flipped bit: refused by the CRC
        local flip = K.EncodeV2(s)
        local c = 3 + (v2count % 32)
        flip[c] = { 1 - flip[c][1], flip[c][2], flip[c][3] }
        assert(K.DecodeV2(flip) == nil, "v2 flip rejected")
        v2count = v2count + 1
    end
end
assert(v2count == 81, "81 v2 vectors: " .. v2count)

-- Fall damage (moment 92): the race and sex in the cue's seed, the helper's vectors
local fallcount = 0
for row in io.lines(root .. "/tests/fixtures/helperlink-fall-vectors.txt") do
    if row:sub(1, 1) ~= "#" and row:find(":") then
        local race, sex, head, digits = row:match("^(%d+) (%d+) : (.-)%s*:%s*(%d+)%s*$")
        race, sex = tonumber(race), tonumber(sex)
        local n, i = {}, 0
        for num in head:gmatch("%d+") do i = i + 1; n[FIELDS[i]] = tonumber(num) end
        assert(i == 19 and #digits == 34 and n.moment == 92, "fall vector line: " .. row)
        assert(K.RaceSexSeed(race, sex) == n.seed, "fall vector seed: " .. row)
        local r2, s2 = K.RaceSexOf(n.seed)
        assert(r2 == race and s2 == sex, "fall vector read back: " .. row)
        local s = { seq = n.seq, left = {}, right = {}, touch = n.touch, gain = n.gain, intensity = n.intensity,
            seed = K.RaceSexSeed(race, sex), moment = 92 }
        local cells, out = K.EncodeV2(s), {}
        for c = 1, #cells do out[c] = tostring(cells[c][1] * 4 + cells[c][2] * 2 + cells[c][3]) end
        assert(table.concat(out) == digits, "fall vector: " .. row .. " got " .. table.concat(out))
        fallcount = fallcount + 1
    end
end
assert(fallcount == 26, "26 fall vectors: " .. fallcount)

-- Emote voices (marker 99): the emote id in side/gain/intensity/level, race and sex in the seed
local emotecount = 0
for row in io.lines(root .. "/tests/fixtures/helperlink-emote-vectors.txt") do
    if row:sub(1, 1) ~= "#" and row:find(":") then
        local id, race, sex, head, digits = row:match("^(%d+) (%d+) (%d+) : (.-)%s*:%s*(%d+)%s*$")
        id, race, sex = tonumber(id), tonumber(race), tonumber(sex)
        local n, i = {}, 0
        for num in head:gmatch("%d+") do i = i + 1; n[FIELDS[i]] = tonumber(num) end
        assert(i == 19 and #digits == 34 and n.moment == K.EMOTE_MARKER and n.touch == 0 and n.sound == 0, "emote vector line: " .. row)
        local side, gain, intensity, level = K.EmoteFields(id)
        assert(side == n.side and gain == n.gain and intensity == n.intensity and level == n.level, "emote vector fields: " .. row)
        assert(K.EmoteOf(n.side, n.gain, n.intensity, n.level) == id, "emote vector read back: " .. row)
        assert(K.RaceSexSeed(race, sex) == n.seed, "emote vector seed: " .. row)
        local s = { seq = n.seq, left = {}, right = {}, touch = 0, sound = 0, side = side, gain = gain, intensity = intensity,
            level = level, seed = K.RaceSexSeed(race, sex), moment = K.EMOTE_MARKER }
        local cells, out = K.EncodeV2(s), {}
        for c = 1, #cells do out[c] = tostring(cells[c][1] * 4 + cells[c][2] * 2 + cells[c][3]) end
        assert(table.concat(out) == digits, "emote vector: " .. row .. " got " .. table.concat(out))
        emotecount = emotecount + 1
    end
end
assert(emotecount == 8, "8 emote vectors: " .. emotecount)

-- Emote voices: a chat line to its emote, the longest wording first
do
    local list = K.EmoteLines({
        [60] = { "LAUGH", "%s laughs at %s.", "%s laughs at you.", "You laugh at %s.", "%s laughs.", "You laugh." },
        [31] = { "CRY", "%s cries on %s's shoulder.", "%s cries." },
        [97] = { "THANK", "%s thanks %s.", "%s thanks you.", "You thank %s.", "%s thanks everyone around %s.", "You thank everyone around you." },
        [1] = "not a list", x = { "BAD", "%s." },
    })
    local function of(t) return (K.EmoteOfLine(list, t)) end
    assert(of("Bob laughs.") == 60 and of("You laugh.") == 60 and of("Bob laughs at you.") == 60, "laugh lines")
    assert(of("Bob laughs at Alice.") == 60 and select(2, K.EmoteOfLine(list, "You laugh at Alice.")) == "LAUGH", "laugh at someone")
    assert(of("Bob cries on Alice's shoulder.") == 31 and of("Bob-Realm cries.") == 31, "a name with a realm, a possessive")
    assert(of("Bob thanks everyone around him.") == 97 and of("You thank everyone around you.") == 97, "thank")
    assert(of("Bob waves.") == nil and of(nil) == nil and of("(Bob laughs.)") == nil, "not a voiced line")
    assert(of("Bob.") == nil, "a non-number key is skipped")
    assert(of("100% laughs.") == 60, "magic characters in a name")
end

-- Live (v1 switch): switch, layout, queue -----------------------------------------------------
K.SetV2(false)
assert(not K.V2() and GamepadCompanionHapticsDB.link.v1 == true, "v1 switch")
local frameCount = 0
local drawn          -- cells on screen
local function render(elapsed)
    frameCount = frameCount + 1
    if K.frame.shown and K.frame.scripts.OnUpdate then K.frame.scripts.OnUpdate(K.frame, elapsed or 1 / 144) end
    drawn = K.Decode(K.lastCells)
end
local realDraw = K.Draw
K.Draw = function(cells) K.lastCells = cells; realDraw(cells) end

assert(K.Play("thump") == false, "Play ignored while off")
K.SetEnabled(true)
assert(K.Enabled() and GamepadCompanionHapticsDB.link.on == true and GamepadCompanionHapticsDB.engine == true, "saved, others kept")
assert(K.frame.shown, "shown while on")
-- pixel-exact size: 4 physical px at 1440p = 4 * 768 / 1440 units
local unit = 4 * 768 / 1440
assert(math.abs(K.frame.width - unit * 18) < 1e-9 and math.abs(K.frame.height - unit) < 1e-9, "strip size")
assert(K.frame.points[1][1] == "BOTTOMLEFT" and K.frame.points[1][4] == 0 and K.frame.points[1][5] == 0, "bottom-left")
-- the cell textures got their colours: the first is magenta
local tex1
for _, f in ipairs(created) do if f.kind == "Texture" and f.parent == K.frame then tex1 = tex1 or f end end
assert(tex1.color[1] == 1 and tex1.color[2] == 0 and tex1.color[3] == 1, "marker drawn")
K.frame:SetScale(2); K.Layout()
assert(math.abs(K.frame.height - unit / 2) < 1e-9, "effective scale")
K.frame:SetScale(1); K.Layout()

-- queue: five events at once, a 144 fps client; each must stay >= 3 frames and >= 50 ms
for _, name in ipairs({ "micro_tap", "thump", "chime", "error", "landing_hard" }) do
    assert((K.CLIPS[name] and K.Play or K.PlaySound)(name, 5), name)
end
local runs, last, startSeq = {}, nil, K.state.seq
for _ = 1, 200 do
    render(1 / 144)
    if drawn.event ~= 0 then
        if last and last.seq == drawn.seq then
            runs[#runs].frames = runs[#runs].frames + 1
        else
            runs[#runs + 1] = { seq = drawn.seq, event = drawn.event, gain = drawn.gain, frames = 1 }
        end
    end
    last = drawn
end
assert(#runs == 5, "five events shown: " .. #runs)
local ids = { K.CLIPS.micro_tap, K.CLIPS.thump, K.SOUNDS.chime, K.SOUNDS.error, K.CLIPS.landing_hard }
for i, r in ipairs(runs) do
    assert(r.event == ids[i] and r.gain == 5, "order")
    assert(r.seq == (startSeq + i) % 16, "seq increments")
    assert(r.frames >= 3 and r.frames / 144 >= 0.05 - 1e-9, "shown long enough: " .. r.frames)
end
assert(drawn.event == 0 and drawn.seq == (startSeq + 5) % 16, "cleared after, seq kept")
-- slow client (30 fps): still >= 3 frames
assert(K.Play(K.CLIPS.crackle))
local n = 0
for _ = 1, 10 do render(1 / 30); if drawn.event == K.CLIPS.crackle then n = n + 1 end end
assert(n == 3, "3 frames at 30 fps: " .. n)
-- triggers are continuous state, no event
local seqBefore = K.state.seq
K.SetTrigger("R2", "resist", 3, 0, 9)
K.SetTrigger("left", K.MODES.weapon, 4, 8, 12)
render(1 / 60)
assert(drawn.seq == seqBefore and drawn.event == 0, "trigger change is no event")
assert(drawn.right.mode == 1 and drawn.right.start == 3 and drawn.right.force == 9, "right trigger")
assert(drawn.left.mode == 3 and drawn.left.finish == 8, "left trigger")
-- unchanged: no redraw
local redraws = 0
K.Draw = function(cells) redraws = redraws + 1; K.lastCells = cells end
K.SetTrigger("R2", "resist", 3, 0, 9)
render(1 / 60); render(1 / 60)
assert(redraws == 0, "no redraw when unchanged")
-- queue cap
for _ = 1, 20 do K.Play(1) end
assert(#K.queue == K.QUEUE_MAX, "queue capped")
-- off: hidden, queue and triggers cleared
K.SetEnabled(false)
assert(not K.frame.shown and #K.queue == 0 and K.state.right.mode == 0, "off clears")
assert(GamepadCompanionHapticsDB.link.on == false, "saved off")
-- names: ids unique, clips 1-127, sounds 128-255
local seen = {}
for name, id in pairs(K.CLIPS) do assert(id >= 1 and id <= 127 and not seen[id], name); seen[id] = true end
for name, id in pairs(K.SOUNDS) do assert(id >= 128 and id <= 255 and not seen[id], name); seen[id] = true end

-- Live v2 (the default): 34 cells, touch and sound apart, HD feels, the mic
K.SetV2(true)
assert(K.V2() and GamepadCompanionHapticsDB.link.v1 == nil, "v2 default")
K.Draw = function(cells) K.lastCells = cells; realDraw(cells) end
K.SetEnabled(true)
assert(math.abs(K.frame.width - unit * 34) < 1e-9, "v2 strip size")
local function renderV2(elapsed)
    if K.frame.scripts.OnUpdate then K.frame.scripts.OnUpdate(K.frame, elapsed or 1 / 144) end
    return assert(K.DecodeV2(K.lastCells))
end
local d0 = renderV2()
-- the id spaces never mix: a sound never through Play, a library sound (1000) as a sound
assert(K.Play("chime") == false and K.Play(1000) == false and K.Play(300) == false, "Play: clips only")
assert(K.PlaySound("chime", 3) and K.Play("thump", 6) and K.PlayFeel(300, 7, -1, 6))
assert(K.PlayFeel(12) == false, "HD feels from 128")
local seen2, prev = {}, d0
for _ = 1, 100 do
    local d = renderV2()
    if d.seq ~= prev.seq then seen2[#seen2 + 1] = d end
    prev = d
end
assert(#seen2 == 3, "three cues: " .. #seen2)
assert(seen2[1].sound == K.SOUNDS.chime and seen2[1].touch == 0 and seen2[1].gain == 3, "a sound: sound field only")
assert(seen2[2].touch == K.CLIPS.thump and seen2[2].sound == 0 and seen2[2].gain == 6, "a clip: touch field")
assert(seen2[3].touch == 300 and seen2[3].side == 1 and seen2[3].intensity == 6 and seen2[3].gain == 7, "an HD feel, left")
assert(K.PlaySound(1000, 5, 52), "a library sound")
local lib
for _ = 1, 30 do
    local d = renderV2()
    if d.seq ~= prev.seq then lib = d end
    prev = d
end
assert(lib and lib.sound == 1000 and lib.touch == 0 and lib.gain == 5 and lib.moment == 52, "library sound: the sound field")
assert(prev.touch == 0 and prev.sound == 0, "cleared after")
-- a moment's cue: HD feel and sound together, its number, open
assert(K.Cue({ moment = 42, touch = 300, sound = 900, gain = 5, open = true }))
assert(K.Cue({ moment = 1 }) == false, "nothing to play")
assert(K.Cue({ moment = 7, open = true }), "open alone")
local cues = {}
for _ = 1, 100 do
    local d = renderV2()
    if d.seq ~= prev.seq then cues[#cues + 1] = d end
    prev = d
end
assert(#cues == 2, "two moment cues: " .. #cues)
assert(cues[1].moment == 42 and cues[1].open and cues[1].touch == 300 and cues[1].sound == 900, "moment, open, both")
assert(cues[2].moment == 7 and cues[2].open and cues[2].touch == 0, "open alone")
assert(prev.moment == 0 and not prev.open, "moment cleared after")
-- Fall damage: its seed (race and sex) on screen as sent; Hush drops it (the yell is a sound)
assert(K.Cue({ moment = 92, touch = 300, seed = K.RaceSexSeed(8, 3) }))
local fallCue
for _ = 1, 50 do
    local d = renderV2()
    if d.seq ~= prev.seq then fallCue = d end
    prev = d
end
assert(fallCue and fallCue.moment == 92 and fallCue.seed == 136, "the fall's seed: " .. tostring(fallCue and fallCue.seed))
do
    local stack = ns.Stack
    ns.Stack = { Is = function(k) return k == "hush" end }
    assert(K.Cue({ moment = 92, touch = 300, seed = 136 }) and K.queue[#K.queue].seed == nil, "hushed: no race and sex")
    ns.Stack = stack
    for _ = 1, 50 do prev = renderV2() end
end
K.SetMic("pulse")
local dm = renderV2()
assert(dm.mic == K.MIC.pulse and dm.seq == prev.seq, "mic: a state, no cue")
-- the trigger row (WoW Helper docs/TRIGGERS.md): the vector pinned in protocol2.rs too
do
    local cells = K.EncodeTrigRow({ left = { shape = 12, value = 0.35, count = 0 }, right = { shape = 1023, value = nil, count = 15 } })
    local t = {}
    for i, c in ipairs(cells) do t[i] = c[1] * 4 + c[2] * 2 + c[3] end
    assert(table.concat(t, " ") == "4 0 3 0 0 6 1 0 1 7 7 7 7 7 7 7 7 6 0", "trigger row vector: " .. table.concat(t, " "))
    local d = K.DecodeTrigRow(cells)
    assert(d.left.shape == 12 and d.left.value == 0.35 and d.right.shape == 1023 and d.right.value == nil and d.right.count == 15, "decoded")
    for k = 2, #cells do
        for ch = 1, 3 do
            local bad = {}
            for i, c in ipairs(cells) do bad[i] = { c[1], c[2], c[3] } end
            bad[k][ch] = 1 - bad[k][ch]
            assert(K.DecodeTrigRow(bad) == nil, "a flipped bit is caught: cell " .. k)
        end
    end
    -- drawn only while a trigger holds a shape; redrawn when a value moves by 1/100
    K.SetTrigRow({ left = { shape = 0 }, right = { shape = 0 } })
    assert(K.trig == nil, "no shape: no row")
    K.SetTrigRow({ right = { shape = 6, value = 0.401 } })
    local first = K.trig
    K.SetTrigRow({ right = { shape = 6, value = 0.403 } })
    assert(K.trig == first, "under 1/100: unchanged")
    K.SetTrigRow({ right = { shape = 6, value = 0.42 } })
    assert(K.trig ~= first and K.trig.right.value == 0.42, "moved: redrawn")
    K.SetTrigRow(nil)
    assert(K.trig == nil, "cleared")
end
-- the trigger row: WoW Helper's generated vectors (tests/fixtures, written by its protocol2.rs)
local trigcount = 0
for row in io.lines(root .. "/tests/fixtures/helperlink-trigger-vectors.txt") do
    if row:sub(1, 1) ~= "#" and row:find(":") then
        local head, digits = row:match("^(.-)%s*:%s*(%d+)%s*$")
        local v = {}
        for num in head:gmatch("%d+") do v[#v + 1] = tonumber(num) end
        local function pick(shape, value, count) return { shape = shape, value = value <= 100 and value / 100 or nil, count = count } end
        local r = { left = pick(v[1], v[2], v[3]), right = pick(v[4], v[5], v[6]) }
        local cells, out = K.EncodeTrigRow(r), {}
        for c = 1, #cells do out[c] = tostring(cells[c][1] * 4 + cells[c][2] * 2 + cells[c][3]) end
        assert(#cells == 19 and table.concat(out) == digits, "trigger vector: " .. row .. " got " .. table.concat(out))
        local d = assert(K.DecodeTrigRow(cells), "decoded: " .. row)
        for _, side in ipairs({ "left", "right" }) do
            assert(d[side].shape == r[side].shape and d[side].count == r[side].count and d[side].value == r[side].value, "round trip " .. side .. ": " .. row)
        end
        trigcount = trigcount + 1
    end
end
assert(trigcount == 61, "61 trigger vectors: " .. trigcount)

-- Fishing (WoW Helper's src/fishing.rs): the cues of moments 93-95 as any cue, and the trigger
-- rows WoW Helper plays while the line is out (R2 one of shapes 18-21, L2 the addon's)
do
    local C = { fishLand = 93, fishBite = 94, fishCatch = 95 }
    local SHAPES = { flick = 18, tug = 19, reel = 20, line = 21 }
    local cues, trigs = 0, 0
    for row in io.lines(root .. "/tests/fixtures/helperlink-fishing-vectors.txt") do
        local key, head, digits = row:match("^cue (%w+) : (.-)%s*:%s*(%d+)%s*$")
        if key then
            local n, i = {}, 0
            for num in head:gmatch("%d+") do i = i + 1; n[FIELDS[i]] = tonumber(num) end
            assert(i == 19 and n.moment == C[key], "fishing cue: " .. row)
            local s = { seq = n.seq, left = {}, right = {}, touch = n.touch, gain = n.gain, intensity = n.intensity,
                seed = n.seed, moment = n.moment }
            local cells, out = K.EncodeV2(s), {}
            for c = 1, #cells do out[c] = tostring(cells[c][1] * 4 + cells[c][2] * 2 + cells[c][3]) end
            assert(table.concat(out) == digits, "fishing cue: " .. row .. " got " .. table.concat(out))
            cues = cues + 1
        end
        local shape, thead, tdigits = row:match("^trig (%w+) : (.-)%s*:%s*(%d+)%s*$")
        if shape then
            local v = {}
            for num in thead:gmatch("%d+") do v[#v + 1] = tonumber(num) end
            assert(v[4] == SHAPES[shape], "fishing trigger shape: " .. row)
            local d = assert(K.DecodeTrigRow((function()
                local cells = {}
                for ch in tdigits:gmatch("%d") do
                    local x = tonumber(ch)
                    cells[#cells + 1] = { math.floor(x / 4) % 2, math.floor(x / 2) % 2, x % 2 }
                end
                return cells
            end)()), "fishing trigger row decodes: " .. row)
            assert(d.right.shape == SHAPES[shape] and d.right.value == nil and d.left.shape == v[1], "fishing trigger row: " .. row)
            trigs = trigs + 1
        end
    end
    assert(cues == 3 and trigs == 8, "fishing vectors: " .. cues .. " cues, " .. trigs .. " trigger rows")
end

-- One line (Lab › Strip, full-feel plan 4b): main 34, the light row from 34 (padded to 23,
-- yellow first), the trigger row from 57: 76 cells; only when WoW Helper says it reads it
do
    K.SetEnabled(true)
    assert(K.Strip() == "stacked" and not K.OneLine(), "stacked by default")
    K.Layout()
    local unit = K.frame.height
    local lt, tt = K.lightTextures, K.trigTextures
    assert(lt[1].points[1][4] == 0 and lt[1].points[1][5] == unit and tt[1].points[1][5] == 2 * unit, "stacked: rows above")
    K.SetStrip("oneline")
    assert(GamepadCompanionHapticsDB.link.strip == "oneline", "saved")
    assert(not K.OneLine() and lt[1].points[1][5] == unit, "WoW Helper hasn't said it reads one line: stacked")
    WowHelperData = { stripOneLine = true }
    K.MarkDirty()
    K.Step(0)
    assert(K.OneLine(), "one line")
    local function x(tex) return tex.points[1][4] end
    assert(math.abs(x(lt[1]) - 34 * unit) < 1e-6 and lt[1].points[1][5] == 0, "the light row from cell 34")
    assert(math.abs(x(tt[1]) - 57 * unit) < 1e-6 and tt[1].points[1][5] == 0, "the trigger row from cell 57")
    assert(math.abs(K.frame.width - 76 * unit) < 1e-6, "76 cells")
    K.DrawLight(K.EncodeLight({ version = 0, hold = 3 }))
    assert(lt[1].color[1] == 1 and lt[1].color[2] == 1 and lt[1].color[3] == 0, "yellow marker first")
    for i = 18, 23 do
        local c = lt[i].color
        assert(lt[i]:IsShown() and c[1] == 0 and c[2] == 0 and c[3] == 0, "padded to 23 with black: " .. i)
    end
    K.DrawLight(nil)
    assert(not lt[1]:IsShown() and not lt[20]:IsShown(), "no light row: hidden")
    -- (WoW Helper says no more: back to stacked at the next draw)
    WowHelperData.stripOneLine = false
    K.MarkDirty()
    K.Step(0)
    assert(not K.OneLine() and lt[1].points[1][5] == unit, "stacked again")
    K.DrawLight(K.EncodeLight({ version = 0, hold = 3 }))
    assert(not lt[18]:IsShown(), "stacked: no padding")
    K.SetStrip("stacked")
    assert(GamepadCompanionHapticsDB.link.strip == nil, "Stacked: nothing saved")
    WowHelperData = nil
    K.SetEnabled(false)
    print("PASS: one-line strip: 34 + 23 + 19 = 76 cells, only when WoW Helper reads it")
end

-- HD off on light row bit 3 (WoW Helper's HD-RELEASE.md): in the CRC, both versions; a row
-- drawn even without lights while HD is off
do
    for _, v in ipairs({ 0, 1 }) do
        local row = K.DecodeLight(K.EncodeLight({ version = v, hold = 3, hdOff = true }))
        assert(row and row.hdOff == true and row.hold == 3, "hdOff round trip, version " .. v)
        row = K.DecodeLight(K.EncodeLight({ version = v, hold = 3 }))
        assert(row and row.hdOff == false, "HD on: bit 3 clear, version " .. v)
    end
    local light = K.light
    K.light = nil
    local hd = true
    ns.HelperCues = { HDMode = function() return hd and "auto" or "off" end }
    assert(K.LightRow() == nil, "HD on, no lights: no row")
    hd = false
    local r = K.LightRow()
    assert(r and r.hdOff == true and K.DecodeLight(K.EncodeLight(r)).hdOff == true, "HD off, no lights: a bare row says so")
    K.light = { version = 1, hold = 5 }
    assert(K.LightRow().hdOff == true and K.LightRow().hold == 5, "HD off with lights: their row, bit 3 set")
    hd = true
    assert(K.LightRow().hdOff == nil, "HD back on: bit clear")
    K.light, ns.HelperCues = light, nil
    print("PASS: HD off on the light row's bit 3")
end

-- 0.59.4: the old strip saved by Lab's former "HD" switch comes back to the wide one, once
do
    local saved = GamepadCompanionHapticsDB
    GamepadCompanionHapticsDB = { link = { on = true, v1 = true } }
    assert(K.V2() == true, "v1 saved by the old switch: the wide strip again")
    K.SetV2(false)
    assert(K.V2() == false, "after that, the strip version is kept (tests, the debug path)")
    GamepadCompanionHapticsDB = saved
    print("PASS: the old HD switch's v1 cleared once")
end

-- The spell row (WoW Helper's reader, same contract): 13 cells, blue first, 36 bits LE: seq 0-3,
-- phase 4-5, spell id 6-25, spare 26-27, CRC-8 (0x07, init 0) over bits 0-27 at 28-35; three rows
-- up (stacked) or from cell 76 (one line: 89 cells); drawn only while WowHelperData.spellRow
do
    -- (an independent CRC: the 28 bits as bytes, LSB first, the last padded with zeros)
    local function bxor(a, b)
        local r, m = 0, 1
        while a > 0 or b > 0 do
            if a % 2 ~= b % 2 then r = r + m end
            a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
        end
        return r
    end
    local function crc28(seq, phase, id)
        local v = seq + phase * 16 + id * 64
        local crc = 0
        for _ = 1, 4 do
            crc = bxor(crc, v % 256)
            v = math.floor(v / 256)
            for _ = 1, 8 do
                if crc >= 128 then crc = bxor((crc * 2) % 256, 7) else crc = (crc * 2) % 256 end
            end
        end
        return crc
    end
    local function bitsOf(cells)
        local bits = {}
        for c = 2, #cells do for k = 1, 3 do bits[#bits + 1] = cells[c][k] end end
        return bits
    end
    local function num(bits, from, n)
        local v = 0
        for i = n - 1, 0, -1 do v = v * 2 + bits[from + i + 1] end
        return v
    end
    -- a known vector, field by field
    local cells = K.EncodeSpellRow({ seq = 5, phase = 1, id = 133 })
    assert(#cells == 13 and cells[1][1] == 0 and cells[1][2] == 0 and cells[1][3] == 1, "13 cells, blue first")
    local bits = bitsOf(cells)
    assert(#bits == 36 and num(bits, 0, 4) == 5 and num(bits, 4, 2) == 1 and num(bits, 6, 20) == 133
        and num(bits, 26, 2) == 0, "fields little-endian at 0, 4, 6, 26")
    assert(num(bits, 28, 8) == crc28(5, 1, 133), "CRC-8 over bits 0-27: " .. num(bits, 28, 8) .. " " .. crc28(5, 1, 133))
    -- round trips; a flipped bit rejected
    local rejected, n = 0, 0
    for _, id in ipairs({ 0, 1, 133, 2050, 19750, 1048575 }) do
        for phase = 0, 3 do
            for _, seq in ipairs({ 0, 7, 15 }) do
                local c = K.EncodeSpellRow({ seq = seq, phase = phase, id = id })
                local d = assert(K.DecodeSpellRow(c), "decoded")
                assert(d.seq == seq and d.phase == phase and d.id == id, "round trip " .. id)
                assert(num(bitsOf(c), 28, 8) == crc28(seq, phase, id), "crc " .. id)
                n = n + 1
                local flip = c[2 + (id + phase + seq) % 12]
                local k = 1 + (seq % 3)
                flip[k] = 1 - flip[k]
                if not K.DecodeSpellRow(c) then rejected = rejected + 1 end
            end
        end
    end
    assert(n == 72 and rejected == 72, "every flip rejected: " .. rejected)
    assert(select(2, K.DecodeSpellRow(K.EncodeTrigRow({}))) == "marker", "a trigger row is not a spell row")
    -- (past 20 bits: phase only)
    assert(K.DecodeSpellRow(K.EncodeSpellRow({ seq = 1, phase = 2, id = 1311676 })).id == 0, "an id past 20 bits: 0")

    -- the strip: gated, stacked three rows up, one line from cell 76
    local t = 100
    GetTime = function() return t end
    K.SetEnabled(true)
    K.Layout()
    local unit = K.frame.height
    local st = K.spellTextures
    assert(#st == 13 and st[1].points[1][5] == 3 * unit and st[1].points[1][4] == 0, "stacked: three rows up")
    K.MarkDirty()
    K.Step(0)
    assert(not st[1]:IsShown(), "WoW Helper hasn't said it reads it: no row")
    WowHelperData = { spellRow = true }
    K.MarkDirty()
    K.Step(0)
    assert(st[1]:IsShown() and st[1].color[3] == 1, "spellRow: drawn, blue first")
    -- (a spell event with a cue in the same frame: on screen with that cue)
    while #K.queue > 0 do K.Step(1) end
    for _ = 1, 10 do K.Step(1) end
    t = t + 1
    assert(K.Cue({ moment = 72, touch = 200 }), "a cue")
    local ev = K.SpellEvent(K.SPELL_CASTING, 133)
    assert(K.queue[#K.queue].spell == ev, "the spell event goes with the cue of its frame")
    t = t + 0.02
    K.Step(0.02)
    local d = K.DecodeSpellRow((function() local c = {} for i = 1, 13 do c[i] = st[i].color end return c end)())
    assert(d and d.phase == 1 and d.id == 133 and d.seq == ev.seq, "drawn with its cue")
    -- (the event first, the cue after, same frame: still together)
    for _ = 1, 10 do t = t + 0.1; K.Step(0.1) end
    local ev2 = K.SpellEvent(K.SPELL_RELEASED, 133)
    assert(K.Cue({ moment = 73, sound = 5 }) and K.queue[#K.queue].spell == ev2, "the cue after, same frame")
    -- (no cue that frame: on its own, the next frame)
    for _ = 1, 10 do t = t + 0.1; K.Step(0.1) end
    local ev3 = K.SpellEvent(K.SPELL_STOPPED, 0)
    t = t + 0.02
    K.Step(0.02)
    assert(K.spell == ev3 and ev3.seq == (ev2.seq + 1) % 16, "on its own, seq + 1")
    -- one line: from cell 76, 89 cells; the trigger row's place black while it has none
    K.SetStrip("oneline")
    WowHelperData.stripOneLine = true
    K.MarkDirty()
    K.Step(0)
    assert(K.OneLine() and math.abs(st[1].points[1][4] - 76 * unit) < 1e-6 and st[1].points[1][5] == 0, "one line: from cell 76")
    assert(math.abs(K.frame.width - 89 * unit) < 1e-6, "89 cells")
    local tt = K.trigTextures
    assert(tt[1]:IsShown() and tt[1].color[1] == 0 and tt[1].color[2] == 0 and tt[1].color[3] == 0, "no trigger row: black there")
    -- (WoW Helper drops it: no row, 76 cells)
    WowHelperData.spellRow = nil
    K.MarkDirty()
    K.Step(0)
    assert(not st[1]:IsShown() and math.abs(K.frame.width - 76 * unit) < 1e-6 and not tt[1]:IsShown(), "no spell row: 76, as before")
    K.SetStrip("stacked")
    WowHelperData = nil
    K.SetEnabled(false)
    GetTime = nil
    print("PASS: spell row: 13 cells, CRC, round trips, stacked and one line (89), gated on spellRow, with its cue")
end

K.SetEnabled(false)

print("HelperLink: ok (2000 round trips, " .. rejected .. " flips rejected, " .. #vectors .. " fixture vectors, " .. v2count .. " v2 vectors, " .. trigcount .. " trigger vectors, " .. fallcount .. " fall vectors, " .. emotecount .. " emote vectors)")
