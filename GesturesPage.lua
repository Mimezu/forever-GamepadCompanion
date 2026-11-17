-- The Gestures tab: what each of WoW Helper's gestures runs (Gestures.lua).
-- The movements are recorded in WoW Helper › Gestures; each arrives here as
-- Ctrl Shift Alt F<slot>.
local _, ns = ...
local S, Shell, HUI = ns.OptionsSkin, ns.Shell, ns.HapticsUI
local W, PH = Shell.W, Shell.H
local floor = math.floor

local ui = { rows = {} }
local ACCEPTS = { spell = true, item = true, macro = true, halo = true, window = true, text = true }

-- A slot's name: WoW Helper's (its data addon), else "Gesture <n>"
local function Name(G, slot)
    local C = ns.HelperCues
    local d = C and type(C.Data) == "function" and C.Data() or nil
    local names = d and type(d.gestures) == "table" and d.gestures
    return names and names[slot] or G.Label(slot)
end

local function Refresh()
    local G = ns.Gestures
    if not G then return end
    for _, r in ipairs(ui.rows) do
        local action = G.Get(r.slot)
        local name, icon
        if action and ns.Touch then name, icon = ns.Touch.ActionLook(action) end
        local sub = "Ctrl Shift Alt F" .. r.slot
        if G.IsPending() then sub = sub .. " · after combat" end
        r.label:SetText(Name(G, r.slot))
        r:SetChoice(action and (name or action) or "Off", icon, sub, action == nil)
    end
end

local function Build(frame, header)
    local G = ns.Gestures
    if not G then return end
    if header then
        local sub = S.Text(header, "Record in WoW Helper › Gestures", 0, 0, 400, 12, S.GREY)
        sub:ClearAllPoints()
        sub:SetPoint("RIGHT", header, "RIGHT", -6, -1)
        sub:SetJustifyH("RIGHT")
    end
    local CW = floor((W - 10) / 2)
    for col = 0, 1 do
        local card = S.Card(frame, nil, col * (CW + 10), 0, CW, PH)
        for i = 1, G.SLOTS / 2 do
            local slot = col * (G.SLOTS / 2) + i
            local function Pick()
                ns.Picker.Open({ title = "Choose · " .. Name(G, slot), accepts = ACCEPTS, current = G.Get(slot),
                    onPick = function(action) G.Set(slot, action); Refresh() end })
            end
            local r = HUI.ChoiceRow(card, -14 - (i - 1) * HUI.ROW_H, CW, "Interface\\Icons\\Ability_Rogue_Sprint", Name(G, slot),
                Pick, nil, "Spell, item, macro or /emote", { clear = function() G.Set(slot, nil); Refresh() end })
            r.slot = slot
            ui.rows[#ui.rows + 1] = r
        end
    end
end

ns.GesturesPage = ui
ui.Refresh = Refresh

Shell.AddPage({
    key = "gestures", name = "Gestures", order = 3, icon = "Interface\\Icons\\Ability_Rogue_Sprint",
    build = Build, refresh = Refresh,
    hide = function() if ns.Picker then ns.Picker.Close() end end,
})
