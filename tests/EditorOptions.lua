local root = arg[1] or "."
local buttons, editing, spread, spells, macros = {}, false, false, 0, 0
local methods = {}
local function frame()
    return setmetatable({ scripts = {}, shown = false }, { __index = function(_, key)
        return methods[key] or function() end
    end })
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return rawget(self, "width") or 1920 end
function methods:GetHeight() return rawget(self, "height") or 1080 end
function methods:GetSize() return self:GetWidth(), self:GetHeight() end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:GetScript(key) return self.scripts[key] end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:SetText(text) self.text = text end
function methods:CreateFontString() return frame() end
function methods:CreateTexture() return frame() end
function methods:IsEnabled() return true end
function methods:IsShown() return self.shown end
function methods:Show()
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local shown = self.shown
    self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function CreateFrame(kind, name, _, template)
    local f = frame()
    f.attributes = {}
    if template and template:find("InsecureActionButtonTemplate", 1, true) then
        f.scripts.OnClick = function()
            if InCombatLockdown() then return end
            if f.attributes.type == "click" then f.attributes.clickbutton:Click() end
            if f.attributes.type == "macro" then
                assert(f.attributes.macrotext == "/macro")
                macros = macros + 1
                GamepadCompanionOptions:Hide()
            end
        end
        f.nativeClick = f.scripts.OnClick
    end
    if name then _G[name] = f end
    if kind == "Button" then buttons[#buttons + 1] = f end
    return f
end
UIParent, UISpecialFrames = frame(), {}
UnitClass = function() return "Mage", "MAGE" end
InCombatLockdown = function() return false end
local config = { x = 0, y = 0, scale = 1 }
local subscribed
GamepadCompanionAPI = {
    GetSettings = function() return { enabled = true, bars = { base = config, stance = config } } end,
    GetState = function() return { enabled = true, available = true, nativeEnabled = true, spread = spread } end,
    GetCapabilities = function() return { layout = true, activeZoom = true } end,
    Subscribe = function() subscribed = true end,
    Unsubscribe = function() subscribed = false end,
    SetEditing = function(value) editing = value; if not value then spread = false end end,
    SetSpread = function(value) spread = value; return true end,
}
PlayerSpellsUtil = { ToggleSpellBookFrame = function() error("Must not call the addon spellbook opener") end }
Enum = { ForbiddenAspect = { ScriptedInput = 1 } }
local forbidden = false
SpellbookMicroButton = {
    HasAccessConstraints = function() return false end,
    HasAnyForbiddenAspects = function() return forbidden end,
    Click = function() spells = spells + 1; GamepadCompanionOptions:Hide() end,
}
C_AddOns = { LoadAddOn = function() end }
MacroFrame_Show = function() error("Must not call the addon macro opener") end
ShowMacroFrame = MacroFrame_Show
local ns = {}
C_Texture = { GetAtlasInfo = function() return {
    file = 123, width = 300, height = 50, leftTexCoord = 0, rightTexCoord = 1,
    topTexCoord = 0, bottomTexCoord = 1,
} end }
assert(loadfile(root .. "/OptionsSkin.lua"))("GamepadCompanion", ns)
assert(loadfile(root .. "/Options.lua"))("GamepadCompanion", ns)
GamepadCompanionAPI.ToggleOptions()
assert(editing and GamepadCompanionOptions:IsShown())
assert(subscribed, 'visible options subscribe to live state')
local function click(label)
    for _, button in ipairs(buttons) do
        if type(rawget(button, "label")) == "table" and button.label.text == label then
            if rawget(button, "nativeClick") then assert(button.scripts.OnClick == button.nativeClick) end
            if button.scripts.PreClick then button.scripts.PreClick() end
            button.scripts.OnClick()
            if button.scripts.PostClick then button.scripts.PostClick() end
            return
        end
    end
    error("Missing button: " .. label)
end
click("Stance")
click("Spread view: Off")
assert(spread)
click("Spells"); click("Macros")
assert(spells == 1 and macros == 1 and editing and spread and GamepadCompanionOptions:IsShown())
forbidden = true
GamepadCompanionAPI.RefreshOptions()
click("Spells")
assert(spells == 1 and editing and spread, "forbidden delegate must not invoke an insecure fallback")
InCombatLockdown = function() return true end
click("Macros")
assert(macros == 1 and editing and spread, "macro action must not run during combat")
InCombatLockdown = function() return false end
click("Close")
assert(not editing and not spread and not GamepadCompanionOptions:IsShown())
assert(not subscribed, 'closed options do not keep input polling alive')
print("PASS: GPC editor controls open spellbook/macros alongside spread and clear temporary mode on close")
