-- The faintest a grip feels, found without timing: one tap at a level, the
-- player answers Felt or Not felt. A Yes steps down, a No steps up; each turn
-- of the answer halves the step (4%, 2%, 1%). Done after three turns or ten
-- taps; the result is the lowest level felt after the first turn (the floor
-- must be felt, so it never lands under a No). Levels are motor levels 0-0.5
-- in 1% steps (db.floor's scale).
local _, ns = ...
ns = ns or {}

local St = {}
St.__index = St
ns.Staircase = St

St.MAX_TRIALS = 10
St.TURNS = 3
St.TOP = 0.5

local function snap(v) return math.max(0, math.min(St.TOP, math.floor(v * 100 + 0.5) / 100)) end

-- start: a level that is clearly felt; step: the first step (0.04)
function St.New(start, step)
    return setmetatable({ level = snap(start or 0.16), step = step or 0.04, last = nil, turns = 0, trials = 0,
        done = false, felt = {} }, St)
end

-- The level to play now
function St:Level() return self.level end

-- The player's answer for the level just played
function St:Answer(felt)
    if self.done then return end
    self.trials = self.trials + 1
    felt = felt and true or false
    if self.last ~= nil and felt ~= self.last then
        self.turns = self.turns + 1
        self.step = math.max(0.01, self.step / 2)
    end
    if felt then self.felt[#self.felt + 1] = { level = self.level, turns = self.turns } end
    self.last = felt
    if self.turns >= St.TURNS or self.trials >= St.MAX_TRIALS then
        self.done = true
        return
    end
    self.level = snap(felt and self.level - self.step or self.level + self.step)
end

-- The lowest level felt after the first turn (else the lowest felt; nothing
-- felt: the top)
function St:Result()
    local best, any
    for _, f in ipairs(self.felt) do
        if f.turns >= 1 and (not best or f.level < best) then best = f.level end
        if not any or f.level < any then any = f.level end
    end
    return best or any or St.TOP
end

return St
