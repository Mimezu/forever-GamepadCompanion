-- Static check (night review 2 V-1): no file reads a global that it also declares
-- as a local (a local used before its declaration, or out of its scope: in the
-- game a nil global, an error), and every global read is known: set by the
-- addon, Lua's own, or a game name listed in tests/fixtures/game-globals.txt
-- (the test harnesses' catch-all no-ops only those).
-- Run: lua5.1 tests/Globals.lua .   (needs luac5.1 on the PATH)
local root = arg[1] or "."

local function lines(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

-- The addon's files, as the TOC loads them
local files = {}
for line in lines(root .. "/GamepadCompanion.toc"):gmatch("[^\r\n]+") do
    local f = line:match("^%s*([%w_/\\]+%.lua)%s*$")
    if f then files[#files + 1] = (f:gsub("\\", "/")) end
end
assert(#files > 20, "TOC read: " .. #files .. " files")

-- Each file's global reads and writes (luac -l: "[line] GETGLOBAL ... ; Name")
local reads, sets = {}, {}
for _, file in ipairs(files) do
    local p = assert(io.popen('luac5.1 -l -p "' .. root .. "/" .. file .. '" 2>&1'))
    local out = p:read("*a")
    p:close()
    assert(out:find("main <", 1, true), "luac5.1 -l on " .. file .. ": " .. out:sub(1, 200))
    reads[file] = {}
    for ln, op, name in out:gmatch("%[(%d+)%]%s+([GS]ETGLOBAL)%s+[^;\n]*;%s*([%w_]+)") do
        if op == "SETGLOBAL" then sets[name] = true
        else reads[file][#reads[file] + 1] = { name = name, line = tonumber(ln) } end
    end
end

-- Lua 5.1's own, and WoW's Lua additions
local LUA = {}
for name in ([[_G _VERSION assert collectgarbage coroutine debug error gcinfo getfenv getmetatable ipairs
    load loadstring math next pairs pcall print rawequal rawget rawset select setfenv setmetatable string table
    tonumber tostring type unpack xpcall bit date time strsplit strjoin strtrim strmatch strfind strsub strlen
    strlower strupper strrep strbyte strchar strrev gsub gmatch format tinsert tremove wipe sort tContains
    abs ceil floor max min mod sqrt random sin cos exp log securecall issecure hooksecurefunc geterrorhandler
    seterrorhandler debugstack forceinsecure scrub issecretvalue CopyTable]]):gmatch("%S+") do LUA[name] = true end
local GAME = {}
for line in lines(root .. "/tests/fixtures/game-globals.txt"):gmatch("[^\r\n]+") do
    local name = line:match("^%s*([%w_]+)")
    if name then GAME[name] = true end
end

local failures = {}
local function fail(msg) failures[#failures + 1] = msg end

for _, file in ipairs(files) do
    local text = lines(root .. "/" .. file)
    -- the file-level locals it declares, and where (local function X / local X, Y = ..., at the
    -- line's start: a local inside a function is that function's, not the file's)
    local locals, n = {}, 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local code = line:gsub("%-%-.*$", "")
        local fname = code:match("^local%s+function%s+([%a_][%w_]*)")
        if fname then
            locals[fname] = locals[fname] or {}
            table.insert(locals[fname], n)
        else
            local names = code:match("^local%s+([%a_][%w_,%s]*)")
            if names then
                for name in names:gmatch("[%a_][%w_]*") do
                    locals[name] = locals[name] or {}
                    table.insert(locals[name], n)
                end
            end
        end
    end
    for _, r in ipairs(reads[file]) do
        local decl = locals[r.name]
        local sameLine = false
        for _, l in ipairs(decl or {}) do if l == r.line then sameLine = true end end
        -- (local X = X: the global read on the declaring line itself)
        if decl and not sameLine then
            fail(string.format("%s:%d reads global %s, but the file declares a local %s (line %s): used before its declaration?",
                file, r.line, r.name, r.name, table.concat(decl, ", ")))
        elseif not (sets[r.name] or LUA[r.name] or GAME[r.name]) then
            fail(string.format("%s:%d reads unknown global %s (not set by the addon, not Lua's, not in tests/fixtures/game-globals.txt)",
                file, r.line, r.name))
        end
    end
end

if #failures > 0 then
    for _, f in ipairs(failures) do io.write(f, "\n") end
    error(#failures .. " global(s) wrong")
end
io.write("PASS: globals: no local used as a global, every global read known (", #files, " files)\n")
