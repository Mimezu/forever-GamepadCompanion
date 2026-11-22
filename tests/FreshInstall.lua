-- A brand-new install (a second PC): nothing saved, new characters of any class. What they
-- get without anyone's own setup: Recommended + FRESH (calm, Alberich's choices), the camera
-- left alone, a first session with a blank realm still new at the next login, the frequent
-- big feels softer, no trigger reaction on the held layer buttons. An older install keeps
-- what it had.
-- lua5.1 tests/FreshInstall.lua <addon folder>
local root = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: ", label, "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end
local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end

-- Frames: one per CreateFrame, events by name
local frames
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, a)
    for _, f in ipairs(frames) do if f.events[event] and f.handler then f.handler(f, event, a) end end
end
local who
function UnitName() return who and who.name end
function GetRealmName() return who and who.realm end
function UnitClass() return who and who.class, who and who.class end
function InCombatLockdown() return false end

-- The account's files on disk, and each character's
local disk = { chars = {} }
local ns
local function Login(name, realm, class)
    who = { name = name, realm = realm, class = class }
    frames = {}
    GamepadCompanionHapticsDB = Copy(disk.haptics)
    GamepadCompanionDB = Copy(disk.db)
    GamepadCompanionCharDB = Copy(disk.chars[name])
    ns = {}
    assert(loadfile(root .. "/Profiles.lua"))("GamepadCompanion", ns)
    ns.Profiles.reload = function() end
    Fire("ADDON_LOADED", "GamepadCompanion")
    Fire("PLAYER_LOGIN")
    return ns.Profiles
end
local function Logout()
    Fire("PLAYER_LOGOUT")
    disk.haptics = Copy(GamepadCompanionHapticsDB)
    disk.db = Copy(GamepadCompanionDB)
    disk.chars[who.name] = Copy(GamepadCompanionCharDB)
end

---------------------------------------------------------------------------
-- 1. A brand-new install, a mage: Recommended + FRESH + the class, the camera off
---------------------------------------------------------------------------
local P = Login("Nyx", "Aria", "MAGE")
local h = GamepadCompanionHapticsDB
check(P.state.pointed, "new install: profiles on")
eq(h.fresh, P.FRESH.version, "the Feel profile stamped FRESH")
eq(h.ui.cameraFraming, false, "new install: camera framing off")
check(not P.CameraFraming(), "new install: the camera left alone")
eq(h.events.uiError.on, false, "UI errors: no rumble on every mashed button")
eq(h.events.block.on, false, "a shield's block: off")
eq(h.events.money.on, true, "money: on (Alberich)")
eq(h.events.hit.on, false, "hits: off (Recommended calm)")
eq(h.events.landing.feel, "flick", "landing: Flick")
local vib = GamepadCompanionCharDB.vibration
check(vib.events.jump == nil, "a jump's take-off: not turned on")
eq(vib.events.autoAttack.on, false, "a mage: melee swings off (class)")
eq(vib.events.shot.on, true, "a mage: the wand's shots on (class)")
eq(vib.intensity, 1, "strength: full")
eq(P.RecommendedOn("events", "uiError"), false, "UI errors' Default: off")
eq(P.RecommendedOn("vibration", "jump"), nil, "jump's Default: the code's own (off)")
eq(P.FreshOf("feelVolumes", "kill"), 0.5, "a kill's Boom: half")
Logout()

-- her next login: still off; a hunter alt on the same account: FRESH too, camera still off
P = Login("Nyx", "Aria", "MAGE")
check(not P.CameraFraming(), "camera framing stays off")
Logout()
P = Login("Talon", "Aria", "HUNTER")
eq(GamepadCompanionHapticsDB.fresh, P.FRESH.version, "a hunter alt: stamped too")
eq(GamepadCompanionCharDB.vibration.events.autoAttack.on, true, "a hunter: swings on (FRESH)")
eq(GamepadCompanionHapticsDB.events.uiError.on, false, "a hunter: UI errors off")
check(not P.CameraFraming(), "camera framing is account-wide")
P.SetCameraFraming(true)
check(P.CameraFraming(), "turned on: on")
Logout()
P = Login("Talon", "Aria", "HUNTER")
check(P.CameraFraming(), "turned on: kept")
Logout()

