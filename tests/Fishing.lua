-- Fishing: the pole swap (MimezuFishing.lua, shared with Halo), R2 as the line while a pole is
-- in hand (Fishing.lua), the nibbles' stand-in timing and the moments' numbers.
-- lua5.1 tests/Fishing.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs ---------------------------------------------------------------------
local items, bags, hands, combat, level = {}, {}, {}, false, 40
local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADRTRIGGER", GamePadEmulateAlt = "NONE",
    SoftTargetInteractRange = "10" }
local overrides, notes, frames, timers = {}, {}, {}, {}
local now = 100
local function Item(id, name, classID, subclass, ilvl, quality, reqLevel)
    items[id] = { name = name, classID = classID, subclass = subclass, ilvl = ilvl or 1, quality = quality or 1,
        reqLevel = reqLevel or 1 }
end
Item(6256, "Fishing Pole", 2, 20, 5, 1, 1)
Item(6365, "Strong Fishing Pole", 2, 20, 15, 1, 10)
Item(6367, "Big Iron Fishing Pole", 2, 20, 30, 2, 20)
Item(19970, "Arcanite Fishing Pole", 2, 20, 50, 3, 60)    -- above level 40: not yet
Item(2489, "Two-Handed Sword", 2, 8)
Item(1201, "Dull Heater Shield", 4, 6)
Item(2488, "Gladius", 2, 7)

