-- Halo rings picked in Choose: the macro they run opens the ring, and the
-- layout names them "Halo: <ring>".
-- lua5.1 tests/HaloRings.lua <addon folder>
local root = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; io.write("FAIL: " .. label .. "\n") end
end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

local ns = {}
assert(loadfile(root .. "/TouchModel.lua"))("GamepadCompanion", ns)
local T = ns.TouchModel

-- The game's /click (SecureCmdList.CLICK): "<name> <mouse button> <down>",
-- the down read with ValueToBoolean (default false)
local function StringToBoolean(s, default)
    local l = s:lower()
    if l == "true" or l == "1" or l == "yes" then return true end
    if l == "false" or l == "0" or l == "no" then return false end
    return default
end
local clicks = {}
local frames = {
    -- Halo's HaloButton, as Secure.lua reads a macro's click: t<id>, on down only
    HaloButton = { Click = function(_, button, down)
        local ring = tonumber(button:match("^t(%d+)$"))
        if ring and down then clicks[#clicks + 1] = ring end
    end },
}
local function RunMacro(text)
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local msg = line:match("^/click%s+(.+)$")
        if msg then
            local name, mouse, down = msg:match("([^%s]+)%s+([^%s]+)%s*(.*)")
            if not name then name = msg end
            local f = frames[name]
            if f then f:Click(mouse or "LeftButton", StringToBoolean(down or "", false)) end
        end
    end
end

local rings = { ["1"] = true, ["12"] = true }
local lookup = { haloRing = function(id) return rings[tostring(id)] == true end }

-- The macro
eq(T.MacroText("halo:1", lookup), "/click HaloButton t1 true", "ring 1's macro")
eq(T.MacroText("halo:12", lookup), "/click HaloButton t12 true", "ring 12's macro")
eq(T.MacroText("halo:7", lookup), nil, "a ring Halo doesn't have: nothing")
eq(T.MacroText("halo:1", {}), nil, "Halo not loaded: nothing")
eq(T.MacroText("halo:1 x", lookup), nil, "a ring id is digits only")

clicks = {}
RunMacro(T.MacroText("halo:12", lookup))
eq(#clicks, 1, "the macro clicks Halo once")
eq(clicks[1], 12, "it opens ring 12")

-- The old macro: the game read its down as "LeftButton true" (false): no ring
clicks = {}
RunMacro("/click HaloButton t1 LeftButton true")
eq(#clicks, 0, "the old macro opened nothing (the bug)")

-- Bar slots run it through a character macro of their own
eq(T.SlotMacroName("halo:12"), "gpc:h:12", "slot macro name")

-- The label
eq(T.HaloLabel("Utility"), "Halo: Utility", "named Halo: ring")
eq(T.HaloLabel(nil), "Halo ring", "no name")
eq(T.HaloLabel(""), "Halo ring", "empty name")

if failures > 0 then
    io.write(("HaloRings: %d of %d checks failed\n"):format(failures, checks))
    os.exit(1)
end
io.write(("PASS: Halo rings: %d checks\n"):format(checks))