---------------------------------------------------------------------------
-- 2. An install from before (saved settings, no camera choice): framing stays on
---------------------------------------------------------------------------
disk = { chars = {}, db = { bars = { main = { x = 10 } }, optionsStyle = "forever" },
    haptics = { events = { hit = { on = true, feel = "thud" } }, link = { on = true } } }
P = Login("Alberich", "Noir", "PALADIN")
check(P.CameraFraming(), "older install: camera framing on as before")
check(GamepadCompanionHapticsDB.ui.cameraFraming == nil, "older install: nothing written")
Logout()
-- (and one already on profiles)
P = Login("Alberich", "Noir", "PALADIN")
check(not P.MarkNewInstall(), "profiles saved: not a new install")
check(P.CameraFraming(), "still on")
Logout()

---------------------------------------------------------------------------
-- 3. A blank realm on the very first session: profiles off; the next login she is still new
---------------------------------------------------------------------------
disk = { chars = {} }
P = Login("Nyx", "", "MAGE")
check(not P.state.pointed, "blank realm: profiles off this session")
check(type(GamepadCompanionCharDB) == "table" and GamepadCompanionCharDB.fresh == true, "her file says: still new")
GamepadCompanionCharDB.keys = { a = "spell:1" }   -- (a module wrote meanwhile)
Logout()
P = Login("Nyx", "Aria", "MAGE")
check(P.state.pointed, "realm known: profiles on")
eq(GamepadCompanionHapticsDB.fresh, P.FRESH.version, "the new-character path: FRESH, not the code's own")
eq(GamepadCompanionHapticsDB.events.hit.on, false, "Recommended's calm kept (hits off)")
eq(GamepadCompanionHapticsDB.events.uiError.on, false, "UI errors off")
check(GamepadCompanionCharDB.fresh == nil, "a new Controls profile (the stub left behind)")
Logout()

---------------------------------------------------------------------------
-- 4. Volumes: FRESH's softer feels only on a stamped profile
---------------------------------------------------------------------------
do
    GamepadCompanionHapticsDB = { fresh = 1 }
    local vns = { Haptics = { DB = function() return GamepadCompanionHapticsDB end } }
    frames = {}
    assert(loadfile(root .. "/Profiles.lua"))("GamepadCompanion", vns)
    assert(loadfile(root .. "/Volume.lua"))("GamepadCompanion", vns)
    local Vol = vns.Volume
    eq(Vol.Feel("kill"), 0.5, "stamped: a kill at half")
    eq(Vol.Feel("lowHp"), 0.6, "stamped: low health softer")
    eq(Vol.Feel("autoAttack"), 0.6, "stamped: swings softer")
    eq(Vol.Feel("mount"), 0.5, "the code's own under-full kept")
    eq(Vol.Feel("loot"), 1, "the rest: full")
    Vol.SetFeel("kill", 0.5)
    check(Vol.DB().feel.kill == nil, "set to its Default: nothing saved")
    GamepadCompanionHapticsDB = {}
    eq(Vol.Feel("kill"), 1, "unstamped (older profile): a kill as before")
end

