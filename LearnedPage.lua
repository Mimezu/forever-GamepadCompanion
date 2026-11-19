-- Learned (Moments, under Attacks and Abilities): what WoW Helper learned,
-- per weapon and hand, per ore and herb, read only (WoW Helper owns it: Reset
-- there), each with Try. The play stays per weapon kind and per action; the
-- per-node rows show what each node taught (fable critique R9).
local _, ns = ...
local S, V, HUI, T = ns.OptionsSkin, ns.Rumble, ns.HapticsUI, ns.Timing
local page = ns.RumblePage
if not (page and page.AddPanel and S and V and HUI and T) then return end

local P = {}
ns.LearnedPage = P
local ROWS = 9
P.ROWS = ROWS
local HAND = { main = "main hand", off = "off hand", ranged = "ranged" }
-- (a gathering action's feel, and a weapon kind's own swing, for Try)
local GATHER = { mining = "pickaxe", herbalism = "pluck", skinning = "skin" }
local SWING = { dagger = "swDagger", oneHand = "swSword", twoHand = "swSword2", polearm = "swPolearm", staff = "swStaff",
    fist = "swFist", unarmed = "swFist", form = "swFist", ranged = "string" }

local function Status(ready, n, what)
    if ready then return "Learned |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t" .. (n and n > 0 and (" · " .. n .. " " .. what) or "") end
    return "Learning…" .. (n and n > 0 and (" · " .. n .. " " .. what) or "")
end

