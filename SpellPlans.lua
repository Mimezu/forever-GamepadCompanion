-- Spell plans for WoW Helper: what each spell in your book plays, so the helper's Your spells can
-- play it as the game does, even a spell never cast (WoW Helper's src/spellplan.rs).
--
-- One source: V.SpellRule, the rule the play path acts on (Rumble.lua). Nothing here decides
-- what a spell plays; it only writes the rule down. A class's own spells (V.MAGE, V.CLASS_SPELLS)
-- come through the rule as they do in play.
--
-- In the export (GamepadCompanionHapticsDB.export.spellPlans), by spell ID (every rank):
--   m     the moment it plays on: "spell" (a cast or a channel), "instant", "quiet", or a linked
--         one (shot, autoAttack, gather, craft, eat, drink: that moment's own feel)
--   w     when: "cast", "hit", "channel", "none"
--   f     an instant's HD feel (at the cast, or as it lands)
--   d     as it lands: seconds after the cast (the hit timing as play has it)
--   imp   a cast's impact feel (as its wound lands, after the flight)
--   burst a cast's feel at its release (a ground spell, Polymorph)
--   tick, last, n, alt   a channel's tick feel, the last tick's, how many, by turns from either hand
--   tail  a shot's tail feel (Multi-Shot's other arrows, a sting)
--   vol   its volume (1: as designed); off: your choice, nothing plays
-- Plans of other characters stay (one account, several classes): a spell's plan is replaced when
-- its character exports again.
local _, ns = ...
local P = {}
ns.SpellPlans = P

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

-- The rule written down (nil: no rule, a spell the addon doesn't play)
function P.Plan(id)
    local V, L = ns.Rumble, ns.HapticsLab
    if not (V and V.SpellRule and L and L.FeelFor) then return nil end
    local ok, r = pcall(V.SpellRule, id)
    if not ok or type(r) ~= "table" then return nil end
    local p = { m = r.moment, w = r.when, f = r.feel or nil }
    if r.off then p.off = true end
    if r.volume and r.volume ~= 1 then p.vol = r.volume end
    if r.tail then p.tail = L.FeelFor(r.tail) end
    if r.when == "hit" and V.HitDelay then
        local kind = r.how and r.how.ranged and "ranged" or V.WeaponKind and V.WeaponKind(16) or "oneHand"
        local okd, d = pcall(V.HitDelay, kind)
        if okd and type(d) == "number" then p.d = math.floor(d * 1000 + 0.5) / 1000 end
    end
    -- a cast's own, as play does them (CastReleased): your own set chosen, none
    local m = r.mage
    if r.moment == "spell" and not (r.own and r.set) then
        if m and m.burst then
            p.burst = L.FeelFor(m.burst)
        elseif m and m.tick then
            p.tick, p.last = L.FeelFor(m.tick), L.FeelFor(m.last or m.tick)
            p.n = m.rankTicks and m.rankTicks[id] or m.ticks or 1
            p.alt = m.alternate and true or nil
        elseif r.when == "cast" then
            local f = V.CAST_IMPACT and V.CAST_IMPACT[r.set or ""]
            local move = f and (m and m.impact or f[1])
            if move then p.imp = L.FeelFor(move) end
        end
    end
    return p
end

-- Every spell in the book, added to the plans kept
function P.Export(plans)
    plans = type(plans) == "table" and plans or {}
    local R = ns.SpellRanks
    if not (R and R.EachBookSpell) then return plans end
    R.EachBookSpell(function(id)
        if type(id) == "number" and not secret(id) then
            local p = P.Plan(id)
            if p then plans[id] = p end
        end
    end)
    return plans
end

-- Wrap the export (HapticsLab's L.Export, as HelperCues does for the moments): the plans kept
-- from before, this character's book over them
local function Wrap()
    local L = ns.HapticsLab
    if not (L and L.Export) or L.plansWrapped then return end
    L.plansWrapped = true
    local export = L.Export
    L.Export = function(...)
        local db = type(GamepadCompanionHapticsDB) == "table" and GamepadCompanionHapticsDB or nil
        local kept = db and type(db.export) == "table" and db.export.spellPlans or nil
        local e = export(...)
        if type(e) == "table" then e.spellPlans = P.Export(kept) end
        return e
    end
end
Wrap()
P.Wrap = Wrap
