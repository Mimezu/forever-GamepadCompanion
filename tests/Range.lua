-- Setup › Range: the yes/no staircase finds the faintest level felt, without timing.
-- lua5.1 tests/Range.lua <addon folder>
local root = arg[1] or "."
local ns = {}
local chunk = assert(loadfile(root .. "/Staircase.lua"))
chunk("GamepadCompanion", ns)
local St = assert(ns.Staircase, "Staircase loads")

-- A player who feels everything at or above `threshold` (and nothing below)
local function run(threshold, start)
    local s = St.New(start or 0.16)
    local taps = 0
    while not s.done do
        taps = taps + 1
        s:Answer(s:Level() >= threshold - 1e-9)
    end
    return s:Result(), taps
end

for t = 1, 40 do
    local threshold = t / 100
    local result, taps = run(threshold)
    assert(math.abs(result - threshold) < 1e-9, ("threshold %.2f: found %.2f"):format(threshold, result))
    assert(taps <= St.MAX_TRIALS, ("threshold %.2f: %d taps"):format(threshold, taps))
end

-- near the start it converges quickly (about 6-8 taps)
local _, taps = run(0.10)
assert(taps <= 8, "0.10 in " .. taps .. " taps")

-- feels everything: down to 0; feels nothing: the top
assert(run(0) == 0, "feels everything")
assert(run(0.9) == St.TOP, "feels nothing")

-- one wrong answer (a missed tap) still lands within a step or two
local s = St.New(0.16)
local missed = false
while not s.done do
    local felt = s:Level() >= 0.08
    if felt and s:Level() == 0.08 and not missed then felt, missed = false, true end
    s:Answer(felt)
end
assert(s:Result() >= 0.08 and s:Result() <= 0.10, "with a miss: " .. s:Result())

-- answers after the end change nothing
local d = St.New(0.1)
while not d.done do d:Answer(true) end
local r = d:Result()
d:Answer(false)
assert(d:Result() == r)

print("Range tests passed")