C_Item = {
    GetItemInfoInstant = function(id) local i = items[id]; if i then return id, nil, nil, nil, nil, i.classID, i.subclass end end,
    GetItemInfo = function(id) local i = items[id]; if i then return i.name, nil, i.quality, i.ilvl, i.reqLevel end end,
    GetItemNameByID = function(id) return items[id] and items[id].name end,
    GetItemIconByID = function(id) return "icon" .. id end,
    IsUsableItem = function(id) return items[id] ~= nil end,
    GetItemSubClassInfo = function(c, s) if c == 2 and s == 20 then return "Fishing Poles" end end,
}
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #bags or 0 end,
    GetContainerItemInfo = function(_, slot) return bags[slot] and { itemID = bags[slot] } or nil end,
}
C_Spell = { GetSpellName = function(id) return id == 7620 and "Fishing" or nil end }
NUM_BAG_SLOTS = 4
function GetInventoryItemID(_, slot) return hands[slot] end
function UnitLevel() return level end
function InCombatLockdown() return combat end
function GetTime() return now end
function GetCVar(k) return cvars[k] end
function SetCVar(k, v) cvars[k] = tostring(v) end
function ClearOverrideBindings(owner) overrides[owner] = {} end
function SetOverrideBinding(owner, _, key, action) overrides[owner] = overrides[owner] or {}; overrides[owner][key] = action end
function SetOverrideBindingClick(owner, _, key, button, mouse)
    overrides[owner] = overrides[owner] or {}
    overrides[owner][key] = "CLICK " .. button .. ":" .. mouse
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
UIErrorsFrame = { AddMessage = function(_, text) notes[#notes + 1] = text end }
C_Timer = { After = function(t, f) timers[#timers + 1] = { at = now + t, fn = f } end }
local function Advance(s)
    now = now + s
    for i = #timers, 1, -1 do
        local t = timers[i]
        if t.at <= now then table.remove(timers, i); t.fn() end
    end
end
function CreateFrame(_, name)
    local f = { name = name, attrs = {}, events = {} }
    function f:SetSize() end
    function f:SetPoint() end
    function f:RegisterForClicks() end
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:GetName() return self.name end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e) self.events[e] = true end
    function f:SetScript(what, fn) if what == "OnUpdate" then self.onUpdate = fn else self.handler = fn end end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = {}
-- the pad: R2 held or not (GetDeviceMappedState, ButtonBindingToIndex 0-based)
local r2Down = false
C_GamePad = {
    GetActiveDeviceID = function() return 1 end,
    GetDeviceMappedState = function() return { buttons = { false, false, false, false, false, false, false, r2Down } } end,
    ButtonBindingToIndex = function(key) return key == "PADRTRIGGER" and 7 or nil end,
}
-- run the frames' OnUpdate once (the release watcher)
local function Tick() for _, f in ipairs(frames) do if f.shown and f.onUpdate then f.onUpdate(f, 0.02) end end end
local fishLoot = false
function IsFishingLoot() return fishLoot end
function UnitChannelInfo() return "Fishing", nil, nil, now * 1000, (now + 20) * 1000 end

-- The shared swap ------------------------------------------------------------------
assert(loadfile(root .. "/MimezuFishing.lua"))()
local lib = MimezuFishing
check(type(lib) == "table" and lib.version == 1, "the library loads as MimezuFishing")
-- (a second copy, the same version: the first stays)
local first = lib
assert(loadfile(root .. "/MimezuFishing.lua"))()
check(MimezuFishing == first, "a second copy of the same version keeps the first")
-- (Halo ships the same file)
local halo = io.open(root .. "/../Halo/MimezuFishing.lua", "rb")
if halo then
    local a = halo:read("*a"); halo:close()
    local mine = io.open(root .. "/MimezuFishing.lua", "rb"); local b = mine:read("*a"); mine:close()
    check(a:gsub("\r\n", "\n") == b:gsub("\r\n", "\n"), "Halo's MimezuFishing.lua is the same file")
end

-- the best pole: usable at your level, then the highest item level
bags = { 6256, 2488, 6367, 19970, 6365 }
eq(lib.BestPole(), 6367, "the best pole you can use (Big Iron; Arcanite is above your level)")
level = 60
eq(lib.BestPole(), 19970, "at 60: Arcanite")
level = 40
eq(lib.Best({}), nil, "no pole: nil")

-- the macro: the pole on, the weapons back, by condition
eq(lib.MacroText("Big Iron Fishing Pole", { [16] = "Gladius", [17] = "Dull Heater Shield" }, "Fishing Poles"),
    "/equip [noequipped:Fishing Poles] Big Iron Fishing Pole\n"
    .. "/equipslot [equipped:Fishing Poles] 16 Gladius\n"
    .. "/equipslot [equipped:Fishing Poles] 17 Dull Heater Shield", "the swap's macro")
eq(lib.MacroText(nil, nil, "Fishing Poles"), nil, "nothing to swap: no macro")
local long = string.rep("x", 90)
local text = lib.MacroText(long, { [16] = long }, "Fishing Poles", "/run MimezuFishing.Note()")
check(not text:find("Note"), "the note line only when it fits a bar slot's macro")
check(lib.MacroText("P", { [16] = "S" }, nil, "/run MimezuFishing.Note()"):find("Note") ~= nil, "the note line when it fits")

-- remembering the hands: a sword and board, then a two-hander
local char = {}
lib.Attach(char)
hands = { [16] = 2488, [17] = 1201 }
check(lib.Remember(), "the hands remembered")
eq(char.fishingWeapons[16], 2488, "kept in the host's settings: main hand")
eq(char.fishingWeapons[17], 1201, "off hand")
local m = lib.Macro()
check(m:find("/equip %[noequipped:Fishing Poles%] Big Iron Fishing Pole") ~= nil, "Macro: the best pole on")
check(m:find("16 Gladius", 1, true) and m:find("17 Dull Heater Shield", 1, true), "Macro: the weapons back")
-- the pole in hand: nothing new remembered
hands = { [16] = 6367 }
check(not lib.Remember(), "a pole in hand is not remembered")
eq(lib.Weapons()[16], 2488, "the weapons before it stay")
eq(select(1, lib.Look()), "Back to weapons", "Look with the pole in hand")
eq(lib.Note(), nil, "a pole in hand and weapons to go back to: no note")
-- empty hands are not remembered either
hands = {}
check(not lib.Remember(), "empty hands: the last weapons stay")
-- no pole anywhere
bags = { 2488 }
eq(lib.Note(), "No fishing pole in your bags", "no pole: a calm note")
eq(notes[#notes], "No fishing pole in your bags", "the note shows")
eq(select(1, lib.Look()), "No fishing pole", "Look with no pole")
-- a pole in hand, nothing remembered (a fresh store, no memory)
lib.memory, char.fishingWeapons = nil, nil
hands = { [16] = 6256 }
eq(lib.Note(), "No weapons to go back to", "nothing to go back to: a calm note")

-- R2 as the line ---------------------------------------------------------------------
local ns = { Shared = { CharDB = function() return char end, Claim = function() end } }
local fired = {}
ns.HapticsLab = { Fire = function(key, gain) fired[#fired + 1] = { key = key, gain = gain, at = now } end }
assert(loadfile(root .. "/Fishing.lua"))("GamepadCompanion", ns)
local F = ns.Fishing
eq(F.Want(true, false, false), nil, "no pole: R2 is yours")
eq(F.Want(true, true, false), "cast", "a pole: R2 casts")
eq(F.Want(true, true, true), "catch", "the line out: R2 catches")
eq(F.Want(false, true, true), nil, "switched off: R2 is yours")

local events
for _, f in ipairs(frames) do if f.events.UNIT_SPELLCAST_CHANNEL_START then events = f end end
local binds = _G.GamepadCompanionFishingBinds
local function R2() return overrides[binds] and overrides[binds].PADRTRIGGER end

hands, bags = { [16] = 2488, [17] = 1201 }, { 6367 }
events.handler(events, "PLAYER_LOGIN")
eq(R2(), nil, "weapons in hand: no R2 binding")
hands = { [16] = 6367 }
events.handler(events, "PLAYER_EQUIPMENT_CHANGED")
eq(R2(), "CLICK GamepadCompanionFishing:LeftButton", "the pole on: R2 clicks the cast button")
eq(_G.GamepadCompanionFishing.attrs.macrotext, "/cast Fishing", "the cast button casts Fishing")
eq(cvars.GamePadEmulateCtrl, "PADRTRIGGER", "R2 stays the gamepad's Ctrl (its override fires anyway)")
eq(cvars.GamePadEmulateShift, "PADLTRIGGER", "L2 as it was")
eq(notes[#notes], "R2 casts", "a word as R2 changes")

-- a cast, R2 still held from its press: R2 turns into Catch only once it's released
r2Down = true
events.handler(events, "UNIT_SPELLCAST_CHANNEL_START", "player", nil, 7620)
eq(R2(), "CLICK GamepadCompanionFishing:LeftButton", "R2 held: its binding doesn't change mid-press")
eq(cvars.SoftTargetInteractRange, "30", "Interact's reach longer")
Tick()
eq(R2(), "CLICK GamepadCompanionFishing:LeftButton", "still held: still waiting")
r2Down = false
Tick()
eq(R2(), "INTERACTTARGET", "R2 released: the line out, R2 interacts")
Advance(F.LAND_AT)
eq(fired[1] and fired[1].key, "fishLand", "the bobber lands")
for _ = 1, 40 do Advance(0.5) end
local nibbles = 0
for _, f in ipairs(fired) do if f.key == "fishNibble" then nibbles = nibbles + 1 end end
check(nibbles <= F.NIBBLE_MAX, "a few nibbles at most (" .. nibbles .. ")")
-- the catch: R2's press interacts, the line comes in while it's held
fishLoot = true
r2Down = true
events.handler(events, "UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 7620)
events.handler(events, "LOOT_OPENED")
eq(fired[#fired].key, "fishCatch", "the catch")
eq(R2(), "INTERACTTARGET", "R2 held through the catch: no change mid-press (its release casts nothing)")
eq(cvars.SoftTargetInteractRange, "10", "Interact's reach back")
r2Down = false
Tick()
eq(R2(), "CLICK GamepadCompanionFishing:LeftButton", "R2 released: it casts again")
-- the same pole, the hands changing nothing: no rebinding at all
local before = overrides[binds]
r2Down = true
events.handler(events, "PLAYER_EQUIPMENT_CHANGED")
check(overrides[binds] == before, "nothing to change: the binding left alone, even held")
r2Down = false
-- a later loot is not a catch
local n = #fired
Advance(10)
events.handler(events, "LOOT_OPENED")
eq(#fired, n, "a loot long after the line came in: no catch")
-- the nibbles' times: after the bobber settles, apart, inside the wait, a few
local seq, k = { 0.5, 0.1, 0.9, 0.2, 0.2, 0.3, 0.4, 0.5 }, 0
local times = F.NibbleTimes(function() k = k + 1; return seq[(k - 1) % #seq + 1] end, 20)
check(#times >= 1 and #times <= F.NIBBLE_MAX, "nibbles: 1-" .. F.NIBBLE_MAX)
check(times[1] >= F.LAND_AT + F.NIBBLE_FROM + F.NIBBLE_GAP[1], "the first after the bobber settles")
for i = 2, #times do check(times[i] - times[i - 1] >= F.NIBBLE_GAP[1], "nibbles apart") end
check(#F.NibbleTimes(function() return 0 end, 4) == 0, "a short wait: no nibbles")

-- the pole off in combat: nothing until combat ends
combat = true
hands = { [16] = 2488, [17] = 1201 }
events.handler(events, "PLAYER_EQUIPMENT_CHANGED")
eq(R2(), "CLICK GamepadCompanionFishing:LeftButton", "in combat: the binding stays")
combat = false
events.handler(events, "PLAYER_REGEN_ENABLED")
eq(R2(), nil, "after combat: R2 is yours")
eq(notes[#notes], "R2 is back", "a word as R2 comes back")
eq(cvars.GamePadEmulateCtrl, "PADRTRIGGER", "R2's modifier never touched")

-- Reloads: Fishing.lua loads again (new frames), the saved settings and the game's CVars stay
local function Reload(charDB)
    for _, f in ipairs(frames) do f.handler, f.onUpdate = nil, nil end
    frames, overrides = {}, {}
    local ns2 = { Shared = { CharDB = function() return charDB end, Claim = function() end },
        HapticsLab = { Fire = function() end } }
    assert(loadfile(root .. "/Fishing.lua"))("GamepadCompanion", ns2)
    for _, f in ipairs(frames) do if f.events.UNIT_SPELLCAST_CHANNEL_START then events = f end end
    binds = _G.GamepadCompanionFishingBinds
    return ns2.Fishing
end
local function Fresh()
    cvars.GamePadEmulateCtrl, cvars.SoftTargetInteractRange = "PADRTRIGGER", "10"
    GamepadCompanionDB = {}
    GamepadCompanionHapticsDB = {}
end

-- 1. fishing through a reload (or a crash) never touches R2's modifier; the reach comes back
Fresh()
hands, bags = { [16] = 6367 }, {}
Reload(char)
events.handler(events, "PLAYER_LOGIN")
events.handler(events, "UNIT_SPELLCAST_CHANNEL_START", "player", nil, 7620)
eq(cvars.GamePadEmulateCtrl, "PADRTRIGGER", "fishing: R2 still the gamepad's Ctrl")
eq(cvars.SoftTargetInteractRange, "30", "the line out: the reach longer")
hands = { [16] = 2488, [17] = 1201 }
Reload(char)                                   -- (no logout ran: a crash)
events.handler(events, "PLAYER_LOGIN")
eq(cvars.SoftTargetInteractRange, "10", "after a crash with the line out: the reach as it was")
eq(cvars.GamePadEmulateCtrl, "PADRTRIGGER", "and R2's modifier as it was")
eq(R2(), nil, "and R2 has no binding of ours")
eq(next(GamepadCompanionHapticsDB.fishingCVars), nil, "the record emptied")

-- 2. logout with the line out: the reach back at once
Fresh()
hands = { [16] = 6367 }
Reload(char)
events.handler(events, "PLAYER_LOGIN")
events.handler(events, "UNIT_SPELLCAST_CHANNEL_START", "player", nil, 7620)
events.handler(events, "PLAYER_LOGOUT")
eq(cvars.SoftTargetInteractRange, "10", "logout with the line out: the reach as it was")

-- 2b. Core rebuilds GamepadCompanionDB mid-session (Save) with the line out: the record survives
Fresh()
hands = { [16] = 6367 }
Reload(char)
events.handler(events, "PLAYER_LOGIN")
events.handler(events, "UNIT_SPELLCAST_CHANNEL_START", "player", nil, 7620)
eq(cvars.SoftTargetInteractRange, "30", "the line out: the reach longer")
GamepadCompanionDB = {}                        -- (what Core's Save does)
events.handler(events, "UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 7620)
eq(cvars.SoftTargetInteractRange, "10", "a Save with the line out: the reach back as the line comes in")

-- 3. a record left by 0.69.1 (account-wide) or 0.68.0 (per character): R2's modifier back once
Fresh()
cvars.GamePadEmulateCtrl = "NONE"
GamepadCompanionDB.fishingCVars = { GamePadEmulateCtrl = "PADRTRIGGER" }
hands = { [16] = 6367 }
Reload(char)
events.handler(events, "PLAYER_LOGIN")
eq(cvars.GamePadEmulateCtrl, "PADRTRIGGER", "0.69.1's record: R2 is Ctrl again at login, pole in hand or not")
eq(GamepadCompanionDB.fishingCVars, nil, "0.69.x's record moved away")
eq(GamepadCompanionHapticsDB.fishingCVars.GamePadEmulateCtrl, nil, "the record cleared")
cvars.GamePadEmulateCtrl = "NONE"               -- (you set it so later: not ours to undo)
Reload(char)
events.handler(events, "PLAYER_LOGIN")
eq(cvars.GamePadEmulateCtrl, "NONE", "healed once: a later NONE of yours stays")
Fresh()
cvars.GamePadEmulateCtrl = "NONE"
local old = { fishing = { r2 = true, mods = { GamePadEmulateCtrl = "PADRTRIGGER" } } }
hands = { [16] = 2488 }
Reload(old)
events.handler(events, "PLAYER_LOGIN")
eq(cvars.GamePadEmulateCtrl, "PADRTRIGGER", "0.68.0's record: R2 is Ctrl again at login")
eq(old.fishing.mods, nil, "the old per-character record gone")

-- 4. R2 fishing turned off with the pole in hand: R2 is yours at once
Fresh()
hands = { [16] = 6367 }
local Fx = Reload(char)
events.handler(events, "PLAYER_LOGIN")
eq(R2(), "CLICK GamepadCompanionFishing:LeftButton", "fishing")
char.fishing.r2 = false
Fx.Apply()
eq(R2(), nil, "R2 fishing off: no binding")
char.fishing.r2 = true
hands = {}

-- Quick use: quick:fish runs the swap's macro, shows the pole or the weapons
ns.Shared.lookup = {}
assert(loadfile(root .. "/TouchModel.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Quick.lua"))("GamepadCompanion", ns)
local T, Q = ns.TouchModel, ns.Quick
check(T.QUICK_BY_KEY.fish ~= nil, "Quick use offers the fishing pole")
hands, bags = { [16] = 2488, [17] = 1201 }, { 6367 }
eq(T.MacroText("quick:fish", ns.Shared.lookup), lib.Macro(), "quick:fish: the swap's macro")
eq(select(1, Q.Look("fish")), "Big Iron Fishing Pole", "it shows the pole to take")
combat = true
hands = { [16] = 6367 }
eq(Q.Macro("fish"), lib.MacroText("Big Iron Fishing Pole", { [16] = "Gladius", [17] = "Dull Heater Shield" }, "Fishing Poles",
    "/run MimezuFishing.Note()"), "in combat: the last macro (its conditions pick the way)")
combat = false

-- The moments: appended, never moved ------------------------------------------------
local src = io.open(root .. "/HelperCues.lua"):read("*a")
local list = {}
for key in src:match("C%.MOMENTS = (%b{})"):gmatch('{ "([%w:]+)", "%a+"') do list[#list + 1] = key end
eq(list[92], "fallDamage", "92 Fall damage")
eq(list[93], "fishLand", "93 Bobber lands")
eq(list[94], "fishBite", "94 Fish hooked")
eq(list[95], "fishCatch", "95 Catch")
eq(#list, 95, "95 the last moment: 96-127 are WoW Helper's markers (steps, emote voices, gathering, swings)")
local lab = io.open(root .. "/HapticsLab.lua"):read("*a")
for _, k in ipairs({ { "fishLand", "plop" }, { "fishNibble", "nibble" }, { "fishBite", "hooked" }, { "fishCatch", "reelIn" } }) do
    check(lab:find('key = "' .. k[1] .. '"[^\n]*feel = "' .. k[2] .. '"') ~= nil, k[1] .. " plays " .. k[2])
    check(lab:find('{ "' .. k[2] .. '", ') ~= nil, k[2] .. " is in the library")
end

io.write(string.format("%s: fishing: %d checks, %d failed\n", failures == 0 and "PASS" or "FAIL", checks, failures))
os.exit(failures == 0 and 0 or 1)
