-- Profiles: migration (Alberich exactly as before, whoever logs in first),
-- isolation (an edit on B never reaches A), across saves and loads that split
-- shared tables as SavedVariables do; no name: nothing touched; menu actions.
local root = arg and arg[1] or "."
local failures = 0
local function check(ok, message)
    if not ok then failures = failures + 1; io.write("FAIL: ", message, "\n") end
end

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end
local function Same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- The frames: one per CreateFrame, events by name
local frames
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, arg)
    for _, f in ipairs(frames) do if f.events[event] and f.handler then f.handler(f, event, arg) end end
end
local who
function UnitName() return who and who.name end
function GetRealmName() return who and who.realm end
function UnitClass() return who and who.class, who and who.class end
function InCombatLockdown() return false end

-- The account's files, and each character's
local disk = { account = {}, chars = {} }
local ns
local function Login(name, realm, class)
    who = name and { name = name, realm = realm, class = class } or nil
    frames = {}
    GamepadCompanionHapticsDB = Copy(disk.account.haptics)
    GamepadCompanionDB = Copy(disk.account.db)
    GamepadCompanionCharDB = Copy(disk.chars[(name or "?") .. "-" .. (realm or "?")])
    ns = {}
    assert(loadfile(root .. "/Profiles.lua"))("GamepadCompanion", ns)
    ns.Profiles.reload = function() end
    Fire("ADDON_LOADED", "GamepadCompanion")
    Fire("PLAYER_LOGIN")
    return ns.Profiles
end
local function Logout()
    Fire("PLAYER_LOGOUT")
    -- (SavedVariables: written apart, so shared tables come back as separate ones)
    disk.account.haptics = Copy(GamepadCompanionHapticsDB)
    disk.account.db = Copy(GamepadCompanionDB)
    disk.chars[(who and who.name or "?") .. "-" .. (who and who.realm or "?")] = Copy(GamepadCompanionCharDB)
end

-- Today: Alberich's account settings and his character file (a realistic shape)
disk.account.haptics = {
    events = { hit = { on = false, feel = "strike" }, oom = { on = false, feel = "alert", moved = 1 } },
    lightEvents = { crit = { on = true, light = "flash" } }, lightBase = { mode = "class", level = 0.35 },
    link = { on = true, cell = 2, cues = { clips = true, castTrigger = true }, sounds = { loot = 131 } },
    volume = { sounds = 1, feel = { mount = 1 }, sound = { loot = 0.5 } },
    landMin = 0.9, landMax = 2, landLong = 0.6, stepNudge = 0.01, triggers = "off", kick = 0, minPulse = 0.05, light = true,
    floor = { 0.05, 0.05 }, feels = { ownA = { label = "Mine" } }, timing = { log = {} },
}
disk.account.db = { bars = { main = { x = 10 } }, compact = true, optionsStyle = "forever", minimap = { angle = 200 } }
disk.chars["Alberich-Noir"] = { version = 1, keys = { a = "spell:1" }, gestures = { [2] = "text:/dance" },
    vibration = { enabled = true, intensity = 1, events = { crit = { on = true, pattern = "critHit" } },
        hitTiming = { sword = 0.3 }, strikes = { mining = { period = 1 } } } }
disk.chars["Celes-Aria"] = { version = 1, keys = { b = "spell:2" }, vibration = { intensity = 0.6, events = {} } }
local alberichBefore = Copy(disk.chars["Alberich-Noir"])
local accountBefore = Copy(disk.account.haptics)

-- 1. No name at login: nothing pointed, nothing cleared
local P = Login(nil, nil, nil)
check(not P.state.pointed and P.state.note, "no name: off, said once")
Logout()
check(Same(disk.account.haptics.events, accountBefore.events) and Same(disk.account.db.bars, { main = { x = 10 } }),
    "no name: the account untouched")

