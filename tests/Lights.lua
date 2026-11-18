-- Lights: one light model, two renderers (C:\games\WowHelper\docs\LIGHTS.md).
-- lua5.1 tests/Lights.lua <addon folder>
--   The light row's vectors and the bar samples come from WoW Helper
--   (cargo test write_light_fixture / write_light_samples -- --ignored).
local root = arg[1] or "."

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
function methods:RegisterUnitEvent(e) self.events[e] = true end
function methods:CreateTexture() return new("Texture", nil, self) end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(v) self.shown = v and true or false end
function methods:IsShown() return self.shown end
function methods:GetEffectiveScale() return 1 end
function methods:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function CreateFrame(kind, name, parent) return new(kind, name, parent) end
function GetPhysicalScreenSize() return 2560, 1440 end
local now = 100
function GetTime() return now end
UnitClass = function() return "Mage", "MAGE" end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
GamepadCompanionHapticsDB = { engine = true, light = true }
local timers = {}
C_Timer = { After = function(t, fn) timers[#timers + 1] = { now + t, fn } end }

-- the light voices (Haptics.lua's mixer): what the game would set
local voices, sets, clears = {}, 0, 0
local ns = { Haptics = {
    DB = function() return GamepadCompanionHapticsDB end,
    Light = function(id, fn, prio) voices[id] = { fn = fn, prio = prio, start = now } end,
    LightStop = function(id) if id then voices[id] = nil else voices = {} end end,
} }
local function Led()
    local best, r, g, b
    for _, v in pairs(voices) do
        local vr, vg, vb = v.fn(now, v)
        if vr and (not best or v.prio > best.prio) then best, r, g, b = v, vr, vg, vb end
    end
    return r, g, b
end

for _, file in ipairs({ "HelperLink.lua", "Stack.lua", "Hush.lua", "LightPresets.lua", "Lights.lua" }) do
    assert(loadfile(root .. "/" .. file))("GamepadCompanion", ns)
end
local K, LT = ns.HelperLink, ns.Lights
local checks = 0
local function ok(cond, msg) checks = checks + 1; assert(cond, msg) end
local function near(a, b, eps, msg) ok(math.abs(a - b) < (eps or 1e-4), (msg or "") .. ": " .. tostring(a) .. " vs " .. tostring(b)) end

-- The light row: the helper's vectors -----------------------------------------------------
local n = 0
for row in io.lines(root .. "/tests/fixtures/helperlink-lights-vectors.txt") do
    if row:sub(1, 1) ~= "#" and row:find(":") then
        local head, digits = row:match("^(.-)%s*:%s*(%d+)%s*$")
        local v = {}
        for num in head:gmatch("%d+") do v[#v + 1] = tonumber(num) end
        local r = { version = v[1], resting = v[2] == 1, hold = v[3], holdTint = v[4], holdStrength = v[5], progress = v[6],
            cue = v[7], cueTint = v[8], cueStrength = v[9] }
        local cells, out = K.EncodeLight(r), {}
        for c = 1, #cells do out[c] = tostring(cells[c][1] * 4 + cells[c][2] * 2 + cells[c][3]) end
        ok(#cells == 17 and table.concat(out) == digits, "light vector: " .. row .. " got " .. table.concat(out))
        local d = assert(K.DecodeLight(cells))
        for k, x in pairs(r) do ok(d[k] == x, "light round trip " .. k) end
        local flip = K.EncodeLight(r)
        local c = 2 + (n % 16)
        flip[c] = { 1 - flip[c][1], flip[c][2], flip[c][3] }
        ok(K.DecodeLight(flip) == nil, "a flipped bit is refused")
        n = n + 1
    end
end
ok(n == 61, "61 light vectors: " .. n)

-- Version 1: each light's dots and mic (the helper's vectors) --------------------------------
local n1 = 0
for row in io.lines(root .. "/tests/fixtures/helperlink-lights-v1-vectors.txt") do
    if row:sub(1, 1) ~= "#" and row:find(":") then
        local head, digits = row:match("^(.-)%s*:%s*(%d+)%s*$")
        local v = {}
        for num in head:gmatch("%d+") do v[#v + 1] = tonumber(num) end
        local r = { version = v[1], resting = v[2] == 1, hold = v[3], holdTint = v[4], holdStrength = v[5], progress = v[6],
            cue = v[7], cueTint = v[8], cueStrength = v[9], holdDots = v[10], holdMic = v[11], cueDots = v[12], cueMic = v[13] }
        local cells, out = K.EncodeLight(r), {}
        for c = 1, #cells do out[c] = tostring(cells[c][1] * 4 + cells[c][2] * 2 + cells[c][3]) end
        ok(#cells == 23 and table.concat(out) == digits, "v1 vector: " .. row .. " got " .. table.concat(out))
        local d = assert(K.DecodeLight(cells))
        for k, x in pairs(r) do ok(d[k] == x, "v1 round trip " .. k) end
        n1 = n1 + 1
    end
end
ok(n1 == 61, "61 v1 vectors: " .. n1)

-- Presets: generated, sampled as the helper does -----------------------------------------
ok(#ns.LIGHT_PRESETS >= 32, "presets")
local function byte(c) return c / 255 end
local ctx = { tint = { byte(255), byte(191), byte(38) }, base = { byte(26), byte(77), byte(255) }, strength = 0.75 }
local samples = 0
for row in io.lines(root .. "/tests/fixtures/light-samples.txt") do
    if row:sub(1, 1) ~= "#" then
        local id, t, r, g, b = row:match("^(%d+) ([%d%.]+) : ([%d%.]+) ([%d%.]+) ([%d%.]+)")
        local l = LT.Light(tonumber(id))
        local sr, sg, sb = LT.Sample(l, tonumber(t), ctx)
        near(sr, tonumber(r), 2e-5, "sample r " .. row)
        near(sg, tonumber(g), 2e-5, "sample g " .. row)
        near(sb, tonumber(b), 2e-5, "sample b " .. row)
        samples = samples + 1
    end
end
ok(samples > 200, "samples: " .. samples)

-- Every moment has a Recommended light of the right kind
for _, e in ipairs(LT.EVENTS) do
    local l = LT.Light(LT.DefaultLight(e.key))
    ok(l, "a light for " .. e.key)
    ok((l.kind == "hold") == (e.state == true), e.key .. ": " .. l.kind)
end
-- every state is on the stack, in the Recommended order once
local inStack = {}
for _, key in ipairs(LT.STACK) do inStack[key] = (inStack[key] or 0) + 1 end
for _, e in ipairs(LT.EVENTS) do if e.state then ok(inStack[e.key] == 1, "on the stack once: " .. e.key) end end

-- Migration from 0.27 (an effect, a colour, a level) --------------------------------------
GamepadCompanionHapticsDB.lightEvents = {
    crit = { on = true, effect = "boost", color = "red", level = 1 },     -- its default: its own light
    loot = { on = true, effect = "double", color = "gold", level = 0.4 }, -- another shape
    kill = { on = false, effect = "glow", color = "white", level = 0.5 },
}
GamepadCompanionHapticsDB.lightBase = { mode = "class", level = 0.35, breathe = true }
local s = LT.Settings("crit")
ok(s.light == LT.LightByKey("crit").id and s.strength == 7 and s.color == "red" and s.effect == nil and s.level == nil, "crit migrated")
s = LT.Settings("loot")
ok(s.light == LT.LightByKey("double").id and s.strength == 2, "loot: Double at 3/8")
s = LT.Settings("kill")
ok(s.light == LT.LightByKey("glow").id and s.on == false and s.strength == 3, "kill: Glow, off kept")
ok(LT.Base().light == "breathe" and LT.Base().breathe == nil, "base: Breathe")
-- L8: a fresh profile's mic is Off (Recommended); only 0.28's unasked "off" meant In combat
ok(LT.Base().mic == "off", "a fresh profile: the mic Off")
GamepadCompanionHapticsDB.lightBase.micV, GamepadCompanionHapticsDB.lightBase.mic = nil, "off"
ok(LT.Base().mic == "combat", "0.28's unasked off: In combat")
-- dots and mic: each moment's Recommended, as data (older settings get it)
-- L2: a moment with no pattern leaves the mic (Pass, 0 on the strip), only an explicit Off sends Off
ok(LT.Settings("crit").dots == "spark" and LT.Settings("crit").mic == "pass", "crit: Spark, the mic left alone")
local _, critMic = LT.Patterns("crit")
ok(critMic == 0, "crit's mic: 0 on the strip (leave), not 1 (Off)")
local lootDots, lootMic = LT.Patterns("loot")
ok(lootDots == 0 and lootMic == 0, "loot: leaves both")
ok(LT.Settings("whisper").mic == "pulse" and LT.Settings("lowHp").dots == "pair" and LT.Settings("lowHp").mic == "pulse", "whisper, low health")
ok(LT.PatternWords("lowHp") == "Pair · Mic pulse", "words: " .. tostring(LT.PatternWords("lowHp")))
ok(LT.PatternWords("kill") == "All" and LT.PatternWords("loot") == nil, "kill: All; loot: nothing")
local d1, m1 = LT.Patterns("readyCheck")
ok(d1 == LT.DOT.all.code and m1 == LT.MIC.pulse.code, "codes")
LT.Settings("crit").dots = "3"
ok(not LT.IsDefault("crit") and LT.PatternWords("crit") == "3 dots", "changed: not Default")
LT.Default("crit")
ok(LT.Settings("crit").dots == "spark" and LT.IsDefault("crit"), "Default: Spark again")
local mics = table.concat(LT.MicMoments(), ",")
ok(mics:find("Whisper") and mics:find("Low health"), "the mic's moments: " .. mics)
GamepadCompanionHapticsDB.lightBase.mic = "off"
ok(LT.Base().mic == "off", "a chosen Off stays")
LT.Default("crit")
ok(LT.IsDefault("crit"), "Default")
-- a light deleted in WoW Helper: back to the moment's own
GamepadCompanionHapticsDB.lightEvents.crit = { on = true, light = 200, color = "base", strength = 7 }
ok(LT.Settings("crit").light == LT.LightByKey("crit").id, "unknown id falls back")

-- The player's own lights (WoW Helper's data addon) ---------------------------------------
WowHelperData = { lights = { { id = 128, key = "u_128", name = "Ember crit", kind = "once", group = "Yours",
    bar = { { 0, "tint", 1, "step" }, { 0.4, "dark", 0, "out" } } },
    { id = 20, key = "crit", name = "Critical hit", kind = "once", group = "Combat", bar = { { 0, { 1, 0, 0 }, 1, "step" } } } } }
local mine = LT.Light(128)
ok(mine and mine.yours and mine.name == "Ember crit", "the player's own listed")
ok(LT.Light(20).bar[1][2][1] == 1, "an edited preset replaces the shipped one")
GamepadCompanionHapticsDB.lightEvents.crit = { on = true, light = 128, color = "gold", strength = 7 }
ok(LT.Settings("crit").light == 128, "an own light kept")
WowHelperData = nil
LT.Default("crit")

-- Game renderer (link off) ----------------------------------------------------------------
ok(not LT.HelperDrives(), "the game draws with the link off")
LT.ApplyBase()
local r, g, b = Led()
ok(r and b > g and g > r, "the resting light: the mage's colour")
local before = b
now = now + 2.5   -- Breathe: brighter half way
r, g, b = Led()
ok(b ~= before, "Breathe moves")
LT.Fire("crit")
r, g, b = Led()
ok(r > 0.9 and g > 0.9 and b > 0.9, "a crit: white first")
now = now + 1
r, g, b = Led()
ok(b < 0.5, "then back to the resting light")
ok(K.light == nil, "no light row with the link off")

-- WoW Helper draws (link on) --------------------------------------------------------------
local drawn
K.DrawLight = function(cells) drawn = cells and K.DecodeLight(cells) end
K.SetEnabled(true)
ok(LT.HelperDrives(), "WoW Helper draws with the link on")
K.Step(0)
ok(drawn and drawn.resting and drawn.hold == LT.LightByKey("breathe").id and drawn.holdTint == 27, "the resting light on the row: Breathe in the mage's colour")
-- the game keeps only a steady colour under it, never cleared
local vr, vg, vb = Led()
local vr2 = select(1, Led())
ok(vr and vr == vr2, "a steady colour from the game")
-- L5: version 1 only to a helper that reads it (WowHelperData.lightRow), else version 0
WowHelperData = nil
LT.SendHold(); K.Step(1 / 60)
ok(#K.EncodeLight(K.light) == 17 and drawn.version == 0, "no WoW Helper data: version 0, 17 cells")
WowHelperData = { lightRow = 1 }
LT.SendHold(); K.Step(1 / 60)
ok(#K.EncodeLight(K.light) == 23 and drawn.version == 1, "lightRow 1: version 1, 23 cells")
-- L2-12: a caller without a version (a Try's hold, a cue's start) gets the gate's
WowHelperData = nil
K.SetLight({ hold = 3, holdTint = 1, holdStrength = 4, progress = 0 })
ok(K.light.version == 0, "L2-12: no lightRow: version 0")
LT.Try("combat")
ok(K.light.version == 0, "L2-12: a state's Try: version 0")
WowHelperData = { lightRow = 1 }
K.SetLight({ hold = 3, holdTint = 1, holdStrength = 5, progress = 0 })
ok(K.light.version == 1, "lightRow 1: version 1")
LT.SendHold(); K.Step(1 / 60)
-- a crit: a cue on the row, nothing animated in the game
voices.lt_crit = nil
LT.Fire("crit")
for _ = 1, 2 do K.Step(1 / 60) end
ok(drawn.cue == LT.LightByKey("crit").id and drawn.cueStrength == 7, "the crit's cue")
ok(drawn.cueDots == LT.DOT.spark.code and drawn.cueMic == 0, "with its dots, the mic left (L2)")
ok(voices.lt_crit == nil, "the game doesn't animate it")
for _ = 1, 10 do K.Step(1 / 30) end
ok(drawn.cue == 0, "the cue cleared after it was shown")
ok(drawn.hold == LT.LightByKey("breathe").id, "what holds stays")
-- a cast: the hold changes, its progress follows
UnitCastingInfo = function() return "Fireball", nil, nil, now * 1000, (now + 2) * 1000 end
local lf
for _, f in ipairs(created) do if f.events.UNIT_SPELLCAST_SUCCEEDED and f.events.PLAYER_REGEN_DISABLED then lf = f end end
lf.scripts.OnEvent(lf, "UNIT_SPELLCAST_START", "player")
K.Step(1 / 60)
ok(drawn.hold == LT.LightByKey("cast").id and not drawn.resting and drawn.progress == 1, "casting holds, progress 0")
now = now + 1
LT.Tick(0.1)
K.Step(1 / 60)
ok(drawn.progress == 8, "half way: step 8 of 15 (" .. drawn.progress .. ")")
lf.scripts.OnEvent(lf, "UNIT_SPELLCAST_SUCCEEDED", "player")
for _ = 1, 2 do K.Step(1 / 60) end
ok(drawn.hold == LT.LightByKey("breathe").id and drawn.cue == LT.LightByKey("release").id, "released: the cue, back to resting")
UnitCastingInfo = nil
-- a loot glint over low health: it plays (a glint adds light; states rank under moments)
LT.Settings("loot").on = true
LT.StartState("lowHp")
for _ = 1, 20 do K.Step(1 / 30) end
ok(drawn.hold == LT.LightByKey("lowHp").id, "low health holds")
ok(drawn.holdDots == LT.DOT.pair.code and drawn.holdMic == LT.MIC.pulse.code, "low health: Pair, the mic pulsing")
LT.Fire("loot")
for _ = 1, 2 do K.Step(1 / 60) end
ok(drawn.cue == LT.Settings("loot").light and drawn.hold == LT.LightByKey("lowHp").id, "a loot glint over low health")
for _ = 1, 10 do K.Step(1 / 30) end
LT.EndState("lowHp")
K.Step(1 / 60)
ok(drawn.hold == LT.LightByKey("breathe").id, "back to resting")
-- The stack (reactions, FrameGambit's model) --------------------------------------------------
local St, S = ns.Stack, LT.stack
local function id(res) return res.row and res.row.id or "otherwise" end
local function Now() local r = S:Now(); return id(r.bar), id(r.mic), id(r.dots) end
-- 0.48's states and the mic card's "In combat" become reactions (silently; its bar passing)
local db = GamepadCompanionHapticsDB
db.lightBase.stackV = nil
db.lightBase.mic = "combat"
db.lightEvents.combat = nil
db.lightStack = { order = { "dead", "afk", "lowHp", "cast", "halo", "taxi", "stealth", "combat", "swimming", "mounted", "moving", "rested" } }
db.lightEvents.rested = { on = true, light = LT.LightByKey("ember").id, color = "gold", strength = 2, dots = "off", mic = "off" }
LT.Migrate()
ok(type(db.lightStack.rows) == "table" and db.lightStack.order == nil, "migrated: reactions")
local cs = LT.Settings("combat")
ok(cs.on and cs.light == 0 and cs.mic == "on" and LT.Base().mic == "off", "In combat sets only the mic")
local rs = LT.Settings("rested")
ok(rs.on and rs.light == LT.LightByKey("ember").id and rs.dots == "pass" and rs.mic == "pass", "a 0.48 state's light kept, its off dots / mic now Pass")
ok(LT.Settings("lowHp").dots == "pair", "a state's own dots kept")
ok(LT.Def("rested").label == "Resting" and LT.Def("rested").state, "a reaction is a light moment that lasts")
db.lightEvents.rested = nil
S:Row("rested").on = false
UnitAffectingCombat = function() return true end
St.ReadAll(); LT.ApplyBase()
local bar, mic = Now()
ok(bar == "otherwise" and mic == "combat", "in combat: the mic from In combat, the bar from Otherwise")
ok(K.state.mic == K.MIC.on, "mic on in combat")
ok(K.DecodeV2(K.EncodeV2(K.state)).mic == K.MIC.on, "the strip carries it (v2 bits 78-79)")
K.Step(1 / 60)
ok(drawn.hold == LT.LightByKey("breathe").id and drawn.resting and drawn.holdMic == LT.MIC.on.code, "the row: Otherwise's bar, In combat's mic")
-- moving too: Movement sets the bar (it's on now), In combat still the mic (Movement passes it)
S:SetOn("moving", true)
GetUnitSpeed = function() return 7 end
St.ReadAll(); St.Refresh()
bar, mic = Now()
ok(bar == "moving" and mic == "combat", "pass-through: bar from Movement, mic from In combat")
K.Step(1 / 60)
ok(drawn.hold == LT.LightByKey("steady").id and not drawn.resting and drawn.holdMic == LT.MIC.on.code, "the row has both")
local drv = S:Driving()
ok(drv.moving[1] == "bar" and drv.combat[1] == "mic", "the teal rows: Movement (bar), In combat (mic)")
-- the order decides: Movement above In combat, Movement's mic Off: the mic goes off
local function pos(key) for i, r in ipairs(S:Rows()) do if r.id == key then return i end end end
ok(S:Rows()[1].id == "dead", "Recommended order")
S:MoveTo("moving", pos("combat"))
ok(pos("moving") < pos("combat") and db.lightStack.rows ~= nil, "dragged above In combat: saved in the Feel profile's table")
LT.Settings("moving").mic = "off"
LT.SendHold()
bar, mic = Now()
ok(bar == "moving" and mic == "moving", "Movement above: its mic Off wins")
S:MoveTo("moving", pos("combat") + 1)
bar, mic = Now()
ok(bar == "moving" and mic == "combat", "back below: In combat's mic again")
-- requirements: Movement only while mounted
S:AddRequirement("moving", "mounted")
IsMounted = function() return false end
St.ReadAll(); St.Refresh()
ok(Now() == "otherwise", "Movement + Mounted: not mounted, no match")
IsMounted = function() return true end
St.ReadAll(); St.Refresh()
ok(Now() == "mounted" or Now() == "moving", "mounted: a match")
S:RemoveRequirement("moving", "mounted")
IsMounted = function() return false end
St.ReadAll(); St.Refresh()
-- a reaction added by the player: Health percentage < 50, on top, red
local hr = S:Add("player_health")
hr.threshold, hr.color, hr.mic = 50, "red", "pulse"
UnitHealth, UnitHealthMax = function() return 40 end, function() return 100 end
St.ReadAll(); St.Refresh()
bar, mic = Now()
ok(bar == hr.id and mic == hr.id and LT.Def(hr.id).label == "Health percentage < 50%", "Health percentage < 50: on top")
ok(LT.IsDefault(hr.id), "a reaction of yours: nothing to restore")
S:Remove(hr.id)
-- a state turned off passes everything
S:SetOn("moving", false)
bar = Now()
ok(bar == "otherwise", "off: Otherwise shows")
-- nothing true
UnitAffectingCombat = function() return false end
St.ReadAll(); St.Refresh()
bar, mic = Now()
ok(bar == "otherwise" and mic == "otherwise", "nothing true: Otherwise")
ok(K.state.mic == K.MIC.off, "mic off out of combat")
-- a moment plays over the stack and hands back (the hold untouched)
S:SetOn("moving", true)
LT.Settings("moving").mic = "pass"
St.ReadAll(); St.Refresh()
LT.Fire("crit")
for _ = 1, 2 do K.Step(1 / 60) end
ok(drawn.cue == LT.LightByKey("crit").id and drawn.hold == LT.LightByKey("steady").id, "a crit over Movement")
for _ = 1, 10 do K.Step(1 / 30) end
ok(drawn.cue == 0 and drawn.hold == LT.LightByKey("steady").id, "back to Movement")
-- Default: the reactions as they ship
S:Default()
ok(S:IsDefault() and not LT.Settings("moving").on, "Default")
GetUnitSpeed = function() return 0 end
St.ReadAll(); St.Refresh()
-- Hush: feels at 30 %, lights at rest, no sounds, no moment lights
local Hu = ns.Hush
S:SetOn("moving", true)
GetUnitSpeed = function() return 7 end
St.ReadAll(); St.Refresh()
ok(Now() == "moving" and ns.FeelScale() == 1, "Movement, full feels")
Hu.Set(true)
K.Step(1 / 60)
ok(ns.FeelScale() == 0.3, "hushed: feels at 30 %")
ok(S:Now().hushed and drawn.resting and drawn.hold == LT.LightByKey("breathe").id, "hushed: the light at rest")
LT.Fire("crit")
for _ = 1, 3 do K.Step(1 / 60) end
ok(drawn.cue == 0, "hushed: no moment light")
ok(K.PlaySound("coin", 5) == false, "hushed: no sound")
-- L2-5: a Try is a preview: it goes out hushed (a moment light, a sound)
local q0 = #K.queue
LT.Try("crit")
ok(#K.queue == q0 + 1 and K.queue[#K.queue].light ~= nil, "L2-5: hushed, a light's Try is sent")
ok(K.Preview(K.PlaySound, "coin", 5) == true and K.queue[#K.queue].sound == K.SOUNDS.coin, "L2-5: hushed, a sound's Try is sent")
ok(K.PlaySound("coin", 5) == false, "and after it, hushed again")
for _ = 1, 30 do K.Step(1 / 30) end
Hu.Set(false)
K.Step(1 / 60)
ok(ns.FeelScale() == 1 and drawn.hold == LT.LightByKey("steady").id, "unhushed: Movement again")
ok(K.PlaySound("coin", 5) == true, "unhushed: the sound goes (L2-11: the check above means something)")
for _ = 1, 30 do K.Step(1 / 30) end
-- L2-4: Hush without the chip: a key binding, /gpc hush
ok(BINDING_NAME_GAMEPADCOMPANION_HUSH == "Hush" and type(GamepadCompanion_Hush) == "function", "L2-4: a binding")
local xml = io.open(root .. "/Bindings.xml"):read("*a")
ok(xml:find('name="GAMEPADCOMPANION_HUSH"', 1, true) and xml:find("GamepadCompanion_Hush()", 1, true), "in Bindings.xml")
GamepadCompanion_Hush()
ok(Hu.On(), "the key: Hush")
GamepadCompanion_Hush()
ok(not Hu.On(), "again: off")
ok(Hu.Command("on") == "on" and Hu.On(), "/gpc hush on")
ok(Hu.Command("resting") == "on · when resting" and Hu.Auto(), "/gpc hush resting")
ok(Hu.Command("off") == "off" and not Hu.On() and not Hu.Auto(), "/gpc hush off: both")
-- when resting too
IsResting = function() return true end
Hu.SetAuto(true)
ok(Hu.On() and ns.FeelScale() == 0.3, "Hush when resting")
Hu.SetAuto(false)
ok(not Hu.On(), "off")
IsResting = nil
S:SetOn("moving", false)
GetUnitSpeed = function() return 0 end
St.ReadAll(); St.Refresh()

-- The night review's P1s, each the way it happened -------------------------------------------
-- L1: an old profile loaded for real: the reactions are read first (Kind:Rows), before Draw
db.lightStack = {}
db.lightBase.stackV, db.lightBase.mic = nil, "combat"
db.lightEvents.cast = { on = true, light = LT.LightByKey("cast").id, color = "school", strength = 6, dots = "off", mic = "off" }
db.lightEvents.combat = nil
local rows1 = S:Rows()
local castRow, combatRow
for _, r in ipairs(rows1) do if r.id == "cast" then castRow = r end; if r.id == "combat" then combatRow = r end end
ok(castRow.mic == "pass" and castRow.dots == "pass", "L1: Casting's old off mic / dots read as Pass, not Off")
ok(combatRow.on and combatRow.mic == "on", "L1: In combat lights the mic")
UnitAffectingCombat = function() return true end
St.Set("cast", true); St.ReadAll(); St.Refresh()
local _, micNow = Now()
ok(micNow == "combat", "L1: casting in combat: the mic stays In combat's")
St.Set("cast", false)
-- L1 repair: a profile already made in the wrong order
db.lightStack.repairL1 = nil
S:Row("cast").mic = "off"
db.lightEvents.cast.mic = "pass"
LT.Migrate()
ok(S:Row("cast").mic == "pass", "L1: repaired")
-- L3: lights off in combat: the mic goes off; with the game's lights the mic is still sent
St.ReadAll(); St.Refresh()
ok(K.state.mic == K.MIC.on, "in combat: mic on")
LT.SetOn(false)
ok(K.state.mic == K.MIC.off, "L3: lights off: the mic off")
LT.SetOn(true)
db.lightGameOnly = true
K.SetMic("off")
ok(K.state.mic == K.MIC.off, "(from the mic off)")
LT.SendHold()
ok(not LT.HelperDrives() and K.state.mic == K.MIC.on, "L3: the game's lights: the mic still sent")
db.lightGameOnly = nil
LT.SendHold()
UnitAffectingCombat = function() return false end
St.ReadAll(); St.Refresh()
-- L14: the mic's moments from the reactions as they are
S:Remove("combat")
ok(not table.concat(LT.MicMoments(), ","):find("In combat"), "L14: a removed In combat is not listed")
S:Default()
-- L16: a hold refreshing while a cue is on screen keeps the cue
LT.Fire("crit")
K.Step(1 / 60)
LT.SendHold()
K.SetLight({ version = 1, hold = 2, holdTint = 1, holdStrength = 3, progress = 0 })
K.Step(1 / 60)
ok(drawn.cue == LT.LightByKey("crit").id, "L16: the cue survives a hold change")
for _ = 1, 10 do K.Step(1 / 30) end
LT.SendHold()
-- L8: a fresh profile is all Recommended (Default greyed)
local saved = GamepadCompanionHapticsDB
GamepadCompanionHapticsDB = { engine = true, light = true }
ok(S:IsDefault() and LT.IsDefault("combat") and LT.IsDefault("cast") and LT.Base().mic == "off", "L8: a fresh profile: Default greyed")
GamepadCompanionHapticsDB = saved
db = saved
St.Refresh(true)

-- link off again: the row goes, the game draws
K.SetEnabled(false)
K.Step(1 / 60)
ok(K.light == nil and drawn == nil, "no row with the link off")
ok(voices.lt_base and select(1, Led()), "the game's resting light again")

print("Lights: ok (" .. checks .. " checks, " .. n .. " row vectors, " .. samples .. " samples)")
