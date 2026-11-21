-- The bobber's prompt (BobberPrompt.lua): Blizzard's soft-target icon on the bobber's nameplate
-- shows Blizzard's R2 prompt while R2 catches; every other prompt untouched; Blizzard's drawing
-- back the moment the target or R2's job changes.
-- lua5.1 tests/BobberPrompt.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- Game stubs ---------------------------------------------------------------------
function strsplit(sep, s)
    local out = {}
    for part in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
    return unpack(out)
end
unpack = unpack or table.unpack

-- units: token -> { guid, name, object }; which one is the soft-interact target
local units = {}
local softinteract
function UnitIsUnit(a, b)
    local function resolve(u) if u == "softinteract" then return softinteract end return u end
    return resolve(a) ~= nil and resolve(a) == resolve(b)
end
function UnitIsGameObject(u) return units[u] ~= nil and units[u].object == true end
function UnitGUID(u) return units[u] and units[u].guid end
function UnitName(u) return units[u] and units[u].name end

-- The game's glyph atlases (the install's UiTextureAtlasMember: Gamepad_<style>_<button>_<size>),
-- and the active controller style (PlayStation shapes)
local atlases = {}
for _, style in ipairs({ "Shp", "Gen", "Ltr", "Rev" }) do
    for _, size in ipairs({ "32", "64" }) do atlases[("gamepad_" .. style .. "_rtrigger_" .. size):lower()] = true end
end
C_Texture = { GetAtlasInfo = function(a) return atlases[a:lower()] and { width = 32 } or nil end }
local iconSet = "Shapes"
InputDeviceIconSetManager = { GetActiveInputDeviceIconSet = function() return iconSet end }

-- a texture: file or atlas, texcoords, shown
local function Texture()
    local t = { shown = false, coords = { 0, 1, 0, 1 } }
    -- (as in the game: a file keeps the texcoords set before; an atlas sets its own)
    function t:SetTexture(f) self.file, self.atlas = f, nil end
    function t:SetAtlas(a) self.atlas, self.file, self.coords = a, "atlasfile", { 0.1, 0.9, 0.2, 0.8 } end
    function t:GetAtlas() return self.atlas end
    function t:GetTexture() return self.file end
    function t:SetTexCoord(...) self.coords = { ... } end
    function t:GetTexCoord() return unpack(self.coords) end
    function t:IsShown() return self.shown end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end

-- nameplates: token -> frame
local plates = {}
local function Plate(token, forbidden)
    local icon = Texture()
    local f = { namePlateUnitToken = token, UnitFrame = { SoftTargetFrame = { Icon = icon } }, forbidden = forbidden }
    function f:GetUnit() return self.namePlateUnitToken end
    function f:IsForbidden() return self.forbidden end
    plates[token] = f
    return f, icon
end
C_NamePlate = { GetNamePlateForUnit = function(u)
    for token, f in pairs(plates) do if UnitIsUnit(token, u) then return f end end
end }

-- Blizzard's driver: draws the cursor's gamepad prompt on the soft-interact unit's icon
local cursorOf = {}     -- token -> what SetUnitCursorTexture draws (an atlas name, or a file)
NamePlateDriverFrame = {}
function NamePlateDriverFrame:UpdateSoftTargetIconInternal(frame)
    local icon = frame.UnitFrame.SoftTargetFrame.Icon
    local unit = frame:GetUnit()
    if UnitIsUnit(unit, "softinteract") and cursorOf[unit] then
        local c = cursorOf[unit]
        if c.atlas then icon:SetAtlas(c.atlas) else icon:SetTexture(c.file) end
        icon:Show()
    else
        icon:Hide()
    end
end
function NamePlateDriverFrame:OnSoftTargetUpdate()
    for _, f in pairs(plates) do self:UpdateSoftTargetIconInternal(f) end
end
function hooksecurefunc(t, name, post)
    local orig = t[name]
    t[name] = function(...) local a, b, c = orig(...); post(...); return a, b, c end
end

-- Fishing.lua's word: R2 catches or not
local catching = false
local char = { fishing = {} }
local ns = { Fishing = { Catching = function() return catching end }, Shared = { CharDB = function() return char end } }

