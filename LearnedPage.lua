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
local HAND = { main = "main hand", off = "off hand", ranged = "ranged" }
-- (a weapon kind's own swing, for Try)
local SWING = { dagger = "swDagger", oneHand = "swSword", twoHand = "swSword2", polearm = "swPolearm", staff = "swStaff",
    fist = "swFist", unarmed = "swFist", form = "swFist", ranged = "string" }

local function Status(ready, n, what)
    if ready then return "Learned ✓" .. (n and n > 0 and (" · " .. n .. " " .. what) or "") end
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

-- Try a node: its strikes as learned (the first at once, the next a period on)
local function TryStrikes(period)
    V.Play("pickaxe")
    if C_Timer and C_Timer.After and period and period > 0.2 then C_Timer.After(period, function() V.Play("pickaxe") end) end
end

-- A card of up to ROWS read-only rows, filled from list() on each refresh
local function Card(panel, cw, pg, title, list, fill)
    local card = S.Card(panel, title, 0, 0, cw, 44 + ROWS * HUI.ROW_H)
    local rows = {}
    for i = 1, ROWS do
        local row
        row = HUI.MomentRow(card, -38 - (i - 1) * HUI.ROW_H, cw, nil, "", function() end,
            function() if row.item then row.try_(row.item) end end)
        row.pick:SetEnabled(false)
        row:Hide()
        rows[i] = row
    end
    local empty = S.Text(card, "Nothing learned yet", 14, -44, cw - 28, 12, S.DIM)
    pg.refresh[#pg.refresh + 1] = function()
        local items = list()
        empty:SetShown(#items == 0)
        for i, row in ipairs(rows) do
            local item = items[i]
            row.item = item
            row:SetShown(item ~= nil)
            if item then fill(row, item) end
        end
    end
    return card
end

page.AddPanel({ after = "Attacks", key = "learnedWeapons", label = "Learned · weapons", build = function(panel, cw, pg)
    P.weapons = Card(panel, cw, pg, "Learned · weapons", P.Weapons, function(row, w)
        local p = V.Pattern(SWING[w.kind] or "swSword")
        row.icon:SetTexture(p and p.icon)
        row.label:SetText(T.Label(w.kind) .. " · " .. (HAND[w.hand] or w.hand))
        row:SetChoice(string.format("%.2f s", w.delay or 0), nil, Status(w.ready, w.hits, "hits"), false, nil, true)
        row.try_ = function(it) V.Play(SWING[it.kind] or "swSword") end
    end)
end })

page.AddPanel({ after = "Abilities", key = "learnedNodes", label = "Learned · gathering", build = function(panel, cw, pg)
    P.nodes = Card(panel, cw, pg, "Learned · gathering", P.Nodes, function(row, n)
        local p = V.Pattern(n.action == "herbalism" and "pluck" or n.action == "skinning" and "skin" or "pickaxe")
        row.icon:SetTexture(p and p.icon)
        row.label:SetText(n.node and ("  " .. n.name) or n.name)
        local when = n.first and string.format("%.2f s", n.first) or "?"
        if n.period and n.period > 0 then when = when .. string.format(" · every %.2f s", n.period) end
        row:SetChoice(when, nil, Status(n.ready, n.count, n.what), false, nil, true)
        row.try_ = function(it) TryStrikes(it.period) end
    end)
end })