---------------------------------------------------------------------------
-- 5. Trigger reactions: none on the held layer buttons for a FRESH profile
---------------------------------------------------------------------------
local function TriggerRows(class, fresh)
    local now = 100
    GetTime = function() return now end
    C_Timer = { After = function() end }
    UnitClass = function() return class, class end
    UnitHealth = function() return 1000 end
    UnitHealthMax = function() return 1000 end
    UnitPower = function() return 50 end
    UnitPowerMax = function() return 100 end
    GetSpellCooldown = function() return 0, 0 end
    GetComboPoints = function() return 0 end
    local db = { link = { on = true } }
    GamepadCompanionHapticsDB = db
    local tns = { Haptics = { DB = function() return db end } }
    frames = {}
    assert(loadfile(root .. "/Profiles.lua"))("GamepadCompanion", tns)
    -- (as in game: the files run first, the profile is pointed at ADDON_LOADED after; no
    -- frames for these, as tests/TriggerStack.lua)
    local cf = CreateFrame
    CreateFrame = nil
    for _, f in ipairs({ "HelperLink.lua", "TriggerRules.lua", "Stack.lua", "TriggerStack.lua" }) do
        assert(loadfile(root .. "/" .. f))("GamepadCompanion", tns)
    end
    CreateFrame = cf
    db.fresh = fresh   -- (the Feel profile pointed: its stamp now)
    tns.Profiles.state.pointed = true
    local byId = {}
    for _, r in ipairs(tns.TriggerStack.kind:Rows()) do byId[r.id] = r end
    return byId, tns.TriggerStack.kind
end
local rows, kind = TriggerRows("MAGE", 1)
check(rows.gcd and rows.gcd.on == false, "fresh mage: no wall on every global cooldown")
check(rows.cast and rows.cast.on == true, "fresh mage: the cast's tension kept")
check(rows.hurt and rows.hurt.on == true, "fresh mage: low health kept")
check(kind:IsDefault(), "fresh mage: that is its Default")
rows = TriggerRows("WARRIOR", 1)
check(rows.rage and rows.rage.on == false, "fresh warrior: L2 not firm all through combat")
rows = TriggerRows("ROGUE", 1)
check(rows.energy and rows.energy.on == false, "fresh rogue: L2 not firm all through combat")
rows = TriggerRows("MAGE", nil)
check(rows.gcd and rows.gcd.on == true, "older profile: the global cooldown's wall as before")

---------------------------------------------------------------------------
-- 6. The camera: off, its CVars never touched; on, framed; turned off, the game's own back
---------------------------------------------------------------------------
do
    local sets, temps, values = 0, 0, {}
    C_CVar = {
        SetCVar = function(n, v) sets = sets + 1; values[n] = v end,
        SetTempCVar = function() temps = temps + 1 end,
        RemoveTempCVar = function() end,
        GetCVarDefault = function(n) return n == "CameraKeepCharacterCentered" and "1" or "0" end,
    }
    C_Timer = { After = function(_, fn) fn() end }
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    CameraZoomIn = function() end
    GamepadCompanionHapticsDB = { ui = { cameraFraming = false } }
    local cns = {}
    frames = {}
    assert(loadfile(root .. "/Profiles.lua"))("GamepadCompanion", cns)
    assert(loadfile(root .. "/CameraPitch.lua"))("GamepadCompanion", cns)
    local CP = cns.CameraPitch
    Fire("PLAYER_ENTERING_WORLD")
    Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
    eq(sets + temps, 0, "off: no camera CVar written")
    CP.SetEnabled(true)
    check(sets > 0 and values.CameraKeepCharacterCentered == "0" and values.test_cameraDynamicPitch == "1", "on: framed")
    check(GamepadCompanionHapticsDB.ui.cameraFraming == true, "on: saved")
    sets = 0
    Fire("PLAYER_ENTERING_WORLD")
    check(sets > 0, "on: framed again after a loading screen")
    CP.SetEnabled(false)
    eq(values.CameraKeepCharacterCentered, "1", "off: centred as the game ships")
    eq(values.test_cameraDynamicPitch, "0", "off: dynamic pitch as the game ships")
    sets = 0
    Fire("PLAYER_ENTERING_WORLD")
    eq(sets, 0, "off again: untouched")
end

io.write(string.format("FreshInstall: %d checks, %d failed\n", checks, failures))
if failures > 0 then os.exit(1) end
