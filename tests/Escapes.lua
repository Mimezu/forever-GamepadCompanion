-- Every quoted string in the addon's Lua: no escape Lua 5.1 doesn't know.
-- "Interface\Icons\x" loses its backslashes ("InterfaceIcons..."): a blank
-- icon, and no error anywhere. lua5.1 tests/Escapes.lua .
local root = arg[1] or "."
local VALID = {}
for c in ("abfnrtv\\\"'\n0123456789"):gmatch(".") do VALID[c] = true end

local files = {}
local toc = assert(io.open(root .. "/GamepadCompanion.toc"))
for line in toc:lines() do
    local f = line:match("^([%w_]+%.lua)%s*$")
    if f then files[#files + 1] = f end
end
toc:close()
assert(#files > 20, "files from the TOC: " .. #files)

local bad = {}
for _, f in ipairs(files) do
    local h = io.open(root .. "/" .. f)
    if h then
        local n = 0
        for line in h:lines() do
            n = n + 1
            local i, q = 1, nil
            while i <= #line do
                local c = line:sub(i, i)
                if not q then
                    if line:sub(i, i + 1) == "--" then break end
                    if c == '"' or c == "'" then q = c end
                elseif c == "\\" then
                    local nxt = line:sub(i + 1, i + 1)
                    if nxt ~= "" and not VALID[nxt] then bad[#bad + 1] = f .. ":" .. n .. ": \\" .. nxt end
                    i = i + 1
                elseif c == q then
                    q = nil
                end
                i = i + 1
            end
        end
        h:close()
    end
end
assert(#bad == 0, "escapes Lua drops (a path loses its backslash):\n" .. table.concat(bad, "\n"))
io.write("PASS: no string with an escape Lua 5.1 drops, in " .. #files .. " files" .. string.char(10))