assert(loadfile(root .. "/BobberPrompt.lua"))("GamepadCompanion", ns)
local P = ns.BobberPrompt
check(P.Hook(), "hooked onto Blizzard's soft-target icon")
check(P.Hook(), "hooking twice: once")

-- The scene: our bobber, a copper vein, a fishing trainer
units.bobber = { guid = "GameObject-0-4170-0-1-35591-0000ABCD12", name = "Fishing Bobber", object = true }
units.vein = { guid = "GameObject-0-4170-0-1-1731-0000ABCD13", name = "Copper Vein", object = true }
units.npc = { guid = "Creature-0-4170-0-1-3332-0000ABCD14", name = "Lumak", object = false }
local _, bobberIcon = Plate("bobber")
local _, veinIcon = Plate("vein")
local _, npcIcon = Plate("npc")
cursorOf.bobber = { atlas = "Gamepad_Shp_Square_32" }
cursorOf.vein = { atlas = "Gamepad_Shp_Square_32" }
cursorOf.npc = { file = "Interface\\Cursor\\Speak" }

-- who is the bobber
eq(P.EntryOf(units.bobber.guid), 35591, "the bobber's entry from its GUID")
eq(P.EntryOf(units.npc.guid), nil, "a creature's GUID: no game object entry")
eq(P.EntryOf(nil), nil, "no GUID")
softinteract = "bobber"
check(P.IsBobber("bobber"), "the soft-interact bobber is the bobber")
check(not P.IsBobber("vein"), "a vein (not the soft target) isn't")
softinteract = "vein"
check(not P.IsBobber("vein"), "a vein as soft target isn't the bobber")
units.oddbobber = { guid = "GameObject-0-1-0-1-999999-0", name = "Fishing Bobber", object = true }
softinteract = "oddbobber"
check(P.IsBobber("oddbobber"), "another entry, the bobber's name: the bobber")
softinteract = "npc"
check(not P.IsBobber("npc"), "an NPC isn't")

-- 1. the bobber the soft target, R2 not catching (no pole, or switched off): Blizzard's prompt
softinteract = "bobber"
NamePlateDriverFrame:OnSoftTargetUpdate()
eq(bobberIcon:GetAtlas(), "Gamepad_Shp_Square_32", "R2 not catching: Blizzard's own prompt")

-- 2. R2 catches: the bobber's prompt is Blizzard's R2, on the same texture
catching = true
NamePlateDriverFrame:OnSoftTargetUpdate()
eq(bobberIcon:GetAtlas(), "Gamepad_Shp_RTrigger_32", "R2 catches: the bobber shows R2")
check(bobberIcon:IsShown(), "shown, as Blizzard showed it")
eq(P.seen and P.seen.atlas, "Gamepad_Shp_Square_32", "what the game drew is remembered")
eq(char.fishing.prompt and char.fishing.prompt.glyph, "Gamepad_Shp_RTrigger_32", "kept in saved settings: the swap ran")
-- the next game update keeps it R2 (Blizzard draws the square again, the hook puts R2 back)
NamePlateDriverFrame:OnSoftTargetUpdate()
eq(bobberIcon:GetAtlas(), "Gamepad_Shp_RTrigger_32", "every game update: still R2")

-- 3. the soft target moves to the vein: its prompt untouched, the bobber's plate hidden by
-- Blizzard and given back its own drawing
softinteract = "vein"
NamePlateDriverFrame:OnSoftTargetUpdate()
eq(veinIcon:GetAtlas(), "Gamepad_Shp_Square_32", "a node: Blizzard's prompt, untouched")
check(not bobberIcon:IsShown(), "the bobber no longer the target: Blizzard hid its icon")
eq(bobberIcon:GetAtlas(), "Gamepad_Shp_Square_32", "and its own drawing is back on it")