-- 2. Celes logs in first: her own copies; Alberich and the snapshot untouched
P = Login("Celes", "Aria", "PRIEST")
check(P.Current("feel") == "Celes" and P.Current("controls") == "Celes", "Celes: her own profiles")
check(GamepadCompanionCharDB.keys.b == "spell:2" and GamepadCompanionCharDB.vibration.intensity == 0.6, "her own character tables")
check(GamepadCompanionHapticsDB.events.hit.on == false, "the account's Feel as it was, copied")
GamepadCompanionHapticsDB.events.hit.on = true                -- Celes edits
GamepadCompanionHapticsDB.volume.sound.loot = 0.2
GamepadCompanionHapticsDB.landMin = 0.5
GamepadCompanionDB.bars.main.x = 99
GamepadCompanionCharDB.vibration.intensity = 0.3
Logout()
local saved = disk.account.haptics
check(saved.events == nil and saved.lightEvents == nil and saved.link.cues == nil and saved.landMin == nil,
    "logout: only the profiles keep the Feel")
check(saved.link.on == true and saved.link.cell == 2 and saved.volume.sounds == 1 and saved.floor[1] == 0.05,
    "logout: the account keys stay")
check(disk.account.db == nil and saved.ui.optionsStyle == "forever" and saved.ui.minimap.angle == 200,
    "bars into the profile; style and minimap account-wide")
check(disk.chars["Celes-Aria"].profiled == 1 and disk.chars["Celes-Aria"].keys == nil, "her character file: a stub")
check(saved.profiles.controls.Celes.char.vibration == nil, "Controls never holds vibration")

-- 3. Alberich: exactly today, after Celes's edits
P = Login("Alberich", "Noir", "PALADIN")
check(P.Current("feel") == "Alberich" and P.Current("controls") == "Alberich", "Alberich: his own")
local h = GamepadCompanionHapticsDB
check(h.events.hit.on == false and h.volume.sound.loot == 0.5 and h.landMin == 0.9, "Alberich's Feel exactly as before")
check(GamepadCompanionDB.bars.main.x == 10 and GamepadCompanionDB.compact == true and GamepadCompanionDB.optionsStyle == "forever",
    "his bars as before, style kept")
check(GamepadCompanionCharDB.keys.a == "spell:1" and GamepadCompanionCharDB.gestures[2] == "text:/dance", "his controls")
local vib = GamepadCompanionCharDB.vibration
check(vib.intensity == 1 and vib.events.crit.pattern == "critHit", "his vibration")
check(vib.hitTiming.sword == 0.3 and vib.strikes.mining.period == 1, "learned timings, account-wide, still there")
h.events.kill = { on = false }                                    -- Alberich edits
Logout()
local feelA = disk.account.haptics.profiles.feel.Alberich
check(feelA.vibration.hitTiming == nil and feelA.vibration.strikes == nil, "Feel never holds learned data")
check(disk.account.haptics.learned.hitTiming.sword == 0.3, "learned data account-wide")

-- 4. Isolation: Celes again: her edits, not Alberich's
P = Login("Celes", "Aria", "PRIEST")
h = GamepadCompanionHapticsDB
check(h.events.hit.on == true and h.volume.sound.loot == 0.2 and h.landMin == 0.5 and h.events.kill == nil, "Celes: hers only")
check(GamepadCompanionDB.bars.main.x == 99 and GamepadCompanionCharDB.vibration.intensity == 0.3, "her bars and strength")
h.events.loot = { on = false }
Logout()
P = Login("Alberich", "Noir", "PALADIN")
check(GamepadCompanionHapticsDB.events.loot == nil and GamepadCompanionHapticsDB.events.kill.on == false, "Alberich: untouched by Celes")
check(Same(disk.account.haptics.profiles.before.feel.events, accountBefore.events), "the snapshot frozen")
check(Same(disk.account.haptics.profiles.beforeChar["Alberich-Noir"].keys, alberichBefore.keys), "his character backup")
-- Alberich: start here for new paladins
P.StartHere("feel", true)
check(P.IsStart("feel"), "start here")
Logout()

