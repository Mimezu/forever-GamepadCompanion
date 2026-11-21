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
--   tick, last, n, alt   a channel's tick feel (HD), the last tick's, how many, by turns from
--         either hand; first: one more as the channel starts (Penance), its tick 0
--   aft, an, ae   after the cast, n more of feel aft every ae s (Consecration's ground)
--   sc    a finisher's strength at a middling 3 combo points (1: as designed)
--   rumble  what plays on the pad's rumble only, no HD (a burst at the release, a released
--         hook: a poison's coat, a lock giving), by pattern
--   tail  a shot's tail feel (Multi-Shot's other arrows, a sting)
--   vol   its volume (1: as designed); off: your choice, nothing of the addon's plays
-- export.spellBook: the IDs this character knows (its ranks)
-- Plans of other characters stay (one account, several classes): a spell's plan is replaced when
-- its character exports again.
local _, ns = ...
local P = {}
ns.SpellPlans = P

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

-- A finisher's strength at 3 combo points (its scale asked with 3 spent; restored after)
local function MidCombo(scale)
    local CP = ns.Combo
    if not (CP and CP.Spent) then return nil end
    local spent = CP.Spent
    CP.Spent = function() return 3 end
    local ok, v = pcall(scale)
    CP.Spent = spent
    return ok and type(v) == "number" and v or nil
end

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
    local m = r.mage
    local rumble = {}
    if m and type(m.scale) == "function" then p.sc = MidCombo(m.scale) end
    -- a channel's ticks (HD, Rumble's V.TickHD), whatever set plays under them
    if r.moment == "spell" and m and m.tick then
        p.tick, p.last = L.FeelFor(m.tick), L.FeelFor(m.last or m.tick)
        p.n = m.rankTicks and m.rankTicks[id] or m.ticks or 1
        p.alt = m.alternate and true or nil
        -- (Penance: one more as the channel starts, in HD too: Priest.lua's V.TickHD(tick, 0))
        if m.first then p.first = true end
    end
    -- a cast's end, as play does it (CastReleased): a class's hook, a burst (rumble), else its
    -- impact by the cast's action; none under your own set
    local own = V.ClassSpellOf and V.ClassSpellOf(id)
    if r.moment == "spell" and not (r.own and r.set) and not (m and m.tick) then
        if own and own.released then
            rumble[#rumble + 1] = "released"
        elseif m and m.burst then
            rumble[#rumble + 1] = m.burst
        elseif r.when == "cast" then
            local f = V.CAST_IMPACT and V.CAST_IMPACT[r.schoolSet or r.ruleSet or ""]
            local move = f and (m and m.impact or f[1])
            if move then p.imp = L.FeelFor(move) end
        end
    end
    if #rumble > 0 then p.rumble = rumble end
    -- Consecration's ground (Paladin.lua): its ticks after it is laid down
    local PD = ns.Paladin
    if PD and PD.CONSECRATION and PD.HALLOW_TICKS and r.name and r.name == SpellName(PD.CONSECRATION) then
        p.aft, p.an, p.ae = "r_hallow", PD.HALLOW_TICKS, PD.HALLOW_PERIOD
    end
    return p
end

-- Every spell in the book, added to the plans kept; and the book's IDs (the ranks this
-- character knows: WoW Helper picks their plans first)
function P.Export(plans)
    plans = type(plans) == "table" and plans or {}
    local ids = {}
    local R = ns.SpellRanks
    if not (R and R.EachBookSpell) then return plans, ids end
    R.EachBookSpell(function(id)
        if type(id) == "number" and not secret(id) then
            local p = P.Plan(id)
            if p then plans[id] = p end
            ids[#ids + 1] = id
        end
    end)
    return plans, ids
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
        if type(e) == "table" then
            -- (a failure here never costs the export, nor the plans kept)
            local okp, plans, ids = pcall(P.Export, kept)
            e.spellPlans = okp and plans or kept
            e.spellBook = okp and ids or nil
        end
        return e
    end
end
Wrap()
P.Wrap = Wrap
