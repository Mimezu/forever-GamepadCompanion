-- OpenMap on the gamepad map. OpenMap already has a controller view of its
-- own (its PadView.lua, "OpenMap's map with the Gamepad UI (test)", off by
-- default): its seamless map drawn over Blizzard's gamepad map, the pad read
-- rather than bound (the right stick zooms, A/X are Blizzard's own hooked,
-- B closes as Blizzard's does), so nothing of Blizzard's map is tainted.
--
-- Companion doesn't draw a second map or add a second switch: it turns
-- OpenMap's own switch on once (before OpenMap starts, so no /reload is
-- needed beyond the one that loads this), then leaves it to OpenMap's menu.
-- Turned off there, it stays off.
--
-- It also keeps a note of the last map opening (GamepadCompanionHapticsDB
-- .openMap.seen): whether the Gamepad UI was on and whether OpenMap's view
-- covered Blizzard's map (OpenMap makes Blizzard's canvas see-through then).
local _, ns = ...
local O = {}
ns.OpenMapPad = O

-- the record, account-wide as OpenMap's settings are
function O.Record(store)
    if type(store.openMap) ~= "table" then store.openMap = {} end
    return store.openMap
end

-- OpenMap's settings table, once OpenMap's saved settings are loaded
function O.Settings(openMapDB)
    return type(openMapDB) == "table" and type(openMapDB.worldmap) == "table" and openMapDB.worldmap or nil
end

-- Once: OpenMap's controller view on. True if it was turned on now.
-- Already on counts as done, so a later "off" in OpenMap's menu is kept.
function O.TurnOn(store, openMapDB, now)
    local record = O.Record(store)
    if record.padViewOn then return false end
    local settings = O.Settings(openMapDB)
    if not settings then return false end
    record.padViewOn = now or 0
    if settings.padView == true then return false end
    settings.padView = true
    return true
end

-- What a map opening showed: OpenMap's view covers Blizzard's map when
-- Blizzard's canvas is see-through (canvasAlpha ~ 0)
function O.Seen(store, padUI, canvasAlpha, padView, now)
    local record = O.Record(store)
    local view = padUI and type(canvasAlpha) == "number" and canvasAlpha < 0.01 or false
    record.seen = { at = now or 0, padUI = padUI and true or false, padView = padView and true or false, view = view }
    record.opens = (tonumber(record.opens) or 0) + 1
    return view
end

-- Game wiring ------------------------------------------------------------------
if not CreateFrame then return end

local function Store()
    if type(GamepadCompanionHapticsDB) ~= "table" then GamepadCompanionHapticsDB = {} end
    return GamepadCompanionHapticsDB
end

local function Now() return time and time() or 0 end

local function TryTurnOn()
    if O.TurnOn(Store(), _G.OpenMapDB, Now()) then
        print("|cff80c0ffGamepad Companion:|r OpenMap on the gamepad map. Off: OpenMap's menu › The map.")
    end
end

local function PadUI()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() and true or false
end

local function Look()
    local map = _G.WorldMapFrame
    if not (map and map:IsShown()) then return end
    local child = map.ScrollContainer and map.ScrollContainer.Child
    local settings = O.Settings(_G.OpenMapDB)
    O.Seen(Store(), PadUI(), child and child:GetAlpha(), settings and settings.padView, Now())
end

local hooked = false
local function HookMap()
    local map = _G.WorldMapFrame
    if hooked or not (map and map.HookScript) then return end
    hooked = true
    map:HookScript("OnShow", function() C_Timer.After(0.5, Look) end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "OpenMap" then TryTurnOn() end
        if name == "Blizzard_WorldMap" then HookMap() end
    elseif event == "PLAYER_LOGIN" then
        TryTurnOn()   -- (OpenMap loaded first, or its settings were new at load)
        HookMap()
    end
end)