-- 5. A new character: Recommended for its class; a paladin: Alberich's Feel, its own copy
P = Login("Dahlia", "Noir", "ROGUE")
h = GamepadCompanionHapticsDB
check(P.Current("feel") == "Dahlia" and P.state.note:find("Recommended", 1, true), "a new rogue: Recommended, said once")
check(h.events.hit.on == false and h.events.combo.on == true, "the calm set, combo points for a rogue")
-- (Alberich's choices, 2026-11-20: Money on with Gravel, Landing's Flick, swings and jumps, full strength)
check(h.events.money.on == true and h.events.money.feel == "gravel" and h.events.landing.feel == "flick"
    and h.events.landing.on == nil and h.events.combo.feel == nil, "Recommended feels; a feel alone leaves on to the code")
local vib = GamepadCompanionCharDB.vibration
check(vib.intensity == 1 and vib.events.autoAttack.on == true and vib.events.jump.on == true, "swings, jumps, full strength")
check(h.fresh == P.FRESH.version and P.Fresh(), "stamped FRESH: its sounds, levels and lights are its defaults")
check(type(GamepadCompanionCharDB) == "table" and GamepadCompanionCharDB.keys == nil, "fresh controls")
Logout()
P = Login("Brann", "Noir", "PALADIN")
check(P.state.note:find("from Alberich", 1, true) and GamepadCompanionHapticsDB.events.kill.on == false, "a new paladin: from Alberich")
GamepadCompanionHapticsDB.events.kill.on = true
Logout()
P = Login("Alberich", "Noir", "PALADIN")
check(GamepadCompanionHapticsDB.events.kill.on == false, "a copy, never shared")

-- 6. Menu: rename keeps every use; delete only when unused; share round-trips
check(P.Rename("feel", "Alberich", "Melee") and P.Current("feel") == "Melee", "rename: in use follows")
check(not P.Delete("feel", "Melee"), "never delete one in use")
local copy = P.New("feel", "Spare", "Melee")
check(P.Delete("feel", copy), "delete an unused one")
local text = P.Export("feel", "Melee")
check(text and text:find("^GPC1:feel:") and not text:find("hitTiming", 1, true), "share: no learned data")
local name, kind = P.Import(text, "From Alberich")
check(kind == "feel" and Same(P.DB().feel[name].events, P.DB().feel.Melee.events), "import: the same")
check(P.Import("GPC1:feel:{os.exit()}") == nil, "import: data only")
-- a typed macro's parentheses are data: it round-trips; a call outside a string stays refused
do
    local macro = "text:/cast Frostbolt(Rank 1)\n/run print(\"a\\\"b\")"
    local c = P.New("controls", "Macros")
    P.DB().controls[c].char = { version = 1, keys = { PAD1 = { base = macro } } }
    local ctext = P.Export("controls", c)
    local cname, ckind = P.Import(ctext, "Macros shared")
    check(ckind == "controls" and P.DB().controls[cname].char.keys.PAD1.base == macro, "import: a rank macro round-trips")
    check(P.Delete("controls", cname) and P.Delete("controls", c), "the macro copies deleted")
end
check(P.Import('GPC1:feel:{a=("x"):rep(9)}') == nil, "import: a method call still refused")
check(P.Import("GPC1:feel:{a='\"',b=(\"x\"):rep(9),c='\"'}") == nil, "import: a quote in another quote hides nothing")
check(P.Import('GPC1:feel:{a=1 --"\n,b=("x"):rep(9) --"\n}') == nil, "import: no comments")
check(P.Import('GPC1:feel:{a=[["]],b=("x"):rep(9),c=[["]]}') == nil, "import: no long strings")
Logout()

-- 6b. A logout that never ran (a crash after a save): duplicates only, never another's settings
P = Login("Celes", "Aria", "PRIEST")
GamepadCompanionHapticsDB.events.hit.on = "celes"
disk.account.haptics = Copy(GamepadCompanionHapticsDB)       -- saved without the logout's release
disk.account.db = Copy(GamepadCompanionDB)
P = Login("Alberich", "Noir", "PALADIN")
check(GamepadCompanionHapticsDB.events.hit.on == false, "Alberich after Celes's unreleased save: his own")
Logout()

