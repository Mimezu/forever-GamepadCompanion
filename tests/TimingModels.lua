-- The per-model timing tables against the fixture shared with WoW Helper (tests/fixtures/timing-models.txt).
-- lua5.1 tests/TimingModels.lua <addon folder>
local root = arg[1] or "."
local want, n = {}, 0
for line in io.lines(root .. "/tests/fixtures/timing-models.txt") do
    local key, run, walk = line:match("^(%d+%-%d+) ([%d%.]+) ([%d%.]+)")
    if key then want[key] = { run = tonumber(run), walk = tonumber(walk) }; n = n + 1 end
end
assert(n == 16, "16 models in the fixture, " .. n)

local text = io.open(root .. "/HapticsLab.lua"):read("*a")
local block = text:match("L%.STEP_MODELS = (%b{})")
assert(block, "L.STEP_MODELS")
local got, m = {}, 0
for key, run, walk in block:gmatch('%["(%d+%-%d+)"%] = { run = ([%d%.]+), walk = ([%d%.]+) }') do
    got[key] = { run = tonumber(run), walk = tonumber(walk) }; m = m + 1
end
assert(m == n, ("HapticsLab has %d models, the fixture %d"):format(m, n))
for key, w in pairs(want) do
    local g = got[key]
    assert(g and g.run == w.run and g.walk == w.walk, "HapticsLab's " .. key .. " as the fixture")
end
-- sane: a step between 1 and 5 a second, running quicker than walking but for a gnome's quick walk
for key, w in pairs(want) do
    assert(w.run > 2 and w.run < 4 and w.walk > 1 and w.walk < 5, key .. " in range")
end
io.write("PASS: every model's own steps, as WoW Helper's table" .. string.char(10))
