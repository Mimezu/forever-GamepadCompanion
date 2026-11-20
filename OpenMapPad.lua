-- OpenMap on the gamepad map: undone. 0.69.3 (ebe8def) turned OpenMap's own
-- controller view (its PadView.lua, off by default) on once; the user prefers
-- Blizzard's gamepad map. This turns it back off, once, only where Companion
-- turned it on (record.padViewOn), then leaves OpenMap's menu alone: turned on
-- there again, it stays on.
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

-- Once: OpenMap's controller view off again, if Companion turned it on.
-- True if it was turned off now.
function O.GiveBack(store, openMapDB)
    local record = O.Record(store)
    if not record.padViewOn or record.padViewBack then return false end
    local settings = O.Settings(openMapDB)
    if not settings then return false end
    record.padViewBack = true
    record.seen, record.opens = nil, nil
    if settings.padView ~= true then return false end
    settings.padView = false
    return true
end

-- Game wiring ------------------------------------------------------------------
if not CreateFrame then return end

local function Store()
    if type(GamepadCompanionHapticsDB) ~= "table" then GamepadCompanionHapticsDB = {} end
    return GamepadCompanionHapticsDB
end

local function TryGiveBack()
    if O.GiveBack(Store(), _G.OpenMapDB) then
        print("|cff80c0ffGamepad Companion:|r Blizzard's map on the gamepad again.")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
    if (event == "ADDON_LOADED" and name == "OpenMap") or event == "PLAYER_LOGIN" then TryGiveBack() end
end)
