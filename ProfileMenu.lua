-- The two profile chips in the window's footer (Profiles.lua): Controls and
-- Feel, each with its own menu: the profiles (pick: switch, reloads), New,
-- Copy, Rename, For new <class>, Reset, Delete, Share.
local _, ns = ...
local S, Shell, HUI, P = ns.OptionsSkin, ns.Shell, ns.HapticsUI, ns.Profiles
local M = {}
ns.ProfileMenu = M

local KINDS = { { "controls", "Controls" }, { "feel", "Feel" } }
local chips = {}

local function Say(text, warn) Shell.SetStatus(warn and ("|cffff7a5c" .. text .. "|r") or text, true) end
local function Trim(text) return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function M.Refresh()
    for _, c in ipairs(chips) do
        local name = P.Current(c.kind)
        c.label:SetText(c.word .. ": " .. (name or "—"))
        c:SetEnabled(name ~= nil)
    end
end

local function Confirm(anchor, title, word, fn)
    HUI.Popup(anchor, title, { { key = "yes", label = word, icon = false }, { key = "no", label = "Cancel", icon = false } }, nil,
        function(k) if k == "yes" then fn() end end, 2, 110, true)
end

local function ClassName()
    local name = UnitClass and UnitClass("player")
    return type(name) == "string" and name or "class"
end

function M.Open(kind, anchor)
    local current = P.Current(kind)
    if not current then return end
    local word = kind == "feel" and "Feel" or "Controls"
    local entries = {}
    for _, name in ipairs(P.Names(kind)) do entries[#entries + 1] = { key = "use:" .. name, label = name, icon = false } end
    for _, a in ipairs({ { "new", "New" }, { "copy", "Copy" }, { "rename", "Rename" },
        { "start", P.IsStart(kind) and "Class start: on" or "Class start" },
        { "reset", "Reset" }, { "delete", "Delete" }, { "share", "Share" } }) do
        entries[#entries + 1] = { key = a[1], label = a[2], icon = false }
    end
    HUI.Popup(anchor, word, entries, "use:" .. current, function(key)
        local name = key:match("^use:(.+)$")
        if name then
            if name ~= current and not P.Use(kind, name) then Say("Not in combat", true) end
        elseif key == "new" then
            HUI.TextWindow("New " .. word, P.Free(kind, word), function(text)
                local made = P.New(kind, Trim(text) ~= "" and Trim(text) or word)
                Say("Made: " .. made)
            end, "Make")
        elseif key == "copy" then
            Say("Made: " .. P.New(kind, current .. " copy", current))
        elseif key == "rename" then
            HUI.TextWindow("Rename " .. current, current, function(text)
                if P.Rename(kind, current, Trim(text)) then M.Refresh() else Say("Name taken", true) end
            end, "Rename")
        elseif key == "start" then
            P.StartHere(kind, not P.IsStart(kind))
            Say(P.IsStart(kind) and ("New " .. ClassName() .. ": " .. current) or "")
        elseif key == "reset" then
            Confirm(anchor, kind == "feel" and "Back to Recommended?" or "Start empty?", "Reset", function()
                if not P.Reset(kind) then Say("Not in combat", true) end
            end)
        elseif key == "delete" then
            local unused = {}
            for _, n in ipairs(P.Names(kind)) do if not P.InUse(kind, n) then unused[#unused + 1] = { key = n, label = n, icon = false } end end
            if #unused == 0 then return Say("All in use", true) end
            HUI.Popup(anchor, "Delete", unused, nil, function(n)
                Confirm(anchor, "Delete " .. n .. "?", "Delete", function() P.Delete(kind, n); Say("Deleted: " .. n) end)
            end, 2, 150, true)
        elseif key == "share" then
            local text = P.Export(kind, current)
            HUI.TextWindow("Share · paste one to add it", text, function(pasted)
                if Trim(pasted) == Trim(text) then return end
                local made, why = P.Import(Trim(pasted))
                Say(made and ("Added: " .. made) or why, not made)
            end, "Add")
        end
        M.Refresh()
    end, 2, 150, true)
end

-- Into the footer, left of `right` (the version)
function M.Build(window, right)
    local x = -12
    for i = #KINDS, 1, -1 do
        local k = KINDS[i]
        local chip = S.NewButton(window, "", 0, 0, 180, nil, nil, 11, 26)
        chip:ClearAllPoints()
        chip:SetPoint("RIGHT", right, "LEFT", x, 0)
        chip.kind, chip.word = k[1], k[2]
        chip:SetScript("OnClick", function(self) M.Open(self.kind, self) end)
        S.Tooltip(chip, k[2], k[1] == "feel" and "Vibration, light, sound" or "Buttons, touchpad, bars")
        chips[#chips + 1] = chip
        x = x - 186
    end
    M.Refresh()
end

M.chips = chips
