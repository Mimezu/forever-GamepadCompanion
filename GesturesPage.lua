-- The Gestures tab: what each gesture runs. Only the gestures that exist:
-- recorded in WoW Helper (its data addon names them) or already given an
-- action here. Each row: the gesture's name, the action's icon, the action
-- on its plate (Choose), and a quiet × to take it off. The key chord WoW
-- Helper presses (Ctrl Shift Alt F<slot>) stays out of sight, in the tooltip.
local _, ns = ...
local S, Shell, HUI = ns.OptionsSkin, ns.Shell, ns.HapticsUI
local W, PH = Shell.W, Shell.H

local ui = { rows = {} }
local ACCEPTS = { spell = true, item = true, macro = true, halo = true, window = true, text = true }
local CARD_W = 700
local MOTION_ICON = "Interface\\Icons\\Ability_Rogue_Sprint"

local function Recorded(slot)
    local C = ns.HelperCues
    local name = C and type(C.GestureName) == "function" and C.GestureName(slot) or nil
    return type(name) == "string" and name or nil
end

-- The gestures to show, in slot order: recorded, or with an action
function ui.Shown()
    local G = ns.Gestures
    local list = {}
    for slot = 1, G.SLOTS do
        local name = Recorded(slot)
        if name or G.Get(slot) then list[#list + 1] = { slot = slot, name = name or G.Label(slot) } end
    end
    return list
end

local function Refresh()
    local G = ns.Gestures
    if not (G and ui.card) then return end
    local list = ui.Shown()
    for i, r in ipairs(ui.rows) do
        local g = list[i]
        r:SetShown(g ~= nil)
        if g then
            r.slot = g.slot
            local action = G.Get(g.slot)
            local name, icon
            if action and ns.Touch then name, icon = ns.Touch.ActionLook(action) end
            r.label:SetText(g.name)
            r.icon:SetTexture(icon or MOTION_ICON)
            r.icon:SetDesaturated(action == nil)
            -- (unassigned: calm, "Choose"; never red)
            r:SetChoice(action and (name or action) or "Choose", icon, G.IsPending() and "After combat" or nil, false)
            r.pick.label:SetTextColor(action and S.GOLD[1] or S.GREY[1], action and S.GOLD[2] or S.GREY[2], action and S.GOLD[3] or S.GREY[3])
            r.clear:SetShown(action ~= nil)
            S.Tooltip(r.pick, g.name, "Ctrl Shift Alt F" .. g.slot)
        end
    end
    local n = #list
    ui.card:SetHeight(n > 0 and (14 + n * HUI.ROW_H + 10) or 180)
    ui.empty:SetShown(n == 0)
end

local function Build(frame)
    local G = ns.Gestures
    if not G then return end
    ui.card = S.Card(frame, nil, 0, 0, CARD_W, 180)
    -- the empty state: no gestures yet, and where they come from
    ui.empty = CreateFrame("Frame", nil, ui.card)
    ui.empty:SetAllPoints()
    local glyph = ui.empty:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(MOTION_ICON)
    glyph:SetDesaturated(true)
    glyph:SetAlpha(0.6)
    glyph:SetSize(40, 40)
    glyph:SetPoint("TOP", 0, -34)
    local title = S.Text(ui.empty, "No gestures yet", 0, 0, CARD_W, 14, S.GOLD)
    title:ClearAllPoints()
    title:SetPoint("TOP", glyph, "BOTTOM", 0, -12)
    title:SetJustifyH("CENTER")
    local hint = S.Text(ui.empty, "Record them in WoW Helper › Gestures", 0, 0, CARD_W, 12, S.GREY)
    hint:ClearAllPoints()
    hint:SetPoint("TOP", title, "BOTTOM", 0, -8)
    hint:SetJustifyH("CENTER")
    -- the rows (as many as there are slots; only the gestures that exist show)
    for i = 1, G.SLOTS do
        local r
        r = HUI.MomentRow(ui.card, -14 - (i - 1) * HUI.ROW_H, CARD_W, MOTION_ICON, "", function()
            local slot = r.slot
            ns.Picker.Open({ title = r.label:GetText() or G.Label(slot), accepts = ACCEPTS, current = G.Get(slot),
                onPick = function(action) G.Set(slot, action); Refresh() end })
        end, nil, nil, { clear = function() G.Set(r.slot, nil); Refresh() end, quiet = true })
        r:Hide()
        ui.rows[i] = r
    end
end

ns.GesturesPage = ui
ui.Refresh = Refresh

Shell.AddPage({
    key = "gestures", name = "Gestures", order = 3, icon = MOTION_ICON,
    build = Build, refresh = Refresh,
    hide = function() if ns.Picker then ns.Picker.Close() end end,
})