-- 4. an NPC (a file texture): untouched, and no texcoords of ours left on a reused icon
softinteract = "npc"
NamePlateDriverFrame:OnSoftTargetUpdate()
eq(npcIcon:GetTexture(), "Interface\\Cursor\\Speak", "an NPC: Blizzard's prompt, untouched")
eq(npcIcon:GetAtlas(), nil, "no atlas put on it")
-- the bobber's (pooled) icon reused for the NPC: Blizzard draws a file; the atlas' texcoords go
softinteract = "bobber"
NamePlateDriverFrame:OnSoftTargetUpdate()
eq(bobberIcon:GetAtlas(), "Gamepad_Shp_RTrigger_32", "back on the bobber: R2")
plates.bobber.namePlateUnitToken = "npc"; plates.npc = nil; plates.bobber = nil; plates.npc2 = nil
local reused = { namePlateUnitToken = "npc", UnitFrame = { SoftTargetFrame = { Icon = bobberIcon } } }
function reused:GetUnit() return self.namePlateUnitToken end
function reused:IsForbidden() return false end
plates.npc = reused
softinteract = "npc"
NamePlateDriverFrame:UpdateSoftTargetIconInternal(reused)
eq(bobberIcon:GetTexture(), "Interface\\Cursor\\Speak", "the reused icon: the NPC's prompt")
eq(table.concat({ bobberIcon:GetTexCoord() }, ","), "0,1,0,1", "full texcoords, none of the atlas'")

-- 5. the line comes in while the bobber is still the soft target: back at once, no game update
local f2, icon2 = Plate("bobber")
softinteract = "bobber"
NamePlateDriverFrame:UpdateSoftTargetIconInternal(f2)
eq(icon2:GetAtlas(), "Gamepad_Shp_RTrigger_32", "R2 on the bobber")
catching = false
P.Refresh()
eq(icon2:GetAtlas(), "Gamepad_Shp_Square_32", "R2 no longer catches: Blizzard's prompt back at once")
-- and R2 catching again: R2 at once
catching = true
P.Refresh()
eq(icon2:GetAtlas(), "Gamepad_Shp_RTrigger_32", "R2 catches again: R2 at once")

-- 6. the same set, another size: R2 at that size; another pad style's set: its R2
cursorOf.bobber = { atlas = "Gamepad_Shp_Square_64" }
NamePlateDriverFrame:UpdateSoftTargetIconInternal(f2)
eq(icon2:GetAtlas(), "Gamepad_Shp_RTrigger_64", "a 64 glyph: the 64 R2")
cursorOf.bobber = { atlas = "gamepad_gen_x_32" }
NamePlateDriverFrame:UpdateSoftTargetIconInternal(f2)
eq(icon2:GetAtlas(), "Gamepad_Gen_RTrigger_32", "an Xbox pad's glyph: its own RT")
-- drawn as a file (no atlas to read): the active style's set
cursorOf.bobber = { file = 4567890 }
NamePlateDriverFrame:UpdateSoftTargetIconInternal(f2)
eq(icon2:GetAtlas(), "Gamepad_Shp_RTrigger_32", "a file: the active style's R2 (Shapes)")
iconSet = "Letters"
NamePlateDriverFrame:UpdateSoftTargetIconInternal(f2)
eq(icon2:GetAtlas(), "Gamepad_Ltr_RTrigger_32", "Letters style: its R2")
iconSet = "Shapes"
cursorOf.bobber = { atlas = "Gamepad_Shp_Square_32" }

-- 7. a forbidden nameplate: never touched
local f3, icon3 = Plate("bobber", true)
NamePlateDriverFrame:UpdateSoftTargetIconInternal(f3)
eq(icon3:GetAtlas(), "Gamepad_Shp_Square_32", "forbidden nameplate: untouched")

-- 8. no such glyph in the install (an atlas this client lacks): Blizzard's prompt stays
local savedAtlases = atlases
atlases = {}
local f4, icon4 = Plate("bobber")
NamePlateDriverFrame:UpdateSoftTargetIconInternal(f4)
eq(icon4:GetAtlas(), "Gamepad_Shp_Square_32", "no R2 glyph in the install: left as it is")
atlases = savedAtlases

io.write(string.format("BobberPrompt: %d checks, %d failures\n", checks, failures))
os.exit(failures == 0 and 0 or 1)