-- 6c. A blank realm at load (seen in game 2026-11-20): the realm this name is known on, never
-- a new character; a blank-realm key an older version made is dropped (its profiles stay listed)
do
    local a = disk.account.haptics.profiles
    a.use["Alberich-"] = { feel = "Alberich 2", controls = "Alberich 2" }
    a.feel["Alberich 2"] = { events = { landing = { on = true, feel = "thud" } } }
    a.controls["Alberich 2"] = { char = { version = 1 }, bars = {} }
    disk.chars["Alberich-"] = Copy(disk.chars["Alberich-Noir"])
    P = Login("Alberich", "", "PALADIN")
    local mine = GamepadCompanionHapticsDB.profiles.use["Alberich-Noir"]
    check(P.Current("feel") == mine.feel and P.Current("controls") == mine.controls, "blank realm: Alberich's own profiles")
    check(GamepadCompanionHapticsDB.profiles.use["Alberich-"] == nil, "the blank-realm key dropped")
    check(GamepadCompanionHapticsDB.profiles.feel["Alberich 2"] ~= nil, "its profiles still listed")
    Logout()
    disk.chars["Alberich-"] = nil
    P = Login("Nobody", "", "MAGE")
    check(GamepadCompanionHapticsDB.profiles.use["Nobody-"] == nil, "blank realm, unknown name: no new character")
    Logout()
end

-- 6d. The characters this account plays (WoW Helper's cards for one of them): a number each,
-- never reused; class, race, sex and faction from the one logged in; who plays, for the marker
do
    UnitRace = function() return "Undead", "Scourge", 5 end
    UnitSex = function() return 3 end
    UnitFactionGroup = function() return "Horde", "Horde" end
    P = Login("Mortia", "Noir", "WARLOCK")
    local list = GamepadCompanionHapticsDB.characters
    local me = list["Mortia-Noir"]
    check(me and me.class == "WARLOCK" and me.race == 5 and me.sex == 3 and me.faction == "Horde", "her entry, all of it")
    check(list["Alberich-Noir"] and list["Celes-Aria"] and list["Alberich-"] == nil, "the characters with profiles listed too")
    local nums = {}
    for _, c in pairs(list) do
        check(type(c.n) == "number" and c.n >= 1 and c.n <= 1023 and not nums[c.n], "a number each")
        nums[c.n] = true
    end
    local sent
    ns.HelperLink = { Who = function(...) sent = { ... }; return true end }
    check(P.SendWho() and sent[1] == me.n and sent[2] == "Horde" and sent[3] == 5 and sent[4] == 3, "who: her number, faction, race, sex")
    local mine = me.n
    Logout()
    check(disk.account.haptics.characters["Mortia-Noir"].n == mine, "kept at logout")
    -- her number stays hers at the next login; a number gone from the list is never given again
    P = Login("Mortia", "Noir", "WARLOCK")
    check(GamepadCompanionHapticsDB.characters["Mortia-Noir"].n == mine, "the same number next time")
    local top = GamepadCompanionHapticsDB.characterNext
    GamepadCompanionHapticsDB.characters["Mortia-Noir"] = nil
    Logout()
    UnitRace, UnitSex, UnitFactionGroup = nil, nil, nil
    P = Login("Newbie", "Noir", "MAGE")
    local nb = GamepadCompanionHapticsDB.characters["Newbie-Noir"]
    check(nb and nb.n > top and nb.class == "MAGE" and nb.race == nil and nb.faction == nil, "a new one: the next number; unknown parts left out")
    ns.HelperLink = nil
    check(not P.SendWho(), "no link: nothing sent")
    Logout()
    -- no name: no entry, nothing sent
    P = Login(nil, nil, nil)
    check(P.Who() == nil, "no name: nobody")
    Logout()
end

-- 7. Recommended's keys exist in the game's lists
local known = {}
local f = io.open(root .. "/HapticsLab.lua"):read("*a") .. io.open(root .. "/Rumble.lua"):read("*a")
for key in pairs(ns.Profiles.RECOMMENDED.events) do
    if not f:find('key = "' .. key .. '"', 1, true) then known[#known + 1] = key end
end
check(#known == 0, "Recommended's moments exist: " .. table.concat(known, ", "))

if failures > 0 then io.write(failures, " failures\n"); os.exit(1) end
io.write("PASS: profiles: migration exact, isolation across saves, no name untouched, new characters, menu, share\n")