-- The weapons shown: what's in hand (as it plays now), then whatever else was learned
function P.Weapons()
    local list, seen = {}, {}
    local function add(kind, hand)
        local key = kind .. "|" .. hand
        if seen[key] or not kind then return end
        seen[key] = true
        local delay, _, source, hits = V.HitDelay(kind, hand)
        list[#list + 1] = { kind = kind, hand = hand, delay = delay, ready = source == "learned", hits = hits }
    end
    add(V.WeaponKind(16), "main")
    if GetInventoryItemID and GetInventoryItemID("player", 17) then add(V.WeaponKind(17), "off") end
    for _, l in ipairs(T.LearnedHits()) do add(l.kind, l.hand) end
    return list
end

-- The nodes shown: each action's play (learned or the default), then each node that taught it
function P.Nodes()
    local list = {}
    for _, action in ipairs({ "mining", "herbalism", "skinning" }) do
        local period, first, _, source, strikes = V.StrikeTiming(action)
        if action == "mining" or source == "learned" then
            list[#list + 1] = { action = action, name = action:sub(1, 1):upper() .. action:sub(2), first = first, period = period,
                ready = source == "learned", count = strikes, what = "strikes" }
        end
    end
    for _, n in ipairs(T.LearnedNodes()) do
        list[#list + 1] = { action = n.action, name = n.name, first = n.first, period = n.period, ready = n.ready,
            count = n.casts, what = "casts", node = true }
    end
    return list
end

local function After(t, fn)
    if t and t > 0.01 and C_Timer and C_Timer.After then C_Timer.After(t, fn) else fn() end
end

-- Try a node or an action: its own feel at its strikes as learned (the first
-- at its time, the next a period on) -> the feel played
function P.TryStrikes(action, first, period)
    local pattern = GATHER[action] or "pickaxe"
    After(first, function()
        V.Play(pattern)
        if period and period > 0.2 then After(period, function() V.Play(pattern) end) end
    end)
    return pattern
end

-- Try a weapon: its swing as it lands (its learned delay on) -> the feel played
function P.TryWeapon(kind, delay)
    local pattern = SWING[kind] or "swSword"
    After(delay, function() V.Play(pattern) end)
    return pattern
end

-- The rows shown from `offset` (clamped) of `n`: the offset, and "1–9 of 24" (none when all fit)
function P.Window(n, offset)
    offset = math.max(0, math.min(offset or 0, n - ROWS))
    return offset, n > ROWS and ((offset + 1) .. "–" .. math.min(n, offset + ROWS) .. " of " .. n) or ""
end

-- A node's or an action's timing in a few words: its first strike, then the crack (mining:
-- the second hit is the ore cracking loose at the cast's end, not a repeat) or its rhythm
P.PLATE_W = 200
function P.When(n)
    local when = n.first and string.format("%.2f s", n.first) or "?"
    if V.STRIKES and V.STRIKES[n.action] then return when .. " · then crack" end
    if n.period and n.period > 0 then when = when .. string.format(" · every %.2f s", n.period) end
    return when
end

-- A card of ROWS read-only rows, filled from list() on each refresh; the wheel scrolls the rest
-- ("1–9 of 24" and a thumb when more than fit)
local function Card(panel, cw, pg, title, list, fill)
    local card = S.Card(panel, title, 0, 0, cw, 44 + ROWS * HUI.ROW_H)
    local rows, offset = {}, 0
    local range = S.Text(card, "", 0, 0, 90, 11, S.DIM)
    range:ClearAllPoints()
    range:SetPoint("TOPRIGHT", -14, -14)
    range:SetJustifyH("RIGHT")
    local thumb = card:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 0.78, 0.25, 0.6)
    card.range, card.rows = range, rows
    for i = 1, ROWS do
        local row
        row = HUI.MomentRow(card, -38 - (i - 1) * HUI.ROW_H, cw, nil, "", function() end,
            function() if row.item then row.try_(row.item) end end)
        row.pick:SetEnabled(false)
        -- (a read-only plate, no icon: wider, its text from the left, so a timing fits)
        row.pick:ClearAllPoints()
        row.pick:SetPoint("TOPRIGHT", row.try, "TOPLEFT", -4, 0)
        row.pick:SetWidth(P.PLATE_W)
        row.pick.label:ClearAllPoints()
        row.pick.label:SetPoint("LEFT", 10, 0)
        row.pick.label:SetPoint("RIGHT", -6, 0)
        row:Hide()
        rows[i] = row
    end
    local empty = S.Text(card, "Nothing learned yet", 14, -44, cw - 28, 12, S.DIM)
    function card.Fill()
        local items = list()
        local text
        offset, text = P.Window(#items, offset)
        range:SetText(text)
        empty:SetShown(#items == 0)
        thumb:SetShown(#items > ROWS)
        if #items > ROWS then
            local h = ROWS * HUI.ROW_H
            local th = math.max(18, h * ROWS / #items)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPRIGHT", -4, -38 - (h - th) * offset / (#items - ROWS))
            thumb:SetSize(3, th)
        end
        for i, row in ipairs(rows) do
            local item = items[offset + i]
            row.item = item
            row:SetShown(item ~= nil)
            if item then fill(row, item) end
        end
    end
    function card.Scroll(delta)
        offset = offset - delta
        card.Fill()
    end
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function(_, d) card.Scroll(d) end)
    pg.refresh[#pg.refresh + 1] = card.Fill
    return card
end

page.AddPanel({ after = "Attacks", key = "learnedWeapons", label = "Learned · weapons", build = function(panel, cw, pg)
    P.weapons = Card(panel, cw, pg, "Learned · weapons", P.Weapons, function(row, w)
        local p = V.Pattern(SWING[w.kind] or "swSword")
        row.icon:SetTexture(p and p.icon)
        row.label:SetText(T.Label(w.kind) .. " · " .. (HAND[w.hand] or w.hand))
        row:SetChoice(string.format("%.2f s", w.delay or 0), nil, Status(w.ready, w.hits, "hits"), false, nil, true)
        row.try_ = function(it) P.TryWeapon(it.kind, it.delay) end
    end)
end })

page.AddPanel({ after = "Abilities", key = "learnedNodes", label = "Learned · gathering", build = function(panel, cw, pg)
    P.nodes = Card(panel, cw, pg, "Learned · gathering", P.Nodes, function(row, n)
        local p = V.Pattern(GATHER[n.action] or "pickaxe")
        row.icon:SetTexture(p and p.icon)
        row.label:SetText(n.node and ("  " .. n.name) or n.name)
        row:SetChoice(P.When(n), nil, Status(n.ready, n.count, n.what), false, nil, true)
        row.try_ = function(it) P.TryStrikes(it.action, it.first, it.period) end
    end)
end })
